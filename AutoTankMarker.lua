local frame = CreateFrame("Frame")

-- Standard-Einstellungen
ATM_Settings = ATM_Settings or {
    marker = 6,           -- Default: Blaues Quadrat
    autoFocus = true,     -- Auto-Fokus an/aus
    aggroAlert = true,    -- Aggro-Warnung an/aus
    manaWhisper = true,   -- Whisper an Tank bei Low Mana an/aus
    drinkWhisper = true,  -- Whisper an Tank beim Trinken an/aus
    tankDeathSound = true,-- Sound & Warnung wenn Tank stirbt
    tankHealthAlert = true,-- Warnung bei < 25% Tank HP
    tankDefAlert = true,  -- Warnung wenn Tank Def-CDs zündet
    language = "DE"       -- Standard auf "DE" für Deutsch gesetzt
}

local lastChatAlert = 0
local lastManaWhisper = 0
local lastDrinkWhisper = 0
local lastHealthAlert = 0
local CHAT_ALERT_COOLDOWN = 10 
local MANA_WHISPER_COOLDOWN = 30
local currentTankUnit = nil

-------------------------------------------------------------------------------
-- WARNBALKEN (GUI FRAME)
-------------------------------------------------------------------------------
local warnFrame = CreateFrame("Frame", "ATMWarnFrame", UIParent)
warnFrame:SetSize(380, 42)
warnFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
warnFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 0, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
warnFrame:Hide()

local warnText = warnFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
warnText:SetPoint("CENTER", warnFrame, "CENTER", 0, 0)

local warnTimer = 0
warnFrame:SetScript("OnUpdate", function(self, elapsed)
    if warnTimer > 0 then
        warnTimer = warnTimer - elapsed
        if warnTimer <= 0 then
            self:Hide()
        elseif warnTimer < 0.5 then
            self:SetAlpha(warnTimer / 0.5) -- Sanftes Ausblenden
        end
    end
end)

local function ShowBannerMessage(message, r, g, b, duration)
    warnText:SetText(message)
    warnFrame:SetBackdropColor(r * 0.2, g * 0.2, b * 0.2, 0.85) -- Dunkler Hintergrund
    warnFrame:SetBackdropBorderColor(r, g, b, 1.0)              -- Farbiger Rahmen
    warnFrame:SetAlpha(1.0)
    warnTimer = duration or 3.0
    warnFrame:Show()
end

-- Liste großer Tank-Defensiv-Cooldowns (Spell ID -> { Name, Dauer })
local TANK_DEF_SPELLS = {
    -- Krieger
    [871]   = { name = "Schildwall / Shield Wall", duration = 12 },
    [12975] = { name = "Letztes Gefecht / Last Stand", duration = 20 },
    -- Paladin
    [498]   = { name = "Göttlicher Schutz / Divine Protection", duration = 12 },
    [31850] = { name = "Unermüdlicher Hüter / Ardent Defender", duration = 10 },
    -- Todesritter
    [48792] = { name = "Eisige Gegenwehr / Icebound Fortitude", duration = 12 },
    [55233] = { name = "Vampirblut / Vampiric Blood", duration = 10 },
    [49028] = { name = "Tanzende Runenwaffe / Dancing Rune Weapon", duration = 12 },
    -- Druide
    [61336] = { name = "Überlebensinstinkte / Survival Instincts", duration = 20 },
    [22812] = { name = "Baumrinde / Barkskin", duration = 12 }
}

-- Übersetzungstexte (Kompatibel mit dem WoW-Chat ohne Emojis)
local L = {
    EN = {
        aggroChat = "[AGGRO] >>> Aggro on Healer %s! Please taunt! <<<",
        aggroScreen = ">>> AGGRO ON HEALER! <<<",
        oom = "[ATM] OOM / Low Mana! Careful!",
        drinking = "[ATM] Is drinking (Mana: %d%%) - Please wait!",
        tankDied = ">>> TANK DIED! <<<",
        tankLow = ">>> TANK LOW HEALTH (%d%%)! <<<",
        defCD = "Tank CD: %s (%ds)"
    },
    DE = {
        aggroChat = "[AGGRO] >>> Aggro auf Heiler %s! Bitte abspotten! <<<",
        aggroScreen = ">>> AGGRO AUF HEILER! <<<",
        oom = "[ATM] OOM / Wenig Mana! Vorsicht!",
        drinking = "[ATM] Trinkt gerade (Mana: %d%%) - Bitte warten!",
        tankDied = ">>> TANK GESTORBEN! <<<",
        tankLow = ">>> TANK WENIG LEBEN (%d%%)! <<<",
        defCD = "Tank CD: %s (%ds)"
    }
}

