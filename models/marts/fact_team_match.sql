with team_stats as (
select
   md.date,
   md.kickoff_time,
   case when ts.team_id = md.home_team_id then md.home_team else md.away_team end as raw_team_name,
   case when ts.team_id = md.home_team_id then md.home_score else md.away_score end as team_score,
   case when ts.team_id = md.home_team_id then 'Y' else 'N' end as is_home,
   case when ts.team_id = md.home_team_id then 'N' else 'Y' end as is_away,
   ts.tries,
   ts.penalty_tries,
   ts.conversions,
   ts.penalty_goals,
   ts.drop_goals,
   ts.red_cards,
   ts.yellow_cards,
   ts.`22m_entries`,
   ts.`22m_conversion`,
   ts.line_breaks,
   ts.carries,
   ts.kicks,
   ts.post_contact_metres,
   ts.dominant_tackles,
   ts.tackles_made,
   ts.tackles_missed,
   ts.turnovers_won,
   ts.tackle_turnover,
   ts.tackle_offload_allowed,
   ts.ruck_speed_0_3_pct,
   ts.ruck_speed_3_6_pct,
   ts.ruck_speed_6_plus_pct,
   ts.rucks_won,
   ts.clean_breaks,
   ts.lineouts_won,
   ts.passes,
   ts.penalties_conceded,
   ts.possession,
   ts.total_scrums,
   ts.scrums_won,
   ts.tackles,
   ts.total_lineouts,
   ts.metres_carried,
   ts.try_assists,
   ts.turnovers,
   ts.offloads
from {{ ref('stg_rugbyapi__match_details') }} md
left join {{ ref('stg_rugbyapi__team_stats') }} ts
   on md.match_id = ts.match_id
where 1=1
--  and md.match_id = 'be0d202b'
), 

final as (
select
   {{ int_surrogate_key(['tnm.team_id']) }} as team_key,
   ts.* except (raw_team_name)
from team_stats ts
left join {{ ref('ref_team_name_mapping') }} tnm
   on ts.raw_team_name = tnm.source_team_name
)

select * from final
