select
   {{ int_surrogate_key(['team_id']) }} as team_key,
   * except (team_id)
from {{ ref('int_team_match_stats') }}
