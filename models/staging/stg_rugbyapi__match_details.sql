with source as 
(

    select * from {{ source('rugbyapi', 'player_stats') }}

)

select * from source
