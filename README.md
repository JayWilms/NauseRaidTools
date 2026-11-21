# Nause Raid Tools

Loot Council, SoftRes, loot tracking, trade timers, raid checks and assignments for WoW: Forever.

**Current testing build: 0.12.0-alpha.108**, protocol 19. SoftRes is now bundled: one addon folder and one version number.

## Download and install

[Download alpha.108](https://github.com/JayWilms/NauseRaidTools/raw/refs/heads/main/dist/NauseRaidTools-0.12.0-alpha.108-install.zip)

1. Exit World of Warcraft.
2. Remove the old `NauseRaidTools` and `NauseSoftReserve` addon folders. Keep your SavedVariables files.
3. Extract **only `NauseRaidTools`** into `Interface/AddOns`. Its `.toc` file must be directly inside that folder.
4. Enable Nause Raid Tools. Everyone participating should use the same build.

Only the SoftRes host needs AtlasLoot Forever with Dungeons and Raids, or a compatible ItemDB, for the item catalogue. Members receive the selected catalogue from the host.

LC settings remain in NauseRaidToolsDB. SoftRes retains NauseSoftReserveDB and its data format. WoW does not automatically transfer the old companion's SavedVariables file; retain it if historical data needs a one-time manual transfer.

## Commands

| Command | Opens |
|---|---|
| `/nrt` | Main menu |
| `/nrt settings` | Settings |
| `/nrt assignments` | My Assignments |
| `/nrt raidcheck` | Raid Check |
| `/nrt responses` | Loot responses |
| `/nrt loot` | Loot window |
| `/nrt timer` | Trade timers |
| `/nrt softres` | SoftRes window |
| `/nrt history` | Loot history |
| `/nrt version` | Version check |
| `/nrt help` | Command help |

Session actions use buttons in their windows. Tests, resynchronisation and diagnostics are in Settings > Advanced. Recovery is in Session settings or SoftRes setup. Leaders open the assignment editor from My Assignments > Assignments or Settings > Raid Tools > Assignments.

Old aliases and slash action subcommands have been removed. SoftRes reservation chat messages remain `!sr`, `!mysr` and `!removesr`. Item names, links and IDs are supported; repeat items or use `x2`. SR/MS uses `/roll 100`; OS uses `/roll 99`.

## Features and testing

Loot and Response/Voting item lists use scrollbars. My Assignments has compact icon-and-text rows, tank names for healers, grouped target markers and boss overrides. Assigned buff reminders show class-coloured names with out-of-combat click-to-buff. Buffing remains raid-wide.

Tests are available through Settings > Advanced. Solo tests use simulated loot and players; group tests share with real members. Assignment Test Raid uses the ten Molten Core bosses. Test activity is isolated from live loot/history.

All **34 automated suites passed**, including unified addon loading, simplified commands, shared LC/SR sessions, catalogue sync, assignments, recovery and buff reminders. The installation ZIP was extracted and checked separately. Native in-game testing remains necessary, especially real trades, recovery and click-to-buff.

## Development

```text
python -m pip install -r qa/requirements.txt
python qa/run_checks.py
```

`python tools/build_install.py` creates the one-addon install ZIP under `outputs/`. Build only when requested.

[Addon notes](NauseRaidTools/README.txt) · [SoftRes guide](NauseRaidTools/SoftRes/README.txt) · [Licence](NauseRaidTools/LICENSE.txt). Bundled libraries retain their licences. Historical installers remain in `dist`.
