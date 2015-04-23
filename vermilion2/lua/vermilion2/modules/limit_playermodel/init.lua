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
MODULE.Name = "Playermodel Enforcer"
MODULE.ID = "limit_playermodel"
MODULE.Description = "Set the player models that players can/cannot use or force a specific model for a rank."
MODULE.Author = "Ned"
MODULE.Tabs = {
	"limit_playermodel"
}
MODULE.Permissions = {
	"manage_playermodels"
}
MODULE.NetworkStrings = {
	"VGetModelList",
	"VAddModel",
	"VDelModel",
	"VModelBlacklistState"
}

function MODULE:InitServer()

	if(not MODULE:GetData("uidUpdate", false)) then
		local ndata = {}
		for i,k in pairs(MODULE:GetAllData()) do
			local nr = nil
			if(string.EndsWith(i, ":isblacklist")) then
				nr = Vermilion:GetRank(string.Explode(":", i)[1]):GetUID() .. ":isblacklist"
			else
				nr = Vermilion:GetRank(i):GetUID()
			end
			local obj = k
			ndata[nr] = obj
			MODULE:SetData(i, nil)
		end
		for i,k in pairs(ndata) do
			MODULE:SetData(i, k)
		end
		MODULE:SetData("uidUpdate", true)
	end

	self:AddHook("PlayerSetModel", function(vplayer)
		local clpm = vplayer:GetInfo("cl_playermodel")
		local modelname = player_manager.TranslatePlayerModel(clpm)
		if(not file.Exists(modelname, "GAME")) then
			timer.Simple(1, function()
				-- notify not available
			end)
			vplayer:SetModel(player_manager.AllValidModels()["kleiner"])
			return false
		end
		local rank = Vermilion:GetUser(vplayer):GetRankUID()
		if(MODULE:GetData(rank .. ":isblacklist", true, true)) then
			if(table.HasValue(MODULE:GetData(rank, {}, true), modelname)) then
				timer.Simple(1, function()
					-- notify banned
				end)
				if(not table.HasValue(MODULE:GetData(rank, {}, true), "kleiner")) then
					vplayer:SetModel(player_manager.AllValidModels()["kleiner"])
				else
					for i,k in pairs(player_manager.AllValidModels()) do
						if(not table.HasValue(MODULE:GetData(rank, {}, true), k)) then
							vplayer:SetModel(k)
							break
						end
					end
				end
				return false
			end
		else
			if(not table.HasValue(MODULE:GetData(rank, {}, true), modelname)) then
				if(table.Count(MODULE:GetData(rank, {}, true)) > 1) then
					timer.Simple(1, function()
						-- notify not whitelisted
					end)
				end
				if(table.HasValue(MODULE:GetData(rank, {}, true), player_manager.AllValidModels()["kleiner"])) then
					vplayer:SetModel(player_manager.AllValidModels()["kleiner"])
				else
					for i,k in pairs(player_manager.AllValidModels()) do
						if(table.HasValue(MODULE:GetData(rank, {}, true), k)) then
							vplayer:SetModel(k)
							break
						end
					end
				end
				return false
			end
		end
	end)

	self:NetHook("VGetModelList", function(vplayer)
		local rnk = net.ReadString()
		local data = MODULE:GetData(rnk, {}, true)
		if(data != nil) then
			MODULE:NetStart("VGetModelList")
			net.WriteString(rnk)
			net.WriteTable(data)
			net.WriteBoolean(MODULE:GetData(rnk .. ":isblacklist", true, true))
			net.Send(vplayer)
		else
			MODULE:NetStart("VGetModelList")
			net.WriteString(rnk)
			net.WriteTable({})
			net.WriteBoolean(MODULE:GetData(rnk .. ":isblacklist", true, true))
			net.Send(vplayer)
		end
	end)

	self:NetHook("VModelBlacklistState", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_playermodels")) then
			local rnk = net.ReadString()
			MODULE:SetData(rnk .. ":isblacklist", net.ReadBoolean())
		end
	end)

	self:NetHook("VAddModel", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_playermodels")) then
			local rnk = net.ReadString()
			local model = net.ReadString()
			if(not table.HasValue(MODULE:GetData(rnk, {}, true), model)) then
				table.insert(MODULE:GetData(rnk, {}, true), model)
			end
		end
	end)

	self:NetHook("VDelModel", function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_playermodels")) then
			local rnk = net.ReadString()
			local model = net.ReadString()
			table.RemoveByValue(MODULE:GetData(rnk, {}, true), model)
		end
	end)

end

