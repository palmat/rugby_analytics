"""
extract_rugbypy_to_bigquery.py

WHAT THIS SCRIPT DOES
----------------------
Pulls Gallagher Premiership 2025/26 season data from the `rugbypy` data
source and loads it into the `raw` BigQuery dataset, ready for dbt to
pick up in the staging layer.

We deliberately scope this first version to ONE competition and ONE
season (rather than all ~6,000 matches / 8,000 players in the dataset)
so it's fast to run, easy to debug, and easy to read end-to-end while
you're still getting comfortable with Python. Once this works, widening
it to more seasons/competitions is mostly just changing the SEASON_START
/ SEASON_END / COMPETITION_ID constants below and re-running.

WHY WE DON'T USE THE `rugbypy` PACKAGE DIRECTLY
-------------------------------------------------
The version of `rugbypy` on PyPI (2.0.0) points at an old version of the
underlying data files and returns 404 errors. The data source itself has
moved on to a "v3" layout (confirmed by looking at the v3.0.0 tag on the
rugbypy GitHub repo, which isn't published to PyPI yet). Rather than
fight a broken pip package, this script talks to the same v3 parquet
files directly using `pandas.read_parquet()` over HTTPS - which is all
the rugbypy functions do under the hood anyway.

CONCEPTS USED (a few notes since Python is new to you)
---------------------------------------------------------
- A "DataFrame" (from the pandas library) is basically a spreadsheet
  living in memory: rows and columns, with helpers for filtering,
  joining, and summarising.
- `requests.get(url)` fetches a file over the internet, the same way a
  browser would - we then hand the raw bytes to pandas to parse.
- A Python `set` is a list with no duplicates, and fast "is this in
  here?" checks - handy for de-duplicating IDs.
- `concurrent.futures.ThreadPoolExecutor` lets us fetch several files
  from the internet AT THE SAME TIME instead of one after another -
  like sending 20 people to the library instead of one. We use it
  because this step alone means over 2,000 small file downloads.
- Functions (`def some_name(...):`) are just named, reusable blocks of
  steps - each one below does one clear job, and `main()` at the bottom
  calls them in order.

DATA QUALITY NOTES (things we found exploring the source - not bugs in
this script, just how the source data is)
---------------------------------------------------------------------------
- Team names are inconsistent across rows for the same club (e.g.
  "Northampton" vs "Northampton Saints", "Bath" vs "Bath Rugby"), and
  the SAME club can even have more than one team_id. We keep team_id as
  the join key everywhere and leave name-tidying to a dbt staging model
  - that's exactly the kind of cleaning dbt's staging layer is for.
- The per-team stats file only holds a small number of matches per team
  overall (we only got ~6 of this season's games back per team when we
  filtered a team's file down to just our season), whereas the
  per-player stats file holds a player's FULL history, which we then
  filter down to this season. So team-level stats will be sparser than
  player-level stats in the `raw` layer - that's a genuine limitation
  of the source, not something to "fix" here. It's worth noting in the
  dbt project README.
- IMPORTANT: because of the point above, we do NOT use the season-
  filtered team_stats rows to work out who played (that missed key
  players like Alex Mitchell, Henry Pollock and Fin Smith entirely,
  since none of them happened to feature in the small in-season slice
  of team_stats we kept). Instead, get_squad_player_ids() below reads
  the `players` column from each team's FULL history file (all ~30
  rows ever recorded for that team, not just this season) to build a
  much more complete list of who has ever turned out for these 10
  clubs - then we fetch each of those individually and filter their
  own stats down to this season. This costs nothing extra, since we
  were downloading each team's full file anyway before filtering it.
- A handful of player IDs (about 1 in 6 for this season) return a 404 -
  no stats file exists for them (likely uncapped players, or players
  who never got minutes recorded). We skip those and log how many.

REQUIREMENTS
------------
Run this inside your existing project virtual environment:
    source .venv/bin/activate
    pip install pandas pyarrow requests google-cloud-bigquery

USAGE
-----
    python scripts/extract_rugbypy_to_bigquery.py
"""

import concurrent.futures as cf
import io
import json

import pandas as pd
import requests
from google.cloud import bigquery

# ---------------------------------------------------------------------------
# CONFIG - the things you're most likely to want to change later
# ---------------------------------------------------------------------------

# Where the rugbypy data source actually lives (v3 layout). rugbypy's own
# Python functions build these same URls internally - we're just doing it
# ourselves so we're not stuck on the outdated PyPI package.
DATA_BASE = "https://raw.githubusercontent.com/seanyboi/rugbydata/main/data/v3"

