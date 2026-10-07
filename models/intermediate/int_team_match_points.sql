with match_points as (
select
    match_id,
    home_team,
    home_team_id,
    away_team,
    away_team_id,
    case when ifnull(md.home_score,0) > ifnull(md.away_score,0) then 4 else 0 end as hmp,
    case when ifnull(md.away_score,0) > ifnull(md.home_score,0) then 4 else 0 end as amp,
    case when ifnull(md.home_score,0) = ifnull(md.away_score,0) then 2 else 0 end as dmp,
    case when ifnull(md.away_score,0) > ifnull(md.home_score,0) and (ifnull(md.away_score,0) - ifnull(md.home_score,0)) <= 7 then 1 else 0 end as hlbp,
    case when ifnull(md.home_score,0) > ifnull(md.away_score,0) and (ifnull(md.home_score,0) - ifnull(md.away_score,0)) <= 7 then 1 else 0 end as albp
from {{ref('stg_rugbyapi__match_details')}} md
),

home_team_points as (
select 
    match_id,
    home_team,
    home_team_id,
    ifnull(hmp,0)+ifnull(dmp,0)+ifnull(hlbp,0) as home_team_match_points
from match_points
),

away_team_points as (
select 
    match_id,
    away_team,
    away_team_id,
    ifnull(amp,0)+ifnull(dmp,0)+ifnull(albp,0) as away_team_match_points
from match_points
),


final as (
select
    htp.match_id as match_id,
    htp.home_team as team_name,
    htp.home_team_id as team_id,
    htp.home_team_match_points as match_points
from home_team_points htp
union all
select
    atp.match_id as match_id,
    atp.away_team as team_name,
    atp.away_team_id as team_id,
    atp.away_team_match_points as match_points
from away_team_points atp
)

select * from final
