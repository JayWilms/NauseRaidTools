Nause Soft Reserve - 0.1.0-experimental.18

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
