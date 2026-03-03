local addonName, CCT = ...
CCT.UI = {}


function CCT.UI:Initialize()
    local mainFrame = CreateFrame("Frame", "CCTMainFrame", UIParent)
    mainFrame:SetSize(100, CCT_DB.size + CCT_DB.padding * 2)
    mainFrame:SetPoint(CCT_DB.point or "CENTER", CCT_DB.x or 0, CCT_DB.y or 0)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self)
        if not CCT_DB.locked then 
            self:StartMoving() 
            self.isDragging = true
        end
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        if self.isDragging then
            self:StopMovingOrSizing()
            self.isDragging = false
            -- Sticky logic implementation after drop
            local snapDistance = 15
            local left = self:GetLeft()
            local right = self:GetRight()
            local top = self:GetTop()
            local bottom = self:GetBottom()
            local centerX, centerY = self:GetCenter()
            
            local screenWidth = UIParent:GetWidth()
            local screenHeight = UIParent:GetHeight()
            local screenCenterX = screenWidth / 2
            local screenCenterY = screenHeight / 2
            
            -- Snap to screen center
            if math.abs(centerX - screenCenterX) < snapDistance then
                local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint(1)
                self:ClearAllPoints()
                self:SetPoint(point, relativeTo, relativePoint, xOfs - (centerX - screenCenterX), yOfs)
            end
            if math.abs(centerY - screenCenterY) < snapDistance then
                local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint(1)
                self:ClearAllPoints()
                self:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs - (centerY - screenCenterY))
            end
            
            -- Save new coordinates
            local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint(1)
            CCT_DB.point = point
            CCT_DB.x = xOfs
            CCT_DB.y = yOfs
        end
    end)
    
    local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.4)
    mainFrame.bg = bg
    
    -- Backdrop for a nicer look when unlocked
    mainFrame.text = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.text:SetPoint("BOTTOM", mainFrame, "TOP", 0, 2)
    mainFrame.text:SetText("CustomCooldownTracker")
    
    CCT.UI.mainFrame = mainFrame
    
    self:UpdateLayout()
    self:UpdateLockState()
end

function CCT.UI:UpdateLockState()
    if CCT_DB.locked then
        CCT.UI.mainFrame.bg:Hide()
        CCT.UI.mainFrame.text:Hide()
    else
        CCT.UI.mainFrame.bg:Show()
        CCT.UI.mainFrame.text:Show()
    end
end

