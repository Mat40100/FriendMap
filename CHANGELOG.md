# FriendMap changelog

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
