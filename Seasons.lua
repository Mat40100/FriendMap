-- PvP seasons, per group.
--   A member proposes a season with an end date; it starts once 1 OTHER member accepts.
--   One season at a time per group. When the end date passes, the final standings
--   are saved in the group's season history.
-- Messages (the group code is appended by SendToGroup):
--   SPROP|id|finish|expires      a proposal (id = "<proposer>-<time>")
--   SVOTE|id|Y|N                 a member's answer
--   SSTART|id|start|finish|by    the season is on (sent by whoever sees the accept)
local FM = FriendMap

local NEEDED      = 1            -- accepts needed, besides the proposer
local PROP_LIFE   = 24 * 3600    -- a proposal expires after (s)
local MAX_LENGTH  = 365 * 86400

local function Clean(s) return (tostring(s or ""):gsub("[|~;]", "")) end

local function S(code)
    FriendMapDB.seasons = FriendMapDB.seasons or {}
    local t = FriendMapDB.seasons[code] or { history = {} }
    t.history = t.history or {}
    FriendMapDB.seasons[code] = t
    return t
end
FM.SeasonState = S

function FM:DateText(t) return date("%d/%m/%Y", t) end

local function Refresh()
    if FM.RefreshLeaderboard then FM:RefreshLeaderboard() end
end

local function Send(code, msg)
    local g = FM:GetGroup(code)
    if g then FM:SendToGroup(g, msg) end
end

-- the players of a group (for the season ranking): its roster + me
function FM:GroupPlayers(code)
    local who = { [self:MyName()] = true }
    for name in pairs(FriendMapDB.roster and FriendMapDB.roster[code] or {}) do who[self:FullName(name)] = true end
    return who
end

-- the leaderboard view of a group's season
function FM:SeasonView(code, season)
    season = season or S(code).cur
    if not season then return end
    return { from = season.start, to = season.finish, who = self:GroupPlayers(code), code = code, season = season }
end

-- oldest running season start (kills since then are kept)
function FM:OldestSeasonStart()
    local oldest
    for _, g in ipairs(FriendMapDB.groups or {}) do
        local cur = FriendMapDB.seasons and FriendMapDB.seasons[g.code] and FriendMapDB.seasons[g.code].cur
        if cur and (not oldest or cur.start < oldest) then oldest = cur.start end
    end
    return oldest
end

----------------------------------------------------------------------
-- Parsing the end date: DD/MM or DD/MM/YYYY (ends at 23:59:59 that day)
----------------------------------------------------------------------
local function ParseDate(text)
    local d, m, y = tostring(text or ""):match("^%s*(%d%d?)[/.%-](%d%d?)[/.%-]?(%d*)%s*$")
    d, m, y = tonumber(d), tonumber(m), tonumber(y)
    if not d or not m or m < 1 or m > 12 or d < 1 or d > 31 then return end
    local now = date("*t")
    if y and y < 100 then y = 2000 + y end
    local function at(year) return time({ year = year, month = m, day = d, hour = 23, min = 59, sec = 59 }) end
    local t = at(y or now.year)
    if not y and t < time() then t = at(now.year + 1) end
    return t
end

----------------------------------------------------------------------
-- Proposing and voting
----------------------------------------------------------------------
function FM:ProposeSeason(code, text)
    local g = self:GetGroup(code)
    if not g then return end
    local st = S(code)
    if st.cur then self:Print("|cffffaa00A season is already running in " .. g.name .. ".|r") return end
    local finish = ParseDate(text)
    if not finish then self:Print("|cffffaa00Invalid date. Use DD/MM or DD/MM/YYYY.|r") return end
    if finish < time() + 3600 or finish > time() + MAX_LENGTH then
        self:Print("|cffffaa00The end date must be in the future (and within a year).|r") return
    end
    local me = self:MyName()
    local id = Clean(me) .. "-" .. time()
    st.prop = { id = id, finish = finish, by = me, expires = time() + PROP_LIFE, yes = {}, no = {} }
    Send(code, ("SPROP|%s|%d|%d"):format(id, finish, st.prop.expires))
    self:Print(("Season proposed in |cffffd100%s|r, until |cffffd100%s|r. It starts when %d other member accepts.")
        :format(g.name, self:DateText(finish), NEEDED))
    Refresh()
end

