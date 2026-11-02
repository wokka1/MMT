<p align="center">
  <img src="media/mmt-banner.png" alt="MMT - Manage My Team: multiboxing assistant for World of Warcraft: Forever" width="760">
</p>

# MMT - Manage My Team

A lean multiboxing assistant for World of Warcraft: Forever (interface 16001).
Version 0.9.43: core addon (MMT) plus optional modules (MMT_*).
To install, download the repository (Code > Download ZIP) and copy the four `MMT*` folders.

## Install
Copy the `MMT` folder and the module folders you want (e.g. `MMT_ItemCompare`) into
`World of Warcraft/_classic_beta_/Interface/AddOns/`.
Install them on **every** account/client you multibox with.
If you used OMT: keep it enabled for the first login with MMT (its settings are
copied into the "Default" profile), then disable or delete OMT.
Saved data from MMT 0.1.x is converted automatically.

## Core and modules
- **Core** (`MMT`, always on): Team, Roles, XP Window, Alerts, FTL, Automations, Trade / Mail / Vendor, Profiles, plus team
  communication, profile sync and debug tools.
- **Modules** (`MMT_<Name>`, optional): separate addons that build on the core. Loot
  Distribution, Quest Tracker and Statistics are on by default, the others off (`## DefaultState:
  disabled` and `## X-MMT-DefaultState: disabled` in their TOC) until switched on in /mmt > Modules or the AddOns list. They
  appear in the game's AddOns list and under MODULES in /mmt (header "MODULES (4 of 11)":
  switched on of installed), switched-on modules first, switched-off ones greyed out below. Switching one off in /mmt stops it right away and disables
  it for the next login; switching one on starts it right away, or after a reload if
  it wasn't loaded. "Manage modules" lists all installed modules with version, author and
  repository link (TOC fields `## Version`, `## Author`, `## X-Repository`; click the link
  to copy it). When a switch needs a UI reload, a "Reload UI" bar appears at the bottom.
- Modules so far: **Item Bar** (`MMT_ItemBar`), **Item Compare** (`MMT_ItemCompare`), **Loot
  Distribution** (`MMT_LootDistribution`), **Quest Tracker** (`MMT_QuestTracker`), **Statistics**
  (`MMT_Statistics`), **Team Launch**
  (`MMT_TeamLaunch`: named team presets, restore the last team, invite-team key and button, add
  characters by name; `/mmtteam`), **Buffs**
  (`MMT_Buffs`: one key buffs your target, another buffs the group one person at a time, never recasting
  a buff that is still up; per-class buff lists; `/mmtbuff`).
- Lists that scroll (the page list, module and team lists) show a small arrow at the top or
  bottom edge while there is more above or below; clicking it scrolls.
- Settings sync for modules: add `sync = true` to `MMT.NewModule{...}` and the module gets
  a "Sync to team" button in the bottom right of its settings page and `/mmt sync <name>`.
  Only `M.db` is sent (never `M.store`). Optional: `syncExclude = { "key", ... }` for
  settings that stay on each client, `M.OnSyncReceived(m, from)` after settings arrived,
  `M:SyncToTeam()` and `M:SyncButton(frame)` for windows of your own. Example on /mmt > Help.
- A new module folder needs a full game restart (not just /reload) before the game lists it.
- Key bindings: Esc > Options > Keybindings > "MMT (Manage My Team)" holds every MMT key,
  one header per addon: Core (open the settings, show / hide the XP window, make this
  character the FTL leader), Item Compare, Item Bar (one key per slot), Statistics (open
  it). Modules add theirs with `category="BINDING_CATEGORY_MMT"` (CreateModules.md).
- Writing your own module: see [CreateModules.md](CreateModules.md) (team management
  API, team communication, two complete examples).

