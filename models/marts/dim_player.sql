with position_counts as (
  select
     player_id,
     name,
     team,
     position,
     count(*) as position_count
  from {{ ref('stg_rugbyapi__player_stats') }}
  where 1=1
    and position is not null
  --   and lower(position) not like '%sub%'
  --   and team like '%orthamp%'
  group by
     player_id,
     name,
     team,
     position
),

player_list as (
  select distinct player_id, name, team
  from position_counts
),

ranked_positions_pivoted as (
  select
     player_id,
     max(case when position_rank = 1 then position end) as primary_position,
     max(case when position_rank = 2 then position end) as secondary_position,
     max(case when position_rank = 3 then position end) as tertiary_position
  from (
    select
       player_id,
       position,
       row_number() over (
         partition by player_id
         order by position_count desc, position
       ) as position_rank
    from position_counts
    qualify position_rank <= 3
  )
  group by player_id
),

position_key as (
  select
     rpp.player_id,
     dp1.position_id as primary_position_key,
     dp2.position_id as secondary_position_key,
     dp3.position_id as tertiary_position_key
   from ranked_positions_pivoted rpp
   left outer join {{ ref("ref_position") }} dp1
       on rpp.primary_position = dp1.position
   left outer join {{ ref("ref_position") }} dp2
       on rpp.secondary_position = dp2.position
   left outer join {{ ref("ref_position") }} dp3
       on rpp.tertiary_position = dp3.position
),

player_name as (
  select
      pl.player_id,
      pl.name,
      lower(pl.team) as team,
      coalesce(rp.primary_position_key, -1) as primary_position_key,
      coalesce(rp.secondary_position_key, -1) as secondary_position_key,
      coalesce(rp.tertiary_position_key, -1) as tertiary_position_key
  from player_list pl
  left outer join position_key rp
      on pl.player_id = rp.player_id
),

dim_team_lower as (
  select
     {{ int_surrogate_key(['team_id']) }} as team_key,
     lower({{ team_name_short('team_name') }}) as team_name_short_lower
  from {{ ref('ref_team') }}
),

final as (
   select
     {{ int_surrogate_key(['pn.player_id']) }} as player_key,
     pn.player_id,
     pn.name,
     dt.team_key,
     pn.primary_position_key,
     pn.secondary_position_key,
     pn.tertiary_position_key
   from player_name pn
   left outer join dim_team_lower dt
       on pn.team = dt.team_name_short_lower
)

select *
from final