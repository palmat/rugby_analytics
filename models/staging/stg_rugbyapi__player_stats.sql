with source as (

    select * from {{ source('rugbyapi', 'player_stats') }}

),

renamed as (

    select
        -- identifiers & context
        player_id,
        name,
        team,
        team_id,
        team_vs,
        team_vs_id,
        position,
        match_id,
        game_date,  -- kept as integer (YYYYMMDD) to match dim_date.date_id
        competition,
        competition_id,

        -- physical attributes
        weight_kg,
        height_cm,

        -- attacking stats
        carries,
        carries_per_minute,
        metres_carried,
        meters_run,
        runs,
        line_breaks,
        clean_breaks,
        defenders_beaten,
        offloads,
        offload,
        passes,
        try_assists,
        tries,
        points,

        -- kicking stats
        kicks,
        kicks_from_hand,
        kick_percent_success,
        conversion_goals,
        penalty_goals,
        drop_goals_converted,

        -- defensive stats
        tackles_made,
        tackles_completed,
        tackles_missed,
        missed_tackles,
        dominant_tackles,
        total_tackles_per_minute,
        tackles,

        -- set piece & breakdown
        lineouts_won,
        lineout_won_steal,
        total_lineouts,
        mauls_won,
        rucks_won,
        ruck_turnovers,
        turnovers_won,
        turnovers_lost,
        turnovers_conceded,
        turnover_knock_on,

        -- discipline
        penalties_conceded,
        total_free_kicks_conceded,
        red_cards,
        yellow_cards,

        -- unclear/internal source fields - kept as-is, not renamed, until we
        -- understand what they represent
        want_team,
        want_teamvs

        -- player_name is dropped here: it is always null in the source,
        -- `name` is the real name field

    from source

    -- Known source data-quality issue: player_id 5fbe8077 conflates two
    -- different real players (confirmed by simultaneous same-day
    -- appearances for two different clubs - see e.g. match bb898940 vs
    -- cd2add57, both dated 2025-09-28). Mat has confirmed Sam Grahamslaw
    -- did not play for Northampton in the 25/26 season, so these
    -- specific Northampton-tagged rows for this player_id are factually
    -- wrong and are excluded here rather than in raw (which gets
    -- truncated and reloaded on every extraction run).
    where not (
        player_id = '5fbe8077'
        and team_id = '30ca1553'
    )

)

select * from renamed
