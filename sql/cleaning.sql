-- cleaning.sql — Cyclistic capstone: combine + clean 12 months of Divvy trips.
--
-- ONE REPRODUCIBLE PATH: run from the repo root with
--     python sql/build_clean.py
-- which streams the 12 zips in data_raw/ (chunked, never all in RAM),
-- loads them into a scratch DuckDB table, then executes every @step below
-- in order. This file is also readable/runnable step by step in any
-- DuckDB client pointed at the same scratch database.
--
-- Source: 12 monthly zips, data_raw/202511-divvy-tripdata.zip through
-- data_raw/202610-divvy-tripdata.zip (6,294,451 raw rows; identical
-- 13-column headers; the 202601 zip internally names its CSV
-- 202501-divvy-tripdata.csv but holds January 2026 trips).
--
-- Cleaning rules (applied in order so the audit counts are disjoint):
--   R1  Drop rows with null or empty ride_id (dedupe key must exist).
--   R2  Dedupe on ride_id, keep the earliest started_at per id.
--   R3  Drop rows whose started_at / ended_at do not parse (null timestamps).
--   R4  Drop rides with negative ride_length_min (ended before started).
--   R5  Drop station-test / depot / warehouse rides: start or end station
--       name matching (depot|warehouse|test station|cassette|charging pillar),
--       case-insensitive. In this window that is the Hastings/Hubbard depots,
--       the West Chicago warehouse, the cassette-repair dock, the charging
--       pillar test dock and the Hastings test station. Plain public racks
--       (e.g. "Public Rack - Bishop St & 46th St") are real trips: kept.
--
-- Deliberately KEPT (with counts in the audit so the choice is visible):
--   K1  Spillover rows: trips starting 2025-10-31 or ending 2026-11-01.
--       They overlap the 12-month window; only a few hundred rows.
--   K2  Rides longer than 24h (5,155). Overlong but real-looking; kept so the
--       cleaning stays mechanical. Duration analysis reports medians too.
--   K3  Blank station names (about 1.3M rows, mostly electric_bike trips that
--       can lock outside docks). Missing location, not a bad trip.
--   K4  Zero-length rides: there are none in this window.
--
-- RESULTS (filled in from the build run, 2026-11-06):
--   raw rows .......................... 6,294,451
--   R1 null/empty ride_id ............. 0
--   R2 duplicate ride_ids removed ..... 35
--   R3 null timestamps ................ 0
--   R4 negative ride_length ........... 29
--   R5 depot/warehouse/test stations .. 1,045
--       (980 depot + 52 warehouse + 12 test station
--        + 1 cassette-repair dock + 2 charging-pillar test dock;
--        union is 1,045 so 2 rows matched two patterns)
--   clean rows ........................ 6,293,342
--   total removed ..................... 1,109 = 0.0176%
--   clean mix: 4,054,095 member (64.4%), 2,239,247 casual (35.6%)
--   kept on purpose: 128 rows starting 2025-10-31 (their own ym=2025-10
--   partition), 194 rows ending 2026-11-01, 5,148 rides over 24h,
--   1,301,680 rows with a blank start station.

-- @step 0: raw landing table. All columns VARCHAR; timestamps are parsed
-- with TRY_CAST in @step 3 so bad values become NULL instead of failing.
DROP TABLE IF EXISTS trips_raw;
CREATE TABLE trips_raw (
    ride_id VARCHAR,
    rideable_type VARCHAR,
    started_at VARCHAR,
    ended_at VARCHAR,
    start_station_name VARCHAR,
    start_station_id VARCHAR,
    end_station_name VARCHAR,
    end_station_id VARCHAR,
    start_lat VARCHAR,
    start_lng VARCHAR,
    end_lat VARCHAR,
    end_lng VARCHAR,
    member_casual VARCHAR,
    src_file VARCHAR
);

-- @python: load_raw_chunks
-- (build_clean.py streams each zip in 500k-row pandas chunks and appends
-- them here with src_file set to the zip name. Nothing to execute in SQL.)

