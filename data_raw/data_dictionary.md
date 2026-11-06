# Divvy Trip Data Dictionary

Source: monthly zips from https://divvy-tripdata.s3.amazonaws.com/ (`<YYYYMM>-divvy-tripdata.zip`), each holding one CSV. I read the headers below straight from the files I downloaded (Nov 2025 through Oct 2026). Every file I checked uses the same 13 columns in the same order.

One quirk I noticed: the `202601-divvy-tripdata.zip` file internally names its CSV `202501-divvy-tripdata.csv`. The trip dates inside are January 2026, so I treat the content as January 2026 and the inner filename as a Divvy labeling slip.

## Columns

| Column | What I see in it |
| --- | --- |
| `ride_id` | Unique id for each trip (text, e.g. `F084BC803A4BE17C`) |
| `rideable_type` | Bike type. Values I observed: `classic_bike`, `electric_bike` |
| `started_at` | Trip start timestamp (`YYYY-MM-DD HH:MM:SS.mmm`) |
| `ended_at` | Trip end timestamp (same format) |
| `start_station_name` | Name of the start station; blank on some dockless or test trips |
| `start_station_id` | Id of the start station; blank where the name is blank |
| `end_station_name` | Name of the end station; blank on some trips |
| `end_station_id` | Id of the end station; blank where the name is blank |
| `start_lat` | Start latitude (decimal degrees) |
| `start_lng` | Start longitude (decimal degrees) |
| `end_lat` | End latitude (decimal degrees) |
| `end_lng` | End longitude (decimal degrees) |
| `member_casual` | Rider type. Values I observed: `member`, `casual` |

## Coverage of my download

Twelve monthly files, Nov 2025 through Oct 2026, totaling 6,294,451 trip rows. Trip start times run from 2025-10-31 (a few spillover rows in the November file) to 2026-10-31. I picked these months because, as of early November 2026, they are the most recent 12 complete months; the November 2026 file is not published yet (the bucket returns 404 for it).
