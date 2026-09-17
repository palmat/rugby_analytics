with stadium_keys as (
  select
      {{ int_surrogate_key(['stadium_id']) }} as stadium_key,
      club_name,
      venue_type
  from {{ ref('ref_stadium') }}
)

select
    {{ int_surrogate_key(['t.team_id']) }} as team_key,
    t.team_id,
    t.team_name,
    {{ team_name_short('t.team_name') }} as team_name_short,
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
    sk.stadium_key as home_stadium_key
from {{ ref('ref_team') }} t
left outer join stadium_keys sk
    on t.team_name = sk.club_name
    and sk.venue_type = 'Primary Home'
