-- Pure Lua 5.1 recruitment model. No game APIs, frames, timers or chat writes.
local addon = VOA25
addon.INVITE_WAIT = 60
addon.JOINED_DELAY = 5
addon.MAX_APPLICANTS = 250
addon.specs, addon.classByToken = {}, {}
for _, class in ipairs(addon.classes) do
    addon.classByToken[class.token] = class
    for _, spec in ipairs(class.specs) do
        addon.specs[spec[1]] = { id = spec[1], label = (#class.specs == 1 and class.name or spec[2] .. " " .. class.name), class = class.token }
    end
end

local aliases = {
    prot = {"ProtWarr", "ProtPala"}, protection = {"ProtWarr", "ProtPala"},
    arms = {"DpsWarr"}, fury = {"DpsWarr"},
    shadow = {"ShadowPriest"}, spriest = {"ShadowPriest"}, sp = {"ShadowPriest"},
    disc = {"HealPriest"}, discipline = {"HealPriest"}, holy = {"HealPriest", "HolyPala"},
    blood = {"TankDk", "DpsDk"}, frost = {"TankDk", "DpsDk", "Mage"}, unholy = {"TankDk", "DpsDk"},
    ret = {"RetPala"}, retri = {"RetPala"}, retribution = {"RetPala"},
    boomkin = {"BalDruid"}, boomie = {"BalDruid"}, moonkin = {"BalDruid"}, balance = {"BalDruid"}, bal = {"BalDruid"},
    feral = {"FeralDruid"}, cat = {"FeralDruid"}, bear = {"FeralDruid"},
    resto = {"RestoDruid", "RestoSham"}, restoration = {"RestoDruid", "RestoSham"},
    ele = {"EleSham"}, elemental = {"EleSham"}, enh = {"EnhSham"}, enha = {"EnhSham"}, enhancement = {"EnhSham"},
    rogue = {"Rogue"}, mage = {"Mage"}, warlock = {"Warlock"}, lock = {"Warlock"}, hunter = {"Hunter"},
}
local classWords = { warrior="WARRIOR", warr="WARRIOR", priest="PRIEST", dk="DEATHKNIGHT", deathknight="DEATHKNIGHT",
    druid="DRUID", sham="SHAMAN", shaman="SHAMAN", pala="PALADIN", paladin="PALADIN", rogue="ROGUE", mage="MAGE",
    hunter="HUNTER", warlock="WARLOCK", lock="WARLOCK" }
local roles = {
    tank={"ProtWarr", "TankDk", "FeralDruid", "ProtPala"},
    heal={"HealPriest", "RestoDruid", "RestoSham", "HolyPala"},
    dps={"DpsWarr", "ShadowPriest", "DpsDk", "BalDruid", "FeralDruid", "EleSham", "EnhSham", "RetPala", "Warlock", "Rogue", "Hunter", "Mage"},
}

function addon.PlayerKey(name)
    if type(name) ~= "string" then return nil end
    name = string.match(name, "^%s*(.-)%s*$")
    if name == "" or #name > 80 or string.find(name, "[%c|]") then return nil end
    return string.lower(name)
end

function addon.ParseWhisper(text, classToken)
    local words, found, hinted, relevant = {}, {}, nil, false
    text = type(text) == "string" and text or ""
    -- Strip links and formatting before matching complete words.
    text = string.gsub(text, "|H.-|h.-|h", " ")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.lower(text)
    for word in string.gmatch(text, "[a-z]+") do words[word] = true end
    for word, token in pairs(classWords) do
        if words[word] then
            relevant = true
            if hinted and hinted ~= token then hinted = false; break end
            hinted = token
        end
    end
    local class = addon.classByToken[classToken] and classToken or hinted or nil
    for word, ids in pairs(aliases) do
        if words[word] then
            relevant = true
            for _, id in ipairs(ids) do if not class or addon.specs[id].class == class then found[id] = true end end
        end
    end
    local roleFound = {}
    for word, ids in pairs(roles) do
        if words[word] or (word == "heal" and (words.healer or words.heals or words.healing)) or (word == "tank" and words.tanking) then
            relevant = true
            for _, id in ipairs(ids) do if not class or addon.specs[id].class == class then roleFound[id] = true end end
        end
    end
    if next(found) and next(roleFound) then
        -- Role resolves talent names such as frost DPS/tank; conflicting roles stay ambiguous.
        local intersection = {}
        for id in pairs(found) do if roleFound[id] then intersection[id] = true end end
        if next(intersection) then found = intersection else for id in pairs(roleFound) do found[id] = true end end
    elseif not next(found) then found = roleFound end
    local emblems = string.find(text, "only%s+emblems?") or string.find(text, "emblems?%s+only")
    relevant = relevant or words.inv or words.invite or emblems
    if relevant and not next(found) and class and #addon.classByToken[class].specs == 1 then
        found[addon.classByToken[class].specs[1][1]] = true
    end
    local candidates = {}
    for _, group in ipairs(addon.classes) do
        for _, spec in ipairs(group.specs) do if found[spec[1]] then candidates[#candidates + 1] = spec[1] end end
    end
    return candidates, not not relevant, class, not not emblems
end

local Model = {}
Model.__index = Model
function addon.NewRecruitment(db)
    local saved = type(db.recruitment) == "table" and db.recruitment or {}
    local self = setmetatable({ db=db, people={}, order={}, active=saved.active == true, serial=0 }, Model)
    if type(saved.people) == "table" then
        for _, old in ipairs(saved.people) do
            if #self.order >= addon.MAX_APPLICANTS then break end
            local key = type(old) == "table" and addon.PlayerKey(old.name)
            if key and not self.people[key] then
                local p = self:Ensure(old.name, old.class, old.guid)
                p.spec = addon.specs[old.spec] and old.spec or nil
                if p.spec and p.class and addon.specs[p.spec].class ~= p.class then p.spec = nil end
                p.counted, p.chosen = old.counted ~= false, old.chosen == true
                p.message = addon.CleanSuffix(old.message)
                p.specMessage = addon.CleanSuffix(old.specMessage or old.message)
                p.state = ({waiting=true, pending=true, joined=true, declined=true, left=true})[old.state] and old.state or "waiting"
                -- No old timer or reservation survives a reload. Membership must be revalidated.
                p.released = p.state == "pending"
                p.noResponse = p.state == "pending"
                p.present = false
            end
        end
    end
    db.recruitment = { active=self.active, people=self.order }
    return self
end
function Model:SetActive(value)
    self.active = not not value
    self.db.recruitment.active = self.active
end
function Model:Ensure(name, class, guid)
    local key = addon.PlayerKey(name)
    if not key then return nil end
    local p = self.people[key]
    if not p then
        if #self.order >= addon.MAX_APPLICANTS then return nil end
        self.serial = self.serial + 1
        p = {name=name, key=key, sequence=self.serial, state="waiting", counted=true, message=""}
        self.people[key] = p
        self.order[#self.order + 1] = p
    end
    if addon.classByToken[class] then p.class = class end
    if type(guid) == "string" and #guid < 100 then p.guid = guid end
    return p
end
function Model:Whisper(name, message, class, guid)
    if not self.active then return end
    local key = addon.PlayerKey(name)
    local p = key and self.people[key]
    local candidates, relevant, inferred, emblems = addon.ParseWhisper(message, class or (p and p.class))
    if not p and not relevant then return end
    p = self:Ensure(name, class or inferred, guid)
    if not p then return nil, "Applicant list is full. Start a new run to clear it." end
    p.message = addon.CleanSuffix(message)
    -- Keep the last actual spec claim when the latest whisper is just "ty" or "inv".
    if #candidates > 0 then p.specMessage = p.message
    elseif p.specMessage then candidates = addon.ParseWhisper(p.specMessage, p.class) end
    if p.state == "left" then p.state = "waiting"; p.chosen = false; p.counted = true end
    if (p.state == "waiting" or ((p.state == "pending" or p.state == "joined") and not p.spec)) and not p.chosen and relevant then
        p.candidates = candidates
        if #candidates > 0 then p.spec = #candidates == 1 and candidates[1] or nil end
        if emblems then p.counted = false; p.chosen = true end
    end
    return p
end
function Model:SetSpec(p, id)
    if not p or (id and not addon.specs[id]) then return false end
    if id and p.class and addon.specs[id].class ~= p.class then return false end
    p.spec, p.chosen, p.counted = id, true, id ~= nil
    return true
end
function Model:Coverage()
    local filled, pending, effective = {}, {}, {}
    for id, value in pairs(self.db.filled) do if value then filled[id] = true end end
    for _, p in ipairs(self.order) do
        if p.spec and p.counted then
            if p.state == "joined" and p.present then filled[p.spec] = true end
            if p.state == "pending" and not p.released then pending[p.spec] = true end
        end
    end
    for id in pairs(filled) do effective[id] = true end
    for id in pairs(pending) do effective[id] = true end
    return filled, pending, effective
end
function Model:SetFilled(id, value)
    if not addon.specs[id] then return end
    self.db.filled[id] = not not value
    if not value then
        for _, p in ipairs(self.order) do
            if p.spec == id then
                if p.state == "joined" then p.counted = false end
                if p.state == "pending" then p.released = true end
            end
        end
    end
end
function Model:ResetSpecs()
    for id in pairs(addon.specs) do self:SetFilled(id, false) end
    self.db.filled = {}
end
function Model:NewRun()
    self.people, self.order, self.serial = {}, {}, 0
    self.db.filled = {}
    self.db.recruitment.people = self.order
    self:SetActive(true)
end
function Model:Invited(name, now)
    if not self.active then return end
    local p = self:Ensure(name)
    if not p or (p.state == "joined" and p.present) then return end
    if p.state == "pending" then return p end -- duplicate calls cannot extend the timer
    p.state, p.invitedAt, p.noResponse, p.released = "pending", now, false, false
    p.failure = nil
    return p
end
function Model:Failure(name, reason)
    local key = addon.PlayerKey(name)
    local p = key and self.people[key]
    if not p or p.state ~= "pending" then return false end
    p.state, p.released, p.noResponse, p.failure = "waiting", false, false, reason
    return true
end
function Model:Decline(p)
    if p and (p.state == "waiting" or p.state == "left") then p.state = "declined"; return true end
    return false
end
function Model:Undo(p)
    if p and p.state == "declined" then p.state = "waiting"; return true end
    return false
end
function Model:Release(p)
    if p and p.state == "pending" then p.released = true; return true end
    return false
end
function Model:KeepWaiting(p, now)
    if p and p.state == "pending" then p.invitedAt=now; p.noResponse=false end
end
function Model:Tick(now)
    local changed = false
    for _, p in ipairs(self.order) do
        if p.state == "pending" and not p.noResponse and p.invitedAt and now - p.invitedAt >= addon.INVITE_WAIT then
            p.noResponse = true; changed = true
        end
        if p.state == "joined" and p.joinedAt and now - p.joinedAt >= addon.JOINED_DELAY then
            p.joinedAt = nil; changed = true
        end
    end
    return changed
end
function Model:Roster(roster, now)
    local seen, retry = {}, false
    for _, member in ipairs(roster) do
        local key = addon.PlayerKey(member.name)
        local p = key and self.people[key]
        if not p and self.active then p = self:Ensure(member.name, member.class, member.guid) end
        if p then
            self:Ensure(p.name, member.class, member.guid)
            seen[p.key] = true
            if p.state ~= "joined" then
                if p.state == "declined" then p.counted = false end
                p.state, p.joinedAt = "joined", now
            end
            p.present, p.missingAt = true, nil
            if not p.spec and not p.chosen then
                local candidates = addon.ParseWhisper(p.specMessage or p.message, p.class)
                if #candidates == 1 then p.spec = candidates[1]
                elseif p.class and #addon.classByToken[p.class].specs == 1 then p.spec=addon.classByToken[p.class].specs[1][1] end
            end
            if p.spec and p.class and addon.specs[p.spec].class ~= p.class then p.spec=nil end
        end
    end
    for _, p in ipairs(self.order) do
        if p.state == "joined" and not seen[p.key] then
            -- Confirm absence in a second snapshot; raid conversion may briefly empty the roster.
            if p.missingAt and now - p.missingAt >= 0.5 then
                p.state, p.present, p.joinedAt, p.missingAt = "left", false, nil, nil
            else p.missingAt = p.missingAt or now; retry = true end
        end
    end
    return retry
end
function Model:Status(p)
    if p.state == "declined" then return "Declined" end
    if p.state == "joined" then
        if p.counted and not p.spec then return "Needs a spec" end
        return p.counted and p.spec and "Joined" or "Joined - not counted"
    end
    if p.state == "pending" then
        if p.released then return "Invited - slot released" end
        return p.noResponse and "No response" or "Invited"
    end
    if p.state == "left" then return "Left group" end
    if not p.counted then return "No slot needed" end
    if not p.spec then return "Choose spec" end
    local filled, pending = self:Coverage()
    if filled[p.spec] then return "Covered" end
    if pending[p.spec] then return "Reserved" end
    return "Needed"
end
function Model:CanInvite(p)
    if not p or p.state ~= "waiting" then return false, "This player is not waiting for an invite." end
    if p.counted and not p.spec then return false, "Choose a spec first." end
    local _, pending = self:Coverage()
    if p.counted and pending[p.spec] then return false, "Another invitation reserves this spec." end
    return true
end
function Model:Entries(expanded, now)
    local entries, joined, declined = {}, {}, {}
    -- Unresolved group members must not disappear into history after five seconds.
    for _, p in ipairs(self.order) do
        if p.state == "joined" and p.counted and not p.spec then entries[#entries+1]={person=p} end
    end
    for _, p in ipairs(self.order) do
        if p.state == "declined" then declined[#declined+1] = p
        elseif p.state == "joined" and p.counted and not p.spec then -- already shown above
        elseif p.state == "joined" and (not p.joinedAt or now-p.joinedAt >= addon.JOINED_DELAY) then joined[#joined+1]=p
        else entries[#entries+1]={person=p} end
    end
    for _, section in ipairs({{key="joined", label="Joined", people=joined}, {key="declined", label="Declined", people=declined}}) do
        if #section.people > 0 then
            entries[#entries+1]={section=section.key, label=section.label .. " (" .. #section.people .. ")"}
            if expanded[section.key] then for _, p in ipairs(section.people) do entries[#entries+1]={person=p} end end
        end
    end
    return entries
end

-- Match localized, named invite messages, never an English substring or an unnamed error.
function addon.InviteFailureName(message, template)
    if type(message) ~= "string" or type(template) ~= "string" then return end
    local start, finish = string.find(template, "%%s")
    if not start then start, finish = string.find(template, "%%1%$s") end
    if not start then return end
    local function escape(s) return (string.gsub(s, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")) end
    local pattern = "^" .. escape(string.sub(template, 1, start-1)) .. "(.+)" .. escape(string.sub(template, finish+1)) .. "$"
    return string.match(message, pattern)
end
