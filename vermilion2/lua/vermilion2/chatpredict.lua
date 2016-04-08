--[[
 Copyright 2015-16 Ned Hyett,

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

Vermilion.ChatPredict = {}

if(SERVER) then
	util.AddNetworkString("VChatPrediction")

	net.Receive("VChatPrediction", function(len, vplayer)
		local current = net.ReadString()

		local command, response = Vermilion.ParseChatLineForCommand(current, vplayer, true)

		local predictor = nil
		local cmdObj = nil
		if(Vermilion.ChatAliases[command] != nil) then
			cmdObj = Vermilion.ChatCommands[Vermilion.ChatAliases[command]]
		else
			cmdObj = Vermilion.ChatCommands[command]
		end
		if(cmdObj != nil and not cmdObj.OnlyConsole) then
			predictor = cmdObj.Predictor
		end

		if(string.find(current, " ") and predictor != nil) then
			local cmdName,parts = Vermilion.ParseChatLineForParameters(current, true)
			local dataTable = predictor(table.Count(parts), parts[table.Count(parts)], parts, vplayer)
			if(dataTable != nil) then
				for i,k in pairs(dataTable) do
					if(istable(k)) then
						table.insert(response, k)
					else
						table.insert(response, { Name = k, Syntax = "" })
					end
				end
			end
		elseif(string.find(current, " ") and predictor == nil) then
			table.insert(response, { Name = "", Syntax = Vermilion:TranslateStr("cmd_chatpredict_nopredict", nil, vplayer) })
		end
		net.Start("VChatPrediction")
		net.WriteTable(response)
		net.Send(vplayer)
	end)

else
	CreateClientConVar("vermilion_chatpredict", 1, true, false)

	Vermilion:AddHook(Vermilion.Event.MOD_LOADED, "ChatPredictOption", false, function()
		if(Vermilion:GetModule("client_settings") == nil) then return end
		Vermilion:GetModule("client_settings"):AddOption({
			GuiText = Vermilion:TranslateStr("cmd_chatpredict_setting"),
			ConVar = "vermilion_chatpredict",
			Type = "Checkbox",
			Category = "Features"
		})
	end)

	net.Receive("VChatPrediction", function()
		local response = net.ReadTable()
		Vermilion.ChatPredict.ChatPredictions = response
	end)

	Vermilion.ChatPredict.ChatOpen = false

	Vermilion:AddHook("StartChat", "VOpenChatbox", false, function()
		Vermilion.ChatPredict.ChatOpen = true
	end)

	Vermilion:AddHook("FinishChat", "VCloseChatbox", false, function()
		Vermilion.ChatPredict.ChatOpen = false
		Vermilion.ChatPredict.ChatPredictions = {}
	end)

	Vermilion:AddHook("HUDShouldDraw", "ChatHideHUD", false, function(name)
		if(GetConVarNumber("vermilion_chatpredict") == 0) then return end
		if(Vermilion.ChatPredict.CurrentChatText == nil or GetConVarNumber("vermilion_chatpredict") == 0) then return end
		if(string.StartWith(Vermilion.ChatPredict.CurrentChatText, "!") and (name == "NetGraph" or name == "CHudAmmo")) then return false end
	end)

	Vermilion.ChatPredict.ChatPredictions = {}
	Vermilion.ChatPredict.ChatTabSelected = 1
	Vermilion.ChatPredict.ChatBGW = 0
	Vermilion.ChatPredict.ChatBGH = 0
	Vermilion.ChatPredict.MoveEnabled = true

	Vermilion:AddHook("Think", "ChatMove", false, function()
		if(GetConVarNumber("vermilion_chatpredict") == 0) then return end
		if(Vermilion.ChatPredict.ChatOpen and Vermilion.ChatPredict.MoveEnabled and table.Count(Vermilion.ChatPredict.ChatPredictions) > 0) then
			if(input.IsKeyDown(KEY_DOWN)) then
				if(string.find(Vermilion.ChatPredict.CurrentChatText, " ")) then
					if(Vermilion.ChatPredict.ChatTabSelected + 1 > table.Count(Vermilion.ChatPredict.ChatPredictions)) then
						Vermilion.ChatPredict.ChatTabSelected = 2
					else
						Vermilion.ChatPredict.ChatTabSelected = Vermilion.ChatPredict.ChatTabSelected + 1
					end
				else
					if(Vermilion.ChatPredict.ChatTabSelected + 1 > table.Count(Vermilion.ChatPredict.ChatPredictions)) then
						Vermilion.ChatPredict.ChatTabSelected = 1
					else
						Vermilion.ChatPredict.ChatTabSelected = Vermilion.ChatPredict.ChatTabSelected + 1
					end
				end
				Vermilion.ChatPredict.MoveEnabled = false
				timer.Simple(0.1, function()
					Vermilion.ChatPredict.MoveEnabled = true
				end)
			elseif(input.IsKeyDown(KEY_UP)) then
				if(string.find(Vermilion.ChatPredict.CurrentChatText, " ")) then
					if(Vermilion.ChatPredict.ChatTabSelected - 1 < 2) then
						Vermilion.ChatPredict.ChatTabSelected = table.Count(Vermilion.ChatPredict.ChatPredictions)
					else
						Vermilion.ChatPredict.ChatTabSelected = Vermilion.ChatPredict.ChatTabSelected - 1
					end
				else
					if(Vermilion.ChatPredict.ChatTabSelected - 1 < 1) then
						Vermilion.ChatPredict.ChatTabSelected = table.Count(Vermilion.ChatPredict.ChatPredictions)
					else
						Vermilion.ChatPredict.ChatTabSelected = Vermilion.ChatPredict.ChatTabSelected - 1
					end
				end
				Vermilion.ChatPredict.MoveEnabled = false
				timer.Simple(0.1, function()
					Vermilion.ChatPredict.MoveEnabled = true
				end)
			end
		end
	end)

	Vermilion:AddHook("OnChatTab", "VInsertPrediction", false, function()
		if(GetConVarNumber("vermilion_chatpredict") == 0) then return end
		if(table.Count(Vermilion.ChatPredict.ChatPredictions) > 0 and string.find(Vermilion.ChatPredict.CurrentChatText, " ") and table.Count(Vermilion.ChatPredict.ChatPredictions) > 1) then
			if(Vermilion.ChatPredict.ChatPredictions[Vermilion.ChatPredict.ChatTabSelected].Name == "") then return end
			local commandText = Vermilion.ChatPredict.CurrentChatText
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
			if(isQuoted) then table.insert(parts2, string.Replace(part, "\"", "")) end
			parts = {}
			for i,k in pairs(parts2) do
				--if(k != nil and k != "") then
					table.insert(parts, k)
				--end
			end
			parts[table.Count(parts)] = Vermilion.ChatPredict.ChatPredictions[Vermilion.ChatPredict.ChatTabSelected].Name

			return table.concat(parts, " ", 1) .. " "
		end
		if(Vermilion.ChatPredict.ChatPredictions != nil and table.Count(Vermilion.ChatPredict.ChatPredictions) > 0 and Vermilion.ChatPredict.ChatTabSelected == 0) then
			return "!" .. Vermilion.ChatPredict.ChatPredictions[1].Name .. " "
		end
		if(Vermilion.ChatPredict.ChatPredictions != nil and Vermilion.ChatPredict.ChatTabSelected > 0) then
			if(Vermilion.ChatPredict.ChatPredictions[Vermilion.ChatPredict.ChatTabSelected] == nil) then return end
			return "!" .. Vermilion.ChatPredict.ChatPredictions[Vermilion.ChatPredict.ChatTabSelected].Name .. " "
		end
	end)

	Vermilion:AddHook("HUDPaint", "PredictDraw", false, function()
		if(GetConVarNumber("vermilion_chatpredict") == 0) then return end
		if(table.Count(Vermilion.ChatPredict.ChatPredictions) > 0 and Vermilion.ChatPredict.ChatOpen) then
			local pos = 0
			local xpos = 0
			local maxw = 0
			local text = Vermilion:TranslateStr("cmd_chatpredict_prompt")
			local mapbx = nil
			local maptx = nil
			mapbx = select(1, chat.GetChatBoxSize()) + 20
			maptx = select(1, chat.GetChatBoxSize()) + 25
			draw.RoundedBox(2, mapbx, select(2, chat.GetChatBoxPos()) - 15, Vermilion.ChatPredict.ChatBGW + 10, Vermilion.ChatPredict.ChatBGH + 5, Color(0, 0, 0, 128))
			draw.SimpleText(text, "Default", maptx, select(2, chat.GetChatBoxPos()) - 20, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			Vermilion.ChatPredict.ChatBGH = 0
			for i,k in pairs(Vermilion.ChatPredict.ChatPredictions) do
				local text = k.Name
				if(table.Count(Vermilion.ChatPredict.ChatPredictions) <= 8 or string.find(Vermilion.ChatPredict.CurrentChatText, " ")) then
					if(k.Name != "") then
						text = k.Name .. " " .. k.Syntax
					else
						text = k.Syntax
					end
				end
				local colour = Color(255, 255, 255)
				if(i == Vermilion.ChatPredict.ChatTabSelected and Vermilion.ChatPredict.ChatPredictions[Vermilion.ChatPredict.ChatTabSelected].Name != "") then colour = Color(255, 0, 0) end
				local w,h = draw.SimpleText(text, "Default", maptx + xpos, select(2, chat.GetChatBoxPos()) + pos, colour, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				if(maxw < w) then maxw = w end
				pos = pos + h + 5
				if(pos > Vermilion.ChatPredict.ChatBGH) then Vermilion.ChatPredict.ChatBGH = pos end
				if(pos + select(2, chat.GetChatBoxPos()) + 20 >= ScrH()) then
					xpos = xpos + maxw + 10
					maxw = 0
					pos = 0
				end
			end
			Vermilion.ChatPredict.ChatBGW = xpos + maxw
		end
	end)

	Vermilion:AddHook("ChatTextChanged", "ChatPredict", false, function(chatText)
		if(GetConVarNumber("vermilion_chatpredict") == 0) then return end
		if(Vermilion.ChatPredict.CurrentChatText != chatText) then
			if(string.find(chatText, " ")) then
				Vermilion.ChatPredict.ChatTabSelected = 2
			else
				Vermilion.ChatPredict.ChatTabSelected = 1
			end
		end
		Vermilion.ChatPredict.CurrentChatText = chatText

		if(string.StartWith(chatText, "!")) then
			net.Start("VChatPrediction")
			local space = nil
			if(string.find(chatText, " ")) then
				space = string.find(chatText, " ") - 1

			end
			net.WriteString(string.sub(chatText, 2))
			net.SendToServer()
		else
			Vermilion.ChatPredict.ChatPredictions = {}
		end
	end)
end
