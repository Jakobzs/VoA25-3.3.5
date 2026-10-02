-- Standalone Lua 5.1 logic, shared by the UI and regression tests.
VOA25 = {}
local addon = VOA25

-- Keep IDs, ordering, abbreviations and labels aligned with crates/voa25.
addon.classes = {
    { name = "Warrior", token = "WARRIOR", short = "warr", specs = {
        { "ProtWarr", "Protection", "prot" }, { "DpsWarr", "DPS", "dps" },
    } },
    { name = "Priest", token = "PRIEST", short = "priest", specs = {
        { "HealPriest", "Heal", "heal" }, { "ShadowPriest", "Shadow", "shadow" },
    } },
    { name = "Death Knight", token = "DEATHKNIGHT", short = "dk", specs = {
        { "TankDk", "Tank", "tank" }, { "DpsDk", "DPS", "dps" },
    } },
    { name = "Druid", token = "DRUID", short = "druid", specs = {
        { "BalDruid", "Balance", "bal" }, { "FeralDruid", "Feral", "feral" },
        { "RestoDruid", "Restoration", "resto" },
    } },
    { name = "Shaman", token = "SHAMAN", short = "sham", specs = {
        { "EleSham", "Elemental", "ele" }, { "EnhSham", "Enhancement", "enh" },
        { "RestoSham", "Restoration", "resto" },
    } },
    { name = "Paladin", token = "PALADIN", short = "pala", specs = {
        { "HolyPala", "Holy", "holy" }, { "ProtPala", "Protection", "prot" },
        { "RetPala", "Retribution", "ret" },
    } },
    { name = "Warlock", token = "WARLOCK", short = "warlock", specs = {
        { "Warlock", "Filled" },
    } },
    { name = "Rogue", token = "ROGUE", short = "rogue", specs = {
        { "Rogue", "Filled" },
    } },
    { name = "Hunter", token = "HUNTER", short = "hunter", specs = {
        { "Hunter", "Filled" },
    } },
    { name = "Mage", token = "MAGE", short = "mage", specs = {
        { "Mage", "Filled" },
    } },
}

addon.CHAT_LIMIT = 255

-- Keep the editable value single-line and bounded without cutting a UTF-8 character.
-- Spaces are retained here so typing a space does not move the cursor backwards.
function addon.CleanMessageText(value)
    if type(value) ~= "string" then return "" end
    value = string.gsub(value, "%c", " ")
    if #value > addon.CHAT_LIMIT then
        local last = addon.CHAT_LIMIT
        while last > 0 and string.byte(value, last + 1) >= 128 and string.byte(value, last + 1) < 192 do
            last = last - 1
        end
        value = string.sub(value, 1, last)
    end
    return value
end

-- Keep existing callers compatible while sharing validation between both fields.
addon.CleanSuffix = addon.CleanMessageText

function addon.Generate(filled, suffix, prefix)
    local needs, count = {}, 0
    for _, class in ipairs(addon.classes) do
        local missing = {}
        for _, spec in ipairs(class.specs) do
            if filled[spec[1]] then
                count = count + 1
            elseif spec[3] then
                missing[#missing + 1] = spec[3]
            else
                needs[#needs + 1] = class.short
            end
        end
        if #missing > 0 then
            needs[#needs + 1] = table.concat(missing, "/") .. " " .. class.short
        end
    end
    local output = "LFM VOA25"
    prefix = string.match(addon.CleanMessageText(prefix), "^%s*(.-)%s*$")
    if prefix ~= "" then output = output .. " " .. prefix end
    if #needs > 0 then
        output = output .. " need " .. table.concat(needs, ", ")
    end
    suffix = string.match(addon.CleanSuffix(suffix), "^%s*(.-)%s*$")
    if suffix ~= "" then output = output .. " " .. suffix end
    return output, count
end

function addon.NormalizeDB(saved)
    local db = { filled = {}, suffix = "", prefix = "" }
    if type(saved) ~= "table" then return db end
    db.suffix = addon.CleanSuffix(saved.suffix)
    db.prefix = addon.CleanMessageText(saved.prefix)
    -- Recruitment.lua validates and copies this session after the generator migration.
    if type(saved.recruitment) == "table" then db.recruitment = saved.recruitment end
    if type(saved.filled) == "table" then
        for _, class in ipairs(addon.classes) do
            for _, spec in ipairs(class.specs) do
                db.filled[spec[1]] = saved.filled[spec[1]] == true
            end
        end
    end
    local p = saved.position
    local function finite(n)
        return type(n) == "number" and n == n and n > -math.huge and n < math.huge
    end
    if type(p) == "table" and finite(p.x) and finite(p.y) then
        db.position = { x = p.x, y = p.y }
    end
    return db
end
