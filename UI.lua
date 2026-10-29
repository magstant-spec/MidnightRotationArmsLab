local addonName, addon = ...

local function ClearPoint(frame)
    if frame and frame.ClearAllPoints then
        frame:ClearAllPoints()
    end
end

local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"
local DEFAULT_FONT_SIZE = 28

local function TrySetFont(fontString, fontPath, fontSize, flags)
    if not fontString or not fontString.SetFont then
        return false
    end

    local ok, applied = pcall(fontString.SetFont, fontString, fontPath, fontSize, flags)
    return ok and applied == true
end

local function BuildSpellAbbreviation(spellName)
    if type(spellName) ~= "string" or spellName == "" then
        return ""
    end

    local abbreviation = ""
    for word in spellName:gmatch("%S+") do
        local firstLetter = word:match("%w")
        if firstLetter then
            abbreviation = abbreviation .. firstLetter:upper()
        end
    end

    if abbreviation:len() >= 2 and abbreviation:len() <= 5 then
        return abbreviation
    end

    local compactName = spellName:gsub("%s+", "")
    if compactName == "" then
        return ""
    end

    if compactName:len() > 5 then
        return compactName:sub(1, 5):upper()
    end

    return compactName:upper()
end

function addon:UpdateFonts()
    if not self.display or not self.db then
        return false
    end

    local requestedFontPath = self.db.fontPath or DEFAULT_FONT_PATH
    local fontPath = self.ResolveFontPath and self:ResolveFontPath(requestedFontPath) or requestedFontPath
    local fontSize = tonumber(self.db.fontSize or DEFAULT_FONT_SIZE) or DEFAULT_FONT_SIZE
    local applied = false

    if type(fontPath) ~= "string" or fontPath == "" then
        fontPath = DEFAULT_FONT_PATH
    end

    applied = TrySetFont(self.display.keybind, fontPath, fontSize, "OUTLINE")

    if not applied and fontPath ~= DEFAULT_FONT_PATH then
        self.db.fontPath = DEFAULT_FONT_PATH
        applied = TrySetFont(self.display.keybind, DEFAULT_FONT_PATH, fontSize, "OUTLINE")
    elseif applied and self.db.fontPath ~= fontPath then
        self.db.fontPath = fontPath
    end

    if not applied and fontSize ~= DEFAULT_FONT_SIZE then
        self.db.fontSize = DEFAULT_FONT_SIZE
        applied = TrySetFont(self.display.keybind, DEFAULT_FONT_PATH, DEFAULT_FONT_SIZE, "OUTLINE")
    end

    return applied == true
end

function addon:CreateUI()
    if self.display then
        return
    end

    local frame = CreateFrame("Frame", "MidnightRotationArmsLabFrame", UIParent, "BackdropTemplate")
    frame:SetSize(72, 72)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetUserPlaced(false)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
    frame:SetScript("OnDragStart", function(selfFrame)
        if addon.db and addon.db.locked ~= true then
            selfFrame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        addon:SavePosition()
    end)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local shade = frame:CreateTexture(nil, "OVERLAY")
    shade:SetAllPoints(frame)
    shade:SetColorTexture(0, 0, 0, 1)

    local keybind = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    keybind:SetPoint("CENTER", frame, "CENTER", 0, 0)
    keybind:SetJustifyH("CENTER")
    keybind:SetTextColor(1, 1, 1, 1)
    keybind:SetShadowColor(0, 0, 0, 1)
    keybind:SetShadowOffset(1, -1)

    local spellName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spellName:SetPoint("TOP", frame, "BOTTOM", 0, -4)
    spellName:SetJustifyH("CENTER")
    spellName:SetTextColor(0.90, 0.90, 0.90, 1)

    local profile = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    profile:SetPoint("TOP", spellName, "BOTTOM", 0, -2)
    profile:SetJustifyH("CENTER")
    profile:SetTextColor(0.70, 0.70, 0.70, 1)

    local mode = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    mode:SetPoint("TOP", profile, "BOTTOM", 0, -1)
    mode:SetJustifyH("CENTER")
    mode:SetTextColor(0.35, 0.78, 1.00, 1)

    self.display = {
        frame = frame,
        icon = icon,
        shade = shade,
        keybind = keybind,
        spellName = spellName,
        profile = profile,
        mode = mode,
    }

    self:UpdateAnchor()
    self:UpdateFrameState()
    self:UpdateFonts()
    frame:Hide()
end

function addon:SavePosition()
    if not self.display or not self.db then
        return
    end

    local point, _, relativePoint, x, y = self.display.frame:GetPoint()
    self.db.point = point
    self.db.relativePoint = relativePoint
    self.db.x = x
    self.db.y = y
end