# Gallagher Premiership's fixed competition_id in this data source.
COMPETITION_ID = "1b875d20"

# The 2025/26 Premiership season runs across two calendar years, so we
# select on match date rather than the source's "season" field (which is
# just the calendar year of the match, and would otherwise split the
# season in two).
SEASON_START = "2025-08-01"
SEASON_END = "2026-07-01"

# Matches your profiles.yml - keep these two in sync with dbt.
GCP_PROJECT = "rugby-analytics-507511"
BQ_DATASET = "raw"
BQ_LOCATION = "EU"
KEYFILE_PATH = "/Users/matthewpalmersmith/.dbt_keys/rugby-analytics-507511-0ac9e7fb7ff8.json"


# ---------------------------------------------------------------------------
# STEP 1: work out which matches are in scope
# ---------------------------------------------------------------------------

def get_season_matches() -> pd.DataFrame:
    """Return one row per Premiership match played in the 2025/26 season.

    The match "registry" file lists every match ever recorded, but only
    gives match_id / home_team / away_team / date - no competition, so we
    can't filter by competition directly. Instead we:
      1. Narrow down to matches in our date window (cheap - no extra
         downloads, it's one file).
      2. Fetch the full match detail file for each of those candidates
         (this is where competition_id, season, scores, venue etc. live).
      3. Keep only the rows that are actually Gallagher Premiership.
    """
    print("Fetching match registry (all matches, all competitions)...")
    registry = pd.read_parquet(
        f"{DATA_BASE}/match/match_registry.parquet", engine="pyarrow"
    )
    registry["date"] = pd.to_datetime(registry["date"])

    candidates = registry[
        (registry["date"] >= SEASON_START) & (registry["date"] <= SEASON_END)
    ]
    print(f"{len(candidates)} candidate matches in the date window - "
          f"fetching full details for each to check competition...")

    def fetch_match_details(match_id: str):
        url = f"{DATA_BASE}/match/{match_id}.parquet"
        try:
            response = requests.get(url, timeout=10)
            if response.status_code != 200:
                return None
            df = pd.read_parquet(io.BytesIO(response.content), engine="pyarrow")
            return df.iloc[0].to_dict()
        except Exception:
            return None

    details = []
    match_ids = candidates["match_id"].tolist()
    # ThreadPoolExecutor.map runs fetch_match_details for every match_id,
    # but with up to 20 requests in flight at once rather than one at a time.
    with cf.ThreadPoolExecutor(max_workers=20) as pool:
        for result in pool.map(fetch_match_details, match_ids):
            if result is not None:
                details.append(result)

    all_details = pd.DataFrame(details)
    season_matches = all_details[all_details["competition_id"] == COMPETITION_ID].copy()
    season_matches["date"] = pd.to_datetime(season_matches["date"])
    season_matches = season_matches[
        (season_matches["date"] >= SEASON_START) & (season_matches["date"] <= SEASON_END)
    ]

    print(f"Found {len(season_matches)} Gallagher Premiership matches in the "
          f"2025/26 season ({season_matches['date'].min().date()} to "
          f"{season_matches['date'].max().date()}).")
    return season_matches


# ---------------------------------------------------------------------------
# STEP 2: team-level stats for the teams in those matches
# ---------------------------------------------------------------------------

def get_team_stats(season_matches: pd.DataFrame) -> pd.DataFrame:
    """Return team-level match stats, filtered down to our season's matches."""
    team_ids = pd.unique(season_matches[["home_team_id", "away_team_id"]].values.ravel())
    match_ids = set(season_matches["match_id"])

    print(f"Fetching team stats for {len(team_ids)} teams...")
    rows = []
    for team_id in team_ids:
        url = f"https://github.com/seanyboi/rugbydata/blob/main/data/v3/team/{team_id}.parquet?raw=true"
        try:
            team_df = pd.read_parquet(url, engine="pyarrow")
        except Exception as e:
            print(f"  Could not fetch team {team_id}: {e}")
            continue
        rows.append(team_df[team_df["match_id"].isin(match_ids)])

    team_stats = pd.concat(rows, ignore_index=True) if rows else pd.DataFrame()

    # The `players` column holds a Python list per row (the matchday squad).
    # BigQuery doesn't take native Python lists well via a simple load, so we
    # store it as a JSON string instead - easy for a later dbt model to
    # unpack with a JSON function if needed.
    if "players" in team_stats.columns:
        team_stats["players"] = team_stats["players"].apply(
            lambda squad: json.dumps(list(squad)) if squad is not None else None
        )

    print(f"Got {len(team_stats)} team-match rows "
          f"(note: the source only keeps a recent rolling window per team, "
          f"so this will be noticeably smaller than 2 x number of matches).")
    return team_stats


