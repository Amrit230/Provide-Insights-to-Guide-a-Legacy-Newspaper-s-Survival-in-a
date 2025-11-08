#Business Request – 1: Monthly Circulation Drop Check 
#Generate a report showing the top 3 months (2019–2024) where any city recorded the 
#sharpest month-over-month decline in net_circulation. 
WITH monthly_data AS (
    SELECT 
        d.city AS city_name,
        f.Month AS month,
        f.Net_Circulation
    FROM fact_print_sales f
    LEFT JOIN dim_city d 
        ON f.City_ID = d.city_id
),
with_diff AS (
    SELECT 
        city_name,
        month,
        net_circulation,
        net_circulation - LAG(net_circulation) OVER (
            PARTITION BY city_name 
            ORDER BY month
        ) AS mom_change
    FROM monthly_data
)
SELECT 
    city_name,
    month,
    net_circulation,
    mom_change
FROM with_diff
WHERE mom_change < 0
ORDER BY mom_change Asc
LIMIT 3;

#Business Request – 2: Yearly Revenue Concentration by Category 
#Identify ad categories that contributed > 50% of total yearly ad revenue.
#category_name 
# category_revenue  
# total_revenue_year  
# pct_of_year_total
select * from dim_ad_category;
select* from  fact_digital_pilot;
select * from fact_ad_revenue;
with cati as
(select *
	from fact_ad_revenue f 
    left join dim_ad_category d
    on f.ad_category=d.ad_category_id),
with_ev as
(
 select 
 quarter as year,
 standard_ad_category,
 ad_revenue,
 sum(ad_revenue) over( partition by  standard_ad_category ) as category_revenue , 
 sum(ad_revenue) over( partition by  standard_ad_category order by quarter  ASC) as total_revenue_year ,
round(((ad_revenue * 100.0 / SUM(ad_revenue) OVER (partition by  quarter))*100),1)AS pct_of_year_total 
 from cati
 )
 select 
 year,
standard_ad_category as category_name,
category_revenue ,
total_revenue_year,
pct_of_year_total 
from with_ev
where pct_of_year_total >50;
#Business Request – 3: 2024 Print Efficiency Leaderboard 
#For 2024, rank cities by print efficiency = net_circulation / copies_printed. Return top 5. 
#Fields: 
# city_name 
# copies_printed_2024 
# net_circulation_2024 
# efficiency_ratio = net_circulation_2024 / copies_printed_2024 
# efficiency_rank_2024 
WITH printed AS (
    SELECT  
        LEFT(f.Month, 4) AS year,
        d.city AS city_name,
        SUM(f.CopiesSold) AS copies_printed_2024,
        SUM(f.Net_Circulation) AS net_circulation_2024
    FROM fact_print_sales f 
    LEFT JOIN dim_city d
        ON f.City_ID = d.city_id
    WHERE LEFT(f.Month, 4) = '2024'
    GROUP BY LEFT(f.Month, 4), d.city
),
efficiency AS (
    SELECT
        city_name,
        copies_printed_2024,
        net_circulation_2024,
        ROUND((net_circulation_2024 / copies_printed_2024), 4) AS efficiency_ratio
    FROM printed
)
SELECT
    city_name,
    copies_printed_2024,
    net_circulation_2024,
    efficiency_ratio,
    RANK() OVER (ORDER BY efficiency_ratio DESC) AS efficiency_rank_2024
FROM efficiency
ORDER BY efficiency_ratio DESC
LIMIT 5;
;
#usiness Request – 4 : Internet Readiness Growth (2021) 
#or each city, compute the change in internet penetration from Q1-2021 to Q4-2021 
#nd identify the city with the highest improvement. 
#felds: 
#city_name 
#internet_rate_q1_2021 
#internet_rate_q4_2021 
#delta_internet_rate = internet_rate_q4_2021 − internet_rate_q1_2021
select * from dim_city;
select * from  fact_city_readiness;
with  rate as(
select	
	d.city as City,
    f.quarter as quarter,
    f.literacy_rate as litreacy_rate,
	f.smartphone_penetration as smartphone_penetration,
    f.internet_penetration,
	Round((f.internet_penetration/(f.literacy_rate* f.smartphone_penetration)*100),2) as Internet_rate
    from  fact_city_readiness f
    left join dim_city d
    on  f.city_id=d.city_id
	WHERE f.quarter IN ('2021-Q1', '2021-Q4')
)
SELECT
    r1.City,
    r1.internet_rate AS internet_rate_q1_2021,
    r2.internet_rate AS internet_rate_q4_2021,
    ROUND((r2.internet_rate - r1.internet_rate), 2) AS delta_internet_rate
FROM rate r1
JOIN rate r2 
    ON r1.city = r2.city
    AND r1.quarter = '2021-Q1'
    AND r2.quarter = '2021-Q4'
ORDER BY delta_internet_rate DESC
LIMIT 1;
#Business Request – 5: Consistent Multi-Year Decline (2019→2024) 
#Find cities where both net_circulation and ad_revenue decreased every year from 2019 
#hrough 2024 (strictly decreasing sequences). 
#Fields: 
#city_name 
#year 
#yearly_net_circulation 
#yearly_ad_revenue 
#is_declining_print (Yes/No per city over 2019–2024) 
#is_declining_ad_revenue (Yes/No) 
#is_declining_both (Yes/No)
WITH yearly_data AS (
    SELECT 
        d.city AS city_name,
        LEFT(s.Month, 4) AS year,
        SUM(s.Net_Circulation) AS yearly_net_circulation,
        SUM(r.ad_revenue) AS yearly_ad_revenue
    FROM fact_print_sales s
    JOIN fact_ad_revenue r 
        ON s.edition_id = r.edition_id 
           AND LEFT(s.Month, 4) = r.quarter
    JOIN dim_city d 
        ON s.city_id = d.city_id
    WHERE LEFT(s.Month, 4) BETWEEN '2019' AND '2024'
    GROUP BY d.city, LEFT(s.Month, 4)
),
lag_check AS (
    SELECT
        city_name,
        year,
        yearly_net_circulation,
        yearly_ad_revenue,
        LAG(yearly_net_circulation) OVER (PARTITION BY city_name ORDER BY year) AS prev_net_circulation,
        LAG(yearly_ad_revenue) OVER (PARTITION BY city_name ORDER BY year) AS prev_ad_revenue
    FROM yearly_data
),
decline_flags AS (
    SELECT
        city_name,
        CASE 
            WHEN SUM(CASE WHEN yearly_net_circulation >= prev_net_circulation THEN 1 ELSE 0 END) > 0 
            THEN 'No' ELSE 'Yes' 
        END AS is_declining_print,
        CASE 
            WHEN SUM(CASE WHEN yearly_ad_revenue >= prev_ad_revenue THEN 1 ELSE 0 END) > 0 
            THEN 'No' ELSE 'Yes' 
        END AS is_declining_ad_revenue
    FROM lag_check
    GROUP BY city_name
)
SELECT 
    y.city_name,
    y.year,
    y.yearly_net_circulation,
    y.yearly_ad_revenue,
    d.is_declining_print,
    d.is_declining_ad_revenue,
    CASE 
        WHEN d.is_declining_print = 'Yes' AND d.is_declining_ad_revenue = 'Yes' 
        THEN 'Yes' ELSE 'No' 
    END AS is_declining_both
FROM yearly_data y
JOIN decline_flags d 
    ON y.city_name = d.city_name
ORDER BY y.city_name, y.year;
 