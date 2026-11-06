-- analysis.sql — Cyclistic capstone: how do casual riders differ from members?
--
-- Run from the repo root (paths below are relative), e.g.
--     python -c "import duckdb; print(duckdb.connect().execute(open('sql/analysis.sql').read()).fetchdf())"
-- or paste one query at a time into any DuckDB client. Each query is
-- independent and reads the cleaned Parquet dataset built by
-- sql/build_clean.py. The 128 spillover rows with ym = '2025-10' stay in
-- the table but are out of scope for the monthly views, so Q1/Q7/Q8 filter
-- ym >= '2025-11'.
--
-- Business question: how do annual members and casual riders use the
-- bikes differently, and what would turn more casual riders into members?

-- Q1 monthly ride counts by rider type (Nov 2025 - Oct 2026).
SELECT ym,
       COUNT(*) FILTER (WHERE member_casual = 'member') AS member_rides,
       COUNT(*) FILTER (WHERE member_casual = 'casual') AS casual_rides,
       COUNT(*) AS total_rides,
       ROUND(100.0 * COUNT(*) FILTER (WHERE member_casual = 'casual') / COUNT(*), 2) AS casual_pct
FROM read_parquet('data_clean/trips_clean/*/*.parquet', hive_partitioning = true)
WHERE ym >= '2025-11'
GROUP BY ym
ORDER BY ym;

-- Q2 overall share: members vs casuals.
SELECT member_casual,
       COUNT(*) AS rides,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_rides
FROM read_parquet('data_clean/trips_clean/*/*.parquet', hive_partitioning = true)
GROUP BY member_casual
ORDER BY rides DESC;

-- Q3 average (and median) ride length in minutes by rider type.
-- The mean is sensitive to the 5,148 kept rides over 24h, so the median
-- is reported alongside it.
SELECT member_casual,
       COUNT(*) AS rides,
       ROUND(AVG(ride_length_min), 2) AS avg_minutes,
       ROUND(MEDIAN(ride_length_min), 2) AS median_minutes,
       ROUND(MAX(ride_length_min), 1) AS max_minutes
FROM read_parquet('data_clean/trips_clean/*/*.parquet', hive_partitioning = true)
GROUP BY member_casual
ORDER BY avg_minutes DESC;

-- Q4 average ride length by weekday and rider type (Monday first).
SELECT DAYNAME(started_at) AS weekday,
       EXTRACT(isodow FROM started_at) AS dow,
       COUNT(*) FILTER (WHERE member_casual = 'member') AS member_rides,
       COUNT(*) FILTER (WHERE member_casual = 'casual') AS casual_rides,
       ROUND(AVG(ride_length_min) FILTER (WHERE member_casual = 'member'), 2) AS member_avg_min,
       ROUND(AVG(ride_length_min) FILTER (WHERE member_casual = 'casual'), 2) AS casual_avg_min,
       ROUND(MEDIAN(ride_length_min) FILTER (WHERE member_casual = 'member'), 2) AS member_med_min,
       ROUND(MEDIAN(ride_length_min) FILTER (WHERE member_casual = 'casual'), 2) AS casual_med_min
FROM read_parquet('data_clean/trips_clean/*/*.parquet', hive_partitioning = true)
GROUP BY weekday, dow
ORDER BY dow;

-- Q5 average ride length by bike type and rider type.
SELECT rideable_type,
       member_casual,
       COUNT(*) AS rides,
       ROUND(AVG(ride_length_min), 2) AS avg_minutes,
       ROUND(MEDIAN(ride_length_min), 2) AS median_minutes
FROM read_parquet('data_clean/trips_clean/*/*.parquet', hive_partitioning = true)
GROUP BY rideable_type, member_casual
ORDER BY rideable_type, member_casual;

-- Q6 top 10 start stations for casual riders (the membership-kiosk angle).
-- Blank station names are dockless trips with no fixed dock, so they are
-- excluded here: a kiosk needs a physical station.
SELECT start_station_name AS station,
       COUNT(*) AS casual_rides,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_casual_station_rides
FROM read_parquet('data_clean/trips_clean/*/*.parquet', hive_partitioning = true)
WHERE member_casual = 'casual'
  AND start_station_name IS NOT NULL
  AND start_station_name <> ''
GROUP BY station
ORDER BY casual_rides DESC
LIMIT 10;

-- Q7 seasonal pattern: rides and casual share by meteorological season.
SELECT CASE WHEN ym IN ('2025-12', '2026-01', '2026-02') THEN 'winter'
            WHEN ym IN ('2026-03', '2026-04', '2026-05') THEN 'spring'
            WHEN ym IN ('2026-06', '2026-07', '2026-08') THEN 'summer'
            ELSE 'fall' END AS season,
       COUNT(*) AS rides,
       ROUND(100.0 * COUNT(*) FILTER (WHERE member_casual = 'casual') / COUNT(*), 2) AS casual_pct,
       ROUND(AVG(ride_length_min) FILTER (WHERE member_casual = 'casual'), 2) AS casual_avg_min,
       ROUND(AVG(ride_length_min) FILTER (WHERE member_casual = 'member'), 2) AS member_avg_min
FROM read_parquet('data_clean/trips_clean/*/*.parquet', hive_partitioning = true)
WHERE ym >= '2025-11'
GROUP BY season
ORDER BY rides DESC;

-- Q8 average ride length by month and rider type (does the gap hold year-round?).
SELECT ym,
       ROUND(AVG(ride_length_min) FILTER (WHERE member_casual = 'casual'), 2) AS casual_avg_min,
       ROUND(AVG(ride_length_min) FILTER (WHERE member_casual = 'member'), 2) AS member_avg_min,
       ROUND(AVG(ride_length_min) FILTER (WHERE member_casual = 'casual')
           - AVG(ride_length_min) FILTER (WHERE member_casual = 'member'), 2) AS gap_min
FROM read_parquet('data_clean/trips_clean/*/*.parquet', hive_partitioning = true)
WHERE ym >= '2025-11'
GROUP BY ym
ORDER BY ym;
