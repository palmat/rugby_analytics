-- a team cannot earn a losing bonus point unless it lost, and total points
-- must equal the sum of its parts (max 4 + 1 try bonus = 5; a loser max 2)
select
    match_id,
    team_id,
    match_points,
    losing_bonus_point,
    try_bonus_point,
    total_points
from {{ ref('int_team_match_points') }}
where (losing_bonus_point = 1 and match_points != 0)
   or total_points != match_points + losing_bonus_point + try_bonus_point
   or total_points > 5
