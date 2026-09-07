select
    position_id,
    position,
    position_description,
    position_group,
    position_unit,
    shirt_number
from {{ ref('ref_position')}}