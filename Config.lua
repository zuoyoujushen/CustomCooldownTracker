local addonName, CCT = ...

-- Main standalone window
local panel = CreateFrame("Frame", "CCTConfigFrame", UIParent, "BasicFrameTemplateWithInset")
panel:SetSize(800, 500)
panel:SetPoint("CENTER")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:Hide()
panel.TitleText:SetText("CustomCooldownTracker - 设置面板")

-- Lock Checkbox
local lockCheck = CreateFrame("CheckButton", "CCTLockCheck", panel, "ChatConfigCheckButtonTemplate")
lockCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, -35)
_G[lockCheck:GetName() .. "Text"]:SetText(" 锁定技能监控条 (无法吸附或拖动)")
lockCheck:SetScript("OnShow", function(self) self:SetChecked(CCT_DB.locked) end)
lockCheck:SetScript("OnClick", function(self)
    CCT_DB.locked = self:GetChecked()
    CCT.UI:UpdateLockState()
end)

-- Size EditBox
local sizeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
sizeLabel:SetPoint("TOPLEFT", lockCheck, "BOTTOMLEFT", 6, -15)
sizeLabel:SetText("图标大小:")
local sizeInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
sizeInput:SetSize(40, 20)
sizeInput:SetPoint("LEFT", sizeLabel, "RIGHT", 10, 0)
sizeInput:SetAutoFocus(false)
sizeInput:SetScript("OnShow", function(self) self:SetText(tostring(CCT_DB.size)) end)
sizeInput:SetScript("OnEnterPressed", function(self)
    local val = tonumber(self:GetText())
    if val and val >= 10 and val <= 100 then
        CCT_DB.size = val
        CCT.UI:UpdateLayout()
        self:ClearFocus()
    else
        self:SetText(tostring(CCT_DB.size))
    end
end)

-- Padding EditBox
local padLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
padLabel:SetPoint("LEFT", sizeInput, "RIGHT", 15, 0)
padLabel:SetText("图标间距:")
local padInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
padInput:SetSize(35, 20)
padInput:SetPoint("LEFT", padLabel, "RIGHT", 5, 0)
padInput:SetAutoFocus(false)
padInput:SetScript("OnShow", function(self) self:SetText(tostring(CCT_DB.padding)) end)
padInput:SetScript("OnEnterPressed", function(self)
    local val = tonumber(self:GetText())
    if val and val >= 0 and val <= 50 then
        CCT_DB.padding = val
        CCT.UI:UpdateLayout()
        self:ClearFocus()
    else
        self:SetText(tostring(CCT_DB.padding))
    end
end)

-- Icons Per Line EditBox
local iplLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
iplLabel:SetPoint("LEFT", padInput, "RIGHT", 15, 0)
iplLabel:SetText("每行/列最大图标数:")
local iplInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
iplInput:SetSize(35, 20)
iplInput:SetPoint("LEFT", iplLabel, "RIGHT", 5, 0)
iplInput:SetAutoFocus(false)
iplInput:SetScript("OnShow", function(self) self:SetText(tostring(CCT_DB.iconsPerLine or 10)) end)
iplInput:SetScript("OnEnterPressed", function(self)
    local val = tonumber(self:GetText())
    if val and val >= 1 and val <= 100 then
        CCT_DB.iconsPerLine = val
        CCT.UI:UpdateLayout()
        self:ClearFocus()
    else
        self:SetText(tostring(CCT_DB.iconsPerLine or 10))
    end
end)

-- Alignment & Orientation Buttons
local alignBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
alignBtn:SetSize(80, 22)
alignBtn:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -15)
local aligns = {["LEFT"]="左对齐", ["CENTER"]="居中对齐", ["RIGHT"]="右对齐"}
local alignOrder = {"LEFT", "CENTER", "RIGHT"}
alignBtn:SetScript("OnShow", function(self)
    CCT_DB.align = CCT_DB.align or "LEFT"
    self:SetText(aligns[CCT_DB.align])
end)
alignBtn:SetScript("OnClick", function(self)
    local nextAlign = "LEFT"
    for i, a in ipairs(alignOrder) do
        if a == CCT_DB.align then
            nextAlign = alignOrder[(i % 3) + 1]
            break
        end
    end
    CCT_DB.align = nextAlign
    self:SetText(aligns[CCT_DB.align])
    CCT.UI:UpdateLayout()
end)

local orientBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
orientBtn:SetSize(80, 22)
orientBtn:SetPoint("LEFT", alignBtn, "RIGHT", 10, 0)
orientBtn:SetScript("OnShow", function(self)
    CCT_DB.orientation = CCT_DB.orientation or "HORIZONTAL"
    self:SetText(CCT_DB.orientation == "HORIZONTAL" and "排列: 水平" or "排列: 垂直")
end)
orientBtn:SetScript("OnClick", function(self)
    CCT_DB.orientation = (CCT_DB.orientation == "HORIZONTAL") and "VERTICAL" or "HORIZONTAL"
    self:SetText(CCT_DB.orientation == "HORIZONTAL" and "排列: 水平" or "排列: 垂直")
    CCT.UI:UpdateLayout()
end)

-- Add via ID Box (Fallback)
local idLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
idLabel:SetPoint("TOPLEFT", alignBtn, "BOTTOMLEFT", 0, -15)
idLabel:SetText("手动添加(法术ID):")
local idInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
idInput:SetSize(80, 20)
idInput:SetPoint("LEFT", idLabel, "RIGHT", 10, 0)
idInput:SetAutoFocus(false)
local addBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
addBtn:SetSize(60, 22)
addBtn:SetPoint("LEFT", idInput, "RIGHT", 5, 0)
addBtn:SetText("添 加")
addBtn:SetScript("OnClick", function()
    local id = tonumber(idInput:GetText())
    if id and C_Spell.GetSpellInfo(id) then
        C_Timer.After(0, function()
            table.insert(CCT.trackedSpells, id)
            idInput:SetText("")
            idInput:ClearFocus()
            CCT.UI:UpdateLayout()
            CCT:RefreshTrackedList()
        end)
    end
end)

-- Left Side: Available Spells (Spellbook & Talents) Grid
local libTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
libTitle:SetPoint("TOPLEFT", idLabel, "BOTTOMLEFT", 0, -30)
libTitle:SetText("个人技能/天赋库 (点击添加至监控)")

local spellScroll = CreateFrame("ScrollFrame", "CCTSpellScroll", panel, "UIPanelScrollFrameTemplate")
spellScroll:SetPoint("TOPLEFT", libTitle, "BOTTOMLEFT", 5, -10)
spellScroll:SetSize(460, 300)

local spellContent = CreateFrame("Frame", nil, spellScroll)
spellContent:SetSize(460, 300)
spellScroll:SetScrollChild(spellContent)

