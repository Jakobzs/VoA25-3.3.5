local addon = VOA25
local UI = addon.UI
local window, db
local checks = {}
local WIDTH, HEIGHT = 780, 610
local activateOnOpen

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0VoA25:|r " .. message)
end
function addon.RecruitmentNotice(message)
    Print(UI.Safe(message))
end

local function Refresh()
    if not window or not window.post then return end
    local model = addon.recruitment
    local filled, pending, effective = model:Coverage()
    local message = addon.Generate(effective, db.suffix, db.prefix)
    local _, count = addon.Generate(filled)
    local members, invitations = addon.recruitmentClient:GroupSummary()
    local applicants = 0
    local owners, reservations = {}, {}
    for _, p in ipairs(model.order) do
        if p.state=="waiting" or p.state=="left" then applicants=applicants+1 end
        if p.counted and p.spec then
            local target
            if p.state=="joined" and p.present then target=owners
            elseif p.state=="pending" and not p.released then target=reservations end
            if target then
                target[p.spec] = target[p.spec] or {}
                target[p.spec][#target[p.spec]+1] = p.name
            end
        end
    end
    window.message:SetText(UI.Safe(message))
    window.raidCount:SetText("Raid " .. members .. "/25")
    window.count:SetText("Specs " .. count .. "/19")
    window.invites:SetText("Invites " .. invitations)
    window.applicantsTab:SetText("Applicants (" .. applicants .. ")")
    window.specsTab:SetText("Specs (" .. count .. "/19)")
    window.recruiting:SetChecked(model.active)
    local tooLong = #message > addon.CHAT_LIMIT
    window.length:SetText(#message .. " / " .. addon.CHAT_LIMIT .. " bytes" .. (tooLong and " - shorten prefix or suffix" or ""))
    window.length:SetTextColor(tooLong and 1 or 0.7, tooLong and 0.4 or 0.72, tooLong and 0.35 or 0.77)
    if tooLong then window.post:Disable() else window.post:Enable() end
    for id, check in pairs(checks) do
        local state = filled[id] and "Filled" or pending[id] and "Invited" or "Open"
        check:SetChecked(filled[id] or pending[id])
        check.coverageState = state
        local names = filled[id] and owners[id] or reservations[id]
        local detail = state
        if names and #names > 0 then detail=names[1] .. (#names>1 and " +" .. (#names-1) or "")
        elseif filled[id] then detail="Manual" end
        if state=="Invited" then detail="Invited: " .. detail end
        check.detail:SetText(UI.Safe(detail))
        check.detail:SetTextColor(state=="Invited" and 0.94 or 0.67, state=="Invited" and 0.77 or 0.7, state=="Invited" and 0.4 or 0.76)
        check.mark:SetTexture(state=="Filled" and "Interface\\RaidFrame\\ReadyCheck-Ready"
            or state=="Invited" and "Interface\\RaidFrame\\ReadyCheck-Waiting" or "Interface\\Buttons\\UI-CheckBox-Up")
        local info = addon.specs[id].label .. "\n" .. state
        if owners[id] then info=info .. "\nJoined: " .. table.concat(owners[id], ", ") end
        if model.db.filled[id] then info=info .. "\nManually marked covered" end
        if reservations[id] then info=info .. "\nInvited: " .. table.concat(reservations[id], ", ") end
        check.help = info .. (state=="Open" and "\nClick to mark this spec manually covered."
            or "\nClick to reopen recruitment for this spec.\nPlayers stay in the group; game invitations are not cancelled.")
    end
    window.applicantsUI:Refresh()
end

local function ResetSpecs()
    addon.recruitment:ResetSpecs()
    if window then Refresh() end
    Print("All specs reopened for recruitment.")
end

StaticPopupDialogs["VOA25_CONFIRM_RESET"] = {
    text = "Reopen recruitment for every spec and release reservations?\n\nPlayers remain in your group. Outstanding game invites are not cancelled. Applicant decisions, prefix and suffix will be kept.",
    button1 = "Reset specs", button2 = CANCEL, OnAccept = ResetSpecs,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}
StaticPopupDialogs["VOA25_CONFIRM_NEW_RUN"] = {
    text = "Start a new VoA25 run?\n\nClear manual specs, assignments and applicant decisions. Current group members will be added again. Your prefix and suffix will be kept. Outstanding game invites are not cancelled.",
    button1 = "New run", button2 = CANCEL, timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnAccept = function()
        if window then
            window.applicantsUI.chooser:Hide()
            window.applicantsUI.expanded = {}
            FauxScrollFrame_SetOffset(window.applicantsUI.scroll, 0)
        end
        addon.recruitmentClient:NewRun()
    end,
}

local function ConfirmResetSpecs()
    if window and window.prefix then window.prefix:ClearFocus() end
    if window and window.suffix then window.suffix:ClearFocus() end
    StaticPopup_Show("VOA25_CONFIRM_RESET")
end

local function CenterWindow()
    db.position = nil
    if window then
        window:ClearAllPoints()
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function FitWindow()
    window:SetScale(math.min(1, UIParent:GetWidth() / (WIDTH + 24),
        UIParent:GetHeight() / (window:GetHeight() + 24)))
end

local function SavePosition(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    if x and y then
        local scale = self:GetScale()
        db.position = {x=x * scale - UIParent:GetWidth() / 2, y=y * scale - UIParent:GetHeight() / 2}
    end
end

local function CreateWindow()
    window = CreateFrame("Frame", "VOA25Frame", UIParent)
    window:Hide()
    window:SetSize(WIDTH, HEIGHT)
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", SavePosition)
    window:SetScript("OnHide", function(self)
        self:StopMovingOrSizing()
        if self.prefix then self.prefix:ClearFocus() end
        if self.suffix then self.suffix:ClearFocus() end
        if self.applicantsUI then self.applicantsUI.chooser:Hide() end
        GameTooltip:Hide()
    end)
    FitWindow()
    local p = db.position
    window:SetPoint("CENTER", UIParent, "CENTER",
        p and p.x / window:GetScale() or 0, p and p.y / window:GetScale() or 0)
    UI.Backdrop(window, 0.065, 0.08, 0.115)
    tinsert(UISpecialFrames, "VOA25Frame")
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() window:Hide() end)
    UI.Text(window, "GameFontNormalLarge", 400, 20, -20, "Vault of Archavon")
    UI.Text(window, "GameFontHighlightSmall", 400, 20, -44, "25-player recruitment")
    window.raidCount = UI.Text(window, "GameFontHighlightSmall", 110, 20, -70)
    window.count = UI.Text(window, "GameFontHighlightSmall", 120, 140, -70)
    window.invites = UI.Text(window, "GameFontHighlightSmall", 110, 270, -70)

    window.applicantsUI = addon.CreateApplicantsUI(window, Refresh)
    local specsPanel = CreateFrame("Frame", nil, window)
    specsPanel:SetSize(740, 342)
    specsPanel:SetPoint("TOPLEFT", window, "TOPLEFT", 20, -124)
    window.specsPanel = specsPanel
    UI.Rule(window, 740, 20, -112)
    local function Tab(showSpecs)
        window.showSpecs = showSpecs
        window.applicantsUI.chooser:Hide()
        if showSpecs then specsPanel:Show(); window.applicantsUI.panel:Hide()
        else specsPanel:Hide(); window.applicantsUI.panel:Show() end
        for _, button in ipairs({window.applicantsTab, window.specsTab}) do
            local selected = (button==window.specsTab) == showSpecs
            button.selected = selected
            button:SetNormalFontObject(selected and GameFontNormal or GameFontHighlightSmall)
            if selected then button.underline:Show() else button.underline:Hide() end
        end
    end
    window.applicantsTab = UI.Button(window, "Applicants", 150, 20, -86, function() Tab(false) end)
    window.specsTab = UI.Button(window, "Specs", 140, 178, -86, function() Tab(true) end)
    for _, button in ipairs({window.applicantsTab, window.specsTab}) do
        button:SetBackdrop(nil)
        button.underline = UI.Rule(button, button:GetWidth(), 0, -25, 0.92, 0.75, 0.35)
        button.underline:SetHeight(2)
    end
    Tab(false)
    local recruiting = CreateFrame("CheckButton", "VOA25Recruiting", window, "UICheckButtonTemplate")
    window.recruiting = recruiting
    recruiting:SetSize(24, 24)
    recruiting:SetPoint("TOPLEFT", window, "TOPLEFT", 506, -23)
    _G[recruiting:GetName().."Text"]:SetText("Recruiting")
    recruiting:SetHitRectInsets(0, -75, 0, 0)
    recruiting:SetScript("OnClick", function(self) addon.recruitmentClient:SetActive(not not self:GetChecked()) end)
    UI.Help(recruiting, "Collect recruitment whispers and observe invitations, even when this window is closed.\nUncheck to pause. Existing group assignments are still updated.")
    window.newRun = UI.Button(window, "New run", 96, 630, -24, function()
        window.prefix:ClearFocus()
        window.suffix:ClearFocus()
        window.applicantsUI.chooser:Hide()
        StaticPopup_Show("VOA25_CONFIRM_NEW_RUN")
    end)
    local credit = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    credit:SetPoint("TOPRIGHT", window.newRun, "BOTTOMRIGHT", 0, -6)
    credit:SetWidth(280)
    credit:SetJustifyH("RIGHT")
    credit:SetTextColor(0.65, 0.67, 0.72)
    credit:SetText("Made by |cffebbf59Zacho|r on ChromieCraft (|cffebbf59rayts5|r on Discord)")

    local legend = {
        {"Open", "Interface\\Buttons\\UI-CheckBox-Up", 0},
        {"Invited", "Interface\\RaidFrame\\ReadyCheck-Waiting", 86},
        {"Filled", "Interface\\RaidFrame\\ReadyCheck-Ready", 180},
    }
    for _, entry in ipairs(legend) do
        local icon = specsPanel:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("TOPLEFT", specsPanel, "TOPLEFT", entry[3], 2)
        icon:SetTexture(entry[2])
        UI.Text(specsPanel, "GameFontHighlightSmall", 70, entry[3]+20, 0, entry[1])
    end
    window.reset = UI.Button(specsPanel, "Reset specs", 100, 640, 3, ConfirmResetSpecs)
    window.reset:SetHeight(22)
    for index, class in ipairs(addon.classes) do
        local card = CreateFrame("Frame", nil, specsPanel)
        card:SetSize(142, 146)
        card:SetPoint("TOPLEFT", specsPanel, "TOPLEFT", ((index-1) % 5)*149, -24-math.floor((index-1)/5)*154)
        UI.Backdrop(card, 0.1, 0.13, 0.18)
        local icon = card:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -10)
        icon:SetTexture("Interface\\AddOns\\VOA25\\Textures\\" .. string.lower(class.token))
        local title = UI.Text(card, "GameFontNormal", 106, 32, -13, class.name)
        local color = RAID_CLASS_COLORS[class.token]
        if color then title:SetTextColor(color.r, color.g, color.b) end
        for specIndex, spec in ipairs(class.specs) do
            local id = spec[1]
            local check = CreateFrame("CheckButton", "VOA25Spec"..id, card, "UICheckButtonTemplate")
            check:SetSize(126, 33)
            check:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -39-(specIndex-1)*34)
            check:SetNormalTexture("")
            check:SetPushedTexture("")
            check:SetCheckedTexture("")
            local label = _G[check:GetName().."Text"]
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", check, "TOPLEFT", 20, 0)
            label:SetWidth(106)
            label:SetHeight(14)
            label:SetJustifyH("LEFT")
            label:SetFontObject(GameFontHighlightSmall)
            label:SetText(#class.specs==1 and "DPS" or spec[2])
            check.mark = check:CreateTexture(nil, "ARTWORK")
            check.mark:SetSize(16, 16)
            check.mark:SetPoint("TOPLEFT", check, "TOPLEFT", 0, 0)
            check.detail = UI.Text(check, "GameFontDisableSmall", 106, 20, -16)
            check.detail:SetHeight(14)
            check:SetScript("OnClick", function(self)
                -- Wrath getters return 1/nil rather than true/false.
                local filled = not not self:GetChecked()
                addon.recruitment:SetFilled(id, filled)
                Refresh()
                UI.Tooltip(self, self.help)
            end)
            UI.Help(check, function(self) return self.help end)
            checks[id] = check
        end
    end
    UI.Text(specsPanel, "GameFontDisableSmall", 740, 2, -330,
        "Click an open spec to cover it manually; click a filled or invited spec to reopen it.")

    local footer = CreateFrame("Frame", nil, window)
    footer:SetSize(740, 114)
    footer:SetPoint("TOPLEFT", window, "TOPLEFT", 20, -476)
    window.footer = footer
    UI.Rule(footer, 740, 0, 0)
    UI.Text(footer, "GameFontNormal", 320, 0, -12, "Recruitment message")
    window.length = UI.Text(footer, "GameFontDisableSmall", 400, 340, -13)
    window.length:SetJustifyH("RIGHT")
    local preview = CreateFrame("Frame", nil, footer)
    preview:SetSize(740, 54)
    preview:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, -32)
    UI.Backdrop(preview, 0.045, 0.06, 0.09)
    window.message = UI.Text(preview, "GameFontHighlightSmall", 716, 12, -10)
    local options = CreateFrame("Frame", nil, footer)
    options:SetSize(740, 60)
    options:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, -96)
    options:Hide()
    window.messageOptions = options
    local saved = UI.Text(options, "GameFontDisableSmall", 740, 0, -48, "Saved automatically per character")
    saved:SetJustifyH("RIGHT")
    local function MessageField(key, name, label, x)
        UI.Text(options, "GameFontNormalSmall", 360, x, 0, label)
        local field = CreateFrame("EditBox", name, options)
        window[key] = field
        field:SetSize(360, 26)
        field:SetPoint("TOPLEFT", options, "TOPLEFT", x, -20)
        field:SetFontObject(GameFontHighlightSmall)
        field:SetAutoFocus(false)
        field:SetMultiLine(false)
        field:SetMaxLetters(addon.CHAT_LIMIT)
        field:SetTextInsets(10, 10, 0, 0)
        UI.Backdrop(field, 0.045, 0.06, 0.09)
        field:SetText(db[key])
        field:SetScript("OnTextChanged", function(self)
            local value = addon.CleanMessageText(self:GetText())
            if self:GetText()~=value then self:SetText(value) end
            db[key] = value
            Refresh()
        end)
        field:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        field:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        return field
    end
    local prefix = MessageField("prefix", "VOA25Prefix", "Message prefix (optional)", 0)
    local suffix = MessageField("suffix", "VOA25Suffix", "Message suffix (optional)", 380)
    UI.Help(prefix, "Added after LFM VOA25, before the needed specs. Leave blank for no prefix.")
    UI.Help(suffix, "Added after the needed specs. Leave blank for no suffix.")
    local bottom = CreateFrame("Frame", nil, footer)
    bottom:SetSize(740, 26)
    bottom:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, -98)
    window.bottom = bottom
    window.optionsToggle = UI.Button(bottom, "+ Message options", 150, 0, 0, function()
        window.optionsOpen = not window.optionsOpen
        prefix:ClearFocus()
        suffix:ClearFocus()
        if window.optionsOpen then options:Show() else options:Hide() end
        window.optionsToggle:SetText((window.optionsOpen and "- " or "+ ") .. "Message options")
        bottom:ClearAllPoints()
        bottom:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, -98-(window.optionsOpen and 60 or 0))
        footer:SetHeight(124+(window.optionsOpen and 60 or 0))
        window:SetHeight(HEIGHT+(window.optionsOpen and 60 or 0))
        FitWindow()
    end)
    window.optionsToggle:SetBackdrop(nil)
    UI.Text(bottom, "GameFontHighlightSmall", 310, 282, 0, "Choose the channel in chat.\nPress Enter there to send.")
    window.post = UI.Button(bottom, "Put in chat", 130, 610, 0, function()
        local _, _, effective = addon.recruitment:Coverage()
        local message = addon.Generate(effective, db.suffix, db.prefix)
        if #message > addon.CHAT_LIMIT then
            Print("Message exceeds the 255-byte chat limit. Shorten the prefix or suffix.")
            return
        end
        prefix:ClearFocus()
        suffix:ClearFocus()
        ChatFrame_OpenChat(message, DEFAULT_CHAT_FRAME)
    end, true)
    Refresh()
