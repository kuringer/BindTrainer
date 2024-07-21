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
    BindTrainer:NextFlashcard()
end)

-- Improved Debug function
local function Debug(format, ...)
    local args = {...}
    for i = 1, select("#", ...) do
        if args[i] == nil then
            args[i] = "nil"
        elseif type(args[i]) == "boolean" then
            args[i] = args[i] and "true" or "false"
        elseif type(args[i]) == "table" then
            args[i] = "table: " .. tostring(args[i])
        end
    end
    print(string.format("|cFF00FF00BindTrainer Debug:|r " .. format, unpack(args)))
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

-- Populate flashcards with actions from action bars
function BindTrainer:PopulateFlashcards()
    Debug("Starting to populate flashcards...")
    local newFlashcards = {}
    local count = 0

    for i = 1, 120 do  -- Scanning all action buttons
        local actionType, id, subType = GetActionInfo(i)
        local name, icon
        
        if actionType == "spell" then
            name, _, icon = GetSpellInfo(id)
        elseif actionType == "item" then
            name, _, _, _, _, _, _, _, _, icon = GetItemInfo(id)
        elseif actionType == "macro" then
            name, icon = GetMacroInfo(id)
        end
        
        Debug("Checking action slot %d: type=%s, id=%s, subType=%s, name=%s", i, tostring(actionType), tostring(id), tostring(subType), tostring(name))
        
        if actionType and name and icon then
            local bindings = GetRelevantBindings(actionType, id, name, i)
            
            if #bindings > 0 then
                local bindingString = table.concat(bindings, ", ")
                table.insert(newFlashcards, {spell = name, bind = bindingString, icon = icon, id = id, type = actionType})
                count = count + 1
                Debug("Added %s: %s, binds: %s, id: %s", actionType, name, bindingString, tostring(id))
            else
                Debug("WARNING: No binding found for %s: %s, id: %s", actionType, tostring(name), tostring(id))
            end
        else
            Debug("No valid action, name, or icon found in slot %d", i)
        end
    end

    -- Shuffle flashcards
    ShuffleTable(newFlashcards)

    -- Replace old table with new
    self.flashcards = newFlashcards
    self.currentCard = 1  -- Reset to first card

    Debug("Total actions added and shuffled: %d", count)
    
    if count == 0 then
        Debug("WARNING: No bound actions found on action bars. Please check your action bars and key bindings.")
    end
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
    print(string.format("Use the keybind (%s) for: %s", card.bind, card.spell))
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

-- Check answer
function BindTrainer:CheckAnswer(actionType, actionId)
    Debug("CheckAnswer called with actionType=%s, actionId=%s", tostring(actionType), tostring(actionId))
    
    if not self.currentSpell or not self.currentType or not self.currentId then
        Debug("Error: Current spell information is missing")
        return
    end

    if self.currentSession then
        self.currentSession.totalActions = self.currentSession.totalActions + 1
    end

    if self.currentType == actionType and self.currentId == actionId then
        print(string.format("Correct! You used the right action: %s", self.currentSpell))
        if self.PlaySound then
            self:PlaySound(true)
        else
            Debug("Warning: PlaySound method not found")
        end
        self:NextFlashcard()
    else
        print(string.format("Incorrect. Expected %s (%s), but got %s with ID %s", 
            self.currentSpell, self.currentType, actionType or "Unknown", tostring(actionId) or "Unknown"))
        if self.PlaySound then
            self.PlaySound(false)
        else
            Debug("Warning: PlaySound method not found")
        end
        if self.ShakeIcon then
            self:ShakeIcon()
        else
            Debug("Warning: ShakeIcon method not found")
        end
        if self.currentSession then
            self.currentSession.mistakes = self.currentSession.mistakes + 1
        end
    end
end

-- Next flashcard
function BindTrainer:NextFlashcard()
    self:CheckFlashcardsIntegrity()
    if #self.flashcards == 0 then
        print("|cFFFF0000BindTrainer Error:|r No valid flashcards remaining. Ending session...")
        self:EndSession()
    else
        self.currentCard = (self.currentCard % #self.flashcards) + 1
        print(string.format("Moving to next flashcard. Current card: %d", self.currentCard))
        if self.currentCard == 1 and self.currentSession then
            self:EndSession()
        else
            self:ShowFlashcard()
        end
    end
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
        print("Session already running.")
        return
    end

    self:PopulateFlashcards()
    self.currentSession = {
        startTime = GetTime(),
        endTime = nil,
        mistakes = 0,
        totalActions = 0,
    }

    -- Countdown
    local countdown = 3
    self.countdownFrame:Show()
    local function DoCountdown()
        if countdown > 0 then
            self.countdownText:SetText(countdown)
            countdown = countdown - 1
            C_Timer.After(1, DoCountdown)
        elseif countdown == 0 then
            self.countdownText:SetText("Start!")
            countdown = countdown - 1
            C_Timer.After(1, DoCountdown)
        else
            self.countdownFrame:Hide()
            print("Session started!")
            self:ShowFlashcard()
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

    self.currentSession.endTime = GetTime()
    local duration = self.currentSession.endTime - self.currentSession.startTime
    local apm = self.currentSession.totalActions / (duration / 60)

    print("Session ended!")
    print(string.format("Total time: %.2f seconds", duration))
    print(string.format("Actions per minute: %.2f", apm))
    print(string.format("Mistakes: %d", self.currentSession.mistakes))

    -- Save session to history
    table.insert(self.sessionHistory, {
        date = date("%Y-%m-%d %H:%M:%S"),
        duration = duration,
        mistakes = self.currentSession.mistakes,
        apm = apm
    })

    -- Ask user if they want to start a new session
    StaticPopupDialogs["BINDTRAINER_NEW_SESSION"] = {
        text = "Do you want to start a new session?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            self:StartSession()
        end,
        OnCancel = function()
            self:Hide()
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
    print(string.format("Session time: %.2f seconds", elapsed))

    C_Timer.After(1, function() self:UpdateSessionTimer() end)
end

-- New function to show session history
function BindTrainer:ShowSessionHistory()
    print("Session history:")
    for i, session in ipairs(self.sessionHistory) do
        print(string.format("%d. %s - Duration: %.2fs, APM: %.2f, Mistakes: %d", 
            i, session.date, session.duration, session.apm, session.mistakes))
    end
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
    local actionType, id = GetActionInfo(slot)
    Debug("UseAction hook called with slot=%s, actionType=%s, id=%s", tostring(slot), tostring(actionType), tostring(id))
    if BindTrainer:IsShown() then
        BindTrainer:CheckAnswer(actionType, id)
    end
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
    
    if BindTrainerSavedVariables then
        self.sessionHistory = BindTrainerSavedVariables.sessionHistory or {}
    else
        BindTrainerSavedVariables = {sessionHistory = {}}
    end
end

BindTrainer:RegisterEvent("ADDON_LOADED")
BindTrainer:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        self:OnAddonLoaded(...)
    elseif event == "PLAYER_LOGOUT" then
        BindTrainerSavedVariables.sessionHistory = self.sessionHistory
    else
        -- Existujúca logika pre iné eventy
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

-- Vytvorenie frame pre odpočítavanie
BindTrainer.countdownFrame = CreateFrame("Frame", nil, UIParent)
BindTrainer.countdownFrame:SetSize(200, 100)
BindTrainer.countdownFrame:SetPoint("CENTER")
BindTrainer.countdownFrame:Hide()

BindTrainer.countdownText = BindTrainer.countdownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
BindTrainer.countdownText:SetPoint("CENTER")
BindTrainer.countdownText:SetText("")