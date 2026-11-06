# Cyclistic Bike-Share Capstone (Case 1)

Hi, I am Daniel Aldana. This is my Google Data Analytics capstone Case 1.

I am working with 12 months of Chicago bike-share trip data from Divvy (operated by Motivate). My goal is to understand how annual members and casual riders use the service differently, so I can suggest ways to turn more casual riders into members.

Status: in progress. Right now I am collecting the raw monthly files. Cleaning and analysis will come next.

## Data source

Divvy trip data, hosted at https://divvy-tripdata.s3.amazonaws.com/. Each monthly zip holds one CSV of individual trips.

## Repo layout

- `data_raw/` raw monthly zips plus a data dictionary (large files live under Git LFS or releases, see note below)
- `data_clean/` cleaned tables (coming in phase 2)
- `sql/` queries I used (coming in phase 2)
- `charts/` exported figures (coming in phase 2)
- `tableau/` Tableau workbook and notes (coming in phase 2)
- `publish/` final summary for sharing (coming later)

## Notes

Raw trip files are big, so if they exceed normal GitHub limits I will track zips with Git LFS or attach them as release assets and keep this repo to code and docs.
