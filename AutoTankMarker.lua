local frame = CreateFrame("Frame")

-- Standard-Einstellungen (v1.9.12)
ATM_Settings = ATM_Settings or {
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
    showTankSwap = true,
    showInterrupt = true,
    language = "DE",
    threatWidth = 250,
    threatHeight = 26,
    cdWidth = 250,
    cdHeight = 18,
    threatX = 0,
    threatY = -120,
    cdX = 0,
    cdY = -155,
    warnX = 0,
    warnY = 180,
    fontSize = 12,
}

local lastChatAlert = 0
local lastManaWhisper = 0
local lastDrinkWhisper = 0
local lastHealthAlert = 0
local CHAT_ALERT_COOLDOWN = 10 
local MANA_WHISPER_COOLDOWN = 30
local currentTankUnit = nil
local isTestingMode = false
local isUnlockedForMoving = false

-------------------------------------------------------------------------------
-- DESIGN IM "TANK GESTORBEN"-STYLE (ROT & ULTRA LESBAR)
-------------------------------------------------------------------------------
local threatText, cdText
local threatBackdrop, cdBackdrop

local function UpdateBarStyles()
    local fSize = ATM_Settings.fontSize or 12

    if threatBackdrop then
        threatBackdrop:SetBackdropColor(0.2, 0.0, 0.0, 0.95)
        threatBackdrop:SetBackdropBorderColor(1.0, 0.1, 0.1, 1.0)
    end
    if cdBackdrop then
        cdBackdrop:SetBackdropColor(0.2, 0.0, 0.0, 0.95)
        cdBackdrop:SetBackdropBorderColor(1.0, 0.1, 0.1, 1.0)
    end

    if threatText then
        threatText:SetFont("Fonts\\FRIZQT__.TTF", fSize, "OUTLINE")
        threatText:SetTextColor(1.0, 1.0, 1.0, 1.0)
    end
    if cdText then
        cdText:SetFont("Fonts\\FRIZQT__.TTF", fSize, "OUTLINE")
        cdText:SetTextColor(1.0, 1.0, 1.0, 1.0)
    end
end

-------------------------------------------------------------------------------
-- WARNBALKEN (BANNER FRAME - JETZT AUCH VERSCHIEBBAR)
-------------------------------------------------------------------------------
local warnFrame = CreateFrame("Frame", "ATMWarnFrame", UIParent)
warnFrame:SetSize(380, 42)
warnFrame:SetPoint("CENTER", UIParent, "CENTER", ATM_Settings.warnX or 0, ATM_Settings.warnY or 180)
warnFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 0, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
warnFrame:Hide()

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

local warnText = warnFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
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
    warnText:SetText(message)
    warnFrame:SetBackdropColor(0.2, 0.0, 0.0, 0.95)
    warnFrame:SetBackdropBorderColor(r, g, b, 1.0)
    warnFrame:SetAlpha(1.0)
    warnTimer = duration or 3.0
    warnFrame:Show()
end

