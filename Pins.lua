-- Map / minimap pins: class icon + small class-coloured nameplate.
local FM = FriendMap
local HBDP = LibStub("HereBeDragons-Pins-2.0")

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
        GameTooltip:AddLine("Group: " .. (self.groupName or "?"), 0.2, 1, 0.6)
        if m.pvpUntil and m.pvpUntil > GetTime() then
            GameTooltip:AddLine("In a world PvP fight!", 1, 0.2, 0.2)
        end
        GameTooltip:AddLine(("Updated %ds ago"):format(GetTime() - m.t), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self.member and ChatFrame_SendTell then
            ChatFrame_SendTell(self.member.name)
        end
    end)
    return f
end

local function Style(f, m, groupName)
    f.member, f.groupName = m, groupName
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[m.class or ""]
    if coords then
        f.icon:SetTexture(CLASS_ICONS)
        f.icon:SetTexCoord(unpack(coords))
    else
        f.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        f.icon:SetTexCoord(0, 1, 0, 1)
    end
    local inPvP = m.pvpUntil and m.pvpUntil > GetTime()
    if inPvP and not f.glow:IsShown() then
        f.glow:Show(); f.glowAnim:Play()
    elseif not inPvP and f.glow:IsShown() then
        f.glowAnim:Stop(); f.glow:Hide()
    end
    if f.label then
        f.label:SetText(m.name)
        f.label:SetTextColor(ClassColor(m.class))
    end
end

local function Get(pool, key, isWorld)
    local f = pool[key]
    if not f then f = CreatePin(isWorld); pool[key] = f end
    return f
end

function Pins:Refresh()
    -- One pin per player, even if they're in several of our groups (keep freshest).
    local best = {}
    for code, list in pairs(FM.members) do
        local g = FM:GetGroup(code)
        for sender, m in pairs(list) do
            if not best[sender] or best[sender].m.t < m.t then
                best[sender] = { m = m, group = g and g.name }
            end
        end
    end

    for key, f in pairs(self.world) do
        if not best[key] then HBDP:RemoveWorldMapIcon(Pins, f); f:Hide() end
    end
    for key, f in pairs(self.mini) do
        if not best[key] or not FriendMapDB.minimap then HBDP:RemoveMinimapIcon(Pins, f); f:Hide() end
    end

    for key, e in pairs(best) do
        local m = e.m
        local w = Get(self.world, key, true)
        Style(w, m, e.group)
        HBDP:AddWorldMapIconWorld(Pins, w, m.inst, m.x, m.y, HBD_PINS_WORLDMAP_SHOW_WORLD)
        if FriendMapDB.minimap then
            local mm = Get(self.mini, key, false)
            Style(mm, m, e.group)
            HBDP:AddMinimapIconWorld(Pins, mm, m.inst, m.x, m.y, true)
        end
    end
end
