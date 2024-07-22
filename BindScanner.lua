local BindScanner = CreateFrame("Frame")
BindScanner:RegisterEvent("PLAYER_LOGIN")

function BindScanner:ScanBindings()
    local bindings = {}

    -- Skenuj všetky možné bindy
    for i = 1, GetNumBindings() do
        local command, category, key1, key2 = GetBinding(i)
        if key1 or key2 then
            bindings[command] = {key1 = key1, key2 = key2, category = category}
        end
    end

    -- Skenuj action bary
    for i = 1, 120 do
        local actionType, id, subType = GetActionInfo(i)
        if actionType then
            local bindingName = "ACTIONBUTTON" .. ((i - 1) % 12 + 1)
            local key1, key2 = GetBindingKey(bindingName)
            if key1 or key2 then
                bindings[bindingName] = {key1 = key1, key2 = key2, actionType = actionType, id = id, subType = subType}
            end
        end
    end

    -- Skenuj stance bar
    for i = 1, GetNumShapeshiftForms() do
        local bindingName = "SHAPESHIFTBUTTON" .. i
        local key1, key2 = GetBindingKey(bindingName)
        if key1 or key2 then
            bindings[bindingName] = {key1 = key1, key2 = key2, category = "STANCE"}
        end
    end

    -- Skenuj pet bar
    for i = 1, 10 do
        local bindingName = "BONUSACTIONBUTTON" .. i
        local key1, key2 = GetBindingKey(bindingName)
        if key1 or key2 then
            bindings[bindingName] = {key1 = key1, key2 = key2, category = "PET"}
        end
    end

    return bindings
end

function BindScanner:DisplayBindings()
    local bindings = self:ScanBindings()
    
    print("Všetky nájdené bindy:")
    for command, bindInfo in pairs(bindings) do
        print(string.format("%s: %s %s (Kategória: %s)", 
            command, 
            bindInfo.key1 or "N/A", 
            bindInfo.key2 or "", 
            bindInfo.category or bindInfo.actionType or "N/A"))
    end
end

BindScanner:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        print("BindScanner je pripravený. Použite /showbinds na zobrazenie všetkých bindov.")
    end
end)

SLASH_SHOWBINDS1 = "/showbinds"
SlashCmdList["SHOWBINDS"] = function()
    BindScanner:DisplayBindings()
end