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
            local queryID = (sInfo and sInfo.name) or spellID
            
            local cooldownInfo = C_Spell.GetSpellCooldown(queryID)
            
            -- CONTINUOUS SYNC: Bypass Event Races by calling SetCooldown every 0.1s
            -- Native C++ UI ignores redundant SetCooldown calls for the same startTime
            if cooldownInfo and cooldownInfo.startTime and cooldownInfo.duration and cooldownInfo.duration > 0 then
                frame.cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration, cooldownInfo.modRate)
            else
                frame.cooldown:Clear()
            end
            
            local isUsable, notEnoughMana = C_Spell.IsSpellUsable(queryID)
            local isPassive = IsPassiveSpell and IsPassiveSpell(spellID) or (C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(spellID))
            
            local isCoolingDown = frame.cooldown:IsShown()
            local isRealCD = isCoolingDown and (cooldownInfo and cooldownInfo.isOnGCD == false)
            
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
