-- Addon initialization
local addonName, addon = ...
local CharacterFavorites = CreateFrame("Frame")
local FAVORITES_DB_VERSION = 1

-- Initialize saved variables
CharacterFavorites:RegisterEvent("ADDON_LOADED")
CharacterFavorites:RegisterEvent("PLAYER_LOGIN")

-- Main data structure
local defaults = {
    version = FAVORITES_DB_VERSION,
    mounts = {},
    pets = {}
}

-- Variable to store current player's key
local playerKey = nil

-- Create macros function (replacing the previous function)
local function CreateFavoritesMacros()
    -- Create wrapper functions for summoning
    _G.CharacterFavoritesSummonMount = function()
        if CharacterFavoritesDB[playerKey] and #CharacterFavoritesDB[playerKey].mounts > 0 then
            local randomMount = CharacterFavoritesDB[playerKey].mounts[math.random(#CharacterFavoritesDB[playerKey].mounts)]
            C_MountJournal.SummonByID(randomMount)
        else
            print("No favorite mounts added yet! Use '/charfav addmount <name>'")
        end
    end

    _G.CharacterFavoritesSummonPet = function()
        if CharacterFavoritesDB[playerKey] and #CharacterFavoritesDB[playerKey].pets > 0 then
            local randomPetGUID = CharacterFavoritesDB[playerKey].pets[math.random(#CharacterFavoritesDB[playerKey].pets)]
            C_PetJournal.SummonPetByGUID(randomPetGUID)
        else
            print("No favorite pets added yet! Use '/charfav addpet <name>'")
        end
    end

    -- Mount macro
    local mountMacroText = [[
/run CharacterFavoritesSummonMount()
]]

    -- Pet macro
    local petMacroText = [[
/run CharacterFavoritesSummonPet()
]]

    -- Create or update the mount macro
    local existingMountMacroIndex = GetMacroIndexByName("FavoriteMount")
    if existingMountMacroIndex > 0 then
        EditMacro(existingMountMacroIndex, "FavoriteMount", "Ability_Mount_RidingHorse", mountMacroText)
    else
        CreateMacro("FavoriteMount", "Ability_Mount_RidingHorse", mountMacroText, nil, 1)
        print("Favorite Mount macro created! You can find it in your macro list.")
    end

    -- Create or update the pet macro
    local existingPetMacroIndex = GetMacroIndexByName("FavoritePet")
    if existingPetMacroIndex > 0 then
        EditMacro(existingPetMacroIndex, "FavoritePet", "INV_Box_PetCarrier_01", petMacroText)
    else
        CreateMacro("FavoritePet", "INV_Box_PetCarrier_01", petMacroText, nil, 1)
        print("Favorite Pet macro created! You can find it in your macro list.")
    end
end

-- First let's make this dope function to show some flash
local function ShowAddedAnimation(parent)
    -- Drop a fresh frame for our sweet effects
    local flash = CreateFrame("Frame", nil, parent)
    flash:SetAllPoints()
    flash:SetAlpha(0)
    
    -- Slap a sick texture on there
    local texture = flash:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetColorTexture(1, 1, 0, 0.4) -- Golden flash, ya feel me?
    
    -- Time to make it POP
    flash.ag = flash:CreateAnimationGroup()
    
    -- Fade in real quick
    local fadeIn = flash.ag:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.2)
    fadeIn:SetOrder(1)
    
    -- Hold it for a hot second
    local hold = flash.ag:CreateAnimation("Alpha")
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)
    hold:SetDuration(0.1)
    hold:SetOrder(2)
    
    -- Fade out smooth
    local fadeOut = flash.ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.3)
    fadeOut:SetOrder(3)
    
    -- Clean up when we're done
    flash.ag:SetScript("OnFinished", function()
        flash:Hide()
    end)
    
    flash:Show()
    flash.ag:Play()
end

-- Gotta make this function available everywhere
local function GetSelectedPetID()
    -- Diggin through the list to find our pet
    if PetJournal.ScrollBox then
        for _, button in pairs(PetJournal.ScrollBox:GetFrames()) do
            if button.selected then
                return button.petID
            end
        end
    end
    return nil
end

-- First let's make some helper functions to check if something's already a fav
local function IsMountFavorited(mountID)
    if not playerKey then return false end
    for _, id in ipairs(CharacterFavoritesDB[playerKey].mounts) do
        if id == mountID then
            return true
        end
    end
    return false
end

local function IsPetFavorited(petID)
    if not playerKey then return false end
    for _, id in ipairs(CharacterFavoritesDB[playerKey].pets) do
        if id == petID then
            return true
        end
    end
    return false
end

-- Function to remove from favorites
local function RemoveFromFavorites(list, id)
    for i = #list, 1, -1 do
        if list[i] == id then
            table.remove(list, i)
            return true
        end
    end
    return false
end

-- Update the add functions to toggle instead
local function ToggleMountFavorite(mountID)
    if not playerKey then return end
    local name = C_MountJournal.GetMountInfoByID(mountID)
    
    if IsMountFavorited(mountID) then
        -- Remove it
        if RemoveFromFavorites(CharacterFavoritesDB[playerKey].mounts, mountID) then
            print("Mount " .. name .. " removed from character favorites!")
            ShowAddedAnimation(MountJournalCharacterFavoritesButton)
        end
    else
        -- Add it
        table.insert(CharacterFavoritesDB[playerKey].mounts, mountID)
        print("Mount " .. name .. " added to character favorites!")
        ShowAddedAnimation(MountJournalCharacterFavoritesButton)
    end
end

local function TogglePetFavorite(petID)
    if not playerKey then return end
    local _, customName, _, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(petID)
    local displayName = customName or name
    
    if IsPetFavorited(petID) then
        -- Remove it
        if RemoveFromFavorites(CharacterFavoritesDB[playerKey].pets, petID) then
            print("Pet " .. displayName .. " removed from character favorites!")
            ShowAddedAnimation(PetJournalCharacterFavoritesButton)
        end
    else
        -- Add it
        table.insert(CharacterFavoritesDB[playerKey].pets, petID)
        print("Pet " .. displayName .. " added to character favorites!")
        ShowAddedAnimation(PetJournalCharacterFavoritesButton)
    end
end

-- Update the button text based on favorite status
local function UpdateMountButtonText()
    local mountID = MountJournal.selectedMountID
    if mountID and IsMountFavorited(mountID) then
        MountJournalCharacterFavoritesButton:SetText("Remove from Favorites")
    else
        MountJournalCharacterFavoritesButton:SetText("Add to Character Favorites")
    end
end

local function UpdatePetButtonText()
    local petID = GetSelectedPetID() -- Using your existing function
    if petID and IsPetFavorited(petID) then
        PetJournalCharacterFavoritesButton:SetText("Remove from Favorites")
    else
        PetJournalCharacterFavoritesButton:SetText("Add to Character Favorites")
    end
end

-- Add this function near the top with our other helpers
local function CreateFavoriteIcon(button)
    if not button.characterFavoriteIcon then
        local icon = button:CreateTexture(nil, "OVERLAY", nil, 7)
        icon:SetSize(16, 16)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        icon:SetAtlas("PetJournal-FavoritesIcon", true)
        -- Let's make it cyan again but keep the texture quality
        icon:SetVertexColor(0, 1, 1)
        button.characterFavoriteIcon = icon
    end
    return button.characterFavoriteIcon
end

-- Update the mount list buttons
local function UpdateMountFavoriteIcon(button)
    if not button or not button.mountID then return end
    
    local icon = CreateFavoriteIcon(button)
    if IsMountFavorited(button.mountID) then
        icon:Show()
    else
        icon:Hide()
    end
end

-- Update the pet list buttons
local function UpdatePetFavoriteIcon(button)
    if not button or not button.petID then return end
    
    local icon = CreateFavoriteIcon(button)
    if IsPetFavorited(button.petID) then
        icon:Show()
    else
        icon:Hide()
    end
end

-- Helper function to set up our buttons
local function SetupFavoriteButton(button, text)
    -- Reset to normal sized text
    button.Text:SetFontObject("GameFontNormal")
    
    -- Set initial text
    button:SetText(text)
    
    -- Get the text width and add padding
    local textWidth = button.Text:GetStringWidth()
    local padding = 24
    button:SetSize(textWidth + padding, 22)
    
    -- Make sure the text updates properly
    local oldSetText = button.SetText
    button.SetText = function(self, newText)
        oldSetText(self, newText)
        local newWidth = self.Text:GetStringWidth()
        self:SetSize(newWidth + padding, 22)
    end
end

-- Hook the pet journal
local function HookPetJournal()
    -- Create "Add to Favorites" button for pets
    local petButton = CreateFrame("Button", "PetJournalCharacterFavoritesButton", PetJournal, "UIPanelButtonTemplate")
    petButton:SetPoint("LEFT", PetJournalSummonButton, "RIGHT", 5, 0)
    SetupFavoriteButton(petButton, "Add to Character Favorites")
    
    -- Function to update all visible pet icons
    local function UpdateAllPetIcons()
        if PetJournal.ScrollBox then
            for _, frame in pairs(PetJournal.ScrollBox:GetFrames()) do
                local button = frame.Button or frame
                if button and button.petID then
                    UpdatePetFavoriteIcon(button)
                end
            end
        end
    end
    
    -- Function to update pet button text
    local function UpdatePetButton()
        local selectedPetID = GetSelectedPetID()
        if selectedPetID then
            if IsPetFavorited(selectedPetID) then
                petButton:SetText("Remove from Character Favorites")
            else
                petButton:SetText("Add to Character Favorites")
            end
            petButton:SetEnabled(true)
        else
            petButton:SetText("Add to Character Favorites")
            petButton:SetEnabled(false)
        end
    end
    
    -- Hook the pet buttons
    local function HookPetButtons()
        if PetJournal.ScrollBox then
            for _, button in pairs(PetJournal.ScrollBox:GetFrames()) do
                if not button.hooked then
                    button:HookScript("OnClick", function()
                        C_Timer.After(0.1, function()
                            UpdatePetButton()
                            UpdateAllPetIcons()
                        end)
                    end)
                    button.hooked = true
                end
            end
        end
    end
    
    -- Hook journal show and updates
    PetJournal:HookScript("OnShow", function()
        C_Timer.After(0.1, function()
            HookPetButtons()
            UpdatePetButton()
            UpdateAllPetIcons()  -- Update icons when journal shows
        end)
    end)
    
    -- Hook scroll updates
    if PetJournal.ScrollBox then
        PetJournal.ScrollBox:RegisterCallback("OnDataRangeChanged", function()
            C_Timer.After(0.1, function()
                HookPetButtons()
                UpdatePetButton()
                UpdateAllPetIcons()  -- Update icons when scrolling
            end)
        end)
    end
    
    petButton:SetScript("OnClick", function()
        local selectedPetID = GetSelectedPetID()
        if selectedPetID then
            TogglePetFavorite(selectedPetID)
            UpdatePetButton()
            UpdateAllPetIcons()
        end
    end)
    
    -- Initial setup
    C_Timer.After(0.2, function()
        HookPetButtons()
        UpdatePetButton()
        UpdateAllPetIcons()  -- Initial icon update
    end)
end

-- Hook the mount journal
local function HookMountJournal()
    -- Create "Add to Favorites" button for mounts
    local mountButton = CreateFrame("Button", "MountJournalCharacterFavoritesButton", MountJournal, "UIPanelButtonTemplate")
    mountButton:SetPoint("LEFT", MountJournalMountButton, "RIGHT", 5, 0)  -- 5px gap between buttons
    SetupFavoriteButton(mountButton, "Add to Character Favorites")
    
    -- Function to update mount button text
    local function UpdateMountButtonText()
        local selectedMountID = MountJournal.selectedMountID
        if selectedMountID then
            if IsMountFavorited(selectedMountID) then
                mountButton:SetText("Remove from Character Favorites")
            else
                mountButton:SetText("Add to Character Favorites")
            end
            mountButton:SetEnabled(true)
        else
            mountButton:SetText("Add to Character Favorites")
            mountButton:SetEnabled(false)
        end
    end
    
    -- Function to update all visible mount icons
    local function UpdateAllMountIcons()
        if MountJournal.ScrollBox then
            for _, frame in pairs(MountJournal.ScrollBox:GetFrames()) do
                -- Need to get the actual button
                local button = frame.Button or frame
                if button and button.mountID then
                    UpdateMountFavoriteIcon(button)
                end
            end
        end
    end
    
    -- Hook mount selection changes
    MountJournal:HookScript("OnShow", function()
        C_Timer.After(0.1, function()
            UpdateMountButtonText()
            UpdateAllMountIcons()
        end)
    end)
    
    -- Hook the mount buttons
    if MountJournal.ScrollBox then
        for _, button in pairs(MountJournal.ScrollBox:GetFrames()) do
            if not button.hooked then
                button:HookScript("OnClick", function()
                    C_Timer.After(0.1, function()
                        UpdateMountButtonText()
                        UpdateAllMountIcons()
                    end)
                end)
                button.hooked = true
            end
        end
        
        MountJournal.ScrollBox:RegisterCallback("OnDataRangeChanged", function()
            C_Timer.After(0.1, function()
                -- Hook any new buttons that got created
                for _, button in pairs(MountJournal.ScrollBox:GetFrames()) do
                    if not button.hooked then
                        button:HookScript("OnClick", function()
                            C_Timer.After(0.1, function()
                                UpdateMountButtonText()
                                UpdateAllMountIcons()
                            end)
                        end)
                        button.hooked = true
                    end
                end
                UpdateMountButtonText()
                UpdateAllMountIcons()
            end)
        end)
    end
    
    mountButton:SetScript("OnClick", function()
        local selectedMountID = MountJournal.selectedMountID
        if selectedMountID then
            ToggleMountFavorite(selectedMountID)
            UpdateMountButtonText()
            UpdateAllMountIcons()  -- Update icons after toggling
        end
    end)
    
    -- Initial update
    C_Timer.After(0.2, function()
        UpdateMountButtonText()
        UpdateAllMountIcons()
    end)
end

-- Update the event handler
CharacterFavorites:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize character-specific saved variables
        _G.CharacterFavoritesDB = _G.CharacterFavoritesDB or {}
        
        -- Set up player key
        playerKey = UnitName("player") .. "-" .. GetRealmName()
        CharacterFavoritesDB[playerKey] = CharacterFavoritesDB[playerKey] or CopyTable(defaults)
        
    elseif event == "PLAYER_LOGIN" then
        CreateFavoritesMacros()
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_Collections" then
        C_Timer.After(1, function()
            HookMountJournal()
            HookPetJournal()
            print("Character Favorites: Added buttons to Pet and Mount journals!")
        end)
    end
end)

