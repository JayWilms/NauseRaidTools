Nause Soft Reserve - 0.1.0-experimental.21

Requires NauseRaidTools. Install the NauseRaidTools and NauseSoftReserve folders
alongside each other inside Interface/AddOns. Everyone using the SR interface
needs both addons. Start fresh sessions with the same versions on each client.

SOURCE DATA
Enable AtlasLoot Forever, including Dungeons and Raids, or compatible ItemDB.
NRT reads installed loot sources for instance/boss selection and reservation
validation. Names and links are resolved from the game when using AtlasLoot.
Unavailable item names retry when the game finishes loading them.
An unavailable catalogue is reported in Setup and the reservation browser.

START
/nrt softres opens setup for the raid leader. Choose instances and 1-6 shared
reserves per player. Confirm to start. Opening setup alone starts nothing.
/nrtsr opens setup for the leader and My Reservations for other raiders.
/nrt results opens the leader's roll results.
/nrt loot and /nrt timer use NRT's existing windows during an SR run.
Guild guided setup starts a guild council session directly. The normal
Start Session control offers the existing Guild Run / PuG Run chooser.

FLOW
Submit reservations, then lock them. Queue collected copies individually or
with Queue All. MS uses /roll 100 and OS uses /roll 99 in the same round.
Valid reservers' /100 results receive SR priority. Stacked reserves allow that
many attempts, with the best valid result counting. Ties use a tied-player
reroll. An explicit confirmation is required to award an item.
An SR award consumes one reserve. MS/OS awards consume none.
Exact GUIDs connect each collected copy, award and delivery.
Timer keeps detailed countdowns. Compact Timer shows item and countdown only.
Loot shows the next action and a badge for a pending award nearing expiry.

RECOVERY
/nrtsr sync requests the active host's state.
/nrtsr resume restores that host's saved run and cancels an interrupted roll.
The council takeover system is separate and cannot start during an SR run.
Live Forever tests of SR reconnects, source coverage and real trades remain
required. Automated transport tests use simulated clients and game APIs.

The experimental .14 chat reservation and Softres.it import functions are
retained. Chat accepts !reserve ITEM_ID [xN], !unreserve ITEM_ID [xN] and
!myreserves through the same host validation as in-game submissions.

UI UPDATE (included in alpha.78)
Overview, Reservations, Rolls and Awards share navigation and consistent sizing.
Overview includes submitted/missing totals, All/Missing/Submitted/Offline filters,
a scrollable roster, item names/icons/tooltips and class-coloured player names.
Reservations use dropdown filters, item source labels, explicit + / - controls,
slot usage and unsaved-selection status. Switching tabs preserves a draft.
Rolls shows one primary next action: Stop, Award, Tie Reroll or View Delivery.
Award corrections are collapsed until requested. Import and sync are secondary
Overview actions. Normal text is white; headings and primary actions use gold.

SOLO SOFTRES TEST (included in alpha.80)
Open Settings > Advanced > Test Modes > Start SoftRes test,
or type /nrt softres test (also /nrtsr test). No raid or ItemDB is required.
The test provides 20 simulated players, 8 item choices and 10 loot copies,
including duplicates, missing submissions and offline players. Reservations
start open. Lock them, open Loot and Queue an item. Sample players roll
automatically; MS / OS buttons generate your own local test rolls. Review
results and confirm an award, then use Awards / Trade to simulate delivery.
Window titles identify SOLO TEST. Real bags, trades, chat announcements,
network snapshots and saved SR sessions/history are not used or changed.
/nrt softres leave-test, /nrtsr leave-test or /nrt leave-test exits.
Re-running the start command resets the test. Joining a real group ends it.
This UI simulation does not verify real multiplayer synchronisation or trades.

