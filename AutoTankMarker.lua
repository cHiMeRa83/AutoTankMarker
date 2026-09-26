local frame = CreateFrame("Frame")

-- Standard-Einstellungen (v1.77)
local defaultSettings = {
    marker = 6,
    autoFocus = false,
    aggroAlert = true,
    manaWhisper = true,
    drinkWhisper = true,
    tankDeathSound = true,
    tankHealthAlert = true,
    tankDefAlert = true,
    tauntAlert = true,
    showTankThreatBar = true,
    showCDMonitor = true,
    showInterruptBar = true,
    showDrinkBar = true,
    showFoodBar = true,
    showTankSwap = true,
    showInterrupt = true,
    language = "DE",
    barSkin = "NEON",
    threatWidth = 400,
    threatHeight = 22,
    warnWidth = 380,
    warnHeight = 42,
    warnFontSize = 14,
    threatX = 0,
    threatY = -120,
    cdX = 0,
    cdY = -160,
    intX = 0,
    intY = -195,
    drinkX = 0,
    drinkY = -230,
    foodX = 0,
    foodY = -265,
    warnX = 0,
    warnY = 180,
    minimapPos = 45,
    fontSize = 12,
    alertSound = "8959",
    tankLostSound = "12197",
    interruptSound = "3227",
}

-- Sofortiges Laden und Absichern der Einstellungen
ATM_Settings = ATM_Settings or {}
for k, v in pairs(defaultSettings) do
    if ATM_Settings[k] == nil then
        ATM_Settings[k] = v
    end
end

local lastChatAlert = 0
local lastManaWhisper = 0
local lastDrinkWhisper = 0
local lastHealthAlert = 0
local CHAT_ALERT_COOLDOWN = 10 
local MANA_WHISPER_COOLDOWN = 30
local currentTankUnit = nil
local ischimeraTestingMode = false
local isUnlockedForMoving = false

-- VERFÜGBARE SOUNDS FÜR DIE DROPDOWNS
local AVAILABLE_SOUNDS = {
    { name = "Aus (Kein Ton)", value = "DISABLED" },
    { name = "Evowow Sound 8959 (Aggro)", value = "8959" },
    { name = "Evowow Sound 12197 (Aggro verloren)", value = "12197" },
    { name = "Evowow Sound 3227 (Interrupt)", value = "3227" },
}

local AVAILABLE_SKINS = {
    { name = "Neon Cyber (Leuchtend)", value = "NEON" },
    { name = "Modern Dark (Clean & Dunkel)", value = "MODERN" },
    { name = "Klassisch (Blizzard Stil)", value = "CLASSIC" },
    { name = "Minimalistisch (Schlicht)", value = "MINIMAL" },
    { name = "Gilden-Gold (Edel & Gold)", value = "GOLD" },
    { name = "Blutrot (Aggressiv)", value = "BLOOD" },
    { name = "Blaues Kristall (Magisch)", value = "CRYSTAL" },
    { name = "Smaragdgrün (Natur)", value = "EMERALD" },
    { name = "Arcane Lila (Mystisch)", value = "ARCANE" },
}

local function PlayCustomSound(soundKey)
    if not soundKey or soundKey == "DISABLED" then return end
    
    local soundId = tonumber(soundKey)
    if soundId then
        PlaySound(soundId)
        return
    end

    if soundKey:find("\\") then
        PlaySoundFile(soundKey)
    else
        PlaySound(soundKey)
    end
end

-------------------------------------------------------------------------------
-- HILFSFUNKTION: PRÜFT OB IN INSTANZ (DUNGEON / RAID) ODER TESTMODUS
-------------------------------------------------------------------------------
local function IsInInstanceArea()
    if ischimeraTestingMode or isUnlockedForMoving then return true end
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "party" or instanceType == "raid")
end

-------------------------------------------------------------------------------
-- BILDSCHIRM-BLITZ (ROTES AUFLEUCHTEN BEI AGGRO)
-------------------------------------------------------------------------------
local flashFrame = CreateFrame("Frame", "ATMFlashFrame", UIParent)
flashFrame:SetAllPoints(UIParent)
flashFrame:SetFrameStrata("FULLSCREEN_DIALOG")
flashFrame:Hide()

local flashTex = flashFrame:CreateTexture(nil, "BACKGROUND")
flashTex:SetAllPoints(flashFrame)
flashTex:SetTexture("Interface\\Buttons\\WHITE8X8")
flashTex:SetVertexColor(1, 0, 0, 0.4)

local flashTimer = 0
flashFrame:SetScript("OnUpdate", function(self, elapsed)
    flashTimer = flashTimer - elapsed
    if flashTimer <= 0 then
        self:Hide()
    elseif flashTimer < 0.4 then
        flashTex:SetVertexColor(1, 0, 0, (flashTimer / 0.4) * 0.4)
    end
end)

local function TriggerScreenFlash()
    flashTimer = 0.8
    flashTex:SetVertexColor(1, 0, 0, 0.4)
    flashFrame:Show()
end

-------------------------------------------------------------------------------
-- MINIMAP BUTTON ERSTELLUNG
-------------------------------------------------------------------------------
local minimapButton = CreateFrame("Button", "ATMMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("HIGH")
minimapButton:SetFrameLevel(99)
minimapButton:SetMovable(true)
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:RegisterForDrag("LeftButton")

local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\Ability_Warrior_ShieldBash")
icon:SetSize(22, 22)
icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)

local bg = minimapButton:CreateTexture(nil, "ARTWORK")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetSize(26, 26)
bg:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
icon:SetDrawLayer("OVERLAY", 1)

local sliderMinimapAngle

local function UpdateMinimapButtonPosition(angle)
    local x = cos(angle) * 80
    local y = sin(angle) * 80
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    if sliderMinimapAngle then
        sliderMinimapAngle:SetValue(angle)
        _G[sliderMinimapAngle:GetName() .. "Text"]:SetText("Minimap-Position: " .. math.floor(angle) .. "°")
    end
end

minimapButton:SetScript("OnLoad", function(self)
    UpdateMinimapButtonPosition(ATM_Settings.minimapPos or 45)
end)

minimapButton:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function(s)
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        if angle < 0 then angle = angle + 360 end
        ATM_Settings.minimapPos = angle
        UpdateMinimapButtonPosition(angle)
    end)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
end)

local RunTestMode

minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if InterfaceOptionsFrame:IsShown() then
            InterfaceOptionsFrame:Hide()
        else
            InterfaceOptionsFrame_OpenToCategory("AutoTankMarker")
            InterfaceOptionsFrame_OpenToCategory("AutoTankMarker")
        end
    elseif button == "RightButton" then
        RunTestMode()
    end
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("AutoTankMarker (ATM)", 1, 0.8, 0)
    GameTooltip:AddLine("Linksklick: |cffffffffEinstellungen öffnen|r", 0.2, 1, 0.2)
    GameTooltip:AddLine("Rechtsklick: |cffffffffTestmodus starten|r", 0.2, 1, 0.2)
    GameTooltip:AddLine("Drag & Drop: |cffffffffPosition verschieben|r", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-------------------------------------------------------------------------------
-- DESIGN & 9-SKIN-SYSTEM
-------------------------------------------------------------------------------
local threatText, cdText, intText, drinkText, foodText, warnText
local threatBackdrop, cdBackdrop, intBackdrop, drinkBackdrop, foodBackdrop, warnBackdrop
local threatBar, cdBar, intBar, drinkBar, foodBar, warnFrame

local function UpdateBarStyles()
    local fSize = ATM_Settings.fontSize or 12
    local w = ATM_Settings.threatWidth or 400
    local h = ATM_Settings.threatHeight or 22
    local skin = ATM_Settings.barSkin or "NEON"

    local bars = { threatBar, cdBar, intBar, drinkBar, foodBar }
    for _, bar in ipairs(bars) do
        if bar then
            bar:SetWidth(w)
            bar:SetHeight(h)
        end
    end

    if skin == "NEON" then
        if threatBackdrop then threatBackdrop:SetBackdropColor(0.0, 0.0, 0.0, 0.9); threatBackdrop:SetBackdropBorderColor(1.0, 0.0, 0.3, 1.0) end
        if cdBackdrop then cdBackdrop:SetBackdropColor(0.0, 0.0, 0.0, 0.9); cdBackdrop:SetBackdropBorderColor(1.0, 0.9, 0.0, 1.0) end
        if intBackdrop then intBackdrop:SetBackdropColor(0.0, 0.0, 0.0, 0.9); intBackdrop:SetBackdropBorderColor(0.0, 0.9, 1.0, 1.0) end
        if drinkBackdrop then drinkBackdrop:SetBackdropColor(0.0, 0.0, 0.0, 0.9); drinkBackdrop:SetBackdropBorderColor(0.0, 1.0, 1.0, 1.0) end
        if foodBackdrop then foodBackdrop:SetBackdropColor(0.0, 0.0, 0.0, 0.9); foodBackdrop:SetBackdropBorderColor(1.0, 0.6, 0.0, 1.0) end
        if warnBackdrop then warnBackdrop:SetBackdropColor(0.0, 0.0, 0.0, 0.95); warnBackdrop:SetBackdropBorderColor(1.0, 0.0, 0.5, 1.0) end
    elseif skin == "MODERN" then
        if threatBackdrop then threatBackdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.85); threatBackdrop:SetBackdropBorderColor(0.8, 0.1, 0.1, 1.0) end
        if cdBackdrop then cdBackdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.85); cdBackdrop:SetBackdropBorderColor(1.0, 0.7, 0.0, 1.0) end
        if intBackdrop then intBackdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.85); intBackdrop:SetBackdropBorderColor(0.0, 0.5, 1.0, 1.0) end
        if drinkBackdrop then drinkBackdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.85); drinkBackdrop:SetBackdropBorderColor(0.0, 0.7, 1.0, 1.0) end
        if foodBackdrop then foodBackdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.85); foodBackdrop:SetBackdropBorderColor(1.0, 0.5, 0.0, 1.0) end
        if warnBackdrop then warnBackdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.9); warnBackdrop:SetBackdropBorderColor(0.8, 0.1, 0.1, 1.0) end
    elseif skin == "CLASSIC" then
        if threatBackdrop then threatBackdrop:SetBackdropColor(0.2, 0.0, 0.0, 0.95); threatBackdrop:SetBackdropBorderColor(1.0, 0.1, 0.1, 1.0) end
        if cdBackdrop then cdBackdrop:SetBackdropColor(0.2, 0.1, 0.0, 0.95); cdBackdrop:SetBackdropBorderColor(1.0, 0.8, 0.0, 1.0) end
        if intBackdrop then intBackdrop:SetBackdropColor(0.1, 0.1, 0.2, 0.95); intBackdrop:SetBackdropBorderColor(0.0, 0.6, 1.0, 1.0) end
        if drinkBackdrop then drinkBackdrop:SetBackdropColor(0.0, 0.2, 0.3, 0.95); drinkBackdrop:SetBackdropBorderColor(0.0, 0.8, 1.0, 1.0) end
        if foodBackdrop then foodBackdrop:SetBackdropColor(0.3, 0.2, 0.0, 0.95); foodBackdrop:SetBackdropBorderColor(1.0, 0.6, 0.0, 1.0) end
        if warnBackdrop then warnBackdrop:SetBackdropColor(0.2, 0.0, 0.0, 0.95); warnBackdrop:SetBackdropBorderColor(1.0, 0.1, 0.1, 1.0) end
    elseif skin == "MINIMAL" then
        if threatBackdrop then threatBackdrop:SetBackdropColor(0, 0, 0, 0.7); threatBackdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8) end
        if cdBackdrop then cdBackdrop:SetBackdropColor(0, 0, 0, 0.7); cdBackdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8) end
        if intBackdrop then intBackdrop:SetBackdropColor(0, 0, 0, 0.7); intBackdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8) end
        if drinkBackdrop then drinkBackdrop:SetBackdropColor(0, 0, 0, 0.7); drinkBackdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8) end
        if foodBackdrop then foodBackdrop:SetBackdropColor(0, 0, 0, 0.7); foodBackdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8) end
        if warnBackdrop then warnBackdrop:SetBackdropColor(0, 0, 0, 0.8); warnBackdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8) end
    elseif skin == "GOLD" then
        if threatBackdrop then threatBackdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.9); threatBackdrop:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0) end
        if cdBackdrop then cdBackdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.9); cdBackdrop:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0) end
        if intBackdrop then intBackdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.9); intBackdrop:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0) end
        if drinkBackdrop then drinkBackdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.9); drinkBackdrop:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0) end
        if foodBackdrop then foodBackdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.9); foodBackdrop:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0) end
        if warnBackdrop then warnBackdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.95); warnBackdrop:SetBackdropBorderColor(1.0, 0.84, 0.0, 1.0) end
    elseif skin == "BLOOD" then
        if threatBackdrop then threatBackdrop:SetBackdropColor(0.15, 0.0, 0.0, 0.9); threatBackdrop:SetBackdropBorderColor(0.9, 0.0, 0.0, 1.0) end
        if cdBackdrop then cdBackdrop:SetBackdropColor(0.15, 0.0, 0.0, 0.9); cdBackdrop:SetBackdropBorderColor(0.9, 0.0, 0.0, 1.0) end
        if intBackdrop then intBackdrop:SetBackdropColor(0.15, 0.0, 0.0, 0.9); intBackdrop:SetBackdropBorderColor(0.9, 0.0, 0.0, 1.0) end
        if drinkBackdrop then drinkBackdrop:SetBackdropColor(0.15, 0.0, 0.0, 0.9); drinkBackdrop:SetBackdropBorderColor(0.9, 0.0, 0.0, 1.0) end
        if foodBackdrop then foodBackdrop:SetBackdropColor(0.15, 0.0, 0.0, 0.9); foodBackdrop:SetBackdropBorderColor(0.9, 0.0, 0.0, 1.0) end
        if warnBackdrop then warnBackdrop:SetBackdropColor(0.2, 0.0, 0.0, 0.95); warnBackdrop:SetBackdropBorderColor(1.0, 0.0, 0.0, 1.0) end
    elseif skin == "CRYSTAL" then
        if threatBackdrop then threatBackdrop:SetBackdropColor(0.0, 0.1, 0.2, 0.9); threatBackdrop:SetBackdropBorderColor(0.0, 0.7, 1.0, 1.0) end
        if cdBackdrop then cdBackdrop:SetBackdropColor(0.0, 0.1, 0.2, 0.9); cdBackdrop:SetBackdropBorderColor(0.0, 0.7, 1.0, 1.0) end
        if intBackdrop then intBackdrop:SetBackdropColor(0.0, 0.1, 0.2, 0.9); intBackdrop:SetBackdropBorderColor(0.0, 0.7, 1.0, 1.0) end
        if drinkBackdrop then drinkBackdrop:SetBackdropColor(0.0, 0.1, 0.2, 0.9); drinkBackdrop:SetBackdropBorderColor(0.0, 0.7, 1.0, 1.0) end
        if foodBackdrop then foodBackdrop:SetBackdropColor(0.0, 0.1, 0.2, 0.9); foodBackdrop:SetBackdropBorderColor(0.0, 0.7, 1.0, 1.0) end
        if warnBackdrop then warnBackdrop:SetBackdropColor(0.0, 0.1, 0.3, 0.95); warnBackdrop:SetBackdropBorderColor(0.0, 0.8, 1.0, 1.0) end
    elseif skin == "EMERALD" then
        if threatBackdrop then threatBackdrop:SetBackdropColor(0.0, 0.15, 0.05, 0.9); threatBackdrop:SetBackdropBorderColor(0.1, 0.9, 0.2, 1.0) end
        if cdBackdrop then cdBackdrop:SetBackdropColor(0.0, 0.15, 0.05, 0.9); cdBackdrop:SetBackdropBorderColor(0.1, 0.9, 0.2, 1.0) end
        if intBackdrop then intBackdrop:SetBackdropColor(0.0, 0.15, 0.05, 0.9); intBackdrop:SetBackdropBorderColor(0.1, 0.9, 0.2, 1.0) end
        if drinkBackdrop then drinkBackdrop:SetBackdropColor(0.0, 0.15, 0.05, 0.9); drinkBackdrop:SetBackdropBorderColor(0.1, 0.9, 0.2, 1.0) end
        if foodBackdrop then foodBackdrop:SetBackdropColor(0.0, 0.15, 0.05, 0.9); foodBackdrop:SetBackdropBorderColor(0.1, 0.9, 0.2, 1.0) end
        if warnBackdrop then warnBackdrop:SetBackdropColor(0.0, 0.2, 0.05, 0.95); warnBackdrop:SetBackdropBorderColor(0.1, 1.0, 0.2, 1.0) end
    elseif skin == "ARCANE" then
        if threatBackdrop then threatBackdrop:SetBackdropColor(0.1, 0.0, 0.2, 0.9); threatBackdrop:SetBackdropBorderColor(0.8, 0.2, 1.0, 1.0) end
        if cdBackdrop then cdBackdrop:SetBackdropColor(0.1, 0.0, 0.2, 0.9); cdBackdrop:SetBackdropBorderColor(0.8, 0.2, 1.0, 1.0) end
        if intBackdrop then intBackdrop:SetBackdropColor(0.1, 0.0, 0.2, 0.9); intBackdrop:SetBackdropBorderColor(0.8, 0.2, 1.0, 1.0) end
        if drinkBackdrop then drinkBackdrop:SetBackdropColor(0.1, 0.0, 0.2, 0.9); drinkBackdrop:SetBackdropBorderColor(0.8, 0.2, 1.0, 1.0) end
        if foodBackdrop then foodBackdrop:SetBackdropColor(0.1, 0.0, 0.2, 0.9); foodBackdrop:SetBackdropBorderColor(0.8, 0.2, 1.0, 1.0) end
        if warnBackdrop then warnBackdrop:SetBackdropColor(0.15, 0.0, 0.3, 0.95); warnBackdrop:SetBackdropBorderColor(0.9, 0.3, 1.0, 1.0) end
    end

    if threatText then threatText:SetFont("Fonts\\FRIZQT__.TTF", fSize, "OUTLINE") end
    if cdText then cdText:SetFont("Fonts\\FRIZQT__.TTF", fSize, "OUTLINE") end
    if intText then intText:SetFont("Fonts\\FRIZQT__.TTF", fSize, "OUTLINE") end
    if drinkText then drinkText:SetFont("Fonts\\FRIZQT__.TTF", fSize, "OUTLINE") end
    if foodText then foodText:SetFont("Fonts\\FRIZQT__.TTF", fSize, "OUTLINE") end
    if warnText then warnText:SetFont("Fonts\\FRIZQT__.TTF", ATM_Settings.warnFontSize or 14, "OUTLINE") end
end

