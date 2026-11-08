-- FriendMap: share your position with friend groups over hidden addon channels.
local ADDON = ...
local FM = {}
_G.FriendMap = FM

local HBD = LibStub("HereBeDragons-2.0")

FM.PREFIX        = "FriendMap"
FM.CHANNEL_TAG   = "FMap"         -- channel name = FMap<code>
FM.SEND_INTERVAL = 2              -- seconds between position checks
FM.HEARTBEAT     = 15             -- resend even when standing still
FM.EXPIRE        = 45             -- forget members silent for this long
FM.LINK_TAG      = "friendmap"

FM.members = {}                   -- [code][senderName] = {class, level, inst, x, y, t}

local playerName = UnitName("player")
local CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

----------------------------------------------------------------------
-- Utils
----------------------------------------------------------------------
function FM:Print(...)
    print("|cff33ff99FriendMap|r:", ...)
end

local function RandomString(len)
    local t = {}
    for i = 1, len do
        local n = math.random(1, #CODE_CHARS)
        t[i] = CODE_CHARS:sub(n, n)
    end
    return table.concat(t)
end

local function Sanitize(name)
    name = (name or ""):gsub("[^%w %-_']", ""):sub(1, 24)
    name = strtrim(name)
    return name ~= "" and name or "Friends"
end

FM.Sanitize = Sanitize

function FM:ChannelName(code) return self.CHANNEL_TAG .. code end

function FM:Groups() return FriendMapDB.groups end

function FM:GetGroup(code)
    for i, g in ipairs(FriendMapDB.groups) do
        if g.code == code then return g, i end
    end
end

-- Resolve a group by list index, code, or (partial) name.
function FM:FindGroup(key)
    if not key or key == "" then return FriendMapDB.groups[1] end
    local n = tonumber(key)
    if n then return FriendMapDB.groups[n] end
    local up, low = key:upper(), key:lower()
    for _, g in ipairs(FriendMapDB.groups) do
        if g.code == up or g.name:lower() == low then return g end
    end
    for _, g in ipairs(FriendMapDB.groups) do
        if g.name:lower():find(low, 1, true) then return g end
    end
end

----------------------------------------------------------------------
-- Share links
--   Plain code (copy/paste anywhere, Discord, ...):  FMAP:<code>:<pw>:<name>
--   Clickable in-game chat link: |Haddon:FriendMap:<code>:<pw>:<name>|h[...]|h
----------------------------------------------------------------------
function FM:GetShareCode(g)
    return ("FMAP:%s:%s:%s"):format(g.code, g.password, g.name)
end

function FM:GetChatLink(g)
    return ("|cff33ff99|Haddon:FriendMap:%s:%s:%s|h[FriendMap: %s]|h|r"):format(
        g.code, g.password, g.name, g.name)
end

function FM:ParseShareCode(text)
    text = strtrim(text or "")
    local code, pw, name = text:match("FMAP:(%w+):(%w+):?(.*)")
    if code then return code:upper(), pw, Sanitize(name) end
end

----------------------------------------------------------------------
-- Group management
----------------------------------------------------------------------
function FM:CreateGroup(name)
    local g = { name = Sanitize(name), code = RandomString(8), password = RandomString(6), owner = playerName }
    table.insert(FriendMapDB.groups, g)
    self:JoinChannel(g)
    self:Print(("Created group |cffffd100%s|r. Share code: |cffffffff%s|r"):format(g.name, self:GetShareCode(g)))
    self:RefreshUI()
    return g
end

function FM:JoinGroup(code, password, name)
    if not code or not password then
        self:Print("Invalid group code. Expected FMAP:<code>:<password>:<name>")
        return
    end
    local g = self:GetGroup(code)
    if g then
        self:Print(("Already in group |cffffd100%s|r."):format(g.name))
        return g
    end
    g = { name = Sanitize(name), code = code, password = password }
    table.insert(FriendMapDB.groups, g)
    self:JoinChannel(g)
    self:Print(("Joined group |cffffd100%s|r."):format(g.name))
    self:RefreshUI()
    return g
end

function FM:LeaveGroup(g)
    local _, idx = self:GetGroup(g.code)
    if not idx then return end
    self:SendToGroup(g, "BYE")
    local ch = self:ChannelName(g.code)
    FM.lastStep = "LeaveChannelByName"
    if GetChannelName(ch) > 0 then LeaveChannelByName(ch) end
    table.remove(FriendMapDB.groups, idx)
    for sender in pairs(self.members[g.code] or {}) do
        self:RemoveMember(g.code, sender)
    end
    self.members[g.code] = nil
    self:Print(("Left group |cffffd100%s|r."):format(g.name))
    self:RefreshUI()
end

----------------------------------------------------------------------
-- Channels
----------------------------------------------------------------------
local function HideChannelFromChat(ch)
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local f = _G["ChatFrame" .. i]
        if f then
            if ChatFrame_RemoveChannel then pcall(ChatFrame_RemoveChannel, f, ch)
            elseif f.RemoveChannel then pcall(f.RemoveChannel, f, ch) end
        end
    end
end

-- Don't grab /1 or /2 before General/Trade got joined on login.
local function DefaultChannelsReady()
    return GetChannelName(1) > 0 or GetChannelName(2) > 0 or (GetTime() - (FM.worldTime or 0)) > 20
end

function FM:JoinChannel(g)
    local ch = self:ChannelName(g.code)
    if GetChannelName(ch) > 0 then return true end
    if not self.worldReady or not DefaultChannelsReady() then return false end
    if not self.inHardwareEvent then
        self.needJoin = true   -- will join on the next click
        return false
    end
    FM.lastStep = "JoinTemporaryChannel"
    if not pcall(JoinTemporaryChannel, ch, g.password) then return false end
    FM.lastStep = "HideChannelFromChat"
    HideChannelFromChat(ch)
    FM.lastStep = "after join"
    return GetChannelName(ch) > 0
end

-- Run fn inside a user click, where channel joins are allowed.
function FM:WithHardware(fn)
    self.inHardwareEvent = true
    local ok, err = pcall(fn)
    self.inHardwareEvent = false
    if not ok then geterrorhandler()(err) end
end

local function OnAnyClick()
    if FM.needJoin and FM.worldReady then
        FM.needJoin = false
        FM:WithHardware(function() FM:EnsureChannels() end)
    end
end
WorldFrame:HookScript("OnMouseDown", OnAnyClick)
Minimap:HookScript("OnMouseDown", OnAnyClick)

function FM:EnsureChannels()
    for _, g in ipairs(FriendMapDB.groups) do self:JoinChannel(g) end
end

function FM:IsConnected(g)
    return GetChannelName(self:ChannelName(g.code)) > 0
end

function FM:SendToGroup(g, msg)
    local id = GetChannelName(self:ChannelName(g.code))
    if id and id > 0 then
        FM.lastStep = "SendAddonMessage CHANNEL " .. msg:sub(1, 3)
        C_ChatInfo.SendAddonMessage(self.PREFIX, msg .. "|" .. g.code, "CHANNEL", id)
    end
end

----------------------------------------------------------------------
-- Position broadcast
----------------------------------------------------------------------
local lastX, lastY, lastInst, lastSend = 0, 0, 0, 0

function FM:BroadcastPosition(force)
    if not FriendMapDB.sharing or #FriendMapDB.groups == 0 then return end
    local x, y, inst = HBD:GetPlayerWorldPosition()
    if not x or not inst then return end
    local now = GetTime()
    local moved = inst ~= lastInst or math.abs(x - lastX) + math.abs(y - lastY) > 1
    if not force and not moved and now - lastSend < self.HEARTBEAT then return end
    lastX, lastY, lastInst, lastSend = x, y, inst, now

    local _, class = UnitClass("player")
    local pvpLeft = math.max(0, math.floor((self.pvpUntil or 0) - now))
    local status = (FriendMapDB.status or ""):gsub("[|:]", "")
    local msg = ("P|%d|%.1f|%.1f|%s|%d|%d|%s"):format(inst, x, y, class or "WARRIOR", UnitLevel("player") or 0, pvpLeft, status)
    for _, g in ipairs(FriendMapDB.groups) do self:SendToGroup(g, msg) end
end

----------------------------------------------------------------------
-- World PvP detection (combat log: hostile player <-> me, outside BG/arena)
----------------------------------------------------------------------
FM.PVP_RECENT  = 60   -- seconds an icon stays "in PvP" after the last hit
FM.PVP_REALERT = 120  -- don't re-announce a new fight within this window

local function IsWorldPvPArea()
    local inInstance, kind = IsInInstance()
    return not inInstance or kind == "none"
end

-- The combat log is off-limits to addons on this client, so instead, while we
-- are in combat, look at target/focus/nameplates for hostile players fighting us.
local function IsHostilePlayerFightingMe(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then return false end
    if not UnitAffectingCombat(unit) then return false end
    return UnitIsUnit(unit .. "target", "player") or UnitIsUnit("target", unit)
end

FM.IsHostilePlayerFightingMe = IsHostilePlayerFightingMe
FM.IsWorldPvPArea = IsWorldPvPArea

local function FindEnemy()
    for _, u in ipairs({ "target", "focus", "mouseover" }) do
        if IsHostilePlayerFightingMe(u) then return UnitName(u) end
    end
    for i = 1, 40 do
        local u = "nameplate" .. i
        if IsHostilePlayerFightingMe(u) then return UnitName(u) end
    end
end

function FM:CheckPvP()
    if not UnitAffectingCombat("player") or not IsWorldPvPArea() then return end
    local enemy = FindEnemy()
    if not enemy then return end
    local now = GetTime()
    local wasInFight = (self.pvpUntil or 0) > now
    self.pvpUntil = now + self.PVP_RECENT
    if not wasInFight then
        self:BroadcastPosition(true) -- push the red flag immediately
        if FriendMapDB.pvpAnnounce and FriendMapDB.sharing and now - (self.lastPvPAlert or -999) > self.PVP_REALERT then
            self.lastPvPAlert = now
            local zone = (GetSubZoneText() ~= "" and GetSubZoneText() .. ", " or "") .. GetZoneText()
            local msg = ("F|%s|%s"):format(zone:gsub("|", ""), (Ambiguate(enemy or "", "none"):gsub("|", "")))
            for _, g in ipairs(FriendMapDB.groups) do self:SendToGroup(g, msg) end
        end
    end
end

----------------------------------------------------------------------
-- Receiving
----------------------------------------------------------------------
function FM:RemoveMember(code, sender)
    if self.members[code] then self.members[code][sender] = nil end
    if self.Pins then self.Pins:Refresh() end
end

function FM:OnAddonMessage(text, distribution, sender)
    local short = Ambiguate(sender, "none")
    if short == playerName then return end

    local parts = { strsplit("|", text) }
    local cmd = parts[1]

    if distribution == "WHISPER" and cmd == "INV" then
        -- INV|code|password|name
        local code, pw, name = parts[2], parts[3], Sanitize(parts[4])
        if code and pw and not self:GetGroup(code) then
            StaticPopup_Show("FRIENDMAP_INVITE", short, name, { code = code, password = pw, name = name })
        end
        return
    end

    if distribution ~= "CHANNEL" then return end
    local code = parts[#parts]
    if not self:GetGroup(code) then return end
    self.members[code] = self.members[code] or {}

    if cmd == "P" then
        local inst, x, y = tonumber(parts[2]), tonumber(parts[3]), tonumber(parts[4])
        if not (inst and x and y) then return end
        local m = self.members[code][sender] or {}
        local isNew = m.t == nil
        m.name, m.inst, m.x, m.y, m.class, m.level, m.t = short, inst, x, y, parts[5], tonumber(parts[6]), GetTime()
        local pvpLeft = tonumber(parts[7]) or 0
        m.pvpUntil = pvpLeft > 0 and (GetTime() + pvpLeft) or nil
        m.status = (parts[8] and parts[8] ~= code and parts[8] ~= "") and parts[8] or nil
        if self.OnMemberMoved then self:OnMemberMoved(m) end
        self.members[code][sender] = m
        if isNew then
            -- greet newcomers so they see us right away
            self:BroadcastPosition(true)
            self:RefreshUI()
        end
        if self.Pins then self.Pins:Refresh() end
    elseif cmd == "F" then
        -- F|zone|enemy|code : a group member entered a world PvP fight
        local g = self:GetGroup(code)
        local m = self.members[code][sender]
        if m then m.pvpUntil = GetTime() + self.PVP_RECENT; if self.Pins then self.Pins:Refresh() end end
        local msg = ("|cffff3333[%s] %s is in a world PvP fight|r at |cffffd100%s|r%s"):format(
            g.name, short, parts[2] or "?", (parts[3] and parts[3] ~= "") and (" vs " .. parts[3]) or "")
        self:Print(msg)
        if FriendMapDB.pvpAlert and RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame, short .. " is in a world PvP fight!", ChatTypeInfo["RAID_WARNING"])
        end
        PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959)
    elseif self.Handlers and self.Handlers[cmd] then
        self.Handlers[cmd](self, parts, code, sender, short)
    elseif cmd == "BYE" then
        self:RemoveMember(code, sender)
        self:RefreshUI()
    end
end

function FM:ExpireMembers()
    local now, changed = GetTime(), false
    for code, list in pairs(self.members) do
        for sender, m in pairs(list) do
            if now - m.t > self.EXPIRE then list[sender] = nil; changed = true end
        end
    end
    if changed then
        if self.Pins then self.Pins:Refresh() end
        self:RefreshUI()
    end
end

function FM:CountMembers(code)
    local n = 0
    for _ in pairs(self.members[code] or {}) do n = n + 1 end
    return n
end

----------------------------------------------------------------------
-- Invites
----------------------------------------------------------------------
function FM:Invite(target, g)
    g = g or FriendMapDB.groups[1]
    if not g then self:Print("Create or join a group first.") return end
    if not target or target == "" then self:Print("Usage: /fm invite <player> [group]") return end
    C_ChatInfo.SendAddonMessage(self.PREFIX, ("INV|%s|%s|%s"):format(g.code, g.password, g.name), "WHISPER", target)
    self:Print(("Invitation to |cffffd100%s|r sent to %s. (They need FriendMap installed; otherwise send them the share code.)"):format(g.name, target))
end

StaticPopupDialogs["FRIENDMAP_INVITE"] = {
    text = "%s invites you to the FriendMap group |cffffd100%s|r.\nJoin and share your position?",
    button1 = ACCEPT, button2 = DECLINE,
    OnAccept = function(_, data) FM:WithHardware(function() FM:JoinGroup(data.code, data.password, data.name) end) end,
    timeout = 60, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["FRIENDMAP_JOIN_LINK"] = {
    text = "Join the FriendMap group |cffffd100%s|r?",
    button1 = ACCEPT, button2 = CANCEL,
    OnAccept = function(_, data) FM:WithHardware(function() FM:JoinGroup(data.code, data.password, data.name) end) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- Clickable chat links (hooked securely, never replacing Blizzard's SetItemRef)
hooksecurefunc("SetItemRef", function(link)
    if type(link) ~= "string" then return end
    local _, tag, code, pw, name = strsplit(":", link)
    if tag ~= "FriendMap" or not code or not pw then return end
    if FM:GetGroup(code) then FM:Print("You are already in that group.") return end
    StaticPopup_Show("FRIENDMAP_JOIN_LINK", Sanitize(name), nil, { code = code, password = pw, name = Sanitize(name) })
end)

function FM:PostLinkToChat(g)
    local link = self:GetChatLink(g)
    if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
        ChatEdit_InsertLink(link)
    else
        ChatFrame_OpenChat(link)
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("CHANNEL_UI_UPDATE")
ev:RegisterEvent("ADDON_ACTION_FORBIDDEN")
ev:RegisterEvent("ADDON_ACTION_BLOCKED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON then
        FriendMapDB = FriendMapDB or {}
        FriendMapDB.groups = FriendMapDB.groups or {}
        if FriendMapDB.sharing == nil then FriendMapDB.sharing = true end
        if FriendMapDB.minimap == nil then FriendMapDB.minimap = true end
        if FriendMapDB.pvpAnnounce == nil then FriendMapDB.pvpAnnounce = true end  -- tell my groups when I fight
        if FriendMapDB.pvpAlert == nil then FriendMapDB.pvpAlert = true end        -- big on-screen warning for others' fights
        C_ChatInfo.RegisterAddonMessagePrefix(FM.PREFIX)
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not FM.worldReady then
            FM.worldTime = GetTime()
            C_Timer.After(5, function()
                FM.worldReady = true
                FM:EnsureChannels()
                FM:BroadcastPosition(true)
                FM:RefreshUI()
            end)
        else
            FM:BroadcastPosition(true)
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, distribution, sender = ...
        if prefix == FM.PREFIX then FM:OnAddonMessage(text, distribution, sender) end
    elseif event == "ADDON_ACTION_FORBIDDEN" or event == "ADDON_ACTION_BLOCKED" then
        local who, func = ...
        if who == ADDON then
            local line = ("%s %s: %s | last step: %s"):format(date("%H:%M:%S"), event, tostring(func), tostring(FM.lastStep))
            FriendMapDB.debug = FriendMapDB.debug or {}
            table.insert(FriendMapDB.debug, line)
            FM:Print("|cffff5555blocked:|r " .. tostring(func) .. " (during " .. tostring(FM.lastStep) .. ")")
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        FM:CheckPvP()
    elseif event == "CHANNEL_UI_UPDATE" then
        FM:RefreshUI()
    elseif event == "PLAYER_LOGOUT" then
        for _, g in ipairs(FriendMapDB.groups) do FM:SendToGroup(g, "BYE") end
    end
end)

-- fast PvP check while in combat
C_Timer.NewTicker(1, function()
    if not FM.worldReady then return end
    FM:CheckPvP()
    if FM.OnTick then FM:OnTick() end
end)

local elapsedJoin = 0
C_Timer.NewTicker(FM.SEND_INTERVAL, function()
    if not FM.worldReady then return end
    FM:BroadcastPosition()
    FM:ExpireMembers()
    FM.Pins:Refresh() -- lets red PvP glows fade out on time
    elapsedJoin = elapsedJoin + FM.SEND_INTERVAL
    if elapsedJoin >= 10 then elapsedJoin = 0; FM:EnsureChannels() end
end)

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
SLASH_FRIENDMAP1, SLASH_FRIENDMAP2 = "/fm", "/friendmap"
SlashCmdList.FRIENDMAP = function(msg) FM:WithHardware(function() FM:Slash(msg) end) end
function FM:Slash(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "" or cmd == "show" then
        FM:ToggleUI()
    elseif cmd == "create" then
        FM:CreateGroup(rest)
    elseif cmd == "join" then
        FM:JoinGroup(FM:ParseShareCode(rest))
    elseif cmd == "invite" then
        local target, key = rest:match("^(%S+)%s*(.*)$")
        FM:Invite(target, FM:FindGroup(key))
    elseif cmd == "leave" then
        local g = FM:FindGroup(rest)
        if g then FM:LeaveGroup(g) else FM:Print("No such group.") end
    elseif cmd == "link" then
        local g = FM:FindGroup(rest)
        if g then FM:PostLinkToChat(g) else FM:Print("No such group.") end
    elseif cmd == "code" then
        local g = FM:FindGroup(rest)
        if g then FM:ShowCopyBox(g) else FM:Print("No such group.") end
    elseif cmd == "share" then
        FriendMapDB.sharing = not FriendMapDB.sharing
        FM:Print("Position sharing " .. (FriendMapDB.sharing and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        if not FriendMapDB.sharing then
            for _, g in ipairs(FriendMapDB.groups) do FM:SendToGroup(g, "BYE") end
        end
        FM:RefreshUI()
    elseif cmd == "minimap" then
        FriendMapDB.minimap = not FriendMapDB.minimap
        FM.Pins:Refresh()
        FM:Print("Minimap icons " .. (FriendMapDB.minimap and "ON" or "OFF"))
    elseif cmd == "pvp" then
        FriendMapDB.pvpAnnounce = not FriendMapDB.pvpAnnounce
        FM:Print("Announce my world PvP fights " .. (FriendMapDB.pvpAnnounce and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
        FM:RefreshUI()
    elseif cmd == "pvpalert" then
        FriendMapDB.pvpAlert = not FriendMapDB.pvpAlert
        FM:Print("On-screen alert for friends' PvP fights " .. (FriendMapDB.pvpAlert and "ON" or "OFF"))
    elseif FM.SlashExtra and FM.SlashExtra[cmd] then
        FM.SlashExtra[cmd](rest)
    elseif cmd == "list" then
        for i, g in ipairs(FriendMapDB.groups) do
            FM:Print(("%d. %s (%d online) %s"):format(i, g.name, FM:CountMembers(g.code),
                FM:IsConnected(g) and "" or "|cffff5555[not connected]|r"))
        end
    else
        FM:Print("Commands:")
        print("  /fm  - open the window")
        print("  /fm create <name>  - create a group")
        print("  /fm join FMAP:...  - join with a share code")
        print("  /fm invite <player> [group]  - invite someone")
        print("  /fm link [group]  - post a clickable link in chat")
        print("  /fm code [group]  - show the share code to copy")
        print("  /fm leave [group] | /fm list | /fm share | /fm minimap")
        print("  /fm pvp  - toggle announcing my world PvP fights")
        print("  /fm pvpalert  - toggle on-screen warning for friends' fights")
        print("  /fm ping [text] | /fm help | /fm status <text> | /fm track <name>")
        print("  /fm rally | /fm rally clear | /fm top | /fm trails | /fm heatmap")
        print("  Map: Alt+click = ping, Alt+Shift+click = rally point, click a friend = track")
    end
end
