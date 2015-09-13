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
      local keyName = "playerConfig"    -- Key to further distinguish different properties, if your mod has a need for such.
      
      myMod.playerHatId = ModsSettings.getIntLocal(modName, keyName, "hatId", myMod.playerHatId)
                                               --  ^        ^         ^       ^- Default-value to use, if attribute not found in "modsSettings.XML"
                                               --  |        |         \--------- Attribute-name
                                               --  |        \------------------- Key-name
                                               --  \---------------------------- Unique identifier, to distinguish different mods' settings in "modsSettings.XML" file 
    else
      -- The ModsSettings module not found, so need to just use the builtin values.
    end
  end

--]]

--[[
Internal worksheet/draft

in ModsSettings.XML:
  <modsSettings>
      <{modName}>
          <{keyName} {attrName}="{value}" {attrName}="{value}" {attrName}="{value}" {attrName}="{value}" {attrName}="{value}" {attrName}="{value}" />
          <{keyName} {attrName}="{value}" />
          <{keyName} {attrName}="{value}" {attrName}="{value}" {attrName}="{value}" {attrName}="{value}" />
      </{modName}>
  </modsSettings>

in CareerSavegame.XML:
  <modsSettings>
    <mod name="{modName}">
        <key name="{keyName}">
            <attr name="{attrName}" value="{value}"/>
        </key>
    </mod>
  </modsSettings>

--]]

-- For debugging
function log(...)
    if true then
        local txt = ""
        for idx = 1,select("#", ...) do
            txt = txt .. tostring(select(idx, ...))
        end
        print(string.format("%7ums ", (g_currentMission ~= nil and g_currentMission.time or 0)) .. txt);
    end
end;

function logInfo(...)
    local txt = "ModsSettings: "
    for idx = 1,select("#", ...) do
        txt = txt .. tostring(select(idx, ...))
    end
    print(txt);
end

local modItem = ModsUtil.findModItemByModName(g_currentModName);

