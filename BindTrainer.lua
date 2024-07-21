local BindTrainer = CreateFrame("Frame", "BindTrainerFrame", UIParent)
BindTrainer:RegisterEvent("PLAYER_LOGIN")
BindTrainer:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
BindTrainer:RegisterEvent("UPDATE_BINDINGS")

BindTrainer.flashcards = {}
BindTrainer.currentCard = 1

-- New variables for sessions
BindTrainer.currentSession = nil
BindTrainer.sessionHistory = {}

-- Create main frame
BindTrainer:SetSize(100, 100)
BindTrainer:SetPoint("CENTER")
BindTrainer:SetMovable(true)
BindTrainer:EnableMouse(true)
BindTrainer:RegisterForDrag("LeftButton")
BindTrainer:SetScript("OnDragStart", BindTrainer.StartMoving)
BindTrainer:SetScript("OnDragStop", BindTrainer.StopMovingOrSizing)
BindTrainer:Hide()

-- Create spell icon
BindTrainer.spellIcon = BindTrainer:CreateTexture(nil, "ARTWORK")
BindTrainer.spellIcon:SetAllPoints()

-- Create skip button
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

-- Improved Debug function
local function Debug(format, ...)
    if BindTrainer.debugMode then
        print(string.format("|cFF00FF00BindTrainer Debug:|r " .. format, ...))
    end
end

-- Function to get relevant bindings for an action
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

