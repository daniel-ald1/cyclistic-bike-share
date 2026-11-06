"""Phase-2 charts for the Cyclistic capstone.

Reads the cleaned Parquet dataset built by sql/build_clean.py and writes
three PNGs into charts/:
    monthly_volume.png      monthly rides, members vs casuals
    avg_duration_weekday.png  avg ride minutes by weekday x rider type
    top_casual_stations.png   top 10 casual start stations

Run from the repo root:  python charts/make_charts.py
"""
import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, 'data_clean', 'trips_clean', '*', '*.parquet')
OUT = os.path.join(REPO, 'charts')


def main():
    import duckdb
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    os.makedirs(OUT, exist_ok=True)
    con = duckdb.connect()

    # 1. Monthly volume, members vs casuals (in-scope months only).
    m = con.execute(
        "SELECT ym,"
        " COUNT(*) FILTER (WHERE member_casual = 'member') AS member,"
        " COUNT(*) FILTER (WHERE member_casual = 'casual') AS casual"
        f" FROM read_parquet('{DATA}', hive_partitioning = true)"
        " WHERE ym >= '2025-11' GROUP BY ym ORDER BY ym").fetchdf()
    fig, ax = plt.subplots(figsize=(10, 5))
    x = range(len(m))
    w = 0.4
    ax.bar([i - w / 2 for i in x], m['member'], w, label='Members')
    ax.bar([i + w / 2 for i in x], m['casual'], w, label='Casuals')
    ax.set_xticks(list(x), m['ym'].tolist(), rotation=45, ha='right')
    ax.set_ylabel('Rides')
    ax.set_title('Monthly rides: members vs casuals (Nov 2025 - Oct 2026)')
    ax.legend()
    ax.grid(axis='y', alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, 'monthly_volume.png'), dpi=150)
    plt.close(fig)

    # 2. Average ride minutes by weekday x rider type, Monday first.
    d = con.execute(
        "SELECT DAYNAME(started_at) AS weekday,"
        " EXTRACT(isodow FROM started_at) AS dow,"
        " AVG(ride_length_min) FILTER (WHERE member_casual = 'member') AS member,"
        " AVG(ride_length_min) FILTER (WHERE member_casual = 'casual') AS casual"
        f" FROM read_parquet('{DATA}', hive_partitioning = true)"
        " GROUP BY weekday, dow ORDER BY dow").fetchdf()
    fig, ax = plt.subplots(figsize=(10, 5))
    x = range(len(d))
    ax.bar([i - w / 2 for i in x], d['member'], w, label='Members')
    ax.bar([i + w / 2 for i in x], d['casual'], w, label='Casuals')
    ax.set_xticks(list(x), d['weekday'].tolist())
    ax.set_ylabel('Average minutes per ride')
    ax.set_title('Average ride length by weekday and rider type')
    ax.legend()
    ax.grid(axis='y', alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, 'avg_duration_weekday.png'), dpi=150)
    plt.close(fig)

    # 3. Top 10 casual start stations (physical stations only).
    t = con.execute(
        "SELECT start_station_name AS station, COUNT(*) AS rides"
        f" FROM read_parquet('{DATA}', hive_partitioning = true)"
        " WHERE member_casual = 'casual'"
        " AND start_station_name IS NOT NULL AND start_station_name <> ''"
        " GROUP BY station ORDER BY rides DESC LIMIT 10").fetchdf()
    t = t.iloc[::-1]  # smallest on top for horizontal bars
    fig, ax = plt.subplots(figsize=(10, 5.5))
    ax.barh(t['station'], t['rides'])
    for i, v in enumerate(t['rides']):
        ax.text(v, i, f' {v:,}', va='center', fontsize=8)
    ax.set_xlabel('Casual rides (Nov 2025 - Oct 2026)')
    ax.set_title('Top 10 start stations for casual riders')
    ax.grid(axis='x', alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, 'top_casual_stations.png'), dpi=150)
    plt.close(fig)

    for fn in ['monthly_volume.png', 'avg_duration_weekday.png', 'top_casual_stations.png']:
        p = os.path.join(OUT, fn)
        print(f'{fn}  {os.path.getsize(p) / 1024:.0f} KB')
    print('charts written to', OUT)


if __name__ == '__main__':
    main()