SHARED SOFTRES TEST (included in alpha.81)
The same Start SoftRes test button and /nrt softres test command now work in
parties and raids. The group leader starts the test. Members with this update
join when the test arrives; clicking Start SoftRes test also requests to join.
Group tests use actual group members, 8 sample item choices and 10 simulated
loot copies. Submit reservations, lock, queue loot, then use MS / OS for real
/roll results. There are no simulated player rolls in shared tests.
Awards and delivery remain simulated. Real bags, trades and saved SR sessions
or history are untouched. Separate test messages keep older clients from
mistaking the test for a live run; update every participating player together.
A member's End test button leaves locally; Start rejoins. The leader's End test
stops it for everyone. Re-running the start command as leader resets the test.
Leaving the group or changing leaders ends the shared test. Solo testing still
works outside a group. Test Modes is now the first section in Advanced.
Automated party/raid simulations passed; native group testing remains required.

OVERVIEW SOURCE UPDATE (included in alpha.82)
Import Softres.it and Refresh session are directly visible beside Lock
reservations and My reservations. The More actions menu has been removed.

TEXT AND COLOUR SOURCE UPDATE (included in alpha.82)
Overview, Reservations, Rolls and Awards share white body text, gold headings
and primary actions, and grey supporting text. Player names use class colours
where known; item names retain loot-quality colours where item data is known.
Missing submissions, unsaved selections, ties and pending delivery use amber
with explicit labels. Submitted, saved and delivered states use muted green.
Awards show readable delivery states instead of internal status names.
Roll results keep invalid attempts subdued and labelled Invalid with a reason;
the highest eligible roll remains highlighted. No loot or reservation rules changed.

NAVIGATION SOURCE UPDATE (included in alpha.82)
All four SoftRes pages use the same Overview / Reservations / Rolls / Awards
navigation, with a gold active tab and matching SoftRes page titles. Loot and
Timer shortcuts are in the same top-right position on every page and keep the
separate tracking windows available. Switching pages keeps the manager window
position and reservation draft. Leader-only pages hide when hosting authority
is lost. Import Softres.it and Refresh session stay directly visible on Overview.
End session stays separate at the bottom-right of Overview with confirmation.

RESERVATION BROWSER SOURCE UPDATE (included in alpha.82)
Instance and Boss selectors have explicit labels and dropdown arrows. Source
labels follow the chosen content/boss, with full source text on hover. Selected
items have a subtle highlight and Selected xN count. The reserve count and up to
six selection slots remain visible; selected slots show a minus action to remove.
Searches with no matches show guidance rather than a blank list. Returning from
another tab preserves the current search, instance, boss, page and draft; a new
session starts fresh browsing filters. Locked reservations have clear guidance.

ROLL TO AWARD SOURCE UPDATE (included in alpha.82)
The roll screens show a larger item name and icon. The leader table highlights
all players tied for the best eligible result, with explicit Leading, Tied and
Winner labels. Supporting text explains SR/MS/OS priority and stacked rolls.
The player prompt explains that player's reserve allowance or tie eligibility.
Stop rolls leads to Award winner, or a tied-player reroll. Award confirmation
shows the player and item name. After recording, the item and award stay visible;
View delivery selects that exact award and its page in Awards. Invalid attempts
remain visible but subdued with their reason. No roll or loot rules changed.

TEST CONTENT PICKER SOURCE UPDATE (included in alpha.82)
Start SoftRes test now opens the normal dungeon/raid selector first, for both
solo tests and leader-started group tests. Choose the content and 1-6 reserves,
then Confirm. Nothing is shared with the group until the leader confirms.
Ten simulated loot copies are sampled from up to eight items in that content;
reservations and browsing use the same selected scope. Solo mode still provides
20 players; group mode uses the actual members. Cancel/close exits the pending
test. Restarting opens the picker again. Tests now require AtlasLoot Forever
with Dungeons and Raids, or compatible ItemDB, for the real content catalogue.
Real bags, trades and saved SR history remain isolated throughout selection.

