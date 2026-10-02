-- Shared chrome using only original Wrath frame APIs and bundled textures.
local UI = {}
VOA25.UI = UI

function UI.Safe(text)
    return (string.gsub(text or "", "|", "||"))
end

function UI.Text(parent, font, width, x, y, text)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    if text then label:SetText(text) end
    return label
end

function UI.Backdrop(frame, r, g, b)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left=3, right=3, top=3, bottom=3},
    })
    frame:SetBackdropColor(r, g, b, 1)
    frame:SetBackdropBorderColor(0.32, 0.35, 0.4, 1)
end

function UI.Button(parent, text, width, x, y, handler, primary)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 26)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", handler)
    if not primary then
        button:SetNormalTexture("")
        button:SetPushedTexture("")
        button:SetDisabledTexture("")
        button:SetNormalFontObject(GameFontHighlightSmall)
        UI.Backdrop(button, 0.13, 0.15, 0.19)
    end
    return button
end

function UI.Tooltip(owner, text)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(UI.Safe(text), 1, 1, 1, 1, true)
    GameTooltip:Show()
end

function UI.Help(frame, text)
    frame:SetScript("OnEnter", function(self) UI.Tooltip(self, type(text)=="function" and text(self) or text) end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function UI.Rule(parent, width, x, y, r, g, b)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(r or 0.3, g or 0.31, b or 0.34, 1)
    line:SetSize(width, 1)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return line
end
