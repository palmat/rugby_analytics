select
   {{ int_surrogate_key(['ms.team_id']) }} as team_key,
   ms.* except (team_id, team_score),
   sc.team_score,
   sc.opponent_score,
   sc.is_score_swapped,
   mp.match_points,
   mp.losing_bonus_point,
   mp.try_bonus_point,
   mp.total_points
from {{ ref('int_team_match_stats') }} ms
left join {{ ref('int_team_match_scores') }} sc
   on ms.match_id = sc.match_id
   and ms.team_id = sc.team_id
left join {{ ref('int_team_match_points') }} mp
   on ms.match_id = mp.match_id
   and ms.team_id = mp.team_id
