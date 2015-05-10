--[[
 Copyright 2015 Ned Hyett,

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
MODULE.Name = "Rank Editor"
MODULE.ID = "rank_editor"
MODULE.Description = "Provides options for editing the rank hierachy used by Vermilion to determine who can do what, at what time, where, and who they are better than."
MODULE.Author = "Ned"
MODULE.PreventDisable = true
MODULE.Permissions = {
	"manage_ranks",
	"identify_as_admin",
	"identify_as_superadmin"
}
MODULE.NetworkStrings = {
	"VGetPermissions",
	"VGivePermission",
	"VRevokePermission",

	"VAddRank",
	"VRemoveRank",
	"VRenameRank",
	"VMoveRank",
	"VSetRankDefault",
	"VChangeRankColour",
	"VChangeRankIcon",
	"VAssignRank",
	"VAssignParent"
}
MODULE.DefaultPermissions = {
	{ Name = "admin", Permissions = {
			"identify_as_admin"
		}
	}
}

function MODULE:RegisterChatCommands()

	Vermilion:AddChatCommand({
		Name = "addplayer",
		Description = "Add a new offline player to the database",
		Syntax = "<name> <steamid>",
		Permissions = { "manage_ranks" },
		Function = function(sender, text, log, glog)
			if(table.Count(text) < 2) then
				log("bad_syntax", nil, NOTIFY_ERROR)
				return
			end
			local target = Vermilion:GetUserBySteamID(text[2])
			if(target != nil) then
				log("Cannot add duplicate SteamID!", nil, NOTIFY_ERROR)
				return
			end
			local usr = Vermilion:CreateUserObj(text[1], string.upper(text[2]), Vermilion:GetDefaultRank(), {})
			table.insert(Vermilion.Data.Users, usr)
			log("Added user! Name will be updated at next login. You can now use !setrank to change their rank.")
		end
	})

	Vermilion:AddChatCommand({
		Name = "delplayer",
		Description = "Delete a user from the database",
		Syntax = "<steamid>",
		Permissions = { "manage_ranks" },
		Function = function(sender, text, log, glog)
			if(table.Count(text) < 1) then
				log("bad_syntax", nil, NOTIFY_ERROR)
				return
			end
			local target = Vermilion:GetUserBySteamID(text[1])
			if(target == nil) then
				log("Cannot find SteamID in database!", nil, NOTIFY_ERROR)
				return
			end
			for i,k in pairs(Vermilion.Data.Users) do
				if(k.SteamID == text[1]) then
					table.RemoveByValue(Vermilion.Data.Users, k)
					log("Removed user!")
					break
				end
			end
		end
	})

	Vermilion:AddChatCommand({
		Name = "setrank",
		Description = "Set a player's rank",
		Syntax = "<player> <rank>",
		CanMute = true,
		Permissions = { "manage_ranks" },
		AllValid = {
			{ Size = nil, Indexes = { 1 } }
		},
		Predictor = function(pos, current, all, vplayer)
			if(pos == 1) then
				return VToolkit.MatchPlayerPart(current)
			elseif(pos == 2) then
				local tab = {}
				for i,k in pairs(Vermilion.Data.Ranks) do
					if(string.find(string.lower(k.Name), string.lower(current))) then
						table.insert(tab, k.Name)
					end
				end
				return tab
			end
		end,
		Function = function(sender, text, log, glog)
			if(table.Count(text) < 2) then
				log("bad_syntax", nil, NOTIFY_ERROR)
				return
			end
			local target = VToolkit.LookupPlayer(text[1])
			if(not IsValid(target)) then
				target = Vermilion:GetUserByName(text[1])
				if(target == nil) then
					log("no_users", nil, NOTIFY_ERROR)
					return
				else
					if(Vermilion:GetRank(text[2]) == nil) then
						log("no_rank", nil, NOTIFY_ERROR)
						return false
					end
					target:SetRank(Vermilion:GetRank(text[2]):GetUID())
					log("Updated rank of offline player!", nil, NOTIFY_GENERIC)
					return
				end
			end
			if(Vermilion:GetRank(text[2]) == nil) then
				log("no_rank", nil, NOTIFY_ERROR)
				return false
			end
			local promotion = true
			if(Vermilion:GetUser(target):GetRank():GetImmunity() < Vermilion:GetRank(text[2]):GetImmunity()) then promotion = false end
			Vermilion:GetUser(target):SetRank(Vermilion:GetRank(text[2]):GetUID())
			Vermilion.Log(Vermilion:GetRank(text[2]):GetUID())
			if(promotion) then
				glog(sender:GetName() .. " has promoted " .. target:GetName() .. " to " .. text[2])
			else
				glog(sender:GetName() .. " has demoted " .. target:GetName() .. " to " .. text[2])
			end
		end,
		AllBroadcast = function(sender, text)
			return sender:GetName() .. " has moved everybody to the " .. text[2] .. " rank."
		end
	})

	Vermilion:AddChatCommand({
		Name = "getrank",
		Description = "Retrieves the rank of a player.",
		Syntax = "[player]",
		Predictor = function(pos, current, all, vplayer)
			if(pos == 1) then
				return VToolkit.MatchPlayerPart(current)
			end
		end,
		Function = function(sender, text, log, glog)
			local target = sender
			if(table.Count(text) > 0) then
				target = VToolkit.LookupPlayer(text[1])
			end
			if(not IsValid(target)) then
				log("no_users", nil, NOTIFY_ERROR)
				return
			end
			if(target == sender) then
				log("Your rank is ".. Vermilion:GetUser(target):GetRankName())
			else
				log(target:GetName() .. "'s rank is " .. Vermilion:GetUser(target):GetRankName())
			end
		end
	})


end

function MODULE:InitShared()
	local meta = FindMetaTable("Player")

	function meta:IsAdmin()
		return Vermilion:HasPermission(self, "identify_as_admin") or self:IsSuperAdmin()
	end

	function meta:IsSuperAdmin()
		return Vermilion:HasPermission(self, "identify_as_superadmin")
	end

	meta.oldGetUserGroup = meta.GetUserGroup
	function meta:GetUserGroup()
		if(not Vermilion:HasPermission(self, "identify_as_superadmin")) then
			if(Vermilion:HasPermission(self, "identify_as_admin")) then
				return "admin"
			end
		else
			return "superadmin"
		end
		return Vermilion:GetUser(self):GetRankName()
	end



	self:AddHook(Vermilion.Event.MOD_LOADED, function()
		local mod = Vermilion:GetModule("server_settings")
		if(mod != nil) then
			mod:AddOption({
				Module = "rank_editor",
				Name = "enabled",
				GuiText = "Enable chat tags",
				Type = "Checkbox",
				Category = "Misc",
				Default = true
			})
		end
	end)
end

function MODULE:InitServer()

	self:NetHook("VGetPermissions", function(vplayer)
		local rank = net.ReadString()
		local rankData = Vermilion:GetRankByID(rank)
		if(rankData != nil) then
			MODULE:NetStart("VGetPermissions")
			net.WriteString(rank)
			net.WriteTable(rankData.Permissions)
			net.Send(vplayer)
		end
	end)

	self:NetHook("VGivePermission", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_ranks")) then
			local rank = net.ReadString()
			local permission = net.ReadString()

			Vermilion:GetRankByID(rank):AddPermission(permission)
		end
	end)

	self:NetHook("VRevokePermission", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_ranks")) then
			local rank = net.ReadString()
			local permission = net.ReadString()

			Vermilion:GetRankByID(rank):RevokePermission(permission)
		end
	end)

	self:NetHook("VAddRank", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_ranks")) then
			local newRank = net.ReadString()
			Vermilion:AddRank(newRank, nil, false, Color(0, 0, 0), "user_suit")
		end
	end)

	self:NetHook("VChangeRankColour", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_ranks")) then
			local rankName = net.ReadString()
			local colour = net.ReadColor()

			Vermilion:GetRankByID(rankName):SetColour(colour)
		end
	end)

	self:NetHook("VMoveRank", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_ranks")) then
			local rnk = net.ReadString()
			local dir = net.ReadBoolean()

			if(dir) then
				Vermilion:GetRankByID(rnk):MoveUp()
			else
				Vermilion:GetRankByID(rnk):MoveDown()
			end
		end
	end)

	self:NetHook("VRemoveRank", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_ranks")) then
			local rnk = net.ReadString()

			Vermilion:GetRankByID(rnk):Delete()
		end
	end)

	self:NetHook("VRenameRank", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_ranks")) then
			local rnk = net.ReadString()
			local new = net.ReadString()

			Vermilion:GetRankByID(rnk):Rename(new)
		end
	end)

	self:NetHook("VSetRankDefault", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_ranks")) then
			local new = net.ReadString()

			Vermilion:SetData("default_rank", new)
			Vermilion:BroadcastRankData(VToolkit.GetValidPlayers())
		end
	end)

	self:NetHook("VChangeRankIcon", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_ranks")) then
			local rankName = net.ReadString()
			local icon = net.ReadString()

			Vermilion:GetRankByID(rankName):SetIcon(icon)
		end
	end)

	self:NetHook("VAssignRank", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_ranks")) then
			local ply = net.ReadEntity()
			local newRank = net.ReadString()

			if(IsValid(ply)) then
				Vermilion:GetUser(ply):SetRank(newRank)
			end
		end
	end)

	self:NetHook("VAssignParent", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_ranks")) then
			local trank = Vermilion:GetRankByID(net.ReadString())
			local proposedrank = net.ReadString()
			if(proposedrank == "nil") then
				trank:SetParent(nil)
				return
			end
			trank:SetParent(Vermilion:GetRankByID(proposedrank))
		end
	end)

	self:AddLPHook("PlayerInitialSpawn", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "identify_as_admin")) then
			vplayer:SetNWString("UserGroup", "admin")
		end
		if(Vermilion:HasPermission(vplayer, "identify_as_superadmin")) then
			vplayer:SetNWString("UserGroup", "superadmin")
		end
	end)

	self:AddDataChangeHook("enabled", "EnableBroadcaster", function(value)
		VToolkit:SetGlobalValue("VChatColourer", value)
	end)
	VToolkit:SetGlobalValue("VChatColourer", self:GetData("enabled", true, true))