## Settings (/mmt)
- **Team**: Add group / Add me / Add target, or type "First Last". Reorder with Up/Dn.
  **Privacy**: "Show characters by" first name (default), last name, full name, class
  ("Druid 1", "Druid 2" in team order) or slot ("Slot 1", "Slot 2"). This applies to
  everything MMT shows: windows, settings, tooltips, its chat lines and raid warnings.
  Real names are only used where the game needs them (macros, invites, whispers, team
  communication). `/mmt leader` also understands the shown name (`/mmt leader Druid 2`).
  "Keep full names in debug logs" (on by default): off replaces them in the debug log
  and report. "Hide names outside MMT too" (off by default, not with "Full name"):
  replaces your team's names in chat (all chat windows; clicking a name still whispers
  the right character), unit frames, raid frames, nameplates, unit tooltips and the
  text of other addons' frames (e.g. their raid frames), where the game allows it.
  Changing the setting updates what is already shown, chat lines included.
  Switching "Hide names outside MMT too" on or off (or switching to or from "Full name"
  while it is on) asks to reload the UI right away, because other addons only pick it up
  after a reload; Cancel leaves it as it was. (The game no longer lets addons reload the UI
  themselves; MMT's "Reload now" buttons are secure macro buttons running /reload.) A profile switch or sync that changes it
  says in chat that a reload is needed.
- **Roles**: create roles, tick their members, add items (drop one on the slot, or
  click the field and shift-click an item anywhere; IDs and exact names work too),
  rules (all grey, all Bind on Equip, by quality) and item groups (Cloth, Leather,
  Herbs, Ore/bars/stone, Enchanting, Potions, Food & drink, Reagents, Consumables, ...).
  Opening a trade with a team member puts the matching items in (switch on the Trade /
  Mail / Vendor page). You accept yourself.
- **XP Window**: XP %, rested XP %, gold, free bag slots, durability (lowest item or
  average), level, reputation and layer, plus font, layout, size, scale and opacity. Each of
  these is a piece: switch it on or off, put it left of the bar (own column, the bar starts
  at the name) or on the bar, and drag it into place in the XP Window page's list or in the
  window itself ("Arrange" / `/mmt xp arrange`: every piece shows with dots, drag pieces
  along a row and rows up or down to change the team order). "Line up pieces" puts each piece in its own column
  (centred, left or right in it), so it sits in the same place on every row. Modules can add pieces
  (`MMT.RegisterXPPiece`, CreateModules.md). "Bar shows": experience
  or the reputation of each character's watched faction (standing and %, faction in
  the tooltip). "Layer Hop": when the game
  offers a layer/phase switch, a pulsing red "Layer Hop" appears left of the name.
  Click it to accept in 3 seconds (a teammate's tag makes their client accept), or let
  MMT accept automatically after X seconds. Both count down in chat. Hover a row for all details of that member,
  Mouse on a member: click makes them the FTL leader, right-click invites, Ctrl-click
  inspects, Ctrl-right-click shows the talents, middle-click invites the whole team.
  Shift + drag moves the window, Shift-right-click opens the settings. A crown marks
  the FTL leader.
  "Click-through" turns the mouse off for it. During a layer hop countdown every
  client's XP window shows "Layer Hop 5, 4, ...".
- **Alerts** (settings page):
  "Follow": every client reports when its character starts or stops following (/follow).
  A member who stops gets a red row that pulses for 10 seconds, then "(no follow)" in red
  after the name until they follow again; the client of the character that was
  followed shows the raid warning "<Name> stopped following" and plays the raid warning
  sound. Options: check /follow of team, warning, sound, ignore breaks during combat
  (then nothing shows during a fight, on either character's side; it only counts if the
  character still isn't following some seconds after combat; default 5, adjustable).
  Flight paths don't count as a break, nor does following again within half a second
  (a new /follow ends the old one for a split second). The same alert about the same
  character (follow, crowd control, bags and quest log) shows at most once every 5 s.
  "Crowd control": every client reports when its character can't move: stunned, feared or
  charmed, incapacitated (polymorph, sap, sleep) or rooted (each can be switched off;
  effects shorter than 2 seconds are ignored, adjustable). The row turns orange and
  pulses, with "(stunned 4)" counting down after the name and the spell in the tooltip.
  The raid warning "<Name> is stunned (4 s)" and its sound come from the FTL leader's
  client (the character you play); with no leader known, from every client.
  Follow, crowd control and layer hop messages go to the FTL leader first (whispered,
  highest priority) and then to the rest of the team.
  "Bags and quest log": the leader (the FTL leader; without one online, the group leader if in the team, else the first online team member) gets a chat line,
  and optionally a raid warning and sound, when a character gets down to a set number
  of free bag slots (default 2) or free quest slots (default 3), and again when full.
- **FTL** (Focusless, Targetless, Leaderless): macros that always target the character
  you are controlling right now, like `/follow {FTL}` or `/assist {FTL}`. Write them on
  the FTL page; MMT turns them into account macros where {FTL} is the leader's name
  ("Drag to bar" puts one on the cursor; macro names have at most 16 characters).
  Defaults: "FTL Follow" (`/follow {FTL}` + `/focus {FTL}`), "FTL Assist" (`/assist {FTL}`
  + `/focus {FTL}`): the game sets the focus only on a key press or click, so following or
  assisting once after a leader change makes the leader the focus, and `[@focustarget]`
  works. Examples: "Pri: Lesser Heal" =
  `/cast [@{FTL},nodead] Lesser Heal`, "Dru: Heal Touch" (Healing Touch) and "Sha: Light
  Bolt" = `/cast [@focustarget,nodead,harm] Lightning Bolt`.
  Lines with {FTL} are left out on the leader's own client (setting). Change the leader
  by clicking a character in the XP window, with the key binding "Make this character
  the leader (FTL)", with `/mmt leader [name]`, or automatically when you move a
  character on its own (Leader: "Automatic, when you move"; off by default). Automatic detection ignores movement while following, on a
  flight path, in combat or without control (feared, charmed), and movement of several team
  characters at once (a movement key or Interact with Target broadcast to every
  window): then the current leader stays. Two claims in the same second are decided
  the same way on every client. The idea comes from ISBoxer, but unlike there the
  FTL target **cannot change during combat**: WoW only lets addons edit macros outside
  combat, so a change in combat is applied when combat ends.
  Sending the macros to the team: characters on the same account with the same profile
  already have them; for other accounts use Profiles > Sync to team (`/mmt sync`). Each
  character still needs the macros on an action bar once.
- **Item Bar** (module, off by default): item slots that are the same on every team
  member (2 to 8, horizontal or vertical, scale 80-200%). Drop an item from your bags on
  a slot and it appears there on every character, also on those that don't have it;
  Ctrl-click removes it everywhere. The tooltip shows every character's count ("Name -
  bag: X / bank: Y", privacy names; optionally the guild bank). A click uses the item on
  this character (WoW lets an addon use an item only on a click or key press on that
  client, so there is no "use on the team" click). Every slot has a key binding (Esc > Options > Keybindings > MMT (Manage My Team) >
  Item Bar): with key broadcasting one key press uses the item everywhere.
  Small buttons: refresh (sync the bar to the team) and clear (both can be hidden).
  Shift + drag moves the bar, Shift-right-click opens its settings.
- **Statistics** (module, on by default; `/mmtstats`):
  - Gold: a table with one row per team member (you first): "This Character", "Other
    Characters" (every other character on that member's WoW account, in a team or not)
    and "Combined". The tooltip of a row lists the account's characters. Every character
    that logs in with MMT records its gold after login and on every change: one
    record per day, kept for 60 days, saved per account (not per profile).
  - A line chart of the combined gold over the last 60 days for "Current team",
    "Current account", "Account of X" (each account the team sent) or "All accounts";
    hover a day for its value. The axis goes in round whole-gold steps ("10k g", "1.2M g").
  - Accounts: every WoW account keeps its own saved variables, so MMT gives each one a
    random id. When two clients send the same id (saved variables copied from one account
    to another), the one with the later name takes a new id and sends again. A character only counts for an
    account once it logged in there, so characters that came with copied files drop out. Clients send a summary of their account to the team (characters with gold
    and kills, daily totals, top kills and killers; compressed when possible) and keep the
    latest of every other account, named after the team member that sent it. Summaries are never
    sent in real time: a change only marks them as changed; they go out after combat, at
    most every 5 minutes (Settings tab: 1 to 30), at the lowest priority; answers to a
    request at most every 20 s. Summaries are exchanged at login, 20 s after joining a
    group, and on "Request update" (button beside "Sync to team").
  - Kills: the same table for NPCs killed, the top 10 NPCs killed and the top 3 NPCs that
    killed you, for the same choice of accounts. Kills count where the game lets addons
    see them (NPCs the character fought that died while targeted or with a nameplate, and
    the experience message; the combat log is reserved for the Blizzard UI on WoW:
    Forever); a kill seen twice counts once. The killer at death: the hostile target that
    targeted you, else an NPC nameplate that did.
  - Settings tab: track gold, track kills and deaths, share with the team, money format
    (5g 32s 1c, 5g, coin icons), clear this account's statistics, forget other accounts.
- **Item Compare** (module): set a key, hover an item and press it to see what every team
  member wears in that slot (both slots for rings, trinkets and one-hand weapons),
  with the stat and item level changes if they equipped the hovered item.
- **Loot Distribution** (module): sets Free for All, Round Robin or Master Looter and the
  loot threshold when a group forms or a team character becomes leader. "Group Loot when
  outsiders join": while a player who isn't in your team list is in the group, the method
  is Group Loot, and the chosen method again when they leave. As master
  looter it gives items at or above the threshold to the team member whose roles want
  them. When roles of different members want the same item, the most specific rule
  wins: an exact item, then an item group ("Cloth"), then an item class, then Bind on
  Equip or a quality ("white items"); this also applies to trades and mail. "Several
  have the role": fill up by team order (the first in team order with
  more free bag slots than the reserve gets everything, then the next) or round robin
  (in turns). "Role members have no room": leave for manual, give to the next team
  member with room (round robin), or to the master looter. Bind on Pickup
  items are never given out: they are posted in group chat for manual assignment.
  "Auto-Round Robin quest items": quest items go to the team in turns (team order).
  The master looter first asks the team who still needs the item (each client checks
  its quest log) and skips characters whose objective is complete. If the game still
  refuses a hand-out, that character is skipped for that item for 10 minutes.
  A character with full bags still counts as having room for a stackable item that fits
  onto a stack it carries (the master looter asks the team). Items nobody has room for
  stay in the loot window with a chat note.
  The "keep free bag slots" reserve doesn't apply to quest items: they are given even
  into the last free slot, and with full bags they are still tried (they may stack).
  Items are recognised as quest items by the loot window or by their item class.
  "No role wants it": leave for manual assignment, give to the master looter, or
  "Round robin to the team" (in turns, keeping the reserve; not for quest items or
  Bind on Pickup). "Say so in chat" prints "[Item] is not part of any role or rule,
  so it was given round robin to <Name>." (only for you).
  "Automatically pass on loot rolls" (off by default): with Group Loot or Need before
  Greed every character passes on its rolls, except the group leader or, if chosen, the
  FTL leader (the character you play), who rolls as usual.
  "Enable 'Pass on Loot' while in a group" (off by default): switches on the game's Pass
  on Loot for every character in a group except that same leader; it is switched off
  again when the character leaves the group or becomes the leader (only if MMT set it).
- **Quest Tracker** (module): replaces the Blizzard quest tracker with a team tracker:
  Zone > [Level] Quest > Objective > one row per team member with their progress
  ("3/8", "done", "not on quest"). Mouse:
  - +/- at the start of a line: collapse / expand it; [-] / [+] on the header: collapse
    everything down to the zones / open everything.
  - Shift + drag: move the tracker (unless locked). Right-click: settings.
  - Quest: click opens it in the quest log, Shift-click links it in chat,
    Shift-right-click abandons it (asks first).
  - Zone: Ctrl-click collapses / expands all its quests (only the quest names),
    Ctrl-right-click shows only that zone (again: all zones). The quest log's tracked
    quests aren't changed by this.
  Background colour and opacity, width, maximum height (scrolls beyond), indent,
  alignment, outline, and font, size and colour for each of the four levels.
  "Hide other addons' quest trackers" (on by default): Questie's tracker window and
  EllesmereUI Quest Tracker are hidden while the module is on (their own settings stay
  untouched) and come back when the option or the module is switched off.
  Quest automation lives here too: accept from NPCs and from the group, turn in, skip
  grey quests, announce "ready for turn-in", share new quests automatically, announce
  quests that can't be shared, mark the reward choices (a coin on the one that sells
  for the most, a green arrow on upgrades: wearable and of a higher item level than
  what is worn in that slot), announce looted items that start a quest ("Looted
  [Item] - it starts a quest!", on by default), and abandon a quest on the whole team (asks first:
  "Do you want to abort this quest on your entire team?"). The quest settings of
  Core > Automations are copied over once.
