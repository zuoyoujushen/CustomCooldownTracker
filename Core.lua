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
        end
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
            local sInfo = C_Spell.GetSpellInfo(spellID)
            local queryName = sInfo and sInfo.name
            
            local overrideID = spellID
            if C_Spell and C_Spell.GetOverrideSpell then
                overrideID = C_Spell.GetOverrideSpell(spellID) or spellID
            elseif _G.GetOverrideSpell then
                overrideID = _G.GetOverrideSpell(spellID) or spellID
            end
            
            local isOnGCD = false
            local foundRealCD = false
            local bestGCD = nil
            
            frame.cooldown:Clear()
            
            local function trySetCD(idOrName)
                if foundRealCD or not idOrName then return end
                local cd = C_Spell.GetSpellCooldown(idOrName)
                if cd and cd.duration then
                    frame.cooldown:SetCooldown(cd.startTime, cd.duration, cd.modRate)
                    if frame.cooldown:IsShown() then
                        if cd.isOnGCD then
                            bestGCD = cd
                        else
                            isOnGCD = false
                            foundRealCD = true
                        end
                    end
                end
            end
            
            trySetCD(spellID)
            trySetCD(overrideID)
            trySetCD(queryName)
            
            local chargeInfo = C_Spell.GetSpellCharges(spellID)
            if not chargeInfo then chargeInfo = C_Spell.GetSpellCharges(overrideID) end
            
            if chargeInfo and chargeInfo.currentCharges < chargeInfo.maxCharges then
                if chargeInfo.cooldownStartTime and chargeInfo.cooldownDuration then
                    frame.cooldown:SetCooldown(chargeInfo.cooldownStartTime, chargeInfo.cooldownDuration, chargeInfo.chargeModRate or 1)
                    if frame.cooldown:IsShown() then
                        isOnGCD = false
                        foundRealCD = true
                    end
                end
            end
            
            if not foundRealCD then
                if bestGCD then
                    frame.cooldown:SetCooldown(bestGCD.startTime, bestGCD.duration, bestGCD.modRate)
                    isOnGCD = true
                else
                    frame.cooldown:Clear()
                    isOnGCD = false
                end
            end
            
            local isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
            local isPassive = IsPassiveSpell and IsPassiveSpell(spellID) or (C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(spellID))
            
            local isCoolingDown = frame.cooldown:IsShown()
            local isRealCD = isCoolingDown and not isOnGCD
            
            if isPassive then
                frame.icon:SetDesaturated(false)
                frame.icon:SetVertexColor(1, 1, 1)
            else
                if isRealCD then
                    frame.icon:SetDesaturated(true)
                    frame.icon:SetVertexColor(1, 1, 1) -- Set CD Gray
                elseif notEnoughMana then
                    frame.icon:SetDesaturated(false)
                    frame.icon:SetVertexColor(128/255, 128/255, 1) -- OOM Purple
                elseif not isUsable then
                    frame.icon:SetDesaturated(true) 
                    frame.icon:SetVertexColor(1, 1, 1) -- Unusable Gray
                else
                    frame.icon:SetDesaturated(false)
                    frame.icon:SetVertexColor(1, 1, 1) -- Ready
                end
            end
        end
    end
end)

function CCT:UpdateCooldowns()
    -- Deprecated: Handled entirely by OnUpdate now
end
