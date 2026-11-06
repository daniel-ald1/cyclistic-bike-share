"""Build the clean Cyclistic trip table.

One reproducible path for phase 2 cleaning:
    python sql/build_clean.py        (run from the repo root)

Streams the 12 monthly zips in data_raw/ in 500k-row pandas chunks
(never all 6.3M rows in RAM) into a scratch DuckDB database, then
executes every @step in sql/cleaning.sql in order, then exports the
clean table as a month-partitioned Parquet dataset in data_clean/.

Outputs:
    data_clean/trips_clean/   partitioned Parquet, hive-style by ym
                              (data_clean/trips_clean/ym=YYYY-MM/*.parquet)
"""
import glob
import os
import re
import shutil
import sys
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(REPO, 'data_raw')
OUT_DIR = os.path.join(REPO, 'data_clean', 'trips_clean')
TMP_DB = os.path.join(REPO, 'data_clean', '_build_tmp.duckdb')
CLEANING_SQL = os.path.join(REPO, 'sql', 'cleaning.sql')
CHUNK = 500_000


def steps(path):
    """Split cleaning.sql into (marker, sql) chunks on '-- @' lines."""
    cur_marker, cur_lines = 'preamble', []
    out = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            m = re.match(r'\s*--\s*@([\w]+)\s*:?\s*(.*)', line)
            if m:
                out.append((cur_marker, ''.join(cur_lines)))
                cur_marker = '@' + m.group(1)
                cur_lines = []
            else:
                cur_lines.append(line)
    out.append((cur_marker, ''.join(cur_lines)))
    return out


def main():
    import duckdb
    import pandas as pd

    print('duckdb', duckdb.__version__, '| pandas', pd.__version__, flush=True)
    if os.path.exists(TMP_DB):
        os.remove(TMP_DB)
    con = duckdb.connect(TMP_DB)

    zips = sorted(glob.glob(os.path.join(RAW_DIR, '*-divvy-tripdata.zip')))
    assert len(zips) == 12, f'expected 12 zips, found {len(zips)}'
    raw_cols = ['ride_id', 'rideable_type', 'started_at', 'ended_at',
                'start_station_name', 'start_station_id', 'end_station_name',
                'end_station_id', 'start_lat', 'start_lng', 'end_lat',
                'end_lng', 'member_casual']

    for marker, sql in steps(CLEANING_SQL):
        if marker == '@python':
            n_files = n_rows = 0
            for z in zips:
                fname = os.path.basename(z)
                with zipfile.ZipFile(z) as zf:
                    inner = [n for n in zf.namelist()
                             if n.endswith('.csv') and not n.startswith('__MACOSX')]
                    assert len(inner) == 1, (fname, zf.namelist())
                    with zf.open(inner[0]) as f:
                        for ch in pd.read_csv(f, chunksize=CHUNK, dtype=str):
                            ch = ch[raw_cols]
                            con.register('chunk_v', ch)
                            con.execute(
                                "INSERT INTO trips_raw (ride_id, rideable_type, started_at, ended_at,"
                                " start_station_name, start_station_id, end_station_name, end_station_id,"
                                " start_lat, start_lng, end_lat, end_lng, member_casual, src_file)"
                                f" SELECT ride_id, rideable_type, started_at, ended_at,"
                                " start_station_name, start_station_id, end_station_name, end_station_id,"
                                " start_lat, start_lng, end_lat, end_lng, member_casual,"
                                f" '{fname}' FROM chunk_v")
                            con.unregister('chunk_v')
                            n_rows += len(ch)
                n_files += 1
                print(f'  loaded {fname}  (cumulative rows: {n_rows})', flush=True)
            print(f'loaded {n_files} files, {n_rows} rows total', flush=True)
        elif marker == 'preamble':
            continue
        else:
            for i, stmt in enumerate([s for s in sql.split(';') if s.strip()]):
                code = '\n'.join(l for l in stmt.splitlines()
                                 if not l.strip().startswith('--')).strip()
                if not code:
                    continue
                if re.match(r'SELECT\b', code, re.S):
                    df = con.execute(stmt).fetchdf()
                    print(f'--- {marker}[{i}]', flush=True)
                    print(df.to_string(index=False), flush=True)
                else:
                    con.execute(stmt)
            print(f'ran {marker}', flush=True)

    if os.path.exists(OUT_DIR):
        shutil.rmtree(OUT_DIR)
    con.execute(
        "COPY (SELECT * FROM trips_clean ORDER BY started_at) "
        f"TO '{OUT_DIR}' (FORMAT PARQUET, PARTITION_BY (ym))")
    con.close()

    # Verify the export straight from Parquet (not from the scratch DB).
    con2 = duckdb.connect()
    n = con2.execute(
        f"SELECT COUNT(*) FROM read_parquet('{OUT_DIR}/*/*.parquet', hive_partitioning=1)"
    ).fetchone()[0]
    print('parquet row count:', n, flush=True)
    total_b = 0
    for root, _, files in os.walk(OUT_DIR):
        for fn in sorted(files):
            p = os.path.join(root, fn)
            total_b += os.path.getsize(p)
            rel = os.path.relpath(p, OUT_DIR)
            print(f'  {rel}  {os.path.getsize(p) / 1e6:.1f} MB', flush=True)
    print(f'parquet total: {total_b / 1e6:.1f} MB in {OUT_DIR}', flush=True)
    os.remove(TMP_DB)
    print('removed scratch db; done.', flush=True)


if __name__ == '__main__':
    sys.exit(main())
