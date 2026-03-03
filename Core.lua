local addonName, CCT = ...
CCT.events = CreateFrame("Frame")
CCT.trackedSpells = {} -- store spellIDs
CCT.frames = {} -- UI frames

CCT.events:RegisterEvent("ADDON_LOADED")
CCT.events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
CCT.events:RegisterEvent("SPELL_UPDATE_USABLE")

CCT.events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            -- Initialize default variables
            CCT_DB = CCT_DB or { spells = {}, locked = false, point = "CENTER", x = 0, y = 0, size = 40, padding = 5 }
            CCT_DB.size = CCT_DB.size or 40
            CCT_DB.padding = CCT_DB.padding or 5
            CCT.trackedSpells = CCT_DB.spells
            CCT.UI:Initialize()
            CCT:UpdateCooldowns()
        end
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" then
        CCT:UpdateCooldowns()
    end
end)

CCT.lastUpdate = 0
CCT.events:SetScript("OnUpdate", function(self, elapsed)
    CCT.lastUpdate = CCT.lastUpdate + elapsed
    if CCT.lastUpdate < 0.1 then return end -- run 10 times a second
    CCT.lastUpdate = 0
    
    if not CCT.trackedSpells then return end
    
    for i, spellID in ipairs(CCT.trackedSpells) do
        local frame = CCT.frames[i]
        if frame and frame.cooldown then
            local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
            local isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
            local isPassive = IsPassiveSpell and IsPassiveSpell(spellID) or (C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(spellID))
            
            -- Because CooldownFrame:SetCooldown is handled natively in C++, 
            -- IsShown() might take a rendering cycle to update its boolean state.
            -- Reading it consistently in OnUpdate ensures accuracy.
            local isCoolingDown = frame.cooldown:IsShown()
            local isRealCD = isCoolingDown and (cooldownInfo and cooldownInfo.isOnGCD == false)
            
            -- VISUAL PRIORITY OVERRIDES
            if isPassive then
                frame.icon:SetDesaturated(false)
                frame.icon:SetVertexColor(1, 1, 1)
            else
                if isRealCD then
                    -- Priority 1: Real Cooldown overrides lack of shards/mana
                    frame.icon:SetDesaturated(true)
                    frame.icon:SetVertexColor(1, 1, 1) -- Keep it clean gray, NOT muddy purple
                elseif notEnoughMana then
                    -- Priority 2: Not on CD, but you don't have enough Shards/Mana
                    frame.icon:SetDesaturated(false)
                    frame.icon:SetVertexColor(128/255, 128/255, 1) -- Distinctive Purple alert
                elseif not isUsable then
                    -- Priority 3: Not on CD, enough mana, but unusable (conditional skills missing target/buff)
                    frame.icon:SetDesaturated(true)
                    frame.icon:SetVertexColor(1, 1, 1) -- Generic Grayout
                else
                    -- Priority 4: Fully Ready
                    frame.icon:SetDesaturated(false)
                    frame.icon:SetVertexColor(1, 1, 1)
                end
            end
        end
    end
end)

function CCT:UpdateCooldowns()
    -- Only handle setting the C++ spinner natively here.
    -- Deferred by 50ms (or 10ms) just to ensure cache consistency, 
    -- but no longer responsible for visual icon coloring.
    if CCT.isUpdating then return end
    CCT.isUpdating = true
    
    C_Timer.After(0.05, function()
        CCT.isUpdating = false
        if not CCT.trackedSpells then return end
        
        for i, spellID in ipairs(CCT.trackedSpells) do
            local frame = CCT.frames[i]
            if frame and frame.cooldown then
                local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
                if cooldownInfo and cooldownInfo.startTime and cooldownInfo.duration then
                    frame.cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration, cooldownInfo.modRate)
                else
                    frame.cooldown:Clear()
                end
            end
        end
    end)
end