-- Hilfsfunktion: Prüft Buffs/Auren/Haltungen auf der Unit
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

-- Tank suchen und markieren
local function FindAndMarkTank()
    if not GetNumPartyMembers() or GetNumPartyMembers() == 0 then
        currentTankUnit = nil
        return
    end

    local targetUnit = nil

    -- 1. LFG Rolle
    for i = 1, GetNumPartyMembers() do
        local unit = "party" .. i
        if UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "TANK" then
            targetUnit = unit
            break
        end
    end

    -- 2. Buff/Stance-Scan
    if not targetUnit then
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            if IsTankActive(unit) then
                targetUnit = unit
                break
            end
        end
    end

    -- 3. Fallback: Erster Tank-Charakter
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

    currentTankUnit = targetUnit

    if targetUnit then
        if GetRaidTargetIndex(targetUnit) ~= ATM_Settings.marker then
            SetRaidTarget(targetUnit, ATM_Settings.marker)
        end
        if ATM_Settings.autoFocus and not InCombatLockdown() then
            FocusUnit(targetUnit)
        end
    end
end

-- Aggro-Prüfung (Verlässlicher All-in-One Scan für 3.3.5a)
local function CheckThreatStatus()
    if not ATM_Settings.aggroAlert or not InCombatLockdown() then return end

    local hasAggro = false

    -- 1. Direktabfrage: Hat der Spieler generell Aggro?
    local globalStatus = UnitThreatSituation("player")
    if globalStatus and globalStatus >= 2 then
        hasAggro = true
    end

    -- 2. Fallback: Detaillierte Abfragen auf typische Gegner-Units
    if not hasAggro then
        local unitsToScan = { "focustarget", "target", "targettarget", "mouseover" }
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

    -- Alarm auslösen
    if hasAggro then
        local now = GetTime()
        if (now - lastChatAlert) > CHAT_ALERT_COOLDOWN then
            lastChatAlert = now
            PlaySound("RaidWarning")
            
            local lang = ATM_Settings.language or "DE"
            
            -- Warnbalken Anzeige (Roter Balken)
            ShowBannerMessage(L[lang].aggroScreen, 1.0, 0.1, 0.1, 3.5)

            -- Chat-Anzeige
            local text = string.format(L[lang].aggroChat, UnitName("player"))
            local chatType = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
            if chatType then SendChatMessage(text, chatType) end
        end
    end
end

-- Statusprüfung (Mana, Drink, Tank Health)
local function CheckStatus()
    local lang = ATM_Settings.language or "DE"

    -- Low Mana Whisper an Tank (< 15%)
    if ATM_Settings.manaWhisper and currentTankUnit and UnitExists(currentTankUnit) and InCombatLockdown() then
        if UnitPowerType("player") == 0 then -- Mana
            local maxMana = UnitPowerMax("player")
            local currMana = UnitPower("player")
            if maxMana > 0 and (currMana / maxMana) < 0.15 then
                local now = GetTime()
                if (now - lastManaWhisper) > MANA_WHISPER_COOLDOWN then
                    lastManaWhisper = now
                    local tankName = UnitName(currentTankUnit)
                    if tankName then
                        SendChatMessage(L[lang].oom, "WHISPER", nil, tankName)
                    end
                end
            end
        end
    end

    -- Trink-Aura / Drink-Check
    if ATM_Settings.drinkWhisper and currentTankUnit and UnitExists(currentTankUnit) then
        for i = 1, 40 do
            local name = UnitBuff("player", i)
            if name and (name:find("Drink") or name:find("Trinken")) then
                local now = GetTime()
                if (now - lastDrinkWhisper) > 15 then
                    lastDrinkWhisper = now
                    local tankName = UnitName(currentTankUnit)
                    local manaPct = math.floor((UnitPower("player") / UnitPowerMax("player")) * 100)
                    if tankName then
                        SendChatMessage(string.format(L[lang].drinking, manaPct), "WHISPER", nil, tankName)
                    end
                end
                break
            end
        end
    end

    -- Tank Low Health Alert (< 25%)
    if ATM_Settings.tankHealthAlert and currentTankUnit and UnitExists(currentTankUnit) and InCombatLockdown() then
        local hp = UnitHealth(currentTankUnit)
        local maxHp = UnitHealthMax(currentTankUnit)
        if maxHp > 0 then
            local pct = math.floor((hp / maxHp) * 100)
            if pct < 25 and hp > 0 then
                local now = GetTime()
                if (now - lastHealthAlert) > 10 then
                    lastHealthAlert = now
                    PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
                    ShowBannerMessage(string.format(L[lang].tankLow, pct), 1.0, 0.3, 0.0, 3.0)
                end
            end
        end
    end
