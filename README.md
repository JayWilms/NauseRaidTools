# Nause Raid Tools

Raid loot tools for WoW: Forever. Previously Sanguine Loot Tools.

**Current testing build: 0.12.0-alpha.84**, protocol 19. Includes **Nause Soft Reserve 0.1.0-experimental.21**. This is an alpha pre-release; multiplayer trade and recovery checks are still in progress.

## Download and install

Download [the alpha.84 install ZIP](https://github.com/JayWilms/NauseRaidTools/releases/tag/v0.12.0-alpha.84), or use the [repository copy](dist/NauseRaidTools-0.12.0-alpha.84-install.zip).

1. Exit World of Warcraft.
2. Remove the old SanguineLootTools or SanguineLootCouncil addon folder, if installed.
3. Extract both `NauseRaidTools` and `NauseSoftReserve` into `Interface/AddOns`, replacing previous copies. Each folder must directly contain its matching `.toc` file.
4. Enable Nause Raid Tools. Enable Nause Soft Reserve to use the experimental SoftRes system.
5. For SoftRes item browsing, enable AtlasLoot Forever and its Dungeons and Raids module, or a compatible ItemDB. These separate addons are not bundled.

Use the same build on everyone participating in a session. Nause uses its own saved data; old Sanguine settings are not migrated.

## SoftRes interface

Setup uses level-range and dungeon/raid dropdowns with multiple selections. AtlasLoot recommended ranges take priority; the entry-level requirement is kept separate from the recommended range.

Reservations uses My reserves, All reserves, Search results and instance/boss navigation, with a scrolling item list, reserve totals, item-type details and visible remaining slots. Your selections stay visible until Submit. Hover tooltips are disabled in Reservations.

Awards uses a scrolling table with item icons, separate columns, Pending/Delivered/All filters and a selected-item delivery panel. Only relevant delivery actions are enabled. Correction controls stay separate. Award confirmation shows the item name and colour. Rolls uses a scrolling results list while preserving SR/MS/OS priority and leader/tie/invalid highlights.

## Test Modes

Open Settings > Advanced > Test Modes. Matching Start/End buttons for Loot Council and SoftRes choose solo or group testing automatically. SoftRes first asks for dungeons/raids, 1-6 reserves and a scenario. Enable AtlasLoot Forever with Dungeons and Raids, or compatible ItemDB, for content selection.

Scenarios: Normal run, Tied rolls, No valid rolls, Stacked reserves, Pending delivery and Import examples. Scripted scenarios seed results; Normal group tests use native player rolls. Solo mode provides 20 players. Ten simulated loot copies come from the selected content. Examples exercise the actual Softres.it import preview and validation and are never applied automatically.

Use `/nrt softres test` or `/nrtsr test` to start. The group leader chooses content and confirms; participants can request to join. `/nrt leave-test` exits locally, while the leader ending a shared test stops it for everyone. Restarting opens setup again. Real bags, trades and saved SR sessions/history remain isolated. All participants need this build. Real trade and disconnect/recovery testing remain required.

Validation: all 28 automated suites passed, including virtual-list checks through the full 800-roll log and extracted installation ZIP checks. Native in-game visual validation is still required.

## Version Check

Open Settings > Advanced > Version Check or `/nrt versions`. This is available to every role without an active loot session. Outside a group it shows only your installed NRT and SoftRes versions and sends no requests. In a party or raid it can compare members' installed versions. It does not query guild members or check GitHub for updates. No reply is unconfirmed, not proof the addon is missing.

Detailed Pre-Raid Loot Check remains restricted to the Raid Leader and Master Looter. `/nrt check` opens the independent Version Check for other players.

## Loot council

`/nrt` opens the launcher. Settings > Session > Set Up Raid guides roles, council, response choices and loot handling. Loot shows the next action for collected items; Timer shows detailed trade countdowns. Voting includes candidate history and gear comparison. Guild Member Help explains personal response colours and window settings.

`/nrt test` starts the existing council simulation; `/nrt leave-test` exits it. This is separate from a normal SoftRes session.

## Soft Reserve

- `/nrt softres`: raid leader setup and session overview.
- `/nrtsr`: player reservations; for the host, opens setup.
- `/nrt results`: roll results and award controls.
- `/nrt loot` and `/nrt timer`: collected loot and delivery timers.

Choose content and 1-6 shared reserves per player, accept submissions, then lock reservations. Start rolling from collected loot or enter an item in Results. SR and MS use `/roll 100`; OS uses `/roll 99`. Valid reserved rolls have priority over MS and OS. An SR award consumes one reserve after confirmation. Awards and physical delivery remain separate.

The updated UI shares Overview, Reservations, Rolls and Awards navigation. Overview has submission totals, player filters and a scrollable roster. The browser has item tooltips, dropdown filters, explicit + / - controls and draft status. Roll actions follow the current stage. Council and SoftRes sessions cannot run simultaneously.

`/nrtsr sync` requests the active host state. `/nrtsr resume` restores the original host's compatible saved session and cancels an interrupted roll. This is separate from council takeover; automatic SoftRes host takeover is not implemented.

## Testing status

All 28 automated suites passed. The finished ZIP also passed extraction, addon manifest, slash command and SoftRes integration checks. Simulations include multiplayer synchronisation and delivery scenarios; they do not establish live game reliability.

The tester confirmed the basic reserve, roll, winner confirmation and reserve-consumption flow in game on alpha.77. Alpha.78 UI spacing, real trades, multiplayer reconnects and council recovery still need in-game review. See [TESTING.md](TESTING.md).

## Development

Python with Lupa is required for the automated checks:

```text
python -m pip install -r qa/requirements.txt
python qa/run_checks.py
```

`python tools/build_install.py` creates the two-addon install ZIP under `outputs/`. Build only when a release is requested.

See the [main addon notes](NauseRaidTools/README.txt), [SoftRes guide](NauseSoftReserve/README.txt), and [licence](NauseRaidTools/LICENSE.txt). Third-party bundled libraries retain their own licences. Historical installers remain in `dist`.
