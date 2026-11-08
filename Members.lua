-- Members window: every player ever seen in each joined group (/fm members)
local FM = FriendMap
local ROW_H, VISIBLE = 18, 20
local frame

local function Roster(code)
    FriendMapDB.roster = FriendMapDB.roster or {}
    FriendMapDB.roster[code] = FriendMapDB.roster[code] or {}
    return FriendMapDB.roster[code]
end

function FM:RecordMember(code, m)
    if not m or not m.name then return end
    local r = Roster(code)
    local e = r[m.name] or {}
    e.class, e.level, e.seen = m.class or e.class, m.level or e.level, time()
    r[m.name] = e
    if frame and frame:IsShown() then frame:Refresh() end
end

local function IsOnline(code, name)
    for _, m in pairs(FM.members[code] or {}) do
        if m.name == name then return m end
    end
end

local function Ago(t)
    if not t then return "never" end
    local d = time() - t
    if d < 3600 then return ("%d min ago"):format(math.max(1, math.floor(d / 60))) end
    if d < 86400 then return ("%d h ago"):format(math.floor(d / 3600)) end
    return ("%d days ago"):format(math.floor(d / 86400))
end

local function Colored(name, class)
    local c = RAID_CLASS_COLORS[class or ""]
    return c and ("|c%s%s|r"):format(c.colorStr or "ffffffff", name) or name
end

-- Flatten into display lines: group headers followed by its players
local function BuildLines()
    local lines = {}
    local me, myClass = UnitName("player"), select(2, UnitClass("player"))
    for _, g in ipairs(FriendMapDB.groups) do
        local list = {}
        if FM:IsConnected(g) then
            list[#list + 1] = { name = me, class = myClass, level = UnitLevel("player"), online = true, you = true }
        end
        for name, e in pairs(Roster(g.code)) do
            if name ~= me then
                local m = IsOnline(g.code, name)
                list[#list + 1] = { name = name, class = e.class, level = m and m.level or e.level,
                                    online = m ~= nil, seen = e.seen, zone = m and m.status }
            end
        end
        table.sort(list, function(a, b)
            if a.you ~= b.you then return a.you == true end
            if a.online ~= b.online then return a.online end
            return a.name < b.name
        end)
        local on = 0
        for _, p in ipairs(list) do if p.online then on = on + 1 end end
        lines[#lines + 1] = { header = true, text = ("%s  |cff888888%d / %d online|r"):format(g.name, on, #list) }
        if #list == 0 then
            lines[#lines + 1] = { empty = true }
        end
        for _, p in ipairs(list) do lines[#lines + 1] = p end
    end
    return lines
end

local function Build()
    frame = CreateFrame("Frame", "FriendMapMembers", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(360, 70 + VISIBLE * ROW_H)
    frame:SetPoint("CENTER", 200, 0)
    frame:SetMovable(true); frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    tinsert(UISpecialFrames, "FriendMapMembers")
    frame.TitleText = frame.TitleText or frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.TitleText:SetText("FriendMap - Group members")

    local scroll = CreateFrame("ScrollFrame", nil, frame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -30)
    scroll:SetPoint("BOTTOMRIGHT", -30, 34)
    frame.scroll = scroll

    frame.rows = {}
    for i = 1, VISIBLE do
        local r = CreateFrame("Button", nil, frame)
        r:SetSize(310, ROW_H)
        r:SetPoint("TOPLEFT", 14, -30 - (i - 1) * ROW_H)
        r.dot = r:CreateTexture(nil, "ARTWORK")
        r.dot:SetSize(8, 8); r.dot:SetPoint("LEFT", 4, 0)
        r.dot:SetTexture("Interface\\Buttons\\WHITE8X8")
        r.left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.left:SetPoint("LEFT", 16, 0)
        r.right = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        r.right:SetPoint("RIGHT", -4, 0)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, btn)
            local p = self.data
            if not p or p.header or p.you or not p.name then return end
            if btn == "RightButton" then
                ChatFrame_OpenChat("/w " .. p.name .. " ")
            elseif p.online then
                FM:Track(p.name)
            end
        end)
        r:SetScript("OnEnter", function(self)
            local p = self.data
            if not p or p.header or p.empty or p.you then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(Colored(p.name, p.class))
            if p.online then
                GameTooltip:AddLine("Left-click: arrow to this friend", 1, 1, 1)
            end
            GameTooltip:AddLine("Right-click: whisper", 1, 1, 1)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", GameTooltip_Hide)
        frame.rows[i] = r
    end

    local foot = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("BOTTOM", 0, 12)
    foot:SetText("Players appear here once they have been seen online")

    function frame:Refresh()
        local lines = BuildLines()
        FauxScrollFrame_Update(scroll, #lines, VISIBLE, ROW_H)
        local off = FauxScrollFrame_GetOffset(scroll)
        for i, r in ipairs(self.rows) do
            local p = lines[i + off]
            r.data = p
            if not p then
                r:Hide()
            else
                r:Show()
                r.right:SetText("")
                if p.header then
                    r.dot:Hide()
                    r.left:SetFontObject("GameFontNormal")
                    r.left:SetText(p.text)
                elseif p.empty then
                    r.dot:Hide()
                    r.left:SetFontObject("GameFontDisableSmall")
                    r.left:SetText("   nobody seen yet")
                else
                    r.dot:Show()
                    if p.online then r.dot:SetVertexColor(0.2, 1, 0.2) else r.dot:SetVertexColor(0.4, 0.4, 0.4) end
                    r.left:SetFontObject("GameFontHighlight")
                    local lvl = p.level and (" |cff888888" .. p.level .. "|r") or ""
                    r.left:SetText(Colored(p.name, p.class) .. lvl .. (p.you and " |cff888888(you)|r" or ""))
                    r.right:SetText(p.online and "|cff33ff33online|r" or Ago(p.seen))
                end
            end
        end
    end
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function() frame:Refresh() end)
    end)

    -- refresh periodically so online/offline states stay current
    local acc = 0
    frame:SetScript("OnUpdate", function(self, e)
        acc = acc + e
        if acc > 2 then acc = 0; self:Refresh() end
    end)
end

function FM:ToggleMembers()
    if not frame then Build() end
    if frame:IsShown() then frame:Hide() else frame:Show(); frame:Refresh() end
end

FM.SlashExtra = FM.SlashExtra or {}
FM.SlashExtra.members = function() FM:ToggleMembers() end
