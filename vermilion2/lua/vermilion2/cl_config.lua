--[[
 Copyright 2015 Ned Hyett

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

Vermilion.Data = {}
Vermilion.Data.Rank = {} -- active rank (for localplayer)
Vermilion.Data.RankOverview = {} -- basic data for all ranks
Vermilion.Data.Permissions = {}
Vermilion.Data.Module = {}

net.Receive("Vermilion_SendRank", function()
	Vermilion.Data.Rank = net.ReadTable()
	hook.Run(Vermilion.Event.CLIENT_GOT_RANKS)
end)

net.Receive("VBroadcastRankData", function()
	Vermilion.Data.RankOverview = net.ReadTable()
	hook.Run(Vermilion.Event.CLIENT_GOT_RANK_OVERVIEWS)
end)

net.Receive("VBroadcastPermissions", function()
	Vermilion.Data.Permissions = net.ReadTable()
end)

function Vermilion:LookupPermissionOwner(permission)
	for i,k in pairs(self.Data.Permissions) do
		if(k.Permission == permission) then return k.Owner end
	end
end

function Vermilion:GetRankByID(id)
	for i,k in pairs(self.Data.RankOverview) do
		if(k.UniqueID == id) then return k end
	end
end

function Vermilion:GetRankColour(id)
	for i,k in pairs(self.Data.RankOverview) do
		if(k.UniqueID == id) then
			if(not IsColor(k.Colour)) then
				k.Colour = Color(k.Colour.r, k.Colour.g, k.Colour.b)
			end
			return k.Colour
		end
	end
end

function Vermilion:GetRankIcon(id)
	for i,k in pairs(self.Data.RankOverview) do
		if(k.UniqueID == id) then
			return k.Icon
		end
	end
end

function Vermilion:HasPermission(permission)
	return table.HasValue(Vermilion.Data.Rank.Permissions, permission) or table.HasValue(Vermilion.Data.Rank.Permissions, "*")
end

Vermilion.RankTables = {}
Vermilion:AddHook(Vermilion.Event.CLIENT_GOT_RANK_OVERVIEWS, "UpdateRankTables", true, function()
	for i,k in pairs(Vermilion.RankTables) do
		Vermilion:PopulateRankTable(k.Table, k.Detailed, k.Protected)
	end
end)


function Vermilion:PopulateRankTable(ranklist, detailed, protected, customiser)
	if(ranklist == nil) then return end
	detailed = detailed or false
	protected = protected or false
	local has = false
	for i,k in pairs(self.RankTables) do
		if(k.Table == ranklist) then
			has = true
			break
		end
	end
	if(not has) then
		table.insert(self.RankTables, { Table = ranklist, Detailed = detailed, Protected = protected })
	end
	ranklist:Clear()
	if(detailed) then
		for i,k in pairs(self.Data.RankOverview) do
			if(not protected and k.Protected) then continue end
			local inherits = Vermilion:GetRankByID(k.InheritsFrom)
			if(inherits != nil) then inherits = inherits.Name end
			if(k.IsDefault) then
				local ln = ranklist:AddLine(k.Name, inherits or Vermilion:TranslateStr("none"), i, Vermilion:TranslateStr("yes"))
				ln.Protected = k.Protected
				ln.UniqueRankID = k.UniqueID
				for i1,k1 in pairs(ln.Columns) do
					k1:SetContentAlignment(5)
				end
				local img = vgui.Create("DImage")
				img:SetImage("icon16/" .. k.Icon .. ".png")
				img:SetSize(16, 16)
				ln:Add(img)
				if(isfunction(customiser)) then customiser(ln, k) end
			else
				local ln = ranklist:AddLine(k.Name, inherits or Vermilion:TranslateStr("none"), i, Vermilion:TranslateStr("no"))
				ln.Protected = k.Protected
				ln.UniqueRankID = k.UniqueID
				for i1,k1 in pairs(ln.Columns) do
					k1:SetContentAlignment(5)
				end
				local img = vgui.Create("DImage")
				img:SetImage("icon16/" .. k.Icon .. ".png")
				img:SetSize(16, 16)
				ln:Add(img)
				if(isfunction(customiser)) then customiser(ln, k) end
			end
		end
	else
		for i,k in pairs(self.Data.RankOverview) do
			if(not protected and k.Protected) then continue end
			local ln = ranklist:AddLine(k.Name)
			ln.Protected = k.Protected
			ln.UniqueRankID = k.UniqueID
			if(isfunction(customiser)) then customiser(ln, k) end
		end
	end
end

net.Receive("VUpdatePlayerLists", function()
	local tab = net.ReadTable()
	hook.Run("Vermilion_PlayersList", tab)
end)

net.Receive("VModuleConfig", function()
	Vermilion.Data.Module[net.ReadString()] = net.ReadTable()
end)

function Vermilion:GetModuleData(mod, name, def)
	if(self.Data.Module[mod] == nil) then self.Data.Module[mod] = {} end
	if(self.Data.Module[mod][name] == nil) then return def end
	return self.Data.Module[mod][name]
end

function Vermilion:SetModuleData(mod, name, val)
	if(self.Data.Module[mod] == nil) then self.Data.Module[mod] = {} end
	self.Data.Module[mod][name] = val
end

Vermilion:AddHook("ChatText", "StopDefaultChat", false, function(index, name, text, typ)
	if(typ == "joinleave") then
		return true
	end
end)
