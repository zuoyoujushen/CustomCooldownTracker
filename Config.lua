local addonName, CCT = ...

-- ElvUI style panel builder
local function ApplyFlatBackdrop(f)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)
end

-- Main standalone window
local panel = CreateFrame("Frame", "CCTConfigFrame", UIParent, "BackdropTemplate")
panel:SetSize(860, 540)
panel:SetPoint("CENTER")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:Hide()
ApplyFlatBackdrop(panel)

-- Close Button
local closeBtn = CreateFrame("Button", nil, panel)
closeBtn:SetSize(24, 24)
closeBtn:SetPoint("TOPRIGHT", -5, -5)
ApplyFlatBackdrop(closeBtn)
closeBtn:SetBackdropColor(0.8, 0.1, 0.1, 0.8)
local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
closeText:SetPoint("CENTER")
closeText:SetText("X")
closeBtn:SetScript("OnClick", function() panel:Hide() end)
closeBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(1, 0.2, 0.2, 1) end)
closeBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.8, 0.1, 0.1, 0.8) end)

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
title:SetPoint("TOP", 0, -12)
title:SetText("Custom Cooldown Tracker")

-- Lock Checkbox
local lockCheck = CreateFrame("CheckButton", "CCTLockCheck", panel, "UICheckButtonTemplate")
lockCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -45)
lockCheck.Text = lockCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
lockCheck.Text:SetPoint("LEFT", lockCheck, "RIGHT", 5, 0)
lockCheck.Text:SetText("锁定主监控条 (无法吸附或拖动)")
lockCheck.Text:SetFontObject("GameFontHighlight")
lockCheck:SetScript("OnShow", function(self) self:SetChecked(CCT_DB.locked) end)
lockCheck:SetScript("OnClick", function(self)
    CCT_DB.locked = self:GetChecked()
    CCT.UI:UpdateLockState()
end)

-- Flat EditBox builder
local function CreateFlatEditBox(parent, width, labelText)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 24)
    local label = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", container, "LEFT", 0, 0)
    label:SetText(labelText)
    local input = CreateFrame("EditBox", nil, container)
    input:SetSize(40, 24)
    input:SetPoint("LEFT", label, "RIGHT", 10, 0)
    input:SetFontObject("ChatFontNormal")
    input:SetAutoFocus(false)
    input:SetTextInsets(5, 5, 0, 0)
    ApplyFlatBackdrop(input)
    input:SetBackdropColor(0, 0, 0, 0.5)
    
    container.label = label
    container.input = input
    return container
end

local sizeContainer = CreateFlatEditBox(panel, 120, "图标大小:")
sizeContainer:SetPoint("TOPLEFT", lockCheck, "BOTTOMLEFT", 0, -15)
sizeContainer.input:SetScript("OnShow", function(self) self:SetText(tostring(CCT_DB.size)) end)
sizeContainer.input:SetScript("OnEnterPressed", function(self)
    local val = tonumber(self:GetText())
    if val and val >= 10 and val <= 100 then
        CCT_DB.size = val
        CCT.UI:UpdateLayout()
        CCT:RefreshTrackedList()
        self:ClearFocus()
    else self:SetText(tostring(CCT_DB.size)) end
end)

local padContainer = CreateFlatEditBox(panel, 120, "图标间距:")
padContainer:SetPoint("LEFT", sizeContainer, "RIGHT", 20, 0)
padContainer.input:SetSize(30, 24)
padContainer.input:SetScript("OnShow", function(self) self:SetText(tostring(CCT_DB.padding)) end)
padContainer.input:SetScript("OnEnterPressed", function(self)
    local val = tonumber(self:GetText())
    if val and val >= 0 and val <= 50 then
        CCT_DB.padding = val
        CCT.UI:UpdateLayout()
        CCT:RefreshTrackedList()
        self:ClearFocus()
    else self:SetText(tostring(CCT_DB.padding)) end
end)

local iplContainer = CreateFlatEditBox(panel, 160, "每行/列数量:")
iplContainer:SetPoint("LEFT", padContainer, "RIGHT", 10, 0)
iplContainer.input:SetSize(30, 24)
iplContainer.input:SetScript("OnShow", function(self) self:SetText(tostring(CCT_DB.iconsPerLine or 10)) end)
iplContainer.input:SetScript("OnEnterPressed", function(self)
    local val = tonumber(self:GetText())
    if val and val >= 1 and val <= 100 then
        CCT_DB.iconsPerLine = val
        CCT.UI:UpdateLayout()
        CCT:RefreshTrackedList()
        self:ClearFocus()
    else self:SetText(tostring(CCT_DB.iconsPerLine or 10)) end
end)

