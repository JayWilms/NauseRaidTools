Nause Soft Reserve - 0.1.0-experimental.16

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
