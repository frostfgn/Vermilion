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
MODULE.Name = "Loadouts"
MODULE.ID = "loadout"
MODULE.Description = "Set the weapons that players spawn with."
MODULE.Author = "Ned"
MODULE.Permissions = {
	"manage_loadout"
}
MODULE.NetworkStrings = {
	"VGetLoadout",
	"VGiveLoadoutWeapons",
	"VTakeLoadoutWeapons"
}

local defaultLoadout = {
	"weapon_crowbar",
	"weapon_pistol",
	"weapon_smg1",
	"weapon_frag",
	"weapon_physcannon",
	"weapon_crossbow",
	"weapon_shotgun",
	"weapon_357",
	"weapon_rpg",
	"weapon_ar2",
	"gmod_tool",
	"gmod_camera",
	"weapon_physgun"
}

function MODULE:InitServer()

	if(not MODULE:GetData("uidUpdate", false)) then
		local ndata = {}
		for i,k in pairs(MODULE:GetAllData()) do
			if(i == "enabled_on_non_sandbox") then continue end
			local obj = k
			local nr = Vermilion:GetRank(i):GetUID()
			ndata[nr] = obj
			MODULE:SetData(i, nil)
		end
		for i,k in pairs(ndata) do
			MODULE:SetData(i, k)
		end
		MODULE:SetData("uidUpdate", true)
	end

	self:AddHook("PlayerLoadout", function(vplayer)
		if(not MODULE:GetData("enabled_on_non_sandbox", false, true) and engine.ActiveGamemode() != "sandbox") then return end
		if(Vermilion:GetModule("kits") != nil) then
			if(Vermilion:GetModule("kits"):WouldRun(vplayer)) then return end
		end
		local data = MODULE:GetData(Vermilion:GetUser(vplayer):GetRankUID(), defaultLoadout, true)
		if(data != nil) then
			vplayer:RemoveAllAmmo()
			if (cvars.Bool("sbox_weapons", true)) then
				vplayer:GiveAmmo(256, "Pistol", true)
				vplayer:GiveAmmo(256, "SMG1", true)
				vplayer:GiveAmmo(5, "grenade", true)
				vplayer:GiveAmmo(64, "Buckshot", true)
				vplayer:GiveAmmo(32, "357", true)
				vplayer:GiveAmmo(32, "XBowBolt", true)
				vplayer:GiveAmmo(6, "AR2AltFire", true)
				vplayer:GiveAmmo(100, "AR2", true)
			end

			for i,weapon in pairs(data) do
				vplayer:Give(weapon)
			end
			vplayer:SwitchToDefaultWeapon()
			return true
		end
	end)

	local function sendLoadout(vplayer, rnk)
		local data = MODULE:GetData(rnk, defaultLoadout, true)
		if(data != nil) then
			MODULE:NetStart("VGetLoadout")
			net.WriteString(rnk)
			net.WriteTable(data)
			net.Send(vplayer)
		else
			MODULE:NetStart("VGetLoadout")
			net.WriteString(rnk)
			net.WriteTable({})
			net.Send(vplayer)
		end
	end

	self:NetHook("VGetLoadout", function(vplayer)
		local rnk = net.ReadString()
		sendLoadout(vplayer, rnk)
	end)

	self:NetHook("VGiveLoadoutWeapons", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_loadout")) then
			local rnk = net.ReadString()
			local weapon = net.ReadString()
			if(not table.HasValue(MODULE:GetData(rnk, defaultLoadout, true), weapon)) then
				table.insert(MODULE:GetData(rnk, defaultLoadout, true), weapon)
			end
			sendLoadout(Vermilion:GetUsersWithPermission("manage_loadout"), rnk)
		end
	end)

	self:NetHook("VTakeLoadoutWeapons", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_loadout")) then
			local rnk = net.ReadString()
			local weapon = net.ReadString()
			table.RemoveByValue(MODULE:GetData(rnk, defaultLoadout, true), weapon)
			sendLoadout(Vermilion:GetUsersWithPermission("manage_loadout"), rnk)
		end
	end)

end