-- Flat Dropdown Builder
local activeDropdownList = nil
local function CreateFlatDropdown(parent, width, labelText, options, dbKey, defaultVal, callbackFn)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 24)
    
    local label = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", container, "LEFT", 0, 0)
    label:SetText(labelText)
    
    local btn = CreateFrame("Button", nil, container)
    btn:SetSize(width - label:GetStringWidth() - 10, 24)
    btn:SetPoint("LEFT", label, "RIGHT", 10, 0)
    ApplyFlatBackdrop(btn)
    btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    
    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btnText:SetPoint("CENTER")
    
    local list = CreateFrame("Frame", nil, btn)
    local listHeight = #options * 24 + 2
    list:SetSize(btn:GetWidth(), listHeight)
    list:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
    ApplyFlatBackdrop(list)
    list:SetBackdropColor(0.1, 0.1, 0.1, 1)
    list:SetFrameStrata("DIALOG")
    list:Hide()
    
    for i, opt in ipairs(options) do
        local rb = CreateFrame("Button", nil, list)
        rb:SetSize(list:GetWidth() - 2, 24)
        rb:SetPoint("TOP", 0, -1 - (i-1)*24)
        local rt = rb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        rt:SetPoint("CENTER")
        rt:SetText(opt.v)
        
        rb:SetScript("OnEnter", function(self) ApplyFlatBackdrop(self) self:SetBackdropColor(0.3, 0.3, 0.3, 1) end)
        rb:SetScript("OnLeave", function(self) self:SetBackdrop(nil) end)
        rb:SetScript("OnClick", function()
            CCT_DB[dbKey] = opt.k
            btnText:SetText(opt.v)
            list:Hide()
            activeDropdownList = nil
            if callbackFn then callbackFn() end
        end)
    end
    
    btn:SetScript("OnShow", function(self)
        local cur = CCT_DB[dbKey] or defaultVal
        for _, opt in ipairs(options) do
            if opt.k == cur then btnText:SetText(opt.v) break end
        end
    end)
    btn:SetScript("OnClick", function()
        if activeDropdownList and activeDropdownList ~= list then activeDropdownList:Hide() end
        if list:IsShown() then 
            list:Hide()
            activeDropdownList = nil
        else 
            list:Show() 
            activeDropdownList = list
        end
    end)
    
    container.label = label
    container.btn = btn
    return container
end

-- Close dropdowns when clicking outside
panel:SetScript("OnMouseDown", function()
    if activeDropdownList then
        activeDropdownList:Hide()
        activeDropdownList = nil
    end
end)

local alignOptions = { {k="LEFT", v="左对齐"}, {k="CENTER", v="居中对齐"}, {k="RIGHT", v="右对齐"} }
local alignDropdown = CreateFlatDropdown(panel, 160, "对齐方式:", alignOptions, "align", "LEFT", function() 
    CCT.UI:UpdateLayout() 
    CCT:RefreshTrackedList() 
end)
alignDropdown:SetPoint("TOPLEFT", sizeContainer, "BOTTOMLEFT", 0, -15)

local orientOptions = { {k="HORIZONTAL", v="水平"}, {k="VERTICAL", v="垂直"} }
local orientDropdown = CreateFlatDropdown(panel, 140, "排列方向:", orientOptions, "orientation", "HORIZONTAL", function() 
    CCT.UI:UpdateLayout() 
    CCT:RefreshTrackedList() 
end)
orientDropdown:SetPoint("LEFT", alignDropdown, "RIGHT", 40, 0)

-- Add via ID Box
local idContainer = CreateFlatEditBox(panel, 200, "手动添加(法术ID):")
idContainer:SetPoint("LEFT", orientDropdown, "RIGHT", 40, 0)
idContainer.input:SetSize(60, 24)

