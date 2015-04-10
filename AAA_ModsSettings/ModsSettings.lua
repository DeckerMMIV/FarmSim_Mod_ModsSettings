--
--  ModsSettings - a "mod for mods" which can store/retrieve player-local settings from a "modsSettings.XML" file.
--
-- @author  Decker_MMIV - fs-uk.com, forum.farming-simulator.com, modhoster.com
-- @date    2015-04-xx
--

--[[

## How to use this

When your own script has a need to get a player-local property, it can check 
first to see if the ModsSettings module is available, and use its methods to
get the property values.

Example code:

  function myMod:load()
    -- Set up your mod's default builtin values.
    myMod.playerHatId = 42
  
    -- Check if the 'ModsSettings' mods is available, before attempting to use it.
    if ModsSettings ~= nil then
      -- Get the player-local custom values, by querying the ModsSettings module.
      --
      -- If there isn't yet any custom values, then these will be added to the "modsSetttings.XML" file,
      -- using the default-value that was given as the last argument in the get<type>Local() method-call.
      
      local modName = "myMod"           -- Unique identification of 'your mod'. This will create a corresponding section in the "modsSettings.XML" file.
      local keyPath = "playerConfig"    -- XPath to further distinguish different properties, if your mod has a need for such.
      
      myMod.playerHatId = ModsSettings.getIntLocal(modName, keyPath, "hatId", myMod.playerHatId)
                                               --  ^        ^         ^       ^- Default-value to use, if attribute not found in "modsSettings.XML"
                                               --  |        |         \--------- Attribute-name
                                               --  |        \------------------- Key-path, its possible to use something like "keyA.keyB(3).keyC"
                                               --  \---------------------------- Unique identifier, to distinguish different mods' settings in "modsSettings.XML" file 
    else
      -- The ModsSettings module not found, so need to just use the builtin values.
    end
  end

--]]

modsSettings = {
-- Private methods
     _rootTag = "modsSettings"
    ,_filename = getUserProfileAppPath() .. "modsSettings.xml"  -- ".../My Games/FarmingSimulator2015/modsSettings.xml"
    ,_xmlFile = nil
    ,_xmlFileDirty = false
    ,_update = function(self,dt)
        if modsSettings._xmlFile ~= nil then
            if modsSettings._xmlFileDirty then
                modsSettings._xmlFileDirty = false
                pcall(modsSettings._save(modsSettings), '')
            end
            delete(modsSettings._xmlFile)
            modsSettings._xmlFile = nil
        end
    end
    ,_load = function(self)
        if self._xmlFile == nil then
            if fileExists(self._filename) then
                print("ModsSettings: Loading file " .. self._filename)
                self._xmlFile = loadXMLFile(self._rootTag, self._filename)
            end
            if self._xmlFile == nil then
                if g_dedicatedServerInfo == nil then -- Only for non-dedicated-server
                    print("ModsSettings: Creating new/empty file " .. self._filename)
                    self._xmlFile = createXMLFile(self._rootTag, self._filename, self._rootTag)
                    self._xmlFileDirty = true
                end
            end
        end
    end
    ,_save = function(self)
        if self._xmlFile ~= nil then
            if g_dedicatedServerInfo == nil then -- Only for non-dedicated-server
                print("ModsSettings: Attempting to save file " .. self._filename)
                saveXMLFile(self._xmlFile)
            end
        end
    end
    ,_makeXPath = function(modName, keyPath, attrName)
        modName  = Utils.getNoNil(modName,  "unspecifiedModName")
        keyPath  = Utils.getNoNil(keyPath,  "unspecifiedKeyPath")
        attrName = Utils.getNoNil(attrName, "unspecifiedAttrName")
        return tostring(modsSettings._rootTag).."."..tostring(modName).."."..tostring(keyPath).."#"..tostring(attrName)
    end
    ,_getLocal = function(fieldType, modName, keyPath, attrName, defaultValue)
        modsSettings:_load()
        if modsSettings._xmlFile ~= nil then
            local xPath = modsSettings._makeXPath(modName, keyPath, attrName)
            local value = _G["getXML"..fieldType](modsSettings._xmlFile, xPath)
            if value ~= nil then
                return value
            end
            _G["setXML"..fieldType](modsSettings._xmlFile, xPath, defaultValue)
            modsSettings._xmlFileDirty = true
        end
        return defaultValue
    end
--
-- Public methods, player-local properties (stored in .../My Games/FarmingSimulator2015/modsSettings.XML)
--
    ,getStringLocal = function(modName, keyPath, attrName, defaultValue)
        return modsSettings._getLocal("String", modName, keyPath, attrName, defaultValue)
    end
    ,getIntLocal = function(modName, keyPath, attrName, defaultValue)
        return modsSettings._getLocal("Int", modName, keyPath, attrName, defaultValue)
    end
    ,getFloatLocal = function(modName, keyPath, attrName, defaultValue)
        return modsSettings._getLocal("Float", modName, keyPath, attrName, defaultValue)
    end
    ,getBoolLocal = function(modName, keyPath, attrName, defaultValue)
        return modsSettings._getLocal("Bool", modName, keyPath, attrName, defaultValue)
    end
--[[ - TODO
-- Public methods, server's properties (stored in .../savegame#/careerSavegame.XML)
    ,getStringServer = function(modName, keyPath, attrName, defaultValue)
        --return modsSettings._getServer("Bool", modName, keyPath, attrName, defaultValue)
        return defaultValue
    end
--]]
}

-- Add to the ESC-menu, so when it gets activated, then if modsSettings has changes it will attempt to update its "modsSettings.XML" file.
g_inGameMenu.update = Utils.appendedFunction(g_inGameMenu.update, modsSettings._update)

-- "Register" this object in global environment, so other mods can "see" it.
getfenv(0)["ModsSettings"] = modsSettings

--
local modItem = ModsUtil.findModItemByModName(g_currentModName);
modsSettings.version = (modItem and modItem.version) and modItem.version or "?.?.?";
modsSettings.modDir = g_currentModDirectory;

print(string.format("Script loaded: ModsSettings.LUA (v%s)", modsSettings.version));
