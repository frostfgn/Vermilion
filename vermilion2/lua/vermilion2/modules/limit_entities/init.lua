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
MODULE.Name = "Entity Limits"
MODULE.ID = "limit_entities"
MODULE.Description = "Prevent players from spawning certain entities."
MODULE.Author = "Ned"
MODULE.Permissions = {
	"manage_entity_limits"
}
MODULE.NetworkStrings = {
	"VGetEntityLimits",
	"VBlockEntity",
	"VUnblockEntity"
}

function MODULE:InitServer()

	if(not MODULE:GetData("uidUpdate", false)) then
		local ndata = {}
		for i,k in pairs(MODULE:GetAllData()) do
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

	self:AddHook("PlayerSpawnSENT", function(vplayer, class)
		if(table.HasValue(MODULE:GetData(Vermilion:GetUser(vplayer):GetRankUID(), {}, true), class)) then
			Vermilion:AddNotification(vplayer, "You cannot spawn this entity!", nil, NOTIFY_ERROR)
			return false
		end
	end)

	self:AddHook("Vermilion_IsEntityDuplicatable", function(vplayer, class)
		if(not IsValid(vplayer)) then return end
		if(table.HasValue(MODULE:GetData(Vermilion:GetUser(vplayer):GetRankUID(), {}, true), class)) then
			return false
		end
	end)

	self:NetHook("VGetEntityLimits", function(vplayer)
		local rnk = net.ReadString()
		local data = MODULE:GetData(rnk, {}, true)
		MODULE:NetStart("VGetEntityLimits")
		net.WriteString(rnk)
		if(data != nil) then
			net.WriteTable(data)
		else
			net.WriteTable({})
		end
		net.Send(vplayer)
	end)

	self:NetHook("VBlockEntity", { "manage_entity_limits" }, function(vplayer)
		if(Vermilion:HasPermission(vplayer, "manage_entity_limits")) then
			local rnk = net.ReadString()
			local weapon = net.ReadString()
			if(not table.HasValue(MODULE:GetData(rnk, {}, true), weapon)) then
				table.insert(MODULE:GetData(rnk, {}, true), weapon)
			end
		end
	end)

	self:NetHook("VUnblockEntity", { "manage_entity_limits" }, function(vplayer)
		local rnk = net.ReadString()
		local weapon = net.ReadString()
		table.RemoveByValue(MODULE:GetData(rnk, {}, true), weapon)
	end)

end