-- Register for the Collections UI loading
CharacterFavorites:RegisterEvent("ADDON_LOADED")

-- Slash command handler
SLASH_CHARFAV1 = "/charfav"
SlashCmdList["CHARFAV"] = function(msg)
    if not playerKey then
        print("Character Favorites not yet initialized!")
        return
    end

    local command, arg = msg:match("^(%S*)%s*(.-)$")
    
    if command == "addmount" then
        local mountName = arg:trim()
        if mountName and mountName ~= "" then
            -- Get all collected mounts
            local mountIDs = C_MountJournal.GetMountIDs()
            local foundMountID = nil
            
            for _, mountID in ipairs(mountIDs) do
                local name, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
                if isCollected and name:lower() == mountName:lower() then
                    foundMountID = mountID
                    break
                end
            end
            
            if foundMountID then
                table.insert(CharacterFavoritesDB[playerKey].mounts, foundMountID)
                local name = C_MountJournal.GetMountInfoByID(foundMountID)
                print("Mount " .. name .. " added to favorites!")
            else
                print("Could not find a collected mount named '" .. mountName .. "'!")
            end
        end
    elseif command == "addpet" then
        local petName = arg:trim()
        if petName and petName ~= "" then
            -- Scan pet journal for the pet by name
            C_PetJournal.SetSearchFilter(petName)
            C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED, true)
            C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED, false)
            
            local numPets = C_PetJournal.GetNumPets()
            local foundPetGUID = nil
            
            for i = 1, numPets do
                local petID, _, owned, _, _, _, _, _, _, _, _, _, _, _, _, _, _ = C_PetJournal.GetPetInfoByIndex(i)
                if owned then
                    local _, customName, _, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(petID)
                    if (name and name:lower() == petName:lower()) or 
                       (customName and customName:lower() == petName:lower()) then
                        foundPetGUID = petID
                        break
                    end
                end
            end
            
            if foundPetGUID then
                table.insert(CharacterFavoritesDB[playerKey].pets, foundPetGUID)
                local _, customName, _, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(foundPetGUID)
                print("Pet " .. (customName or name) .. " added to favorites!")
            else
                print("Could not find a pet named '" .. petName .. "' in your journal!")
            end
        end
    elseif command == "clear" then
        CharacterFavoritesDB[playerKey].mounts = {}
        CharacterFavoritesDB[playerKey].pets = {}
        print("Favorites cleared!")
    elseif command == "list" then
        print("Favorite Mounts:")
        for _, mountID in ipairs(CharacterFavoritesDB[playerKey].mounts) do
            local name = C_MountJournal.GetMountInfoByID(mountID)
            print("- " .. (name or "Unknown"))
        end
        print("Favorite Pets:")
        for _, petGUID in ipairs(CharacterFavoritesDB[playerKey].pets) do
            local _, customName, _, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(petGUID)
            print("- " .. (customName or name or "Unknown"))
        end
    end
end