- **Automations**: gossip to vendor or flight map, click through dialog-only NPCs (plain
  dialog lines; anything that could cost gold, teleport, train or start a fight stays
  manual), invites (team, friends, guild, and anyone who whispers the keyword, default
  "mybox"), camera zoom, distance window (distance to your target, mostly for hunters
  avoiding the dead zone; font, outline, alignment, size, width and background are in
  "Format window", a small window beside the settings).
  - "Take flight paths with the team": when a team member picks a destination at a
    flight master, every team member talking to a flight master too (flight map open, or
    opened within 5 seconds) flies to the same destination (as in EMA). "Tell the
    leader": the leader's chat shows who took the flight too or couldn't.
  - "Mount up / Dismount with the leader": when the leader mounts, the team mounts the
    same mount (or one of the same kind, or a random favourite); when it dismounts, the
    team dismounts (never in the air). Hold Shift to ride alone.
  - "Release as team" / "Revive as team": an MMT panel under the game's death dialog and
    under the corpse dialog, on every character it concerns. One click releases every
    dead team member, or revives every ghost at its corpse (one with a corpse delay
    revives when it ends). The panel lists who is dead or a ghost and who can revive now.
  - "Accept automatically": resurrections and warlock summons, each from team, friends,
    guild and/or anyone.
  The leader is the FTL leader; without one online, the group leader if in the team, else the first online team member (team order).
