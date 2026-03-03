local addonName, CCT = ...
CCT.events = CreateFrame("Frame")
CCT.trackedSpells = {} -- store spellIDs
CCT.frames = {} -- UI frames

CCT.events:RegisterEvent("ADDON_LOADED")
CCT.events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
CCT.events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
CCT.events:RegisterEvent("SPELL_UPDATE_USABLE")

function CCT:UpdateActiveSpecProfile()
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or 0
    if not CCT_DB.specs then CCT_DB.specs = {} end
    if not CCT_DB.specs[specID] then
        -- Default to the legacy spells list if this is the first time, or an empty list
        CCT_DB.specs[specID] = CCT_DB.spells or {}
    end
    CCT.trackedSpells = CCT_DB.specs[specID]
    
    if CCT.UI and CCT.UI.mainFrame and CCT.UI.UpdateLayout then
        CCT.UI:UpdateLayout()
    end
    -- Also refresh the config UI if it's open
    if CCTConfigFrame and CCTConfigFrame:IsShown() and CCT.RefreshTrackedList then
        CCT:RefreshTrackedList()
    end
end

CCT.events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            -- Initialize default variables
            CCT_DB = CCT_DB or { spells = {}, specs = {}, locked = false, point = "CENTER", x = 0, y = 0, size = 40, padding = 5 }
            CCT_DB.size = CCT_DB.size or 40
            CCT_DB.padding = CCT_DB.padding or 5
            CCT:UpdateActiveSpecProfile()
            CCT.UI:Initialize()
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        CCT:UpdateActiveSpecProfile()
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
            
            local hasCharges = chargeInfo and chargeInfo.maxCharges and chargeInfo.maxCharges > 1
            if frame.countText then
                if hasCharges then
                    frame.countText:SetText(chargeInfo.currentCharges)
                else
                    frame.countText:SetText("")
                end
            end
            
            if chargeInfo and chargeInfo.cooldownStartTime and chargeInfo.cooldownDuration then
                -- Dodge Taint from evaluating currentCharges < maxCharges by just blindly passing to SetCooldown!
                frame.cooldown:SetCooldown(chargeInfo.cooldownStartTime, chargeInfo.cooldownDuration, chargeInfo.chargeModRate or 1)
                -- If it isn't cooling down, IsShown() perfectly evaluates to false natively in C++!
                if frame.cooldown:IsShown() then
                    isOnGCD = false
                    foundRealCD = true
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
            
            local shouldGray = false
            if hasCharges then
                shouldGray = isRealCD and not isUsable
            else
                shouldGray = isRealCD
            end
            
            if isPassive then
                frame.icon:SetDesaturated(false)
                frame.icon:SetVertexColor(1, 1, 1)
            else
                if shouldGray then
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