local addBtn = CreateFrame("Button", nil, panel)
addBtn:SetSize(60, 24)
addBtn:SetPoint("LEFT", idContainer.input, "RIGHT", 5, 0)
ApplyFlatBackdrop(addBtn)
addBtn:SetBackdropColor(0.2, 0.5, 0.2, 1)
local addText = addBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
addText:SetPoint("CENTER")
addText:SetText("添 加")
addBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.3, 0.7, 0.3, 1) end)
addBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.2, 0.5, 0.2, 1) end)
addBtn:SetScript("OnClick", function()
    local id = tonumber(idContainer.input:GetText())
    if id and C_Spell.GetSpellInfo(id) then
        C_Timer.After(0, function()
            table.insert(CCT.trackedSpells, id)
            idContainer.input:SetText("")
            idContainer.input:ClearFocus()
            CCT.UI:UpdateLayout()
            CCT:RefreshTrackedList()
        end)
    end
end)

-- Layout Grids Backgrounds
local libTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
libTitle:SetPoint("TOPLEFT", alignDropdown, "BOTTOMLEFT", 0, -30)
libTitle:SetText("个人技能/天赋库 (点击添加至监控)")

local spellBg = CreateFrame("Frame", nil, panel)
spellBg:SetPoint("TOPLEFT", libTitle, "BOTTOMLEFT", 0, -10)
spellBg:SetSize(480, 320)
ApplyFlatBackdrop(spellBg)
spellBg:SetBackdropColor(0, 0, 0, 0.5)

local spellScroll = CreateFrame("ScrollFrame", "CCTSpellScroll", spellBg, "UIPanelScrollFrameTemplate")
spellScroll:SetPoint("TOPLEFT", 10, -10)
spellScroll:SetPoint("BOTTOMRIGHT", -30, 10)

-- Hide default scrollbar textures
for _, child in ipairs({spellScroll:GetRegions()}) do
    if child:IsObjectType("Texture") then child:SetAlpha(0) end
end

local spellContent = CreateFrame("Frame", nil, spellScroll)
spellContent:SetSize(440, 300)
spellScroll:SetScrollChild(spellContent)

local function BuildSpellLibrary()
    if spellContent.icons then
        for _, icon in pairs(spellContent.icons) do icon:Hide() end
    end
    spellContent.icons = {}
    local uniqueSpells, spells = {}, {}

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
    
    local ICON_SIZE, COLUMNS, PADDING = 36, 11, 4
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

-- TRACKED LIST Right Side
local trackTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
trackTitle:SetPoint("TOPLEFT", spellBg, "TOPRIGHT", 20, 0)
trackTitle:SetText("当前监控序列 (左键拖拽，右键移除)")

local trackBg = CreateFrame("Frame", nil, panel)
trackBg:SetPoint("TOPLEFT", trackTitle, "BOTTOMLEFT", 0, -10)
trackBg:SetSize(300, 320)
ApplyFlatBackdrop(trackBg)
trackBg:SetBackdropColor(0, 0, 0, 0.5)

if not panel.ghostIcon then
    panel.ghostIcon = CreateFrame("Frame", nil, panel)
    panel.ghostIcon:SetSize(36, 36)
    panel.ghostIcon:SetFrameStrata("TOOLTIP")
    panel.ghostIcon.tex = panel.ghostIcon:CreateTexture(nil, "ARTWORK")
    panel.ghostIcon.tex:SetAllPoints()
    panel.ghostIcon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    panel.ghostIcon:Hide()
    panel.ghostIcon:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local s = self:GetEffectiveScale()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x/s, y/s)
    end)
end