- **Trade / Mail / Vendor**:
  - Vendor: repair (optionally with guild funds), sell grey items, print results, tell
    the leader (sales and repairs of the other characters), money format.
  - Sell list / never-sell list: roles from the Roles page (items and rules: item,
    quality, Bind on Equip, item group). Items of the sell list are sold too; the
    never-sell list wins, greys included.
  - Trade: "Fill trades from role rules" puts the items the partner's roles want into
    the trade window (it was on the Roles page). "Share among team" picks any number
    of roles; the items of each are split evenly among the members that have that role: every member's MMT
    reports its counts, the share per item is the total of the role members divided by
    their number (rounded down), and in a trade between two members the one above the
    share gives the other what is missing (no more than it has above the share). The
    trade window only takes whole bag slots, so the giver re-stacks first to hand over as
    few stacks as possible: full stacks (partial ones merged into full ones when needed),
    then the rest as one stack: one with exactly that many, else the biggest smaller one
    topped up from the others, else a part split off into an empty bag slot (only then a
    free bag slot is needed). Trades with characters without the role are not affected.
    Example: members 1, 2 and 4 carry 50, 0 and 40 water: 30 each; 1 trading with 2
    gives 20, 1 with 4 gives nothing, 4 with 2 gives 10. An item in several shared roles
    is shared by the first of them (alphabetical).
  - Buy list: items and a count; at a vendor that sells them, each character buys up to
    that count (gold only). "Buy on" picks one character for an item; then only that
    character buys it.
  - Mail: a "Mail to team" button beside the mail window sends every item another team
    member's role wants to that member (items your own role wants stay), 12 per mail,
    and optionally the gold above an amount to one team member.
  - Guild bank: a "Deposit to guild bank" button puts the items of a chosen role into a
    chosen tab, and optionally the gold above an amount.

