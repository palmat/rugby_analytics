with source as 
(

    select * from {{ source('rugbyapi', 'team_stats') }}

)

select * from source