-------------------------------------------------------------------------------
-- TANK AGGRO PROZENT-LEISTE
-------------------------------------------------------------------------------
local threatBar = CreateFrame("StatusBar", "ATMTankThreatBar", UIParent)
threatBar:SetSize(ATM_Settings.threatWidth, ATM_Settings.threatHeight)
threatBar:SetPoint("CENTER", UIParent, "CENTER", ATM_Settings.threatX, ATM_Settings.threatY)
threatBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
threatBar:SetMinMaxValues(0, 100)
threatBar:SetValue(0)
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
threatBackdrop:SetBackdropColor(0.2, 0.0, 0.0, 0.95)
threatBackdrop:SetBackdropBorderColor(1.0, 0.1, 0.1, 1.0)

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
    if isTestingMode or isUnlockedForMoving then return end

    threatTimer = threatTimer + elapsed
    if threatTimer > 0.15 then
        threatTimer = 0
        
        if not ATM_Settings.showTankThreatBar or not InCombatLockdown() then
            self:Hide()
            return
        end

        local mobUnit = nil
        if UnitExists("target") and UnitCanAttack("player", "target") then
            mobUnit = "target"
        elseif UnitExists("targettarget") and UnitCanAttack("player", "targettarget") then
            mobUnit = "targettarget"
        elseif currentTankUnit and UnitExists(currentTankUnit .. "target") and UnitCanAttack("player", currentTankUnit .. "target") then
            mobUnit = currentTankUnit .. "target"
        elseif UnitExists("focustarget") and UnitCanAttack("player", "focustarget") then
            mobUnit = "focustarget"
        end

        if mobUnit then
            local pct = nil
            local tankUnit = currentTankUnit or "player"

            local _, _, threatpct = UnitDetailedThreatSituation("player", mobUnit)
            if threatpct then
                pct = math.floor(threatpct)
            else
                local tankStatus = UnitThreatSituation(tankUnit, mobUnit)
                if tankStatus == 3 then pct = 100 
                elseif tankStatus == 2 then pct = 80  
                elseif tankStatus == 1 then pct = 60  
                elseif tankStatus == 0 then pct = 30  
                end
            end

            if pct and pct > 0 then
                self:Show()
                self:SetValue(pct)
                threatText:SetText(string.format("Tank Aggro: %d%%", pct))
                threatText:SetTextColor(1.0, 1.0, 1.0, 1.0)

                if pct >= 100 then
                    self:SetStatusBarColor(0.0, 0.8, 0.2) 
                elseif pct >= 80 then
                    self:SetStatusBarColor(1.0, 0.8, 0.0) 
                else
                    self:SetStatusBarColor(0.9, 0.1, 0.1) 
                end
            else
                local globalStatus = UnitThreatSituation("player")
                if globalStatus and globalStatus > 0 then
                    self:Show()
                    self:SetValue(globalStatus == 3 and 100 or (globalStatus == 2 and 80 or 50))
                    threatText:SetText("Aggro im Kampf!")
                    threatText:SetTextColor(1.0, 1.0, 1.0, 1.0)
                    self:SetStatusBarColor(0.9, 0.1, 0.1)
                else
                    self:Hide()
                end
            end
        else
            self:Hide()
        end
    end
end)

-------------------------------------------------------------------------------
-- INTELLIGENTER CD-MONITOR
-------------------------------------------------------------------------------
local cdBar = CreateFrame("StatusBar", "ATMCdBar", UIParent)
cdBar:SetSize(ATM_Settings.cdWidth, ATM_Settings.cdHeight)
cdBar:SetPoint("CENTER", UIParent, "CENTER", ATM_Settings.cdX, ATM_Settings.cdY)
cdBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
cdBar:SetStatusBarColor(0.2, 0.0, 0.0, 0.95)
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
cdBackdrop:SetBackdropColor(0.2, 0.0, 0.0, 0.95)
cdBackdrop:SetBackdropBorderColor(1.0, 0.1, 0.1, 1.0)

local cdTextContainer = CreateFrame("Frame", nil, cdBar)
cdTextContainer:SetAllPoints(cdBar)
cdTextContainer:SetFrameLevel(cdBar:GetFrameLevel() + 15)

