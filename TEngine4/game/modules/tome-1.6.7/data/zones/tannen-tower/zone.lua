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

return {
	name = "Tannen's Tower",
	level_range = {35, 45},
	level_scheme = "player",
	max_level = 4, reverse_level_display=true,
	decay = {300, 800},
	actor_adjust_level = function(zone, level, e) return zone.base_level + e:getRankLevelAdjust() + level.level-1 + rng.range(-1,2) end,
	width = 25, height = 25,
--	all_remembered = true,
--	all_lited = true,
	no_worldport = true,
	persistent = "zone",
	no_level_connectivity = true,
	ambient_music = {"Remembrance.ogg","weather/dungeon_base.ogg"},
	min_material_level = 4,
	max_material_level = 5,
	generator =  {
		map = {
			class = "engine.generator.map.Static",
		},
		actor = {
			class = "mod.class.generator.actor.Random",
			nb_npc = {0, 0},
		},
		object = {
			class = "engine.generator.object.Random",
			nb_object = {2, 3},
		},
		trap = {
			class = "engine.generator.trap.Random",
			nb_trap = {0, 0},
		},
	},
	on_enter = function(lev, old_lev, newzone)
		if newzone and not game.level.shown_warning then
			require("engine.ui.Dialog"):simplePopup("Tannen's Tower", "The portal brought you to what seems to be a cell in the basement of the tower. You must escape!")
			game.level.shown_warning = true
		end
		if lev == 4 then
			core.fov.set_actor_vision_size(0)
			if not game.level.data.seen_tannen then
				game.level.data.seen_tannen = true
				require("engine.ui.Dialog"):simpleLongPopup("Tannen's Tower", [[As you climb up the steps, you see Tannen standing with his drolem, reading a scrap of parchment.  As he reads, his eyes grow wider, and he starts sweating and pacing back and forth.  When he reaches to stuff it in his pocket, he sees you and jumps back like a startled cat.  "No!  Not now!  You have no idea what's at stake!"  He retrieves a fistful of brightly-colored flasks from his robes, and his drolem's eyes glow as it springs to life, metal screeching in an impressive imitation of a roar.]], 500)
			end
		end
	end,
	on_leave = function()
		if game.level.level == 4 then
			core.fov.set_actor_vision_size(1)
		end
	end,
	on_loaded = function() -- When the game is loaded from a savefile
		game:onTickEnd(function() if game.level.level == 4 then
			core.fov.set_actor_vision_size(0)
		end end)
	end,
	levels =
	{
		[4] = { generator = { map = { map = "zones/tannen-tower-1" }, }, all_remembered = true, all_lited = true, },
		[3] = { generator = { map = { map = "zones/tannen-tower-2" }, actor = { nb_npc = {22, 22}, }, trap = { nb_trap = {6, 6} }, }, },
		[2] = { generator = { map = { map = "zones/tannen-tower-3" }, actor = { nb_npc = {22, 22}, filters={{special_rarity="aquatic_rarity"}} }, trap = { nb_trap = {6, 6} }, }, },
		[1] = { generator = { map = { map = "zones/tannen-tower-4" }, }, },
	},
	post_process = function(level)
		game.state:makeAmbientSounds(level, {
			dungeon2={ chance=250, volume_mod=1, pitch=1, random_pos={rad=10}, files={"ambient/dungeon/dungeon1","ambient/dungeon/dungeon2","ambient/dungeon/dungeon3","ambient/dungeon/dungeon4","ambient/dungeon/dungeon5"}},
		})
	end,
}
