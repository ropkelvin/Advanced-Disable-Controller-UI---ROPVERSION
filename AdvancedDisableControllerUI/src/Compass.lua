-- Compass sizing and positioning, using the live compass controls.
-- No polling loop: settings and mouse-release events drive updates.

local ADDON = ADCUI

local function GetCompassControls()
    local frame = ZO_CompassFrame
    if not frame then return nil end

    local compass = ZO_Compass
    local pinLabel = frame.GetNamedChild and frame:GetNamedChild("CenterOverPinLabel")
    if not pinLabel then
        pinLabel = ZO_CompassCenterOverPinLabel or ZO_CompassFrameCenterOverPinLabel
    end

    return frame, compass, pinLabel, ZO_CompassFrameLeft, ZO_CompassFrameRight
end

local function SaveAnchor()
    local frame = ZO_CompassFrame
    if not frame or not frame.GetAnchor then return end

    local _, point, relativeTo, relativePoint, offsetX, offsetY = frame:GetAnchor()
    if not point then return end

    local settings = ADDON:GetSettings()
    settings.point = point
    settings.anchorOffsetX = offsetX or 0
    settings.anchorOffsetY = offsetY or 0
end

local function ApplyDimensions(settings)
    local frame, compass, pinLabel, left, right = GetCompassControls()
    if not frame then return end

    if compass then
        compass:SetScale(settings.scale)
        compass:SetDimensions(settings.width, settings.height)
    end
    if pinLabel then
        pinLabel:SetScale(settings.pinLabelScale)
    end
    if left then left:SetDimensions(10, settings.height) end
    if right then right:SetDimensions(10, settings.height) end
    frame:SetDimensions(settings.width, settings.height)
end

local function InstallCompassHandlers()
    if ADDON.runtime.compassHooksInstalled or not ZO_CompassFrame then return end

    local frame = ZO_CompassFrame
    frame:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            SaveAnchor()
        end
    end, "ADCUICompass")

    if EVENT_MANAGER and EVENT_GLOBAL_MOUSE_UP then
        EVENT_MANAGER:RegisterForEvent(ADDON.ADDON_NAME .. "_CompassSave", EVENT_GLOBAL_MOUSE_UP, SaveAnchor)
    end

    ADDON.runtime.compassHooksInstalled = true
end

function ADDON:ApplyCompass()
    local settings = self:GetSettings()
    local frame = ZO_CompassFrame
    if not frame then return end

    InstallCompassHandlers()

    if not settings.enableCompassCustomization then
        if self.runtime.compassOriginal then
            local original = self.runtime.compassOriginal
            frame:ClearAnchors()
            frame:SetAnchor(original.point, original.relativeTo, original.relativePoint, original.offsetX, original.offsetY)
            frame:SetDimensions(original.width, original.height)
            if ZO_Compass then ZO_Compass:SetScale(original.compassScale) end
        end
        return
    end

    if not self.runtime.compassOriginal then
        local _, point, relativeTo, relativePoint, offsetX, offsetY = frame:GetAnchor()
        local width, height = frame:GetDimensions()
        self.runtime.compassOriginal = {
            point = point or TOP,
            relativeTo = relativeTo or GuiRoot,
            relativePoint = relativePoint or TOP,
            offsetX = offsetX or 0,
            offsetY = offsetY or 40,
            width = width,
            height = height,
            compassScale = ZO_Compass and ZO_Compass:GetScale() or 1,
        }
    end

    frame:ClearAnchors()
    frame:SetAnchor(settings.point or TOP, GuiRoot, nil, settings.anchorOffsetX or 0, settings.anchorOffsetY or 40)
    frame:SetClampedToScreen(true)
    frame:SetMovable(not settings.lockEnabled)
    frame:SetMouseEnabled(not settings.lockEnabled)

    ApplyDimensions(settings)
end