end

local function ToggleWindow()
    if activateOnOpen then activateOnOpen=false;addon.recruitmentClient:SetActive(true) end
    if not window then CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        FitWindow()
        window:Show()
    end
end

SLASH_VOA251 = "/voa25"
SLASH_VOA252 = "/voa"
SlashCmdList.VOA25 = function(message)
    if not db then return end
    local command = string.lower(string.match(message or "", "^%s*(.-)%s*$"))
    if command == "" then
        ToggleWindow()
    elseif command == "reset" then
        ConfirmResetSpecs()
    elseif command == "new" then
        StaticPopup_Show("VOA25_CONFIRM_NEW_RUN")
    elseif command == "center" then
        CenterWindow()
        if not window or not window:IsShown() then ToggleWindow() end
    elseif command == "selftest" then
        local started = debugprofilestop()
        local ok, passed, total, failures = pcall(addon.RunSelfTest)
        local elapsed = debugprofilestop() - started
        if not ok then
            Print("Self-test failed: " .. tostring(passed))
        else
            Print(string.format("Self-test: %d/%d checks passed in %.2f ms.", passed, total, elapsed))
            for _, failure in ipairs(failures) do Print(failure) end
        end
    else
        Print("/voa25 - toggle window; /voa25 reset - clear specs; /voa25 new - new run; /voa25 center - recenter; /voa25 selftest - quick checks.")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == "VOA25" then
        db = addon.NormalizeDB(VOA25DB)
        activateOnOpen = not db.recruitment
        VOA25DB = db
        addon.StartRecruitment(db, Refresh)
        self:UnregisterEvent("ADDON_LOADED")
        Print("Loaded. Type /voa25 to open the LFM generator.")
    end
end)
