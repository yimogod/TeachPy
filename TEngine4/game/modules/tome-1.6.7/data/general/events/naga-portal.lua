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

-- Find a random spot
local x, y = game.state:findEventGrid(level)
if not x then return false end

local id = "naga-invasion-"..game.turn

print("[EVENT] Placing event", id, "at", x, y)

local changer = function(id)
	local npcs = mod.class.NPC:loadList{"/data/general/npcs/naga.lua"}
	local objects = mod.class.Object:loadList("/data/general/objects/objects.lua")
	local terrains = mod.class.Grid:loadList{"/data/general/grids/basic.lua", "/data/general/grids/water.lua"}
	terrains.PORTAL_BACK = mod.class.Grid.new{
		type = "floor", subtype = "underwater",
		display = "&", color = colors.BLUE,
		name = "coral invasion portal",
		name = "portal back to "..game.zone.name,
		image = "terrain/underwater/subsea_floor_02.png",
		add_displays = {mod.class.Grid.new{z=18, image="terrain/naga_portal.png", display_h=2, display_y=-1, embed_particles = {
			{name="naga_portal_smoke", rad=2, args={smoke="particles_images/smoke_whispery_bright"}},
			{name="naga_portal_smoke", rad=2, args={smoke="particles_images/smoke_heavy_bright"}},
			{name="naga_portal_smoke", rad=2, args={smoke="particles_images/smoke_dark"}},
		}}},
		change_level = 1,
		change_zone = game.zone.short_name,
		change_level_shift_back = true,
		change_zone_auto_stairs = true,
	}
	local zone = mod.class.Zone.new(id, {
		name = "water cavern",
		level_range = game.zone.actor_adjust_level and {math.floor(game.zone:actor_adjust_level(game.level, game.player)*1.05),
			math.ceil(game.zone:actor_adjust_level(game.level, game.player)*1.15)} or {game.zone.base_level, game.zone.base_level}, -- 5-15% higher levels
		__applied_difficulty = true, -- Difficulty already applied to parent zone
		level_scheme = "player",
		max_level = 1,
		actor_adjust_level = function(zone, level, e) return zone.base_level + e:getRankLevelAdjust() + level.level-1 + rng.range(-1,2) end,
		width = 30, height = 30,
		ambient_music = "Dark Secrets.ogg",
		reload_lists = false,
		no_worldport = game.zone.no_worldport,
		color_shown = {0.5, 1, 0.8, 1},
		color_obscure = {0.5*0.6, 1*0.6, 0.8*0.6, 0.6},
		persistent = "zone",
		min_material_level = util.getval(game.zone.min_material_level),
		max_material_level = util.getval(game.zone.max_material_level),
		effects = {"EFF_ZONE_AURA_UNDERWATER"},
		generator =  {
			map = {
				class = "engine.generator.map.Cavern",
				zoom = 12,
				min_floor = 250,
				floor = {"WATER_FLOOR","WATER_FLOOR","WATER_FLOOR","WATER_FLOOR","WATER_FLOOR","WATER_FLOOR","WATER_FLOOR","WATER_FLOOR","WATER_FLOOR","WATER_FLOOR","WATER_FLOOR_BUBBLE"},
				wall = "WATER_WALL",
				up = "WATER_FLOOR",
				down = "PORTAL_BACK",
				door = "WATER_FLOOR",
				force_last_stair = true,
			},
			actor = {
				class = "mod.class.generator.actor.Random",
				nb_npc = {12, 12},
				guardian = {random_elite={life_rating=function(v) return v * 1.5 + 4 end, name_scheme="#rng# the Tidebender", on_die=function(self) world:gainAchievement("EVENT_NAGA", game:getPlayer(true)) end,
				nb_rares=(rng.percent(resolvers.current_level-50) and 4 or 3),
				nb_classes=(rng.percent(resolvers.current_level-50) and 2 or 1)
				}},
			},
			object = {
				class = "engine.generator.object.Random",
				filters = {{type="gem"}},
				nb_object = {6, 9},
			},
			trap = {
				class = "engine.generator.trap.Random",
				nb_trap = {6, 9},
			},
		},
		post_process = function(level) for uid, e in pairs(level.entities) do e.faction = e.hard_faction or "vargh-republic" end end,
		npc_list = npcs,
		grid_list = terrains,
		object_list = objects,
		trap_list = mod.class.Trap:loadList("/data/general/traps/water.lua"),
	})
	return zone