-------------------------------------------------------------------------------
-- WARNBALKEN (BANNER FRAME)
-------------------------------------------------------------------------------
warnFrame = CreateFrame("Frame", "ATMWarnFrame", UIParent)
warnFrame:SetWidth(380)
warnFrame:SetHeight(42)
warnFrame:SetPoint("CENTER", UIParent, "CENTER", ATM_Settings.warnX or 0, ATM_Settings.warnY or 180)
warnFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 0, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
warnFrame:Hide()

warnBackdrop = warnFrame

warnFrame:EnableMouse(true)
warnFrame:SetMovable(true)
warnFrame:RegisterForDrag("LeftButton")
warnFrame:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() or isUnlockedForMoving then
        self:StartMoving()
    end
end)
warnFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    ATM_Settings.warnX = x
    ATM_Settings.warnY = y
end)

warnText = warnFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
warnText:SetPoint("CENTER", warnFrame, "CENTER", 0, 0)
warnText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
warnText:SetTextColor(1, 1, 1, 1)

local warnTimer = 0
warnFrame:SetScript("OnUpdate", function(self, elapsed)
    if isUnlockedForMoving then return end
    if warnTimer > 0 then
        warnTimer = warnTimer - elapsed
        if warnTimer <= 0 then
            self:Hide()
        elseif warnTimer < 0.5 then
            self:SetAlpha(warnTimer / 0.5)
        end
    end
end)

local function ShowBannerMessage(message, r, g, b, duration)
    UpdateBarStyles()
    warnText:SetText(message)
    warnFrame:SetAlpha(1.0)
    warnTimer = duration or 3.0
    warnFrame:Show()
end

-------------------------------------------------------------------------------
-- TANK AGGRO AMPEL-LEISTE
-------------------------------------------------------------------------------
threatBar = CreateFrame("StatusBar", "ATMTankThreatBar", UIParent)
threatBar:SetWidth(ATM_Settings.threatWidth or 400)
threatBar:SetHeight(ATM_Settings.threatHeight or 22)
threatBar:SetPoint("CENTER", UIParent, "CENTER", ATM_Settings.threatX, ATM_Settings.threatY)
threatBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
threatBar:SetMinMaxValues(0, 100)
threatBar:SetValue(100)
threatBar:Hide()

threatBackdrop = CreateFrame("Frame", "ATMThreatBackdropFrame", threatBar)
threatBackdrop:SetPoint("TOPLEFT", -2, 2)
threatBackdrop:SetPoint("BOTTOMRIGHT", 2, -2)
threatBackdrop:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 0, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})

local threatTextContainer = CreateFrame("Frame", nil, threatBar)
threatTextContainer:SetAllPoints(threatBar)
threatTextContainer:SetFrameLevel(threatBar:GetFrameLevel() + 15)

threatText = threatTextContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
threatText:SetPoint("CENTER", threatTextContainer, "CENTER", 0, 0)
threatText:SetFont("Fonts\\FRIZQT__.TTF", ATM_Settings.fontSize, "OUTLINE")
threatText:SetTextColor(1.0, 1.0, 1.0, 1.0)

threatBar:EnableMouse(true)
threatBar:SetMovable(true)
threatBar:RegisterForDrag("LeftButton")
threatBar:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() or isUnlockedForMoving then
        self:StartMoving()
    end
end)
threatBar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    ATM_Settings.threatX = x
    ATM_Settings.threatY = y
end)

local threatTimer = 0
threatBar:SetScript("OnUpdate", function(self, elapsed)
    if ischimeraTestingMode or isUnlockedForMoving then return end

    threatTimer = threatTimer + elapsed
    if threatTimer > 0.2 then
        threatTimer = 0
        
        if not ATM_Settings.showTankThreatBar or not InCombatLockdown() then
            self:Hide()
            return
        end

        self:Show()
        self:SetValue(100)

        local hasAggro = false
        local globalStatus = UnitThreatSituation("player")
        if globalStatus and globalStatus >= 2 then 
            hasAggro = true 
        end

        if not hasAggro then
            local unitsToScan = { "target", "targettarget", "focustarget" }
            for _, unit in ipairs(unitsToScan) do
                if UnitExists(unit) and UnitCanAttack("player", unit) then
                    local _, status = UnitDetailedThreatSituation("player", unit)
                    if status and status >= 2 then
                        hasAggro = true
                        break
                    end
                end
            end
        end

        if hasAggro then
            self:SetStatusBarColor(0.9, 0.1, 0.1)
            threatText:SetText("Tank Aggro: VERLOREN (ACHTUNG!)")
        else
            self:SetStatusBarColor(0.0, 0.8, 0.2)
            threatText:SetText("Tank Aggro: Sicher (OK)")
        end
    end
end)

-------------------------------------------------------------------------------
-- TANK DEF-CD MONITOR (STATUSLEISTE)
-------------------------------------------------------------------------------
cdBar = CreateFrame("StatusBar", "ATMCdBar", UIParent)
cdBar:SetWidth(ATM_Settings.threatWidth or 400)
cdBar:SetHeight(ATM_Settings.threatHeight or 22)
cdBar:SetPoint("CENTER", UIParent, "CENTER", ATM_Settings.cdX, ATM_Settings.cdY)
cdBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
cdBar:SetStatusBarColor(0.8, 0.5, 0.0, 0.95)
cdBar:Hide()

cdBackdrop = CreateFrame("Frame", "ATMCDBackdropFrame", cdBar)
cdBackdrop:SetPoint("TOPLEFT", -2, 2)
cdBackdrop:SetPoint("BOTTOMRIGHT", 2, -2)
cdBackdrop:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 0, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})

local cdTextContainer = CreateFrame("Frame", nil, cdBar)
cdTextContainer:SetAllPoints(cdBar)
cdTextContainer:SetFrameLevel(cdBar:GetFrameLevel() + 15)

cdText = cdTextContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
cdText:SetPoint("CENTER", cdTextContainer, "CENTER", 0, 0)
cdText:SetFont("Fonts\\FRIZQT__.TTF", ATM_Settings.fontSize or 12, "OUTLINE")
cdText:SetTextColor(1.0, 0.85, 0.0, 1.0)
cdText:SetText("Kein aktiver Def-CD")

cdBar:EnableMouse(true)
cdBar:SetMovable(true)
cdBar:RegisterForDrag("LeftButton")
cdBar:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() or isUnlockedForMoving then
        self:StartMoving()
    end
end)
cdBar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    ATM_Settings.cdX = x
    ATM_Settings.cdY = y
end)

local function UpdateCDMonitorDisplay(tankName, spellName, duration)
    if not ATM_Settings.showCDMonitor or not IsInInstanceArea() then return end
    UpdateBarStyles()
    
    cdBar:Show()
    local totalTime = duration or 12
    cdBar:SetMinMaxValues(0, totalTime)
    
    local timeLeft = totalTime
    cdText:SetText(string.format("%s: %s", tankName, spellName))
    cdText:SetTextColor(1.0, 0.85, 0.0, 1.0)
    cdBar:SetStatusBarColor(0.8, 0.5, 0.0)
    
    if cdBar.timerScript then cdBar:SetScript("OnUpdate", nil) end
    cdBar:SetScript("OnUpdate", function(f, el)
        if isUnlockedForMoving then return end
        timeLeft = timeLeft - el
        f:SetValue(timeLeft)
        if timeLeft <= 0 then
            f:Hide()
            f:SetScript("OnUpdate", nil)
            cdText:SetText("Kein aktiver Def-CD")
            cdText:SetTextColor(1.0, 0.85, 0.0, 1.0)
        end
    end)
end

-------------------------------------------------------------------------------
-- INTERRUPT-MONITOR (STATUSLEISTE)
-------------------------------------------------------------------------------
intBar = CreateFrame("StatusBar", "ATMIntBar", UIParent)
intBar:SetWidth(ATM_Settings.threatWidth or 400)
intBar:SetHeight(ATM_Settings.threatHeight or 22)
intBar:SetPoint("CENTER", UIParent, "CENTER", ATM_Settings.intX or 0, ATM_Settings.intY or -195)
intBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
intBar:SetStatusBarColor(0.1, 0.5, 0.9, 0.95)
intBar:Hide()

intBackdrop = CreateFrame("Frame", "ATMIntBackdropFrame", intBar)
intBackdrop:SetPoint("TOPLEFT", -2, 2)
intBackdrop:SetPoint("BOTTOMRIGHT", 2, -2)
intBackdrop:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 0, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})

local intTextContainer = CreateFrame("Frame", nil, intBar)
intTextContainer:SetAllPoints(intBar)
intTextContainer:SetFrameLevel(intBar:GetFrameLevel() + 15)

intText = intTextContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
intText:SetPoint("CENTER", intTextContainer, "CENTER", 0, 0)
intText:SetFont("Fonts\\FRIZQT__.TTF", ATM_Settings.fontSize or 12, "OUTLINE")
intText:SetTextColor(0.2, 0.8, 1.0, 1.0)
intText:SetText("Kein Interrupt")

intBar:EnableMouse(true)
intBar:SetMovable(true)
intBar:RegisterForDrag("LeftButton")
intBar:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() or isUnlockedForMoving then
        self:StartMoving()
    end
end)
intBar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    ATM_Settings.intX = x
    ATM_Settings.intY = y
end)

