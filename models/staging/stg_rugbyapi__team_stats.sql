select
     *
     
from {{ source('rugbyapi', 'team_stats') }}
