# How casual riders differ, and what would turn them into members

## The business question

I work with 12 months of Chicago bike-share trips, and I want to answer one question: how do annual members and casual riders use the bikes differently, and what would convince more casual riders to buy a membership?

## What I found

I cleaned 6,294,451 raw trip records down to 6,293,342 usable rides (details at the bottom). Members take 64.4% of all rides, casuals 35.6%. But the two groups ride in very different ways.

Casuals ride for fun while members ride to get somewhere: the average casual ride lasts 20.1 minutes against 12.3 for members, and the medians tell the same story (10.7 vs 8.5). The gap holds in every single month, from 4.9 minutes in January to 9.5 in May, so it is a habit, not a season.

**Weekends belong to casuals.** On Saturdays casuals take 482,000 rides and average 22.5 minutes; on Sundays 363,000 rides at 23.3 minutes. Midweek they drop to about 260,000 rides a day. Members do the opposite: they peak on Tuesdays (661,000 rides), stay flat around 12 minutes all week, and dip on Sundays. That pattern reads as commuting versus leisure.

**Summer is casual season.** July brought 869,000 rides with a 41.2% casual share; January brought 138,000 rides with only an 18.0% casual share. Winter cycling in Chicago is almost entirely members, which tells me membership already means year-round riding, while casual riding is a fair-weather habit I can sell into.

The standout casual behavior is the classic-bike day trip. Casuals on classic bikes average 39.8 minutes a ride (median 15.7), far above members on classic bikes (15.2) and far above anyone on e-bikes (casuals 14.0, members 11.0). A casual rider checking out a classic bike for 40 minutes is exactly the person for whom a membership could pay off fast.

Geography points the same way: casual trips cluster on the lakefront leisure corridor. The top casual start stations are Navy Pier (50,894 rides), DuSable Lake Shore Dr and Monroe, Michigan Ave and Oak, Millennium Park, the Shedd, Theater on the Lake, Dusable Harbor, the Field Museum, and the Adler. That is tourists and weekend wanderers, not commuters, and it tells me exactly where a membership pitch would be seen.

## My top 3 recommendations

1. **Put the membership pitch where casuals already ride: the lakefront corridor, on summer weekends.** Kiosks or staffed tents at Navy Pier, Millennium Park, and the museum campus, timed for May through August weekends when casual volume and the duration gap both peak. The message practically writes itself from the numbers: if your Saturday rides are 20-plus minutes, a membership beats paying per ride.

2. **Aim a conversion offer at long-ride classic-bike casuals.** They average nearly 40 minutes a ride, so show them the break-even math directly (one long weekend ride covers a big slice of membership) and pair it with a first-month trial that starts on the day they ride, not the day they sign up. This group already rides like members on duration; they just pay like tourists.

3. **Convert summer casuals before winter takes them away.** Casual share falls from 41% in July to 20% by December, so run the membership push in September and October at the same lakefront stations while the summer riders are still around. Members keep riding through winter (about 115,000 rides a month), which is the strongest proof point that the membership habit sticks once it forms.

## Data and cleaning notes

The raw files are the monthly Divvy trip zips, November 2025 through October 2026, with identical 13-column headers. One naming quirk: the January zip internally calls its CSV 202501, but the trips inside are January 2026. The November file also holds 128 trips starting October 31, and the October file holds 194 trips ending November 1; I kept both spillovers since they overlap the window.

Cleaning removed 1,109 rows (0.02%): 35 duplicate ride_ids, 29 rides with negative durations, and 1,045 depot, warehouse, or test-station rides. I kept the 5,148 rides over 24 hours and the 1.3 million rides with blank station names (mostly dockless e-bike trips), and I report medians next to means wherever long rides could skew an average. The full rules and audit counts live in sql/cleaning.sql, the queries in sql/analysis.sql, and the numbers above come straight from those queries.
