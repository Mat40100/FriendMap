-- FriendMap extras: map pings, help calls, trails, distance/arrow, status,
-- PvP kill feed + weekly leaderboard, level/achievement news, rally point, zone heatmap.
local FM = FriendMap
local HBD = LibStub("HereBeDragons-2.0")
local HBDP = LibStub("HereBeDragons-Pins-2.0")

FM.Handlers = {}
FM.SlashExtra = {}

local MarkerRef, TrailRef, HeatRef = {}, {}, {}
local DISC = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local PI2 = math.pi * 2

local function Sound(id, fallback)
    pcall(PlaySound, id or fallback)
end

local function ZoneName()
    local sub = GetSubZoneText()
    return ((sub and sub ~= "") and (sub .. ", ") or "") .. (GetZoneText() or "?")
end

local function Clean(s) return (tostring(s or ""):gsub("[|]", "")) end

local function Broadcast(msg)
    if not FriendMapDB.sharing then return end
    for _, g in ipairs(FriendMapDB.groups) do FM:SendToGroup(g, msg) end
end

local function Defaults()
    local db = FriendMapDB
    if db.trails == nil then db.trails = true end
    if db.heatmap == nil then db.heatmap = true end
    if db.autoHelp == nil then db.autoHelp = true end
    db.status = db.status or ""
    db.kills = db.kills or {}
end

----------------------------------------------------------------------
-- Distance & direction
----------------------------------------------------------------------
local DIRS = { "N", "NW", "W", "SW", "S", "SE", "E", "NE" } -- angle grows counter-clockwise from north

function FM:VectorTo(inst, x, y)
    local px, py, pinst = HBD:GetPlayerWorldPosition()
    if not px or pinst ~= inst then return end
    local angle, dist = HBD:GetWorldVector(inst, px, py, x, y)
    if not angle then return end
    local idx = math.floor((angle + math.pi / 8) / (math.pi / 4)) % 8 + 1
    return dist, angle, DIRS[idx]
end

function FM:DistanceText(inst, x, y)
    local dist, _, dir = self:VectorTo(inst, x, y)
    if not dist then return "other continent" end
    return ("%d yd %s"):format(dist, dir)
end

----------------------------------------------------------------------
-- Markers (pings, help calls, rally flag)
----------------------------------------------------------------------
local function CreateMarker(parent, size, r, g, b, iconPath, label)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.disc = f:CreateTexture(nil, "BACKGROUND")
    f.disc:SetPoint("CENTER")
    f.disc:SetSize(size, size)
    f.disc:SetTexture(DISC)
    f.disc:SetVertexColor(r, g, b, 0.9)
    local ag = f.disc:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local sc = ag:CreateAnimation("Scale")
    if sc.SetScaleFrom then sc:SetScaleFrom(0.4, 0.4); sc:SetScaleTo(1.6, 1.6) else sc:SetScale(1.6, 1.6) end
    sc:SetDuration(1)
    local al = ag:CreateAnimation("Alpha")
    al:SetFromAlpha(1); al:SetToAlpha(0); al:SetDuration(1)
    ag:Play()
    f.anim = ag
    if iconPath then
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetPoint("CENTER")
        f.icon:SetSize(size * 0.6, size * 0.6)
        f.icon:SetTexture(iconPath)
    end
    if label then
        f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.label:SetPoint("TOP", f, "BOTTOM", 0, -1)
        f.label:SetText(label)
        f.label:SetTextColor(r, g, b)
    end
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.tip, r, g, b)
        if self.inst then GameTooltip:AddLine(FM:DistanceText(self.inst, self.wx, self.wy), 1, 1, 1) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)
    return f
end

local markers = {}

