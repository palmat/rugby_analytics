select
    {{ int_surrogate_key(['stadium_id']) }} as stadium_key,
    *
from {{ ref('ref_stadium')}}
