--* -*- -*- -*- -*- -*- -*- -*- -*- -*- -*- -*-
--* "Scale Tune" Job Plugin for VOCALOID Editor
--* 28 Aug 2017
--* -*- -*- -*- -*- -*- -*- -*- -*- -*- -*- -*-

--*
--* Global variables
--*

-- the path of tuning set file
OS_WIN, OS_MAC = 1, 2
MY_OS = OS_WIN	-- HERE SET OS KIND
if MY_OS == OS_WIN then
    DATA_FILE_PATH = os.getenv("APPDATA").."\\VOCALOIDJOBP\\"
    os.execute("CMD /C \"MKDIR %appdata%\\VOCALOIDJOBP\\ > NUL 2>&1")
else
    DATA_FILE_PATH = "/Users/Shared/JobPlugindat/"
    os.execute("mkdir " .. DATA_FILE_PATH)
end

-- config file
CONFIG_FN = "V4EJobPluginScaleTuneConfig.dat"	-- name of config file
CONFIG_DATA_LIST = {}
CONFIG_DEFAULT = {
    skipConfirmationDlg = 0,
}

-- tune setting file
TUNING_SET_FN = "V4EJobPluginScaleTuneSet.dat"	-- name of tuning set file
TUNING_SET_HEADER = {"name", "offset", "C", "C#Db", "D", "D#Eb", "E", "F", "F#Gb", "G", "G#Ab", "A", "A#Bb", "B"}
TUNING_SET_DATA_LIST = {}	-- tuning set data list
TUNING_SET_DATA_LIST_DEFAULT = {
    "Equal 12,0,0,0,0,0,0,0,0,0,0,0,0,0",
    "Werkmeister 1-3,7,0,-10,-8,-6,-10,-2,-12,-4,-8,-12,-4,-8",
    "Kirnberger 3,6.9,0,-7.7,-6.8,-6,-13.7,-2,-9.7,-3.4,-8,-10.3,-4,-11.7",
    "Kirnberger 1,6.3,0,-10,4,-6,-14,-2,-10,2,-8,-16,-4,-12",
    "Kirnberger 2,5.4,0,-10,4,-6,-14,-2,-10,2,-8,-5,-4,-12",
    "Vallotti-Young,5.9,0,-9.8,-3.9,-5.9,-7.9,-2,-11.8,-2,-7.9,-5.9,-3.9,-9.8",
    "Meantone with G#,8.5,0,-23.9,-6.8,10.3,-13.7,3.4,-20.5,-3.4,-27.3,-10.3,6.8,-17.1",
    "Meantone with Ab,8.5,0,-23.9,-6.8,10.3,-13.7,3.4,-20.5,-3.4,13.7,-10.3,6.8,-17.1",
    "Meantone with D#,8.5,0,-23.9,-6.8,-30.8,-13.7,3.4,-20.5,-3.4,-27.3,-10.3,6.8,-17.1",
    "Pythagorean with G#,-5,0,14,4,-6,8,-2,12,2,16,6,-4,10",
    "Pythagorean with Ab,-5,0,14,4,-6,8,-2,12,2,-8,6,-4,10",
    "Pythagorean with D#,-5,0,14,4,18,8,-2,12,2,16,6,-4,10",
}

--*
--* Manifest
--* The Job plugin script must have a function named "manifest"
--*
function manifest()
    myManifest = {
        name          = [[ScaleTune]],
        comment       = [[Scale Tuning]],
        author        = [[Sajna P.Lakshmi]],
        pluginID      = [[{70afc4d6-3bdf-4d60-828a-e7efe5be42fa}]],
        pluginVersion = [[1.0.0.0]],
        apiVersion    = [[3.0.1.0]]
    }

    return myManifest
end