local KINDS = {
    ping  = { r = 1,   g = 0.85, b = 0.1, icon = nil, life = 30 },
    help  = { r = 1,   g = 0.1,  b = 0.1, icon = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew", life = 60 },
    rally = { r = 0.2, g = 0.6,  b = 1,   icon = "Interface\\Icons\\Ability_Warrior_BattleShout", life = 1800 },
}

function FM:ShowMarker(kind, inst, x, y, tip, label)
    local k = KINDS[kind]
    local w = CreateMarker(WorldMapFrame, 28, k.r, k.g, k.b, k.icon, label)
    local m = CreateMarker(Minimap, 16, k.r, k.g, k.b, k.icon)
    for _, f in ipairs({ w, m }) do f.tip, f.inst, f.wx, f.wy = tip, inst, x, y end
    HBDP:AddWorldMapIconWorld(MarkerRef, w, inst, x, y, HBD_PINS_WORLDMAP_SHOW_WORLD)
    HBDP:AddMinimapIconWorld(MarkerRef, m, inst, x, y, true)
    local entry = { w = w, m = m, kind = kind, expires = GetTime() + k.life }
    table.insert(markers, entry)
    return entry
end

function FM:RemoveMarker(e)
    HBDP:RemoveWorldMapIcon(MarkerRef, e.w); e.w:Hide()
    HBDP:RemoveMinimapIcon(MarkerRef, e.m); e.m:Hide()
    e.expires = 0
end

local function ExpireMarkers()
    local now = GetTime()
    for i = #markers, 1, -1 do
        local e = markers[i]
        if e.expires <= now then
            if e.w:IsShown() or e.m:IsShown() then FM:RemoveMarker(e) end
            table.remove(markers, i)
        end
    end
end

----------------------------------------------------------------------
-- 1. Map ping   (Alt+click on the world map, or /fm ping [text])
----------------------------------------------------------------------
local lastPing = 0

function FM:SendPing(inst, x, y, text)
    if GetTime() - lastPing < 1 then return end
    lastPing = GetTime()
    text = Clean(text):sub(1, 40)
    local me = UnitName("player")
    self:ShowMarker("ping", inst, x, y, me .. (text ~= "" and (": " .. text) or " pinged here"), me)
    Broadcast(("PING|%d|%.1f|%.1f|%s"):format(inst, x, y, text))
    Sound(SOUNDKIT and SOUNDKIT.MAP_PING, 3175)
end

FM.Handlers.PING = function(self, p, code, sender, short)
    local inst, x, y, text = tonumber(p[2]), tonumber(p[3]), tonumber(p[4]), p[5]
    if not (inst and x and y) then return end
    text = (text and text ~= code) and text or ""
    self:ShowMarker("ping", inst, x, y, short .. (text ~= "" and (": " .. text) or " pinged here"), short)
    self:Print(("|cffffd100%s pinged the map|r%s (%s)"):format(short, text ~= "" and (": " .. text) or "", self:DistanceText(inst, x, y)))
    Sound(SOUNDKIT and SOUNDKIT.MAP_PING, 3175)
end

local function MapCursorWorld()
    local mapID = WorldMapFrame:GetMapID()
    local sc = WorldMapFrame.ScrollContainer
    if not mapID or not sc or not sc.GetNormalizedCursorPosition then return end
    local cx, cy = sc:GetNormalizedCursorPosition()
    if not cx then return end
    local x, y, inst = HBD:GetWorldCoordinatesFromZone(cx, cy, mapID)
    if x and inst then return x, y, inst end
end

if WorldMapFrame and WorldMapFrame.ScrollContainer then
    WorldMapFrame.ScrollContainer:HookScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not IsAltKeyDown() then return end
        local x, y, inst = MapCursorWorld()
        if not x then return end
        if IsShiftKeyDown() then FM:SetRally(inst, x, y) else FM:SendPing(inst, x, y) end
    end)
end

FM.SlashExtra.ping = function(rest)
    local x, y, inst = HBD:GetPlayerWorldPosition()
    if x then FM:SendPing(inst, x, y, rest) end
end

----------------------------------------------------------------------
-- 2. Help!   (button / /fm help, automatic below 30% HP in a PvP fight)
----------------------------------------------------------------------
local lastHelp = -999

function FM:SendHelp(auto)
    local now = GetTime()
    if now - lastHelp < (auto and 60 or 5) then return end
    local x, y, inst = HBD:GetPlayerWorldPosition()
    if not x then return end
    lastHelp = now
    local hp = math.floor(100 * UnitHealth("player") / math.max(1, UnitHealthMax("player")))
    Broadcast(("HELP|%d|%.1f|%.1f|%d"):format(inst, x, y, hp))
    self:Print("|cffff3333Help call sent to your groups.|r")
end