- **Shift**: hold it while an NPC window opens to keep that page manual; pick an option
  without Shift and the next page (dialog, quest, reward) is automated again.
- **Profiles**: per character; copy, reset, delete, export/import. After a reset or a new
  empty profile, MMT asks whether to switch the modules back to their default (on or off) too.
- **Sync to team**: `/mmt sync` (or the blue button in the bottom right of Profiles) sends
  the core settings of the active profile: team, roles, XP window incl. its position,
  automations, distance window. Module settings are not included. Item Compare, Loot
  Distribution and Quest Tracker have their own button and `/mmt sync <module>`
  (e.g. `/mmt sync questtracker`), which sends only that module's settings.
  Messages are paced to stay under the game's addon message limit. The sender sees who
  it went to and who confirmed (received, accepted, declined); recipients see when a
  transfer starts and when it is complete, then a dialog to accept it. "Auto-accept
  synced settings" (beside the button) applies core and module settings from team
  members without the dialog; it is stored per account and never synced.
  `/mmt sync` also sends which modules are on or off, and with "Use guild channel" and
  every recipient in your guild also the settings of the modules (sync = true); the
  recipients switch their modules the same way (modules switched on that weren't loaded need a UI reload; modules they don't
  have installed are named in chat). Modules page > "Sync to team" (or
  `/mmt sync modules`) sends only the on/off states.
