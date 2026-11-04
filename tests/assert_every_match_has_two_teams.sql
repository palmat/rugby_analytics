-- each match should appear exactly twice in the fact table (home and away)
select
    match_id,
    count(*) as team_rows
from {{ ref('fact_team_match') }}
group by match_id
having count(*) != 2
