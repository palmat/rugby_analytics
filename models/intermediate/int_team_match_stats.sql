with resolved_home as (

select
   md.match_id,
   md.date,
   md.kickoff_time,
   md.home_team_id,
   md.home_team,
   md.home_score,
   md.away_team_id,
   md.away_team,
   md.away_score,
   tnm_home.team_id as home_team_slug,
   tnm_away.team_id as away_team_slug,
   -- priority: 1) manually confirmed override for known-bad one-off/marquee
   -- fixtures, 2) the venue's usual home club (unless neutral or it doesn't
   -- match either team in this match), 3) fall back to the source's own
   -- home_team label
   coalesce(
      mo.team_id,
      case when vm.team_id in (tnm_home.team_id, tnm_away.team_id) then vm.team_id end,
      tnm_home.team_id
   ) as resolved_home_team_slug
from {{ ref('stg_rugbyapi__match_details') }} md
left join {{ ref('ref_team_name_mapping') }} tnm_home
   on md.home_team = tnm_home.source_team_name
left join {{ ref('ref_team_name_mapping') }} tnm_away
   on md.away_team = tnm_away.source_team_name
left join {{ ref('ref_venue_team_mapping') }} vm
   on md.venue_id = vm.venue_id
left join {{ ref('ref_match_home_team_override') }} mo
   on md.match_id = mo.match_id

),

deduped as (

-- some fixtures are ingested twice under different match_ids (same date,
-- same two teams, same pair of scores), occasionally with home/away team
-- names swapped but the raw score columns left in place, which would
-- otherwise attribute the wrong score to the wrong team. Keep only the
-- self-consistent record per duplicate group (the one whose home_team
-- label already agrees with the venue-resolved true home team).
select
   * except (dup_rank)
from (
   select
      *,
      row_number() over (
         partition by
            date,
            least(home_team_slug, away_team_slug),
            greatest(home_team_slug, away_team_slug),
            least(home_score, away_score),
            greatest(home_score, away_score)
         order by
            case when home_team_slug = resolved_home_team_slug then 0 else 1 end,
            match_id
      ) as dup_rank
   from resolved_home
)
where dup_rank = 1

),

match_teams as (

select
   match_id,
   date,
   kickoff_time,
   home_team_id as team_id,
   home_team as raw_team_name,
   home_score as team_score,
   case when home_team_slug = resolved_home_team_slug then 'Y' else 'N' end as is_home,
   case when home_team_slug = resolved_home_team_slug then 'N' else 'Y' end as is_away
from deduped

union all

select
   match_id,
   date,
   kickoff_time,
   away_team_id as team_id,
   away_team as raw_team_name,
   away_score as team_score,
   case when away_team_slug = resolved_home_team_slug then 'Y' else 'N' end as is_home,
   case when away_team_slug = resolved_home_team_slug then 'N' else 'Y' end as is_away
from deduped

),

team_stats as (
select
   cast(format_date('%Y%m%d', cast(mt.date as date)) as int64) as date_key,
   mt.kickoff_time,
   mt.raw_team_name,
   mt.team_score,
   mt.is_home,
   mt.is_away,
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
from match_teams mt
left join {{ ref('stg_rugbyapi__team_stats') }} ts
   on mt.match_id = ts.match_id
  and mt.team_id = ts.team_id
)

select
   tnm.team_id,
   ts.* except (raw_team_name)
from team_stats ts
left join {{ ref('ref_team_name_mapping') }} tnm
   on ts.raw_team_name = tnm.source_team_name