local function Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
FM.SeasonVotes = function(prop) return Count(prop and prop.yes), NEEDED end

local function StartSeason(code, id, start, finish, by)
    local st = S(code)
    if st.cur and st.cur.id == id then return end
    if st.cur then return end   -- one season at a time
    for _, h in ipairs(st.history) do if h.id == id then return end end
    st.cur = { id = id, start = start, finish = finish, by = by }
    st.prop = nil
    local g = FM:GetGroup(code)
    FM:Print(("|TInterface\\PVPFrame\\Icons\\PVP-Banner-Emblem-1:0|t |cffffd100A PvP season starts in %s!|r Ends on %s.")
        :format(g and g.name or "?", FM:DateText(finish)))
    pcall(PlaySound, SOUNDKIT and SOUNDKIT.UI_PVP_HONOR_PRESTIGE_RANK_UP or 8959)
    Refresh()
end

local function CheckAccepted(code)
    local st = S(code)
    local p = st.prop
    if not p or Count(p.yes) < NEEDED then return end
    local start = time()
    Send(code, ("SSTART|%s|%d|%d|%s"):format(p.id, start, p.finish, Clean(p.by)))
    StartSeason(code, p.id, start, p.finish, p.by)
end

function FM:VoteSeason(code, yes)
    local st = S(code)
    local p = st.prop
    if not p then return end
    local me = self:MyName()
    if p.by == me then return end
    p.voted = yes and "Y" or "N"
    if yes then p.yes[me] = true; p.no[me] = nil else p.no[me] = true; p.yes[me] = nil end
    Send(code, ("SVOTE|%s|%s"):format(p.id, yes and "Y" or "N"))
    CheckAccepted(code)
    Refresh()
end