FM.Handlers.HELP = function(self, p, code, sender, short)
    local inst, x, y, hp = tonumber(p[2]), tonumber(p[3]), tonumber(p[4]), tonumber(p[5]) or 0
    if not (inst and x and y) then return end
    self:ShowMarker("help", inst, x, y, short .. " needs help! (" .. hp .. "% HP)", short .. " !")
    local msg = ("%s needs help! %d%% HP - %s"):format(short, hp, self:DistanceText(inst, x, y))
    self:Print("|cffff3333" .. msg .. "|r")
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
    end
    Sound(SOUNDKIT and SOUNDKIT.RAID_WARNING, 8959)
    self:Track(short, true)
end

FM.SlashExtra.help = function() FM:SendHelp(false) end
FM.SlashExtra.autohelp = function()
    FriendMapDB.autoHelp = not FriendMapDB.autoHelp
    FM:Print("Automatic help call at low health in PvP: " .. (FriendMapDB.autoHelp and "ON" or "OFF"))
end

local function CheckAutoHelp()
    if not FriendMapDB.autoHelp or (FM.pvpUntil or 0) < GetTime() then return end
    local max = UnitHealthMax("player")
    if max > 0 and UnitHealth("player") / max < 0.3 and not UnitIsDeadOrGhost("player") then
        FM:SendHelp(true)
    end
end

----------------------------------------------------------------------
-- 3. Trails (last 3 minutes of movement, world map only)
----------------------------------------------------------------------
local TRAIL_TIME, TRAIL_MAX, TRAIL_STEP = 180, 30, 12

function FM:OnMemberMoved(m)
    m.trail = m.trail or {}
    local last = m.trail[#m.trail]
    local now = GetTime()
    if not last or last.inst ~= m.inst or (HBD:GetWorldDistance(m.inst, last.x, last.y, m.x, m.y) or 999) > TRAIL_STEP then
        table.insert(m.trail, { inst = m.inst, x = m.x, y = m.y, t = now })
    end
    while #m.trail > TRAIL_MAX or (m.trail[1] and now - m.trail[1].t > TRAIL_TIME) do
        table.remove(m.trail, 1)
    end
end

local dots, usedDots = {}, 0

local function GetDot()
    usedDots = usedDots + 1
    local d = dots[usedDots]
    if not d then
        d = CreateFrame("Frame", nil, WorldMapFrame)
        d:SetSize(6, 6)
        d.tex = d:CreateTexture(nil, "BACKGROUND")
        d.tex:SetAllPoints()
        d.tex:SetTexture(DISC)
        dots[usedDots] = d
    end
    return d
end

function FM:DrawTrails()
    HBDP:RemoveAllWorldMapIcons(TrailRef)
    for i = 1, usedDots do dots[i]:Hide() end
    usedDots = 0
    if not FriendMapDB.trails or not FM:IsAnyMapShown() then return end
    local seen, now = {}, GetTime()
    for _, list in pairs(self.members) do
        for sender, m in pairs(list) do
            if not seen[sender] and m.trail then
                seen[sender] = true
                local c = RAID_CLASS_COLORS[m.class or ""] or { r = 1, g = 1, b = 1 }
                for i = 1, #m.trail - 1 do -- skip newest point, the icon is there
                    local pt = m.trail[i]
                    local d = GetDot()
                    d.tex:SetVertexColor(c.r, c.g, c.b, 0.25 + 0.6 * (1 - (now - pt.t) / TRAIL_TIME))
                    d:Show()
                    HBDP:AddWorldMapIconWorld(TrailRef, d, pt.inst, pt.x, pt.y, HBD_PINS_WORLDMAP_SHOW_PARENT)
                end
            end
        end
    end
end

FM.SlashExtra.trails = function()
    FriendMapDB.trails = not FriendMapDB.trails
    FM:DrawTrails()
    FM:Print("Trails " .. (FriendMapDB.trails and "ON" or "OFF"))
end

----------------------------------------------------------------------
-- 4. Arrow towards a tracked friend (or the rally point)
----------------------------------------------------------------------
local arrow = CreateFrame("Frame", "FriendMapArrow", UIParent)
arrow:SetSize(56, 70)
arrow:SetPoint("TOP", UIParent, "TOP", 0, -140)
arrow:SetMovable(true)
arrow:EnableMouse(true)
arrow:RegisterForDrag("LeftButton")
arrow:SetScript("OnDragStart", arrow.StartMoving)
arrow:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    FriendMapDB.arrowPos = { p, rp, x, y }
end)
arrow:Hide()
arrow.tex = arrow:CreateTexture(nil, "ARTWORK")
arrow.tex:SetSize(42, 42)
arrow.tex:SetPoint("TOP")
arrow.tex:SetTexture("Interface\\Minimap\\MinimapArrow")
arrow.text = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
arrow.text:SetPoint("TOP", arrow.tex, "BOTTOM", 0, -2)
arrow:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then FM:Track(nil) end
end)
arrow:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("FriendMap arrow")
    GameTooltip:AddLine("Drag to move, right-click to stop tracking", 1, 1, 1)
    GameTooltip:Show()
