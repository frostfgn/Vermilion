--[[
 The MIT License

 Copyright 2014 Ned Hyett.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
]]

Vermilion = {}

Vermilion.EVENT_EXT_LOADED = "Vermilion_LoadedEXT"

Vermilion.Constants = {
	['default_file_ext'] = ".txt",
	['users_file_name'] = "users",
	['permissions_file_name'] = "permissions",
	['rankings_file_name'] = "rankings",
	['settings_file_name'] = "settings"	
}


-- Internal logging function
function Vermilion.Log( str ) 
	print("Vermilion: " .. tostring(str))
	file.Append("vermilion_client_log.txt", util.DateStamp() .. tostring(str) .. "\n")
end

local preloadFiles = {
	"vermilion/crimson_gmod.lua",
	"vermilion/vermilion_shared.lua",
	"vermilion/vermilion_commands_client.lua",
	"vermilion/vermilion_client.lua"
}
if(not game.SinglePlayer()) then
	for i, luaFile in pairs(preloadFiles) do
		include(luaFile)
	end
	Vermilion.Log("Started!")
else
	Vermilion.Log("Not starting on singleplayer game!")
end