StaticPopupDialogs["FRIENDMAP_SEASON_VOTE"] = {
    text = "%s\nuntil |cffffd100%s|r.\n\nDo you accept?",
    button1 = ACCEPT, button2 = DECLINE,
    OnAccept = function(_, data) FM:VoteSeason(data, true) end,
    OnCancel = function(_, data, reason) if reason == "clicked" then FM:VoteSeason(data, false) end end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["FRIENDMAP_SEASON_PROPOSE"] = {
    text = "New PvP season in |cffffd100%s|r\n\nEnd date (DD/MM or DD/MM/YYYY):",
    button1 = ACCEPT, button2 = CANCEL,
    hasEditBox = true, maxLetters = 10,
    OnShow = function(self)
        local eb = self.editBox or self.EditBox
        if eb then eb:SetText(date("%d/%m", time() + 30 * 86400)); eb:HighlightText() end
    end,
    OnAccept = function(self, data)
        local eb = self.editBox or self.EditBox
        FM:ProposeSeason(data, eb and eb:GetText())
    end,
    EditBoxOnEnterPressed = function(self)
        local p = self:GetParent()
        FM:ProposeSeason(p.data, self:GetText())
        p:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function FM:AskProposeSeason(code)
    local g = self:GetGroup(code)
    if not g then return end
    if S(code).cur then self:Print("|cffffaa00A season is already running in " .. g.name .. ".|r") return end
    StaticPopup_Show("FRIENDMAP_SEASON_PROPOSE", g.name, nil, code)
end

local function ShowVote(code)
    local p, g = S(code).prop, FM:GetGroup(code)
    if not p or not g or p.voted or p.by == FM:MyName() then return end
    StaticPopup_Show("FRIENDMAP_SEASON_VOTE", ("%s proposes a PvP season in |cffffd100%s|r"):format(p.by, g.name),
        FM:DateText(p.finish), code)
end
FM.ShowSeasonVote = ShowVote

----------------------------------------------------------------------
-- Messages
----------------------------------------------------------------------
FM.Handlers.SPROP = function(self, p, code, sender, short)
    local id, finish, expires = Clean(p[2]), tonumber(p[3]), tonumber(p[4])
    if id == "" or not finish or not expires or expires < time() then return end
    local st = S(code)
    if st.cur or (st.prop and st.prop.id == id) then return end
    for _, h in ipairs(st.history) do if h.id == id then return end end
    st.prop = { id = id, finish = finish, by = short, expires = expires, yes = {}, no = {} }
    local g = self:GetGroup(code)
    self:Print(("|cffffd100%s proposes a PvP season in %s|r until %s. Open the leaderboard (/fm top) to answer.")
        :format(short, g and g.name or "?", self:DateText(finish)))
    ShowVote(code)
    Refresh()
end

FM.Handlers.SVOTE = function(self, p, code, sender, short)
    local st = S(code)
    local prop = st.prop
    if not prop or prop.id ~= p[2] or short == prop.by then return end
    if p[3] == "Y" then prop.yes[short] = true; prop.no[short] = nil
    else prop.no[short] = true; prop.yes[short] = nil end
    CheckAccepted(code)
    Refresh()
end

FM.Handlers.SSTART = function(self, p, code, sender, short)
    local id, start, finish = Clean(p[2]), tonumber(p[3]), tonumber(p[4])
    local by = (p[5] and p[5] ~= code) and Clean(p[5]) or short
    if id == "" or not start or not finish or finish < time() then return end
    StartSeason(code, id, start, finish, by)
end

-- someone appears: tell them about the running season and the open proposal
local baseNewMember = FM.OnNewMember
function FM:OnNewMember(code, ...)
    if baseNewMember then baseNewMember(self, code, ...) end
    local st = S(code)
    C_Timer.After(3 + math.random() * 3, function()
        if st.cur then
            Send(code, ("SSTART|%s|%d|%d|%s"):format(st.cur.id, st.cur.start, st.cur.finish, Clean(st.cur.by)))
        end
        if st.prop and st.prop.expires > time() then
            Send(code, ("SPROP|%s|%d|%d"):format(st.prop.id, st.prop.finish, st.prop.expires))
            if st.prop.voted then Send(code, ("SVOTE|%s|%s"):format(st.prop.id, st.prop.voted)) end
        end
    end)
end

----------------------------------------------------------------------
-- End of season: save the final standings in the history
----------------------------------------------------------------------
local function Finish(code)
    local st = S(code)
    local cur = st.cur
    local view = FM:SeasonView(code, cur)
    local top = {}
    for i, e in ipairs(FM:Leaderboard(nil, view)) do
        top[i] = { name = e.name, n = e.n, k = e.k, a = e.a, class = FM:KillerClass(e.name) }
    end
    table.insert(st.history, 1, { id = cur.id, start = cur.start, finish = cur.finish, by = cur.by, top = top })
    st.cur = nil
    local g = FM:GetGroup(code)
    local w = top[1]
    FM:Print(("|cffffd100The PvP season of %s is over!|r %s"):format(g and g.name or "?",
        w and ("Winner: |cffffd100" .. w.name .. "|r with " .. w.n .. " points.") or "No kills."))
    Refresh()
end

local since = 0
C_Timer.NewTicker(15, function()
    if not FM.worldReady or not FriendMapDB then return end
    since = since + 15
    local now = time()
    for _, g in ipairs(FriendMapDB.groups or {}) do
        local st = S(g.code)
        if st.prop and st.prop.expires < now then st.prop = nil; Refresh() end
        -- wait a minute after login so kills made while offline are synced first
        if st.cur and st.cur.finish < now and since >= 60 then Finish(g.code) end
    end
end)

-- leaving a group forgets its seasons
local baseLeave = FM.LeaveGroup
if baseLeave then
    function FM:LeaveGroup(g, ...)
        local code = type(g) == "table" and g.code or g
        if FriendMapDB.seasons and code then FriendMapDB.seasons[code] = nil end
        return baseLeave(self, g, ...)
    end
end

----------------------------------------------------------------------
-- /fm season
----------------------------------------------------------------------
FM.SlashExtra = FM.SlashExtra or {}
FM.SlashExtra.season = function()
    if #FriendMapDB.groups == 0 then FM:Print("You are not in any group.") return end
    for _, g in ipairs(FriendMapDB.groups) do
        local st = S(g.code)
        if st.cur then
            FM:Print(("%s: season running until %s."):format(g.name, FM:DateText(st.cur.finish)))
        elseif st.prop then
            FM:Print(("%s: season proposed by %s until %s (%d/%d accepted)."):format(g.name, st.prop.by,
                FM:DateText(st.prop.finish), Count(st.prop.yes), NEEDED))
        else
            FM:Print(("%s: no season. Propose one from the Seasons tab of /fm top."):format(g.name))
        end
    end
    FM:ToggleSeasons()
end
