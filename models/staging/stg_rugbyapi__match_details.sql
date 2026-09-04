select
     *
     
from {{ source('rugbyapi', 'match_details') }}