end

local g = game.level.map(x, y, engine.Map.TERRAIN):cloneFull()
g.name = "naga invasion coral portal"
g.always_remember = true
g.display='&' g.color_r=0 g.color_g=0 g.color_b=255 g.notice = true
g.special_minimap = colors.VIOLET
g.change_level=1 g.change_zone=id g.glow=true
g:removeAllMOs()
if engine.Map.tiles.nicer_tiles then
	g.add_displays = g.add_displays or {}
	g.add_displays[#g.add_displays+1] = mod.class.Grid.new{z=18, image="terrain/naga_portal.png", display_h=2, display_y=-1, embed_particles = {
		{name="naga_portal_smoke", rad=2, args={smoke="particles_images/smoke_whispery_bright"}},
		{name="naga_portal_smoke", rad=2, args={smoke="particles_images/smoke_heavy_bright"}},
		{name="naga_portal_smoke", rad=2, args={smoke="particles_images/smoke_dark"}},
	}}
end
g:altered()
g.grow = nil g.dig = nil
g:initGlow()
g.special = true
g.real_change = changer
g.break_portal = function(self)
	game.log("#VIOLET#The portal is broken!")
	self.broken = true
	self.name = "broken naga invasion coral portal"
	self.change_level = nil
	self.autoexplore_ignore = true
	self.show_tooltip = false
end
g.change_level_check = function(self)
	self:break_portal()
	game:changeLevel(1, self.real_change(self.change_zone), {temporary_zone_shift=true, direct_switch=true})
	return true
end
g.on_move = function(self, x, y, who, act, couldpass)
	if not who or not who.player then return false end
	if self.broken then
		game.log("#VIOLET#The portal is already broken!")
		return false
	end
	require("engine.ui.Dialog"):yesnoPopup("Coral Portal", "Do you wish to enter the portal, destroy it, or ignore it (press escape)?", function(ret)
		if ret == "Quit" then
			game.log("#VIOLET#Ignoring the portal...")
			return
		end
		if not ret then
			self:change_level_check()
		else self:break_portal()
		end

	end, "Destroy", "Enter", false, "Quit")
	
	return false
end

game.zone:addEntity(game.level, g, "terrain", x, y)

local respawn = function(self)
	local portal = game.level.map(self.naga_portal_x, self.naga_portal_y, engine.Map.TERRAIN)
	if not portal or portal.broken then return end

	local npcs = mod.class.NPC:loadList{"/data/general/npcs/naga.lua"}
	local m = game.zone:makeEntity(game.level, "actor", {base_list=npcs}, nil, true)
	if not m then return end

	local adjacent = util.adjacentCoords(self.naga_portal_x, self.naga_portal_y)
	adjacent[5] = {self.naga_portal_x, self.naga_portal_y}

	repeat
		local grid = rng.tableRemove(adjacent)
		if m:canMove(grid[1], grid[2]) then
			m.naga_portal_x = self.naga_portal_x
			m.naga_portal_y = self.naga_portal_y
			m.naga_respawn = self.naga_respawn
			m.exp_worth = 0
			m.no_drops = true
			m.ingredient_on_death = nil
			m.faction = "vargh-republic"
			m.on_die = function(self) self:naga_respawn() end
			game.zone:addEntity(game.level, m, "actor", grid[1], grid[2])
			game.logSeen(m, "#VIOLET#A naga steps out of the %s!", portal.name)
			break
		end
	until #adjacent <= 0
end

-- Spawn two nagas that will keep on being replenished
local base = {naga_portal_x=x, naga_portal_y=y, naga_respawn=respawn}
respawn(base)
respawn(base)

return x, y