- **Help**: debug tools with a how-to, guides for writing modules and using the team
  communication (with copyable example code), and **Appearance**: a background for the
  settings window (plain looks such as Dark, Dusk, Vignette, Accent or Class glow, Grid,
  Glass, or the game's talent tree paintings: one per class and spec, or "My class", which
  follows the talent tree with the most points), its opacity (default 30 %) and whether
  the painting is drawn in MMT's accent colour. Per account, never synced; default None.
  "Debug mode (ignore online requirements)" (off, per account): the XP window and the
  Quest Tracker list every team member, also those offline or never heard from (in grey,
  with their last known values). Only for testing: while it is on, MMT asks at every
  login or /reload whether to switch it off.

The page list on the left shows up to 16 pages; scroll it with the mouse wheel. Click
CORE or MODULES to collapse or expand that section (remembered per account).

The settings window has its own scale (- / + at the bottom left, right-click resets,
or `/mmt scale 130`), kept per account. The XP window's scale is under XP Window > Look.

Names follow Team > Privacy (first name by default) in windows and chat messages;
the debug report keeps full names unless "Keep full names in debug logs" is off.

## Layer and phasing
- Layer (zoneUID of nearby NPCs) and phasing (`UnitPhaseReason`) are still shown in the
  XP window's mouseover details and in the debug report:
  0 Phased, 1 Sharded, 2 War Mode, 3 Chromie Time, 4 Timerunning, 5 Ruleset.
- Layer hops ("World refresh in N minutes", event SHARD_TRANSFER_IMMINENT) are accepted
  with `C_PlayerInteractionManager.ShardTransferConfirm()`.
  "Sharded" on the same layer: cross a zone border together, re-invite from the
  character whose shard you want to keep, or meet in a capital city.

## Item Compare data
Each client stores the team's equipped items (account-wide, so offline members are
shown with the age of their data). Only item strings are sent, never tooltips:
the core heartbeat carries a hash of your gear, a member with an outdated copy asks
once for a snapshot, and gear changes send only the changed slots.
The key can also be set in Esc > Options > Keybindings > MMT (Manage My Team) > Item Compare.

## Quest Tracker data
Every client keeps the team's quest logs (quest ID, level, zone, title, objective
progress). The heartbeat carries a hash (qt=), an outdated copy is requested once
(QTREQ, answered in chunks QTS), and changes send only the changed quests (QTD).
Team abandon is QTAB:<questID>.

