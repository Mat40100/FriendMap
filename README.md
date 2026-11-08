# FriendMap

*[Version française](README.fr.md)*

A World of Warcraft addon (WoW Forever client) that shows your friends on the world map and minimap — class icon plus a small class-coloured nameplate — as long as they also run FriendMap and share a group with you.

## Features

- **Friends on the map**: class icon + name on the world map, smaller icons on the minimap. Hover for level/class/group, right-click to whisper.
- **Groups**: create as many as you like. Each group uses its own hidden, password-protected addon channel to know who is online; data is sent as invisible addon messages to those members only (WoW Forever blocks addon messages inside custom channels). Nothing shows up in your chat.
- **Easy joining**: in-game invites (Accept/Decline popup), clickable chat links, or a share code you can paste anywhere (Discord…).
- **World PvP**: a pulsing red glow surrounds a friend's icon while they are in a world PvP fight, and (optionally) your groups get an alert when you start one.
- **Map pings**: Alt+click the world map to drop a pulsing marker on all your friends' maps (with a sound).
- **Help!**: one button (or automatic below 30% health in a PvP fight) alerts your group, shows where you are and points their arrow at you.
- **Trails**: faint dots show where each friend went in the last 3 minutes.
- **Distance & arrow**: tooltips show "340 yd NE"; click a friend on the map to get an on-screen arrow pointing to them.
- **Status**: a short status ("farming", "LFG"...) shown under your name on the map.
- **Kill feed & leaderboard**: your group sees your world PvP kills; weekly ranking in the window and `/fm top`. Kills are synced between all group members, even those made while you or the killer were offline (any friend who saw them passes them on).
- **Level-up & achievement news**: announced to the group, with a golden glow on the icon.
- **Rally point**: Alt+Shift+click the map (or **Rally here**) to place a flag everyone gets an arrow to.
- **Zone heatmap**: on the continent map, each zone shows how many friends are in it.

## Installation

1. Download the latest release: **[FriendMap on the Releases page](https://github.com/Mat40100/FriendMap/releases/latest)** → `FriendMap-vX.Y.Z-forever.zip`.
2. Extract it into your AddOns folder:
   ```
   World of Warcraft/_forever_/Interface/AddOns/
   ```
3. Check the folder is named `FriendMap` (it already is in the release ZIP; a "Code → Download ZIP" of the repo extracts as `FriendMap-main` and must be renamed). You should end up with:
   ```
   Interface/AddOns/FriendMap/FriendMap.toc
   ```
4. Start the game (or `/reload`), and make sure **FriendMap** is enabled in the AddOns list on the character screen.

To update, replace the folder with the new version (your groups are kept, they're stored in `WTF/`).

## Map menu

Whenever a map is open — Blizzard's world map, **MelloUI's map**, or another map addon — a small FriendMap button appears at its top-right corner (Shift+drag to move it). Its menu lets you:

- **Ping / Rally at my map pin**: Ctrl+click any spot on the map to place the game's standard map pin, then pick one of these. Works on every map that uses the game's map pin (Blizzard, MelloUI, ...).
- Ping / rally at your own position, clear the rally point, call for help.
- Toggle trails, zone heatmap, minimap icons; stop the arrow; open the FriendMap window.

On Blizzard's map you can also Alt+click (ping) and Alt+Shift+click (rally) directly.

## Updates

FriendMap tells you when a newer version exists: as soon as anyone in your groups runs a newer version, you get a chat message (and the window title shows it). Type `/fm update` to copy the download link, then reinstall as above. `/fm version` shows your version.

## Quick bar

A small movable bar of icons for one-click actions: **Help!**, ping your position, rally here, clear the rally point, track the nearest friend, stop the arrow, toggle position sharing, toggle PvP announcements, PvP leaderboard, settings (gear). By default it shows **Help!**, **Rally here**, the **PvP leaderboard** and **Settings**.

Choose which icons it shows with the **Quick bar** button in `/fm`, `/fm bar`, or by right-clicking the bar. There you can also hide it, lock it, make it vertical and change the icon size. Drag the bar to move it.

## Getting started

1. Type `/fm` to open the window.
2. One person clicks **Create group** and gives it a name.
3. Bring your friends in, any way you like:
   - **Invite**: type their character name (or target them first). They get an Accept/Decline popup.
   - **Link**: drops a clickable `[FriendMap: Name]` link into chat; clicking it offers to join.
   - **Code**: shows a `FMAP:...` code to copy (Ctrl+C) and send anywhere. Friends join with **Join with code** or `/fm join FMAP:...`.
4. Open the world map — your friends appear on it.


## Commands

| Command | Description |
|---|---|
| `/fm` | Open / close the window |
| `/fm create <name>` | Create a group |
| `/fm join FMAP:...` | Join a group with a share code |
| `/fm invite <player> [group]` | Invite a player |
| `/fm link [group]` | Post a clickable join link in chat |
| `/fm code [group]` | Show the share code to copy |
| `/fm leave [group]` | Leave a group |
| `/fm list` | List your groups and who is online |
| `/fm share` | Turn sharing your position on/off |
| `/fm minimap` | Turn minimap icons on/off |
| `/fm pvp` | Turn announcing your world PvP fights on/off |
| `/fm pvpalert` | Turn the on-screen alert for friends' fights on/off |
| `/fm ping [text]` | Ping your position |
| `/fm help` | Call your group for help |
| `/fm autohelp` | Turn the automatic help call on/off |
| `/fm status <text>` | Set your status (empty = clear) |
| `/fm track <name>` | Arrow towards a friend (no name = stop) |
| `/fm rally` / `/fm rally clear` | Set / clear the rally point at your position |
| `/fm top` | Open the weekly world PvP leaderboard |
| `/fm members` | Show every player seen in each of your groups (online / last seen) |
| `/fm trails` / `/fm heatmap` | Turn trails / zone heatmap on/off |

`[group]` can be the group's number from `/fm list`, or its name. Without it, the first group is used.

## Limitations

- Everyone must have FriendMap installed.
- Channels and invites only reach players on your realm or connected realms.
- Positions usually can't be read inside dungeons/raids, so friends there won't show until they leave.
- PvP detection and the kill feed work from your target, focus, mouseover and nameplates (the combat log is unavailable to addons on this client), so turning enemy nameplates on helps. A kill is credited when an enemy you were fighting dies, even if someone else landed the last hit.
- The clickable chat link may be stripped by the server; the share code always works.

## Credits

Uses [HereBeDragons](https://github.com/Nevcairiel/HereBeDragons), LibStub and CallbackHandler.
