local BindTrainer = CreateFrame("Frame", "BindTrainerFrame", UIParent)
BindTrainer:RegisterEvent("PLAYER_LOGIN")
BindTrainer:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
BindTrainer:RegisterEvent("UPDATE_BINDINGS")

BindTrainer.flashcards = {}
BindTrainer.currentCard = 1

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


-- Populate flashcards with actions from action bars
function BindTrainer:PopulateFlashcards()
    Debug("Starting to populate flashcards...")
    wipe(self.flashcards)
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
        
        if actionType and name then
            local bindings = GetRelevantBindings(actionType, id, name, i)
            
            if #bindings > 0 then
                -- Add only one flashcard per action, with all relevant bindings
                local bindingString = table.concat(bindings, ", ")
                table.insert(self.flashcards, {spell = name, bind = bindingString, icon = icon, id = id, type = actionType})
                count = count + 1
                Debug("Added %s: %s, binds: %s, id: %s", actionType, name, bindingString, tostring(id))
            else
                Debug("WARNING: No binding found for %s: %s, id: %s", actionType, tostring(name), tostring(id))
            end
        else
            Debug("No action or name found in slot %d", i)
        end
    end

    Debug("Total actions added: %d", count)
    
    if count == 0 then
        Debug("WARNING: No bound actions found on action bars. Please check your action bars and key bindings.")
    end
end

-- Show flashcard
function BindTrainer:ShowFlashcard()
    if #self.flashcards == 0 then 
        print("|cFFFF0000BindTrainer Error:|r No bound actions found. Please check your action bars and key bindings.")
        return 
    end
    
    local card = self.flashcards[self.currentCard]
    self.spellIcon:SetTexture(card.icon)
    print(string.format("Use the keybind (%s) for: %s", card.bind, card.spell))
    self:Show()
end

-- Check answer
function BindTrainer:CheckAnswer(actionType, actionId)
    local card = self.flashcards[self.currentCard]
    if card.type == actionType and card.id == actionId then
        print(string.format("Correct! You used the right action: %s", card.spell))
        self:NextFlashcard()
    else
        print(string.format("Incorrect. Expected %s, but got %s with ID %s", card.spell, actionType, tostring(actionId)))
    end
end

-- Next flashcard
function BindTrainer:NextFlashcard()
    self.currentCard = (self.currentCard % #self.flashcards) + 1
    print(string.format("Moving to next flashcard. Current card: %d", self.currentCard))
    self:ShowFlashcard()
end

-- Initialize
BindTrainer:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" or event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BINDINGS" then
        Debug("Event triggered:", event)
        self:PopulateFlashcards()
        print(string.format("BindTrainer loaded with %d flashcards. Type /bt to start training, /btend to end.", #self.flashcards))
    end
end)

-- Hook spell cast
hooksecurefunc("UseAction", function(slot, checkCursor, onSelf)
    local actionType, id = GetActionInfo(slot)
    if BindTrainer:IsShown() then
        BindTrainer:CheckAnswer(actionType, id)
    end
end)

-- Slash commands
SLASH_BINDTRAINER1 = "/bt"
SlashCmdList["BINDTRAINER"] = function()
    BindTrainer:ShowFlashcard()
end

SLASH_BINDTRAINEREND1 = "/btend"
SlashCmdList["BINDTRAINEREND"] = function()
    BindTrainer:Hide()
    print("Bind training ended.")
end


