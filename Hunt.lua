-- Enemy sightings + Revenge.
--  * Sightings: a hostile player of your level or higher seen in the open world
--    (target, mouseover, nameplates) shows as a red marker on your friends' maps for 2 minutes.
--  * Revenge: when an enemy kills a group member, they go on the revenge list. Anyone in the
--    group who then sees them gets an alert, and so does everyone else. Killing them clears it.
local FM = FriendMap
local HBD = LibStub("HereBeDragons-2.0")

local SPOT_LIFE      = 120        -- marker on the map (s)
local SPOT_SAME      = 120        -- don't re-send the same enemy within (s)
local SPOT_ANY       = 8          -- min seconds between two sightings sent
local REVENGE_KEEP   = 2 * 3600   -- an enemy stays on the revenge list (s, real time)
local REVENGE_ALERT  = 90         -- re-alert about the same revenge target after (s)
local KILLER_WINDOW  = 15         -- the last enemy who fought us within this counts as the killer

FM.MarkerKinds.enemy   = { r = 1, g = 0.25, b = 0.25, icon = "Interface\\Icons\\Ability_DualWield", life = SPOT_LIFE }
FM.MarkerKinds.revenge = { r = 0.75, g = 0.2, b = 1, icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", life = SPOT_LIFE }

local function Clean(s) return (tostring(s or ""):gsub("[|~;]", "")) end
local function Short(n) return n and Ambiguate(n, "none") or n end
local function Zone()
    local sub = GetSubZoneText()
    return ((sub and sub ~= "") and (sub .. ", ") or "") .. (GetZoneText() or "?")
end
local function Colored(name, class)
    local c = RAID_CLASS_COLORS[class or ""]
    return c and ("|c%s%s|r"):format(c.colorStr or "ffffffff", name) or name
end
local function ClassName(class) return (LOCALIZED_CLASS_NAMES_MALE or {})[class or ""] or class or "?" end

local function DB()
    FriendMapDB.revenge = FriendMapDB.revenge or {}
    if FriendMapDB.spots == nil then FriendMapDB.spots = true end
    local now = time()
    for name, e in pairs(FriendMapDB.revenge) do
        if now - (e.at or 0) > REVENGE_KEEP then FriendMapDB.revenge[name] = nil end
    end
    return FriendMapDB.revenge
end

local function Broadcast(msg)
    if not FriendMapDB.sharing then return end
    for _, g in ipairs(FriendMapDB.groups) do FM:SendToGroup(g, msg) end
end

local function Alert(text)
    FM:Print(text)
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
    end
end

----------------------------------------------------------------------
-- Markers: one per enemy (a newer sighting replaces the older one)
----------------------------------------------------------------------
local spotMarkers = {}

local function ShowSpot(name, class, level, inst, x, y, seenBy, victim)
    if spotMarkers[name] then FM:RemoveMarker(spotMarkers[name]) end
    local lvl = (tonumber(level) or 0) > 0 and level or "??"
    local tip = ("%s - level %s %s\nseen by %s"):format(name, lvl, ClassName(class), seenBy)
    if victim and victim ~= "" then tip = tip .. ("\n|cffcc66ffKilled %s - REVENGE!|r"):format(victim) end
    spotMarkers[name] = FM:ShowMarker(victim and victim ~= "" and "revenge" or "enemy", inst, x, y, tip, name)
end

----------------------------------------------------------------------
-- Who is fighting me (to know who killed me)
----------------------------------------------------------------------
local lastAttacker

local function NoteAttacker()
    if not UnitAffectingCombat("player") or not FM.IsWorldPvPArea() then return end
    local function look(u)
        if FM.IsHostilePlayerFightingMe(u) then
            lastAttacker = { name = Clean(Short(UnitName(u))), class = select(2, UnitClass(u)),
                             level = UnitLevel(u), t = GetTime() }
            return true
        end
    end
    for _, u in ipairs({ "target", "focus", "mouseover" }) do if look(u) then return end end
    for i = 1, 40 do if look("nameplate" .. i) then return end end
end

local function AddRevenge(enemy, class, level, victim, zone)
    DB()[enemy] = { victim = victim, class = class, level = tonumber(level), zone = zone, at = time() }
end

local function OnDeath()
    if not FM.IsWorldPvPArea() then return end
    local a = lastAttacker
    if not a or GetTime() - a.t > KILLER_WINDOW then return end
    local me, zone = UnitName("player"), Clean(Zone())
    AddRevenge(a.name, a.class, a.level, me, zone)
    FM:Print(("|cffcc66ffKilled by %s|r (level %s %s). Your friends are told - revenge is on!")
        :format(Colored(a.name, a.class), a.level and a.level > 0 and a.level or "??", ClassName(a.class)))
    Broadcast(("DIED|%s|%s|%d|%s"):format(a.name, a.class or "", a.level or 0, zone))
    lastAttacker = nil
end

FM.Handlers.DIED = function(self, p, code, sender, short)
    -- DIED|killer|class|level|zone
    local enemy, class, level, zone = Clean(p[2]), p[3], tonumber(p[4]) or 0, Clean(p[5])
    if enemy == "" or enemy == code then return end
    if zone == code then zone = "?" end
    AddRevenge(enemy, class, level, short, zone)
    self:Print(("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t |cffcc66ff%s was killed by %s|r (level %s %s) in %s. Revenge is on!")
        :format(short, Colored(enemy, class), level > 0 and level or "??", ClassName(class), zone))
end

-- A revenge target died at the hands of the group: settled
function FM:OnKill(killer, victim)
    victim = Clean(Short(victim))
    local e = DB()[victim]
    if not e then return end
    DB()[victim] = nil
    if spotMarkers[victim] then FM:RemoveMarker(spotMarkers[victim]); spotMarkers[victim] = nil end
    self:Print(("|cffcc66ffRevenge!|r %s killed %s, who had killed %s."):format(killer, victim, e.victim or "?"))
end

----------------------------------------------------------------------
-- Seeing enemies
----------------------------------------------------------------------
local lastSent, lastAny, lastAlert = {}, 0, {}

local function Seen(u)
    if not UnitExists(u) or not UnitIsPlayer(u) or not UnitCanAttack("player", u) or UnitIsDeadOrGhost(u) then return end
    if not FM.IsWorldPvPArea() then return end
    local name = Clean(Short(UnitName(u)))
    if name == "" then return end
    local class, level = select(2, UnitClass(u)), UnitLevel(u)
    local now = GetTime()
    local rev = DB()[name]

    -- revenge target: alert me (and the group) right away
    if rev and now - (lastAlert[name] or -999) > REVENGE_ALERT then
        lastAlert[name] = now
        Alert(("|cffcc66ffREVENGE: %s is here!|r (killed %s)"):format(name, rev.victim or "?"))
        pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959)
    end

    -- send the sighting to the group
    if not FriendMapDB.spots and not rev then return end
    local strong = level == -1 or level >= (UnitLevel("player") or 1)
    if not strong and not rev then return end
    if now - (lastSent[name] or -999) < SPOT_SAME then return end
    if now - lastAny < SPOT_ANY and not rev then return end
    local x, y, inst = HBD:GetPlayerWorldPosition()
    if not x then return end
    lastSent[name], lastAny = now, now
    Broadcast(("SPOT|%s|%s|%d|%d|%.1f|%.1f|%s"):format(name, class or "", level or 0, inst, x, y, rev and Clean(rev.victim) or ""))
