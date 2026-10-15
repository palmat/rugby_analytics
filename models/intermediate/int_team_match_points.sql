{% set losing_bonus_margin = 7 %}

with team_matches as (

    -- deduped, score-corrected, one row per team per match (team_id is the slug)
    select
        match_id,
        team_id,
        team_score,
        opponent_score
    from {{ ref('int_team_match_scores') }}

),

match_tries as (

    select
        match_id,
        team_id,
        ifnull(penalty_tries, 0) + ifnull(tries, 0) as total_tries
    from {{ ref('int_team_match_stats') }}

),

final as (

    select
        tm.match_id,
        tm.team_id,
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
    -- where tm.team_score is not null and tm.opponent_score is not null

)

select
    match_id,
    team_id,
    match_points,
    try_bonus_point,
    losing_bonus_point,
    match_points + losing_bonus_point + try_bonus_point as total_points
from final
