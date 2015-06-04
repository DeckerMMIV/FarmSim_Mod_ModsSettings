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

local modItem = ModsUtil.findModItemByModName(g_currentModName);

modsSettings = {
-- Constants
     modDir = g_currentModDirectory
    ,version = (modItem and modItem.version) and modItem.version or "?.?.?"
-- Private methods/fields
    ,_rootTag = "modsSettings"
    ,_filename = getUserProfileAppPath() .. "modsSettings.xml"  -- ".../My Games/FarmingSimulator2015/modsSettings.xml"
    ,_xmlFile = nil
    ,_xmlFileDirty = false
    ,_update = function(self,dt)
        if modsSettings._xmlFile ~= nil then
            if modsSettings._xmlFileDirty then
                modsSettings._xmlFileDirty = false
                pcall(modsSettings._saveLocal(modsSettings), '')
            end
            delete(modsSettings._xmlFile)
            modsSettings._xmlFile = nil
        elseif table.getn(modsSettings._localKeysPendingSave) > 0 then
            modsSettings:_loadLocal()
            if self._xmlFile ~= nil then
                -- Persist the local pending keys/values.
                for k,vt in pairs(modsSettings._localKeysPendingSave) do
                    _G["setXML"..vt.t](self._xmlFile, k, vt.v)
                end
                modsSettings._xmlFileDirty = true
            end
            modsSettings._localKeysPendingSave = {}
        end
    end
    ,_makeXPath = function(modName, keyPath, attrName)
        modName  = Utils.getNoNil(modName,  "unspecifiedModName")
        keyPath  = Utils.getNoNil(keyPath,  "unspecifiedKeyPath")
        attrName = Utils.getNoNil(attrName, "unspecifiedAttrName")
        return tostring(modsSettings._rootTag).."."..tostring(modName).."."..tostring(keyPath).."#"..tostring(attrName)
    end
-- Private methods - Local
    ,_loadLocal = function(self)
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
    ,_saveLocal = function(self)
        if self._xmlFile ~= nil then
            if g_dedicatedServerInfo == nil then -- Only for non-dedicated-server
                print("ModsSettings: Attempting to save file " .. self._filename)
                saveXMLFile(self._xmlFile)
            end
        end
    end
    ,_localKeysPendingSave = {}
    ,_getLocal = function(fieldType, modName, keyPath, attrName, defaultValue)
        modsSettings:_loadLocal()
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
    ,_setLocal = function(fieldType, modName, keyPath, attrName, value)
        if g_dedicatedServerInfo == nil then -- Only for non-dedicated-server
            local xPath = modsSettings._makeXPath(modName, keyPath, attrName)
            modsSettings._localKeysPendingSave[xPath] = { v=value, t=fieldType }
        end
    end
-- Private methods - Server
    ,_serverKeysPendingSave = {}
    ,_getServer = function(fieldType, modName, keyPath, attrName, defaultValue)
        -- TODO
        local xPath = modsSettings._makeXPath(modName, keyPath, attrName)
        if modsSettings._serverKeysPendingSave[xPath] ~= nil then
            return modsSettings._serverKeysPendingSave[xPath].v
        end
        return defaultValue
    end
    ,_setServer = function(fieldType, modName, keyPath, attrName, value)
        -- TODO
        local xPath = modsSettings._makeXPath(modName, keyPath, attrName)
        modsSettings._serverKeysPendingSave[xPath] = { v=value, t=fieldType }
    end
    ,_loadServer = function(xmlFile, xmlRootKey)
        print("modsSettings._loadServer:"..tostring(xmlFile).."/"..tostring(xmlRootKey));
    end
    ,_saveServer = function(xmlFile, xmlRootKey)
        print("modsSettings._saveServer:"..tostring(xmlFile).."/"..tostring(xmlRootKey));
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
--
-- Public methods, server's properties (stored in .../savegame#/careerSavegame.XML)
--
    ,getStringServer = function(modName, keyPath, attrName, defaultValue)
        return modsSettings._getServer("String", modName, keyPath, attrName, defaultValue)
    end
    ,getIntServer = function(modName, keyPath, attrName, defaultValue)
        return modsSettings._getServer("Int", modName, keyPath, attrName, defaultValue)
    end
    ,getFloatServer = function(modName, keyPath, attrName, defaultValue)
        return modsSettings._getServer("Float", modName, keyPath, attrName, defaultValue)
    end
    ,getBoolServer = function(modName, keyPath, attrName, defaultValue)
        return modsSettings._getServer("Bool", modName, keyPath, attrName, defaultValue)
    end
    --
    ,setStringServer = function(modName, keyPath, attrName, value)
        return modsSettings._setServer("String", modName, keyPath, attrName, value)
    end
    ,setIntServer = function(modName, keyPath, attrName, value)
        return modsSettings._setServer("Int", modName, keyPath, attrName, value)
    end
    ,setFloatServer = function(modName, keyPath, attrName, value)
        return modsSettings._setServer("Float", modName, keyPath, attrName, value)
    end
    ,setBoolServer = function(modName, keyPath, attrName, value)
        return modsSettings._setServer("Bool", modName, keyPath, attrName, value)
    end
}

-- Add to the ESC-menu, so when it gets activated, then if modsSettings has changes it will attempt to update its "modsSettings.XML" file.
g_inGameMenu.update = Utils.appendedFunction(g_inGameMenu.update, modsSettings._update)

-- Inject method, to be able to add additional xml-keys to the careerSavegame.XML file.
FSCareerMissionInfo.saveToXML = Utils.prependedFunction(FSCareerMissionInfo.saveToXML, function(self)
    -- Apparently FSCareerMissionInfo's 'xmlFile' variable isn't always assigned, previous to it calling saveToXml()?
    if self.isValid and self.xmlKey ~= nil and self.xmlFile ~= nil then
        modsSettings._saveServer(self.xmlFile, self.xmlKey)
    end
end)

-- Inject method, to be able to extract xml-keys from the careerSavegame.XML file.
FSCareerMissionInfo.loadFromXML = Utils.overwrittenFunction(FSCareerMissionInfo.loadFromXML, function(self, superFunc, xmlFile, xmlKey)
    local res = { superFunc(self,xmlFile,xmlKey) }
    if res[1] == true then
        modsSettings._loadServer(xmlFile, xmlKey)
    end
    return unpack(res)
end)

-- "Register" this object in global environment, so other mods can "see" it.
getfenv(0)["ModsSettings"] = modsSettings

--
print(string.format("Script loaded: ModsSettings.LUA (v%s)", modsSettings.version))