end

FM.Handlers.SPOT = function(self, p, code, sender, short)
    -- SPOT|enemy|class|level|inst|x|y|victim
    local name, class, level = Clean(p[2]), p[3], tonumber(p[4]) or 0
    local inst, x, y = tonumber(p[5]), tonumber(p[6]), tonumber(p[7])
    if name == "" or not (inst and x and y) then return end
    local victim = (p[8] and p[8] ~= code and p[8] ~= "") and p[8] or nil
    if not victim and DB()[name] then victim = DB()[name].victim end
    if not FriendMapDB.spots and not victim then return end
    ShowSpot(name, class, level, inst, x, y, short, victim)
    local where = self:DistanceText(inst, x, y)
    if victim then
        local now = GetTime()
        if now - (lastAlert[name] or -999) > REVENGE_ALERT then
            lastAlert[name] = now
            Alert(("|cffcc66ffREVENGE: %s (killed %s) spotted by %s|r - %s"):format(name, victim, short, where))
            pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959)
        end
    else
        self:Print(("|cffff4040Enemy spotted:|r %s (level %s %s) by %s - %s")
            :format(Colored(name, class), level > 0 and level or "??", ClassName(class), short, where))
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_DEAD")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_DEAD" then OnDeath()
    elseif event == "PLAYER_TARGET_CHANGED" then Seen("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then Seen("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" and unit then Seen(unit)
    end
end)
C_Timer.NewTicker(0.5, NoteAttacker)

----------------------------------------------------------------------
-- Commands: /fm spots (on/off), /fm revenge (list)
----------------------------------------------------------------------
FM.SlashExtra = FM.SlashExtra or {}
FM.SlashExtra.spots = function()
    DB()
    FriendMapDB.spots = not FriendMapDB.spots
    FM:Print("Enemy sightings (send and show): " .. (FriendMapDB.spots and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
end
FM.SlashExtra.revenge = function(rest)
    if rest == "clear" then FriendMapDB.revenge = {}; FM:Print("Revenge list cleared.") return end
    local list = DB()
    if not next(list) then FM:Print("Revenge list is empty.") return end
    FM:Print("|cffcc66ffRevenge list|r (last 2 hours):")
    for name, e in pairs(list) do
        FM:Print(("  %s (level %s %s) killed %s in %s, %d min ago"):format(Colored(name, e.class),
            (e.level or 0) > 0 and e.level or "??", ClassName(e.class), e.victim or "?", e.zone or "?", math.floor((time() - e.at) / 60)))
    end
end
