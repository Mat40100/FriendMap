-- Transport: WoW Forever silently drops addon messages sent in custom channels.
-- The hidden group channel is now used only to know WHO is online (its member
-- list + join/leave notices); data goes as invisible addon whispers to each of them.
local FM = FriendMap

local LIST_EVERY   = 60     -- re-read each channel's member list (s)
local LIST_HIDE    = 5      -- hide the member-list reply printed by the game (s)
local QUEUE_RATE   = 0.12   -- min seconds between two addon whispers
local MISSED_HIDE  = 30     -- hide "No player named" for names we whispered recently

FM.peers = {}               -- [code][lowercase name] = name as the game gives it
local listAsked = {}        -- [channel name upper] = GetTime()
local missed = {}           -- [lowercase short name] = GetTime()
local whispered = {}        -- [lowercase short name] = GetTime() of last send
local queue, qHead = {}, 1

local me = UnitName("player")
local function Key(name) return Ambiguate(name or "", "none"):lower() end
local function Readable(s) return type(s) == "string" and not (issecretvalue and issecretvalue(s)) end

-- channel name -> group
local function GroupOfChannel(ch)
    if not Readable(ch) then return end
    ch = ch:gsub("^%d+%.%s*", ""):upper()
    for _, g in ipairs(FriendMapDB.groups) do
        if FM:ChannelName(g.code):upper() == ch then return g end
    end
end

local function Peers(code)
    FM.peers[code] = FM.peers[code] or {}
    return FM.peers[code]
end

function FM:AddPeer(code, name)
    if not Readable(name) or name == "" then return end
    if FM:IsMe(name) then return end
    local p = Peers(code)
    local k = Key(name)
    if p[k] then return end
    p[k] = name
    missed[k] = nil
    -- say hello right away so they see us
    C_Timer.After(0.5, function() FM:BroadcastPosition(true) end)
    return true
end

function FM:RemovePeer(code, name)
    local k = Key(name)
    if FM.peers[code] then FM.peers[code][k] = nil end
    for sender in pairs(self.members[code] or {}) do
        if Key(sender) == k then self:RemoveMember(code, sender) end
    end
    self:RefreshUI()
end

function FM:PeerCount(code)
    local n = 0
    for _ in pairs(FM.peers[code] or {}) do n = n + 1 end
    return n
end

local function AskList(g)
    local ch = FM:ChannelName(g.code)
    if GetChannelName(ch) == 0 then return end
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return end
    listAsked[ch:upper()] = GetTime()
    pcall(ListChannelByName, ch)
end

function FM:AskAllLists()
    for _, g in ipairs(FriendMapDB.groups) do AskList(g) end
end

----------------------------------------------------------------------
-- Sending (throttled queue of addon whispers)
----------------------------------------------------------------------
local pump = CreateFrame("Frame")
local acc = 0
pump:Hide()
pump:SetScript("OnUpdate", function(self, e)
    acc = acc + e
    if acc < QUEUE_RATE then return end
    acc = 0
    local item = queue[qHead]
    if not item then
        queue, qHead = {}, 1
        self:Hide()
        return
    end
    queue[qHead] = nil
    qHead = qHead + 1
    -- a newer position to the same peer supersedes this one
    if item.superseded then return end
    FM.lastStep = "SendAddonMessage WHISPER " .. item.msg:sub(1, 3)
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, FM.PREFIX, item.msg, "WHISPER", item.to)
    whispered[Key(item.to)] = GetTime()
    FM.stats = FM.stats or { sent = 0, recv = 0 }
    FM.stats.sent = FM.stats.sent + 1
    FM.stats.lastSend = { ok = ok, result = result, cmd = item.msg:sub(1, 4), at = GetTime() }
end)

local lastPos = {}          -- [peer key .. code] = queue item (to drop stale positions)

