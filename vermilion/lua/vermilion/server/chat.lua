--[[
 Copyright 2014 Ned Hyett

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

Vermilion.ChatCommands = {}
Vermilion.ChatPredictors = {}
Vermilion.ChatAliases = {}

--[[ 
	Add a chat command to the Vermilion interpreter
	
	@param activator (string) - what the player has to type into chat to activate the command
	@param func (function with params: sender (player), text (table) space split input) - the command handler
]]--
function Vermilion:AddChatCommand(activator, func, syntax)
	syntax = syntax or ""
	if(self.ChatCommands[activator] != nil) then
		self.Log("Chat command " .. activator .. " has been overwritten!")
	end
	self.ChatCommands[activator] = { Function = func, Syntax = syntax }
	concommand.Add("vermilion_" .. activator, function(sender, cmd, args, fullstring)
		local success, err = pcall(func, sender, args, function(text) Vermilion.Log(text) end)
		if(not success) then
			Vermilion.Log("Command failed with an error: " .. tostring(err))
		end
	end, nil, "This command can also be run by typing !" .. activator .. " into the chat.")
end

function Vermilion:AddChatPredictor(activator, func)
	self.ChatPredictors[activator] = func
end

--[[
	Create a command that redirects to another command.
	
	@param alias (string) - the new command name
	@param command (string) - the command to redirect to
]]--
function Vermilion:AliasChatCommand(alias, command)
	if(self.ChatAliases[alias] != nil) then
		self.Log("Chat alias " .. alias .. " has been overwritten!")
	end
	self.ChatAliases[alias] = command
end

function Vermilion:HandleChat(vplayer, text, targetLogger, isConsole)
	targetLogger = targetLogger or vplayer
	local logFunc = nil
	if(isfunction(targetLogger)) then
		logFunc = targetLogger
	else
		if(isConsole) then
			logFunc = function(text) if(sender == nil) then Vermilion.Log(text) else sender:PrintMessage(HUD_PRINTCONSOLE, text) end end
		else
			logFunc = function(text, delay, typ) Vermilion:SendNotify(targetLogger, text, delay, typ) end
		end
	end
	if(string.StartWith(text, "!")) then
		local commandText = string.sub(text, 2)
		local parts = string.Explode(" ", commandText, false)
		local parts2 = {}
		local part = ""
		local isQuoted = false
		for i,k in pairs(parts) do
			if(isQuoted and string.find(k, "\"")) then
				table.insert(parts2, string.Replace(part .. " " .. k, "\"", ""))
				isQuoted = false
				part = ""
			elseif(not isQuoted and string.find(k, "\"")) then
				part = k
				isQuoted = true
			elseif(isQuoted) then
				part = part .. " " .. k
			else
				table.insert(parts2, k)
			end
		end
		table.insert(parts2, string.Trim(string.Replace(part, "\"", "")))
		parts = {}
		for i,k in pairs(parts2) do
			if(k != nil and k != "") then
				table.insert(parts, k)
			end
		end
		local commandName = parts[1]
		if(Vermilion.ChatAliases[commandName] != nil) then
			commandName = Vermilion.ChatAliases[commandName]
		end
		local command = Vermilion.ChatCommands[commandName]
		if(command != nil) then
			table.remove(parts, 1)
			local success, err = pcall(command.Function, vplayer, parts, logFunc)
			if(not success) then 
				logFunc("Command failed with an error " .. tostring(err), 25, VERMILION_NOTIFY_ERROR) 
			end
		else 
			if(commandName == nil) then commandName = "" end
			logFunc("No such command '" .. commandName .. "'", VERMILION_NOTIFY_ERROR)
			local percentages = {}
			for i,k in pairs(Vermilion.ChatCommands) do
				local actual = string.ToTable(i)
				local typed = string.ToTable(commandName)
				local correct = 0
				for i1,k2 in ipairs(actual) do
					if(typed[i1] == nil) then break end
					if(string.lower(k2) == string.lower(typed[i1])) then
						correct = correct + 1
					end
				end
				table.insert(percentages, { Name = table.concat(actual), Percentage = (correct / table.Count(actual)) * 100})
			end
			table.SortByMember(percentages, "Percentage", false)
			if(percentages[1].Percentage == 0) then return "" end
			logFunc("Did you mean to type any of these?", 10, VERMILION_NOTIFY_ERROR)
			for i=1,3,1 do
				logFunc(percentages[i].Name, 10, VERMILION_NOTIFY_ERROR)
			end
		end
		return ""
	end
end

Vermilion:RegisterHook("PlayerSay", "Say1", function(vplayer, text, teamChat)
	return Vermilion:HandleChat(vplayer, text, vplayer, false)
end)