-- @step 1: audit the raw load.
-- Q0 raw row count (must equal 6,294,451).
SELECT COUNT(*) AS raw_rows FROM trips_raw;

-- @step 2: R1 + R2. Drop null/empty ride_id, then keep the earliest
-- started_at per ride_id.
-- Q1 rows dropped by R1.
SELECT COUNT(*) AS r1_null_empty_id
FROM trips_raw
WHERE ride_id IS NULL OR ride_id = '';
-- Q2 rows dropped by R2 (extra copies beyond the first per ride_id).
SELECT (SELECT COUNT(*) FROM trips_raw WHERE ride_id IS NOT NULL AND ride_id <> '')
     - (SELECT COUNT(DISTINCT ride_id) FROM trips_raw WHERE ride_id IS NOT NULL AND ride_id <> '')
    AS r2_duplicate_rows;
DROP TABLE IF EXISTS trips_dedup;
CREATE TABLE trips_dedup AS
SELECT *
FROM (
    SELECT r.*,
           ROW_NUMBER() OVER (
               PARTITION BY ride_id
               ORDER BY TRY_CAST(started_at AS TIMESTAMP) NULLS LAST,
                        TRY_CAST(ended_at AS TIMESTAMP) NULLS LAST
           ) AS rn
    FROM trips_raw AS r
    WHERE ride_id IS NOT NULL AND ride_id <> ''
) AS ranked
WHERE rn = 1;

-- @step 3: parse timestamps; R3 drops unparseable ones.
-- Q3 rows dropped by R3.
SELECT COUNT(*) AS r3_null_timestamps
FROM trips_dedup
WHERE TRY_CAST(started_at AS TIMESTAMP) IS NULL
   OR TRY_CAST(ended_at AS TIMESTAMP) IS NULL;
DROP TABLE IF EXISTS trips_ts;
CREATE TABLE trips_ts AS
SELECT *,
       TRY_CAST(started_at AS TIMESTAMP) AS started_ts,
       TRY_CAST(ended_at AS TIMESTAMP) AS ended_ts
FROM trips_dedup
WHERE TRY_CAST(started_at AS TIMESTAMP) IS NOT NULL
  AND TRY_CAST(ended_at AS TIMESTAMP) IS NOT NULL;

-- @step 4: ride_length_min; R4 drops negatives.
-- Q4 rows dropped by R4, plus the over-24h count (kept, K2) for the record.
SELECT COUNT(*) FILTER (
    WHERE DATE_DIFF('second', started_ts, ended_ts) / 60.0 < 0
) AS r4_negative,
COUNT(*) FILTER (
    WHERE DATE_DIFF('second', started_ts, ended_ts) / 60.0 > 1440
) AS kept_over_24h
FROM trips_ts;
DROP TABLE IF EXISTS trips_pos;
CREATE TABLE trips_pos AS
SELECT *,
       DATE_DIFF('second', started_ts, ended_ts) / 60.0 AS ride_length_min
FROM trips_ts
WHERE DATE_DIFF('second', started_ts, ended_ts) / 60.0 >= 0;

-- @step 5: R5 drops depot / warehouse / test-station rides.
-- Q5 rows dropped by R5 (which names matched, for the record).
SELECT COUNT(*) AS r5_test_station_rows,
       COUNT(*) FILTER (WHERE start_station_name ILIKE '%depot%'
                             OR end_station_name ILIKE '%depot%') AS n_depot,
       COUNT(*) FILTER (WHERE start_station_name ILIKE '%warehouse%'
                             OR end_station_name ILIKE '%warehouse%') AS n_warehouse,
       COUNT(*) FILTER (WHERE start_station_name ILIKE '%test station%'
                             OR end_station_name ILIKE '%test station%') AS n_test_station,
       COUNT(*) FILTER (WHERE start_station_name ILIKE '%cassette%'
                             OR end_station_name ILIKE '%cassette%') AS n_cassette,
       COUNT(*) FILTER (WHERE start_station_name ILIKE '%charging pillar%'
                             OR end_station_name ILIKE '%charging pillar%') AS n_charging_pillar