# ---------------------------------------------------------------------------
# STEP 3: work out the full roster, then fetch player-level stats
# ---------------------------------------------------------------------------

def get_squad_player_ids(season_matches: pd.DataFrame) -> set:
    """Return every player_id who has ever appeared in a squad for one of
    our 10 teams - NOT limited to this season.

    We can't ask "who played in match X?" directly (match_details doesn't
    say), so the `players` column on each team's stats file is our only
    way in. That file is short (each team only has ~30 rows, ever), so we
    read every row's squad list rather than just the handful that overlap
    our season - a squad list from a 2023 game still tells us a player is
    associated with this club, which is exactly what we need to know
    which player files to go and fetch next.
    """
    team_ids = pd.unique(season_matches[["home_team_id", "away_team_id"]].values.ravel())

    print(f"Building a full roster for {len(team_ids)} teams (reading each "
          f"team's entire history, not just this season)...")
    player_ids = set()
    for team_id in team_ids:
        url = f"https://github.com/seanyboi/rugbydata/blob/main/data/v3/team/{team_id}.parquet?raw=true"
        try:
            team_df = pd.read_parquet(url, engine="pyarrow")
        except Exception as e:
            print(f"  Could not fetch team {team_id}: {e}")
            continue
        for squad in team_df["players"].dropna():
            player_ids.update(squad)

    print(f"Found {len(player_ids)} distinct players across these teams' full history.")
    return player_ids


def get_player_stats(season_matches: pd.DataFrame, player_ids: set) -> pd.DataFrame:
    """Return player-level match stats, filtered down to our season's matches."""
    match_ids = set(season_matches["match_id"])

    print(f"Fetching stats for {len(player_ids)} distinct players "
          f"(each player's file covers their whole career, so we filter "
          f"down to this season's matches afterwards)...")

    def fetch_player(player_id: str):
        url = f"{DATA_BASE}/player/{player_id}.parquet"
        try:
            response = requests.get(url, timeout=10)
            if response.status_code != 200:
                return None
            df = pd.read_parquet(io.BytesIO(response.content), engine="pyarrow")
            return df[df["match_id"].isin(match_ids)]
        except Exception:
            return None

    results = []
    missing = 0
    with cf.ThreadPoolExecutor(max_workers=20) as pool:
        for result in pool.map(fetch_player, player_ids):
            if result is None:
                missing += 1
            elif len(result) > 0:
                results.append(result)

    player_stats = pd.concat(results, ignore_index=True) if results else pd.DataFrame()
    print(f"Got {len(player_stats)} player-match rows across "
          f"{player_stats['player_id'].nunique() if len(player_stats) else 0} players "
          f"({missing} player IDs had no stats file available and were skipped).")
    return player_stats


# ---------------------------------------------------------------------------
# STEP 4: load everything into BigQuery
# ---------------------------------------------------------------------------

def load_to_bigquery(df: pd.DataFrame, table_name: str, client: bigquery.Client) -> None:
    """Replace the contents of raw.<table_name> with this DataFrame."""
    if df.empty:
        print(f"  Skipping {table_name} - no rows to load.")
        return

    table_id = f"{GCP_PROJECT}.{BQ_DATASET}.{table_name}"
    job_config = bigquery.LoadJobConfig(
        # WRITE_TRUNCATE means "replace the table" rather than append - the
        # right choice here since we want a clean re-run each time, not
        # ever-growing duplicates from running this script twice.
        write_disposition="WRITE_TRUNCATE",
        autodetect=True,
    )
    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()  # Waits for the load to finish before moving on.
    print(f"  Loaded {len(df)} rows into {table_id}")


# ---------------------------------------------------------------------------
# MAIN - runs all the steps above in order
# ---------------------------------------------------------------------------

def main():
    season_matches = get_season_matches()
    team_stats = get_team_stats(season_matches)
    player_ids = get_squad_player_ids(season_matches)
    player_stats = get_player_stats(season_matches, player_ids)

    print("\nLoading to BigQuery...")
    client = bigquery.Client.from_service_account_json(KEYFILE_PATH)

    load_to_bigquery(season_matches, "match_details", client)
    load_to_bigquery(team_stats, "team_stats", client)
    load_to_bigquery(player_stats, "player_stats", client)

    print("\nDone. Check the `raw` dataset in BigQuery for match_details, "
          "team_stats and player_stats tables.")


if __name__ == "__main__":
    main()