function MODULE:InitClient()

	self:NetHook("VGetLoadout", function()
		if(not IsValid(Vermilion.Menu.Pages["loadout"].RankList)) then return end
		if(net.ReadString() != Vermilion.Menu.Pages["loadout"].RankList:GetSelected()[1].UniqueRankID) then return end
		local data = net.ReadTable()
		local loadout_list = Vermilion.Menu.Pages["loadout"].RankPermissions
		local weps = Vermilion.Menu.Pages["loadout"].Weapons
		if(IsValid(loadout_list)) then
			loadout_list:Clear()
			for i,k in pairs(data) do
				for i1,k1 in pairs(weps) do
					if(k1.ClassName == k) then
						loadout_list:AddLine(k1.Name).ClassName = k
					end
				end
			end
		end
	end)

	Vermilion.Menu:AddCategory("player", 4)

	Vermilion.Menu:AddPage({
			ID = "loadout",
			Name = "Loadouts",
			Order = 6,
			Category = "player",
			Size = { 900, 560 },
			Conditional = function(vplayer)
				return Vermilion:HasPermission("manage_loadout")
			end,
			Builder = function(panel, paneldata)
				local giveDefault = nil
				local giveWeapon = nil
				local takeWeapon = nil
				local rankList = nil
				local allPermissions = nil
				local rankPermissions = nil

				local default = {
					["weapon_crowbar"] = "models/weapons/w_crowbar.mdl",
					["weapon_pistol"] = "models/weapons/w_pistol.mdl",
					["weapon_smg1"] = "models/weapons/w_smg1.mdl",
					["weapon_frag"] = "models/weapons/w_grenade.mdl",
					["weapon_physcannon"] = "models/weapons/w_Physics.mdl",
					["weapon_crossbow"] = "models/weapons/w_crossbow.mdl",
					["weapon_shotgun"] = "models/weapons/w_shotgun.mdl",
					["weapon_357"] = "models/weapons/w_357.mdl",
					["weapon_rpg"] = "models/weapons/w_rocket_launcher.mdl",
					["weapon_ar2"] = "models/weapons/w_irifle.mdl",
					["weapon_bugbait"] = "models/weapons/w_bugbait.mdl",
					["weapon_slam"] = "models/weapons/w_slam.mdl",
					["weapon_stunstick"] = "models/weapons/w_stunbaton.mdl",
					["weapon_physgun"] = "models/weapons/w_Physics.mdl"
				}
				function paneldata.getMdl(class)
					if(default[class] != nil) then return default[class] end
					return weapons.Get(class).WorldModel
				end

				paneldata.PreviewPanel = VToolkit:CreatePreviewPanel("model", panel, function(ent)
					ent:SetPos(Vector(20, 20, 45))
				end)


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
					giveWeapon:SetDisabled(not (self:GetSelected()[1] != nil and allPermissions:GetSelected()[1] != nil))
					takeWeapon:SetDisabled(not (self:GetSelected()[1] != nil and rankPermissions:GetSelected()[1] != nil))
					giveDefault:SetDisabled(self:GetSelected()[1] == nil)
					MODULE:NetStart("VGetLoadout")
					net.WriteString(rankList:GetSelected()[1].UniqueRankID)
					net.SendToServer()
				end

				rankPermissions = VToolkit:CreateList({
					cols = {
						"Name"
					}
				})
				rankPermissions:SetPos(220, 30)
				rankPermissions:SetSize(240, panel:GetTall() - 40)
				rankPermissions:SetParent(panel)
				paneldata.RankPermissions = rankPermissions

				local rankPermissionsHeader = VToolkit:CreateHeaderLabel(rankPermissions, "Rank Loadout")
				rankPermissionsHeader:SetParent(panel)

				function rankPermissions:OnRowSelected(index, line)
					takeWeapon:SetDisabled(not (self:GetSelected()[1] != nil and rankList:GetSelected()[1] != nil))
				end

				VToolkit:CreateSearchBox(rankPermissions)


				allPermissions = VToolkit:CreateList({
					cols = {
						"Name"
					}
				})
				allPermissions:SetPos(panel:GetWide() - 250, 30)
				allPermissions:SetSize(240, panel:GetTall() - 40)
				allPermissions:SetParent(panel)
				paneldata.AllPermissions = allPermissions

				local allPermissionsHeader = VToolkit:CreateHeaderLabel(allPermissions, "All Weapons")
				allPermissionsHeader:SetParent(panel)

				function allPermissions:OnRowSelected(index, line)
					giveWeapon:SetDisabled(not (self:GetSelected()[1] != nil and rankList:GetSelected()[1] != nil))
				end

				VToolkit:CreateSearchBox(allPermissions)



				giveDefault = VToolkit:CreateButton("Give Default Loadout", function()
					for i,k in pairs(rankPermissions:GetLines()) do
						MODULE:NetStart("VTakeLoadoutWeapons")
						net.WriteString(rankList:GetSelected()[1].UniqueRankID)
						net.WriteString(k.ClassName)
						net.SendToServer()

						rankPermissions:RemoveLine(k:GetID())
					end

					for i,k in pairs(defaultLoadout) do
						rankPermissions:AddLine(list.Get("Weapon")[k].PrintName).ClassName = k

						MODULE:NetStart("VGiveLoadoutWeapons")
						net.WriteString(rankList:GetSelected()[1].UniqueRankID)
						net.WriteString(k)
						net.SendToServer()
					end
				end)
				giveDefault:SetPos(select(1, rankPermissions:GetPos()) + rankPermissions:GetWide() + 10, 480)
				giveDefault:SetWide(panel:GetWide() - 20 - select(1, allPermissions:GetWide()) - select(1, giveDefault:GetPos()))
				giveDefault:SetParent(panel)
				giveDefault:SetDisabled(true)


				giveWeapon = VToolkit:CreateButton("Give Weapon", function()
					for i,k in pairs(allPermissions:GetSelected()) do
						local has = false
						for i1,k1 in pairs(rankPermissions:GetLines()) do
							if(k.ClassName == k1.ClassName) then has = true break end
						end
						if(has) then continue end
						rankPermissions:AddLine(k:GetValue(1)).ClassName = k.ClassName

						MODULE:NetStart("VGiveLoadoutWeapons")
						net.WriteString(rankList:GetSelected()[1].UniqueRankID)
						net.WriteString(k.ClassName)
						net.SendToServer()
					end
				end)
				giveWeapon:SetPos(select(1, rankPermissions:GetPos()) + rankPermissions:GetWide() + 10, 100)
				giveWeapon:SetWide(panel:GetWide() - 20 - select(1, allPermissions:GetWide()) - select(1, giveWeapon:GetPos()))
				giveWeapon:SetParent(panel)
				giveWeapon:SetDisabled(true)

				takeWeapon = VToolkit:CreateButton("Take Weapon", function()
					for i,k in pairs(rankPermissions:GetSelected()) do
						MODULE:NetStart("VTakeLoadoutWeapons")
						net.WriteString(rankList:GetSelected()[1].UniqueRankID)
						net.WriteString(k.ClassName)
						net.SendToServer()

						rankPermissions:RemoveLine(k:GetID())
					end
				end)
				takeWeapon:SetPos(select(1, rankPermissions:GetPos()) + rankPermissions:GetWide() + 10, 130)
				takeWeapon:SetWide(panel:GetWide() - 20 - select(1, allPermissions:GetWide()) - select(1, takeWeapon:GetPos()))
				takeWeapon:SetParent(panel)
				takeWeapon:SetDisabled(true)

				paneldata.GiveDefault = giveDefault
				paneldata.GiveWeapon = giveWeapon
				paneldata.TakeWeapon = takeWeapon


			end,
			OnOpen = function(panel, paneldata)
				if(paneldata.Weapons == nil) then
					paneldata.Weapons = {}
					for i,k in pairs(list.Get("Weapon")) do
						local name = k.PrintName
						if(name == nil or name == "") then
							name = k.ClassName
						end
						table.insert(paneldata.Weapons, { Name = name, ClassName = k.ClassName })
					end
				end
				if(table.Count(paneldata.AllPermissions:GetLines()) == 0) then
					for i,k in pairs(paneldata.Weapons) do
						local ln = paneldata.AllPermissions:AddLine(k.Name)
						ln.ClassName = k.ClassName

						ln.ModelPath = paneldata.getMdl(k.ClassName)

						ln.OldCursorMoved = ln.OnCursorMoved
						ln.OldCursorEntered = ln.OnCursorEntered
						ln.OldCursorExited = ln.OnCursorExited

						function ln:OnCursorEntered()
							if(ln.ModelPath == nil) then return end
							paneldata.PreviewPanel:SetVisible(true)
							paneldata.PreviewPanel.ModelView:SetModel(ln.ModelPath)

							if(self.OldCursorEntered) then self:OldCursorEntered() end
						end

						function ln:OnCursorExited()
							paneldata.PreviewPanel:SetVisible(false)

							if(self.OldCursorExited) then self:OldCursorExited() end
						end

						function ln:OnCursorMoved(x,y)
							if(IsValid(paneldata.PreviewPanel)) then
								local x, y = input.GetCursorPos()
								paneldata.PreviewPanel:SetPos(x - 180, y - 117)
							end

							if(self.OldCursorMoved) then self:OldCursorMoved(x,y) end
						end
					end
				end
				Vermilion:PopulateRankTable(paneldata.RankList, false, true)
				paneldata.RankPermissions:Clear()
				paneldata.GiveWeapon:SetDisabled(true)
				paneldata.TakeWeapon:SetDisabled(true)
				paneldata.GiveDefault:SetDisabled(true)
			end
		})

end

function MODULE:InitShared()
	self:AddHook(Vermilion.Event.MOD_LOADED, function()
		local mod = Vermilion:GetModule("server_settings")
		if(mod != nil) then
			mod:AddOption({
				Module = "loadout",
				Name = "enabled_on_non_sandbox",
				GuiText = "Enable Loadouts on non-sandbox gamemodes",
				Type = "Checkbox",
				Category = "Misc",
				Default = false
			})
		end
	end)
end
