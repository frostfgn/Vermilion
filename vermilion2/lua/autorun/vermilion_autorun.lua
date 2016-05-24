--[[
 Copyright 2015-16 Ned Hyett

 Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
 in compliance with the License. You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under the License
 is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 or implied. See the License for the specific language governing permissions and limitations under
 the License.

 The right to upload this project to the Steam Workshop (which is operated by Valve Corporation)
 is reserved by the original copyright holder, regardless of any modifications made to the code,
 resources or related content. The original copyright holder is not affiliated with Valve Corporation
 in any way, nor claims to be so.
]]

if(Vermilion) then
	if(isfunction(Vermilion.GetVersion)) then
		if(not isnumber(Vermilion:GetVersion())) then
			print("Vermilion 2 has detected the presence of Vermilion 1 and has stopped loading! Get rid of Vermilion 1!")
			return
		end
	end
end

local gmodver = string.Explode(".", VERSIONSTR)
for i,k in pairs(gmodver) do gmodver[i] = tonumber(k) end
local time = (gmodver[1] * 31557600) + (gmodver[2] * 2678400) + (gmodver[3] * 86400)
if(time < 63604720800) then
	print("[Vermilion2] CRITICAL WARNING: You are running an old version of GMod that is NOT supported and has NETWORKING ERRORS!")
	print("[Vermilion2] If something goes wrong and you do not update to the latest version, I will not help you. Ever.")
end
if(tmysql4 = nil) then
	print("[Vermilion2] Failed to initialize TMYSQL4!")
end

if(SERVER) then
	AddCSLuaFile()
	NOTIFY_GENERIC = 0
	NOTIFY_ERROR = 1
	NOTIFY_UNDO = 2
	NOTIFY_HINT = 3
	NOTIFY_CLEANUP = 4

	--[[ local tab = {}

	local netstart = net.Start
	local currmsg = nil
	function net.Start(msg)
		if(tab[msg] == nil) then
			tab[msg] = { Number = 1, Size = 0 }
		else
			tab[msg].Number = tab[msg].Number + 1
		end
		currmsg = msg
		netstart(msg)
	end
	local netsend = net.Send
	function net.Send(vplayer)
		tab[currmsg].Size = tab[currmsg].Size + net.BytesWritten()
		netsend(vplayer)
	end

	concommand.Add("v_networktracker", function()
		PrintTable(tab)
	end) ]]
end
if(not file.Exists("vermilion2/", "DATA")) then
	file.CreateDir("vermilion2")
end
if(not file.Exists("vermilion2sqlof/", "DATA")) then
	file.CreateDir("vermilion2sqlof")
end

Vermilion = {}

--[[
Vermilion.NetStrings = {}

local addns = util.AddNetworkString
function util.AddNetworkString(str)
	if(string.StartWith(str, "V")) then table.insert(Vermilion.NetStrings, str) end
	return addns(str)
end
]]--

function Vermilion.GetFileName(name)
	if(CLIENT) then
		return "vermilion2/vermilion_client_" .. name .. ".txt"
	elseif(SERVER) then
		return "vermilion2/vermilion_server_" .. name .. ".txt"
	else
		return "vermilion2/vermilion_unknown_" .. name .. ".txt"
	end
end

if(not file.Exists(Vermilion.GetFileName("settings"), "DATA") and SERVER) then
	Vermilion.FirstRun = true
end


local startTime = os.clock()



Vermilion.Colours = {
	White = Color(255, 255, 255),
	Black = Color(0, 0, 0),
	Red = Color(255, 0, 0),
	Green = Color(0, 128, 0),
	Blue = Color(0, 0, 255),
	Yellow = Color(255, 255, 0),
	Grey = Color(128, 128, 128)
}

function Vermilion.GetVersionString()
	return table.concat( { Vermilion.GetVersion() }, ".")
end

function Vermilion.GetVersion()
	return 2, 5, 6
end

Vermilion.Internal = {}