end)
arrow:SetScript("OnLeave", GameTooltip_Hide)

local function FindMemberByName(name)
    if not name then return end
    local low, best = name:lower(), nil
    for _, list in pairs(FM.members) do
        for _, m in pairs(list) do
            if m.name:lower() == low and (not best or best.t < m.t) then best = m end
        end
    end
    return best
end

function FM:Track(name, quiet)
    self.trackName = name
    if name and not quiet then self:Print("Tracking " .. name .. " (right-click the arrow to stop).") end
    self:UpdateArrow()
end

FM.SlashExtra.track = function(rest)
    if rest == "" then FM:Track(nil) else FM:Track(rest) end
end

local function ArrowTarget()
    local m = FindMemberByName(FM.trackName)
    if m then return m.inst, m.x, m.y, m.name end
    if FM.rally then return FM.rally.inst, FM.rally.x, FM.rally.y, "Rally point" end
end

local elapsed = 0
arrow:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed < 0.05 then return end
    elapsed = 0
    local inst, x, y, label = ArrowTarget()
    if not inst then self:Hide() return end
    local dist, angle = FM:VectorTo(inst, x, y)
    if not dist then
        self.tex:SetRotation(0)
        self.text:SetText(label .. "\n|cffaaaaaaother continent|r")
        return
    end
    local facing = GetPlayerFacing and GetPlayerFacing()
    self.tex:SetRotation(facing and (angle - facing) or 0)
    if dist < 10 then
        self.tex:SetVertexColor(0.2, 1, 0.2)
        self.text:SetText(label .. "\n|cff33ff33arrived|r")
    else
        self.tex:SetVertexColor(1, 0.82, 0)
        self.text:SetText(("%s\n|cffffffff%d yd|r"):format(label, dist))
    end
end)

function FM:UpdateArrow()
    if ArrowTarget() then arrow:Show() else arrow:Hide() end
end

----------------------------------------------------------------------
-- 5. Status / mood
----------------------------------------------------------------------
function FM:SetStatus(text)
    FriendMapDB.status = Clean(text):gsub(":", ""):sub(1, 30)
    self:BroadcastPosition(true)
    self:Print(FriendMapDB.status ~= "" and ("Status: " .. FriendMapDB.status) or "Status cleared.")
    self:RefreshUI()
end

FM.SlashExtra.status = function(rest) FM:SetStatus(rest) end

----------------------------------------------------------------------
-- 6. PvP kill feed + weekly leaderboard
----------------------------------------------------------------------
local engaged, credited = {}, {}

local function WeekKey(t) return date("%Y-%W", t) end

local function ClassOf(name)
    if name == UnitName("player") then return select(2, UnitClass("player")) end
    for _, list in pairs(FM.members) do
        for _, m in pairs(list) do
            if m.name == name then return m.class end
        end
    end
end

-- Kills are stored as unique events (killer + time + victim), so merging the
-- sets other players send never counts a kill twice. Everyone ends up with the
-- same weekly leaderboard, even for kills made while they were offline.
local MAX_EVENTS = 600