end

-- TESTER FUNKTION (Zeigt den neuen Warnbalken)
local function RunTestMode()
    local lang = ATM_Settings.language or "DE"
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM TEST]|r Starte Test mit neuem Warnbalken...")

    -- 1. Aggro Simulation (Roter Balken)
    PlaySound("RaidWarning")
    ShowBannerMessage(L[lang].aggroScreen, 1.0, 0.1, 0.1, 2.5)
    
    local text = string.format(L[lang].aggroChat, UnitName("player"))
    local chatType = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
    
    if chatType then 
        SendChatMessage(text, chatType) 
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM TEST]|r Aggro-Meldung gesendet an: " .. chatType)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[ATM TEST]|r Einzeltest - Chat-Text wäre: " .. text)
    end

    -- 2. Simulation weiterer Warnbalken
    local testTimer = CreateFrame("Frame")
    local step = 0
    testTimer:SetScript("OnUpdate", function(self, elapsed)
        step = step + elapsed
        if step > 2.0 and step < 2.1 then
            -- Defensiv CD Test (Grüner Balken)
            ShowBannerMessage(string.format(L[lang].defCD, "Schildwall", 12), 0.0, 1.0, 0.2, 2.5)
        elseif step > 4.0 and step < 4.1 then
            -- Tank Low Health Test (Orangener Balken)
            ShowBannerMessage(string.format(L[lang].tankLow, 18), 1.0, 0.4, 0.0, 2.5)
        elseif step > 6.0 and step < 6.1 then
            -- Tank Tod Test (Dunkelroter Balken)
            ShowBannerMessage(L[lang].tankDied, 0.8, 0.0, 0.0, 3.0)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM TEST]|r Balken-Test abgeschlossen!")
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- Events
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
    
    if event == "UNIT_THREAT_LIST_UPDATE" or event == "PLAYER_REGEN_DISABLED" then
        CheckThreatStatus()
    elseif event == "UNIT_AURA" or event == "UNIT_HEALTH" or event == "UNIT_MANA" then
        CheckStatus()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID = ...
        
        -- Tank Death Alert
        if ATM_Settings.tankDeathSound and currentTankUnit then
            if subEvent == "UNIT_DIED" and destGUID == UnitGUID(currentTankUnit) then
                PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
                ShowBannerMessage(L[lang].tankDied, 0.8, 0.0, 0.0, 4.0)
            end
        end

        -- Tank Defensiv CD Alert
        if ATM_Settings.tankDefAlert and currentTankUnit and subEvent == "SPELL_CAST_SUCCESS" then
            if sourceGUID == UnitGUID(currentTankUnit) and TANK_DEF_SPELLS[spellID] then
                local cdInfo = TANK_DEF_SPELLS[spellID]
                PlaySound("3337") -- Interface-Sound
                ShowBannerMessage(string.format(L[lang].defCD, cdInfo.name, cdInfo.duration), 0.0, 1.0, 0.2, 3.5)
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
-- OPTIONS PANEL (INTERFACE-MENÜ)
-------------------------------------------------------------------------------
local optionsPanel = CreateFrame("Frame", "AutoTankMarkerOptionsPanel", UIParent)
optionsPanel.name = "AutoTankMarker"

