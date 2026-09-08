select
    row_number() over (order by team_id) as team_key,
    t.team_id,
    t.team_name,
    split(t.team_name, ' ')[offset(0)] as team_name_short,
    t.nickname,
    t.short_code,
    t.year_formed,
    t.squad_size,
    t.club_captain,
    t.mascot_name,
    t.mascot_description,
    t.home_shirt_details,
    t.away_shirt_details,
    t.third_strip_details,
    t.kit_manufacturer,
    t.main_shirt_sponsor,
    t.premiership_titles,
    t.last_premiership_title,
    t.european_champions_cup_titles,
    t.social_media_handle,
    t.official_website,
    t.chairperson,
    t.director_of_rugby,
    t.head_coach,
    s.stadium_key as home_stadium_key
from {{ ref('ref_team')}} t
left outer join {{ ref('dim_stadium')}} s
    on t.team_name = s.club_name
    and s.venue_type = 'Primary Home'
