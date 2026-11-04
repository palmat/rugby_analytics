-- in a match, a win (4) must be paired with a loss (0), or two draws (2 and 2)
select
    match_id,
    sum(match_points) as pair_match_points
from {{ ref('int_team_match_points') }}
where match_points is not null
group by match_id
having sum(match_points) != 4
