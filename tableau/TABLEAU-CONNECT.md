# Tableau Build Guide: Cyclistic Members vs Casuals

I rebuilt my three Python charts in Tableau Public so stakeholders can filter the patterns themselves. My source is the cleaned Parquet in data_clean/trips_clean/, which I aggregate into three small CSVs in tableau/ for Tableau Public, and my sanity checks below use the real analysis numbers. If a view disagrees with them, my build is wrong rather than the data.

## Connect the data

Tableau Public cannot read partitioned Parquet directly, and it never needs the 6.3M-row trip table, so I export three small aggregate CSVs first. From the repo root I run one DuckDB export per sheet into tableau/, then connect Tableau to those CSVs. The exports keep only the columns each sheet needs: monthly_volume_membership.csv carries ym, member_casual, and rides; avg_duration_weekday.csv carries weekday, member_casual, and avg_minutes; and top_casual_stations.csv carries station and rides.

1. Run the export from the repo root with DuckDB and confirm three CSVs appear in tableau/: monthly_volume_membership.csv with 26 rows, avg_duration_weekday.csv with 14 rows, and top_casual_stations.csv with 10 rows.
2. Open Tableau Desktop or Tableau Public and choose Connect, then Text File, and point it at the three CSVs in tableau/, one data source per sheet: Monthly Volume reads monthly_volume_membership.csv, Weekday Duration reads avg_duration_weekday.csv, and Top Casual Stations reads top_casual_stations.csv.
3. In the Data Source tab, confirm ym, member_casual, weekday, and station read as strings, and rides and avg_minutes read as numbers.
4. Create an extract with Data, then Create Data Extract, so publishing to Tableau Public carries the data with the workbook.
5. Sanity check before building anything: monthly_volume_membership.csv sums to 6,293,342 rides, with member share reading 64.42% member and 35.58% casual. Top_casual_stations.csv reads Navy Pier at 50,894 on top, and avg_duration_weekday.csv reads 22.52 for casuals on Saturday and 23.32 on Sunday. When all match, I start the sheets.

## Sheet 1: Monthly volume, members vs casuals

This is the seasonal swing view. July should read 869,000 rides with a 41.2% casual share and January 138,000 rides with an 18.0% casual share.

1. Open a new sheet and name it Monthly Volume.
2. Drag ym to Columns. Right click it and set Sort to Ascending so months run Nov 2025 to Oct 2026.
3. Drag Number of Records to Rows. Change the aggregation to CNT if Tableau defaults to SUM.
4. Drag member_casual to Color. Confirm the legend shows exactly two values: member and casual.
5. Change the mark type to Bar and set the view to Side-by-Side Bars from the Show Me panel.
6. Add member_casual to Tooltip alongside CNT, then add a table calculation of Percent of Total on a copy of CNT so hovering a month shows the casual share. July should read 41.2% and January 18.0%.
7. Label the axes Rides and Month, and title the sheet Monthly rides: members vs casuals.
8. Sanity check: July is the tallest month and January the shortest. When filtered to casual only, Navy Pier style lakefront stations dominate, which Sheet 3 confirms.

## Sheet 2: Average duration by weekday and membership

This is the habit split view. Casuals should read 22.5 minutes on Saturday and 23.3 on Sunday against members near 12 minutes every day, with overall averages of 20.14 for casuals and 12.27 for members.

1. Open a new sheet and name it Weekday Duration.
2. Create a calculated field named Weekday with the formula DATENAME('weekday', [started_at]).
3. Create a second calculated field named Weekday Order with DATEPART('weekday', [started_at]). Tableau numbers Sunday as 1, so I use this only for sorting.
4. Drag Weekday to Columns, then drag Weekday Order onto the same Weekday pill with Sort set to Sort by Field using Weekday Order ascending, so the axis runs Monday to Sunday.
5. Drag ride_length_min to Rows and set the aggregation to AVG.
6. Drag member_casual to Color and confirm two series: member and casual.
7. Change the mark type to Bar, Side-by-Side, and add AVG and MEDIAN of ride_length_min to the Tooltip for each weekday.
8. Title the sheet Average ride length by weekday and rider type.
9. Sanity check: the casual bars spike on Saturday and Sunday while the member bars stay flat near 12. The grand averages should read 20.14 for casuals and 12.27 for members, with medians 10.73 and 8.50. When a weekday average lands far from these, I check the aggregation first.

## Sheet 3: Top 10 casual start stations

This is the geography view. Navy Pier belongs on top with 50,894 casual rides, followed by the lakefront corridor stations.

1. Open a new sheet and name it Top Casual Stations.
2. Drag start_station_name to Rows.
3. Drag Number of Records to Columns with CNT aggregation.
4. Drag member_casual to Filters, keep only casual, and confirm the filter shows on the sheet.
5. Add a second filter on start_station_name with Condition set to filter out Null and empty strings, since blank names are dockless trips with no fixed dock.
6. Right click the start_station_name pill, choose Filter, go to the Top tab, set Top 10 by CNT, and sort descending so Navy Pier sits at the top.
7. Change the mark type to Bar, add CNT labels to the end of each bar, and title the sheet Top 10 start stations for casual riders.
8. Sanity check: Navy Pier reads 50,894. The next stations should include DuSable Lake Shore Dr and Monroe, Michigan Ave and Oak, Millennium Park, and the museum campus stations. When a depot or test station appears here, my R5 cleaning filter did not apply to the export.

## Dashboard: 1600 by 900 with KPI tiles

I assemble the three sheets plus three KPI tiles so the headline numbers land first.

1. Open a new dashboard and set Size to Fixed at 1600 by 900.
2. Add a Text object at the top with the title Cyclistic: how casual riders differ, Nov 2025 to Oct 2026.
3. Create three KPI text objects with these exact values: 6.29M trips (6,293,342 clean rides), 64.4% member share (64.42% member against 35.58% casual), and Navy Pier top casual station (50,894 rides). I type the rounded value large and the exact value small beneath it, so the tile reads cleanly while staying auditable.
4. Drag Monthly Volume to the upper left, Weekday Duration to the upper right, and Top Casual Stations across the bottom.
5. Add a member_casual legend as a dashboard filter with Apply to all worksheets, so clicking member or casual highlights every view.
6. Add a caption text object at the bottom with the data note: 6,294,451 raw rows to 6,293,342 clean after 1,109 removals (35 duplicate ride ids, 29 negative durations, 1,045 depot or warehouse or test rows). Window Nov 2025 to Oct 2026.
7. Publish with Server, Tableau Public, Save to Tableau Public, and confirm the three sheets plus the dashboard render in the browser preview before sharing the link.
