with source as 
(

    select * from {{ source('rugbyapi', 'match_details') }}

)

select * from source
