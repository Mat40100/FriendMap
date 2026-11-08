-- FriendMap map menu: a small button shown next to whichever map is open
-- (Blizzard's world map, MelloUI's map, ...). It is our own frame, only
-- anchored to the map frame: nothing of the map addon is modified.
--
-- To mark a precise spot on any map, use the game's standard map pin
-- (Ctrl+click on the map, in Blizzard's map and MelloUI's alike) and choose
-- "Ping my map pin" / "Rally at my map pin" in the menu.
local FM = FriendMap
local HBD = LibStub("HereBeDragons-2.0")

----------------------------------------------------------------------
-- Which map is open?
----------------------------------------------------------------------
local function Mello()
    local M = _G.MelloUI and _G.MelloUI.Map
    if M and type(M.IsShown) == "function" then return M end
end

-- returns the frame of the open map (for anchoring), and its kind
function FM:OpenMap()
    local M = Mello()
    if M and M:IsShown() and _G.MelloUIMapFrame and MelloUIMapFrame:IsShown() then
        return MelloUIMapFrame, "mello"
    end
    if WorldMapFrame and WorldMapFrame:IsShown() then
        return WorldMapFrame, "blizzard"
    end
end

function FM:IsAnyMapShown()
    return self:OpenMap() ~= nil
end

-- MelloUI tells us which map is under the middle of its view
FM.melloViewMap = nil
local function HookMello()
    local M = Mello()
    if M and M.OnViewChanged and not FM.melloHooked then
        FM.melloHooked = true
        M:OnViewChanged("FriendMap", function(uiMapID)
            FM.melloViewMap = uiMapID
            if FM.DrawHeatmap then FM:DrawHeatmap() end
        end)
    end
end

-- the map the user is looking at, whatever the map addon
function FM:ViewedMapID()
    local _, kind = self:OpenMap()
    if kind == "blizzard" then return WorldMapFrame:GetMapID() end
    if kind == "mello" then return self.melloViewMap end
end

----------------------------------------------------------------------
-- The game's map pin (works with every map addon using it)
----------------------------------------------------------------------
local function MapPinWorld()
    if not (C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()) then return end
    local point = C_Map.GetUserWaypoint()
    if not point or not point.uiMapID or not point.position then return end
    local px, py = point.position.x, point.position.y
    if point.position.GetXY then px, py = point.position:GetXY() end
    local x, y, inst = HBD:GetWorldCoordinatesFromZone(px, py, point.uiMapID)
    if x and inst then return x, y, inst end
end

local function NoPin()
    FM:Print("Place a map pin first: |cffffd100Ctrl+click|r a spot on the map, then pick this again.")
end

----------------------------------------------------------------------
-- Menu
----------------------------------------------------------------------
local function OnOff(v) return v and "|cff33ff33on|r" or "|cff888888off|r" end

local function Items()
    return {
        { title = "FriendMap" },
        { text = "Ping my map pin", tip = "Ctrl+click the map to place the game's map pin first", func = function()
            local x, y, inst = MapPinWorld()
            if x then FM:SendPing(inst, x, y) else NoPin() end
        end },
        { text = "Rally at my map pin", func = function()
            local x, y, inst = MapPinWorld()
            if x then FM:SetRally(inst, x, y) else NoPin() end
        end },
        { text = "Ping my position", func = function() FM.SlashExtra.ping("") end },
        { text = "Rally at my position", func = function() FM.SlashExtra.rally("") end },
        { text = "Clear rally point", disabled = not FM.rally, func = function() FM:ClearRally() end },
        { text = "|cffff4444Help!|r", func = function() FM:SendHelp(false) end },
        { separator = true },
        { text = "Trails: " .. OnOff(FriendMapDB.trails), keepOpen = true, func = function() FM.SlashExtra.trails() end },
        { text = "Zone heatmap: " .. OnOff(FriendMapDB.heatmap), keepOpen = true, func = function() FM.SlashExtra.heatmap() end },
        { text = "Minimap icons: " .. OnOff(FriendMapDB.minimap), keepOpen = true, func = function() FM:Slash("minimap") end },
        { text = "Stop arrow", disabled = not FM.trackName, func = function() FM:Track(nil) end },
        { separator = true },
        { text = "Open FriendMap window", func = function() FM:ToggleUI() end },
    }
