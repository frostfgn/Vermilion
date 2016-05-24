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

local MODULE = MODULE
MODULE.Name = "Bans"
MODULE.ID = "bans"
MODULE.Description = "Manages the ban system and prevents banned users from reconnecting."
MODULE.Author = "Ned"
MODULE.PreventDisable = true
MODULE.Permissions = {
	"ban_user",
	"unban_user",
	"kick_user",
	"manage_bans",
	"manage_globalbans"
}
MODULE.NetworkStrings = {
	"GetBanRecords",
	"BanPlayer",
	"KickPlayer",
	"UnbanPlayer",
	"UpdateBanReason",
	"BanSQLConnector"
}
MODULE.DefaultPermissions = {
	{ Name = "admin", Permissions = {
			"ban_user",
			"unban_user",
			"kick_user",
			"manage_bans",
			"manage_globalbans"
		}
	}
}
MODULE.BanReasons = {
	"Spamming props",
	"Spamming chat",
	"Spamming VoIP",
	"Circumventing protection measures",
	"Harassment",
	"Stupid questions",
	"Abusing privileges",
	"Hacking",
	"Using an aimbot",
	"Impersonation",
	"Prop-surfing",
	"Alternate account",
	"Disobeying administrator's instructions",
	"Asking for permissions"
}