cdText = cdTextContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
cdText:SetPoint("CENTER", cdTextContainer, "CENTER", 0, 0)
cdText:SetFont("Fonts\\FRIZQT__.TTF", ATM_Settings.fontSize, "OUTLINE")
cdText:SetTextColor(1.0, 1.0, 1.0, 1.0)
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
    if not ATM_Settings.showCDMonitor then return end
    UpdateBarStyles()
    cdBar:Show()
    local totalTime = duration or 12
    cdBar:SetMinMaxValues(0, totalTime)
    
    local timeLeft = totalTime
    cdText:SetText(string.format(">> %s: %s <<", tankName, spellName))
    cdText:SetTextColor(1.0, 1.0, 1.0, 1.0)
    cdBar:SetStatusBarColor(1.0, 0.5, 0.0)
    
    if cdBar.timerScript then cdBar:SetScript("OnUpdate", nil) end
    cdBar:SetScript("OnUpdate", function(f, el)
        if isUnlockedForMoving then return end
        timeLeft = timeLeft - el
        f:SetValue(timeLeft)
        if timeLeft <= 0 then
            f:Hide()
            f:SetScript("OnUpdate", nil)
            cdText:SetText("Kein aktiver Def-CD")
            cdText:SetTextColor(1.0, 1.0, 1.0, 1.0)
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

local L = {
    EN = {
        aggroChat = "[AGGRO] >>> Aggro on Healer %s! Please taunt! <<<",
        aggroScreen = ">>> AGGRO ON HEALER! <<<",
        oom = "[ATM] OOM / Low Mana! Careful!",
        drinking = "[ATM] Is drinking (Mana: %d%%) - Please wait!",
        tankDied = ">>> TANK DIED! <<<",
        tankLow = ">>> TANK LOW HEALTH (%d%%)! <<<",
        defCD = ">> Tank CD: %s (%ds) <<",
        tauntFail = ">>> TAUNT FAILED (%s) on %s! <<<",
        tankSwap = ">> Taunt-Swap: %s -> %s <<",
        interrupt = ">> Interrupt: %s (%s gekickt) <<"
    },
    DE = {
        aggroChat = "[AGGRO] >>> Aggro auf Heiler %s! Bitte abspotten! <<<",
        aggroScreen = ">>> AGGRO AUF HEILER! <<<",
        oom = "[ATM] OOM / Wenig Mana! Vorsicht!",
        drinking = "[ATM] Trinkt gerade (Mana: %d%%) - Bitte warten!",
        tankDied = ">>> TANK GESTORBEN! <<<",
        tankLow = ">>> TANK WENIG LEBEN (%d%%)! <<<",
        defCD = ">> Tank CD: %s (%ds) <<",
        tauntFail = ">>> SPOTT VERFEHLT (%s) auf %s! <<<",
        tankSwap = ">> Taunt-Swap: %s -> %s <<",
        interrupt = ">> Interrupt: %s (%s gekickt) <<"
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
    if not GetNumPartyMembers() or GetNumPartyMembers() == 0 then
        currentTankUnit = nil
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

    currentTankUnit = targetUnit
    if targetUnit then
        if GetRaidTargetIndex(targetUnit) ~= ATM_Settings.marker then
            SetRaidTarget(targetUnit, ATM_Settings.marker)
        end
    end
end

local function CheckThreatStatus()
    if not ATM_Settings.aggroAlert or not InCombatLockdown() then return end
    local hasAggro = false

    local globalStatus = UnitThreatSituation("player")
    if globalStatus and globalStatus >= 2 then hasAggro = true end

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

    if hasAggro then
        local now = GetTime()
        if (now - lastChatAlert) > CHAT_ALERT_COOLDOWN then
            lastChatAlert = now
            PlaySound("RaidWarning")
            local lang = ATM_Settings.language or "DE"
            ShowBannerMessage(L[lang].aggroScreen, 1.0, 0.1, 0.1, 3.5)
            local text = string.format(L[lang].aggroChat, UnitName("player"))
            local chatType = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
            if chatType then SendChatMessage(text, chatType) end
        end
    end
end

local function CheckStatus()
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
                    PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
                    ShowBannerMessage(string.format(L[lang].tankLow, pct), 1.0, 0.3, 0.0, 3.0)
                end
            end
        end
    end
end

local function RunTestMode()
    local lang = ATM_Settings.language or "DE"
    isTestingMode = true
    UpdateBarStyles()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM TEST]|r Starte Testmodus v1.9.12...")

    PlaySound("RaidWarning")
    ShowBannerMessage(L[lang].aggroScreen, 1.0, 0.1, 0.1, 2.5)
    
    threatBar:Show()
    threatBar:SetValue(85)
    threatBar:SetStatusBarColor(1.0, 0.8, 0.0)
    threatText:SetText("Tank Aggro: 85% (Test)")
    threatText:SetTextColor(1.0, 1.0, 1.0, 1.0)

    UpdateCDMonitorDisplay("TestTank", "Schildwall", 12)
    
    local text = string.format(L[lang].aggroChat, UnitName("player"))
    local chatType = GetNumRaidMembers() > 0 and "RAID" or (GetNumPartyMembers() > 0 and "PARTY" or nil)
    if chatType then SendChatMessage(text, chatType) end

    local testTimer = CreateFrame("Frame")
    local step = 0
    testTimer:SetScript("OnUpdate", function(self, elapsed)
        step = step + elapsed
        if step > 2.5 and step < 2.6 then
            threatBar:SetValue(100)
            threatBar:SetStatusBarColor(0.0, 0.8, 0.2)
            threatText:SetText("Tank Aggro: 100%")
            threatText:SetTextColor(1.0, 1.0, 1.0, 1.0)
            ShowBannerMessage(string.format(L[lang].defCD, "Schildwall", 12), 0.0, 1.0, 0.2, 2.5)
        elseif step > 5.0 and step < 5.1 then
            ShowBannerMessage(string.format(L[lang].tauntFail, "Spott", "Mob"), 1.0, 0.0, 0.0, 2.5)
            PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
        elseif step > 7.5 and step < 7.6 then
            ShowBannerMessage(string.format(L[lang].tankSwap, "Tank1", "Tank2"), 0.0, 0.8, 1.0, 2.5)
        elseif step > 10.0 and step < 10.1 then
            ShowBannerMessage(string.format(L[lang].interrupt, "Spieler", "Feuerball"), 1.0, 0.5, 0.0, 2.5)
        elseif step > 12.5 and step < 12.6 then
            ShowBannerMessage(L[lang].tankDied, 0.8, 0.0, 0.0, 3.0)
            if not isUnlockedForMoving then threatBar:Hide() cdBar:Hide() warnFrame:Hide() end
            isTestingMode = false
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM TEST]|r Test beendet.")
            self:SetScript("OnUpdate", nil)
        end
    end)
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
        end
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "PLAYER_REGEN_DISABLED" then
        CheckThreatStatus()
    elseif event == "UNIT_AURA" or event == "UNIT_HEALTH" or event == "UNIT_MANA" then
        CheckStatus()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subEvent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName, _, extraArg1, extraArg2 = ...
        
        if ATM_Settings.tankDeathSound and currentTankUnit then
            if subEvent == "UNIT_DIED" and destGUID == UnitGUID(currentTankUnit) then
                PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
                ShowBannerMessage(L[lang].tankDied, 0.8, 0.0, 0.0, 4.0)
            end
        end

        if ATM_Settings.tauntAlert and currentTankUnit then
            if subEvent == "SPELL_MISSED" and (sourceGUID == UnitGUID(currentTankUnit) or (sourceName and sourceName == UnitName(currentTankUnit))) then
                if TAUNT_SPELLS[spellID] or TAUNT_SPELLS[spellName] then
                    local spellUsed = TAUNT_SPELLS[spellID] or TAUNT_SPELLS[spellName]
                    local targetMob = destName or "Gegner"
                    PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
                    ShowBannerMessage(string.format(L[lang].tauntFail, spellUsed, targetMob), 1.0, 0.1, 0.1, 3.5)
                end
            end
        end

        if ATM_Settings.tankDefAlert then
            if (subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_AURA_APPLIED") then
                local cdInfo = TANK_DEF_SPELLS[spellID] or TANK_DEF_SPELLS[spellName]
                if cdInfo then
                    PlaySound("3337")
                    ShowBannerMessage(string.format(L[lang].defCD, cdInfo.name, cdInfo.duration), 0.0, 1.0, 0.2, 3.5)
                    if ATM_Settings.showCDMonitor then
                        UpdateCDMonitorDisplay(sourceName or "Tank", cdInfo.name, cdInfo.duration)
                    end
                end
            end
        end

        if ATM_Settings.showTankSwap and subEvent == "SPELL_CAST_SUCCESS" then
            if TAUNT_SPELLS[spellID] or TAUNT_SPELLS[spellName] then
                if sourceName and destName then
                    ShowBannerMessage(string.format(L[lang].tankSwap, sourceName, destName), 0.0, 0.8, 1.0, 3.0)
                end
            end
        end

        if ATM_Settings.showInterrupt and subEvent == "SPELL_INTERRUPT" then
            local interruptedSpell = extraArg2 or "Zauber"
            ShowBannerMessage(string.format(L[lang].interrupt, sourceName or "Spieler", interruptedSpell), 1.0, 0.5, 0.0, 3.0)
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
-- OPTIONS PANEL (GUI)
-------------------------------------------------------------------------------
local optionsPanel = CreateFrame("Frame", "AutoTankMarkerOptionsPanel", UIParent)
optionsPanel.name = "AutoTankMarker"

local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("AutoTankMarker v1.9.12 - Einstellungen")

local function CreateCheckbox(name, labelText, yOffset, settingKey)
    local cb = CreateFrame("CheckButton", name, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, yOffset)
    _G[cb:GetName() .. "Text"]:SetText(labelText)
    cb:SetScript("OnShow", function(self) self:SetChecked(ATM_Settings[settingKey]) end)
    cb:SetScript("OnClick", function(self) ATM_Settings[settingKey] = self:GetChecked() end)
    return cb
end

CreateCheckbox("ATM_CB_AggroAlert", "Aggro-Warnung & Chat-Meldung senden", -45, "aggroAlert")
CreateCheckbox("ATM_CB_ThreatBar", "Tank-Aggro Prozentleiste im Kampf anzeigen", -70, "showTankThreatBar")
CreateCheckbox("ATM_CB_CDMonitor", "Intelligenter CD-Monitor (Statusleiste) anzeigen", -95, "showCDMonitor")
CreateCheckbox("ATM_CB_TankSwap", "Tank-Wechsel (Taunt-Swap) Ansage", -120, "showTankSwap")
CreateCheckbox("ATM_CB_Interrupt", "Interrupt & CC-Tracker aktivieren", -145, "showInterrupt")
CreateCheckbox("ATM_CB_ManaWhisper", "Flüstern bei < 15% Mana an Tank", -170, "manaWhisper")
CreateCheckbox("ATM_CB_DrinkWhisper", "Flüstern an Tank wenn du trinkst", -195, "drinkWhisper")
CreateCheckbox("ATM_CB_TankHealth", "Warnung wenn Tank unter 25% Leben fällt", -220, "tankHealthAlert")
CreateCheckbox("ATM_CB_TankDeath", "Sound & Meldung wenn Tank stirbt", -245, "tankDeathSound")
CreateCheckbox("ATM_CB_TankDef", "Meldung wenn Tank Defensiv-CDs zündet", -270, "tankDefAlert")
CreateCheckbox("ATM_CB_TauntAlert", "Warnung wenn Spott des Tanks verfehlt", -295, "tauntAlert")

-- SLIDER: Aggro-Leiste Skalierung (Breite)
local sliderThreatW = CreateFrame("Slider", "ATMSliderThreatW", optionsPanel, "OptionsSliderTemplate")
sliderThreatW:SetPoint("TOPLEFT", 20, -345)
sliderThreatW:SetMinMaxValues(150, 400)
sliderThreatW:SetValueStep(10)
_G[sliderThreatW:GetName() .. "Low"]:SetText("150")
_G[sliderThreatW:GetName() .. "High"]:SetText("400")
_G[sliderThreatW:GetName() .. "Text"]:SetText("Aggro-Leiste Breite: " .. ATM_Settings.threatWidth)
sliderThreatW:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value)
    ATM_Settings.threatWidth = value
    threatBar:SetWidth(value)
    _G[self:GetName() .. "Text"]:SetText("Aggro-Leiste Breite: " .. value)
end)