--*
--* Entry point
--* The Job plugin script must have a function named "main"
--*
function main(processParam, envParam)
    -- Information on the selection range is given to the first argument of "main()"
    -- *If it is not selected, entire the song part is given
    beginPosTick = processParam.beginPosTick	-- tick of the beginning position of selection
    endPosTick   = processParam.endPosTick	-- tick of the ending position of selection
    songPosTick  = processParam.songPosTick	-- tick fo the current song position

    -- Execution environment information is given to the second argument of "main()"
    scriptDir  = envParam.scriptDir	-- directory path where this script is placed
    scriptName = envParam.scriptName	-- name of this script
    tempDir    = envParam.tempDir	-- Temporary directory path available for Job Plugin
    apiVersion = envParam.apiVersion	-- Current Job Plugin version

    local retCode

    retCode = readConfigFile()

    -- Read tuning set file
    local readTuningSetStatus
    readTuningSetStatus, TUNING_SET_DATA_LIST = readTuningSet()
    while (readTuningSetStatus ~= 0) do	-- tuning set has been initialized
        retCode = saveTuningSetFile()
        if retCode ~= 0 then
            return 0
        end
        retCode = VSMessageBox("Setting file has been initialized.\n\"" .. DATA_FILE_PATH .. CONFIG_FN .. "\"\n\nDo you wanna continue?" , 1)
        if retCode ~= 1 then
            return 0
        end
        readTuningSetStatus, TUNING_SET_DATA_LIST = readTuningSet()
    end

    -- Select a tuning set on the dialog
    local tuningSetIndex
    local skipConfirmationDlg
    retCode, tuningSetIndex, skipConfirmationDlg = getTuningSetIndex()
    if retCode ~= 0 or tuningSetIndex == 0 then
        return 0
    end

    -- Retrieve the values from the tuning set line
    local title
    local offset
    local centList
    retCode, title, offset, centList = getDataFromTuningSet(TUNING_SET_DATA_LIST[tuningSetIndex], true)
     if retCode ~= 0 then
         VSMessageBox("Error. Invalid tuning set:" .. retCode , 0)
         return 0
     end

    -- Show the result message
    if skipConfirmationDlg == 0 then
        retCode = showConfirmationDlg(title, offset, centList)
        if retCode ~= 0 then
            return 0
        end
    end

    -- Scale Tuning
    retCode = tuning(centList)

    -- Save setting to file
    CONFIG_DATA_LIST["skipConfirmationDlg"] = skipConfirmationDlg
    retCode = saveConfigFile()
    retCode = saveTuningSetFile(tuningSetIndex)

    return retCode
end

--*
--* Build the contents of the pull down
--* Returns: a comma-separated string
--*
function getTuningSetFieldVal()
    local retCode
    local fieldValLine
    local fieldVal = ""
    local fieldValFormat = "%d \"%s\" offset:%s%s {%s}"
    local title
    local offset
    local centList = {}

    for idx = 1, #TUNING_SET_DATA_LIST, 1 do
        local line = TUNING_SET_DATA_LIST[idx]
        retCode, title, offset, centList = getDataFromTuningSet(line, false)
        if retCode ~= 0 then
            VSMessageBox("Error. Invalid tuningSet.\n" .. "#" .. idx .. " " .. line .. "\n" .. "Rreason:" .. retCode, 0)
        else
            local centValstr = ""
            for n = 1, #centList, 1 do
                centValstr = centValstr .. ((math.floor(centList[n]) - centList[n]) == 0 and math.floor(centList[n]) or centList[n]) .. " "
            end
            fieldValLine = string.format(fieldValFormat, idx, title, ((offset > 0) and "+" or ""), ((math.floor(offset) -offset) == 0 and math.floor(offset) or offset), centValstr)
            fieldVal = (idx > 1 and fieldVal .. "," or "") .. fieldValLine
         end
    end

    return fieldVal
end

