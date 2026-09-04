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