-- SLIDER: CD-Monitor Skalierung (Breite)
local sliderCDW = CreateFrame("Slider", "ATMSliderCDW", optionsPanel, "OptionsSliderTemplate")
sliderCDW:SetPoint("TOPLEFT", 240, -345)
sliderCDW:SetMinMaxValues(150, 400)
sliderCDW:SetValueStep(10)
_G[sliderCDW:GetName() .. "Low"]:SetText("150")
_G[sliderCDW:GetName() .. "High"]:SetText("400")
_G[sliderCDW:GetName() .. "Text"]:SetText("CD-Monitor Breite: " .. ATM_Settings.cdWidth)
sliderCDW:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value)
    ATM_Settings.cdWidth = value
    cdBar:SetWidth(value)
    _G[self:GetName() .. "Text"]:SetText("CD-Monitor Breite: " .. value)
end)

-- SLIDER: Schriftgröße
local sliderFont = CreateFrame("Slider", "ATMSliderFont", optionsPanel, "OptionsSliderTemplate")
sliderFont:SetPoint("TOPLEFT", 20, -400)
sliderFont:SetMinMaxValues(10, 24)
sliderFont:SetValueStep(1)
_G[sliderFont:GetName() .. "Low"]:SetText("10")
_G[sliderFont:GetName() .. "High"]:SetText("24")
_G[sliderFont:GetName() .. "Text"]:SetText("Schriftgröße: " .. ATM_Settings.fontSize)
sliderFont:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value)
    ATM_Settings.fontSize = value
    UpdateBarStyles()
    _G[self:GetName() .. "Text"]:SetText("Schriftgröße: " .. value)
