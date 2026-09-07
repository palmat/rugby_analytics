select
    t.*,
    s.stadium_key as home_stadium_key
from {{ ref('ref_team')}} t
left outer join {{ ref('dim_stadium')}} s
    on t.team_name = s.club_name
    and s.venue_type = 'Primary Home'