local function Store()
    FriendMapDB.kills = FriendMapDB.kills or {}
    local k = FriendMapDB.kills
    if k.week ~= WeekKey() then
        k.week, k.events, k.classes = WeekKey(), {}, k.classes or {}
    end
    k.events = k.events or {}
    k.classes = k.classes or {}
    -- older versions kept counts + a short log: keep what the log has
    if k.log then
        for _, e in ipairs(k.log) do
            if e.killer and e.at and WeekKey(e.at) == k.week then
                k.events[e.killer .. "@" .. e.at .. "@" .. (e.victim or "?")] =
                    { killer = e.killer, victim = e.victim or "?", zone = e.zone or "?", at = e.at }
            end
        end
        k.log, k.counts = nil, nil
    end
    return k
end

local function SafeField(s) return (tostring(s or "?"):gsub("[|~;]", "")) end

-- add one kill; returns true if it was new
local function AddEvent(killer, victim, zone, at, class)
    at = tonumber(at)
    if not killer or not at or WeekKey(at) ~= WeekKey() then return false end
    local k = Store()
    killer, victim, zone = SafeField(killer), SafeField(victim), SafeField(zone)
    local id = killer .. "@" .. at .. "@" .. victim
    if class and class ~= "" and class ~= "?" then k.classes[killer] = class end
    if k.events[id] then return false end
    k.events[id] = { killer = killer, victim = victim, zone = zone, at = at }
    k.classes[killer] = ClassOf(killer) or k.classes[killer]
    -- keep the store bounded (drop the oldest)
    local n, oldestId, oldestAt = 0, nil, math.huge
    for eid, e in pairs(k.events) do
        n = n + 1
        if e.at < oldestAt then oldestId, oldestAt = eid, e.at end
    end
    if n > MAX_EVENTS and oldestId then k.events[oldestId] = nil end
    return true
end

local function Changed()
    if FM.RefreshLeaderboard then FM:RefreshLeaderboard() end
    FM:RefreshUI()
end