function MODULE:RegisterChatCommands()
	Vermilion:AddChatCommand({
		Name = "ban",
		Description = "Bans a player",
		Syntax = function(vplayer) return MODULE:TranslateStr("bans:cmd:ban:syntax", nil, vplayer) end,
		CanMute = true,
		Permissions = { "ban_user" },
		AllValid = {
			{ Size = nil, Indexes = { 1 } }
		},
		Predictor = function(pos, current, all, vplayer)
			if(pos == 1) then
				return VToolkit.MatchPlayerPart(current)
			end
			if(pos == 2) then
				if(tonumber(current) == nil and current != nil and current != "") then
					return { { Name = "", Syntax = Vermilion:TranslateStr("not_number", nil, vplayer) } }
				end
			end
			if(pos == 3) then
				return VToolkit.MatchStringPart(MODULE.BanReasons, current)
			end
		end,
		Function = function(sender, text, log, glog)
			if(tonumber(text[2]) == nil) then
				log("not_number", nil, NOTIFY_ERROR)
				return
			end
			local target = VToolkit.LookupPlayer(text[1])
			if(target == nil) then 
				if(tonumber(util.SteamIDTo64(text[1])) > 0) then
					MODULE:BanPlayer({ SteamID = function() return text[1] end, GetName = function() return text[1] end }, sender, tonumber(text[2]) * 60, table.concat(text, " ", 3), log, glog)
				end
				return
			end
			if(Vermilion:GetUser(target):IsImmune(sender)) then
				log("bad_syntax", { target:GetName() }, NOTIFY_ERROR)
				return
			end
			if(target == sender) then
				log("bans:ban_self", nil, NOTIFY_ERROR)
				return
			end
			MODULE:BanPlayer(target, sender, tonumber(text[2]) * 60, table.concat(text, " ", 3), log, glog)
		end,
		AllBroadcast = function(sender, text)
			if(tonumber(text[2]) == nil) then return end
			local time = tonumber(text[2]) * 60
			local reason = table.concat(text, " ", 3)
			if(time == 0) then
				return "bans:ban:allplayers:perma", { sender:GetName(), reason or MODULE:TranslateStr("noreason") }
			else
				return "bans:ban:allplayers", { sender:GetName(), os.date("%d/%m/%y", os.time() + time), reason or MODULE:TranslateStr("noreason") }
			end
		end
	})

	Vermilion:AddChatCommand({
		Name = "kick",
		Description = "Kicks a player",
		Syntax = function(vplayer) return MODULE:TranslateStr("cmd:kick:syntax", nil, vplayer) end,
		CanMute = true,
		Permissions = { "kick_user" },
		AllValid = {
			{ Size = nil, Indexes = { 1 } }
		},
		Predictor = function(pos, current, all, vplayer)
			if(pos == 1) then
				return VToolkit.MatchPlayerPart(current)
			end
			if(pos == 2) then
				return VToolkit.MatchStringPart(MODULE.BanReasons, current)
			end
		end,
		Function = function(sender, text, log, glog)
			local target = VToolkit.LookupPlayer(text[1])
			if(target == sender) then
				log("bans:kick_self", nil, NOTIFY_ERROR)
				return
			end
			if(Vermilion:GetUser(target):IsImmune(sender)) then
				log("bans:player_immune", { target:GetName() }, NOTIFY_ERROR)
				return
			end
			glog("bans:kick:kicked", { target:GetName(), sender:GetName(), table.concat(text, " ", 2) })
			target:Kick(MODULE:TranslateStr("kick:kickedtext", { sender:GetName(), table.concat(text, " ", 2) }, target))
		end,
		AllBroadcast = function(sender, text)
			local reason = table.concat(text, " ", 2)
			return "bans:kick:allplayers", { sender:GetName(), reason }
		end
	})

	Vermilion:AddChatCommand({
		Name = "unban",
		Description = "Unbans a player",
		Syntax = function(vplayer) return MODULE:TranslateStr("cmd:unban:syntax", nil, vplayer) end,
		CanMute = true,
		Permissions = { "unban_user" },
		Predictor = function(pos, current, all, vplayer)
			if(pos == 1) then
				local tab = {}
				for i,k in pairs(MODULE:GetData("bans", {}, true)) do
					if(string.find(string.lower(k.Name), string.lower(current))) then
						table.insert(tab, { Name = k.Name, Syntax = "(" .. (k.Reason or "No reason given") .. ")" })
					end
				end
				return tab
			end
		end,
		Function = function(sender, text, log, glog)
			if(table.Count(text) < 1) then
				log("bad_syntax", nil, NOTIFY_ERROR)
				return
			end
			local candidates = {}
			for i,k in pairs(MODULE:GetData("bans", {}, true)) do
				if(string.find(string.lower(k.Name), string.lower(text[1]))) then
					table.insert(candidates, k)
				end
			end
			if(table.Count(candidates) > 1) then
				log("bans:unban:toomany", nil, NOTIFY_ERROR)
				return
			end
			if(table.Count(candidates) == 0) then
				log("bans:unban:none", nil, NOTIFY_ERROR)
				return
			end
			table.RemoveByValue(MODULE:GetData("bans", {}, true), candidates[1])
			glog("bans:unban:text", { candidates[1].Name, sender:GetName() })
		end
	})

end

function MODULE:BanPlayer(vplayer, banner, time, reason, log, glog)
	if(IsValid(banner)) then
		log = log or function(text, typ, time) Vermilion:AddNotification(banner, text, typ, time) end
	else
		log = log or function(text, typ, time) Vermilion.Log(text) end
		banner = {}
		function banner:GetName()
			return "Vermilion"
		end
		function banner:SteamID()
			return "VERMILION"
		end
	end
	glog = glog or function(text, replacements, typ, time) Vermilion:BroadcastNotification(text, replacements, typ, time) end
	local has = false
	for i,k in pairs(MODULE:GetData("bans", {}, true)) do
		if(k.SteamID == vplayer:SteamID()) then
			has = true
			break
		end
	end
	if(has) then
		log("bans:alreadybanned", nil, NOTIFY_ERROR)
		return
	end
	if(time < 0) then
		log("bans:time:toosmall", nil, NOTIFY_ERROR)
		return
	end
	if(time == 0) then
		table.insert(MODULE:GetData("bans", {}, true), { Name = vplayer:GetName(), SteamID = vplayer:SteamID(), Reason = reason, BanTime = os.time(), ExpiryTime = 0, BannerSteamID = banner:SteamID(), BannerName = banner:GetName() })
		glog("bans:ban:perma:text", { vplayer:GetName(), banner:GetName(), reason or MODULE:TranslateStr("noreason") })
	else
		table.insert(MODULE:GetData("bans", {}, true), { Name = vplayer:GetName(), SteamID = vplayer:SteamID(), Reason = reason, BanTime = os.time(), ExpiryTime = os.time() + time, BannerSteamID = banner:SteamID(), BannerName = banner:GetName() })
		glog("bans:ban:text", { vplayer:GetName(), banner:GetName(), os.date("%d/%m/%y", os.time() + time), reason or MODULE:TranslateStr("noreason") })
	end
	if(vplayer.Kick) then
		vplayer:Kick(reason or MODULE:TranslateStr("noreason", nil, vplayer))
	end