local function UpdateInterruptDisplay(playerName, spellName)
    if not ATM_Settings.showInterruptBar or not IsInInstanceArea() then return end
    UpdateBarStyles()
    
    intBar:Show()
    local totalTime = 3.5
    intBar:SetMinMaxValues(0, totalTime)
    
    local timeLeft = totalTime
    intText:SetText(string.format("Interrupt: %s (%s)", playerName, spellName))
    intText:SetTextColor(0.2, 0.9, 1.0, 1.0)
    intBar:SetStatusBarColor(0.1, 0.6, 1.0)
    
    if intBar.timerScript then intBar:SetScript("OnUpdate", nil) end
    intBar:SetScript("OnUpdate", function(f, el)
        if isUnlockedForMoving then return end
        timeLeft = timeLeft - el
        f:SetValue(timeLeft)
        if timeLeft <= 0 then
            f:Hide()
            f:SetScript("OnUpdate", nil)
            intText:SetText("Kein Interrupt")
            intText:SetTextColor(0.2, 0.8, 1.0, 1.0)
        end
    end)
end

-------------------------------------------------------------------------------
-- TRINK-STATUSLEISTE (MEGA ICONS: 30x30)
-------------------------------------------------------------------------------
drinkBar = CreateFrame("StatusBar", "ATMDrinkBar", UIParent)
drinkBar:SetWidth(ATM_Settings.threatWidth or 400)
drinkBar:SetHeight(ATM_Settings.threatHeight or 22)
drinkBar:SetPoint("CENTER", UIParent, "CENTER", ATM_Settings.drinkX or 0, ATM_Settings.drinkY or -230)
drinkBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
drinkBar:SetStatusBarColor(0.0, 0.5, 0.8, 0.95)
drinkBar:Hide()

drinkBackdrop = CreateFrame("Frame", "ATMDrinkBackdropFrame", drinkBar)
drinkBackdrop:SetPoint("TOPLEFT", -2, 2)
drinkBackdrop:SetPoint("BOTTOMRIGHT", 2, -2)
drinkBackdrop:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 0, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})

local drinkTextContainer = CreateFrame("Frame", nil, drinkBar)
drinkTextContainer:SetAllPoints(drinkBar)
drinkTextContainer:SetFrameLevel(drinkBar:GetFrameLevel() + 15)

drinkText = drinkTextContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
drinkText:SetPoint("CENTER", drinkTextContainer, "CENTER", 0, 0)
drinkText:SetFont("Fonts\\FRIZQT__.TTF", ATM_Settings.fontSize or 12, "OUTLINE")
drinkText:SetTextColor(0.0, 0.9, 1.0, 1.0)
drinkText:SetText("Niemand am Trinken")

drinkBar:EnableMouse(true)
drinkBar:SetMovable(true)
drinkBar:RegisterForDrag("LeftButton")
drinkBar:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() or isUnlockedForMoving then
        self:StartMoving()
    end
end)
drinkBar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    ATM_Settings.drinkX = x
    ATM_Settings.drinkY = y
end)

-------------------------------------------------------------------------------
-- ESS-STATUSLEISTE (MEGA ICONS: 30x30)
-------------------------------------------------------------------------------
foodBar = CreateFrame("StatusBar", "ATMFoodBar", UIParent)
foodBar:SetWidth(ATM_Settings.threatWidth or 400)
foodBar:SetHeight(ATM_Settings.threatHeight or 22)
foodBar:SetPoint("CENTER", UIParent, "CENTER", ATM_Settings.foodX or 0, ATM_Settings.foodY or -265)
foodBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
foodBar:SetStatusBarColor(0.8, 0.5, 0.0, 0.95)
foodBar:Hide()

foodBackdrop = CreateFrame("Frame", "ATMFoodBackdropFrame", foodBar)
foodBackdrop:SetPoint("TOPLEFT", -2, 2)
foodBackdrop:SetPoint("BOTTOMRIGHT", 2, -2)
foodBackdrop:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 0, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})

local foodTextContainer = CreateFrame("Frame", nil, foodBar)
foodTextContainer:SetAllPoints(foodBar)
foodTextContainer:SetFrameLevel(foodBar:GetFrameLevel() + 15)

foodText = foodTextContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
foodText:SetPoint("CENTER", foodTextContainer, "CENTER", 0, 0)
foodText:SetFont("Fonts\\FRIZQT__.TTF", ATM_Settings.fontSize or 12, "OUTLINE")
foodText:SetTextColor(1.0, 0.8, 0.2, 1.0)
foodText:SetText("Niemand am Essen")

foodBar:EnableMouse(true)
foodBar:SetMovable(true)
foodBar:RegisterForDrag("LeftButton")
foodBar:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() or isUnlockedForMoving then
        self:StartMoving()
    end
end)
foodBar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint()
    ATM_Settings.foodX = x
    ATM_Settings.foodY = y
end)

local function CheckGroupDrinkingAndFood()
    if not IsInInstanceArea() or InCombatLockdown() then
        if not ischimeraTestingMode then
            drinkBar:Hide()
            foodBar:Hide()
        end
        return
    end

    local drinkingList = {}
    local foodList = {}

    local isSelfDrinking, isSelfEating = false, false
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if name then
            if name:find("Drink") or name:find("Trinken") then
                isSelfDrinking = true
            end
            if name:find("Food") or name:find("Essen") or name:find("Well Fed") or name:find("Essen & Trinken") then
                isSelfEating = true
            end
        end
    end
    if isSelfDrinking then table.insert(drinkingList, UnitName("player") or "Du") end
    if isSelfEating then table.insert(foodList, UnitName("player") or "Du") end

    local numMembers = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers()
    local prefix = GetNumRaidMembers() > 0 and "raid" or "party"

    for i = 1, numMembers do
        local unit = prefix .. i
        if UnitExists(unit) then
            local unitName = UnitName(unit)
            for b = 1, 40 do
                local buffName = UnitBuff(unit, b)
                if buffName then
                    if (buffName:find("Drink") or buffName:find("Trinken")) and unitName then
                        table.insert(drinkingList, unitName)
                    end
                    if (buffName:find("Food") or buffName:find("Essen") or buffName:find("Well Fed") or buffName:find("Essen & Trinken")) and unitName then
                        table.insert(foodList, unitName)
                    end
                end
            end
        end
    end

    if ATM_Settings.showDrinkBar and #drinkingList > 0 then
        UpdateBarStyles()
        drinkBar:Show()
        drinkBar:SetValue(100)
        drinkText:SetText("|TInterface\\Icons\\INV_Drink_07:30:30:0:0|t " .. table.concat(drinkingList, ", "))
    else
        drinkBar:Hide()
    end

    if ATM_Settings.showFoodBar and #foodList > 0 then
        UpdateBarStyles()
        foodBar:Show()
        foodBar:SetValue(100)
        foodText:SetText("|TInterface\\Icons\\INV_Misc_Food_15:30:30:0:0|t " .. table.concat(foodList, ", "))
    else
        foodBar:Hide()
    end
end

-------------------------------------------------------------------------------
-- TESTMODUS
-------------------------------------------------------------------------------
function RunTestMode()
    ischimeraTestingMode = true
    UpdateBarStyles()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM TEST]|r Starte Testmodus (v1.77)...")

    PlayCustomSound(ATM_Settings.alertSound)
    TriggerScreenFlash()
    local lang = ATM_Settings.language or "DE"
    ShowBannerMessage(string.format(L[lang].aggroScreen, "Testmob"), 1.0, 0.1, 0.1, 2.5)
    
    threatBar:Show()
    threatBar:SetValue(100)
    threatBar:SetStatusBarColor(0.9, 0.1, 0.1)
    threatText:SetText("Tank Aggro: VERLOREN (Test)")

    UpdateCDMonitorDisplay("TestTank", "Schildwall", 12)
    UpdateInterruptDisplay("TestSpieler", "Feuerball")

    local testTimer = CreateFrame("Frame")
    local step = 0
    testTimer:SetScript("OnUpdate", function(self, elapsed)
        step = step + elapsed
        if step > 2.5 and step < 2.6 then
            threatBar:SetStatusBarColor(0.0, 0.8, 0.2)
            threatText:SetText("Tank Aggro: Sicher (OK)")
            ShowBannerMessage(string.format(L[lang].defCD, "TestTank", "Schildwall", 12), 0.0, 1.0, 0.2, 2.5)
        elseif step > 5.0 and step < 5.1 then
            PlayCustomSound(ATM_Settings.tankLostSound)
            ShowBannerMessage(string.format(L[lang].tauntFail, "Spott", "TestTank", "Testboss"), 1.0, 0.0, 0.0, 2.5)
        elseif step > 7.5 and step < 7.6 then
            ShowBannerMessage(string.format(L[lang].tankSwap, "Tank1", "Spott", "Tank2"), 0.0, 0.8, 1.0, 2.5)
        elseif step > 10.0 and step < 10.1 then
            PlayCustomSound(ATM_Settings.interruptSound)
            ShowBannerMessage(string.format(L[lang].interrupt, "Spieler", "Feuerball"), 1.0, 0.5, 0.0, 2.5)
        elseif step > 12.5 and step < 12.6 then
            if ATM_Settings.showDrinkBar then
                drinkBar:Show()
                drinkBar:SetValue(100)
                drinkText:SetText("|TInterface\\Icons\\INV_Drink_07:30:30:0:0|t Chimera, TestHeiler")
            end
            if ATM_Settings.showFoodBar then
                foodBar:Show()
                foodBar:SetValue(100)
                foodText:SetText("|TInterface\\Icons\\INV_Misc_Food_15:30:30:0:0|t TankDD, TestDD")
            end
        elseif step > 16.5 and step < 16.6 then
            drinkBar:Hide()
            foodBar:Hide()
            ShowBannerMessage(L[lang].tankDied, 0.8, 0.0, 0.0, 3.0)
            if not isUnlockedForMoving then 
                threatBar:Hide() 
                cdBar:Hide()
                intBar:Hide()
                drinkBar:Hide()
                foodBar:Hide()
                warnFrame:Hide() 
            end
            ischimeraTestingMode = false
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM TEST]|r Test beendet.")
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-------------------------------------------------------------------------------
-- SPOTT-ZAUBER & DEFENSIV-COOLDOWNS
-------------------------------------------------------------------------------
local TAUNT_SPELLS = {
    [355]   = "Spott", ["Spott"] = "Spott", ["Taunt"] = "Taunt",
    [62124] = "Hand der Abrechnung", ["Hand der Abrechnung"] = "Hand der Abrechnung", ["Hand of Reckoning"] = "Hand of Reckoning",
    [49576] = "Todesgriff", ["Todesgriff"] = "Todesgriff", ["Death Grip"] = "Death Grip",
    [56222] = "Dunkler Befehl", ["Dunkler Befehl"] = "Dunkler Befehl", ["Dark Command"] = "Dark Command",
    [6795]  = "Knurren", ["Knurren"] = "Knurren", ["Growl"] = "Growl"
}