FROM trips_pos
WHERE COALESCE(start_station_name, '') ILIKE '%depot%'
   OR COALESCE(end_station_name, '') ILIKE '%depot%'
   OR COALESCE(start_station_name, '') ILIKE '%warehouse%'
   OR COALESCE(end_station_name, '') ILIKE '%warehouse%'
   OR COALESCE(start_station_name, '') ILIKE '%test station%'
   OR COALESCE(end_station_name, '') ILIKE '%test station%'
   OR COALESCE(start_station_name, '') ILIKE '%cassette%'
   OR COALESCE(end_station_name, '') ILIKE '%cassette%'
   OR COALESCE(start_station_name, '') ILIKE '%charging pillar%'
   OR COALESCE(end_station_name, '') ILIKE '%charging pillar%';
DROP TABLE IF EXISTS trips_clean;
CREATE TABLE trips_clean AS
SELECT
    ride_id,
    rideable_type,
    started_ts AS started_at,
    ended_ts AS ended_at,
    CAST(started_ts AS DATE) AS ride_date,
    STRFTIME(started_ts, '%Y-%m') AS ym,
    start_station_name,
    start_station_id,
    end_station_name,
    end_station_id,
    TRY_CAST(start_lat AS DOUBLE) AS start_lat,
    TRY_CAST(start_lng AS DOUBLE) AS start_lng,
    TRY_CAST(end_lat AS DOUBLE) AS end_lat,
    TRY_CAST(end_lng AS DOUBLE) AS end_lng,
    member_casual,
    ride_length_min
FROM trips_pos
WHERE NOT (
    COALESCE(start_station_name, '') ILIKE '%depot%'
    OR COALESCE(end_station_name, '') ILIKE '%depot%'
    OR COALESCE(start_station_name, '') ILIKE '%warehouse%'
    OR COALESCE(end_station_name, '') ILIKE '%warehouse%'
    OR COALESCE(start_station_name, '') ILIKE '%test station%'
    OR COALESCE(end_station_name, '') ILIKE '%test station%'
    OR COALESCE(start_station_name, '') ILIKE '%cassette%'
    OR COALESCE(end_station_name, '') ILIKE '%cassette%'
    OR COALESCE(start_station_name, '') ILIKE '%charging pillar%'
    OR COALESCE(end_station_name, '') ILIKE '%charging pillar%'
);

-- @step 6: final audit of the clean table.
-- Q6 value sanity: rider mix, bike mix, date span, duration extremes.
SELECT member_casual, COUNT(*) AS n
FROM trips_clean GROUP BY member_casual ORDER BY n DESC;
-- Q7 clean row count and removal summary.
SELECT (SELECT COUNT(*) FROM trips_raw) AS raw_rows,
       (SELECT COUNT(*) FROM trips_clean) AS clean_rows,
       (SELECT COUNT(*) FROM trips_raw) - (SELECT COUNT(*) FROM trips_clean) AS removed_rows,
       ROUND(100.0 * ((SELECT COUNT(*) FROM trips_raw) - (SELECT COUNT(*) FROM trips_clean))
             / (SELECT COUNT(*) FROM trips_raw), 4) AS removed_pct;
-- Q8 kept-but-notable (K1/K3): spillover rows and blank start stations.
SELECT COUNT(*) FILTER (WHERE started_at < TIMESTAMP '2025-11-01 00:00:00') AS kept_started_oct31,
       COUNT(*) FILTER (WHERE ended_at >= TIMESTAMP '2026-11-01 00:00:00') AS kept_ended_nov01,
       COUNT(*) FILTER (WHERE start_station_name IS NULL OR start_station_name = '') AS kept_blank_start_station
FROM trips_clean;
