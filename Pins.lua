-- Map / minimap pins: class icon + small class-coloured nameplate.
local FM = FriendMap
local HBDP = LibStub("HereBeDragons-Pins-2.0")
local HBD = LibStub("HereBeDragons-2.0")

local Pins = { world = {}, mini = {} }
FM.Pins = Pins

local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"

local function ClassColor(class)
    local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class or ""]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function CreatePin(isWorld)
    local size = isWorld and 22 or 16
    local f = CreateFrame("Frame", nil, isWorld and WorldMapFrame or Minimap)
    f:SetSize(size, size)
    f:EnableMouse(true)


    -- red "shadow" shown while the player has a recent PvP fight
    f.glow = f:CreateTexture(nil, "BACKGROUND")
    f.glow:SetPoint("CENTER")
    f.glow:SetSize(size * 1.7, size * 1.7)
    f.glow:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    f.glow:SetVertexColor(1, 0, 0, 0.85)
    f.glow:Hide()
    local ag = f.glow:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0.95); a:SetToAlpha(0.35); a:SetDuration(0.7)
    f.glowAnim = ag

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexture(CLASS_ICONS)

    if isWorld then
        f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.label:SetPoint("BOTTOM", f, "TOP", 0, 1)
        f.label:SetShadowColor(0, 0, 0, 1)
        f.label:SetShadowOffset(1, -1)
        f.labelBg = f:CreateTexture(nil, "BORDER")
        f.labelBg:SetColorTexture(0, 0, 0, 0.55)
        f.labelBg:SetPoint("TOPLEFT", f.label, "TOPLEFT", -3, 1)
        f.labelBg:SetPoint("BOTTOMRIGHT", f.label, "BOTTOMRIGHT", 3, -1)
    end

    f:SetScript("OnEnter", function(self)
        local m = self.member
        if not m then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(m.name, ClassColor(m.class))
        local className = (LOCALIZED_CLASS_NAMES_MALE or {})[m.class] or m.class
        GameTooltip:AddLine(("Level %s %s"):format(m.level or "?", className or ""), 1, 1, 1)
        if m.status then GameTooltip:AddLine('"' .. m.status .. '"', 0.8, 0.8, 1) end
        GameTooltip:AddLine("Group: " .. (self.groupName or "?"), 0.2, 1, 0.6)
        if FM.DistanceText then GameTooltip:AddLine(FM:DistanceText(m.inst, m.x, m.y), 1, 0.82, 0) end
        if m.pvpUntil and m.pvpUntil > GetTime() then
            GameTooltip:AddLine("In a world PvP fight!", 1, 0.2, 0.2)
        end
        GameTooltip:AddLine(("Updated %ds ago"):format(GetTime() - m.t), 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Click: track with arrow - Right-click: whisper", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnMouseUp", function(self, button)
        if not self.member then return end
        if button == "RightButton" and ChatFrame_SendTell then
            ChatFrame_SendTell(self.member.name)
        elseif button == "LeftButton" and FM.Track then
            FM:Track(self.member.name)
        end
    end)
    return f
end

-- Friends are a light class-coloured circle (default) or the class icon (/fm icons)
local function UseCircle() return FriendMapDB.iconStyle ~= "class" end
FM.UseCircleIcons = UseCircle

local function Style(f, m, groupName)
    f.member, f.groupName = m, groupName
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[m.class or ""]
    local circle = UseCircle()
    if circle ~= f.isCircle then
        f.isCircle = circle
        local size = f.label and (circle and 11 or 22) or (circle and 8 or 16)
        f:SetSize(size, size)
        f.glow:SetSize(size * 1.9, size * 1.9)
    end
    if circle then
        f.icon:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        f.icon:SetTexCoord(0, 1, 0, 1)
        local r, g, b = ClassColor(m.class)
        f.icon:SetVertexColor(r, g, b, 1)
    elseif coords then
        f.icon:SetVertexColor(1, 1, 1, 1)
        f.icon:SetTexture(CLASS_ICONS)
        f.icon:SetTexCoord(unpack(coords))
    else
        f.icon:SetVertexColor(1, 1, 1, 1)
        f.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        f.icon:SetTexCoord(0, 1, 0, 1)
    end
    -- gold glow = just levelled up / achievement, red glow = PvP fight
    local now = GetTime()
    local flash = m.flashUntil and m.flashUntil > now
    local inPvP = m.pvpUntil and m.pvpUntil > now
    if flash then f.glow:SetVertexColor(1, 0.8, 0.1, 0.9) else f.glow:SetVertexColor(1, 0, 0, 0.85) end
    if (inPvP or flash) and not f.glow:IsShown() then
        f.glow:Show(); f.glowAnim:Play()
    elseif not (inPvP or flash) and f.glow:IsShown() then
        f.glowAnim:Stop(); f.glow:Hide()
    end
    if f.label then
        f.label:SetText(m.status and (m.name .. "\n|cffaaaaff" .. m.status .. "|r") or m.name)
        f.label:SetTextColor(ClassColor(m.class))
    end
end

local function Get(pool, key, isWorld)
    local f = pool[key]
    if not f then f = CreatePin(isWorld); pool[key] = f end
    return f
end

----------------------------------------------------------------------
-- MelloUI's map: friends drawn by MelloUI itself (its public pin API), with
-- the same class pictures it uses for your party members.
----------------------------------------------------------------------
local MELLO_ICONS = "Interface\\AddOns\\MelloUI\\Media\\Textures\\Icons\\"
local MELLO_OWNER = "FriendMap_friends"
local MELLO_MAPS = { 1414, 1415, 947 }  -- Kalimdor, Eastern Kingdoms, Azeroth
local melloKeys = {}

local function Mello()
    local M = _G.MelloUI and _G.MelloUI.Map
    if M and type(M.AddPin) == "function" then return M end
end

local function MelloPlace(M, key, wx, wy, spec)
    for _, mapID in ipairs(MELLO_MAPS) do
        local x, y = HBD:GetZoneCoordinatesFromWorld(wx, wy, mapID)
        if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 and M:AddPin(MELLO_OWNER, key, mapID, x, y, spec) then
            melloKeys[key] = true
            return true
        end
    end
end

local function MelloTip(m, groupName)
    return function()
        local lines = {}
        local className = (LOCALIZED_CLASS_NAMES_MALE or {})[m.class] or m.class or ""
        lines[#lines + 1] = ("Level %s %s"):format(m.level or "?", className)
        if m.status then lines[#lines + 1] = '"' .. m.status .. '"' end
        if FM.DistanceText then lines[#lines + 1] = FM:DistanceText(m.inst, m.x, m.y) end
        if groupName then lines[#lines + 1] = "Group: " .. groupName end
        local now = GetTime()
        if m.pvpUntil and m.pvpUntil > now then lines[#lines + 1] = "|cffff3333In a world PvP fight!|r" end
        if m.flashUntil and m.flashUntil > now then lines[#lines + 1] = "|cffffd100Just levelled up!|r" end
        lines[#lines + 1] = "|cff888888Click: track with arrow|r"
        local c = RAID_CLASS_COLORS[m.class or ""]
        local title = c and ("|c%s%s|r"):format(c.colorStr or "ffffffff", m.name) or m.name
        return title, table.concat(lines, "\n")
    end
end

local function ClearMello()
    local M = Mello()
    if M and next(melloKeys) then M:ClearPins(MELLO_OWNER) end
    wipe(melloKeys)
end

local function DrawMello(best)
    local M = Mello()
    if not M then return false end
    M:ClearPins(MELLO_OWNER)
    wipe(melloKeys)
    local now = GetTime()
    for key, e in pairs(best) do
        local m = e.m
        -- coloured disc under the icon: red = PvP fight, gold = level-up / achievement
        local glow = (m.flashUntil and m.flashUntil > now) and { 1, 0.8, 0.1 }
            or (m.pvpUntil and m.pvpUntil > now) and { 1, 0.1, 0.1 }
        if glow then
            MelloPlace(M, key .. "#glow", m.x, m.y, {
                icon = MELLO_ICONS .. "badge_disc", size = 26, rgb = glow, alpha = 0.75, show = "world",
            })
        end
        local hasClass = m.class and RAID_CLASS_COLORS[m.class]
        local circle = UseCircle()
        local c = hasClass and RAID_CLASS_COLORS[m.class]
        MelloPlace(M, key, m.x, m.y, {
            icon = MELLO_ICONS .. ((not circle and hasClass) and ("class_" .. m.class) or "map_dot"),
            size = circle and 10 or 16, show = "world",
            rgb = circle and c and { c.r, c.g, c.b } or nil, alpha = circle and 1 or nil,
            tip = MelloTip(m, e.group),
            click = function() FM:Track(m.name) end,
        })
    end
    return true
end

function Pins:Refresh()
    local me = UnitName("player")
    -- One pin per player, even if they're in several of our groups (keep freshest).
    local best = {}
    for code, list in pairs(FM.members) do
        local g = FM:GetGroup(code)
        for sender, m in pairs(list) do
            -- never draw yourself (the game / other map addons already do)
            if FM:IsMe(m.name) or FM:IsMe(sender) then
                -- skip
            elseif not best[sender] or best[sender].m.t < m.t then
                best[sender] = { m = m, group = g and g.name }
            end
        end
    end

    -- MelloUI's map open: MelloUI draws the friends in its own style, our world map icons step aside
    -- (MelloUI would otherwise show them as well, borrowed from HereBeDragons)
    local _, kind = FM.OpenMap and FM:OpenMap()
    local onMello = kind == "mello" and DrawMello(best)
    if not onMello then ClearMello() end

    for key, f in pairs(self.world) do
        if onMello or not best[key] then HBDP:RemoveWorldMapIcon(Pins, f); f:Hide() end
    end
    for key, f in pairs(self.mini) do
        if not best[key] or not FriendMapDB.minimap then HBDP:RemoveMinimapIcon(Pins, f); f:Hide() end
    end

    for key, e in pairs(best) do
        local m = e.m
        if not onMello then
            local w = Get(self.world, key, true)
            Style(w, m, e.group)
            w:Show()
            HBDP:AddWorldMapIconWorld(Pins, w, m.inst, m.x, m.y, HBD_PINS_WORLDMAP_SHOW_WORLD)
        end
        if FriendMapDB.minimap then
            local mm = Get(self.mini, key, false)
            Style(mm, m, e.group)
            mm:Show()
            HBDP:AddMinimapIconWorld(Pins, mm, m.inst, m.x, m.y, true)
        end
    end
end

FM.SlashExtra = FM.SlashExtra or {}
FM.SlashExtra.icons = function()
    FriendMapDB.iconStyle = UseCircle() and "class" or "circle"
    FM:Print("Friends on the map: " .. (UseCircle() and "class-coloured circles" or "class icons"))
    Pins:Refresh()
end