function FM:SendToGroup(g, msg)
    if not self:IsConnected(g) then return end
    local full = msg .. "|" .. g.code
    local isPos = msg:sub(1, 2) == "P|"
    for k, name in pairs(Peers(g.code)) do
        local item = { to = name, msg = full }
        if isPos then
            local id = k .. g.code
            if lastPos[id] then lastPos[id].superseded = true end
            lastPos[id] = item
        end
        queue[#queue + 1] = item
    end
    pump:Show()
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local function PatternFor(fmt)
    if not fmt then return end
    local esc = fmt:gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0")
    return "^" .. esc:gsub("%%%%s", "(.+)"):gsub("%%%%d", "%%d+") .. "$"
end
local notFoundPat = PatternFor(ERR_CHAT_PLAYER_NOT_FOUND_S)

local function NotFoundName(text)
    if not notFoundPat or not Readable(text) then return end
    local name = text:match(notFoundPat)
    if not name then return end
    local k = Key(name)
    local t = whispered[k] or missed[k]
    if t and GetTime() - t < MISSED_HIDE then return name end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_CHANNEL_LIST")
ev:RegisterEvent("CHAT_MSG_CHANNEL_JOIN")
ev:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE")
ev:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
ev:RegisterEvent("CHAT_MSG_SYSTEM")
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_CHANNEL_LIST" then
        local text, _, _, chString, _, _, _, _, chName = ...
        local g = GroupOfChannel(chName ~= "" and chName or chString)
        if not g or not Readable(text) then return end
        local changed
        for entry in text:gmatch("[^,]+") do
            local name = entry:gsub("^%s*[%*@%+]*", ""):gsub("%s+$", "")
            if FM:AddPeer(g.code, name) then changed = true end
        end
        if changed then FM:RefreshUI() end
    elseif event == "CHAT_MSG_CHANNEL_JOIN" then
        local _, sender, _, _, _, _, _, _, chName = ...
        local g = GroupOfChannel(chName)
        if g and FM:AddPeer(g.code, sender) then FM:RefreshUI() end
    elseif event == "CHAT_MSG_CHANNEL_LEAVE" then
        local _, sender, _, _, _, _, _, _, chName = ...
        local g = GroupOfChannel(chName)
        if g and Readable(sender) then FM:RemovePeer(g.code, sender) end
    elseif event == "CHAT_MSG_CHANNEL_NOTICE" then
        local kind, _, _, _, _, _, _, _, chName = ...
        local g = GroupOfChannel(chName)
        if g and kind == "YOU_CHANGED" or (g and kind == "YOU_JOINED") then
            C_Timer.After(1, function() AskList(g) end)
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        local name = NotFoundName((...))
        if name then
            local k = Key(name)
            missed[k] = GetTime()
            for code in pairs(FM.peers) do FM:RemovePeer(code, name) end
        end
    end
end)

-- keep the member-list reply and "No player named" errors out of the chat
local addFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
if addFilter then
    addFilter("CHAT_MSG_CHANNEL_LIST", function(_, _, _, _, _, chString, _, _, _, _, chName)
        local g = GroupOfChannel(Readable(chName) and chName ~= "" and chName or chString)
        if not g then return false end
        local t = listAsked[FM:ChannelName(g.code):upper()]
        return t ~= nil and GetTime() - t < LIST_HIDE
    end)
    addFilter("CHAT_MSG_SYSTEM", function(_, _, text) return NotFoundName(text) ~= nil end)
    for _, e in ipairs({ "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE" }) do
        addFilter(e, function(_, _, _, _, _, _, _, _, _, _, chName) return GroupOfChannel(chName) ~= nil end)
    end
end

-- periodic member-list refresh
local t = LIST_EVERY - 10   -- first read ~10 s after login
C_Timer.NewTicker(5, function()
    t = t + 5
    if not FM.worldReady then return end
    if t >= LIST_EVERY then t = 0; FM:AskAllLists() end
end)