end

function MODULE:UnbanPlayer(name)
  local candidates = {}
  for i,k in pairs(MODULE:GetData("bans", {}, true)) do
    if(string.find(string.lower(k.Name), string.lower(name))) then
      table.insert(candidates, k)
    end
  end
  if(table.Count(candidates) > 1) then
    return
  end
  if(table.Count(candidates) == 0) then
    return
  end
  table.RemoveByValue(MODULE:GetData("bans", {}, true), candidates[1])
end

function MODULE:GetBanData(steamid)
	for i,k in pairs(MODULE:GetData("bans", {}, true)) do
		if(k.SteamID == steamid) then return k end
	end
end

function MODULE:IsPlayerBanned(steamid)
	for i,k in pairs(MODULE:GetData("bans", {}, true)) do
		if(k.SteamID == steamid) then return true end
	end
	return false
end

function MODULE:UpdateBans()
	for i,k in pairs(MODULE:GetData("bans", {}, true)) do
		if(k.ExpiryTime <= os.time() and k.ExpiryTime > 0) then
			table.RemoveByValue(MODULE:GetData("bans", {}, true), k)
		end
	end
end

function MODULE:InitServer()
	self:AddHook("CheckPassword", function(steamid, ip, svpass, clpass, name)
		MODULE:UpdateBans()
		if(MODULE:IsPlayerBanned(util.SteamIDFrom64(steamid))) then
			Vermilion:BroadcastNotification("bans:reconnectalert", { name }, NOTIFY_ERROR)
			if(Vermilion:GetModule("event_logger") != nil) then
				Vermilion:GetModule("event_logger"):AddEvent("exclamation", MODULE:TranslateStr("reconnect:event", { name }))
			end
			if(MODULE:GetBanData(util.SteamIDFrom64(steamid)).ExpiryTime == 0) then
				return false, MODULE:TranslateStr("retorttext:perma", { MODULE:GetBanData(util.SteamIDFrom64(steamid)).Reason or MODULE:TranslateStr("noreason") })
			end
			return false, MODULE:TranslateStr("retorttext", { os.date("%d/%m/%y", MODULE:GetBanData(util.SteamIDFrom64(steamid)).ExpiryTime), MODULE:GetBanData(util.SteamIDFrom64(steamid)).Reason or MODULE:TranslateStr("noreason") })
		end
	end)

	local function sendBanRecords(vplayer)
		MODULE:NetStart("GetBanRecords")
		net.WriteTable(MODULE:GetData("bans", {}, true))
		net.Send(vplayer)
	end

	self:NetHook("GetBanRecords", function(vplayer)
		sendBanRecords(vplayer)
	end)

	self:NetHook("BanPlayer", { "manage_bans" }, function(vplayer)
		local ent = net.ReadEntity()
		if(IsValid(ent)) then
			MODULE:BanPlayer(ent, vplayer, net.ReadInt(32), net.ReadString())

			sendBanRecords(Vermilion:GetUsersWithPermission("manage_bans"))
		end
	end)

	self:NetHook("KickPlayer", { "manage_bans" }, function(vplayer)
		local ent = net.ReadEntity()
		if(IsValid(ent)) then
			ent:Kick(net.ReadString())
			MODULE:NetStart("VGetBanRecords")
			net.WriteTable(MODULE:GetData("bans", {}, true))
			net.Broadcast()
		end
	end)

	self:NetHook("UnbanPlayer", { "manage_bans" }, function(vplayer)
		local steamid = net.ReadString()
		for i,k in pairs(MODULE:GetData("bans", {}, true)) do
			if(k.SteamID == steamid) then
				table.RemoveByValue(MODULE:GetData("bans", {}, true), k)
				Vermilion:BroadcastNotify("bans:unban:text", { k.Name, vplayer:GetName() })
				sendBanRecords(Vermilion:GetUsersWithPermission("manage_bans"))
				break
			end
		end
	end)

	self:NetHook("UpdateBanReason", { "manage_bans" }, function(vplayer)
		local steamid = net.ReadString()
		local newreason = net.ReadString()

		for i,k in pairs(MODULE:GetData("bans", {}, true)) do
			if(k.SteamID == steamid) then
				k.Reason = newreason
				sendBanRecords(Vermilion:GetUsersWithPermission("manage_bans"))
				return
			end
		end
	end)