local TANK_DEF_SPELLS = {
    [871] = { name = "Schildwall", duration = 12 },
    ["Schildwall"] = { name = "Schildwall", duration = 12 },
    ["Shield Wall"] = { name = "Shield Wall", duration = 12 },
    [12975] = { name = "Letztes Gefecht", duration = 20 },
    ["Letztes Gefecht"] = { name = "Letztes Gefecht", duration = 20 },
    ["Last Stand"] = { name = "Last Stand", duration = 20 },
    [498] = { name = "Göttlicher Schutz", duration = 12 },
    ["Göttlicher Schutz"] = { name = "Göttlicher Schutz", duration = 12 },
    ["Divine Protection"] = { name = "Divine Protection", duration = 12 },
    [31850] = { name = "Unermüdlicher Hüter", duration = 10 },
    ["Unermüdlicher Hüter"] = { name = "Unermüdlicher Hüter", duration = 10 },
    ["Ardent Defender"] = { name = "Ardent Defender", duration = 10 },
    [48792] = { name = "Eisige Gegenwehr", duration = 12 },
    ["Eisige Gegenwehr"] = { name = "Eisige Gegenwehr", duration = 12 },
    ["Icebound Fortitude"] = { name = "Icebound Fortitude", duration = 12 },
    [55233] = { name = "Vampirblut", duration = 10 },
    ["Vampirblut"] = { name = "Vampirblut", duration = 10 },
    ["Vampiric Blood"] = { name = "Vampiric Blood", duration = 10 },
    [61336] = { name = "Überlebensinstinkte", duration = 20 },
    ["Überlebensinstinkte"] = { name = "Überlebensinstinkte", duration = 20 },
    ["Survival Instincts"] = { name = "Survival Instincts", duration = 20 },
    [22812] = { name = "Baumrinde", duration = 12 },
    ["Baumrinde"] = { name = "Baumrinde", duration = 12 },
    ["Barkskin"] = { name = "Barkskin", duration = 12 }
}

-- PERFEKTE WARNMELDUNGEN MIT 30x30 XXL-ICONS (v1.77)
L = {
    EN = {
        aggroChat = "[AGGRO] >>> Aggro on Healer %s! Please taunt! <<<",
        aggroScreen = "|TInterface\\Icons\\Ability_Warrior_ShieldBash:30:30:0:0|t |cffff2222AGGRO GEZOGEN von %s!|r |TInterface\\Icons\\Ability_Warrior_ShieldBash:30:30:0:0|t",
        oom = "[ATM] OOM / Low Mana! Careful!",
        drinking = "[ATM] Is drinking (Mana: %d%%) - Please wait!",
        tankDied = "|TInterface\\Icons\\Spell_Shadow_DeathCoil:30:30:0:0|t |cffff0000TANK GESTORBEN!|r |TInterface\\Icons\\Spell_Shadow_DeathCoil:30:30:0:0|t",
        tankLow = "|TInterface\\Icons\\Ability_Rogue_FeignDeath:30:30:0:0|t |cffff8800TANK KRITISCH (%d%%)!|r",
        defCD = "|TInterface\\Icons\\Ability_Warrior_ShieldBarrier:30:30:0:0|t |cff00ff00%s: %s (%ds)|r",
        tauntFail = "|TInterface\\Icons\\Spell_Nature_WispSplode:30:30:0:0|t |cffff4444SPOTT VERFEHLT (%s) durch %s auf %s!|r",
        tankSwap = "|TInterface\\Icons\\Ability_DualWield:30:30:0:0|t |cff00ccffTaunt-Swap: %s (%s) -> %s|r",
        interrupt = "|TInterface\\Icons\\Spell_Frost_WindWalk:30:30:0:0|t |cffff9900Interrupt: %s (%s)|r"
    },
    DE = {
        aggroChat = "[AGGRO] >>> Aggro auf Heiler %s! Bitte abspotten! <<<",
        aggroScreen = "|TInterface\\Icons\\Ability_Warrior_ShieldBash:30:30:0:0|t |cffff2222AGGRO GEZOGEN von %s!|r |TInterface\\Icons\\Ability_Warrior_ShieldBash:30:30:0:0|t",
        oom = "[ATM] OOM / Wenig Mana! Vorsicht!",
        drinking = "[ATM] Trinkt gerade (Mana: %d%%) - Bitte warten!",
        tankDied = "|TInterface\\Icons\\Spell_Shadow_DeathCoil:30:30:0:0|t |cffff0000TANK GESTORBEN!|r |TInterface\\Icons\\Spell_Shadow_DeathCoil:30:30:0:0|t",
        tankLow = "|TInterface\\Icons\\Ability_Rogue_FeignDeath:30:30:0:0|t |cffff8800TANK KRITISCH (%d%%)!|r",
        defCD = "|TInterface\\Icons\\Ability_Warrior_ShieldBarrier:30:30:0:0|t |cff00ff00%s: %s (%ds)|r",
        tauntFail = "|TInterface\\Icons\\Spell_Nature_WispSplode:30:30:0:0|t |cffff4444SPOTT VERFEHLT (%s) durch %s auf %s!|r",
        tankSwap = "|TInterface\\Icons\\Ability_DualWield:30:30:0:0|t |cff00ccffTaunt-Swap: %s (%s) -> %s|r",
        interrupt = "|TInterface\\Icons\\Spell_Frost_WindWalk:30:30:0:0|t |cffff9900Interrupt: %s (%s)|r"
    }
}

local function IsTankActive(unit)
    local _, class = UnitClass(unit)
    if class == "PALADIN" then
        for i = 1, 40 do
            local name = UnitBuff(unit, i)
            if name and (name:find("Righteous Fury") or name:find("Zorn des Gerechten")) then return true end
        end
    elseif class == "WARRIOR" then
        for i = 1, 40 do
            local name = UnitBuff(unit, i)
            if name and (name:find("Defensive Stance") or name:find("Verteidigungshaltung")) then return true end
        end
    elseif class == "DRUID" then
        for i = 1, 40 do
            local name = UnitBuff(unit, i)
            if name and (name:find("Bear Form") or name:find("Bärenform")) then return true end
        end
    elseif class == "DEATHKNIGHT" then
        for i = 1, 40 do
            local name = UnitBuff(unit, i)
            if name and (name:find("Frost Presence") or name:find("Frostpräsenz")) then return true end
        end
    end
    return false
end

local function FindAndMarkTank()
    if not IsInInstanceArea() then return end
    if not GetNumPartyMembers() or GetNumPartyMembers() == 0 then
        currentTankUnit = "player"
        return
    end

    local targetUnit = nil
    for i = 1, GetNumPartyMembers() do
        local unit = "party" .. i
        if UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "TANK" then
            targetUnit = unit
            break
        end
    end

    if not targetUnit then
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            if IsTankActive(unit) then
                targetUnit = unit
                break
            end
        end
    end

    if not targetUnit then
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            local _, class = UnitClass(unit)
            if class == "WARRIOR" or class == "PALADIN" or class == "DEATHKNIGHT" or class == "DRUID" then
                targetUnit = unit
                break
            end
        end
    end

    currentTankUnit = targetUnit or "party1" or "player"
    if targetUnit and targetUnit ~= "player" then
        if GetRaidTargetIndex(targetUnit) ~= ATM_Settings.marker then
            SetRaidTarget(targetUnit, ATM_Settings.marker)
        end
    end
end

local function CheckThreatStatus()
    if not ATM_Settings.aggroAlert or not InCombatLockdown() then return end
    local hasAggro = false
    local attackingMob = "Unbekannt"

    local globalStatus = UnitThreatSituation("player")
    if globalStatus and globalStatus >= 2 then 
        hasAggro = true 
        if UnitExists("target") and UnitCanAttack("player", "target") then
            attackingMob = UnitName("target") or "Unbekannt"
        end
    end

    if not hasAggro then
        local unitsToScan = { "focustarget", "target", "targettarget", "mouseover" }
        for _, unit in ipairs(unitsToScan) do
            if UnitExists(unit) and UnitCanAttack("player", unit) then
                local _, status = UnitDetailedThreatSituation("player", unit)
                if status and status >= 2 then
                    hasAggro = true
                    attackingMob = UnitName(unit) or "Gegner"
                    break
                end
            end
        end
    end

    if hasAggro then
        local now = GetTime()
        if (now - lastChatAlert) > CHAT_ALERT_COOLDOWN then
            lastChatAlert = now
            PlayCustomSound(ATM_Settings.alertSound)
            TriggerScreenFlash()
            local lang = ATM_Settings.language or "DE"
            ShowBannerMessage(string.format(L[lang].aggroScreen, attackingMob), 1.0, 0.1, 0.1, 3.5)
            local text = string.format(L[lang].aggroChat, UnitName("player"))
            local chatType = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
            if chatType then SendChatMessage(text, chatType) end
        end
    end