function addon:UpdateAnchor()
    if not self.display or not self.db then
        return
    end

    local frame = self.display.frame
    ClearPoint(frame)
    frame:SetPoint(
        self.db.point or "CENTER",
        UIParent,
        self.db.relativePoint or "CENTER",
        self.db.x or 0,
        self.db.y or 0
    )
end

function addon:UpdateFrameState()
    if not self.display or not self.db then
        return
    end

    local frame = self.display.frame
    frame:SetScale(self.db.scale or 1)
    frame:SetAlpha(self.db.alpha or 1)
    frame:EnableMouse(self.db.locked ~= true)
end

function addon:ClearDisplay(profileLabel, modeLabel)
    if not self.display then
        return
    end

    self.display.keybind:SetText("")
    self.display.spellName:SetText("")
    self.display.profile:SetText(profileLabel or "")
    self.display.mode:SetText(modeLabel or "")
    self.display.icon:SetTexture(nil)

    if self.db and self.db.locked ~= true then
        self.display.icon:SetAlpha(0)
        self.display.shade:SetAlpha(1)
        self.display.frame:Show()
    else
        self.display.frame:Hide()
    end
end

function addon:DisplayRecommendation(recommendation, profileLabel, modeLabel)
    if not self.display then
        return
    end

    if type(recommendation) == "table" and recommendation.type == "item" then
        local itemID = tonumber(recommendation.itemID)
        if not itemID or itemID <= 0 then
            self:ClearDisplay(profileLabel, modeLabel)
            return
        end

        local itemName = recommendation.name or (self.GetItemNameSafe and self:GetItemNameSafe(itemID)) or "Item"
        local iconID = self.GetItemIconSafe and self:GetItemIconSafe(itemID) or nil
        local keybindText = self.GetItemKeybindText and self:GetItemKeybindText(itemID, itemName) or ""
        local showIcon = self.db.keybindOnly ~= true
        if showIcon == false and keybindText == "" then
            keybindText = BuildSpellAbbreviation(itemName)
            if keybindText == "" then
                keybindText = tostring(itemID)
            end
        end

        self.display.icon:SetTexture(iconID)
        self.display.icon:SetAlpha(showIcon and 1 or 0)
        self.display.shade:SetAlpha(showIcon and 0.28 or 1)
        self.display.keybind:SetText(keybindText)
        self.display.spellName:SetText(itemName)
        self.display.profile:SetText(profileLabel or "")
        self.display.mode:SetText(modeLabel or "")
        self.display.frame:Show()
        return
    end

    local spellNameOverride = nil
    local iconSpellID = nil
    local keybindSpellID = nil
    local spellID = recommendation
    if type(recommendation) == "table" and recommendation.type == "spell" then
        spellID = recommendation.spellID
        spellNameOverride = recommendation.name
        iconSpellID = recommendation.iconSpellID
        keybindSpellID = recommendation.keybindSpellID
    end

    if type(spellID) ~= "number" or spellID <= 0 then
        self:ClearDisplay(profileLabel, modeLabel)
        return
    end

    if type(iconSpellID) ~= "number" or iconSpellID <= 0 then
        iconSpellID = spellID
    end
    if type(keybindSpellID) ~= "number" or keybindSpellID <= 0 then
        keybindSpellID = spellID
    end

    local spellInfo = nil
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, resolvedSpellInfo = pcall(C_Spell.GetSpellInfo, iconSpellID)
        if ok then
            spellInfo = resolvedSpellInfo
        end
        if not spellInfo and iconSpellID ~= spellID then
            ok, resolvedSpellInfo = pcall(C_Spell.GetSpellInfo, spellID)
            if ok then
                spellInfo = resolvedSpellInfo
            end
        end
    end

    if not spellInfo then
        self:ClearDisplay(profileLabel, modeLabel)
        return
    end

    local iconID = spellInfo.iconID or spellInfo.originalIconID or spellInfo.iconFileID
    local spellName = spellNameOverride or spellInfo.name or ""
    local keybindText = self:GetKeybindText(keybindSpellID) or ""
    local showIcon = self.db.keybindOnly ~= true
    if showIcon == false and keybindText == "" then
        keybindText = BuildSpellAbbreviation(spellName)
        if keybindText == "" then
            keybindText = tostring(spellID)
        end
    end

    self.display.icon:SetTexture(iconID)
    self.display.icon:SetAlpha(showIcon and 1 or 0)
    self.display.shade:SetAlpha(showIcon and 0.28 or 1)
    self.display.keybind:SetText(keybindText)
    self.display.spellName:SetText(spellName)
    self.display.profile:SetText(profileLabel or "")
    self.display.mode:SetText(modeLabel or "")
    self.display.frame:Show()
end
