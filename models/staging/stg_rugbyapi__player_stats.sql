select
     *
     
from {{ source('rugbyapi', 'player_stats') }}