end)

-- BUTTON: TESTMODUS STARTEN
local btnTest = CreateFrame("Button", "ATM_Btn_RunTest", optionsPanel, "UIPanelButtonTemplate")
btnTest:SetPoint("TOPLEFT", 16, -450)
btnTest:SetSize(160, 24)
btnTest:SetText("Testmodus starten")
btnTest:SetScript("OnClick", function() RunTestMode() end)

-- CHECKBOX: ALLE ELEMENTE FREIGEBEN (ZUM VERSCHIEBEN)
local cbMove = CreateFrame("CheckButton", "ATM_CB_MoveThreatBar", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
cbMove:SetPoint("TOPLEFT", 185, -450)
_G[cbMove:GetName() .. "Text"]:SetText("Alle Elemente verschiebbar machen")
cbMove:SetScript("OnClick", function(self)
    isUnlockedForMoving = self:GetChecked()
    UpdateBarStyles()
    if isUnlockedForMoving then
        warnFrame:Show()
        warnText:SetText("Warnbalken (Verschiebbar)")
        warnFrame:SetBackdropColor(0.2, 0.0, 0.0, 0.95)
        warnFrame:SetBackdropBorderColor(1.0, 0.1, 0.1, 1.0)

        threatBar:Show()
        threatBar:SetValue(85)
        threatBar:SetStatusBarColor(1.0, 0.8, 0.0)
        threatText:SetText("Aggro-Leiste (Verschiebbar)")
        
        cdBar:Show()
        UpdateCDMonitorDisplay("TestTank", "Schildwall", 999)
        cdText:SetText("CD-Monitor (Verschiebbar)")
    else
        warnFrame:Hide()
        threatBar:Hide()
        cdBar:Hide()
    end
end)

-- BUTTON: POSITIONEN ZURÜCKSETZEN
local btnResetPos = CreateFrame("Button", "ATM_Btn_ResetPos", optionsPanel, "UIPanelButtonTemplate")
btnResetPos:SetPoint("TOPLEFT", 16, -485)
btnResetPos:SetSize(160, 22)
btnResetPos:SetText("Positionen zurücksetzen")
btnResetPos:SetScript("OnClick", function()
    threatBar:ClearAllPoints()
    threatBar:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    ATM_Settings.threatX = 0
    ATM_Settings.threatY = -120

    cdBar:ClearAllPoints()
    cdBar:SetPoint("CENTER", UIParent, "CENTER", 0, -155)
    ATM_Settings.cdX = 0
    ATM_Settings.cdY = -155

    warnFrame:ClearAllPoints()
    warnFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    ATM_Settings.warnX = 0
    ATM_Settings.warnY = 180

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM]|r Alle Positionen zurückgesetzt.")
end)

