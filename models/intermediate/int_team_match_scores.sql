{% set score_tolerance = 2 %}

-- One row per team per match (deduped, via int_team_match_stats), with the
-- score the source reported, the score implied by the team's stats, and a
-- corrected score for use downstream. team_id is the team slug.

with base as (

    select
        match_id,
        team_id,
        team_score as reported_score,
        -- null when the match has no team_stats row at all
        if(
            tries is null,
            null,
            ifnull(tries, 0) * 5
              + ifnull(conversions, 0) * 2
              + ifnull(penalty_goals, 0) * 3
              + ifnull(drop_goals, 0) * 3
        ) as derived_score
    from {{ ref('int_team_match_stats') }}

),

paired as (

    select
        b.match_id,
        b.team_id,
        b.reported_score,
        b.derived_score,
        o.reported_score as opponent_reported_score,
        o.derived_score as opponent_derived_score
    from base b
    join base o
        on b.match_id = o.match_id
        and b.team_id != o.team_id

),

flagged as (

    select
        *,
        -- swapped = this team's reported score matches the OPPONENT's derived
        -- score (and vice versa) within tolerance, and that pairing fits
        -- better than the reported one
        ifnull(
            reported_score != opponent_reported_score
            and abs(reported_score - opponent_derived_score) <= {{ score_tolerance }}
            and abs(opponent_reported_score - derived_score) <= {{ score_tolerance }}
            and abs(reported_score - opponent_derived_score)
                + abs(opponent_reported_score - derived_score)
              < abs(reported_score - derived_score)
                + abs(opponent_reported_score - opponent_derived_score),
            false
        ) as is_score_swapped
    from paired

)

select
    match_id,
    team_id,
    reported_score,
    derived_score,
    if(is_score_swapped, opponent_reported_score, reported_score) as team_score,
    if(is_score_swapped, reported_score, opponent_reported_score) as opponent_score,
    is_score_swapped
from flagged
