{% set losing_bonus_margin = 7 %}

with team_matches as (

    select
        match_id,
        home_team as team_name,
        home_team_id as team_id,
        home_score as team_score,
        away_score as opponent_score
    from {{ ref('stg_rugbyapi__match_details') }}

    union all

    select
        match_id,
        away_team as team_name,
        away_team_id as team_id,
        away_score as team_score,
        home_score as opponent_score
    from {{ ref('stg_rugbyapi__match_details') }}

),

match_tries as (
select
  match_id,
  team_id,
  team as team_name,
  ifnull(penalty_tries,0)+ifnull(tries,0) as total_tries
from {{ref('stg_rugbyapi__team_stats')}}   
),

final as (

    select
        tm.match_id,
        tm.team_name,
        tnm.team_id,
        case
            when tm.team_score is null or tm.opponent_score is null then null
            when tm.team_score > tm.opponent_score then 4
            when tm.team_score = tm.opponent_score then 2
            else 0
        end as match_points,
        case
            when tm.team_score < tm.opponent_score
             and tm.opponent_score - tm.team_score <= {{ losing_bonus_margin }}
            then 1
            else 0
        end as losing_bonus_point,
        case 
            when mt.total_tries >= 4 then 1
            else 0
        end as try_bonus_point
    from team_matches tm
    left join match_tries mt
        on tm.match_id = mt.match_id
        and tm.team_id = mt.team_id
    left join {{ ref('ref_team_name_mapping') }} tnm
        on tm.team_name = tnm.source_team_name
    -- where team_score is not null and opponent_score is not null
)

select
    match_id,
    team_name,
    team_id,
    match_points,
    try_bonus_point,
    losing_bonus_point,
    match_points + losing_bonus_point + try_bonus_point as total_points
from final
