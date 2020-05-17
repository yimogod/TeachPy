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

load("/data/general/objects/objects.lua")

local Stats = require "engine.interface.ActorStats"

newEntity{ base = "BASE_LEATHER_BOOT",
	power_source = {arcane=true},
	define_as = "BOOTS_OF_PHASING",
	unique = true,
	name = "Shifting Boots", image = "object/artifact/shifting_boots.png",
	unided_name = "pair of shifting boots",
	desc = [[Those leather boots can make anybody as annoying as their former possessor, Draebor.]],
	color = colors.BLUE,
	rarity = false,
	cost = 200,
	material_level = 5,
	wielder = {
		combat_armor = 1,
		combat_def = 7,
		fatigue = 2,
		talents_types_mastery = { ["spell/temporal"] = 0.1 },
		inc_stats = { [Stats.STAT_CUN] = 8, [Stats.STAT_DEX] = 4, },
	},

	max_power = 40, power_regen = 1,
	use_power = {
		name = function(self, who) return ("blink to a nearby random location within range %d (based on Magic)"):format(self.use_power.range(self, who)) end,
		power = 22,
		tactical = { ESCAPE = 2},
		range = function(self, who) return 10 + who:getMag(5) end,
		use = function(self, who)
			game.logSeen(who, "%s taps %s %s together!", who.name:capitalize(), who:his_her(), self:getName{no_count=true, do_color = true, no_add_name = true})
			game.level.map:particleEmitter(who.x, who.y, 1, "teleport")
			who:teleportRandom(who.x, who.y, self.use_power.range(self, who))
			game.level.map:particleEmitter(who.x, who.y, 1, "teleport")
			return {id=true, used=true}
	end}
}