function FM:KillLog()
    local t = {}
    for _, e in pairs(Store().events) do t[#t + 1] = e end
    table.sort(t, function(a, b) return a.at > b.at end)
    return t
end

function FM:KillerClass(name)
    return ClassOf(name) or Store().classes[name]
end

function FM:WeekLabel()
    return WeekKey()
end

function FM:Leaderboard(limit)
    local counts = {}
    for _, e in pairs(Store().events) do counts[e.killer] = (counts[e.killer] or 0) + 1 end
    local t = {}
    for name, n in pairs(counts) do t[#t + 1] = { name = name, n = n } end
    table.sort(t, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end)
    while limit and #t > limit do table.remove(t) end
    return t
end

----------------------------------------------------------------------
-- Kill sync between group members
--   KHI|count|digest        "here is what I have" (on connect / when someone appears)
--   KS|e1;e2;...            kill events, e = killer~victim~zone~time~class
-- When digests differ, both sides send their events; merging is idempotent.
----------------------------------------------------------------------
local function Digest()
    local n, sum = 0, 0
    for _, e in pairs(Store().events) do
        n = n + 1
        sum = (sum + e.at % 1000003 + #e.killer * 7 + #e.victim) % 2147483647
    end
    return n, sum
end

local sendQueue, sending = {}, false
local function PumpQueue()
    local job = table.remove(sendQueue, 1)
    if not job then sending = false return end
    FM:SendToGroup(job.g, job.msg)
    C_Timer.After(0.3, PumpQueue)
end
local function Queue(g, msg)
    table.insert(sendQueue, { g = g, msg = msg })
    if not sending then sending = true; C_Timer.After(0.1, PumpQueue) end
end

local function SendHello(g)
    local n, sum = Digest()
    Queue(g, ("KHI|%d|%d"):format(n, sum))
end

local lastFull = {} -- [code] = GetTime() of our last full send to that group
local function SendAll(g)
    if lastFull[g.code] and GetTime() - lastFull[g.code] < 20 then return end
    lastFull[g.code] = GetTime()
    local k = Store()
    local buf, len = {}, 0
    for _, e in pairs(k.events) do
        local s = ("%s~%s~%s~%d~%s"):format(e.killer, e.victim, e.zone, e.at, k.classes[e.killer] or "")
        if len + #s + 1 > 200 and #buf > 0 then
            Queue(g, "KS|" .. table.concat(buf, ";"))
            buf, len = {}, 0
        end
        buf[#buf + 1] = s
        len = len + #s + 1
    end
    if #buf > 0 then Queue(g, "KS|" .. table.concat(buf, ";")) end
end

local helloSent, helloPending = {}, {}
local function ScheduleHello(g, delay)
    if helloPending[g.code] then return end
    helloPending[g.code] = true
    C_Timer.After(delay or 3, function()
        helloPending[g.code] = nil
        if FM:GetGroup(g.code) and FM:IsConnected(g) then SendHello(g) end
    end)
end

-- someone new appeared in a group: compare kill sets
function FM:OnNewMember(code)
    local g = self:GetGroup(code)
    if g then ScheduleHello(g, 2 + math.random() * 3) end
end

local lastReply = {}
FM.Handlers.KHI = function(self, p, code, sender)
    local g = self:GetGroup(code)
    if not g then return end
    local theirN, theirSum = tonumber(p[2]) or 0, tonumber(p[3]) or 0
    local n, sum = Digest()
    if theirN == n and theirSum == sum then return end
    -- different: give them ours (if we have something), and ask for theirs
    if n > 0 then
        C_Timer.After(0.5 + math.random() * 2.5, function() SendAll(g) end)
    end
    if theirN > 0 and (not lastReply[sender] or GetTime() - lastReply[sender] > 30) then
        lastReply[sender] = GetTime()
        ScheduleHello(g, 1)
    end
end

FM.Handlers.KS = function(self, p, code)
    local added = 0
    for entry in tostring(p[2] or ""):gmatch("[^;]+") do
        local killer, victim, zone, at, class = strsplit("~", entry)
        if AddEvent(killer, victim, zone, at, class) then added = added + 1 end
    end
    if added > 0 then Changed() end
end

C_Timer.NewTicker(5, function()
    if not FM.worldReady or not FriendMapDB or not FriendMapDB.kills then return end
    for _, g in ipairs(FriendMapDB.groups) do
        if not helloSent[g.code] and FM:IsConnected(g) then
            helloSent[g.code] = true
            ScheduleHello(g, 2 + math.random() * 4)
        end
    end
end)

local function ScanUnits(fn)
    for _, u in ipairs({ "target", "focus", "mouseover" }) do fn(u) end
    for i = 1, 40 do fn("nameplate" .. i) end
end

local function CheckKills()
    local now = GetTime()
    if not FM.IsWorldPvPArea() then return end
    ScanUnits(function(u)
        if not UnitExists(u) or not UnitIsPlayer(u) then return end
        local guid = UnitGUID(u)
        if not guid then return end
        if FM.IsHostilePlayerFightingMe(u) then
            engaged[guid] = now
        elseif engaged[guid] and UnitIsDeadOrGhost(u) and not credited[guid] and now - engaged[guid] < 20 then
            credited[guid] = now
            local victim = Clean(UnitName(u))
            local me = UnitName("player")
            local at, zone = time(), SafeField(ZoneName())
            AddEvent(me, victim, zone, at, select(2, UnitClass("player")))
            Changed()
            FM:Print(("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t |cffff8800You killed %s|r (%s)"):format(victim, zone))
            Broadcast(("KILL|%s|%s|%d"):format(SafeField(victim), zone, at))
        end
    end)
    for guid, t in pairs(engaged) do if now - t > 60 then engaged[guid] = nil end end
    for guid, t in pairs(credited) do if now - t > 300 then credited[guid] = nil end end
end

FM.Handlers.KILL = function(self, p, code, sender, short)
    -- KILL|victim|zone|time  (older versions send no time)
    local at = (p[4] and p[4] ~= code) and tonumber(p[4]) or time()
    local class
    for _, m in pairs(self.members[code] or {}) do if m.name == short then class = m.class end end
    if not AddEvent(short, p[2], p[3], at, class) then return end -- already known (e.g. via another group)
    Changed()
    self:Print(("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t |cffff8800%s killed %s|r (%s)"):format(short, p[2] or "?", p[3] or "?"))
end

FM.SlashExtra.top = function() FM:ToggleLeaderboard() end

----------------------------------------------------------------------
-- 7. Level-up & achievement news
----------------------------------------------------------------------
local function Celebrate(self, short, text)
    self:Print("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t |cffffd100" .. short .. " " .. text .. "|r")
    Sound(SOUNDKIT and SOUNDKIT.UI_GARRISON_MISSION_COMPLETE_ENCOUNTER_CHANCE, 888)
    for _, list in pairs(self.members) do
        for _, m in pairs(list) do
            if m.name == short then m.flashUntil = GetTime() + 10 end
        end
    end
    if self.Pins then self.Pins:Refresh() end
end

FM.Handlers.LVL = function(self, p, code, sender, short)
    Celebrate(self, short, "reached level " .. (p[2] or "?") .. "!")
end

FM.Handlers.ACH = function(self, p, code, sender, short)
    Celebrate(self, short, "earned the achievement [" .. (p[2] or "?") .. "]!")
end

----------------------------------------------------------------------
-- 8. Rally point  (Alt+Shift+click on the world map, or /fm rally)
----------------------------------------------------------------------
function FM:ApplyRally(inst, x, y, by)
    if self.rally and self.rally.marker then self:RemoveMarker(self.rally.marker) end
    self.rally = nil
    if inst then
        self.rally = { inst = inst, x = x, y = y, by = by }
        self.rally.marker = self:ShowMarker("rally", inst, x, y, "Rally point (set by " .. by .. ")", "Rally")
    end
    self:UpdateArrow()
end

function FM:SetRally(inst, x, y)
    local me = UnitName("player")
    self:ApplyRally(inst, x, y, me)
    Broadcast(("RALLY|%d|%.1f|%.1f"):format(inst, x, y))
    self:Print("Rally point set and shared with your groups.")
end

function FM:ClearRally()
    self:ApplyRally(nil)
    Broadcast("RALLY|clear")
    self:Print("Rally point cleared.")
end

FM.Handlers.RALLY = function(self, p, code, sender, short)
    if p[2] == "clear" then
        if self.rally then self:ApplyRally(nil); self:Print(short .. " cleared the rally point.") end
        return
    end
    local inst, x, y = tonumber(p[2]), tonumber(p[3]), tonumber(p[4])
    if not (inst and x and y) then return end
    self:ApplyRally(inst, x, y, short)
    self:Print(("|cff3399ff%s set a rally point|r (%s). Follow the arrow!"):format(short, self:DistanceText(inst, x, y)))
    Sound(SOUNDKIT and SOUNDKIT.READY_CHECK, 8960)
end

FM.SlashExtra.rally = function(rest)
    if rest == "clear" then FM:ClearRally() return end
    local x, y, inst = HBD:GetPlayerWorldPosition()
    if x then FM:SetRally(inst, x, y) end
end

----------------------------------------------------------------------
-- 9. Zone heatmap (continent view of the world map)
----------------------------------------------------------------------
local badges = {}

local function GetBadge(i)
    local b = badges[i]
    if not b then
        b = CreateFrame("Frame", nil, WorldMapFrame)
        b.tex = b:CreateTexture(nil, "BACKGROUND")
        b.tex:SetAllPoints()
        b.tex:SetTexture(DISC)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        b.text:SetPoint("CENTER")
        b:EnableMouse(false)
        badges[i] = b
    end
    return b
end

local lastMelloHeat = ""

local function ContinentOf(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    local guard = 0
    while info and info.mapType ~= Enum.UIMapType.Continent and info.parentMapID and info.parentMapID > 0 and guard < 10 do
        info = C_Map.GetMapInfo(info.parentMapID)
        guard = guard + 1
    end
    if info and info.mapType == Enum.UIMapType.Continent then return info.mapID end
end

function FM:DrawHeatmap()
    HBDP:RemoveAllWorldMapIcons(HeatRef)
    for _, b in ipairs(badges) do b:Hide() end
    local M = _G.MelloUI and _G.MelloUI.Map
    local _, kind = self:OpenMap()
    if not FriendMapDB.heatmap or not kind or not (Enum and Enum.UIMapType) then
        if M and M.ClearPins and lastMelloHeat ~= "" then M:ClearPins("FriendMap_heat"); lastMelloHeat = "" end
        return
    end

    local mapID
    if kind == "blizzard" then
        mapID = WorldMapFrame:GetMapID()
        local info = mapID and C_Map.GetMapInfo(mapID)
        if not info or info.mapType ~= Enum.UIMapType.Continent then return end
    else
        mapID = ContinentOf(self:ViewedMapID())   -- MelloUI: one seamless map, use the continent in view
        if not mapID then return end
    end

    local counts, names, seen = {}, {}, {}
    for _, list in pairs(self.members) do
        for sender, m in pairs(list) do
            if not seen[sender] then
                seen[sender] = true
                local cx, cy = HBD:GetZoneCoordinatesFromWorld(m.x, m.y, mapID)
                local zi = cx and C_Map.GetMapInfoAtPosition(mapID, cx, cy)
                if zi and zi.mapID ~= mapID then
                    counts[zi.mapID] = (counts[zi.mapID] or 0) + 1
                    names[zi.mapID] = (names[zi.mapID] and (names[zi.mapID] .. ", ") or "") .. m.name
                end
            end
        end
    end

    if kind == "mello" then
        -- MelloUI's own pin API; only rebuilt when something changed
        local sig = {}
        for z, n in pairs(counts) do sig[#sig + 1] = z .. "=" .. n end
        table.sort(sig)
        sig = mapID .. ":" .. table.concat(sig, ",")
        if sig == lastMelloHeat or not (M and M.AddPin) then return end
        lastMelloHeat = sig
        M:ClearPins("FriendMap_heat")
        for zoneID, n in pairs(counts) do
            local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(zoneID, mapID)
            if minX then
                local heat = math.min(1, (n - 1) / 4)
                local zinfo = C_Map.GetMapInfo(zoneID)
                M:AddPin("FriendMap_heat", zoneID, mapID, (minX + maxX) / 2, (minY + maxY) / 2, {
                    icon = DISC, size = math.min(70, 26 + n * 8), alpha = 0.55,
                    rgb = { 0.2 + 0.8 * heat, 0.9 - 0.7 * heat, 0.2 },
                    tip = function() return ("%d friend%s in %s"):format(n, n > 1 and "s" or "", zinfo and zinfo.name or "?"), names[zoneID] end,
                    show = "continent",
                })
            end
        end
        return
    end

    local i = 0
    for zoneID, n in pairs(counts) do
        local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(zoneID, mapID)
        if minX then
            i = i + 1
            local b = GetBadge(i)
            local size = math.min(90, 34 + n * 10)
            b:SetSize(size, size)
            local heat = math.min(1, (n - 1) / 4)          -- 1 friend = green ... 5+ = red
            b.tex:SetVertexColor(0.2 + 0.8 * heat, 0.9 - 0.7 * heat, 0.2, 0.45)
            b.text:SetText(n)
            b:Show()
            HBDP:AddWorldMapIconMap(HeatRef, b, mapID, (minX + maxX) / 2, (minY + maxY) / 2)
        end
    end
end

FM.SlashExtra.heatmap = function()
    FriendMapDB.heatmap = not FriendMapDB.heatmap
    FM:DrawHeatmap()
    FM:Print("Zone heatmap " .. (FriendMapDB.heatmap and "ON" or "OFF"))
end

local function RedrawMapExtras()
    FM:DrawTrails()
    FM:DrawHeatmap()
end
FM.RedrawMapExtras = RedrawMapExtras
WorldMapFrame:HookScript("OnShow", RedrawMapExtras)
if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", RedrawMapExtras) end

----------------------------------------------------------------------
-- Events & tick
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LEVEL_UP")
pcall(ev.RegisterEvent, ev, "ACHIEVEMENT_EARNED")
ev:SetScript("OnEvent", function(_, event, a1)
    if event == "PLAYER_LOGIN" then
        Defaults()
        local p = FriendMapDB.arrowPos
        if p then arrow:ClearAllPoints(); arrow:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
    elseif event == "PLAYER_LEVEL_UP" then
        Broadcast("LVL|" .. tostring(a1))
    elseif event == "ACHIEVEMENT_EARNED" and GetAchievementInfo then
        local _, name = GetAchievementInfo(a1)
        if name then Broadcast("ACH|" .. Clean(name)) end
    end
end)

local ticks = 0
function FM:OnTick()
    if not FriendMapDB.kills then Defaults() end
    ExpireMarkers()
    CheckAutoHelp()
    CheckKills()
    ticks = ticks + 1
    if ticks % 2 == 0 and FM:IsAnyMapShown() then RedrawMapExtras() end
    if self.trackName and not FindMemberByName(self.trackName) and not self.rally then arrow:Hide() end
end