-- Shuffle table
local function ShuffleTable(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

-- Upravená funkcia PopulateFlashcards
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
                if seenSpells[name] then
                    Debug("Duplicitný spell nájdený: %s (Slot: %d, Predchádzajúci slot: %d)", name, i, seenSpells[name])
                else
                    table.insert(newFlashcards, {spell = name, bind = table.concat(bindings, ", "), icon = icon, id = id, type = actionType, slot = i})
                    seenSpells[name] = i
                    count = count + 1
                    Debug("Pridaný nový flashcard: %s (Slot: %d)", name, i)
                end
            end
        end
    end

    -- Nahradenie starej tabuľky novou
    self.flashcards = newFlashcards
    self.currentCard = 1  -- Reset na prvú kartu

    print(string.format("Celkový počet unikátnych akcií pridaných: %d", count))
    self:DebugFlashcards()
end

-- Check flashcards integrity
function BindTrainer:CheckFlashcardsIntegrity()
    for i, card in ipairs(self.flashcards) do
        if not card.spell or not card.type or not card.id or not card.icon then
            Debug("Warning: Invalid flashcard found at index %d", i)
            table.remove(self.flashcards, i)
        end
    end
end

-- Show flashcard
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
    
    if self.currentSession then
        print(string.format("Použite klávesovú skratku (%s) pre: %s (%d/%d)", card.bind, card.spell, self.currentCard, self.currentSession.totalFlashcards))
    else
        print(string.format("Použite klávesovú skratku (%s) pre: %s", card.bind, card.spell))
    end
    
    self:Show()
end

-- Play sound function
function BindTrainer:PlaySound(correct)
    Debug("PlaySound called with correct=%s", tostring(correct))
    if correct then
        PlaySound(SOUNDKIT.UI_EPICLOOT_TOAST)
    else
        PlaySound(SOUNDKIT.UI_BATTLEGROUND_COUNTDOWN_FINISHED)
    end
end

-- Shake Icon
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

-- Upravená funkcia CheckAnswer
function BindTrainer:CheckAnswer(actionType, actionId)
    if not self.isSessionActive or not self.currentSession then return end

    if not self.currentSpell or not self.currentType or not self.currentId then
        Debug("Chyba: Chýbajú informácie o aktuálnom kúzle")
        return
    end

    self.currentSession.totalActions = self.currentSession.totalActions + 1

    if self.currentType == actionType and self.currentId == actionId then
        print(string.format("Correct! You used the right action: %s", self.currentSpell))
        self:PlaySound(true)
        self:NextFlashcard()
    else
        print(string.format("Incorrect. Expected %s (%s), but got %s with ID %s", 
            self.currentSpell, self.currentType, actionType or "Unknown", tostring(actionId) or "Unknown"))
        self:PlaySound(false)
        self:ShakeIcon()
        self.currentSession.mistakes = self.currentSession.mistakes + 1
    end
end

-- Upravená funkcia NextFlashcard
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

        print(string.format("Vybraný flashcard: %d - %s (Celkovo zobrazené: %d/%d)", 
            self.currentCard, newCard.spell, #self.currentSession.seenFlashcards, self.currentSession.totalFlashcards))
    else
        print("Všetky flashcardy boli zobrazené. Ukončujem reláciu...")
        self:EndSession()
        return
    end

    self:ShowFlashcard()
end

-- Restart training
function BindTrainer:RestartTraining()
    ShuffleTable(self.flashcards)
    self.currentCard = 1
    print("Training restarted with a new random order.")
    self:ShowFlashcard()
end

-- New function to start a session
function BindTrainer:StartSession()
    if self.currentSession then
        print("Relácia už beží.")
        return
    end

    self:PopulateFlashcards()
    print("Počiatočný zoznam všetkých dostupných flashcardov:")
    self:PrintSpellList()

    self.currentSession = {
        startTime = nil,
        endTime = nil,
        mistakes = 0,
        totalActions = 0,
        skips = 0,
        totalFlashcards = #self.flashcards,
        seenFlashcards = {},
        unseenFlashcards = nil,
    }

    print(string.format("Začínam novú reláciu s %d flashcardmi!", self.currentSession.totalFlashcards))
    print("Flashcardy budú zobrazované v náhodnom poradí.")

    -- Inicializujeme unseenFlashcards tu
    self.currentSession.unseenFlashcards = {}
    for i = 1, #self.flashcards do
        table.insert(self.currentSession.unseenFlashcards, i)
    end

    -- A hneď zavoláme NextFlashcard, aby sme vybrali prvú náhodnú kartu
    self:NextFlashcard()

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
            self:Show()  -- Zobrazenie hlavnej ikony
            self.skipButton:Show()  -- Zobrazenie tlačidla Skip
            self.isSessionActive = true  -- Nastavenie relácie ako aktívnej
            self.currentSession.startTime = GetTime()  -- Nastavenie času začiatku relácie
            self:UpdateSessionTimer()
        end
    end
    DoCountdown()
end

-- New function to end a session
function BindTrainer:EndSession()
    if not self.currentSession then
        print("No active session.")
        return
    end

    self.isSessionActive = false

    self.currentSession.endTime = GetTime()
    local duration = self.currentSession.endTime - self.currentSession.startTime
    local apm = self.currentSession.totalActions / (duration / 60)

    print("Relácia skončila!")
    print(string.format("Celkový čas: %.2f sekúnd", duration))
    print(string.format("Akcií za minútu: %.2f", apm))
    print(string.format("Počet chýb: %d", self.currentSession.mistakes))
    print(string.format("Počet preskočených: %d", self.currentSession.skips))
    print(string.format("Celkový počet flashcardov: %d", self.currentSession.totalFlashcards))
    print(string.format("Počet unikátnych flashcardov: %d", #self.currentSession.seenFlashcards))

    -- Pridajte toto na koniec funkcie EndSession
    self:DebugFlashcardDisplayCount()

    -- Save session to history
    table.insert(self.sessionHistory, {
        date = date("%Y-%m-%d %H:%M:%S"),
        duration = duration,
        mistakes = self.currentSession.mistakes,
        apm = apm,
        skips = self.currentSession.skips,  -- Add skip count to history
        totalFlashcards = self.currentSession.totalFlashcards  -- Add total flashcards count to history
    })
    self:SaveSessionHistory()
    Debug("Added new session to history. Total sessions: " .. #self.sessionHistory)

    -- Hide the main icon and relevant elements
    self:Hide()
    self.skipButton:Hide()
    -- If you have any other visible elements, hide them here

    -- Ask user if they want to start a new session
    StaticPopupDialogs["BINDTRAINER_NEW_SESSION"] = {
        text = "Do you want to start a new session?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            self:StartSession()
        end,
        OnCancel = function()
            -- No need to hide anything, as we've already hidden them above
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("BINDTRAINER_NEW_SESSION")

    self.currentSession = nil
end

-- New function to update session timer
function BindTrainer:UpdateSessionTimer()
    if not self.currentSession then return end

    local elapsed = GetTime() - self.currentSession.startTime
    print(string.format("Čas relácie: %.2f sekúnd", elapsed))

    C_Timer.After(1, function() self:UpdateSessionTimer() end)
end

-- New function to show session history
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

-- Initialize
BindTrainer:SetScript("OnEvent", function(self, event)
    Debug("Event triggered: %s", event)
    if event == "PLAYER_LOGIN" or event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BINDINGS" then
        self:PopulateFlashcards()
        print(string.format("BindTrainer loaded with %d flashcards. Type /bt to start training, /btend to end, /btrestart to shuffle and restart.", #self.flashcards))
    end
end)

-- Hook spell cast
hooksecurefunc("UseAction", function(slot, checkCursor, onSelf)
    if not BindTrainer.isSessionActive then return end  -- If session is not active, do nothing

    local actionType, id = GetActionInfo(slot)
    Debug("UseAction hook called with slot=%s, actionType=%s, id=%s", tostring(slot), tostring(actionType), tostring(id))
    BindTrainer:CheckAnswer(actionType, id)
end)

-- Slash commands
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

-- Addon loaded event
function BindTrainer:OnAddonLoaded(addonName)
    if addonName ~= "BindTrainer" then return end
    
    self:InitializeSavedVariables()
    Debug("Loaded session history: " .. #self.sessionHistory)
end

BindTrainer:RegisterEvent("ADDON_LOADED")
BindTrainer:RegisterEvent("PLAYER_LOGOUT")
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

-- Restart training
SLASH_BINDTRAINERRESTART1 = "/btrestart"
SlashCmdList["BINDTRAINERRESTART"] = function()
    BindTrainer:RestartTraining()
end

-- Create frame for countdown
BindTrainer.countdownFrame = CreateFrame("Frame", nil, UIParent)
BindTrainer.countdownFrame:SetSize(200, 100)
BindTrainer.countdownFrame:SetPoint("CENTER")
BindTrainer.countdownFrame:Hide()

BindTrainer.countdownText = BindTrainer.countdownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
BindTrainer.countdownText:SetPoint("CENTER")
BindTrainer.countdownText:SetText("")

-- Create frame for history
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

-- Create scrollframe for history
BindTrainer.historyScrollFrame = CreateFrame("ScrollFrame", nil, BindTrainer.historyFrame, "UIPanelScrollFrameTemplate")
BindTrainer.historyScrollFrame:SetPoint("TOPLEFT", 10, -30)
BindTrainer.historyScrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

BindTrainer.historyContent = CreateFrame("Frame", nil, BindTrainer.historyScrollFrame)
BindTrainer.historyContent:SetSize(330, 1) -- Height will be adjusted dynamically
BindTrainer.historyScrollFrame:SetScrollChild(BindTrainer.historyContent)

-- Funkcia na inicializáciu SavedVariables
function BindTrainer:InitializeSavedVariables()
    if not BindTrainerSavedVariables then
        BindTrainerSavedVariables = {
            sessionHistory = {}
        }
    end
    self.sessionHistory = BindTrainerSavedVariables.sessionHistory
end

-- Funkcia na uloženie histórie do SavedVariables
function BindTrainer:SaveSessionHistory()
    BindTrainerSavedVariables.sessionHistory = self.sessionHistory
end

-- Debug mode
BindTrainer.debugMode = false

SLASH_BINDTRAINERDEBUG1 = "/btdebug"
SlashCmdList["BINDTRAINERDEBUG"] = function()
    BindTrainer.debugMode = not BindTrainer.debugMode
    print("BindTrainer debug mode: " .. (BindTrainer.debugMode and "ON" or "OFF"))
end

-- Debug function for flashcards
function BindTrainer:DebugFlashcards()
    print("Debug: Flashcards")
    print("Total flashcards: " .. #self.flashcards)
    for i, card in ipairs(self.flashcards) do
        print(string.format("%d. %s (Slot: %d, Type: %s, ID: %s, Bind: %s)", i, card.spell, card.slot, card.type, tostring(card.id), card.bind))
    end
end

-- Pridajte túto novú funkciu na sledovanie zobrazení flashcardov
function BindTrainer:TrackFlashcardDisplay(spell)
    if not self.flashcardDisplayCount then
        self.flashcardDisplayCount = {}
    end
    self.flashcardDisplayCount[spell] = (self.flashcardDisplayCount[spell] or 0) + 1
end

-- Pridajte túto novú funkciu na debugovanie počtu zobrazení flashcardov
function BindTrainer:DebugFlashcardDisplayCount()
    print("Debug: Počet zobrazení flashcardov")
    for spell, count in pairs(self.flashcardDisplayCount) do
        print(string.format("%s: %d", spell, count))
    end
    
    print("Debug: Porovnanie s pôvodným zoznamom flashcardov")
    for _, card in ipairs(self.flashcards) do
        local displayCount = self.flashcardDisplayCount[card.spell] or 0
        print(string.format("%s: Zobrazené %d krát", card.spell, displayCount))
    end
end

-- Nová funkcia na výpis zoznamu kúziel
function BindTrainer:PrintSpellList()
    print("Zoznam kúziel pre túto reláciu:")
    for i, card in ipairs(self.flashcards) do
        print(string.format("%d. %s (Slot: %d, Type: %s, ID: %s)", i, card.spell, card.slot, card.type, tostring(card.id)))
    end
end