--*
--* Retrieve the values from the tuning set line
--* Param: tuning set str, whether to use offset
--* if useOffset = true, the cent value of each note is set to the value obtained by adding offset
--* Returns: index, offset list of cent value
--*
function getDataFromTuningSet(tuningSetStr, useOffset)
    if tuningSetStr == nil then
        return 1
    end
    local tuningSet = split(tuningSetStr, ',')
    if (tuningSet == nil) or (#tuningSet ~= #TUNING_SET_HEADER) then
        return 2
    end
    local offset = tonumber(tuningSet[2])
    if offset == nil then
        return 3
    end
    local centList = {}
    for i = 1 , 12, 1 do
        local cent = tonumber(tuningSet[#TUNING_SET_HEADER - 12 + i])
        if cent == nil then
            return 4
        end
        centList[#centList + 1] = (useOffset and offset or 0) + cent
    end

    return 0, tuningSet[1], offset, centList
end

--*
--* Select a tuning set on the dialog.
--* Returns: selected index, skip showing confirmation message
--*
function getTuningSetIndex()
    local retCode
    local dlgStatus

    VSDlgSetDialogTitle("Scale Tune Setting")	-- Set the window title of the dialog
    local tuningSetFieldVal = getTuningSetFieldVal()	-- Get setting selection pull down contents

    -- Add fields to the dialog
    local field = {}
    field.name       = "selection"
    field.caption    = "Choose setting"
    field.initialVal = tuningSetFieldVal
    field.type = 4
    dlgStatus  = VSDlgAddField(field)

    field.name       = "skipConfirmationDlg"
    field.caption    = "Skip confirmation"
    field.initialVal = tonumber(CONFIG_DATA_LIST["skipConfirmationDlg"])
    field.type       = 1
    dlgStatus = VSDlgAddField(field)

    -- Get values from dialog
    dlgStatus = VSDlgDoModal()
    if  (dlgStatus ~= 1) then
        return 1
    end
    local dlgValue
    local skipConfirmationDlg
    dlgStatus, dlgValue = VSDlgGetStringValue("selection")
    dlgStatus, skipConfirmationDlg = VSDlgGetBoolValue("skipConfirmationDlg")
    local settingList = split(dlgValue, " ", 1)
    if (settingList == nil) or (#settingList == 0) then
        return 2
    end
    local tuningSetIndex = tonumber(settingList[1])
    if (tuningSetIndex == nil) or (tuningSetIndex == 0) then
        return 3
    end

    return 0, tuningSetIndex, skipConfirmationDlg
end

--*
--* Show the result message
--* Returns: 0:Yes 1:No
--*
function showConfirmationDlg(title, offset, centList)
    local msgStr = "Perform scale tuning"
    .. " from " .. beginPosTick .. " to " .. endPosTick .. " ticks" .. " with this setting:\n\n"
    .. "\"" .. title .. "\"" .. "\n\n"
    .. "cent value difference from Equal Temperament:\n"

    local lineFormat = "%9s: %s\n"
    for n = 1, #centList, 1 do
        msgStr = msgStr .. string.format(lineFormat, TUNING_SET_HEADER[#TUNING_SET_HEADER - 12 + n], centList[n])
    end

    msgStr = msgStr .. "\n"
    .. "setting file: "  .. DATA_FILE_PATH .. CONFIG_FN .. "\n"

    local confirmationResult = VSMessageBox(msgStr, 1)

    return (confirmationResult == 2) and 1 or 0
end

--*
--* Scale Tuning
--* Param: list of cent value
--*
function tuning(centList)
    local retCode
    local control = {}

    -- Delete all PIT controls within selected range
    retCode = VSSeekToBeginControl("PIT")
    retCode, control = VSGetNextControl("PIT")
    while(retCode == 1 and control.posTick <= endPosTick) do
        if(control.posTick >= beginPosTick and control.posTick ~= 0) then
            retCode = VSRemoveControl(control)
        end
        retCode, control = VSGetNextControl("PIT")
    end

    -- store note events
    VSSeekToBeginNote()
    local noteExList = {}
    retCode, control = VSGetNextNoteEx()
    while (retCode == 1 and control.posTick <= endPosTick) do
        if control.posTick >= beginPosTick then
            noteExList[#noteExList + 1] = control
        end
        retCode, control = VSGetNextNoteEx()
    end
    if #noteExList == 0 then
        VSMessageBox("There is no note to be tuned.", 0)
        return 0
    end

    -- Insert PIT control at every notes
    retCode = VSSeekToBeginControl("PIT")
    local lastPosTick = 0
    for i = 1, #noteExList, 1 do
        local cent = centList[(noteExList[i].noteNum % 12) + 1]
        retCode, control = VSGetControlAt("PBS", noteExList[i].posTick)
        local pit = pitForCent(cent, control)
        retCode = insertPitControl(noteExList[i].posTick, pit)
        lastPosTick = noteExList[i].posTick + noteExList[i].durTick
    end

    -- At the end of the processed range, set PIT = 0
    if lastPosTick ~= 0 then
        retCode = insertPitControl(lastPosTick, 0)
    end

    return 0
end

--*
--* Insert PIT control at specified position
--* Param: tick where insert PIT at, PIT value
--*
function insertPitControl(posTick, pit)
    local control = {}
    control.posTick = posTick
    control.value = pit
    control.type = "PIT"
    local result = VSInsertControl(control)
    if (result ~= 1) then
        VSMessageBox("Couldn't add pitch bend control parameter. posTick=" .. posTick .. ", pit=" .. pit, 0)
        return 0
    end

    return result
end

--*
--* Calculate PIT from cents
--* Param: cent value, BPS value
--* Returns: PIT value
--*
function pitForCent(cent, pbs)
    local pit = 0
    if cent ~= 0 and pbs ~= 0 then
        local unit_pit = 8191 / (100.0 * pbs)
        pit = math.max(-8192, math.min(8191, math.floor((unit_pit * cent) + 0.5)))
    end

    return pit
end

--*
--* Read config from file
--*
function readConfigFile()
    local retCode
    local added = 0
    local f = io.open(DATA_FILE_PATH .. CONFIG_FN, "r")
    if f then
        local line = f:read()
        while (line ~= nil) do
            if (trim(line) ~= "") and (string.sub(line, 1, 1) ~= "#") then
                local list = split(line, ",", 1)
                if (list ~= nil) and (#list == 2) then
                    CONFIG_DATA_LIST[list[1]] = list[2]
                    added = 1
                end
            end
            line = f:read()
        end
    end

    if (added == 0) then
        CONFIG_DATA_LIST = CONFIG_DEFAULT
    end

    return 0
end

--*
--* Save congig list to file
--*
function saveConfigFile()
    local f = io.open(DATA_FILE_PATH..CONFIG_FN, "w")

    for key, val in pairs(CONFIG_DATA_LIST) do
        if (f ~=  nil) then
            f:write(key .. "," .. val .."\n")
        end
    end
    if f == nil then
        VSMessageBox("Failed to save config file", 0)
        return 1
    else
        f:close()
    end

    return 0
end

--*
--* Read tuning set from file
--* Returns: array of each row
--*
function readTuningSet()
    local retCode
    local dataList = {}
    local f = io.open(DATA_FILE_PATH .. TUNING_SET_FN, "r")
    if f then
        f:read()	-- skip header line
        local line = f:read()
        while (line ~= nil) do
            if (trim(line) ~= "") and (string.sub(line, 1, 1) ~= "#") then
                dataList[#dataList + 1] = line
            end
            line = f:read()
        end
    end

    if (dataList == nil) or (#dataList == 0) then
        return 1, TUNING_SET_DATA_LIST_DEFAULT
    end

    return 0, dataList
end

--*
--* Save tuning set list to file
--* Param: index of selected tuningSet
--*
function saveTuningSetFile(indexToPutAtTheTop)
    -- Move selected tuning set to the top of TUNING_SET_DATA_LIST
    if (indexToPutAtTheTop ~= nil) and (indexToPutAtTheTop > 1) and (indexToPutAtTheTop <= #TUNING_SET_DATA_LIST) then
        local tuningSetToPutAtTheTop = TUNING_SET_DATA_LIST[indexToPutAtTheTop]
        table.remove(TUNING_SET_DATA_LIST, indexToPutAtTheTop)
        table.insert(TUNING_SET_DATA_LIST, 1, tuningSetToPutAtTheTop)
    end

    local f = io.open(DATA_FILE_PATH..TUNING_SET_FN, "w")
    f:write(table.concat(TUNING_SET_HEADER, ",") .. "\n")	-- write header
    for i = 1, #TUNING_SET_DATA_LIST, 1 do
        if (f ~=  nil) and (trim(TUNING_SET_DATA_LIST[i]) ~= "") then
            f:write(TUNING_SET_DATA_LIST[i] .. "\n")
        end
    end
    if f == nil then
        VSMessageBox("Failed to save tuning set file", 0)
        return 1
    else
        f:close()
    end

    return 0
end

--*
--* Split a given character string with a delimiter
--* Param: string, delimiter, number of parts to split
--* if maxDivNum = 0 to split entire
--* Returns: array of split
--*
function split(str, delimiter, maxDivNum)
    if maxDivNum == nil then
        maxDivNum = 0
    end

    local itemList = {}

    if string.find(str, delimiter) == nil then
        table.insert(itemList, str)
        return itemList
    end

    local lastPos
    local ptn = "(.-)" .. delimiter .. "()"
    for part, pos in string.gfind(str, ptn) do
        table.insert(itemList, part)
        lastPos = pos
        if (maxDivNum ~= 0) and (pos >= maxDivNum) then
            break
        end
    end
    table.insert(itemList, string.sub(str, lastPos))

    return itemList
end

--*
--* Trim string
--*
function trim(str)
    local p = str:find"%S"
    return p and str:match(".*%S", p) or ""
end