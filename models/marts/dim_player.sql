with position_counts as (
    select
        player_id,
        position,
        count(*) as position_count
    from {{ ref('stg_rugbyapi__player_stats') }}
    where
        1 = 1
        and position is not null
    group by
        player_id,
        position
),

-- One name per player: the most used (latest wins a tie).
player_names as (
    select
        player_id,
        name
    from {{ ref('stg_rugbyapi__player_stats') }}
    where position is not null
    group by player_id, name
    qualify row_number() over (
        partition by player_id
        order by count(*) desc, max(game_date) desc
    ) = 1
),

-- One team per player: the team_id with the most matches (latest wins a tie).
-- team_id is stable where the source's team name varies ("Leicester" vs
-- "Leicester Tigers"), and a player who moves club keeps a single row here;
-- the per-match team lives on the fact table.
player_teams as (
    select
        player_id,
        team_id
    from {{ ref('stg_rugbyapi__player_stats') }}
    where position is not null
    group by player_id, team_id
    qualify row_number() over (
        partition by player_id
        order by count(*) desc, max(game_date) desc
    ) = 1
),

player_list as (
    select
        pn.player_id,
        pn.name,
        pt.team_id
    from player_names as pn
    inner join player_teams as pt
        on pn.player_id = pt.player_id
),

ranked_positions_pivoted as (
    select
        player_id,
        max(case when position_rank = 1 then position end) as primary_position,
        max(case when position_rank = 2 then position end) as secondary_position,
        max(case when position_rank = 3 then position end) as tertiary_position
    from (
        select
            player_id,
            position,
            row_number() over (
                partition by player_id
                order by position_count desc, position asc
            ) as position_rank
        from position_counts
        qualify position_rank <= 3
    ) as ranked_positions
    group by player_id
),

position_key as (
    select
        rpp.player_id,
        dp1.position_id as primary_position_key,
        dp2.position_id as secondary_position_key,
        dp3.position_id as tertiary_position_key
    from ranked_positions_pivoted as rpp
    left outer join {{ ref("ref_position") }} as dp1
        on rpp.primary_position = dp1.position
    left outer join {{ ref("ref_position") }} as dp2
        on rpp.secondary_position = dp2.position
    left outer join {{ ref("ref_position") }} as dp3
        on rpp.tertiary_position = dp3.position
),

player_name as (
    select
        pl.player_id,
        pl.name,
        pl.team_id as source_team_id,
        coalesce(rp.primary_position_key, -1) as primary_position_key,
        coalesce(rp.secondary_position_key, -1) as secondary_position_key,
        coalesce(rp.tertiary_position_key, -1) as tertiary_position_key
    from player_list as pl
    left outer join position_key as rp
        on pl.player_id = rp.player_id
),

dim_team_by_source_id as (
    select
        {{ int_surrogate_key(['team_id']) }} as team_key,
        source_team_id
    from {{ ref('ref_team') }}
),

final as (
    select
        {{ int_surrogate_key(['pn.player_id']) }} as player_key,
        pn.player_id,
        pn.name,
        dt.team_key,
        pn.primary_position_key,
        pn.secondary_position_key,
        pn.tertiary_position_key
    from player_name as pn
    left outer join dim_team_by_source_id as dt
        on pn.source_team_id = dt.source_team_id
)

select *
from final