end

local function CheckStatus()
    if not IsInInstanceArea() then return end
    local lang = ATM_Settings.language or "DE"
    
    if ATM_Settings.manaWhisper and currentTankUnit and UnitExists(currentTankUnit) and InCombatLockdown() then
        if UnitPowerType("player") == 0 then
            local maxMana = UnitPowerMax("player")
            local currMana = UnitPower("player")
            if maxMana > 0 and (currMana / maxMana) < 0.15 then
                local now = GetTime()
                if (now - lastManaWhisper) > MANA_WHISPER_COOLDOWN then
                    lastManaWhisper = now
                    local tankName = UnitName(currentTankUnit)
                    if tankName then SendChatMessage(L[lang].oom, "WHISPER", nil, tankName) end
                end
            end
        end
    end

    if ATM_Settings.drinkWhisper and currentTankUnit and UnitExists(currentTankUnit) then
        for i = 1, 40 do
            local name = UnitBuff("player", i)
            if name and (name:find("Drink") or name:find("Trinken")) then
                local now = GetTime()
                if (now - lastDrinkWhisper) > 15 then
                    lastDrinkWhisper = now
                    local tankName = UnitName(currentTankUnit)
                    local manaPct = math.floor((UnitPower("player") / UnitPowerMax("player")) * 100)
                    if tankName then SendChatMessage(string.format(L[lang].drinking, manaPct), "WHISPER", nil, tankName) end
                end
                break
            end
        end
    end

    if ATM_Settings.tankHealthAlert and currentTankUnit and UnitExists(currentTankUnit) and InCombatLockdown() then
        local hp = UnitHealth(currentTankUnit)
        local maxHp = UnitHealthMax(currentTankUnit)
        if maxHp > 0 then
            local pct = math.floor((hp / maxHp) * 100)
            if pct < 25 and hp > 0 then
                local now = GetTime()
                if (now - lastHealthAlert) > 10 then
                    lastHealthAlert = now
                    PlayCustomSound(ATM_Settings.alertSound)
                    TriggerScreenFlash()
                    ShowBannerMessage(string.format(L[lang].tankLow, pct), 1.0, 0.3, 0.0, 3.0)
                end
            end
        end
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_MANA")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

frame:SetScript("OnEvent", function(self, event, ...)
    local lang = ATM_Settings.language or "DE"
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "AutoTankMarker" then
            SetCVar("threatShowNumeric", 1)
            UpdateBarStyles()
            UpdateMinimapButtonPosition(ATM_Settings.minimapPos or 45)
        end
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "PLAYER_REGEN_DISABLED" then
        CheckThreatStatus()
    elseif event == "UNIT_AURA" or event == "UNIT_HEALTH" or event == "UNIT_MANA" then
        CheckStatus()
        CheckGroupDrinkingAndFood()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not IsInInstanceArea() then return end
        local timestamp, subEvent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName, _, extraArg1, extraArg2 = ...
        
        if ATM_Settings.tankDeathSound and currentTankUnit then
            if subEvent == "UNIT_DIED" and destGUID == UnitGUID(currentTankUnit) then
                PlayCustomSound(ATM_Settings.tankLostSound)
                ShowBannerMessage(L[lang].tankDied, 0.8, 0.0, 0.0, 4.0)
            end
        end

        if ATM_Settings.tauntAlert and currentTankUnit then
            if subEvent == "SPELL_MISSED" and (sourceGUID == UnitGUID(currentTankUnit) or (sourceName and sourceName == UnitName(currentTankUnit))) then
                if TAUNT_SPELLS[spellID] or TAUNT_SPELLS[spellName] then
                    local spellUsed = TAUNT_SPELLS[spellID] or TAUNT_SPELLS[spellName]
                    local targetMob = destName or "Gegner"
                    local activeTank = sourceName or UnitName(currentTankUnit) or "Tank"
                    PlayCustomSound(ATM_Settings.tankLostSound)
                    ShowBannerMessage(string.format(L[lang].tauntFail, spellUsed, activeTank, targetMob), 1.0, 0.1, 0.1, 3.5)
                end
            end
        end

        if ATM_Settings.tankDefAlert then
            if (subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_CAST_START") then
                local cdInfo = TANK_DEF_SPELLS[spellID] or TANK_DEF_SPELLS[spellName]
                if cdInfo then
                    local tankName = sourceName or "Tank"
                    ShowBannerMessage(string.format(L[lang].defCD, tankName, cdInfo.name, cdInfo.duration), 0.0, 1.0, 0.2, 3.5)
                    if ATM_Settings.showCDMonitor then
                        UpdateCDMonitorDisplay(tankName, cdInfo.name, cdInfo.duration)
                    end
                end
            end
        end

        if ATM_Settings.showTankSwap and subEvent == "SPELL_CAST_SUCCESS" then
            if TAUNT_SPELLS[spellID] or TAUNT_SPELLS[spellName] then
                if sourceName and destName then
                    local spellUsed = TAUNT_SPELLS[spellID] or TAUNT_SPELLS[spellName]
                    ShowBannerMessage(string.format(L[lang].tankSwap, sourceName, spellUsed, destName), 0.0, 0.8, 1.0, 3.0)
                end
            end
        end

        if ATM_Settings.showInterrupt and subEvent == "SPELL_INTERRUPT" then
            local interruptedSpell = extraArg2 or "Zauber"
            PlayCustomSound(ATM_Settings.interruptSound)
            ShowBannerMessage(string.format(L[lang].interrupt, sourceName or "Spieler", interruptedSpell), 1.0, 0.5, 0.0, 3.0)
            if ATM_Settings.showInterruptBar then
                UpdateInterruptDisplay(sourceName or "Spieler", interruptedSpell)
            end
        end
    else
        local timer = 0
        self:SetScript("OnUpdate", function(self, elapsed)
            timer = timer + elapsed
            if timer > 1.5 then
                FindAndMarkTank()
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end)

-------------------------------------------------------------------------------
-- OPTIONS PANEL (GUI) - v1.77
-------------------------------------------------------------------------------
local optionsPanel = CreateFrame("Frame", "AutoTankMarkerOptionsPanel", UIParent)
optionsPanel.name = "AutoTankMarker"

local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("v1.77 ©cHiMeRa83")

-- ScrollFrame Erstellung für das Einstellungsmenü
local scrollFrame = CreateFrame("ScrollFrame", "ATMOptionsScrollFrame", optionsPanel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -45)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

local scrollChild = CreateFrame("Frame", "ATMOptionsScrollChild", scrollFrame)
scrollChild:SetSize(560, 960)
scrollFrame:SetScrollChild(scrollChild)

local function CreateCheckbox(name, labelText, yOffset, settingKey, tooltipText)
    local cb = CreateFrame("CheckButton", name, scrollChild, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, yOffset)
    _G[cb:GetName() .. "Text"]:SetText(labelText)
    cb:SetScript("OnShow", function(self) self:SetChecked(ATM_Settings[settingKey]) end)
    cb:SetScript("OnClick", function(self) ATM_Settings[settingKey] = self:GetChecked() end)
    
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(labelText, 1, 0.8, 0, 1, true)
        GameTooltip:AddLine(tooltipText, 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    return cb
end

CreateCheckbox("ATM_CB_AggroAlert", "Aggro-Warnung, Chat-Meldung & Bildschirm-Blitz", -10, "aggroAlert", "Schlägt Alarm, sendet Gruppennachrichten und lässt den Bildschirm rot aufleuchten, wenn du Aggro ziehst.")
CreateCheckbox("ATM_CB_ThreatBar", "Tank-Aggro Ampel-Leiste im Kampf anzeigen", -32, "showTankThreatBar", "Zeigt eine Statusleiste an, die den Aggro-Status des Tanks im Kampf überwacht.")
CreateCheckbox("ATM_CB_CDMonitor", "Tank Def-CD Statusleiste anzeigen", -54, "showCDMonitor", "Zeigt eine eigene Leiste für aktive Defensiv-Cooldowns des Tanks an.")
CreateCheckbox("ATM_CB_IntBar", "Interrupt-Statusleiste anzeigen", -76, "showInterruptBar", "Zeigt bei erfolgreichen Kicks/Interrupts eine Leiste mit Namen und Zauber an.")
CreateCheckbox("ATM_CB_DrinkBar", "Trink-Statusleiste anzeigen", -98, "showDrinkBar", "Zeigt eine eigene Leiste an, wenn Gruppenmitglieder gerade Wasser trinken.")
CreateCheckbox("ATM_CB_FoodBar", "Ess-Statusleiste anzeigen", -120, "showFoodBar", "Zeigt eine eigene Leiste an, wenn Gruppenmitglieder gerade essen.")
CreateCheckbox("ATM_CB_TankSwap", "Tank-Wechsel (Taunt-Swap) Ansage", -142, "showTankSwap", "Informiert dich per Banner, wenn ein Tank erfolgreich spottet.")
CreateCheckbox("ATM_CB_Interrupt", "Interrupt & CC-Tracker aktivieren", -164, "showInterrupt", "Überwacht Gruppen-Interrupts und gibt Sound-Warnungen aus.")
CreateCheckbox("ATM_CB_ManaWhisper", "Flüstern bei < 15% Mana an Tank", -186, "manaWhisper", "Sendet automatisch einen Flüsterton an den Tank, wenn dein Mana unter 15% fällt.")
CreateCheckbox("ATM_CB_DrinkWhisper", "Flüstern an Tank wenn du trinkst", -208, "drinkWhisper", "Teilt dem Tank per Whisper mit, dass du gerade am Trinken bist.")
CreateCheckbox("ATM_CB_TankHealth", "Warnung wenn Tank unter 25% Leben fällt", -230, "tankHealthAlert", "Warnt dich akustisch und visuell, wenn das Leben des Tanks unter 25% sinkt.")
CreateCheckbox("ATM_CB_TankDeath", "Sound & Meldung wenn Tank stirbt", -252, "tankDeathSound", "Spielt einen Sound ab und zeigt ein Banner, falls der zugewiesene Tank stirbt.")
CreateCheckbox("ATM_CB_TankDef", "Meldung wenn Tank Defensiv-CDs zündet", -274, "tankDefAlert", "Gibt eine Meldung aus, sobald der Tank Schutzfähigkeiten einsetzt.")
CreateCheckbox("ATM_CB_TauntAlert", "Warnung wenn Spott des Tanks verfehlt", -296, "tauntAlert", "Warnt dich, wenn ein Spott des Tanks vom Gegner verfehlt/widerstanden wird.")

-- SLIDER: Gemeinsame Leisten-Breite (bis 800px) & Höhe
local sliderThreatW = CreateFrame("Slider", "ATMSliderThreatW", scrollChild, "OptionsSliderTemplate")
sliderThreatW:SetPoint("TOPLEFT", 20, -345)
sliderThreatW:SetMinMaxValues(150, 800)
sliderThreatW:SetValueStep(10)
_G[sliderThreatW:GetName() .. "Low"]:SetText("150")
_G[sliderThreatW:GetName() .. "High"]:SetText("800")
_G[sliderThreatW:GetName() .. "Text"]:SetText("Leisten Breite: " .. ATM_Settings.threatWidth)
sliderThreatW:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value)
    ATM_Settings.threatWidth = value
    UpdateBarStyles()
    _G[self:GetName() .. "Text"]:SetText("Leisten Breite: " .. value)
end)
sliderThreatW:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Leisten Breite", 1, 0.8, 0, 1, true)
    GameTooltip:AddLine("Legt die horizontale Breite für ALLE Leisten gemeinsam fest (bis zu 800px für Raids).", 0.9, 0.9, 0.9, true)
    GameTooltip:Show()
end)
sliderThreatW:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