function CCT.UI:UpdateLayout()
    -- Clear old frames visually
    for _, f in pairs(CCT.frames) do
        f:Hide()
    end
    
    -- Grid Layout Mathematics
    local sz = CCT_DB.size
    local pad = CCT_DB.padding
    local cols = CCT_DB.iconsPerLine or 10
    local orient = CCT_DB.orientation or "HORIZONTAL"
    local align = CCT_DB.align or "LEFT"
    
    local numItems = #CCT.trackedSpells
    if numItems == 0 then
        CCT.UI.mainFrame:SetSize(100, sz + pad * 2)
        return
    end
    
    local numCols, numRows
    if orient == "HORIZONTAL" then
        numCols = math.min(numItems, cols)
        numRows = math.ceil(numItems / cols)
    else
        numRows = math.min(numItems, cols)
        numCols = math.ceil(numItems / cols)
    end
    
    local totalGridW = numCols * sz + math.max(0, numCols - 1) * pad
    local totalGridH = numRows * sz + math.max(0, numRows - 1) * pad
    
    -- Provide a draggable padding boundary when unlocked
    local framePad = CCT_DB.locked and 4 or 20
    CCT.UI.mainFrame:SetSize(totalGridW + framePad * 2, totalGridH + framePad * 2)
    
    for i, spellID in ipairs(CCT.trackedSpells) do
        local frame = CCT.frames[i]
        if not frame then
            frame = CreateFrame("Button", nil, CCT.UI.mainFrame)
            frame:SetSize(sz, sz)
            
            local border = frame:CreateTexture(nil, "BACKGROUND")
            border:SetAllPoints()
            border:SetColorTexture(0, 0, 0, 1)
            
            local icon = frame:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
            icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            frame.icon = icon
            
            frame:SetClipsChildren(true)
            local cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
            cd:SetAllPoints()
            cd:SetDrawEdge(false)
            cd:SetDrawBling(false)
            cd:SetHideCountdownNumbers(false)
            cd:SetSwipeColor(0, 0, 0, 0.8)
            frame.cooldown = cd
            
            frame:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spellID)
                GameTooltip:Show()
            end)
            frame:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
            
            frame:RegisterForDrag("LeftButton", "RightButton")
            frame:SetScript("OnDragStart", function(self)
                if not CCT_DB.locked then
                    CCT.UI.draggingFrame = self
                    self:SetAlpha(0.5)
                end
            end)
            frame:SetScript("OnDragStop", function(self)
                if CCT.UI.draggingFrame == self then
                    self:SetAlpha(1)
                    local draggedFrame = CCT.UI.draggingFrame
                    CCT.UI.draggingFrame = nil
                    CCT.UI:DropLogic(draggedFrame)
                end
            end)
            
            CCT.frames[i] = frame
        end
        
        -- Apply the dynamic size just in case user changed it
        frame:SetSize(sz, sz)
        
        frame.spellID = spellID
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo then
            frame.icon:SetTexture(spellInfo.iconID)
        else
            frame.icon:SetTexture(134400)
        end
        
        local x, y
        if orient == "HORIZONTAL" then
            local r = math.floor((i - 1) / cols)
            local c = (i - 1) % cols
            
            local rowItems = (r == numRows - 1 and numItems % cols ~= 0) and (numItems % cols) or cols
            local rowW = rowItems * sz + math.max(0, rowItems - 1) * pad
            
            if align == "LEFT" then
                x = framePad + c * (sz + pad)
            elseif align == "CENTER" then
                x = framePad + (totalGridW - rowW) / 2 + c * (sz + pad)
            else -- RIGHT
                x = framePad + (totalGridW - rowW) + c * (sz + pad)
            end
            y = -framePad - r * (sz + pad)
        else
            local c = math.floor((i - 1) / cols)
            local r = (i - 1) % cols
            
            local colItems = (c == numCols - 1 and numItems % cols ~= 0) and (numItems % cols) or cols
            local colH = colItems * sz + math.max(0, colItems - 1) * pad
            
            -- Re-using the literal "LEFT", "CENTER", "RIGHT" string configs to mean Top/Center/Bottom for Vertical rows
            if align == "LEFT" then
                y = -framePad - r * (sz + pad)
            elseif align == "CENTER" then
                y = -framePad - (totalGridH - colH) / 2 - r * (sz + pad)
            else -- RIGHT / BOTTOM
                y = -framePad - (totalGridH - colH) - r * (sz + pad)
            end
            x = framePad + c * (sz + pad)
        end
        
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", CCT.UI.mainFrame, "TOPLEFT", x, y)
        frame:Show()
    end
    
    CCT:UpdateCooldowns()
end

function CCT.UI:DropLogic(draggedFrame)
    if not CCT_DB.locked and draggedFrame then
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        x = x / scale
        y = y / scale
        
        -- Find which frame we dropped on
        local targetIndex = nil
        for i, frame in ipairs(CCT.frames) do
            if frame:IsShown() and frame ~= draggedFrame then
                local left = frame:GetLeft()
                local right = frame:GetRight()
                local bottom = frame:GetBottom()
                local top = frame:GetTop()
                if left and right and bottom and top then
                    -- If mouse is mostly inside another icon
                    if x >= left and x <= right and y >= bottom and y <= top then
                        targetIndex = i
                        break
                    end
                end
            end
        end
        
        if targetIndex then
            local fromIndex = nil
            for i, id in ipairs(CCT.trackedSpells) do
                if id == draggedFrame.spellID then
                    fromIndex = i
                    break
                end
            end
            
            if fromIndex and targetIndex and fromIndex ~= targetIndex then
                local temp = CCT.trackedSpells[fromIndex]
                table.remove(CCT.trackedSpells, fromIndex)
                table.insert(CCT.trackedSpells, targetIndex, temp)
                CCT.UI:UpdateLayout()
            end
        end
    end
end