## Commands
- `/mmt` settings, `/mmt xp` toggle XP window, `/mmt xp arrange` drag its pieces and rows, `/mmt trade` refill open trade,
  `/mmt sync` send the core settings to the team, `/mmt sync <module>` only that module's settings, `/mmt sync modules` only which modules are on or off, `/mmt modules` installed
  modules, `/mmt scale <percent>` settings window size, `/mmt leader [name]` FTL leader (this character or the named one), `/jamba-team iammaster all` same as `/mmt leader` (only when Jamba isn't loaded, for old Jamba macros), `/mmt help` help page, `/mmt reset` reset profile.

## Team communication
- All messages go through one send queue in the core with three priorities (alerts such
  as follow and layer hop first, then normal messages, large transfers last). It keeps to
  the game's limit of about 10 messages per addon prefix and then 1 per second on group
  and guild channels, caps the data rate (800 bytes/s; Team > "Faster sending": 1200) and
  sends throttled messages again.
- Large transfers (settings sync, Item Compare and Quest Tracker snapshots) use their own
  prefix "MMTB", so they never delay the normal messages, and outside instances they go
  by whisper to each team member (whispers aren't throttled there).
- Team > "Use guild channel": one message on the guild channel reaches every team member
  in your guild, grouped or not; the guild roster tells who is online. It can only be
  switched on in a guild, and is switched off (with a chat note) at login when the
  character isn't in one any more. Members outside the
  guild still get whispers. Every client needs the same setting.
  Large transfers use it too when that is faster: a settings sync goes once on the guild
  channel instead of once per recipient by whisper (from 2 recipients in the guild, when
  the estimate is lower), other large data from 3 online team members in the guild on.
- Large transfers on the guild or group channel are spread over four prefixes ("MMTB" to
  "MMTB4"): the game's allowance of 1 message per second counts per prefix, so they go up
  to four times as fast (the data-rate cap still applies).
- Settings syncs are compressed (Deflate, then Base64) when the client has
  `C_EncodingUtil`; the debug report shows `compress=true` then.
- Modules: `MMT.SendToTeam(msg, onlyOnline, prio)`, `MMT.SendAddon(msg, channel, target, prio)`,
  `MMT.SendLong(text[, target])` for texts of any size (Help > Team communication).
- Leader tag (FTL): `MMT.SendToLeader(msg[, prio])` reaches only the FTL leader (whispered
  to the leader if known and online, otherwise sent to the team with the tag). Scope
  `"FOLLOWERS"` as 5th argument of `SendToTeam` (4th of `SendLong`) reaches everybody but
  the leader. Each receiving client checks against the leader it knows and drops what
  isn't meant for it; modules get the scope as 4th argument of `TEAM_MESSAGE`.
  `MMT.SendAlert(msg)` sends to the leader first and then to everybody else (leader tag,
  highest priority); MMT uses it for follow, crowd control and layer hop. Clients
  older than 0.8.8 don't know the tag and would pass such messages on to every module.
- All clients need MMT 0.8.4 or later for large transfers (older versions don't listen
  on "MMTB").

## Character names
Characters on WoW: Forever have a first and a last name. MMT keeps two rules:
- **Internally, always the full name.** Team keys ("First-Last"), messages between the
  clients, whispers, invites and unit lookups use the real first and last name, so
  every feature finds the right character.
- **Everything you see follows Team > Privacy** (first name by default, or last name,
  full name, "Druid 1", "Slot 1"): windows, settings pages, tooltips, MMT's chat lines
  and raid warnings. With "Hide names outside MMT too" also chat, unit frames,
  nameplates, tooltips and other addons' frames.
- **Exception: macros.** `{FTL}` macros contain the real name, because the game needs it
  to find the character.

For modules: show names with `MMT.ShownName(key)` (`MMT.FirstName` and
`MMT.FullDisplay` do the same); use `MMT.RealName(key)` / `MMT.RealFirst(key)` /
`MMT.RealLast(key)` only where the game needs the real name. Never put a real name
into text the player sees.

## Two accounts = two separate teams
Every account keeps its own saved settings, so the team must exist on each client:
group up and press *Add group* on every client, or add the team once and send it
with `/mmt sync` (accept the popup on the others).

## Debugging (also on /mmt > Help)
1. `/mmt debug` switches the debug log on (again to switch off).
2. `/mmt debug clear`, then add your characters, run `/mmt ping` and open a trade.
3. `/mmt debug dump` opens a report (names, group, layer, phase reasons, team, trade,
   log). *Select all*, Ctrl+C, paste it to Claude.
- `/mmt ping` whispers every team member with three spellings of the name.
- `/mmt debug name First Last` shows how a typed name is understood.
- `/mmt debug talents` lists what the game offers to view talents (XP window Ctrl-click).
- `/mmt debug chat` prints the log lines live into chat.

## Logo
The MMT logo is in [`media/`](media): profile images (`mmt-logo.png` dark, `mmt-logo-light.png` light,
512×512), the GitHub social preview (`mmt-banner.png`, 1280×640) and the mark as SVG
(`mmt-mark.svg`). In the game it shows in the settings window and the AddOns list
(`MMT/Media`).

## License
GNU General Public License v3.0, see [LICENSE](LICENSE).