local function BuildSpellLibrary()
    -- Clear old icons
    if spellContent.icons then
        for _, icon in pairs(spellContent.icons) do icon:Hide() end
    end
    spellContent.icons = {}
    
    local uniqueSpells = {}
    local spells = {}

    -- 1. Grab from SpellBook (11.0 API)
    local numSkillLines = C_SpellBook.GetNumSpellBookSkillLines()
    for skillLineIndex = 1, numSkillLines do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)
        if skillLineInfo and skillLineInfo.itemIndexOffset and skillLineInfo.numSpellBookItems then
            for i = 1, skillLineInfo.numSpellBookItems do
                local slotIndex = skillLineInfo.itemIndexOffset + i
                local spellType, spellBankId = C_SpellBook.GetSpellBookItemType(slotIndex, Enum.SpellBookSpellBank.Player)
                
                if spellType == Enum.SpellBookItemType.Spell or spellType == Enum.SpellBookItemType.FutureSpell then
                    local spellInfo = C_SpellBook.GetSpellBookItemInfo(slotIndex, Enum.SpellBookSpellBank.Player)
                    if spellInfo and spellInfo.spellID and not uniqueSpells[spellInfo.spellID] then
                        uniqueSpells[spellInfo.spellID] = true
                        table.insert(spells, spellInfo.spellID)
                    end
                end
            end
        end
    end
    
    -- 2. Grab from Talents (11.0 API)
    local configID = C_ClassTalents.GetActiveConfigID()
    if configID then
        local configInfo = C_Traits.GetConfigInfo(configID)
        if configInfo then
            for _, treeID in ipairs(configInfo.treeIDs) do
                local nodes = C_Traits.GetTreeNodes(treeID)
                for _, nodeID in ipairs(nodes) do
                    local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                    if nodeInfo and nodeInfo.activeEntry then
                        local entryInfo = C_Traits.GetEntryInfo(configID, nodeInfo.activeEntry.entryID)
                        if entryInfo and entryInfo.definitionID then
                            local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                            if defInfo and defInfo.spellID and not uniqueSpells[defInfo.spellID] then
                                uniqueSpells[defInfo.spellID] = true
                                table.insert(spells, defInfo.spellID)
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Draw Spells Grid
    local ICON_SIZE = 36
    local COLUMNS = 12
    local PADDING = 2
    local row, col = 0, 0
    
    for i, spellID in ipairs(spells) do
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.iconID then
            local btn = CreateFrame("Button", nil, spellContent)
            btn:SetSize(ICON_SIZE, ICON_SIZE)
            btn:SetPoint("TOPLEFT", col * (ICON_SIZE + PADDING), -row * (ICON_SIZE + PADDING))
            
            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexture(info.iconID)
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            btn.icon = tex
            
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(spellID)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            btn:SetScript("OnClick", function()
                -- Add to tracker on click
                local clickedID = spellID
                local spellName = info.name
                C_Timer.After(0, function()
                    table.insert(CCT.trackedSpells, clickedID)
                    CCT.UI:UpdateLayout()
                    CCT:RefreshTrackedList()
                    print("|cFF00FF00[CCT]|r 将 " .. spellName .. " 添加到了监控面板！")
                end)
            end)
            
            table.insert(spellContent.icons, btn)
            
            col = col + 1
            if col >= COLUMNS then
                col = 0
                row = row + 1
            end
        end
    end
    
    spellContent:SetHeight((row + 1) * (ICON_SIZE + PADDING))
end

-- Right Side: Tracked Spells List
local trackTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
trackTitle:SetPoint("TOPLEFT", spellScroll, "TOPRIGHT", 25, 40)
trackTitle:SetText("当前正在监控的技能")

local trackBg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
trackBg:SetPoint("TOPLEFT", trackTitle, "BOTTOMLEFT", -5, -10)
trackBg:SetSize(270, 300)
trackBg:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
trackBg:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
trackBg:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

panel.trackIcons = {}
function CCT:RefreshTrackedList()
    for _, iconBtn in ipairs(panel.trackIcons) do iconBtn:Hide() end
    
    local ICON_SIZE = 24
    local COLUMNS = 10
    local PADDING = 2
    local row, col = 0, 0
    
    for i, spellID in ipairs(CCT.trackedSpells) do
        local btn = panel.trackIcons[i]
        if not btn then
            btn = CreateFrame("Button", nil, trackBg)
            btn:SetSize(ICON_SIZE, ICON_SIZE)
            
            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            btn.icon = tex
            
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spellID)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            -- Left click to remove (silent or with print)
            btn:SetScript("OnClick", function(self)
                local idx = self.index
                local sName = C_Spell.GetSpellInfo(self.spellID)
                sName = sName and sName.name or self.spellID
                C_Timer.After(0, function()
                    table.remove(CCT.trackedSpells, idx)
                    CCT.UI:UpdateLayout()
                    CCT:RefreshTrackedList()
                    print("|cFFFF0000[CCT]|r 将 " .. sName .. " 移出了监控面板。")
                end)
            end)
            
            panel.trackIcons[i] = btn
        end
        
        btn.index = i
        btn.spellID = spellID
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.iconID then
            btn.icon:SetTexture(info.iconID)
        else
            btn.icon:SetTexture(134400)
        end
        
        btn:SetPoint("TOPLEFT", 10 + col * (ICON_SIZE + PADDING), -10 - row * (ICON_SIZE + PADDING))
        btn:Show()
        
        col = col + 1
        if col >= COLUMNS then
            col = 0
            row = row + 1
        end
    end
end

panel:SetScript("OnShow", function() 
    BuildSpellLibrary()
    CCT:RefreshTrackedList() 
end)

SLASH_CCT1 = "/cct"
SlashCmdList["CCT"] = function()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end
