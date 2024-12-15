use trips_db;

-- request 1
-- City level fare and trip summary Report 
select 
	d.city_name,
	count(trip_id) as total_trip,
	round(avg(fare_amount/distance_travelled_km),2) as avg_face_per_km,
	round(sum(fare_amount)/count(trip_id),2) as avg_fare_per_trip,
	round(count(trip_id)/(select count(*) from fact_trips)*100, 2) as percentage_total
from fact_trips t 
	join dim_city d
	on t.city_id=d.city_id
group by t.city_id
;


-- request 2
-- Monthly city level trips target performance report
select 
	c.city_name,
	date_format(dd.start_of_month, '%M %Y') as date__,
	count(ft.trip_id) as total_trips,
    mtt.total_target_trips,
    case when count(ft.trip_id) > mtt.total_target_trips then 'Above target'
		else 'below target'
	end as target_result,
    round((count(ft.trip_id)- mtt.total_target_trips)/mtt.total_target_trips*100,2) as diff_percentage
from 
	fact_trips ft 
	join dim_city c
	on ft.city_id=c.city_id
	join dim_date dd 
	on ft.date=dd.date
    join targets_db.monthly_target_trips mtt
    on ft.city_id=mtt.city_id and dd.start_of_month = mtt.month
group by c.city_id, month_name, mtt.total_target_trips, dd.start_of_month
ORDER BY c.city_name, dd.start_of_month
;



-- Request 3
-- City level repeat Passenger Trip Frequency
with trip_cte as(
	select 
		month,
		rtd.city_id,
		city_name,
		trip_count, 
		repeat_passenger_count,
		sum(repeat_passenger_count) over(partition by city_name) as total_trips
	from 
		dim_repeat_trip_distribution rtd 
	join dim_city c
	on rtd.city_id = c.city_id
)
select 
	city_name,
	sum(case when trip_count = '2-Trips' then repeat_passenger_count else 0 end) /max(total_trips)*100 as '2-Trips',
	sum(case when trip_count = '3-Trips' then repeat_passenger_count else 0 end) /max(total_trips)*100 as '3-Trips',
	sum(case when trip_count = '4-Trips' then repeat_passenger_count else 0 end) /max(total_trips)*100 as '4-Trips',
	sum(case when trip_count = '5-Trips' then repeat_passenger_count else 0 end) /max(total_trips)*100 as '5-Trips',
	sum(case when trip_count = '6-Trips' then repeat_passenger_count else 0 end) /max(total_trips)*100 as '6-Trips',
	sum(case when trip_count = '7-Trips' then repeat_passenger_count else 0 end) /max(total_trips)*100 as '7-Trips',
	sum(case when trip_count = '8-Trips' then repeat_passenger_count else 0 end) /max(total_trips)*100 as '8-Trips',
	sum(case when trip_count = '9-Trips' then repeat_passenger_count else 0 end) /max(total_trips)*100 as '9-Trips',
	sum(case when trip_count = '10-Trips' then repeat_passenger_count else 0 end) /max(total_trips)*100 as '10-Trips'
from trip_cte
group by city_name
;


-- Request 4
-- top and bottom 3 cities with new customers
with main_cte as(
with top_cte as (
select 
	city_id,
    sum(new_passengers) as new_passengers
from fact_passenger_summary
group by city_id
order by new_passengers desc
limit 3)
,
bottom_cte as(
select 
	city_id,
    sum(new_passengers) as new_passengers
from fact_passenger_summary
group by city_id
order by new_passengers asc
limit 3)
select 
	*,
    case when city_id is not null then "Top 3" else "Other" end as city_category
from top_cte 
union
select 
	*,
	case when city_id is not null then "Bottom 3" else "Other" end as city_category
from bottom_cte 
) 
select 
	city_name,
    new_passengers,
    city_category
from main_cte mc
	join dim_city dc
    on mc.city_id=dc.city_id
order by new_passengers desc
;


-- Request 5
-- Month with highest revenue for each city
with cte as(
select 
	city_name,
    monthname(date) as months,
    sum(fare_amount) as fare_amount
from trips_db.fact_trips ft
	join dim_city dc on ft.city_id = dc.city_id
group by ft.city_id, months
),
total_revenue as(
select 
	city_name,
    sum(fare_amount) as total_fare
    from cte
group by city_name
),
final_cte as(
select 
	c.city_name,
    c.months as highest_revenue_month,
    c.fare_amount as revenue,
    c.fare_amount/total_fare * 100 as `percentage_contribution (%)`
from cte c join total_revenue tr
		on c.city_name=tr.city_name
where c.fare_amount=(
				select 
					max(fare_amount) from cte c2
				where c2.city_name = c.city_name
                )
)
select 
	*
from final_cte
;


-- Request 6
-- Repeat Passenger Rate Analysis
with monthly_repeat as(
select 
	city_name,
    fps.city_id,
    monthname(month) as months,
    sum(repeat_passengers) as repeat_passengers,
    sum(total_passengers) as total_passengers,
    sum(repeat_passengers)/sum(total_passengers)*100 as monthly_repeat_passenger_rate
from fact_passenger_summary fps
	join dim_city dc
    on fps.city_id=dc.city_id
	group by fps.city_id, months
),
overall_repeat as(
select 
	city_id,
    sum(repeat_passengers),
    sum(total_passengers),
    sum(repeat_passengers)/sum(total_passengers)*100 as city_repeat_passenger_rate
from fact_passenger_summary
group by city_id
)
select 
	mr.city_name,
    mr.months,
    mr.total_passengers,
    mr.repeat_passengers,
    mr.monthly_repeat_passenger_rate,
    r.city_repeat_passenger_rate
from overall_repeat r
	join monthly_repeat mr
    on r.city_id=mr.city_id
;