end

function MODULE:InitClient()

	function MODULE:CreateBanForPanel(playersToBan)
		if(not istable(playersToBan)) then playersToBan = { playersToBan } end
		local bTimePanel = VToolkit:CreateFrame(
			{
				['size'] = { 640, 90 },
				['pos'] = { (ScrW() / 2) - 320, (ScrH() / 2) - 45 },
				['closeBtn'] = true,
				['draggable'] = true,
				['title'] = MODULE:TranslateStr("gui:bantime"),
				['bgBlur'] = true
			}
		)

		VToolkit:SetDark(false)

		local yearsLabel = VToolkit:CreateLabel(MODULE:TranslateStr("yearslabel"))
		yearsLabel:SetPos(10 + ((64 - yearsLabel:GetWide()) / 2), 30)
		yearsLabel:SetParent(bTimePanel)

		local yearsWang = VToolkit:CreateNumberWang(0, 1000)
		yearsWang:SetPos(10, 45)
		yearsWang:SetParent(bTimePanel)



		local monthsLabel = VToolkit:CreateLabel(MODULE:TranslateStr("monthslabel"))
		monthsLabel:SetPos(84 + ((64 - monthsLabel:GetWide()) / 2), 30)
		monthsLabel:SetParent(bTimePanel)

		local monthsWang = VToolkit:CreateNumberWang(0, 12)
		monthsWang:SetPos(84, 45)
		monthsWang:SetParent(bTimePanel)
		monthsWang.OnValueChanged = function(wang, val)
			if(tonumber(val) == 12) then
				wang:SetValue(0)
				yearsWang:SetValue(yearsWang:GetValue() + 1)
			end
		end



		local weeksLabel = VToolkit:CreateLabel(MODULE:TranslateStr("weekslabel"))
		weeksLabel:SetPos(158 + ((64 - weeksLabel:GetWide()) / 2), 30)
		weeksLabel:SetParent(bTimePanel)

		local weeksWang = VToolkit:CreateNumberWang(0, 4)
		weeksWang:SetPos(158, 45)
		weeksWang:SetParent(bTimePanel)
		weeksWang.OnValueChanged = function(wang, val)
			if(tonumber(val) == 4) then
				wang:SetValue(0)
				monthsWang:SetValue(monthsWang:GetValue() + 1)
			end
		end



		local daysLabel = VToolkit:CreateLabel(MODULE:TranslateStr("dayslabel"))
		daysLabel:SetPos(232 + ((64 - daysLabel:GetWide()) / 2), 30)
		daysLabel:SetParent(bTimePanel)

		local daysWang = VToolkit:CreateNumberWang(0, 7)
		daysWang:SetPos(232, 45)
		daysWang:SetParent(bTimePanel)
		daysWang.OnValueChanged = function(wang, val)
			if(tonumber(val) == 7) then
				wang:SetValue(0)
				weeksWang:SetValue(weeksWang:GetValue() + 1)
			end
		end



		local hoursLabel = VToolkit:CreateLabel(MODULE:TranslateStr("hourslabel"))
		hoursLabel:SetPos(306 + ((64 - hoursLabel:GetWide()) / 2), 30)
		hoursLabel:SetParent(bTimePanel)

		local hoursWang = VToolkit:CreateNumberWang(0, 24)
		hoursWang:SetPos(306, 45)
		hoursWang:SetParent(bTimePanel)
		hoursWang.OnValueChanged = function(wang, val)
			if(tonumber(val) == 24) then
				wang:SetValue(0)
				daysWang:SetValue(daysWang:GetValue() + 1)
			end
		end



		local minsLabel = VToolkit:CreateLabel(MODULE:TranslateStr("minuteslabel"))
		minsLabel:SetPos(380 + ((64 - minsLabel:GetWide()) / 2), 30)
		minsLabel:SetParent(bTimePanel)

		local minsWang = VToolkit:CreateNumberWang(0, 60)
		minsWang:SetPos(380, 45)
		minsWang:SetParent(bTimePanel)
		minsWang.OnValueChanged = function(wang, val)
			if(tonumber(val) == 60) then
				wang:SetValue(0)
				hoursWang:SetValue(hoursWang:GetValue() + 1)
			end
		end



		local secondsLabel = VToolkit:CreateLabel(MODULE:TranslateStr("secondslabel"))
		secondsLabel:SetPos(454 + ((64 - secondsLabel:GetWide()) / 2), 30)
		secondsLabel:SetParent(bTimePanel)

		local secondsWang = VToolkit:CreateNumberWang(0, 60)
		secondsWang:SetPos(454, 45)
		secondsWang:SetParent(bTimePanel)
		secondsWang.OnValueChanged = function(wang, val)
			if(tonumber(val) == 60) then
				wang:SetValue(0)
				minsWang:SetValue(minsWang:GetValue() + 1)
			end
		end



		local confirmButton = VToolkit:CreateButton(MODULE:TranslateStr("ok"), function(self)
			local times = { yearsWang:GetValue(), monthsWang:GetValue(), weeksWang:GetValue(), daysWang:GetValue(), hoursWang:GetValue(), minsWang:GetValue(), secondsWang:GetValue() }
			bTimePanel:Close()
			VToolkit:CreateTextInput(MODULE:TranslateStr("reason"), function(text)
				local time = (times[1] * 31557600) + (times[2] * 2592000) + (times[3] * 604800) + (times[4] * 86400) + (times[5] * 3600) + (times[6] * 60) + times[7]
				for i,k in pairs(playersToBan) do
					MODULE:NetStart("BanPlayer")
					net.WriteEntity(k)
					net.WriteInt(time, 32)
					net.WriteString(text)
					net.SendToServer()
				end
			end)
		end)
		confirmButton:SetPos(528, 30)
		confirmButton:SetSize(100, 20)
		confirmButton:SetParent(bTimePanel)



		local cancelButton = VToolkit:CreateButton(MODULE:TranslateStr("cancel"), function(self)
			bTimePanel:Close()
		end)
		cancelButton:SetPos(528, 60)
		cancelButton:SetSize(100, 20)
		cancelButton:SetParent(bTimePanel)

		VToolkit:SetDark(true)

		bTimePanel:MakePopup()
		bTimePanel:DoModal()
		bTimePanel:SetAutoDelete(true)

	end


	self:NetHook("GetBanRecords", function()
		if(not Vermilion.Menu.IsOpen) then return end
		local paneldata = Vermilion.Menu.Pages["bans"]
		paneldata.UnbanPlayer:SetDisabled(true)

		paneldata.BanList:Clear()
		for i,k in pairs(net.ReadTable()) do
			local ln = nil
			if(k.ExpiryTime == 0) then
				ln = paneldata.BanList:AddLine(k.Name, os.date("%d/%m/%y %H:%M:%S", k.BanTime), MODULE:TranslateStr("never"), k.BannerName, k.Reason)
			else
				ln = paneldata.BanList:AddLine(k.Name, os.date("%d/%m/%y %H:%M:%S", k.BanTime), os.date("%d/%m/%y %H:%M:%S", k.ExpiryTime), k.BannerName, k.Reason)
			end
			ln.BSteamID = k.SteamID
			ln.BBSteamID = k.BannerSteamID

			steamworks.RequestPlayerInfo(util.SteamIDTo64(k.SteamID))
			if(k.BannerSteamID != "VERMILION") then steamworks.RequestPlayerInfo(util.SteamIDTo64(k.BannerSteamID)) end
			timer.Simple(3, function()
				if(not IsValid(paneldata.Panel) or not IsValid(ln)) then
					return
				end
				local bannedName = steamworks.GetPlayerName(util.SteamIDTo64(k.SteamID))
				local bannerName = k.BannerName
				if(k.BannerSteamID != "VERMILION") then bannerName = steamworks.GetPlayerName(util.SteamIDTo64(k.BannerSteamID)) end

				if(bannedName != nil) then
					ln:SetValue(1, bannedName)
				end
				if(bannerName != nil) then
					ln:SetValue(4, bannerName)
				end
			end)
		end
		paneldata.BanList:OnRowSelected()
	end)

	Vermilion.Menu:AddCategory("player", 4)

	self:AddMenuPage({
			ID = "bans",
			Name = Vermilion:TranslateStr("menu:bans"),
			Order = 1,
			Category = "player",
			Size = { 900, 560 },
			Conditional = function(vplayer)
				return Vermilion:HasPermission("manage_bans")
			end,
			Builder = function(panel, paneldata)
				local banPlayer = nil
				local kickPlayer = nil
				local unbanPlayer = nil
				local editReason = nil
				local viewReasonDetail = nil

				local banList = VToolkit:CreateList({
					cols = {
						MODULE:TranslateStr("name"),
						MODULE:TranslateStr("list:bannedon"),
						MODULE:TranslateStr("list:expires"),
						MODULE:TranslateStr("list:bannedby"),
						MODULE:TranslateStr("list:reason")
					}
				})
				banList:SetPos(10, 30)
				banList:SetSize(700, panel:GetTall() - 40)
				banList:SetParent(panel)
				paneldata.BanList = banList

				function banList:OnRowSelected(index, line)
					local enabled = self:GetSelected()[1] == nil
					unbanPlayer:SetDisabled(enabled)
					editReason:SetDisabled(enabled)
					viewReasonDetail:SetDisabled(enabled)
				end

				local banHeader = VToolkit:CreateHeaderLabel(banList, MODULE:TranslateStr("listings"))
				banHeader:SetParent(panel)

				VToolkit:CreateSearchBox(banList)


				local banUserPanel = VToolkit:CreateRightDrawer(panel, 0)
				paneldata.BanUserPanel = banUserPanel


				local banUserList = VToolkit:CreateList({
					cols = {
						MODULE:TranslateStr("name")
					}
				})
				banUserList:SetPos(10, 40)
				banUserList:SetSize(300, panel:GetTall() - 50)
				banUserList:SetParent(banUserPanel)
				paneldata.BanUserList = banUserList

				VToolkit:CreateSearchBox(banUserList)

				local banUserHeader = VToolkit:CreateHeaderLabel(banUserList, MODULE:TranslateStr("activeplayers"))
				banUserHeader:SetParent(banUserPanel)

				local banUserButton = VToolkit:CreateButton(MODULE:TranslateStr("banbtn"), function()
					if(table.Count(banUserList:GetSelected()) == 0) then
						VToolkit:CreateErrorDialog(MODULE:TranslateStr("banbtn:error:0"))
						return
					end
					local tab = {}
					for i,k in pairs(banUserList:GetSelected()) do
						table.insert(tab, VToolkit.LookupPlayer(k:GetValue(1)))
					end
					MODULE:CreateBanForPanel(tab)
					banUserPanel:Close()
				end)
				banUserButton:SetTall(30)
				banUserButton:SetPos(banUserPanel:GetWide() - 185, (banUserPanel:GetTall() - banUserButton:GetTall()) / 2)
				banUserButton:SetWide(banUserPanel:GetWide() - banUserButton:GetX() - 15)
				banUserButton:SetParent(banUserPanel)



				local kickUserPanel = VToolkit:CreateRightDrawer(panel, 0)
				paneldata.KickUserPanel = kickUserPanel

				local kickUserList = VToolkit:CreateList({
					cols = {
						MODULE:TranslateStr("name")
					}
				})
				kickUserList:SetPos(10, 40)
				kickUserList:SetSize(300, panel:GetTall() - 50)
				kickUserList:SetParent(kickUserPanel)
				paneldata.KickUserList = kickUserList

				VToolkit:CreateSearchBox(kickUserList)

				local kickUserHeader = VToolkit:CreateHeaderLabel(kickUserList, MODULE:TranslateStr("activeplayers"))
				kickUserHeader:SetParent(kickUserPanel)

				local kickUserButton = VToolkit:CreateButton(MODULE:TranslateStr("kickbtn"), function()
					if(table.Count(kickUserList:GetSelected()) == 0) then
						VToolkit:CreateErrorDialog(MODULE:TranslateStr("kickbtn:error:0"))
						return
					end
					VToolkit:CreateTextInput(MODULE:TranslateStr("kickbtn:reason"), function(text)
						for i,k in pairs(kickUserList:GetSelected()) do
							MODULE:NetStart("KickPlayer")
							net.WriteEntity(VToolkit.LookupPlayer(k:GetValue(1)))
							net.WriteString(text)
							net.SendToServer()
						end
						kickUserPanel:Close()
					end)
				end)
				kickUserButton:SetTall(30)
				kickUserButton:SetPos(kickUserPanel:GetWide() - 185, (kickUserPanel:GetTall() - kickUserButton:GetTall()) / 2)
				kickUserButton:SetWide(kickUserPanel:GetWide() - kickUserButton:GetX() - 15)
				kickUserButton:SetParent(kickUserPanel)



				banPlayer = VToolkit:CreateButton(MODULE:TranslateStr("banply"), function()
					banUserPanel:Open()
				end)
				banPlayer:SetPos(panel:GetWide() - 185, 30)
				banPlayer:SetSize(panel:GetWide() - banPlayer:GetX() - 5, 30)
				banPlayer:SetParent(panel)

				local banImg = vgui.Create("DImage")
				banImg:SetImage("icon16/user_delete.png")
				banImg:SetSize(16, 16)
				banImg:SetParent(banPlayer)
				banImg:SetPos(10, (banPlayer:GetTall() - 16) / 2)

				kickPlayer = VToolkit:CreateButton(MODULE:TranslateStr("kickply"), function()
					kickUserPanel:Open()
				end)
				kickPlayer:SetPos(panel:GetWide() - 185, 70)
				kickPlayer:SetSize(panel:GetWide() - kickPlayer:GetX() - 5, 30)
				kickPlayer:SetParent(panel)

				local kickImg = vgui.Create("DImage")
				kickImg:SetImage("icon16/disconnect.png")
				kickImg:SetSize(16, 16)
				kickImg:SetParent(kickPlayer)
				kickImg:SetPos(10, (kickPlayer:GetTall() - 16) / 2)


				editReason = VToolkit:CreateButton(MODULE:TranslateStr("editreason"), function()
					VToolkit:CreateTextInput(MODULE:TranslateStr("editreason:dialog"), function(text)
						banList:GetSelected()[1]:SetValue(5, text)
						MODULE:NetStart("UpdateBanReason")
						net.WriteString(banList:GetSelected()[1].BSteamID)
						net.WriteString(text)
						net.SendToServer()
					end)
				end)
				editReason:SetPos(panel:GetWide() - 185, 150)
				editReason:SetSize(panel:GetWide() - editReason:GetX() - 5, 30)
				editReason:SetParent(panel)
				editReason:SetDisabled(true)

				local editImg = vgui.Create("DImage")
				editImg:SetImage("icon16/pencil.png")
				editImg:SetSize(16, 16)
				editImg:SetParent(editReason)
				editImg:SetPos(10, (editReason:GetTall() - 16) / 2)

				viewReasonDetail = VToolkit:CreateButton(MODULE:TranslateStr("details"), function()
					VToolkit:CreateErrorDialog("Not implemented!")
				end)
				viewReasonDetail:SetPos(panel:GetWide() - 185, 190)
				viewReasonDetail:SetSize(panel:GetWide() - viewReasonDetail:GetX() - 5, 30)
				viewReasonDetail:SetParent(panel)
				viewReasonDetail:SetDisabled(true)

				local detailImg = vgui.Create("DImage")
				detailImg:SetImage("icon16/report.png")
				detailImg:SetSize(16, 16)
				detailImg:SetParent(viewReasonDetail)
				detailImg:SetPos(10, (viewReasonDetail:GetTall() - 16) / 2)

				updateDuration = VToolkit:CreateButton(MODULE:TranslateStr("editduration"), function()
					VToolkit:CreateErrorDialog("Not implemented!")
				end)
				updateDuration:SetPos(panel:GetWide() - 185, 230)
				updateDuration:SetSize(panel:GetWide() - updateDuration:GetX() - 5, 30)
				updateDuration:SetParent(panel)
				updateDuration:SetDisabled(true)

				local durationImg = vgui.Create("DImage")
				durationImg:SetImage("icon16/clock.png")
				durationImg:SetSize(16, 16)
				durationImg:SetParent(updateDuration)
				durationImg:SetPos(10, (updateDuration:GetTall() - 16) / 2)

				unbanPlayer = VToolkit:CreateButton(MODULE:TranslateStr("unbanbtn"), function()
					MODULE:NetStart("UnbanPlayer")
					net.WriteString(banList:GetSelected()[1].BSteamID)
					net.SendToServer()
				end)
				unbanPlayer:SetPos(panel:GetWide() - 185, 270)
				unbanPlayer:SetSize(panel:GetWide() - unbanPlayer:GetX() - 5, 30)
				unbanPlayer:SetParent(panel)
				unbanPlayer:SetDisabled(true)
				paneldata.UnbanPlayer = unbanPlayer

				local unbanImg = vgui.Create("DImage")
				unbanImg:SetImage("icon16/accept.png")
				unbanImg:SetSize(16, 16)
				unbanImg:SetParent(unbanPlayer)
				unbanImg:SetPos(10, (unbanPlayer:GetTall() - 16) / 2)

				banUserPanel:MoveToFront()
				kickUserPanel:MoveToFront()

			end,
			OnOpen = function(panel, paneldata)
				MODULE:NetCommand("GetBanRecords")

				paneldata.BanUserList:Clear()
				paneldata.KickUserList:Clear()
				for i,k in pairs(VToolkit.GetValidPlayers()) do
					paneldata.BanUserList:AddLine(k:GetName())
					paneldata.KickUserList:AddLine(k:GetName())
				end
				paneldata.BanUserPanel:Close()
				paneldata.KickUserPanel:Close()
			end
		})
end
