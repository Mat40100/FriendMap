# FriendMap changelog

## 1.6.5
- **Fix: the Help! button did nothing.** Reading your health could fail silently on this client, which stopped the call before it was sent. The help call now always goes out, and any error is shown in the chat.
- **Fix: you still appeared twice** ("First" and "First Last"). The game gives only your first name for yourself, while the server uses your full name. FriendMap now learns your full name from the group channel and merges your old entries in the leaderboard and members window.
- **Fix: friends appeared twice on the leaderboard** (e.g. "Black" and "Black Pvp"). Full names are now also learned from the group channel and from every message, so it works even with friends on an older version, and the duplicates merge.

## 1.6.4
- **Fix: names with a surname.** Everyone is now named "First Last" everywhere in FriendMap (map, group lists, members window, leaderboard, kill feed, alerts), so nobody appears twice anymore. Each player sends their full name with their position; entries saved under a first name only are merged automatically.
- Whispers from the map or the members window still go to the right player.

## 1.6.3
- **Assists:** the PvP leaderboard now counts assists. A kill (the enemy was your target when it died) is worth **2 points**, an assist (you fought it, or it was fighting one of your friends, in the last 30 s) is worth **1 point**. The leaderboard ranks by points and shows kills and assists for everyone.
- **Fix: you no longer appear twice** ("First" and "First Last") in group lists and on the leaderboard. FriendMap now always uses your character's first name, like the server does; your old "First Last" kills are merged into it.
- **More kills detected:** deaths are checked the moment an enemy's health changes, so kills are no longer missed when the enemy's nameplate disappears right after it dies. Enemies fighting your friends now count too.

## 1.6.2
- **Revenge:** when an enemy kills you in world PvP, your groups are told and the killer goes on the revenge list for 2 hours. When anyone in the group sees them again, everyone gets a purple **REVENGE** alert and a marker on the map for 2 minutes. Killing them settles it. `/fm revenge` shows the list.
- Friends now show as a **light circle in their class colour** on every map (Blizzard, MelloUI, OpenMap) and on the minimap. Prefer the class icons? `/fm icons` or the map menu switches back.

## 1.6.1
- New option **Arrow to the rally point** in the `/fm` window (or `/fm rally off` / `/fm rally on`): turn it off to hide the on-screen arrow towards rally points. The rally flag still shows on the map.

## 1.6.0
- **OpenMap support:** with OpenMap installed, friends show on the world map as a light circle in their class colour (with their name) instead of the class icon. The red PvP / gold glow still shows around it.
- You are never drawn as a friend on your own map.

## 1.5.1
- The Help! button always answers: how many friends received the call, or why it couldn't be sent (cooldown, no group, sharing off, inside an instance).

## 1.5.0
- **Fix: friends now see each other on WoW Forever.** The game silently drops addon messages sent in custom channels, so nothing was getting through. The hidden group channel is now used only to know who is online, and data is sent as invisible addon messages to those members. Nothing shows up in your chat.
- Positions are sent every 2 s while you move, every 15 s while standing still.
- "No player named..." errors caused by FriendMap are hidden.
- `/fm debug` shows how many members are in each group channel.
- Everyone in the group needs 1.5.0 or newer.

## 1.4.0
- New **Group members** window (`/fm members`, the *Members* button, or a quick bar icon): every player seen in each of your groups, online first, with level and "last seen".
- Left-click an online friend for the arrow, right-click to whisper.

## 1.3.2
- You now count as online in your own groups and appear first as "Name (you)".

## 1.3.1
- Group channels are joined automatically after login (no click needed).
- New `/fm debug` and `/fm test` commands to check the connection.

## 1.3.0
- PvP kills are synced between all group members, and passed on by any friend even when the killer is offline.
