with player_list as (
    select distinct player_id, name, team
    from {{ ref('stg_rugbyapi__player_stats') }}
)

select * from player_list