TEST SCENARIOS SOURCE UPDATE (included in alpha.82)
Start a SoftRes test, select dungeons/raids and the reserve limit, then choose
Test scenario before Confirm. Normal run keeps the usual practice flow.
Tied rolls seeds two equal results; close and reroll for a deterministic winner.
No valid rolls seeds passed/invalid attempts and a 5-second expiry; do not add
new rolls if checking the no-winner path. Stacked reserves needs at least two
slots and seeds several SR results, an invalid extra attempt and a higher MS
roll. For these three scenarios, lock reservations and queue the first loot copy.
Pending delivery opens Awards with three pending copies and short timers.
Import examples opens a valid sample preview. Load test example offers valid,
unknown-player and outside-content exports using the actual import codec.
Out-of-scope picks are now blocked during preview as well as during apply.
These presets also work in leader-hosted group tests and script results for real
members; Normal run continues to use native player rolls. Import examples never
apply automatically. Test controls disappear when returning to normal setup.
Real trade evidence, real bag collection and recovery still need live testing.

LEVEL PICKER AND DROPDOWN SOURCE UPDATE (included in alpha.83)
Setup now uses Level range and Dungeon / raid dropdowns instead of the paged
alphabetical list. Choices are ordered by recommended level and include ranges
that overlap the chosen level band. Multiple selections are kept when changing
filters, with a scrollable selected-content summary and Clear selected control.
Ranges come from catalogue metadata or the game's Group Finder activities;
unknown ranges remain selectable under Level unavailable. No level ranges are
estimated from loot item levels. SoftRes dropdown arrows now use the bundled
chevron texture instead of a font character that could display as a square.

RESERVATION SIDEBAR SOURCE UPDATE (included in alpha.83)
Reservations now uses a sidebar for My reserves, All reserves, Search results,
All loot and per-instance/boss browsing. A virtual scroll list replaces item
paging, with larger icons, item-type/source details and reserve counts. Hover an
item to see reserving players; totals include your current unsaved selections
in place of your confirmed picks, so your own reserves are not double-counted.
Remaining reserve slots are prominent at the top. Selected picks, Submit and
Reset stay visible in a separate footer. Use Reserve/Reserve +1 and - to edit.
Locked sessions disable editing. Uncached reserved items remain visible in the
personal/all-reserves views. Tab switching keeps the current view and search.

ATLASLOOT RANGE FIX (included in alpha.84)
AtlasLoot LevelRange has three values: minimum entry, recommended minimum and
recommended maximum. Setup now displays/filters using values 2 and 3, matching
AtlasLoot's own ContentProto:GetName display. Two-value generic ranges still
work. Installed AtlasLoot ranges take priority over alternate catalogue/native
suggestions. All 55 range triples in the installed AtlasLoot data were checked,
with regression cases for Gnomeregan, Scarlet Monastery wings, Wetlands,
Dalaran and Hall of Thanes. The full 28 check suites passed.

RESERVATIONS TOOLTIP UPDATE (included in alpha.84)
Item rows, Reserve/remove buttons and selected picks no longer open hover
tooltips in Reservations. Reserve totals and item/source details stay inline.

AWARD CONFIRMATION ITEM UPDATE (included in alpha.84)
Confirm award shows the item name/link and loot colour on its own line, using
the tracked copy or catalogue link as a fallback when native metadata is loading.
The session/round/winner checks still apply when confirming.

AWARDS AND ROLLS LIST UPDATE (included in alpha.84)
Awards now uses item icons and separate Item, Winner, Result, Holder and Status
columns in a scrolling list. Pending is the default view, with Delivered and All
filters. A selected-award panel shows the item and delivery details, one relevant
claim/trade action, and manual confirmation where allowed. Correction controls
stay separate and expand only when requested; selecting another award clears
old correction inputs. Exact-award navigation selects the matching filter and
scrolls to that award. Rolls also replaces Previous/Next with a virtual scrolling
list while keeping leading, tied, winner and invalid-result styling. All 800
supported roll attempts are reachable; new rounds return the list to the top.
