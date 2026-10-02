-- Original 3.3.5a game boundary. All recruitment decisions live in Recruitment.lua.
local addon = VOA25

function addon.StartRecruitment(db, refresh)
    local model = addon.NewRecruitment(db)
    addon.recruitment = model
    local client = {model=model, refresh=refresh}
    addon.recruitmentClient = client
    local events = CreateFrame("Frame")
    client.events = events
    local rosterDue, elapsed = nil, 0

    function client:Name(name)
        if type(name) ~= "string" then return name end
        local short, realm = string.match(name, "^([^%-]+)%-(.+)$")
        local home = GetRealmName()
        if short and string.lower(string.gsub(realm, "%s", "")) == string.lower(string.gsub(home, "%s", "")) then return short end
        return name
    end
    function client:QueueRoster()
        rosterDue = GetTime() + 0.2
    end
    function client:ReadRoster()
        local result, raid, party = {}, GetNumRaidMembers(), GetNumPartyMembers()
        local function add(unit)
            if not UnitExists(unit) then return false end
            local name, realm = UnitName(unit)
            if not name or name == UNKNOWNOBJECT or name == UNKNOWN then return false end
            if realm and realm ~= "" then name = name .. "-" .. realm end
            result[#result+1] = {name=self:Name(name), class=select(2, UnitClass(unit)), guid=UnitGUID(unit)}
            return true
        end
        if raid > 0 then
            for i=1,raid do if not add("raid" .. i) then return nil end end
        else
            if not add("player") then return nil end
            for i=1,party do if not add("party" .. i) then return nil end end
        end
        return result
    end
    function client:SetActive(active)
        model:SetActive(active)
        if active then self:QueueRoster() end
        refresh()
    end
    function client:GroupSummary()
        local raid, party = GetNumRaidMembers(), GetNumPartyMembers()
        local pending = 0
        for _, person in ipairs(model.order) do
            if person.state=="pending" and not person.released then pending=pending+1 end
        end
        return raid > 0 and raid or party + 1, pending, raid > 0
    end
    function client:RecruitmentBlocker()
        if not model.active then return false, "Enable Recruiting first." end
        local raid, party = GetNumRaidMembers(), GetNumPartyMembers()
        if raid > 0 and not (IsRaidLeader() or IsRaidOfficer()) then return false, "Raid leader or assistant is required." end
        if raid == 0 and party > 0 and not IsPartyLeader() then return false, "You are not the party leader." end
        local _, pending = self:GroupSummary()
        if raid > 0 and raid+pending >= 25 then return false, "All 25 raid places are filled or reserved." end
        if raid == 0 and party+1+pending >= 5 then return false, "Convert the party to a raid before inviting more players." end
        return true
    end
    function client:InvitePermission(p)
        if not model.active then return false, "Enable Recruiting first." end
        local ok, reason = model:CanInvite(p)
        if not ok then return false, reason end
        return self:RecruitmentBlocker()
    end
    function client:Invite(p)
        local ok, reason = self:InvitePermission(p)
        if not ok then addon.RecruitmentNotice(reason); return false end
        -- InviteUnit is also observed for /invite and the standard unit popup.
        InviteUnit(p.name)
        refresh()
        return true
    end
    function client:NewRun()
        model:NewRun()
        self:QueueRoster()
        refresh()
    end
    function client:RefreshRoster(now)
        local roster = self:ReadRoster()
        if not roster then rosterDue=now+0.5; return end
        rosterDue = model:Roster(roster, now) and now+0.5 or nil
        refresh()
    end
    hooksecurefunc("InviteUnit", function(name)
        -- A /reload creates a fresh Lua environment; the guard also makes harness reloads safe.
        if addon.recruitmentClient ~= client or not model.active then return end
        model:Invited(client:Name(name), GetTime())
        refresh()
    end)
    for _, event in ipairs({"CHAT_MSG_WHISPER", "CHAT_MSG_SYSTEM", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ENTERING_WORLD"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_WHISPER" then
            local message, name = ...
            local guid = select(12, ...)
            local class
            if type(guid)=="string" and guid~="" then class=select(2, GetPlayerInfoByGUID(guid)) end
            local _, reason = model:Whisper(client:Name(name), message, class, guid)
            if reason then addon.RecruitmentNotice(reason) end
            refresh()
        elseif event == "CHAT_MSG_SYSTEM" then
            local message = ...
            for _, constant in ipairs({"ERR_DECLINE_GROUP_S", "ERR_ALREADY_IN_GROUP_S", "ERR_BAD_PLAYER_NAME_S"}) do
                local name = addon.InviteFailureName(message, _G[constant])
                if name and model:Failure(client:Name(name), message) then
                    addon.RecruitmentNotice(message)
                    refresh()
                    break
                end
            end
        else client:QueueRoster() end
    end)
    events:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed < 0.2 then return end
        elapsed = 0
        local now = GetTime()
        if rosterDue and now >= rosterDue then client:RefreshRoster(now) end
        if model:Tick(now) then refresh() end
    end)
    return client
end