panel.trackIcons = {}
function CCT:RefreshTrackedList()
    for _, iconBtn in ipairs(panel.trackIcons) do iconBtn:Hide() end
    
    local cols = CCT_DB.iconsPerLine or 10
    local PADDING = 4
    local align = CCT_DB.align or "LEFT"
    
    local boxWidth = trackBg:GetWidth() - 20 -- 10px padding each side
    
    -- Dynamic Icon Scaling: Fits exactly `cols` inside the boxWidth
    -- Total width = cols * ICON_SIZE + (cols - 1) * PADDING
    -- ICON_SIZE = (boxWidth - (cols - 1) * PADDING) / cols
    local calcSize = (boxWidth - (cols - 1) * PADDING) / cols
    local ICON_SIZE = math.floor(math.min(36, math.max(12, calcSize)))
    
    local displayCols = cols
    
    local totalSpells = #CCT.trackedSpells
    
    for i, spellID in ipairs(CCT.trackedSpells) do
        local btn = panel.trackIcons[i]
        if not btn then
            btn = CreateFrame("Button", nil, trackBg)
            
            local activeHighlight = btn:CreateTexture(nil, "HIGHLIGHT")
            activeHighlight:SetAllPoints()
            activeHighlight:SetColorTexture(1, 1, 1, 0.3)
            
            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            btn.icon = tex
            
            btn:RegisterForDrag("LeftButton")
            btn:SetScript("OnDragStart", function(self)
                self:SetAlpha(0.2)
                panel.draggedIcon = self
                panel.ghostIcon.tex:SetTexture(self.icon:GetTexture())
                panel.ghostIcon:Show()
            end)
            btn:SetScript("OnDragStop", function(self)
                self:SetAlpha(1)
                panel.ghostIcon:Hide()
                local draggedFrame = panel.draggedIcon
                panel.draggedIcon = nil
                
                if draggedFrame then
                    local x, y = GetCursorPosition()
                    local scale = UIParent:GetEffectiveScale()
                    x, y = x / scale, y / scale
                    local targetIndex = nil
                    for j, checkBtn in ipairs(panel.trackIcons) do
                        if checkBtn:IsShown() and checkBtn ~= draggedFrame then
                            local left, bottom, width, height = checkBtn:GetRect()
                            if left and bottom and width and height then
                                if x >= left and x <= left + width and y >= bottom and y <= bottom + height then
                                    targetIndex = j
                                    break
                                end
                            end
                        end
                    end
                    
                    local fromIndex = draggedFrame.index
                    if targetIndex and fromIndex and fromIndex ~= targetIndex then
                        local temp = CCT.trackedSpells[fromIndex]
                        table.remove(CCT.trackedSpells, fromIndex)
                        table.insert(CCT.trackedSpells, targetIndex, temp)
                        
                        local targetBtn = panel.trackIcons[targetIndex]
                        if targetBtn then
                            local flash = targetBtn:CreateTexture(nil, "OVERLAY")
                            flash:SetAllPoints()
                            flash:SetColorTexture(1, 1, 0, 0.6)
                            C_Timer.After(0.3, function() flash:Hide() end)
                        end
                        CCT.UI:UpdateLayout()
                        CCT:RefreshTrackedList()
                    end
                end
            end)
            
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spellID)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            btn:RegisterForClicks("RightButtonUp")
            btn:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    local idx = self.index
                    local sName = C_Spell.GetSpellInfo(self.spellID)
                    sName = sName and sName.name or self.spellID
                    C_Timer.After(0, function()
                        table.remove(CCT.trackedSpells, idx)
                        CCT.UI:UpdateLayout()
                        CCT:RefreshTrackedList()
                        print("|cFFFF0000[CCT]|r 将 " .. sName .. " 移出了监控面板。")
                    end)
                end
            end)
            
            panel.trackIcons[i] = btn
        end
        
        btn:SetSize(ICON_SIZE, ICON_SIZE)
        btn.index = i
        btn.spellID = spellID
        local info = C_Spell.GetSpellInfo(spellID)
        btn.icon:SetTexture(info and info.iconID or 134400)
        
        -- Calculate Dynamic Position with Alignment inside trackBg
        -- Row logic: calculate elements in this row
        local rowIndex = math.floor((i - 1) / displayCols)
        local colIndex = (i - 1) % displayCols
        
        -- Number of items in the current row
        local itemsInThisRow = math.min(displayCols, totalSpells - rowIndex * displayCols)
        local rowTotalWidth = itemsInThisRow * ICON_SIZE + (itemsInThisRow - 1) * PADDING
        
        local startX = 10
        if align == "CENTER" then
            startX = (trackBg:GetWidth() - rowTotalWidth) / 2
        elseif align == "RIGHT" then
            startX = trackBg:GetWidth() - 10 - rowTotalWidth
        end
        
        local xOffset = startX + colIndex * (ICON_SIZE + PADDING)
        local yOffset = -10 - rowIndex * (ICON_SIZE + PADDING)
        
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", trackBg, "TOPLEFT", xOffset, yOffset)
        btn:Show()
    end
end

panel:SetScript("OnShow", function() 
    BuildSpellLibrary()
    CCT:RefreshTrackedList() 
end)

SLASH_CCT1 = "/cct"
SlashCmdList["CCT"] = function()
    if panel:IsShown() then panel:Hide() else panel:Show() end
end
