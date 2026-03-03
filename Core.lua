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

function CCT:UpdateCooldowns()
    if CCT.isUpdating then return end
    CCT.isUpdating = true
    
    -- Defer checking by 50ms to allow the WoW backend to fully populate 
    -- the GetSpellCooldown cache after a cast completes.
    C_Timer.After(0.05, function()
        CCT.isUpdating = false
        
        for i, spellID in ipairs(CCT.trackedSpells) do
            local frame = CCT.frames[i]
            if frame and frame.cooldown then
                local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
                local isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
                local isPassive = IsPassiveSpell and IsPassiveSpell(spellID) or (C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(spellID))
                
                -- C++ natively handles SecretNumbers when setting cooldowns
                if cooldownInfo and cooldownInfo.startTime and cooldownInfo.duration then
                    frame.cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration, cooldownInfo.modRate)
                else
                    frame.cooldown:Clear()
                end
                
                -- ULTIMATE WOW 12.0 GCD BYPASS (NO MATH, NO TAINT EVALUATION):
                -- CooldownFrame C++ internals natively evaluate if duration > 0 and will automatically 
                -- toggle `IsShown()` to true if the spell is actively cooling down, and `false` if not (duration 0).
                -- By querying the frame visibility, we get a mathematically pure boolean safely evaluating the SecretNumber.
                -- Combining this with the pure Lua boolean `isOnGCD`, we accurately detect real cooldowns!
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
end

