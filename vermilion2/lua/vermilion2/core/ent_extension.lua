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

local eMeta = FindMetaTable("Entity")

function eMeta:ShouldBeInvisible()
	if(self:GetRenderMode() == RENDERMODE_NONE) then return true end


	return false
end

function eMeta:VSetOwner(vplayer)
	if(vplayer == nil or not IsValid(vplayer)) then
		vplayer = {
			SteamID = function() return nil end
		}
	end
	self.Vermilion_Owner = vplayer:SteamID()
	self:SetGlobalValue("Vermilion_Owner", vplayer:SteamID())
	duplicator.StoreEntityModifier(self, "Vermilion_Owner", { Owner = vplayer:SteamID() })
end