function MODULE:InitClient()

	self:NetHook("VGetEntityLimits", function()
		if(not IsValid(Vermilion.Menu.Pages["limit_entities"].RankList)) then return end
		if(net.ReadString() != Vermilion.Menu.Pages["limit_entities"].RankList:GetSelected()[1].UniqueRankID) then return end
		local data = net.ReadTable()
		local blocklist = Vermilion.Menu.Pages["limit_entities"].RankBlockList
		local ents = Vermilion.Menu.Pages["limit_entities"].Entities
		if(IsValid(blocklist)) then
			blocklist:Clear()
			for i,k in pairs(data) do
				for i1,k1 in pairs(ents) do
					if(k1.ClassName == k) then
						blocklist:AddLine(k1.Name).ClassName = k
					end
				end
			end
			blocklist:OnRowSelected()
		end
	end)

	Vermilion.Menu:AddCategory("limits", 5)

	self:AddMenuPage({
			ID = "limit_entities",
			Name = "Entities",
			Order = 4,
			Category = "limits",
			Size = { 900, 560 },
			Conditional = function(vplayer)
				return Vermilion:HasPermission("manage_entity_limits")
			end,
			Builder = function(panel, paneldata)
				local blockEntity = nil
				local unblockEntity = nil
				local rankList = nil
				local allEntites = nil
				local rankBlockList = nil


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
					blockEntity:SetDisabled(not (self:GetSelected()[1] != nil and allEntites:GetSelected()[1] != nil))
					unblockEntity:SetDisabled(not (self:GetSelected()[1] != nil and rankBlockList:GetSelected()[1] != nil))
					MODULE:NetStart("VGetEntityLimits")
					net.WriteString(rankList:GetSelected()[1].UniqueRankID)
					net.SendToServer()
				end

				rankBlockList = VToolkit:CreateList({
					cols = {
						"Name"
					}
				})
				rankBlockList:SetPos(220, 30)
				rankBlockList:SetSize(240, panel:GetTall() - 40)
				rankBlockList:SetParent(panel)
				paneldata.RankBlockList = rankBlockList

				local rankBlockListHeader = VToolkit:CreateHeaderLabel(rankBlockList, "Blocked Entities")
				rankBlockListHeader:SetParent(panel)

				function rankBlockList:OnRowSelected(index, line)
					unblockEntity:SetDisabled(not (self:GetSelected()[1] != nil and rankList:GetSelected()[1] != nil))
				end

				VToolkit:CreateSearchBox(rankBlockList)


				allEntites = VToolkit:CreateList({
					cols = {
						"Name"
					}
				})
				allEntites:SetPos(panel:GetWide() - 250, 30)
				allEntites:SetSize(240, panel:GetTall() - 40)
				allEntites:SetParent(panel)
				paneldata.AllEntities = allEntites

				local allEntitesHeader = VToolkit:CreateHeaderLabel(allEntites, "All Entites")
				allEntitesHeader:SetParent(panel)

				function allEntites:OnRowSelected(index, line)
					blockEntity:SetDisabled(not (self:GetSelected()[1] != nil and rankList:GetSelected()[1] != nil))
				end

				VToolkit:CreateSearchBox(allEntites)


				blockEntity = VToolkit:CreateButton("Block Entity", function()
					for i,k in pairs(allEntites:GetSelected()) do
						local has = false
						for i1,k1 in pairs(rankBlockList:GetLines()) do
							if(k.ClassName == k1.ClassName) then has = true break end
						end
						if(has) then continue end
						rankBlockList:AddLine(k:GetValue(1)).ClassName = k.ClassName

						MODULE:NetStart("VBlockEntity")
						net.WriteString(rankList:GetSelected()[1].UniqueRankID)
						net.WriteString(k.ClassName)
						net.SendToServer()
					end
				end)
				blockEntity:SetPos(select(1, rankBlockList:GetPos()) + rankBlockList:GetWide() + 10, 100)
				blockEntity:SetWide(panel:GetWide() - 20 - select(1, allEntites:GetWide()) - select(1, blockEntity:GetPos()))
				blockEntity:SetParent(panel)
				blockEntity:SetDisabled(true)

				unblockEntity = VToolkit:CreateButton("Unblock Entity", function()
					for i,k in pairs(rankBlockList:GetSelected()) do
						MODULE:NetStart("VUnblockEntity")
						net.WriteString(rankList:GetSelected()[1].UniqueRankID)
						net.WriteString(k.ClassName)
						net.SendToServer()

						rankBlockList:RemoveLine(k:GetID())
						rankBlockList:OnRowSelected()
					end
				end)
				unblockEntity:SetPos(select(1, rankBlockList:GetPos()) + rankBlockList:GetWide() + 10, 130)
				unblockEntity:SetWide(panel:GetWide() - 20 - select(1, allEntites:GetWide()) - select(1, unblockEntity:GetPos()))
				unblockEntity:SetParent(panel)
				unblockEntity:SetDisabled(true)

				paneldata.BlockEntity = blockEntity
				paneldata.UnblockEntity = unblockEntity


			end,
			OnOpen = function(panel, paneldata)
				if(paneldata.Entities == nil) then
					paneldata.Entities = {}
					for i,k in pairs(list.Get("SpawnableEntities")) do
						local printname = k.PrintName
						if(printname == nil or printname == "") then
							printname = k.ClassName
						end
						table.insert(paneldata.Entities, { Name = printname, ClassName = k.ClassName })
					end
				end
				if(table.Count(paneldata.AllEntities:GetLines()) == 0) then
					for i,k in pairs(paneldata.Entities) do
						local ln = paneldata.AllEntities:AddLine(k.Name)
						ln.ClassName = k.ClassName
					end
				end
				Vermilion:PopulateRankTable(paneldata.RankList, false, true)
				paneldata.RankBlockList:Clear()
				paneldata.BlockEntity:SetDisabled(true)
				paneldata.UnblockEntity:SetDisabled(true)
			end
		})

end
