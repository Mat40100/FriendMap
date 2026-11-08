-- /fm debug : what works and what doesn't (channels, position, sending, receiving)
local FM = FriendMap
local HBD = LibStub("HereBeDragons-2.0")

local function Y(b) return b and "|cff33ff33yes|r" or "|cffff4444NO|r" end

local function ResultName(r)
    if r == nil then return "nil" end
    if Enum and Enum.SendAddonMessageResult then
        for k, v in pairs(Enum.SendAddonMessageResult) do if v == r then return k .. " (" .. tostring(r) .. ")" end end
    end
    return tostring(r)
end

FM.SlashExtra.debug = function()
    local P = function(...) FM:Print(...) end
    P("|cffffd100--- FriendMap debug (v" .. tostring(FM.VERSION) .. ") ---|r")
    local reg = C_ChatInfo.IsAddonMessagePrefixRegistered and C_ChatInfo.IsAddonMessagePrefixRegistered(FM.PREFIX)
    P("Prefix registered: " .. Y(reg) .. "   world ready: " .. Y(FM.worldReady) .. "   sharing: " .. Y(FriendMapDB.sharing))
    if C_ChatInfo.InChatMessagingLockdown then
        P("Chat lockdown (game blocks addon chat): " .. tostring(C_ChatInfo.InChatMessagingLockdown()))
    end
    local x, y, inst = HBD:GetPlayerWorldPosition()
    P(("Position: %s  (inst %s, x %s, y %s)"):format(Y(x ~= nil), tostring(inst), x and ("%.0f"):format(x) or "-", y and ("%.0f"):format(y) or "-"))
    local faction = UnitFactionGroup("player")
    P("Faction: " .. tostring(faction) .. "   realm: " .. tostring(GetRealmName()))
    if #FriendMapDB.groups == 0 then P("|cffff4444No group.|r") end
    for i, g in ipairs(FriendMapDB.groups) do
        local ch = FM:ChannelName(g.code)
        local id, name = GetChannelName(ch)
        P(("Group %d '%s': channel %s -> id %s %s, %d in channel, %d friend(s) seen"):format(i, g.name, ch, tostring(id), Y(id and id > 0), FM.PeerCount and FM:PeerCount(g.code) or 0, FM:CountMembers(g.code)))
    end
    if FM.needJoin then P("|cffffaa00Waiting for a click in the world to join channels.|r") end
    local st = FM.stats or {}
    P(("Messages sent: %d   received: %d"):format(st.sent or 0, st.recv or 0))
    if st.lastSend then
        P(("Last send: %s, pcall ok=%s, result=%s, %ds ago"):format(st.lastSend.cmd, tostring(st.lastSend.ok), ResultName(st.lastSend.result), GetTime() - st.lastSend.at))
    end
    if st.lastRecv then
        P(("Last received: from %s via %s: %s (%ds ago)"):format(tostring(st.lastRecv.sender), tostring(st.lastRecv.dist), st.lastRecv.text, GetTime() - st.lastRecv.at))
    end
    P("Tip: both players run /fm debug and compare the channel id + messages received.")
end

-- /fm test : send a test message to every group (friends see it in chat)
FM.SlashExtra.test = function()
    local n = 0
    for _, g in ipairs(FriendMapDB.groups) do
        FM:SendToGroup(g, "TEST|" .. UnitName("player"))
        n = n + (FM.PeerCount and FM:PeerCount(g.code) or 0)
    end
    if FM.AskAllLists then FM:AskAllLists() end
    if n == 0 then FM:Print("|cffffaa00Nobody else found in your group channels yet (they must be online and on 1.5.0+).|r") end
    FM:Print("Test message sent. Your friends should see 'test received' in their chat.")
end
FM.Handlers.TEST = function(self, p, code, sender, short)
    local g = self:GetGroup(code)
    self:Print(("|cff33ff33Test received from %s in group %s - the connection works!|r"):format(short, g and g.name or code))
end
