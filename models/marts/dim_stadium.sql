select
    row_number() over (order by stadium_id) as stadium_key,
    *
from {{ ref('ref_stadium')}}