local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("AutoTankMarker - Einstellungen")

local function CreateCheckbox(name, labelText, yOffset, settingKey)
    local cb = CreateFrame("CheckButton", name, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, yOffset)
    _G[cb:GetName() .. "Text"]:SetText(labelText)
    cb:SetScript("OnShow", function(self) self:SetChecked(ATM_Settings[settingKey]) end)
    cb:SetScript("OnClick", function(self) ATM_Settings[settingKey] = self:GetChecked() end)
    return cb
end

CreateCheckbox("ATM_CB_AutoFocus", "Tank als Fokus-Ziel setzen (außerhalb Kampf)", -45, "autoFocus")
CreateCheckbox("ATM_CB_AggroAlert", "Aggro-Warnung & Chat-Meldung senden", -70, "aggroAlert")
CreateCheckbox("ATM_CB_ManaWhisper", "Flüstern bei < 15% Mana an Tank", -95, "manaWhisper")
CreateCheckbox("ATM_CB_DrinkWhisper", "Flüstern an Tank wenn du trinkst", -120, "drinkWhisper")
CreateCheckbox("ATM_CB_TankHealth", "Warnung wenn Tank unter 25% Leben fällt", -145, "tankHealthAlert")
CreateCheckbox("ATM_CB_TankDeath", "Sound & Meldung wenn Tank stirbt", -170, "tankDeathSound")
CreateCheckbox("ATM_CB_TankDef", "Meldung wenn Tank Defensiv-CDs zündet", -195, "tankDefAlert")

-- SPRACH-EINSTELLUNG: CHECKBOXEN (DE / ENG)
local langHeader = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
langHeader:SetPoint("TOPLEFT", 16, -230)
langHeader:SetText("Sprache für Chat & Warnungen:")

local cbDE = CreateFrame("CheckButton", "ATM_CB_LangDE", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
cbDE:SetPoint("TOPLEFT", 16, -250)
_G[cbDE:GetName() .. "Text"]:SetText("Deutsch (DEU)")

local cbEN = CreateFrame("CheckButton", "ATM_CB_LangEN", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
cbEN:SetPoint("TOPLEFT", 150, -250)
_G[cbEN:GetName() .. "Text"]:SetText("Englisch (ENG)")

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

-- Dropdown Symbol-Auswahl
local iconHeader = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
iconHeader:SetPoint("TOPLEFT", 16, -285)
iconHeader:SetText("Tank-Symbol auswählen:")

local iconDropdown = CreateFrame("Frame", "ATMIconDropdown", optionsPanel, "UIDropDownMenuTemplate")
iconDropdown:SetPoint("TOPLEFT", 6, -305)
local iconNames = { [1]="1 - Stern", [2]="2 - Kreis", [3]="3 - Diamant", [4]="4 - Dreieck", [5]="5 - Mond", [6]="6 - Quadrat", [7]="7 - Kreuz", [8]="8 - Totenkopf" }

UIDropDownMenu_Initialize(iconDropdown, function(self, level)
    for id, name in ipairs(iconNames) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = name; info.value = id
        info.func = function(self)
            ATM_Settings.marker = self.value
            UIDropDownMenu_SetSelectedValue(iconDropdown, self.value)
            FindAndMarkTank()
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

    UIDropDownMenu_SetSelectedValue(iconDropdown, ATM_Settings.marker)
    UIDropDownMenu_SetText(iconDropdown, iconNames[ATM_Settings.marker] or "")
end)

InterfaceOptions_AddCategory(optionsPanel)

-- SLASH COMMANDS
SLASH_AUTOTANK1 = "/autotank"
SLASH_AUTOTANK2 = "/atm"
SlashCmdList["AUTOTANK"] = function(msg)
    local cmd = msg:lower():trim()
    if cmd == "config" or cmd == "opt" or cmd == "options" then
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
    elseif cmd == "test" then
        RunTestMode()
    else
        FindAndMarkTank()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Tank-Suche ausgeführt. Tippe |cffffd100/atm config|r für Einstellungen oder |cffffd100/atm test|r zum Testen.")
    end
end