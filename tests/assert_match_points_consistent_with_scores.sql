-- match points must follow the corrected score: win 4, draw 2, loss 0
select
    sc.match_id,
    sc.team_id,
    sc.team_score,
    sc.opponent_score,
    mp.match_points
from {{ ref('int_team_match_scores') }} sc
join {{ ref('int_team_match_points') }} mp
    on sc.match_id = mp.match_id
    and sc.team_id = mp.team_id
where sc.team_score is not null
  and sc.opponent_score is not null
  and mp.match_points != case
        when sc.team_score > sc.opponent_score then 4
        when sc.team_score = sc.opponent_score then 2
        else 0
      end