function MODULE:InitClient()

	self:NetHook("VGetModelList", function()
		if(not IsValid(Vermilion.Menu.Pages["limit_playermodel"].RankList)) then return end
		if(net.ReadString() != Vermilion.Menu.Pages["limit_playermodel"].RankList:GetSelected()[1].UniqueRankID) then return end
		local data = net.ReadTable()
		local model_list = Vermilion.Menu.Pages["limit_playermodel"].RankPermissions
		local is_blacklist = Vermilion.Menu.Pages["limit_playermodel"].IsBlacklist
		local models = Vermilion.Menu.Pages["limit_playermodel"].Models
		if(IsValid(model_list)) then
			model_list:Clear()
			for i,k in pairs(data) do
				for i1,k1 in pairs(models) do
					if(k1.ClassName == k) then
						model_list:AddLine(k1.Name).ClassName = k
					end
				end
			end
		end
		is_blacklist:SetDisabled(true)
		is_blacklist:SetValue(net.ReadBoolean())
		is_blacklist:SetDisabled(false)
	end)

	Vermilion.Menu:AddCategory("limits", 5)

	Vermilion.Menu:AddPage({
			ID = "limit_playermodel",
			Name = "Player Model",
			Order = 3,
			Category = "limits",
			Size = { 900, 560 },
			Conditional = function(vplayer)
				return Vermilion:HasPermission("manage_playermodels")
			end,
			Builder = function(panel, paneldata)
				local addModel = nil
				local delModel = nil
				local rankList = nil
				local allModels = nil
				local isBlacklist = nil
				local rankPermissions = nil

				paneldata.PreviewPanel = VToolkit:CreatePreviewPanel("model", panel)


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
					addModel:SetDisabled(not (self:GetSelected()[1] != nil and allModels:GetSelected()[1] != nil))
					delModel:SetDisabled(not (self:GetSelected()[1] != nil and rankPermissions:GetSelected()[1] != nil))
					MODULE:NetStart("VGetModelList")
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

				local rankPermissionsHeader = VToolkit:CreateHeaderLabel(rankPermissions, "Rank Models")
				rankPermissionsHeader:SetParent(panel)

				function rankPermissions:OnRowSelected(index, line)
					delModel:SetDisabled(not (self:GetSelected()[1] != nil and rankList:GetSelected()[1] != nil))
				end

				VToolkit:CreateSearchBox(rankPermissions)


				allModels = VToolkit:CreateList({
					cols = {
						"Name"
					}
				})
				allModels:SetPos(panel:GetWide() - 250, 30)
				allModels:SetSize(240, panel:GetTall() - 40)
				allModels:SetParent(panel)
				paneldata.AllModels = allModels

				local allModelsHeader = VToolkit:CreateHeaderLabel(allModels, "All Models")
				allModelsHeader:SetParent(panel)

				function allModels:OnRowSelected(index, line)
					addModel:SetDisabled(not (self:GetSelected()[1] != nil and rankList:GetSelected()[1] != nil))
				end

				VToolkit:CreateSearchBox(allModels)


				addModel = VToolkit:CreateButton("Add Model", function()
					for i,k in pairs(allModels:GetSelected()) do
						local has = false
						for i1,k1 in pairs(rankPermissions:GetLines()) do
							if(k.ClassName == k1.ClassName) then has = true break end
						end
						if(has) then continue end
						rankPermissions:AddLine(k:GetValue(1)).ClassName = k.ClassName

						MODULE:NetStart("VAddModel")
						net.WriteString(rankList:GetSelected()[1].UniqueRankID)
						net.WriteString(k.ClassName)
						net.SendToServer()
					end
				end)
				addModel:SetPos(select(1, rankPermissions:GetPos()) + rankPermissions:GetWide() + 10, 100)
				addModel:SetWide(panel:GetWide() - 20 - select(1, allModels:GetWide()) - select(1, addModel:GetPos()))
				addModel:SetParent(panel)
				addModel:SetDisabled(true)

				delModel = VToolkit:CreateButton("Remove Model", function()
					for i,k in pairs(rankPermissions:GetSelected()) do
						MODULE:NetStart("VDelModel")
						net.WriteString(rankList:GetSelected()[1].UniqueRankID)
						net.WriteString(k.ClassName)
						net.SendToServer()

						rankPermissions:RemoveLine(k:GetID())
					end
				end)
				delModel:SetPos(select(1, rankPermissions:GetPos()) + rankPermissions:GetWide() + 10, 130)
				delModel:SetWide(panel:GetWide() - 20 - select(1, allModels:GetWide()) - select(1, delModel:GetPos()))
				delModel:SetParent(panel)
				delModel:SetDisabled(true)

				isBlacklist = VToolkit:CreateCheckBox("Blacklist")
				isBlacklist:SetPos(select(1, rankPermissions:GetPos()) + rankPermissions:GetWide() + 10, 400)
				isBlacklist:SetDisabled(true)
				isBlacklist:SetParent(panel)
				isBlacklist:SizeToContents()

				function isBlacklist:OnChange(val)
					if(not self:GetDisabled()) then
						MODULE:NetStart("VModelBlacklistState")
						net.WriteString(rankList:GetSelected()[1].UniqueRankID)
						net.WriteBoolean(val)
						net.SendToServer()
					end
				end

				paneldata.AddModel = addModel
				paneldata.DelModel = delModel
				paneldata.IsBlacklist = isBlacklist

			end,
			OnOpen = function(panel, paneldata)
				if(paneldata.Models == nil) then
					paneldata.Models = {}
					for i,k in pairs(player_manager.AllValidModels()) do
						table.insert(paneldata.Models, { Name = i, ClassName = k })
					end
				end
				if(table.Count(paneldata.AllModels:GetLines()) == 0) then
					for i,k in pairs(paneldata.Models) do
						local ln = paneldata.AllModels:AddLine(k.Name)
						ln.ClassName = k.ClassName

						ln.ModelPath = k.ClassName

						ln.OldCursorMoved = ln.OnCursorMoved
						ln.OldCursorEntered = ln.OnCursorEntered
						ln.OldCursorExited = ln.OnCursorExited

						function ln:OnCursorEntered()
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
				paneldata.AddModel:SetDisabled(true)
				paneldata.DelModel:SetDisabled(true)
				paneldata.IsBlacklist:SetDisabled(true)
				paneldata.IsBlacklist:SetValue(false)
			end
		})

end