local sliderThreatH = CreateFrame("Slider", "ATMSliderThreatH", scrollChild, "OptionsSliderTemplate")
sliderThreatH:SetPoint("TOPLEFT", 260, -345)
sliderThreatH:SetMinMaxValues(10, 50)
sliderThreatH:SetValueStep(2)
_G[sliderThreatH:GetName() .. "Low"]:SetText("10")
_G[sliderThreatH:GetName() .. "High"]:SetText("50")
_G[sliderThreatH:GetName() .. "Text"]:SetText("Leisten Höhe: " .. ATM_Settings.threatHeight)
sliderThreatH:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value)
    ATM_Settings.threatHeight = value
    UpdateBarStyles()
    _G[self:GetName() .. "Text"]:SetText("Leisten Höhe: " .. value)
end)
sliderThreatH:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Leisten Höhe", 1, 0.8, 0, 1, true)
    GameTooltip:AddLine("Legt die vertikale Höhe für ALLE Leisten gemeinsam fest.", 0.9, 0.9, 0.9, true)
    GameTooltip:Show()
end)
sliderThreatH:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

-- SLIDER: Schriftgröße & Minimap-Position
local sliderFont = CreateFrame("Slider", "ATMSliderFont", scrollChild, "OptionsSliderTemplate")
sliderFont:SetPoint("TOPLEFT", 20, -405)
sliderFont:SetMinMaxValues(10, 24)
sliderFont:SetValueStep(1)
_G[sliderFont:GetName() .. "Low"]:SetText("10")
_G[sliderFont:GetName() .. "High"]:SetText("24")
_G[sliderFont:GetName() .. "Text"]:SetText("Leisten Schriftgröße: " .. ATM_Settings.fontSize)
sliderFont:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value)
    ATM_Settings.fontSize = value
    UpdateBarStyles()
    _G[self:GetName() .. "Text"]:SetText("Leisten Schriftgröße: " .. value)
end)
sliderFont:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Leisten Schriftgröße", 1, 0.8, 0, 1, true)
    GameTooltip:AddLine("Passt die Schriftgröße aller Leistentexte gemeinsam an.", 0.9, 0.9, 0.9, true)
    GameTooltip:Show()
end)
sliderFont:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

local sliderMinimapAngle = CreateFrame("Slider", "ATMSliderMinimapAngle", scrollChild, "OptionsSliderTemplate")
sliderMinimapAngle:SetPoint("TOPLEFT", 260, -405)
sliderMinimapAngle:SetMinMaxValues(0, 360)
sliderMinimapAngle:SetValueStep(5)
_G[sliderMinimapAngle:GetName() .. "Low"]:SetText("0°")
_G[sliderMinimapAngle:GetName() .. "High"]:SetText("360°")
_G[sliderMinimapAngle:GetName() .. "Text"]:SetText("Minimap-Position: " .. (ATM_Settings.minimapPos or 45) .. "°")
sliderMinimapAngle:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value)
    ATM_Settings.minimapPos = value
    UpdateMinimapButtonPosition(value)
    _G[self:GetName() .. "Text"]:SetText("Minimap-Position: " .. value .. "°")
end)
sliderMinimapAngle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Minimap-Position", 1, 0.8, 0, 1, true)
    GameTooltip:AddLine("Verschiebt den ATM Minimap-Button im Kreis um die Minimap (0–360°).", 0.9, 0.9, 0.9, true)
    GameTooltip:Show()
end)
sliderMinimapAngle:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

-- BUTTONS & EXTRAS UNTEN
local btnTest = CreateFrame("Button", "ATM_Btn_RunTest", scrollChild, "UIPanelButtonTemplate")
btnTest:SetPoint("TOPLEFT", 260, -465)
btnTest:SetSize(160, 24)
btnTest:SetText("Testmodus starten")
btnTest:SetScript("OnClick", function() RunTestMode() end)

local cbMove = CreateFrame("CheckButton", "ATM_CB_MoveThreatBar", scrollChild, "InterfaceOptionsCheckButtonTemplate")
cbMove:SetPoint("TOPLEFT", 16, -465)
_G[cbMove:GetName() .. "Text"]:SetText("Alle Elemente verschiebbar machen")
cbMove:SetScript("OnClick", function(self)
    isUnlockedForMoving = self:GetChecked()
    UpdateBarStyles()
    if isUnlockedForMoving then
        warnFrame:Show()
        warnText:SetText("Warnbalken (Verschiebbar)")

        threatBar:Show()
        threatBar:SetValue(100)
        threatBar:SetStatusBarColor(0.0, 0.8, 0.2)
        threatText:SetText("Aggro-Leiste (Verschiebbar)")
        
        cdBar:Show()
        cdBar:SetValue(100)
        cdText:SetText("Def-CD Leiste (Verschiebbar)")

        intBar:Show()
        intBar:SetValue(100)
        intText:SetText("Interrupt-Leiste (Verschiebbar)")

        drinkBar:Show()
        drinkBar:SetValue(100)
        drinkText:SetText("|TInterface\\Icons\\INV_Drink_07:30:30:0:0|t Trink-Leiste (Verschiebbar)")

        foodBar:Show()
        foodBar:SetValue(100)
        foodText:SetText("|TInterface\\Icons\\INV_Misc_Food_15:30:30:0:0|t Ess-Leiste (Verschiebbar)")
    else
        warnFrame:Hide()
        threatBar:Hide()
        cdBar:Hide()
        intBar:Hide()
        drinkBar:Hide()
        foodBar:Hide()
    end
end)

local btnResetPos = CreateFrame("Button", "ATM_Btn_ResetPos", scrollChild, "UIPanelButtonTemplate")
btnResetPos:SetPoint("TOPLEFT", 16, -505)
btnResetPos:SetSize(160, 22)
btnResetPos:SetText("Positionen zurücksetzen")
btnResetPos:SetScript("OnClick", function()
    threatBar:ClearAllPoints() threatBar:SetPoint("CENTER", UIParent, "CENTER", 0, -120) ATM_Settings.threatX, ATM_Settings.threatY = 0, -120
    cdBar:ClearAllPoints() cdBar:SetPoint("CENTER", UIParent, "CENTER", 0, -160) ATM_Settings.cdX, ATM_Settings.cdY = 0, -160
    intBar:ClearAllPoints() intBar:SetPoint("CENTER", UIParent, "CENTER", 0, -195) ATM_Settings.intX, ATM_Settings.intY = 0, -195
    drinkBar:ClearAllPoints() drinkBar:SetPoint("CENTER", UIParent, "CENTER", 0, -230) ATM_Settings.drinkX, ATM_Settings.drinkY = 0, -230
    foodBar:ClearAllPoints() foodBar:SetPoint("CENTER", UIParent, "CENTER", 0, -265) ATM_Settings.foodX, ATM_Settings.foodY = 0, -265
    warnFrame:ClearAllPoints() warnFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 180) ATM_Settings.warnX, ATM_Settings.warnY = 0, 180
    ATM_Settings.minimapPos = 45 UpdateMinimapButtonPosition(45)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Alle Positionen zurückgesetzt.")
