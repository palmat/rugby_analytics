with dates as (
select
    cast(format_date('%Y%m%d', date_day) as int64) as date_id,
    date_day,
    extract(year from date_day) as year,
    extract(quarter from date_day) as quarter,
    extract(month from date_day) as month,
    format_date('%B', date_day) as month_name,
    extract(week from date_day) as week_of_year,
    extract(dayofweek from date_day) as day_of_week,
    format_date('%A', date_day) as day_name,
    case when extract(dayofweek from date_day) in (1, 7) then true else false end as is_weekend
from unnest(generate_date_array('2025-01-01', '2026-12-31')) as date_day
),

rounds as (
select
    r.round_id,
    r.season,
    r.competition,
    r.round_type,
    cast(format_date('%Y%m%d', date_day) as int64) as date_id,
    date_day
from {{ ref('ref_rounds')}} as r
cross join unnest(generate_date_array(r.start_date, r.end_date)) as date_day
), 

final as (
select
    d.date_id,
    d.date_day,
    d.year,
    d.quarter,
    d.month,
    d.month_name,
    d.week_of_year,
    d.day_of_week,
    d.day_name,
    d.is_weekend,
    r.round_id,
    r.season,
    r.competition,
    r.round_type
from dates as d
left join rounds as r
on d.date_id = r.date_id
)

select * from final