Vermilion.Event = {
	["MOD_LOADED"] = "Vermilion2_LoadedMOD",
	["MOD_POST"] = "Vermilion2_LoadedMODPost",
	["MENU_OPENING"] = "Vermilion2_MenuOpening",
	["MENU_OPEN"] = "Vermilion2_MenuOpen",
	["MENU_CLOSING"] = "Vermilion2_MenuClosing",
	["MENU_CLOSED"] = "Vermilion2_MenuClosed",
	["MENU_TAB"] = "Vermilion2_MenuChangeTab",
	["CLIENT_GOT_RANK_DATA"] = "Vermilion2_Ranks",
	["CLIENT_GOT_USERDATA"] = "Vermilion2_Users",
	["CLIENT_NewPermissionData"] = "Vermilion2_PermissionData",
	["CheckLimit"] = "Vermilion2_CheckLimit",
	["RankCreated"] = "Vermilion2_RankCreate",
	["RankDeleted"] = "Vermilion2_RankDelete",
	["RankRenamed"] = "Vermilion2_RankRename",
	["ShuttingDown"] = "Vermilion2_Shutdown",
	["PlayerChangeRank"] = "Vermilion2_PlayerRankChange",
	["AnythingSpawned"] = "Vermilion2_AnythingSpawned",
	["SQLConnectStatus"] = "Vermilion2_SQLConnectStatus"
}

function Vermilion.Log( str, forceside )
	local side = "UNKNOWN"
	if(SERVER) then
		side = "Server"
	elseif(CLIENT) then
		side = "Client"
	end
	if(forceside != nil) then side = forceside end
	if(not istable(str)) then
		str = { Color(255, 0, 0), "[Vermilion2 - " .. side .. "] ", Color(255, 255, 255), str }
	else
		table.insert(str, 1, Color(255, 255, 255))
		table.insert(str, 1, "[Vermilion2 - " .. side .. "] ")
		table.insert(str, 1, Color(255, 0, 0))
	end
	table.insert(str, "\n")
	MsgC(unpack(str))
	local texttab = {}
	for i,k in pairs(str) do
		if(not IsColor(k)) then
			table.insert(texttab, tostring(k))
		end
	end
	if(forceside != nil) then return end
	file.Append("vermilion2/vermilion_" .. string.lower(side) .. "_log.txt", util.DateStamp() .. " " .. table.concat(texttab, " ") .. "\n")
end

Vermilion.Log("Starting up...")

-- file / addcsluafile / include on client / include on server
local files = {
	{ "vtoolkit/toolkit.lua", false, true, true },
	{ "vermilion2/utils.lua", true, true, true },
	{ "vermilion2/basecommand.lua", true, true, true },
	{ "vermilion2/core/hooks.lua", true, true, true },
	{ "vermilion2/core/basemodule.lua", true, true, true },
	{ "vermilion2/core/notifications.lua", true, true, true },
	{ "vermilion2/shared.lua", true, true, true },
	{ "vermilion2/config/rankobj.lua", true, true, true },
	{ "vermilion2/config/userobj.lua", true, true, true },
	{ "vermilion2/config/sh_config.lua", true, true, true },
	{ "vermilion2/config/sv_config.lua", false, false, true },
	{ "vermilion2/config/cl_config.lua", true, true, false },
	{ "vermilion2/menuclient.lua", true, true, false },
	{ "vermilion2/chatcommands.lua", false, false, true },
	{ "vermilion2/chatcommands_client.lua", true, true, false },
	{ "vermilion2/chatpredict.lua", true, true, true },
	{ "vermilion2/geoip.lua", true, true, true },
	{ "vermilion2/memoryviewer.lua", true, true, true },
	{ "vermilion2/core/ent_extension.lua", true, true, true },
	{ "vermilion2/ply_extension.lua", false, false, true },
	{ "vermilion2/targetid.lua", true, true, true }
}

local clientfiles = 0
local cfiles = 0

for i,k in ipairs(files) do
	if(SERVER and k[2]) then
		AddCSLuaFile(k[1])
		clientfiles = clientfiles + 1
	end
	if((SERVER and k[4]) or (CLIENT and k[3])) then
		include(k[1])
		cfiles = cfiles + 1
	end
end
if(SERVER) then
	Vermilion:LoadModules()
	Vermilion.Log({
		"Started in ",
		Vermilion.Colours.Blue,
		tostring(math.Round(os.clock() - startTime, 4)),
		"ms",
		Vermilion.Colours.White,
		" triggering ",
		Vermilion.Colours.Blue,
		tostring(cfiles),
		Vermilion.Colours.White,
		" files and sending ",
		Vermilion.Colours.Blue,
		tostring(clientfiles),
		Vermilion.Colours.White,
		" to the client."
	})
else

	Vermilion.Log({
		"Started in ",
		Vermilion.Colours.Blue,
		tostring(math.Round(os.clock() - startTime, 4)),
		"ms",
		Vermilion.Colours.White,
		" triggering ",
		Vermilion.Colours.Blue,
		tostring(cfiles),
		Vermilion.Colours.White,
		" files."
	})
end

Vermilion.FirstRun = false
