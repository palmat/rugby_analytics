-- exactly one team per match should be flagged as home
select
    match_id,
    countif(is_home = 'Y') as home_teams
from {{ ref('int_team_match_stats') }}
group by match_id
having countif(is_home = 'Y') != 1
