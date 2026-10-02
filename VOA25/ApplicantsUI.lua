local addon = VOA25
local UI = addon.UI
local ROWS, ROW_HEIGHT, HEADER_HEIGHT = 8, 38, 22

function addon.CreateApplicantsUI(window, refresh)
    local ui = {expanded={}, rows={}, window=window, visibleRows=ROWS, rowHeight=ROW_HEIGHT}
    local panel = CreateFrame("Frame", nil, window)
    panel:SetSize(740, 342)
    panel:SetPoint("TOPLEFT", window, "TOPLEFT", 20, -124)
    ui.panel = panel
    UI.Text(panel, "GameFontDisableSmall", 156, 8, 0, "Player / whisper")
    UI.Text(panel, "GameFontDisableSmall", 160, 172, 0, "Assigned spec")
    UI.Text(panel, "GameFontDisableSmall", 142, 343, 0, "Status")
    local actions = UI.Text(panel, "GameFontDisableSmall", 214, 488, 0, "Actions")
    actions:SetJustifyH("RIGHT")
    local scroll = CreateFrame("ScrollFrame", "VOA25ApplicantScroll", panel, "FauxScrollFrameTemplate")
    scroll:SetSize(714, ROWS * ROW_HEIGHT)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -20)
    scroll:SetScript("OnVerticalScroll", function(self, value)
        FauxScrollFrame_OnVerticalScroll(self, value, ROW_HEIGHT, refresh)
    end)
    ui.scroll = scroll
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(self, delta)
        local offset = math.max(0, math.min(math.max(0, #(ui.entries or {})-ROWS), (FauxScrollFrame_GetOffset(scroll) or 0)-delta))
        FauxScrollFrame_OnVerticalScroll(scroll, offset*ROW_HEIGHT, ROW_HEIGHT, refresh)
    end)
    ui.empty = UI.Text(panel, "GameFontHighlightSmall", 710, 8, -36)
    ui.hint = UI.Text(panel, "GameFontDisableSmall", 740, 2, -330)

    -- Known classes get a compact picker; unknown classes retain all categories.
    local chooser = CreateFrame("Frame", "VOA25SpecChooser", window)
    chooser:SetPoint("CENTER", window, "CENTER", 0, 0)
    chooser:SetFrameStrata("FULLSCREEN_DIALOG")
    chooser:SetClampedToScreen(true)
    chooser:EnableMouse(true)
    UI.Backdrop(chooser, 0.09, 0.11, 0.15)
    chooser:Hide()
    tinsert(UISpecialFrames, "VOA25SpecChooser")
    ui.chooser = chooser
    chooser.title = UI.Text(chooser, "GameFontNormal", 440, 16, -16)
    local close = CreateFrame("Button", nil, chooser, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", chooser, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() chooser:Hide() end)
    chooser.choices = {}
    for _, class in ipairs(addon.classes) do
        for _, spec in ipairs(class.specs) do
            local id = spec[1]
            local button = UI.Button(chooser, addon.specs[id].label, 212, 16, -48, function()
                if chooser.person then addon.recruitment:SetSpec(chooser.person, id) end
                chooser:Hide()
                refresh()
            end)
            chooser.choices[#chooser.choices+1] = {button=button, id=id}
        end
    end
    chooser.noSlot = UI.Button(chooser, "No slot / emblems only", 212, 16, -48, function()
        if chooser.person then addon.recruitment:SetSpec(chooser.person, nil) end
        chooser:Hide()
        refresh()
    end)
    UI.Help(chooser.noSlot, "Keep this player in the raid without filling a spec category.")

    function ui:Choose(p)
        chooser.person = p
        self:RefreshChooser()
        chooser:Show()
    end
    function ui:RefreshChooser()
        local p = chooser.person
        if not p then return end
        local known = addon.classByToken[p.class] ~= nil
        local width, count = known and 280 or 480, 0
        chooser.title:SetWidth(width-58)
        chooser.title:SetText("Assign spec: " .. UI.Safe(p.name))
        for _, choice in ipairs(chooser.choices) do
            local button = choice.button
            if not known or addon.specs[choice.id].class == p.class then
                local column = known and 0 or count % 2
                local row = known and count or math.floor(count / 2)
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", chooser, "TOPLEFT", 16 + column * 226, -48 - row * 30)
                button:SetWidth(known and 248 or 212)
                local selected = p.counted and p.spec == choice.id
                button:SetText((selected and "|cffffdd88" or "") .. addon.specs[choice.id].label .. (selected and "|r" or ""))
                button:SetBackdropBorderColor(selected and 0.85 or 0.32, selected and 0.68 or 0.35, selected and 0.32 or 0.4, 1)
                button:Enable()
                button:Show()
                count = count + 1
            else
                button:Disable()
                button:Hide()
            end
        end
        local rows = known and count or math.ceil(count / 2)
        chooser.noSlot:ClearAllPoints()
        chooser.noSlot:SetPoint("TOPLEFT", chooser, "TOPLEFT", 16, -54 - rows * 30)
        chooser.noSlot:SetWidth(width-32)
        chooser.noSlot:SetBackdropBorderColor(not p.counted and 0.85 or 0.32, not p.counted and 0.68 or 0.35, not p.counted and 0.32 or 0.4, 1)
        chooser:SetSize(width, 96 + rows * 30)
    end

    for i=1,ROWS do
        local row = CreateFrame("Frame", nil, panel)
        row:SetSize(714, ROW_HEIGHT)
        row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
        row.rule = UI.Rule(row, 714, 0, 0, 0.2, 0.23, 0.28)
        row.playerButton = CreateFrame("Button", nil, row)
        row.playerButton:SetSize(164, ROW_HEIGHT)
        row.playerButton:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.playerButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.playerButton:SetScript("OnClick", function()
            -- Read the current occupant: these rows are reused while scrolling.
            local p = row.person
            if not p then return end
            if window.prefix then window.prefix:ClearFocus() end
            if window.suffix then window.suffix:ClearFocus() end
            chooser:Hide()
            GameTooltip:Hide()
            -- Opens the whisper editor only; the player types and sends the message.
            ChatFrame_SendTell(p.name, DEFAULT_CHAT_FRAME)
        end)
        row.name = UI.Text(row.playerButton, "GameFontHighlightSmall", 156, 8, -4)
        row.message = UI.Text(row.playerButton, "GameFontDisableSmall", 156, 8, -20)
        row.name:SetHeight(14)
        row.message:SetHeight(14)
        row.spec = UI.Button(row, "", 160, 172, -6, function() if row.person then ui:Choose(row.person) end end)
        row.specText = UI.Text(row.spec, "GameFontHighlightSmall", 136, 8, -7)
        UI.Text(row.spec, "GameFontDisableSmall", 10, 146, -7, "v")
        row.status = UI.Text(row, "GameFontHighlightSmall", 142, 343, -5)
        row.status:ClearAllPoints()
        row.status:SetPoint("LEFT", row, "LEFT", 343, 0)
        row.status:SetHeight(30)
        row.status:SetJustifyV("MIDDLE")
        row.primary = UI.Button(row, "", 105, 488, -6, function()
            local p = row.person
            if not p then return end
            local model = addon.recruitment
            if p.state=="declined" then model:Undo(p)
            elseif p.state=="pending" then
                if p.noResponse and not p.released then model:KeepWaiting(p, GetTime())
                else model:Release(p); addon.RecruitmentNotice("Slot released. The game invitation may still be outstanding.") end
            elseif p.state=="left" then p.state="waiting"
            else addon.recruitmentClient:Invite(p) end
            refresh()
        end, true)
        row.secondary = UI.Button(row, "", 104, 598, -6, function()
            local p = row.person
            if not p then return end
            if p.state=="pending" then
                addon.recruitment:Release(p)
                addon.RecruitmentNotice("Slot released. The game invitation may still be outstanding.")
            elseif addon.recruitment:Decline(p) then
                addon.RecruitmentNotice(p.name .. " moved to Declined. No whisper sent; expand Declined to Undo.")
            end
            refresh()
        end)
        row.header = UI.Button(row, "", 714, 0, 0, function()
            if row.section then
                ui.expanded[row.section] = not ui.expanded[row.section]
                refresh()
            end
        end)
        row.header:SetHeight(HEADER_HEIGHT)
        row.headerText = UI.Text(row.header, "GameFontHighlightSmall", 690, 8, -5)
        row:EnableMouse(true)
        local function PlayerTooltip()
            local p = row.person
            if not p then return "" end
            local text = p.name .. "\n" .. p.message
            if p.specMessage and p.specMessage~="" and p.specMessage~=p.message then text=text .. "\nSpec whisper: " .. p.specMessage end
            if p.failure then text=text .. "\n" .. p.failure end
            return text
        end
        UI.Help(row, PlayerTooltip)
        UI.Help(row.playerButton, function()
            return PlayerTooltip() .. "\nClick to whisper."
        end)
        UI.Help(row.spec, "Choose this player's spec, or No slot / emblems only.")
        row.primary:SetScript("OnEnter", function(self) if self.reason then UI.Tooltip(self, self.reason) end end)
        row.primary:SetScript("OnLeave", function() GameTooltip:Hide() end)
        UI.Help(row.secondary, function()
            return row.person and row.person.state=="pending" and "Reopen the spec without cancelling the game invitation." or "Move to Declined. No whisper is sent; you can Undo."
        end)
        ui.rows[i] = row
    end

    function ui:Refresh()
        local model = addon.recruitment
        self.entries = model:Entries(self.expanded, GetTime())
        local offset = math.max(0, math.min(FauxScrollFrame_GetOffset(scroll) or 0, math.max(0, #self.entries-ROWS)))
        FauxScrollFrame_SetOffset(scroll, offset)
        FauxScrollFrame_Update(scroll, #self.entries, ROWS, ROW_HEIGHT)
        if #self.entries==0 then
            self.empty:SetText(model.active and "Waiting for recruitment whispers..." or "Enable Recruiting to collect applicants.")
            self.empty:Show()
        else self.empty:Hide() end
        local _, blocker = addon.recruitmentClient:RecruitmentBlocker()
        self.hint:SetText(blocker or (#self.entries>ROWS and "Scroll for more applicants. Decline is local; no whisper is sent." or "Decline is local; no whisper is sent."))
        self.hint:SetTextColor(blocker and 0.94 or 0.65, blocker and 0.77 or 0.67, blocker and 0.4 or 0.72)
        local y = -20
        for i,row in ipairs(self.rows) do
            local entry = self.entries[offset+i]
            row.person, row.section = nil, nil
            if not entry then row:Hide()
            else
                row:Show()
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
                row.primary:Hide(); row.secondary:Hide(); row.header:Hide(); row.spec:Hide()
                row.playerButton:Hide()
                row.name:Hide(); row.message:Hide(); row.status:Hide(); row.rule:Show()
                if entry.section then
                    row:SetHeight(HEADER_HEIGHT)
                    row.rule:Hide()
                    row.section = entry.section
                    row.headerText:SetText((self.expanded[entry.section] and "- " or "+ ") .. entry.label)
                    row.header:Show()
                    row:SetBackdropColor(0.13, 0.15, 0.19, 1)
                    y = y - HEADER_HEIGHT
                else
                    local p = entry.person
                    row:SetHeight(ROW_HEIGHT)
                    row.person = p
                    row.playerButton:Show()
                    local needsSpec = p.state=="joined" and p.counted and not p.spec
                    if needsSpec then row:SetBackdropColor(0.19, 0.17, 0.12, 1)
                    elseif i % 2==1 then row:SetBackdropColor(0.1, 0.12, 0.16, 1)
                    else row:SetBackdropColor(0.08, 0.1, 0.14, 1) end
                    row.name:SetText(UI.Safe(p.name))
                    row.message:SetText(UI.Safe(p.message~="" and p.message or (needsSpec and "Joined your group - assign a spec" or "")))
                    row.name:Show(); row.message:Show()
                    local color = p.class and RAID_CLASS_COLORS[p.class]
                    row.name:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
                    row.specText:SetText(p.spec and addon.specs[p.spec].label or (p.counted and "Choose spec..." or "No slot / emblems"))
                    row.spec:Show()
                    local status = model:Status(p)
                    row.status:SetText(status)
                    row.status:Show()
                    if status=="Needed" or status=="Joined" then row.status:SetTextColor(0.65, 0.84, 0.51)
                    elseif p.state=="pending" or status=="Choose spec" or needsSpec then row.status:SetTextColor(0.94, 0.77, 0.4)
                    else row.status:SetTextColor(0.7, 0.72, 0.77) end
                    row.primary.reason = nil
                    row.primary:Enable()
                    if p.state=="joined" then
                        -- The spec field is the edit action; no duplicate Edit spec button.
                    elseif p.state=="declined" then row.primary:SetText("Undo"); row.primary:Show()
                    elseif p.state=="left" then
                        row.primary:SetText("Restore"); row.primary:Show()
                        row.secondary:SetText("Decline"); row.secondary:Show()
                    elseif p.state=="pending" then
                        if not p.released then
                            if p.noResponse then
                                row.primary:SetText("Keep waiting"); row.primary:Show()
                                row.secondary:SetText("Release slot"); row.secondary:Show()
                            else row.secondary:SetText("Release slot"); row.secondary:Show() end
                        end
                    else
                        row.primary:SetText(status=="Covered" and "Invite extra" or "Invite")
                        local ok, reason = addon.recruitmentClient:InvitePermission(p)
                        if not ok then row.primary:Disable(); row.primary.reason=reason end
                        row.primary:Show()
                        row.secondary:SetText("Decline"); row.secondary:Show()
                    end
                    y = y - ROW_HEIGHT
                end
            end
        end
        if self.chooser:IsShown() then self:RefreshChooser() end
    end
    return ui
end
