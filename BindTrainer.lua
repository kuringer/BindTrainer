local BindTrainer = CreateFrame("Frame", "BindTrainerFrame", UIParent)
BindTrainer:RegisterEvent("PLAYER_LOGIN")
BindTrainer:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
BindTrainer:RegisterEvent("UPDATE_BINDINGS")
BindTrainer:RegisterEvent("ADDON_LOADED")
BindTrainer:RegisterEvent("PLAYER_LOGOUT")

-- HELPER FUNCTIONS
-- 1. Debug
local function Debug(message)
    if BindTrainer.debugMode then
        print("|cFF00FF00BindTrainer Debug:|r " .. message)
    end
end

-- 2. Shuffle table
local function ShuffleTable(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

-- 3. Get relevant bindings for an action
local function GetRelevantBindings(actionType, id, name, slot)
    local bindings = {}
    local actionBarBindings = {
        "ACTIONBUTTON", "MULTIACTIONBAR1BUTTON", "MULTIACTIONBAR2BUTTON",
        "MULTIACTIONBAR3BUTTON", "MULTIACTIONBAR4BUTTON", "EXTRAACTIONBUTTON"
    }

    -- Check action bar bindings
    for _, bindingType in ipairs(actionBarBindings) do
        local binding = bindingType .. ((slot - 1) % 12 + 1)
        local key = GetBindingKey(binding)
        if key then
            table.insert(bindings, key)
        end
    end

    -- Check for direct spell bindings
    if actionType == "spell" and name then
        local spellBinding = "SPELL " .. name:upper()
        local key = GetBindingKey(spellBinding)
        if key then
            table.insert(bindings, key)
        end
    end

    -- Check for item bindings
    if actionType == "item" and id then
        local itemBinding = "ITEM " .. id
        local key = GetBindingKey(itemBinding)
        if key then
            table.insert(bindings, key)
        end
    end

    -- Check for macro bindings
    if actionType == "macro" and name then
        local macroIndex = GetMacroIndexByName(name)
        if macroIndex > 0 then
            local macroBinding = "MACRO " .. macroIndex
            local key = GetBindingKey(macroBinding)
            if key then
                table.insert(bindings, key)
            end
        end
    end

    return bindings
end

-- Initialize
BindTrainer:SetScript("OnEvent", function(self, event)
    Debug("Event triggered: %s", event)
    if event == "PLAYER_LOGIN" or event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BINDINGS" then
        self:PopulateFlashcards()
        print(string.format("BindTrainer loaded with %d flashcards. Type /bt to start training, /btend to end, /btrestart to shuffle and restart.", #self.flashcards))
    end
end)

-- Addon loaded event
function BindTrainer:OnAddonLoaded(addonName)
    if addonName ~= "BindTrainer" then return end
    
    self:InitializeSavedVariables()
    Debug("Loaded session history: " .. #self.sessionHistory)
end


BindTrainer:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        self:OnAddonLoaded(...)
    elseif event == "PLAYER_LOGOUT" then
        self:SaveSessionHistory()
    else
        -- Existing logic for other events
        if event == "PLAYER_LOGIN" or event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BINDINGS" then
            self:PopulateFlashcards()
            print(string.format("BindTrainer loaded with %d flashcards. Type /bt to start training, /btend to end, /btrestart to shuffle and restart.", #self.flashcards))
        end
    end
end)

-- GLOBAL VARIABLES
BindTrainer.flashcards = {}
BindTrainer.currentCard = 1
BindTrainer.currentSession = nil
BindTrainer.sessionHistory = {}


-- UI COMPONENTS
-- 1. Create main frame
BindTrainer:SetSize(100, 100)
BindTrainer:SetPoint("CENTER")
BindTrainer:SetMovable(true)
BindTrainer:EnableMouse(true)
BindTrainer:RegisterForDrag("LeftButton")
BindTrainer:SetScript("OnDragStart", BindTrainer.StartMoving)
BindTrainer:SetScript("OnDragStop", BindTrainer.StopMovingOrSizing)
BindTrainer:Hide()

-- 2. Create spell icon
BindTrainer.spellIcon = BindTrainer:CreateTexture(nil, "ARTWORK")
BindTrainer.spellIcon:SetAllPoints()

-- 3. Create skip button
BindTrainer.skipButton = CreateFrame("Button", nil, BindTrainer, "UIPanelButtonTemplate")
BindTrainer.skipButton:SetSize(60, 25)
BindTrainer.skipButton:SetPoint("BOTTOM", BindTrainer, "BOTTOM", 0, -30)
BindTrainer.skipButton:SetText("Skip")
BindTrainer.skipButton:SetScript("OnClick", function()
    if BindTrainer.currentSession then
        BindTrainer.currentSession.skips = BindTrainer.currentSession.skips + 1
    end
    BindTrainer:NextFlashcard()
end)

-- 4. Create frame for countdown
BindTrainer.countdownFrame = CreateFrame("Frame", nil, UIParent)
BindTrainer.countdownFrame:SetSize(200, 100)
BindTrainer.countdownFrame:SetPoint("CENTER")
BindTrainer.countdownFrame:Hide()

BindTrainer.countdownText = BindTrainer.countdownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
BindTrainer.countdownText:SetPoint("CENTER")
BindTrainer.countdownText:SetText("")

-- 5. Create frame for history
BindTrainer.historyFrame = CreateFrame("Frame", "BindTrainerHistoryFrame", UIParent, "BasicFrameTemplateWithInset")
BindTrainer.historyFrame:SetSize(400, 300)
BindTrainer.historyFrame:SetPoint("CENTER")
BindTrainer.historyFrame:SetMovable(true)
BindTrainer.historyFrame:EnableMouse(true)
BindTrainer.historyFrame:RegisterForDrag("LeftButton")
BindTrainer.historyFrame:SetScript("OnDragStart", BindTrainer.historyFrame.StartMoving)
BindTrainer.historyFrame:SetScript("OnDragStop", BindTrainer.historyFrame.StopMovingOrSizing)
BindTrainer.historyFrame:Hide()

BindTrainer.historyFrame.title = BindTrainer.historyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
BindTrainer.historyFrame.title:SetPoint("TOPLEFT", 5, -5)
BindTrainer.historyFrame.title:SetText("Session History")

-- 6. Create scrollframe for history
BindTrainer.historyScrollFrame = CreateFrame("ScrollFrame", nil, BindTrainer.historyFrame, "UIPanelScrollFrameTemplate")
BindTrainer.historyScrollFrame:SetPoint("TOPLEFT", 10, -30)
BindTrainer.historyScrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

BindTrainer.historyContent = CreateFrame("Frame", nil, BindTrainer.historyScrollFrame)
BindTrainer.historyContent:SetSize(330, 1) -- Height will be adjusted dynamically
BindTrainer.historyScrollFrame:SetScrollChild(BindTrainer.historyContent)

-- MAIN FUNCTIONS
-- 1. Populate flashcards
function BindTrainer:PopulateFlashcards()
    local newFlashcards = {}
    local seenSpells = {}
    local count = 0

    for i = 1, 180 do
        local actionType, id, subType = GetActionInfo(i)
        local name, icon
        
        if actionType == "spell" then
            name, _, icon = GetSpellInfo(id)
        elseif actionType == "item" then
            name, _, _, _, _, _, _, _, _, icon = GetItemInfo(id)
        elseif actionType == "macro" then
            name, icon = GetMacroInfo(id)
        end
        
        if actionType and name and icon then
            local bindings = GetRelevantBindings(actionType, id, name, i)
            
            if #bindings > 0 then
                if not seenSpells[name] then
                    table.insert(newFlashcards, {spell = name, bind = table.concat(bindings, ", "), icon = icon, id = id, type = actionType, slot = i})
                    seenSpells[name] = i
                    count = count + 1
                end
            end
        end
    end

    -- Nahradenie starej tabuľky novou
    self.flashcards = newFlashcards
    self.currentCard = 1  -- Reset na prvú kartu

    print(string.format("Celkový počet unikátnych akcií pridaných: %d", count))
end

-- 2. Check flashcards integrity
function BindTrainer:CheckFlashcardsIntegrity()
    for i, card in ipairs(self.flashcards) do
        if not card.spell or not card.type or not card.id or not card.icon then
            Debug("Warning: Invalid flashcard found at index %d", i)
            table.remove(self.flashcards, i)
        end
    end
end

-- 3. Show flashcard
function BindTrainer:ShowFlashcard()
    if #self.flashcards == 0 then 
        print("|cFFFF0000BindTrainer Error:|r No bound actions found. Please check your action bars and key bindings.")
        return 
    end
    
    local card = self.flashcards[self.currentCard]
    if not card then
        Debug("Error: Invalid card at index %d", self.currentCard)
        return
    end

    self.spellIcon:SetTexture(card.icon)
    self.currentSpell = card.spell  -- Save current spell for later check
    self.currentType = card.type    -- Save current type for later check
    self.currentId = card.id        -- Save current ID for later check
    
    self:TrackFlashcardDisplay(card.spell)  -- Pridajte toto
    
    self:Show()
end

-- 4. Play sound function
function BindTrainer:PlaySound(correct)
    Debug("PlaySound called with correct=%s", tostring(correct))
    if correct then
        PlaySound(SOUNDKIT.UI_EPICLOOT_TOAST)
    else
        PlaySound(SOUNDKIT.UI_BATTLEGROUND_COUNTDOWN_FINISHED)
    end
end

-- 5. Shake Icon
function BindTrainer:ShakeIcon()
    Debug("ShakeIcon called")
    local shakeTime, shakeX, shakeY = 0.5, 5, 5
    local origX, origY = self:GetCenter()
    local shakes = 8
    local shakeDuration = shakeTime / shakes
    local parent = self:GetParent()
    
    local function DoShake(i)
        if i > shakes then
            self:ClearAllPoints()
            self:SetPoint("CENTER", parent, "BOTTOMLEFT", origX, origY)
            return
        end
        
        local offsetX = math.random(-shakeX, shakeX)
        local offsetY = math.random(-shakeY, shakeY)
        self:ClearAllPoints()
        self:SetPoint("CENTER", parent, "BOTTOMLEFT", origX + offsetX, origY + offsetY)
        
        C_Timer.After(shakeDuration, function()
            DoShake(i + 1)
        end)
    end
    
    DoShake(1)
end

-- 6. Check answer
function BindTrainer:CheckAnswer(actionType, actionId)
    if not self.isSessionActive or not self.currentSession then return end

    if not self.currentSpell or not self.currentType or not self.currentId then
        Debug("Chyba: Chýbajú informácie o aktuálnom kúzle")
        return
    end

    self.currentSession.totalActions = self.currentSession.totalActions + 1

    if self.currentType == actionType and self.currentId == actionId then
        print(string.format("Správne! Použili ste správnu akciu: %s", self.currentSpell))
        self:PlaySound(true)
        self:NextFlashcard()
    else
        print(string.format("Nesprávne. Očakávalo sa %s (%s), ale dostali sme %s s ID %s", 
            self.currentSpell, self.currentType, actionType or "Neznáme", tostring(actionId) or "Neznáme"))
        self:PlaySound(false)
        self:ShakeIcon()
        
        -- Kontrola, či už bola zaznamenaná chyba pre túto flashcard
        if not self.currentSession.mistakesMade then
            self.currentSession.mistakesMade = {}
        end
        
        if not self.currentSession.mistakesMade[self.currentSpell] then
            self.currentSession.mistakes = self.currentSession.mistakes + 1
            self.currentSession.mistakesMade[self.currentSpell] = true
            Debug(string.format("Zaznamenaná nová chyba pre %s", self.currentSpell))
        else
            Debug(string.format("Chyba pre %s už bola predtým zaznamenaná", self.currentSpell))
        end
    end
end

-- 7. Next flashcard
function BindTrainer:NextFlashcard()
    self:CheckFlashcardsIntegrity()
    if #self.flashcards == 0 then
        print("|cFFFF0000BindTrainer Error:|r Žiadne platné flashcardy. Ukončujem reláciu...")
        self:EndSession()
        return
    end

    if not self.currentSession then
        print("|cFFFF0000BindTrainer Error:|r Žiadna aktívna relácia. Začínam novú...")
        self:StartSession()
        return
    end

    -- Kontrola, či sme už prešli všetky flashcardy
    if #self.currentSession.seenFlashcards >= #self.flashcards then
        print("Všetky flashcardy boli zobrazené. Ukončujem reláciu...")
        self:EndSession()
        return
    end

    -- Vytvorenie zoznamu nevidených flashcardov
    if not self.currentSession.unseenFlashcards then
        self.currentSession.unseenFlashcards = {}
        for i, card in ipairs(self.flashcards) do
            if not self.currentSession.seenFlashcards[card.spell] then
                table.insert(self.currentSession.unseenFlashcards, i)
            end
        end
    end

    -- Výber náhodného nevidenéh flashcardu
    if #self.currentSession.unseenFlashcards > 0 then
        local randomIndex = math.random(1, #self.currentSession.unseenFlashcards)
        self.currentCard = table.remove(self.currentSession.unseenFlashcards, randomIndex)
        
        local newCard = self.flashcards[self.currentCard]
        self.currentSession.seenFlashcards[newCard.spell] = true

        Debug(string.format("Vybraný flashcard: %s (Zobrazené: %d/%d)", 
            newCard.spell, #self.currentSession.seenFlashcards, self.currentSession.totalFlashcards))
    else
        print("Všetky flashcardy boli zobrazené. Ukončujem reláciu...")
        self:EndSession()
        return
    end

    self:ShowFlashcard()
end

-- SESSION FUNCTIONS
-- 8. Restart training
function BindTrainer:RestartTraining()
    ShuffleTable(self.flashcards)
    self.currentCard = 1
    print("Training restarted with a new random order.")
    self:ShowFlashcard()
end

-- 9. Start session
function BindTrainer:StartSession()
    if self.currentSession then
        print("Relácia už beží.")
        return
    end

    self:PopulateFlashcards()
    Debug("Počiatočný počet flashcardov: " .. #self.flashcards)

    self.currentSession = {
        startTime = nil,
        endTime = nil,
        mistakes = 0,
        totalActions = 0,
        skips = 0,
        totalFlashcards = #self.flashcards,
        seenFlashcards = {},
        unseenFlashcards = {},
        mistakesMade = {},  -- Pridané nové pole
    }

    for i = 1, #self.flashcards do
        table.insert(self.currentSession.unseenFlashcards, i)
    end

    print(string.format("Začínam novú reláciu s %d flashcardmi.", self.currentSession.totalFlashcards))

    -- Odpočítavanie
    local countdown = 3
    self.countdownFrame:Show()
    local function DoCountdown()
        if countdown > 0 then
            self.countdownText:SetText(countdown)
            countdown = countdown - 1
            C_Timer.After(1, DoCountdown)
        elseif countdown == 0 then
            self.countdownText:SetText("Štart!")
            countdown = countdown - 1
            C_Timer.After(1, DoCountdown)
        else
            self.countdownFrame:Hide()
            print("Relácia začala!")
            self:Show()
            self.skipButton:Show()
            self.isSessionActive = true
            self.currentSession.startTime = GetTime()
            self:UpdateSessionTimer()
            self:NextFlashcard()
        end
    end
    DoCountdown()
end

-- 10. End session
function BindTrainer:EndSession()
    if not self.currentSession then
        print("Žiadna aktívna relácia.")
        return
    end

    self.isSessionActive = false

    self.currentSession.endTime = GetTime()
    local duration = self.currentSession.endTime - self.currentSession.startTime
    local apm = self.currentSession.totalActions / (duration / 60)

    print("\nRelácia skončila!")
    print(string.format("Celkový čas: %.2f sekúnd", duration))
    print(string.format("Akcií za minútu: %.2f", apm))
    print(string.format("Počet chýb: %d", self.currentSession.mistakes))
    print(string.format("Počet preskočených: %d", self.currentSession.skips))
    print(string.format("Celkový počet flashcardov: %d", self.currentSession.totalFlashcards))

    -- Skrytie hlavnej ikony a relevantných elementov
    self:Hide()
    self.skipButton:Hide()

    -- Uloženie relácie do histórie a resetovanie aktuálnej relácie
    self:SaveSessionToHistory()
    self.currentSession = nil
end

-- 11. Update session timer
function BindTrainer:UpdateSessionTimer()
    if not self.currentSession then return end

    local elapsed = GetTime() - self.currentSession.startTime
    Debug(string.format("Čas relácie: %.2f sekúnd", elapsed))

    C_Timer.After(1, function() self:UpdateSessionTimer() end)
end

-- 12. Show session history
function BindTrainer:ShowSessionHistory()
    Debug("Showing session history. Number of records: " .. #self.sessionHistory)
    BindTrainer.historyFrame:Show()
    
    -- Clear existing content
    for _, child in pairs({BindTrainer.historyContent:GetChildren()}) do
        child:Hide()
    end
    
    local yOffset = 0
    for i, session in ipairs(self.sessionHistory) do
        local sessionText = BindTrainer.historyContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sessionText:SetPoint("TOPLEFT", 0, -yOffset)
        sessionText:SetText(string.format("%d. %s\nDuration: %.2fs, APM: %.2f, Mistakes: %d, Skips: %d\nTotal flashcards: %d", 
            i, session.date, session.duration, session.apm, session.mistakes, session.skips, session.totalFlashcards))
        yOffset = yOffset + 60  -- Increase offset for more space
        Debug("Added record to history: " .. i)
    end
    
    BindTrainer.historyContent:SetHeight(yOffset)
end

-- SESSION SAVING
-- 13. Initialize saved variables
function BindTrainer:InitializeSavedVariables()
    if not BindTrainerSavedVariables then
        BindTrainerSavedVariables = {
            sessionHistory = {}
        }
    end
    self.sessionHistory = BindTrainerSavedVariables.sessionHistory
end

-- 14. Save session history
function BindTrainer:SaveSessionHistory()
    BindTrainerSavedVariables.sessionHistory = self.sessionHistory
end

-- 15. Track flashcard display
function BindTrainer:TrackFlashcardDisplay(spell)
    if not self.flashcardDisplayCount then
        self.flashcardDisplayCount = {}
    end
    self.flashcardDisplayCount[spell] = (self.flashcardDisplayCount[spell] or 0) + 1
end

-- 16. Save session to history
function BindTrainer:SaveSessionToHistory()
    local session = self.currentSession
    table.insert(self.sessionHistory, {
        date = date("%Y-%m-%d %H:%M:%S"),
        duration = session.endTime - session.startTime,
        mistakes = session.mistakes,
        apm = session.totalActions / ((session.endTime - session.startTime) / 60),
        skips = session.skips,
        totalFlashcards = session.totalFlashcards
    })
    Debug("Relácia uložená do histórie. Celkový počet relácií: " .. #self.sessionHistory)
end

-- HOOKS AND OVERRIDES
-- Hook spell cast
hooksecurefunc("UseAction", function(slot, checkCursor, onSelf)
    if not BindTrainer.isSessionActive then return end  -- If session is not active, do nothing

    local actionType, id = GetActionInfo(slot)
    Debug("UseAction hook called with slot=%s, actionType=%s, id=%s", tostring(slot), tostring(actionType), tostring(id))
    BindTrainer:CheckAnswer(actionType, id)
end)

-- SLASH COMMANDS
SLASH_BINDTRAINER1 = "/bt"
SlashCmdList["BINDTRAINER"] = function()
    BindTrainer:StartSession()
end

SLASH_BINDTRAINEREND1 = "/btend"
SlashCmdList["BINDTRAINEREND"] = function()
    BindTrainer:EndSession()
end

SLASH_BINDTRAINERHISTORY1 = "/bthistory"
SlashCmdList["BINDTRAINERHISTORY"] = function()
    BindTrainer:ShowSessionHistory()
end

SLASH_BINDTRAINERRESTART1 = "/btrestart"
SlashCmdList["BINDTRAINERRESTART"] = function()
    BindTrainer:RestartTraining()
end

BindTrainer.debugMode = false

SLASH_BINDTRAINERDEBUG1 = "/btdebug"
SlashCmdList["BINDTRAINERDEBUG"] = function()
    BindTrainer.debugMode = not BindTrainer.debugMode
    print("BindTrainer debug mode: " .. (BindTrainer.debugMode and "ON" or "OFF"))
end