end)

-- SPRACH-EINSTELLUNG
local langHeader = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
langHeader:SetPoint("TOPLEFT", 320, -505)
langHeader:SetText("Sprache:")

local cbDE = CreateFrame("CheckButton", "ATM_CB_LangDE", scrollChild, "InterfaceOptionsCheckButtonTemplate")
cbDE:SetPoint("TOPLEFT", 310, -525)
_G[cbDE:GetName() .. "Text"]:SetText("DE")
_G[cbDE:GetName() .. "Text"]:SetPoint("LEFT", cbDE, "RIGHT", 2, 0)

local cbEN = CreateFrame("CheckButton", "ATM_CB_LangEN", scrollChild, "InterfaceOptionsCheckButtonTemplate")
cbEN:SetPoint("TOPLEFT", 430, -525)
_G[cbEN:GetName() .. "Text"]:SetText("EN")
_G[cbEN:GetName() .. "Text"]:SetPoint("LEFT", cbEN, "RIGHT", 2, 0)

cbDE:SetScript("OnClick", function(self)
    ATM_Settings.language = "DE"
    cbDE:SetChecked(true)
    cbEN:SetChecked(false)
end)

cbEN:SetScript("OnClick", function(self)
    ATM_Settings.language = "EN"
    cbDE:SetChecked(false)
    cbEN:SetChecked(true)
end)

-- RECHTE SPALTE: DROPDOWNS IM SCROLLCHILD (Icons, Skins & Sounds)
local iconHeader = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
iconHeader:SetPoint("TOPLEFT", 320, -10)
iconHeader:SetText("Tank-Symbol:")

local iconDropdown = CreateFrame("Frame", "ATMIconDropdown", scrollChild, "UIDropDownMenuTemplate")
iconDropdown:SetPoint("TOPLEFT", 310, -28)
UIDropDownMenu_SetWidth(iconDropdown, 180)
local iconNames = { 
    [1] = "1 - Stern", [2] = "2 - Kreis", [3] = "3 - Diamant", [4] = "4 - Dreieck", 
    [5] = "5 - Mond", [6] = "6 - Quadrat", [7] = "7 - Kreuz", [8] = "8 - Totenkopf" 
}

UIDropDownMenu_Initialize(iconDropdown, function(self, level)
    for id, name in ipairs(iconNames) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = name
        info.value = id
        info.func = function(self)
            ATM_Settings.marker = self.value
            UIDropDownMenu_SetSelectedValue(iconDropdown, self.value)
            FindAndMarkTank()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

local skinHeader = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
skinHeader:SetPoint("TOPLEFT", 320, -75)
skinHeader:SetText("Leisten-Skin (Design):")

local skinDropdown = CreateFrame("Frame", "ATMSkinDropdown", scrollChild, "UIDropDownMenuTemplate")
skinDropdown:SetPoint("TOPLEFT", 310, -92)
UIDropDownMenu_SetWidth(skinDropdown, 180)

UIDropDownMenu_Initialize(skinDropdown, function(self, level)
    for _, sk in ipairs(AVAILABLE_SKINS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = sk.name
        info.value = sk.value
        info.func = function(self)
            ATM_Settings.barSkin = self.value
            UIDropDownMenu_SetSelectedValue(skinDropdown, self.value)
            UIDropDownMenu_SetText(skinDropdown, sk.name)
            UpdateBarStyles()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

local soundHeader1 = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
soundHeader1:SetPoint("TOPLEFT", 320, -140)
soundHeader1:SetText("Sound: Eigene Aggro")

local soundDropdown1 = CreateFrame("Frame", "ATMSoundDropdown1", scrollChild, "UIDropDownMenuTemplate")
soundDropdown1:SetPoint("TOPLEFT", 310, -157)
UIDropDownMenu_SetWidth(soundDropdown1, 180)

UIDropDownMenu_Initialize(soundDropdown1, function(self, level)
    for _, s in ipairs(AVAILABLE_SOUNDS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = s.name
        info.value = s.value
        info.func = function(self)
            ATM_Settings.alertSound = self.value
            UIDropDownMenu_SetSelectedValue(soundDropdown1, self.value)
            UIDropDownMenu_SetText(soundDropdown1, s.name)
            PlayCustomSound(self.value)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

local soundHeader2 = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
soundHeader2:SetPoint("TOPLEFT", 320, -205)
soundHeader2:SetText("Sound: Tank Aggro verloren")

local soundDropdown2 = CreateFrame("Frame", "ATMSoundDropdown2", scrollChild, "UIDropDownMenuTemplate")
soundDropdown2:SetPoint("TOPLEFT", 310, -222)
UIDropDownMenu_SetWidth(soundDropdown2, 180)

UIDropDownMenu_Initialize(soundDropdown2, function(self, level)
    for _, s in ipairs(AVAILABLE_SOUNDS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = s.name
        info.value = s.value
        info.func = function(self)
            ATM_Settings.tankLostSound = self.value
            UIDropDownMenu_SetSelectedValue(soundDropdown2, self.value)
            UIDropDownMenu_SetText(soundDropdown2, s.name)
            PlayCustomSound(self.value)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

local soundHeader3 = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
soundHeader3:SetPoint("TOPLEFT", 320, -270)
soundHeader3:SetText("Sound: Interrupt Erfolg")

local soundDropdown3 = CreateFrame("Frame", "ATMSoundDropdown3", scrollChild, "UIDropDownMenuTemplate")
soundDropdown3:SetPoint("TOPLEFT", 310, -287)
UIDropDownMenu_SetWidth(soundDropdown3, 180)

UIDropDownMenu_Initialize(soundDropdown3, function(self, level)
    for _, s in ipairs(AVAILABLE_SOUNDS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = s.name
        info.value = s.value
        info.func = function(self)
            ATM_Settings.interruptSound = self.value
            UIDropDownMenu_SetSelectedValue(soundDropdown3, self.value)
            UIDropDownMenu_SetText(soundDropdown3, s.name)
            PlayCustomSound(self.value)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

optionsPanel:SetScript("OnShow", function()
    if ATM_Settings.language == "EN" then
        cbDE:SetChecked(false)
        cbEN:SetChecked(true)
    else
        cbDE:SetChecked(true)
        cbEN:SetChecked(false)
    end

    cbMove:SetChecked(isUnlockedForMoving)
    sliderThreatW:SetValue(ATM_Settings.threatWidth)
    sliderThreatH:SetValue(ATM_Settings.threatHeight)
    sliderFont:SetValue(ATM_Settings.fontSize)
    if sliderMinimapAngle then
        sliderMinimapAngle:SetValue(ATM_Settings.minimapPos or 45)
    end
    UIDropDownMenu_SetSelectedValue(iconDropdown, ATM_Settings.marker)
    UIDropDownMenu_SetText(iconDropdown, iconNames[ATM_Settings.marker] or "")

    local function GetSkinName(val)
        for _, sk in ipairs(AVAILABLE_SKINS) do
            if sk.value == val then return sk.name end
        end
        return "Neon Cyber (Leuchtend)"
    end
    UIDropDownMenu_SetSelectedValue(skinDropdown, ATM_Settings.barSkin or "NEON")
    UIDropDownMenu_SetText(skinDropdown, GetSkinName(ATM_Settings.barSkin or "NEON"))

    local function GetSoundName(val)
        for _, s in ipairs(AVAILABLE_SOUNDS) do
            if s.value == val or tostring(s.value) == tostring(val) then return s.name end
        end
        return "Aus (Kein Ton)"
    end

    UIDropDownMenu_SetSelectedValue(soundDropdown1, ATM_Settings.alertSound)
    UIDropDownMenu_SetText(soundDropdown1, GetSoundName(ATM_Settings.alertSound))

    UIDropDownMenu_SetSelectedValue(soundDropdown2, ATM_Settings.tankLostSound)
    UIDropDownMenu_SetText(soundDropdown2, GetSoundName(ATM_Settings.tankLostSound))

    UIDropDownMenu_SetSelectedValue(soundDropdown3, ATM_Settings.interruptSound)
    UIDropDownMenu_SetText(soundDropdown3, GetSoundName(ATM_Settings.interruptSound))
end)

InterfaceOptions_AddCategory(optionsPanel)

-- SLASH COMMANDS
SLASH_AUTOTANK1 = "/autotank"
SLASH_AUTOTANK2 = "/atm"
SlashCmdList["AUTOTANK"] = function(msg)
    local cmd, arg = msg:match("^(%S+)%s*(.-)$")
    cmd = (cmd or msg):lower():trim()
    
    if cmd == "config" or cmd == "opt" or cmd == "options" then
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
    elseif cmd == "test" then
        RunTestMode()
    elseif cmd == "pos" then
        local val = tonumber(arg)
        if val then
            ATM_Settings.minimapPos = val
            UpdateMinimapButtonPosition(val)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[ATM]|r Minimap-Position auf %d° gesetzt.", val))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[ATM]|r Bitte gib einen Winkel an (z.B. /atm pos 90).")
        end
    else
        FindAndMarkTank()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM v1.77]|r Tank-Suche ausgeführt. Tippe |cffffd100/atm config|r für Einstellungen.")
    end
end