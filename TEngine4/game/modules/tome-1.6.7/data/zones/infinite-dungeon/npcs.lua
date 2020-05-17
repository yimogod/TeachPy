-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2019 Nicolas Casalini
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

ignoreLoaded(true)

-- Wont work here, so fake having loaded them
loaded["/data/general/npcs/shade.lua"] = true

-- Load all others
load("/data/general/npcs/all.lua")
load("/data/general/npcs/bone-giant.lua")
load("/data/general/npcs/faeros.lua")
load("/data/general/npcs/gwelgoroth.lua")
load("/data/general/npcs/shivgoroth.lua")
load("/data/general/npcs/undead-rat.lua")
load("/data/general/npcs/mummy.lua")
load("/data/general/npcs/ritch.lua")

-- Load the bosses of all other zones
local function loadOuter(file)
--[[
	local list = loadList(file, function(e)
		if e.allow_infinite_dungeon and not e.rarity then
			e.rarity = 25
			e.on_die = nil
			e.can_talk = nil
			e.on_acquire_target = nil
		end
--	end, {ignore_loaded=true, import_source=loading_list}, loaded)
	end)
	for i, e in ipairs(list) do
		if e.allow_infinite_dungeon then
			importEntity(e)
			print("========================= Importing boss", e.name)
		end
	end
]]
	load(file, function(e) 
		if not e.allow_infinite_dungeon then
			e.rarity = nil
		else
			if not e.rarity then
				e.rarity = 25
				e.on_die = nil
				e.can_talk = nil
				e.on_acquire_target = nil
			end
		end
	end)
end

for i, zone in ipairs(fs.list("/data/zones/")) do
	local file = "/data/zones/"..zone.."/npcs.lua"
--	if fs.exists(file) and not zone:find("infinite%-dungeon") then loadOuter(file) end
	if fs.exists(file) and not zone:find("infinite%-dungeon") and not zone:find("noxious%-caldera") then loadOuter(file) end --Bug fix
end