-- SPRACH-EINSTELLUNG: CHECKBOXEN (DE / ENG)
local langHeader = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
langHeader:SetPoint("TOPLEFT", 16, -535)
langHeader:SetText("Sprache für Chat & Warnungen:")

local cbDE = CreateFrame("CheckButton", "ATM_CB_LangDE", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
cbDE:SetPoint("TOPLEFT", 16, -555)
_G[cbDE:GetName() .. "Text"]:SetText("Deutsch (DEU)")

local cbEN = CreateFrame("CheckButton", "ATM_CB_LangEN", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
cbEN:SetPoint("TOPLEFT", 150, -555)
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

-- Tank-Symbol Beschriftung & Dropdown (Rechts platziert)
local iconHeader = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
iconHeader:SetPoint("TOPLEFT", 270, -45)
iconHeader:SetText("Tank-Symbol:")

local iconDropdown = CreateFrame("Frame", "ATMIconDropdown", optionsPanel, "UIDropDownMenuTemplate")
iconDropdown:SetPoint("TOPLEFT", 260, -62)
local iconNames = { 
    [1] = "1 - Stern", 
    [2] = "2 - Kreis", 
    [3] = "3 - Diamant", 
    [4] = "4 - Dreieck", 
    [5] = "5 - Mond", 
    [6] = "6 - Quadrat", 
    [7] = "7 - Kreuz", 
    [8] = "8 - Totenkopf" 
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
    sliderCDW:SetValue(ATM_Settings.cdWidth)
    sliderFont:SetValue(ATM_Settings.fontSize)
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
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[ATM v1.9.12]|r Tank-Suche ausgeführt. Tippe |cffffd100/atm config|r für Einstellungen oder |cffffd100/atm test|r.")
    end
end