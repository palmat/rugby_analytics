select
   {{ int_surrogate_key(['ms.team_id']) }} as team_key,
   ms.* except (team_id),
   mp.match_points,
   mp.losing_bonus_point,
   mp.try_bonus_point,
   mp.total_points
from {{ ref('int_team_match_stats') }} ms
left join {{ ref('int_team_match_points') }} mp
   on ms.match_id = mp.match_id
   and ms.team_id = mp.team_id