end

local menu = CreateFrame("Frame", "FriendMapMapMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate")
menu:SetFrameStrata("FULLSCREEN_DIALOG")
menu:SetClampedToScreen(true)
menu:EnableMouse(true)
menu:Hide()
if menu.SetBackdrop then
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    menu:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
end
menu.lines = {}

local function Line(i)
    local b = menu.lines[i]
    if not b then
        b = CreateFrame("Button", nil, menu)
        b:SetHeight(18)
        b:SetPoint("LEFT", 8, 0)
        b:SetPoint("RIGHT", -8, 0)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetColorTexture(1, 0.82, 0, 0.18)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("LEFT", 4, 0)
        b.text:SetJustifyH("LEFT")
        b.sep = b:CreateTexture(nil, "ARTWORK")
        b.sep:SetHeight(1)
        b.sep:SetPoint("LEFT", 2, 0)
        b.sep:SetPoint("RIGHT", -2, 0)
        b.sep:SetColorTexture(1, 1, 1, 0.15)
        b:SetScript("OnEnter", function(self)
            if self.item and self.item.tip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.item.tip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        b:SetScript("OnClick", function(self)
            local it = self.item
            if not it or not it.func or it.disabled then return end
            FM:WithHardware(it.func)
            if it.keepOpen then FM:ShowMapMenu(menu.anchor) else menu:Hide() end
        end)
        menu.lines[i] = b
    end
    return b
end

function FM:ShowMapMenu(anchor)
    local items = Items()
    local y, width = -8, 150
    for i, it in ipairs(items) do
        local b = Line(i)
        b.item = it
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 8, y)
        b:SetPoint("TOPRIGHT", -8, y)
        b.sep:SetShown(it.separator == true)
        b.hl:SetShown(it.func ~= nil and not it.disabled)
        if it.separator then
            b:SetHeight(8); b.text:SetText("")
        elseif it.title then
            b:SetHeight(18); b.text:SetText("|cff33ff99" .. it.title .. "|r")
        else
            b:SetHeight(18)
            b.text:SetText(it.disabled and ("|cff666666" .. it.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r") or it.text)
        end
        width = math.max(width, b.text:GetStringWidth() + 24)
        b:Show()
        y = y - b:GetHeight()
    end
    for i = #items + 1, #menu.lines do menu.lines[i]:Hide() end
    menu:SetSize(width + 16, -y + 8)
    menu.anchor = anchor
    menu:ClearAllPoints()
    if anchor.onRail then
        menu:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 6, 0)   -- opens beside the rail, upwards
    else
        menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    end
    menu:Show()
end

-- close when clicking elsewhere
menu:SetScript("OnShow", function(self) self.openedAt = GetTime() end)
local closer = CreateFrame("Frame")
pcall(closer.RegisterEvent, closer, "GLOBAL_MOUSE_DOWN")
closer:SetScript("OnEvent", function()
    if menu:IsShown() and not menu:IsMouseOver() and not (menu.anchor and menu.anchor:IsMouseOver()) then
        menu:Hide()
    end
end)

----------------------------------------------------------------------
-- The button next to the open map
----------------------------------------------------------------------
local btn = CreateFrame("Button", "FriendMapMapButton", UIParent)
btn:SetSize(26, 26)
btn:SetFrameStrata("FULLSCREEN_DIALOG")
btn:SetClampedToScreen(true)
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:Hide()
btn.bg = btn:CreateTexture(nil, "BACKGROUND")
btn.bg:SetAllPoints()
btn.bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
btn.bg:SetVertexColor(0, 0, 0, 0.75)
btn.icon = btn:CreateTexture(nil, "ARTWORK")
btn.icon:SetPoint("CENTER")
btn.icon:SetSize(17, 17)
btn.icon:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
btn.ring = btn:CreateTexture(nil, "OVERLAY")
btn.ring:SetPoint("TOPLEFT", -6, 6)
btn.ring:SetPoint("BOTTOMRIGHT", 22, -22)
btn.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
btn:SetScript("OnClick", function(self)
    if menu:IsShown() then menu:Hide() else FM:ShowMapMenu(self) end
end)
btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("FriendMap")
    GameTooltip:AddLine("Click: markers & options", 1, 1, 1)
    GameTooltip:AddLine("Ctrl+click the map to place a map pin,\nthen use \"Ping/Rally at my map pin\".", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Shift+drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", GameTooltip_Hide)

-- Shift+drag to move; the offset is remembered per map kind
btn:SetMovable(true)
btn:RegisterForDrag("LeftButton")
btn:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local map, kind = FM:OpenMap()
    if not map then return end
    local canvas = Canvas(map, kind)
    local x = self:GetRight() - canvas:GetRight()
    local y = self:GetTop() - canvas:GetTop()
    FriendMapDB.mapButtonPos = FriendMapDB.mapButtonPos or {}
    FriendMapDB.mapButtonPos[kind] = { x, y }
    self.placedFor = nil -- re-anchor to the map with the new offset
end)

-- inside the top-right corner of the map picture (clear of the window's title bar buttons)
local DEFAULT_OFFSET = { -8, -8 }

-- MelloUI's map has a narrow rail of round buttons between the map and the quest
-- column (46 px wide, as tall as the map). We sit at its bottom, under its own buttons.
local function MelloRail(map)
    local best
    for _, child in ipairs({ map:GetChildren() }) do
        local w, h = child:GetWidth(), child:GetHeight()
        if child:IsShown() and w and h and w > 30 and w < 70 and h > 200 and (not best or h > best:GetHeight()) then
            best = child
        end
    end
    return best
end

local function Canvas(map, kind)
    if kind == "blizzard" and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer:IsShown() then
        return WorldMapFrame.ScrollContainer
    end
    return map
end

local function Place(map, kind)
    local saved = FriendMapDB.mapButtonPos and FriendMapDB.mapButtonPos[kind]
    local rail = kind == "mello" and not saved and MelloRail(map)
    local target = rail or Canvas(map, kind)
    if btn.placedFor == target then return end
    btn.placedFor = target
    btn:ClearAllPoints()
    if rail then
        btn:SetSize(30, 30)                     -- same size as MelloUI's rail buttons
        btn:SetPoint("BOTTOM", rail, "BOTTOM", 0, 10)
        btn.ring:Hide()
        btn.onRail = true
    else
        btn.ring:Show()
        btn.onRail = false
        btn:SetSize(26, 26)
        local o = saved or DEFAULT_OFFSET
        btn:SetPoint("TOPRIGHT", target, "TOPRIGHT", o[1], o[2])
    end
end

-- cheap watcher: follow whichever map opens or closes
local watcher, acc, wasShown = CreateFrame("Frame"), 0, false
watcher:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.2 then return end
    acc = 0
    HookMello()
    local map, kind = FM:OpenMap()
    if map then
        Place(map, kind)
        btn:Show()
        if not wasShown and FM.RedrawMapExtras then FM.RedrawMapExtras() end
        wasShown = true
    else
        btn:Hide(); menu:Hide()
        btn.placedFor = nil
        wasShown = false
    end
end)

FM.SlashExtra.mapbutton = function()
    FriendMapDB.mapButtonPos = nil
    btn.placedFor = nil
    FM:Print("Map button position reset.")
end