end

function MODULE:InitClient()
	Vermilion:AddCommand("setrank", function(sender, args)
		Vermilion.Log("You aren't supposed to use this command here.")
		Vermilion.Log("Type the command into the server console (not here)")
		if(table.Count(args) < 2) then return end
		Vermilion.Log("If you use RCON, try:")
		Vermilion.Log("")
		Vermilion.Log("rcon vermilion setrank " .. table.concat(args, " ", 1, 2))
	end)

	self:AddHook("OnPlayerChat", function(sender, text, teamChat, dead)
		if(not VToolkit:GetGlobalValue("VChatColourer")) then return end
		if(not IsValid(sender)) then return end
		local tab = {}
		if(dead) then
			table.insert(tab, Color(255, 30, 40))
			table.insert(tab, "*DEAD* ")
		end

		if(teamChat) then
			table.insert(tab, Color(30, 160, 40))
			table.insert(tab, "(TEAM) ")
		end

		local rank = sender:GetNWString("Vermilion_Rank")
		rank = Vermilion:GetRankByID(rank).Name

		local ranku = string.SetChar(rank, 1, string.upper(string.GetChar(rank, 1)))
		table.insert(tab, Vermilion.Colours.White)
		table.insert(tab, "[" .. ranku .. "] ")

		if(IsValid(sender)) then
			if(Vermilion:GetRankByID(sender:GetNWString("Vermilion_Rank")):GetColour() == nil) then
				table.insert(tab, Vermilion.Colours.White)
			else
				table.insert(tab, Vermilion:GetRankByID(sender:GetNWString("Vermilion_Rank")):GetColour())
			end
			table.insert(tab, sender:Nick())
		else
			table.insert(tab, "Console")
		end

		table.insert(tab, Vermilion.Colours.White)
		table.insert(tab, ": " .. text)

		chat.AddText(unpack(tab))
		hook.Run("VOnPlayerChat", sender, text, teamChat, dead) -- run a compatibility hook
		return true
	end)

	self:NetHook("VGetPermissions", function()
		local rank = net.ReadString()
		local paneldata = Vermilion.Menu.Pages["permission_editor"]
		if(rank == paneldata.RankList:GetSelected()[1].UniqueRankID) then
			local permissions = net.ReadTable()
			local rnkPList = paneldata.RankPermissions
			rnkPList:Clear()
			for i,k in pairs(permissions) do
				rnkPList:AddLine(k, Vermilion:LookupPermissionOwner(k))
			end
		end
	end)

	self:AddHook(Vermilion.Event.CLIENT_NewPermissionData, function()
		local rank_overview_list = Vermilion.Menu.Pages["rank_editor"].RankList
		if(IsValid(rank_overview_list)) then
			Vermilion:PopulateRankTable(rank_overview_list, true, true)
		else
			return
		end
		rank_overview_list:OnRowSelected()
		local permission_editor_list = Vermilion.Menu.Pages["permission_editor"].RankList
		if(IsValid(permission_editor_list)) then
			Vermilion:PopulateRankTable(permission_editor_list)
		end
	end)

	self:AddHook("VPlayerInitialSpawn", function(name, steamid, rank, entindex)
		local player_list = Vermilion.Menu.Pages["rank_assignment"].PlayerList
		if(IsValid(player_list)) then
			player_list:AddLine(name, rank).EntityID = entindex
		end
	end)

	self:AddHook("Vermilion2_TargetIDDataIcon", function(vplayer)
		if(vplayer.VIcon == nil or vplayer.VIcon == "" or vplayer.VIcon != string.lower(Vermilion:GetRankByID(vplayer:GetNWString("Vermilion_Rank")):GetIcon())) then
			if(Vermilion:GetRankByID(vplayer:GetNWString("Vermilion_Rank")):GetIcon() == nil) then return end
			vplayer.VIcon = string.lower(Vermilion:GetRankByID(vplayer:GetNWString("Vermilion_Rank")):GetIcon())
			vplayer.VIconMat = Material("icon16/" .. vplayer.VIcon .. ".png", "noclamp smooth")
		end
		return vplayer.VIconMat
	end)


	Vermilion.Menu:AddCategory("ranks", 3)

	self:AddMenuPage({
			ID = "rank_editor",
			Name = "Rank Editor",
			Order = 0,
			Category = "ranks",
			Size = { 700, 560 },
			Conditional = function(vplayer)
				return Vermilion:HasPermission("manage_ranks")
			end,
			Builder = function(panel, paneldata)
				local rankList = nil
				local addRank = nil
				local delRank = nil
				local renameRank = nil
				local moveUp = nil
				local moveDown = nil
				local setDefault = nil
				local setColour = nil
				local setIcon = nil
				local setParent = nil

				addRank = VToolkit:CreateButton("Add", function()
					VToolkit:CreateTextInput("Enter the name for the new rank:", function(text)
						local has = false
						for i,k in pairs(rankList:GetLines()) do
							if(k:GetValue(1) == text) then
								has = true
								break
							end
						end
						if(has) then
							VToolkit:CreateErrorDialog("This rank already exists!")
							return
						end
						MODULE:NetStart("VAddRank")
						net.WriteString(text)
						net.SendToServer()
						VToolkit:CreateDialog("Success", "Rank created!")
					end)
				end)
				addRank:SetPos(panel:GetWide() - 285, 30)
				addRank:SetSize(panel:GetWide() - addRank:GetX() - 5, 30)
				addRank:SetParent(panel)
				paneldata.addRank = addRank

				local addImg = vgui.Create("DImage")
				addImg:SetImage("icon16/add.png")
				addImg:SetSize(16, 16)
				addImg:SetParent(addRank)
				addImg:SetPos(10, (addRank:GetTall() - 16) / 2)

				delRank = VToolkit:CreateButton("Delete", function()
					local rnk = rankList:GetSelected()[1]
					if(not rnk.Protected) then
						VToolkit:CreateConfirmDialog("Really delete the rank \"" .. rnk:GetValue(1) .. "\"?", function()
							MODULE:NetStart("VRemoveRank")
							net.WriteString(rnk.UniqueRankID)
							net.SendToServer()
							VToolkit:CreateDialog("Success", "Rank deleted!")
							delRank:SetDisabled(true)
							renameRank:SetDisabled(true)
							moveUp:SetDisabled(true)
							moveDown:SetDisabled(true)
							setDefault:SetDisabled(true)
							setColour:SetDisabled(true)
							setIcon:SetDisabled(true)
							setParent:SetDisabled(true)
						end, { Confirm = "Yes", Deny = "No", Default = false })
					else
						VToolkit:CreateErrorDialog("This is a protected rank!")
					end
				end)
				delRank:SetPos(panel:GetWide() - 285, 70)
				delRank:SetSize(panel:GetWide() - delRank:GetX() - 5, 30)
				delRank:SetParent(panel)
				delRank:SetDisabled(true)
				paneldata.delRank = delRank

				local remImg = vgui.Create("DImage")
				remImg:SetImage("icon16/delete.png")
				remImg:SetSize(16, 16)
				remImg:SetParent(delRank)
				remImg:SetPos(10, (delRank:GetTall() - 16) / 2)

				renameRank = VToolkit:CreateButton("Rename", function()
					local rnk = rankList:GetSelected()[1]
					if(not rnk.Protected) then
						VToolkit:CreateTextInput("Enter the new name for the \"" .. rnk:GetValue(1) .. "\" rank:", function(text)
							local has = false
							for i,k in pairs(rankList:GetLines()) do
								if(k:GetValue(1) == text) then
									has = true
									break
								end
							end
							if(not has) then
								MODULE:NetStart("VRenameRank")
								net.WriteString(rnk.UniqueRankID)
								net.WriteString(text)
								net.SendToServer()
								VToolkit:CreateDialog("Success", "Rank renamed!")
							else
								VToolkit:CreateErrorDialog("This rank already exists!")
							end
						end)
					else
						VToolkit:CreateErrorDialog("This is a protected rank!")
					end
				end)
				renameRank:SetPos(panel:GetWide() - 285, 110)
				renameRank:SetSize(panel:GetWide() - renameRank:GetX() - 5, 30)
				renameRank:SetParent(panel)
				renameRank:SetDisabled(true)
				paneldata.renameRank = renameRank

				local renImg = vgui.Create("DImage")
				renImg:SetImage("icon16/textfield_rename.png")
				renImg:SetSize(16, 16)
				renImg:SetParent(renameRank)
				renImg:SetPos(10, (renameRank:GetTall() - 16) / 2)

				moveUp = VToolkit:CreateButton("Move Up", function()
					local rnk = rankList:GetSelected()[1]
					if(not rnk.Protected) then
						if(rnk:GetID() == 2) then
							VToolkit:CreateErrorDialog("This rank cannot be moved up.")
						else
							MODULE:NetStart("VMoveRank")
							net.WriteString(rnk.UniqueRankID)
							net.WriteBoolean(true) -- Up
							net.SendToServer()
						end
					else
						VToolkit:CreateErrorDialog("This is a protected rank!")
					end
				end)
				moveUp:SetPos(panel:GetWide() - 285, 150)
				moveUp:SetSize(panel:GetWide() - moveUp:GetX() - 5, 30)
				moveUp:SetParent(panel)
				moveUp:SetDisabled(true)
				paneldata.moveUp = moveUp

				local upImg = vgui.Create("DImage")
				upImg:SetImage("icon16/arrow_up.png")
				upImg:SetSize(16, 16)
				upImg:SetParent(moveUp)
				upImg:SetPos(10, (moveUp:GetTall() - 16) / 2)

				moveDown = VToolkit:CreateButton("Move Down", function()
					local rnk = rankList:GetSelected()[1]
					if(not rnk.Protected) then
						if(rnk:GetID() == table.Count(rankList:GetLines())) then
							VToolkit:CreateErrorDialog("This rank cannot be moved down.")
						else
							MODULE:NetStart("VMoveRank")
							net.WriteString(rnk.UniqueRankID)
							net.WriteBoolean(false) -- Down
							net.SendToServer()
						end
					else
						VToolkit:CreateErrorDialog("This is a protected rank!")
					end
				end)
				moveDown:SetPos(panel:GetWide() - 285, 190)
				moveDown:SetSize(panel:GetWide() - moveDown:GetX() - 5, 30)
				moveDown:SetParent(panel)
				moveDown:SetDisabled(true)
				paneldata.moveDown = moveDown

				local downImg = vgui.Create("DImage")
				downImg:SetImage("icon16/arrow_down.png")
				downImg:SetSize(16, 16)
				downImg:SetParent(moveDown)
				downImg:SetPos(10, (moveDown:GetTall() - 16) / 2)

				setDefault = VToolkit:CreateButton("Set As Default", function()
					local rnk = rankList:GetSelected()[1]
					local cont = function()
						MODULE:NetStart("VSetRankDefault")
						net.WriteString(rnk.UniqueRankID)
						net.SendToServer()
						VToolkit:CreateDialog("Success", "Rank set as default!")
					end
					if(rnk.Protected) then
						VToolkit:CreateConfirmDialog("Are you sure you want to set a protected rank as the default rank?", cont, { Confirm = "Yes", Deny = "No", Default = false })
					else
						cont()
					end
				end)
				setDefault:SetPos(panel:GetWide() - 285, 230)
				setDefault:SetSize(panel:GetWide() - setDefault:GetX() - 5, 30)
				setDefault:SetParent(panel)
				setDefault:SetDisabled(true)
				paneldata.setDefault = setDefault

				local defImg = vgui.Create("DImage")
				defImg:SetImage("icon16/accept.png")
				defImg:SetSize(16, 16)
				defImg:SetParent(setDefault)
				defImg:SetPos(10, (setDefault:GetTall() - 16) / 2)

				setColour = VToolkit:CreateButton("Set Colour", function()
					local frame = VToolkit:CreateFrame({
						size = { 400, 270 },
						pos = { (ScrW() - 400) / 2, (ScrH() - 270) / 2 },
						closeBtn = false,
						draggable = true,
						title = "Set Rank Colour - " .. rankList:GetSelected()[1]:GetValue(1)
					})
					frame:DoModal()
					frame:MakePopup()
					frame:SetAutoDelete(true)

					local rankName = rankList:GetSelected()[1].UniqueRankID

					local mixer = VToolkit:CreateColourMixer(true, false, true, Vermilion:GetRankByID(rankName):GetColour(), function(colour)

					end)
					mixer:SetPos(10, 30)
					mixer:SetParent(frame)

					local ok = VToolkit:CreateButton("Save", function()
						MODULE:NetStart("VChangeRankColour")
						net.WriteString(rankName)
						local colour = mixer:GetColor()
						if(istable(mixer:GetColor())) then
							colour = Color(mixer:GetColor().r, mixer:GetColor().g, mixer:GetColor().b)
						end
						net.WriteColor(colour)
						net.SendToServer()
						frame:Remove()
					end)
					ok:SetPos(300, 30)
					ok:SetSize(80, 20)
					ok:SetParent(frame)


					local cancel = VToolkit:CreateButton("Cancel", function()
						frame:Remove()
					end)
					cancel:SetPos(300, 60)
					cancel:SetSize(80, 20)
					cancel:SetParent(frame)
				end)
				setColour:SetPos(panel:GetWide() - 285, 270)
				setColour:SetSize(panel:GetWide() - setColour:GetX() - 5, 30)
				setColour:SetParent(panel)
				setColour:SetDisabled(true)
				paneldata.setColour = setColour

				local colourImg = vgui.Create("DImage")
				colourImg:SetImage("icon16/color_wheel.png")
				colourImg:SetSize(16, 16)
				colourImg:SetParent(setColour)
				colourImg:SetPos(10, (setColour:GetTall() - 16) / 2)

				setIcon = VToolkit:CreateButton("Set Icon", function()
					local frame = VToolkit:CreateFrame({
						size = { 400, 270 },
						pos = { (ScrW() - 400) / 2, (ScrH() - 270) / 2 },
						closeBtn = false,
						draggable = true,
						title = "Set Rank Icon - " .. rankList:GetSelected()[1]:GetValue(1)
					})
					frame:DoModal()
					frame:MakePopup()
					frame:SetAutoDelete(true)

					local rankName = rankList:GetSelected()[1].UniqueRankID

					local icnBrowser = vgui.Create("DIconBrowser")
					icnBrowser:SetPos(10, 30)
					icnBrowser:SetSize(280, 230)
					icnBrowser:SetParent(frame)
					icnBrowser:SelectIcon(Vermilion:GetRankIcon(rankName))

					local ok = VToolkit:CreateButton("Save", function()
						MODULE:NetStart("VChangeRankIcon")
						net.WriteString(rankName)
						local icn = icnBrowser.m_strSelectedIcon
						icn = string.Replace(icn, "icon16/", "")
						icn = string.Replace(icn, ".png", "")
						net.WriteString(icn)
						net.SendToServer()
						frame:Remove()
					end)
					ok:SetPos(300, 30)
					ok:SetSize(80, 20)
					ok:SetParent(frame)


					local cancel = VToolkit:CreateButton("Cancel", function()
						frame:Remove()
					end)
					cancel:SetPos(300, 60)
					cancel:SetSize(80, 20)
					cancel:SetParent(frame)
				end)
				setIcon:SetPos(panel:GetWide() - 285, 310)
				setIcon:SetSize(panel:GetWide() - setIcon:GetX() - 5, 30)
				setIcon:SetParent(panel)
				setIcon:SetDisabled(true)
				paneldata.setIcon = setIcon

				local icnImg = vgui.Create("DImage")
				icnImg:SetImage("icon16/picture.png")
				icnImg:SetSize(16, 16)
				icnImg:SetParent(setIcon)
				icnImg:SetPos(10, (setIcon:GetTall() - 16) / 2)

				setParent = VToolkit:CreateButton("Set Parent Rank", function()
					local selected = rankList:GetSelected()[1]
					if(rankList:GetSelected()[1].Protected) then
						VToolkit:CreateErrorDialog("This is a protected rank!")
						return
					end
					local possibleParents = { { Name = "None", Value = nil } }
					for i,k in pairs(rankList:GetLines()) do
						if(k:GetValue(1) == selected:GetValue(1)) then continue end
						if(tonumber(k:GetValue(3)) < tonumber(selected:GetValue(3))) then continue end
						if(k.Protected) then continue end
						table.insert(possibleParents, { Name = k:GetValue(1), Value = k.UniqueRankID })
					end
					local values = {}
					for i,k in pairs(possibleParents) do
						table.insert(values, k.Name)
					end
					VToolkit:CreateComboboxPanel("Choose a parent rank:", values, 1, function(val)
						local nval = nil
						for i,k in pairs(possibleParents) do
							if(k.Name == val) then
								nval = k.Value
								break
							end
						end
						MODULE:NetStart("VAssignParent")
						net.WriteString(selected.UniqueRankID)
						net.WriteString(tostring(nval))
						net.SendToServer()
					end)
				end)
				setParent:SetPos(panel:GetWide() - 285, 350)
				setParent:SetSize(panel:GetWide() - setParent:GetX() - 5, 30)
				setParent:SetParent(panel)
				setParent:SetDisabled(true)
				paneldata.setParent = setParent

				local parentImg = vgui.Create("DImage")
				parentImg:SetImage("icon16/group.png")
				parentImg:SetSize(16, 16)
				parentImg:SetParent(setParent)
				parentImg:SetPos(10, (setParent:GetTall() - 16) / 2)


				rankList = VToolkit:CreateList({
					cols = {
						"Name",
						"Parent",
						"Immunity",
						"Default"
					},
					multiselect = false,
					sortable = false
				})
				rankList:SetPos(10, 30)
				rankList:SetSize(400, panel:GetTall() - 40)
				rankList:SetParent(panel)
				paneldata.RankList = rankList

				rankList.Columns[3]:SetFixedWidth(59)
				rankList.Columns[4]:SetFixedWidth(52)

				local rankHeader = VToolkit:CreateHeaderLabel(rankList, "Ranks")
				rankHeader:SetParent(panel)

				function rankList:OnRowSelected(index, line)
					local enabled = self:GetSelected()[1] == nil
					delRank:SetDisabled(enabled)
					renameRank:SetDisabled(enabled)
					moveUp:SetDisabled(enabled)
					moveDown:SetDisabled(enabled)
					setDefault:SetDisabled(enabled)
					setColour:SetDisabled(enabled)
					setIcon:SetDisabled(enabled)
					setParent:SetDisabled(enabled)
				end

			end,
			OnOpen = function(panel, paneldata)
				Vermilion:PopulateRankTable(paneldata.RankList, true, true)
				paneldata.delRank:SetDisabled(true)
				paneldata.renameRank:SetDisabled(true)
				paneldata.moveUp:SetDisabled(true)
				paneldata.moveDown:SetDisabled(true)
				paneldata.setDefault:SetDisabled(true)
				paneldata.setColour:SetDisabled(true)
				paneldata.setIcon:SetDisabled(true)
				paneldata.setParent:SetDisabled(true)
			end
		})

	self:AddMenuPage({
			ID = "permission_editor",
			Name = "Permission Editor",
			Order = 1,
			Category = "ranks",
			Size = { 1000, 560 },
			Conditional = function(vplayer)
				return Vermilion:HasPermission("manage_ranks")
			end,
			Builder = function(panel, paneldata)

				local allPermissions = nil
				local rankPermissions = nil
				local givePermission = nil
				local takePermission = nil
				local rankList = nil


				givePermission = VToolkit:CreateButton("Give Permission", function()
					for i,k in pairs(allPermissions:GetSelected()) do
						local has = false
						for i1,k1 in pairs(rankPermissions:GetLines()) do
							if(k1:GetValue(1) == k:GetValue(1)) then
								has = true
								break
							end
						end
						if(not has) then
							rankPermissions:AddLine(k:GetValue(1), k:GetValue(2))
						end
						MODULE:NetStart("VGivePermission")
						net.WriteString(rankList:GetSelected()[1].UniqueRankID)
						net.WriteString(k:GetValue(1))
						net.SendToServer()
					end
				end)
				givePermission:SetPos(530, 120)
				givePermission:SetSize(150, 20)
				givePermission:SetParent(panel)
				givePermission:SetEnabled(false)
				paneldata.GivePermission = givePermission

				takePermission = VToolkit:CreateButton("Revoke Permission", function()
					for i,k in pairs(rankPermissions:GetSelected()) do
						MODULE:NetStart("VRevokePermission")
						net.WriteString(rankList:GetSelected()[1].UniqueRankID)
						net.WriteString(k:GetValue(1))
						net.SendToServer()
						rankPermissions:RemoveLine(k:GetID())
					end
				end)
				takePermission:SetPos(530, 150)
				takePermission:SetSize(150, 20)
				takePermission:SetParent(panel)
				takePermission:SetEnabled(false)
				paneldata.TakePermission = takePermission



				rankList = VToolkit:CreateList({
					cols = {
						"Name"
					},
					multiselect = false,
					sortable = false,
					centre = true
				})
				rankList:SetPos(10, 30)
				rankList:SetSize(200, panel:GetTall() - 40)
				rankList:SetParent(panel)
				paneldata.RankList = rankList

				local rankHeader = VToolkit:CreateHeaderLabel(rankList, "Ranks")
				rankHeader:SetParent(panel)

				function rankList:OnRowSelected(index, line)
					givePermission:SetEnabled(self:GetSelected()[1] != nil and allPermissions:GetSelected()[1] != nil)
					takePermission:SetEnabled(self:GetSelected()[1] != nil and rankPermissions:GetSelected()[1] != nil)
					MODULE:NetStart("VGetPermissions")
					net.WriteString(rankList:GetSelected()[1].UniqueRankID)
					net.SendToServer()
				end


				rankPermissions = VToolkit:CreateList({
					cols = {
						"Name",
						"Module"
					}
				})
				rankPermissions:SetPos(220, 30)
				rankPermissions:SetSize(290, panel:GetTall() - 40)
				rankPermissions:SetParent(panel)
				paneldata.RankPermissions = rankPermissions

				local rankPermissionsHeader = VToolkit:CreateHeaderLabel(rankPermissions, "Rank Permissions")
				rankPermissionsHeader:SetParent(panel)

				function rankPermissions:OnRowSelected(index, line)
					takePermission:SetEnabled(self:GetSelected()[1] != nil and rankList:GetSelected()[1] != nil)
				end

				VToolkit:CreateSearchBox(rankPermissions)




				allPermissions = VToolkit:CreateList({
					cols = {
						"Name",
						"Module"
					}
				})
				allPermissions:SetPos(panel:GetWide() - 300, 30)
				allPermissions:SetSize(290, panel:GetTall() - 40)
				allPermissions:SetParent(panel)
				paneldata.AllPermissions = allPermissions

				local allPermissionsHeader = VToolkit:CreateHeaderLabel(allPermissions, "All Permissions")
				allPermissionsHeader:SetParent(panel)

				function allPermissions:OnRowSelected(index, line)
					givePermission:SetEnabled(self:GetSelected()[1] != nil and rankList:GetSelected()[1] != nil)
				end

				VToolkit:CreateSearchBox(allPermissions)

			end,
			OnOpen = function(panel, paneldata)
				Vermilion:PopulateRankTable(paneldata.RankList)
				paneldata.AllPermissions:Clear()
				for i,k in pairs(Vermilion.Data.Permissions) do
					if(Vermilion:GetModule(k.Owner) == nil) then continue end
					paneldata.AllPermissions:AddLine(k.Permission, Vermilion:GetModule(k.Owner).Name)
				end
			end,
			Destroyer = function(panel, paneldata)
				paneldata.GivePermission:SetEnabled(false)
				paneldata.TakePermission:SetEnabled(false)
				paneldata.RankPermissions:Clear()
				paneldata.RankList:Clear()
			end
		})

	self:AddMenuPage({
			ID = "rank_assignment",
			Name = "Rank Assignment",
			Order = 2,
			Category = "ranks",
			Size = { 600, 560 },
			Conditional = function(vplayer)
				return Vermilion:HasPermission("manage_ranks")
			end,
			Builder = function(panel, paneldata)
				local assignRank = nil
				local rankList = nil
				local playerList = VToolkit:CreateList({
					cols = {
						"Name",
						"Rank"
					},
					multiselect = false,
					sortable = false
				})
				playerList:SetPos(10, 30)
				playerList:SetSize(200, panel:GetTall() - 40)
				playerList:SetParent(panel)
				paneldata.PlayerList = playerList

				local playerHeader = VToolkit:CreateHeaderLabel(playerList, "Active Players")
				playerHeader:SetParent(panel)

				function playerList:OnRowSelected(index, line)
					assignRank:SetDisabled(self:GetSelected()[1] == nil and rankList:GetSelected()[1] == nil)
				end

				VToolkit:CreateSearchBox(playerList)


				rankList = VToolkit:CreateList({
					cols = {
						"Name"
					},
					multiselect = false,
					sortable = false,
					centre = true
				})
				rankList:SetPos(220, 30)
				rankList:SetSize(200, panel:GetTall() - 40)
				rankList:SetParent(panel)
				paneldata.RankList = rankList

				local rankHeader = VToolkit:CreateHeaderLabel(rankList, "Ranks")
				rankHeader:SetParent(panel)

				function rankList:OnRowSelected(index, line)
					assignRank:SetDisabled(self:GetSelected()[1] == nil and playerList:GetSelected()[1] == nil)
				end

				assignRank = VToolkit:CreateButton("Assign Rank", function()
					if(playerList:GetSelected()[1] == nil) then return end
					if(Vermilion.Data.Rank.Protected and Entity(playerList:GetSelected()[1].EntityID) == LocalPlayer()) then
						VToolkit:CreateConfirmDialog("Really modify your rank?", function()
							MODULE:NetStart("VAssignRank")
							net.WriteEntity(Entity(playerList:GetSelected()[1].EntityID))
							net.WriteString(rankList:GetSelected()[1].UniqueRankID)
							net.SendToServer()
							playerList:GetSelected()[1]:SetValue(2, rankList:GetSelected()[1].UniqueRankID)
						end, { Confirm = "Yes", Deny = "No", Default = false })
					else
						MODULE:NetStart("VAssignRank")
						net.WriteEntity(Entity(playerList:GetSelected()[1].EntityID))
						net.WriteString(rankList:GetSelected()[1].UniqueRankID)
						net.SendToServer()
						playerList:GetSelected()[1]:SetValue(2, rankList:GetSelected()[1]:GetValue(1))
					end
				end)
				assignRank:SetPos(440, (panel:GetTall() - 20) / 2)
				assignRank:SetSize(panel:GetWide() - 460, 20)
				assignRank:SetParent(panel)
				assignRank:SetDisabled(true)

				paneldata.PlayerList = playerList

			end,
			OnOpen = function(panel, paneldata)
				Vermilion:PopulateRankTable(paneldata.RankList, false, true)
				paneldata.PlayerList:Clear()
				for i,k in pairs(VToolkit.GetValidPlayers()) do
					paneldata.PlayerList:AddLine(k:GetName(), Vermilion:GetRankByID(k:GetNWString("Vermilion_Rank", "player")).Name).EntityID = k:EntIndex()
				end
			end
		})

	self:AddMenuPage({
			ID = "rank_overview",
			Name = "Rank Overview",
			Order = 3,
			Category = "ranks",
			Size = { 600, 560 },
			Conditional = function(vplayer)
				return Vermilion:HasPermission("manage_ranks")
			end,
			Builder = function(panel, paneldata)
				local label = VToolkit:CreateLabel(Vermilion:TranslateStr("under_construction"))
				label:SetFont("DermaLarge")
				label:SizeToContents()
				label:SetPos((panel:GetWide() - label:GetWide()) / 2, (panel:GetTall() - label:GetTall()) / 2)
				label:SetParent(panel)
			end
		})
end
