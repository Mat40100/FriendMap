-- New-version notice: every FriendMap tells its groups which version it runs
-- (and relays the newest one it has heard of). When a newer one shows up,
-- you get a one-time message with the download link.
local FM = FriendMap
local ADDON = ...

FM.DOWNLOAD_URL = "https://github.com/Mat40100/FriendMap/releases/latest"

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
FM.VERSION = (GetMeta and GetMeta(ADDON, "Version")) or "0"

local function Parse(v)
    local a, b, c = tostring(v or ""):match("^(%d+)%.?(%d*)%.?(%d*)")
    return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

-- true if version a is newer than version b
function FM:IsNewer(a, b)
    local a1, a2, a3 = Parse(a)
    local b1, b2, b3 = Parse(b)
    if a1 ~= b1 then return a1 > b1 end
    if a2 ~= b2 then return a2 > b2 end
    return a3 > b3
end

local told = {} -- groups we already announced our version to this session

function FM:AnnounceVersion(g, force)
    if told[g.code] and not force then return end
    told[g.code] = true
    -- send the newest version we know of, so news spreads even through people who haven't updated
    local newest = (FriendMapDB.newestVersion and self:IsNewer(FriendMapDB.newestVersion, self.VERSION))
        and FriendMapDB.newestVersion or self.VERSION
    self:SendToGroup(g, ("VER|%s|%s"):format(self.VERSION, newest))
end

local function Notify(version, from)
    FM:Print(("|cff00ff00A new version of FriendMap is available: %s|r (you have %s)%s"):format(
        version, FM.VERSION, from and (" - seen from " .. from) or ""))
    FM:Print("Download: |cffffd100" .. FM.DOWNLOAD_URL .. "|r  (type |cffffd100/fm update|r to copy the link)")
end

FM.Handlers.VER = function(self, p, code, sender, short)
    local theirs, newest = p[2], p[3]
    if newest == code then newest = theirs end
    local candidate = newest
    if theirs and self:IsNewer(theirs, candidate or "0") then candidate = theirs end
    if candidate and self:IsNewer(candidate, self.VERSION)
        and (not FriendMapDB.newestVersion or self:IsNewer(candidate, FriendMapDB.newestVersion)) then
        FriendMapDB.newestVersion = candidate
        Notify(candidate, short)
        self:RefreshUI()
    end
    -- they run an older version than what we know: reply once so they learn about it
    local mine = FriendMapDB.newestVersion and self:IsNewer(FriendMapDB.newestVersion, self.VERSION)
        and FriendMapDB.newestVersion or self.VERSION
    if self:IsNewer(mine, newest or theirs or "0") then
        local g = self:GetGroup(code)
        if g then self:AnnounceVersion(g, true) end
    end
end

StaticPopupDialogs["FRIENDMAP_UPDATE"] = {
    text = "FriendMap download page\nCtrl+C to copy, then open it in your browser:",
    button1 = OKAY,
    hasEditBox = true, editBoxWidth = 300,
    OnShow = function(self)
        local eb = self.editBox or self.EditBox
        eb:SetText(FM.DOWNLOAD_URL); eb:HighlightText(); eb:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

FM.SlashExtra.update = function() StaticPopup_Show("FRIENDMAP_UPDATE") end
FM.SlashExtra.version = function()
    FM:Print("Version " .. FM.VERSION .. (FriendMapDB.newestVersion and FM:IsNewer(FriendMapDB.newestVersion, FM.VERSION)
        and (" - |cff00ff00" .. FriendMapDB.newestVersion .. " available|r (/fm update)") or " - up to date"))
end

-- announce once per group after joining its channel; remind at login if an update is pending
local ticker
ticker = C_Timer.NewTicker(5, function()
    if not FM.worldReady or not FriendMapDB then return end
    if not FM.loginReminded then
        FM.loginReminded = true
        if FriendMapDB.newestVersion and FM:IsNewer(FriendMapDB.newestVersion, FM.VERSION) then
            Notify(FriendMapDB.newestVersion)
        else
            FriendMapDB.newestVersion = nil -- we updated
        end
    end
    for _, g in ipairs(FriendMapDB.groups) do
        if FM:IsConnected(g) then FM:AnnounceVersion(g) end
    end
end)
