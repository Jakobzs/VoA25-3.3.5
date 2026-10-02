local addon = VOA25

-- Optional, bounded checks of real generator functions using temporary data only.
-- Never replaces WoW APIs, touches saved settings, or runs automatically.
function addon.RunSelfTest()
    local cases = {}
    local function case(name, run) cases[#cases + 1] = { name, run } end
    local allNeeds = "LFM VOA25 need prot/dps warr, heal/shadow priest, tank/dps dk, bal/feral/resto druid, ele/enh/resto sham, holy/prot/ret pala, warlock, rogue, hunter, mage"
    case("empty selection", function()
        local message, count = addon.Generate({})
        assert(message == allNeeds and count == 0)
    end)
    case("all specs filled", function()
        local filled = {}
        for _, class in ipairs(addon.classes) do
            for _, spec in ipairs(class.specs) do filled[spec[1]] = true end
        end
        local message, count = addon.Generate(filled)
        assert(message == "LFM VOA25" and count == 19)
    end)
    case("mixed selection", function()
        local message, count = addon.Generate({ ProtWarr = true, Mage = true })
        assert(message == "LFM VOA25 need dps warr, heal/shadow priest, tank/dps dk, bal/feral/resto druid, ele/enh/resto sham, holy/prot/ret pala, warlock, rogue, hunter")
        assert(count == 2)
    end)
    case("custom prefix and suffix", function()
        assert(addon.Generate({}, "- guild run") == allNeeds .. " - guild run")
        assert(addon.Generate({}, "- guild run", "  quick run  ") ==
            "LFM VOA25 quick run" .. string.sub(allNeeds, 10) .. " - guild run")
    end)
    case("blank suffix", function()
        assert(addon.Generate({}, "   ") == allNeeds)
    end)
    case("single-line suffix", function()
        assert(addon.Generate({}, "  hello\nworld  ") == allNeeds .. " hello world")
    end)
    case("old saved settings", function()
        local saved = { filled = { Mage = true }, position = { x = 10, y = -20 } }
        local db = addon.NormalizeDB(saved)
        assert(db.filled.Mage and db.suffix == "" and db.prefix == "" and db.position.y == -20)
        assert(saved.suffix == nil and db.filled ~= saved.filled)
    end)
    case("message options persistence", function()
        local db = addon.NormalizeDB({ filled = { Rogue = true }, prefix = "quick run", suffix = "- guild run" })
        local restored = addon.NormalizeDB(db)
        assert(restored.prefix == "quick run" and restored.suffix == "- guild run" and restored.filled.Rogue)
    end)
    case("invalid saved data", function()
        local db = addon.NormalizeDB({ filled = "invalid", suffix = false })
        assert(next(db.filled) == nil and db.suffix == "")
    end)
    case("chat length boundary", function()
        local room = addon.CHAT_LIMIT - #allNeeds - 1
        assert(#addon.Generate({}, string.rep("x", room)) == 255)
        assert(#addon.Generate({}, string.rep("x", room + 1)) == 256)
    end)
    case("UTF-8 suffix boundary", function()
        local value = string.rep("x", 254) .. "\195\166"
        assert(addon.CleanSuffix(value) == string.rep("x", 254))
        assert(addon.CleanSuffix("\195\166") == "\195\166")
    end)
    local passed, failures = 0, {}
    for _, test in ipairs(cases) do
        local ok, err = pcall(test[2])
        if ok then
            passed = passed + 1
        else
            failures[#failures + 1] = test[1] .. ": " .. tostring(err)
        end
    end
    return passed, #cases, failures
end
