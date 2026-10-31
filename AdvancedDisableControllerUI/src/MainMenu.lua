-- Shoulder-button category navigation for the keyboard main menu.

local ADDON = ADCUI

local function IsCategoryAvailable(category)
    if not MAIN_MENU_KEYBOARD or not MAIN_MENU_KEYBOARD.categoryInfo or not ZO_CATEGORY_LAYOUT_INFO then
        return false
    end

    local categoryInfo = MAIN_MENU_KEYBOARD.categoryInfo[category]
    local layoutInfo = ZO_CATEGORY_LAYOUT_INFO[category]
    if not categoryInfo or not layoutInfo or layoutInfo.hideCategoryBar then
        return false
    end

    if layoutInfo.visible then
        local ok, visible = pcall(layoutInfo.visible)
        if not ok or not visible then return false end
    end

    return true
end

local function GetCurrentCategory()
    if MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.lastCategory then
        return MAIN_MENU_KEYBOARD.lastCategory
    end

    local sceneName = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
    local sceneInfo = MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.sceneInfo
    local info = sceneName and sceneInfo and sceneInfo[sceneName]
    return info and info.category or 0
end

local function ChangeCategory(direction)
    if not MAIN_MENU_KEYBOARD or not MAIN_MENU_KEYBOARD.ShowCategory or not ZO_CATEGORY_LAYOUT_INFO then
        return
    end

    local categories = {}
    for category in pairs(ZO_CATEGORY_LAYOUT_INFO) do
        if type(category) == "number" then
            categories[#categories + 1] = category
        end
    end
    table.sort(categories)

    local current = GetCurrentCategory()
    local currentIndex
    for index, category in ipairs(categories) do
        if category == current then
            currentIndex = index
            break
        end
    end
    if not currentIndex then return end

    for offset = 1, #categories do
        local index = ((currentIndex - 1 + direction * offset) % #categories) + 1
        local candidate = categories[index]
        if IsCategoryAvailable(candidate) then
            MAIN_MENU_KEYBOARD:ShowCategory(candidate)
            return
        end
    end
end

local keybindGroup = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    {
        name = "Previous category",
        keybind = "UI_SHORTCUT_LEFT_SHOULDER",
        callback = function() ChangeCategory(-1) end,
        visible = function()
            local settings = ADDON:GetSettings()
            return settings.enableMainMenuShoulderButtons
                and not settings.useControllerUI
                and ADDON:IsNativeGamepadMode()
                and IsCategoryAvailable(GetCurrentCategory())
        end,
    },
    {
        name = "Next category",
        keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
        callback = function() ChangeCategory(1) end,
        visible = function()
            local settings = ADDON:GetSettings()
            return settings.enableMainMenuShoulderButtons
                and not settings.useControllerUI
                and ADDON:IsNativeGamepadMode()
        end,
    },
}

local function IsMainMenuScene(scene)
    if not scene or not scene.GetName or not MAIN_MENU_KEYBOARD or not MAIN_MENU_KEYBOARD.sceneInfo then
        return false
    end
    return MAIN_MENU_KEYBOARD.sceneInfo[scene:GetName()] ~= nil
end

local function OnSceneStateChanged(scene, oldState, newState)
    if not IsMainMenuScene(scene) or not KEYBIND_STRIP then return end

    if newState == SCENE_SHOWING then
        local settings = ADDON:GetSettings()
        if settings.enableMainMenuShoulderButtons and not settings.useControllerUI and ADDON:IsNativeGamepadMode() then
            if not ADDON.runtime.menuGroupActive then
                KEYBIND_STRIP:AddKeybindButtonGroup(keybindGroup)
                ADDON.runtime.menuGroupActive = true
            end
        end
    elseif newState == SCENE_HIDING then
        if ADDON.runtime.menuGroupActive then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(keybindGroup)
            ADDON.runtime.menuGroupActive = false
        end
    end
end

function ADDON:ApplyMainMenu()
    if not self.runtime.mainMenuHooksInstalled and SCENE_MANAGER and SCENE_MANAGER.RegisterCallback then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
        self.runtime.mainMenuHooksInstalled = true
    end

    if self.runtime.menuGroupActive and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(keybindGroup)
        self.runtime.menuGroupActive = false
    end

    local settings = self:GetSettings()
    local currentSceneName = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
    local isMainMenuScene = currentSceneName
        and MAIN_MENU_KEYBOARD and MAIN_MENU_KEYBOARD.sceneInfo
        and MAIN_MENU_KEYBOARD.sceneInfo[currentSceneName] ~= nil

    if settings.enableMainMenuShoulderButtons and not settings.useControllerUI
        and self:IsNativeGamepadMode() and isMainMenuScene then
        if KEYBIND_STRIP and not self.runtime.menuGroupActive then
            KEYBIND_STRIP:AddKeybindButtonGroup(keybindGroup)
            self.runtime.menuGroupActive = true
        end
    end
end