modsSettings = {
-- Constants
     modDir = g_currentModDirectory
    ,version = (modItem and modItem.version) and modItem.version or "?.?.?"
-- Private methods/fields
    ,_rootTag = "modsSettings"
    ,_filenameLocal = getUserProfileAppPath() .. "modsSettings.xml"  -- Should resolve to "{...}/My Games/FarmingSimulator2015/modsSettings.xml"
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
        --elseif table.getn(modsSettings._localKeysPendingSave) > 0 then
        --    modsSettings:_loadLocal()
        --    if self._xmlFile ~= nil then
        --        -- Persist the local pending keys/values.
        --        for k,vt in pairs(modsSettings._localKeysPendingSave) do
        --            _G["setXML"..vt.t](self._xmlFile, k, vt.v)
        --        end
        --        modsSettings._xmlFileDirty = true
        --    end
        --    modsSettings._localKeysPendingSave = {}
        end
    end
    ,_makeXPath = function(modName, keyName, attrName)
        modName  = Utils.getNoNil(modName,  "unspecifiedModName")
        keyName  = Utils.getNoNil(keyName,  "unspecifiedKeyName")
        attrName = Utils.getNoNil(attrName, "unspecifiedAttrName")
        return tostring(modName).."."..tostring(keyName).."#"..tostring(attrName)
    end
-- Private methods - Local
    ,_loadLocal = function(self)
        if self._xmlFile == nil then
            if fileExists(self._filenameLocal) then
                logInfo("Loading file ", self._filenameLocal)
                self._xmlFile = loadXMLFile(self._rootTag, self._filenameLocal)
            end
            if self._xmlFile == nil then
                if g_dedicatedServerInfo == nil then -- Only for non-dedicated-server
                    logInfo("Creating new/empty file ", self._filenameLocal)
                    self._xmlFile = createXMLFile(self._rootTag, self._filenameLocal, self._rootTag)
                    self._xmlFileDirty = true
                end
            end
        end
    end
    ,_saveLocal = function(self)
        if self._xmlFile ~= nil then
            if g_dedicatedServerInfo == nil then -- Only for non-dedicated-server
                logInfo("Attempting to save file ", self._filenameLocal)
                saveXMLFile(self._xmlFile)
            end
        end
    end
    ,_getLocal = function(fieldType, modName, keyName, attrName, defaultValue)
        modsSettings:_loadLocal()
        if modsSettings._xmlFile ~= nil then
            local xPath = tostring(modsSettings._rootTag) .. "." .. modsSettings._makeXPath(modName, keyName, attrName)
            local value = _G["getXML"..fieldType](modsSettings._xmlFile, xPath)
            if value ~= nil then
                return value
            end
            _G["setXML"..fieldType](modsSettings._xmlFile, xPath, defaultValue)
            modsSettings._xmlFileDirty = true
        end
        return defaultValue
    end
    --,_localKeysPendingSave = {}
    --,_setLocal = function(fieldType, modName, keyName, attrName, value)
    --    if g_dedicatedServerInfo == nil then -- Only for non-dedicated-server
    --        local xPath = modsSettings._makeXPath(modName, keyName, attrName)
    --        modsSettings._localKeysPendingSave[xPath] = { v=value, t=fieldType }
    --    end
    --end
-- Private methods - Server
    ,_serverValues = {}
    ,_getServer = function(fieldType, modName, keyName, attrName, defaultValue)
        local xPath = modsSettings._makeXPath(modName, keyName, attrName)
        if modsSettings._serverValues[xPath] ~= nil then
            if fieldType == "String" then
                return tostring(modsSettings._serverValues[xPath])
            elseif fieldType == "Int" then
                return tonumber(modsSettings._serverValues[xPath])
            elseif fieldType == "Float" then
                return tonumber(modsSettings._serverValues[xPath])
            elseif fieldType == "Bool" then
                return tostring(modsSettings._serverValues[xPath]):lower() == "true" 
            end
            logInfo("_getServer() Invalid field-type: ",fieldType)
            return defaultValue
        end
        if defaultValue ~= nil then
            modsSettings._setServer(fieldType, modName, keyName, attrName, defaultValue)
        end
        return defaultValue
    end
    ,_serverValuesPendingSave = {}
    ,_setServer = function(fieldType, modName, keyName, attrName, value)
        -- Only server can set server-properties
        if not g_currentMission:getIsServer() then
            return;
        end
        
        modName  = tostring(Utils.getNoNil(modName,  "unspecifiedModName" ))
        keyName  = tostring(Utils.getNoNil(keyName,  "unspecifiedKeyName" ))
        attrName = tostring(Utils.getNoNil(attrName, "unspecifiedAttrName"))
        
        modsSettings._serverValuesPendingSave[modName] = Utils.getNoNil(modsSettings._serverValuesPendingSave[modName], {})
        local mod = modsSettings._serverValuesPendingSave[modName]
        
        mod[keyName] = Utils.getNoNil(mod[keyName], {})
        local key = mod[keyName]
        
        local oldValue = key[attrName]
        key[attrName] = (value ~= nil) and tostring(value) or nil
        
        log("modsSettings._setServer: ",modsSettings._makeXPath(modName, keyName, attrName),"='",value,"' (old-value='",oldValue,"')")
    end
    ,_loadServer = function(xmlFile, xmlRootKey)
        log("modsSettings._loadServer:",xmlFile,"/",xmlRootKey);
        
        local rootTag = xmlRootKey ..".".. tostring(modsSettings._rootTag);
        local m=0
        while (true) do
            local modTag = string.format(rootTag..".mod(%d)", m)
            m=m+1
            local modName = getXMLString(xmlFile, modTag.."#name")
            if modName == nil then
                break
            end
            
            local k=0
            while (true) do
                local keyTag = string.format(modTag..".key(%d)", k)
                k=k+1
                local keyName = getXMLString(xmlFile, keyTag.."#name")
                if keyName == nil then
                    break
                end
                
                local a=0
                while (true) do
                    local attrTag = string.format(keyTag..".attr(%d)", a)
                    a=a+1
                    local attrName = getXMLString(xmlFile, attrTag.."#name")
                    if attrName == nil then
                        break
                    end

                    local attrValue = getXMLString(xmlFile, attrTag.."#value")
                    if attrValue ~= nil then
                        local xPath = modsSettings._makeXPath(modName, keyName, attrName)
                        modsSettings._serverValues[xPath] = attrValue
                        log("modsSettings._loadServer: ",xPath,"='",attrValue,"'")
                        -- Need to set them again, else they'll vanish when careerSavegame.XML is saved.
                        modsSettings._setServer("String", modName, keyName, attrName, attrValue)
                    end
                end
            end
        end
    end
    ,_saveServer = function(xmlFile, xmlRootKey)
        log("modsSettings._saveServer:",xmlFile,"/",xmlRootKey);
        
        local rootTag = xmlRootKey ..".".. tostring(modsSettings._rootTag);
        local m=0
        for modName,mods in pairs(modsSettings._serverValuesPendingSave) do
            local modTag = string.format(rootTag..".mod(%d)", m)
            m=m+1
            
            local k=0
            for keyName,keys in pairs(mods) do
                local keyTag = string.format(modTag..".key(%d)", k)
                k=k+1
                
                local a=0
                for attrName,attrValue in pairs(keys) do
                    if attrValue ~= nil then
                        local attrTag = string.format(keyTag..".attr(%d)", a)
                        a=a+1
                        
                        setXMLString(xmlFile, attrTag.."#name", attrName)
                        setXMLString(xmlFile, attrTag.."#value", attrValue)

                        log("modsSettings._saveServer: ",modsSettings._makeXPath(modName, keyName, attrName),"='",attrValue,"'")
                    end
                end
                
                if a>0 then
                    setXMLString(xmlFile, keyTag.."#name", keyName)
                end
            end
            
            if k>0 then
                setXMLString(xmlFile, modTag.."#name", modName)
            end
        end
    end
--
-- Public methods, player-local properties (stored in .../My Games/FarmingSimulator2015/modsSettings.XML)
--
    ,getStringLocal = function(modName, keyName, attrName, defaultValue)
        return modsSettings._getLocal("String", modName, keyName, attrName, defaultValue)
    end
    ,getIntLocal = function(modName, keyName, attrName, defaultValue)
        return modsSettings._getLocal("Int", modName, keyName, attrName, defaultValue)
    end
    ,getFloatLocal = function(modName, keyName, attrName, defaultValue)
        return modsSettings._getLocal("Float", modName, keyName, attrName, defaultValue)
    end
    ,getBoolLocal = function(modName, keyName, attrName, defaultValue)
        return modsSettings._getLocal("Bool", modName, keyName, attrName, defaultValue)
    end
--
-- Public methods, server's properties (stored in .../savegame#/careerSavegame.XML)
--
    ,getStringServer = function(modName, keyName, attrName, defaultValue)
        return modsSettings._getServer("String", modName, keyName, attrName, defaultValue)
    end
    ,getIntServer = function(modName, keyName, attrName, defaultValue)
        return modsSettings._getServer("Int", modName, keyName, attrName, defaultValue)
    end
    ,getFloatServer = function(modName, keyName, attrName, defaultValue)
        return modsSettings._getServer("Float", modName, keyName, attrName, defaultValue)
    end
    ,getBoolServer = function(modName, keyName, attrName, defaultValue)
        return modsSettings._getServer("Bool", modName, keyName, attrName, defaultValue)
    end
    --
    ,setStringServer = function(modName, keyName, attrName, value)
        return modsSettings._setServer("String", modName, keyName, attrName, value)
    end
    ,setIntServer = function(modName, keyName, attrName, value)
        return modsSettings._setServer("Int", modName, keyName, attrName, value)
    end
    ,setFloatServer = function(modName, keyName, attrName, value)
        return modsSettings._setServer("Float", modName, keyName, attrName, value)
    end
    ,setBoolServer = function(modName, keyName, attrName, value)
        return modsSettings._setServer("Bool", modName, keyName, attrName, value)
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

---- Replace the loadMap() method, to be able to extract xml-keys from the careerSavegame.XML file.
modsSettings.orig_FSBaseMission_loadMap = FSBaseMission.loadMap
FSBaseMission.loadMap = function(...)
    if g_currentMission ~= nil and g_currentMission:getIsServer() then
        if g_currentMission.missionInfo.isValid then
            local fileName = g_currentMission.missionInfo.savegameDirectory .. "/careerSavegame.xml"
            local xmlFile = loadXMLFile("xml", fileName);
            if xmlFile ~= nil then
                pcall(modsSettings._loadServer(xmlFile, "careerSavegame"), '')
                delete(xmlFile);
            end
        end
    end

    return modsSettings.orig_FSBaseMission_loadMap(...);
end

-- "Register" this object in global environment, so other mods can "see" it.
getfenv(0)["ModsSettings"] = modsSettings

--
print(string.format("Script loaded: ModsSettings.LUA (v%s)", modsSettings.version))
