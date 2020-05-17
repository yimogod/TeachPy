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

local Talents = require("engine.interface.ActorTalents")
local Stats = require "engine.interface.ActorStats"
local DamageType = require "engine.DamageType"

load("/data/general/objects/egos/armor.lua")

newEntity{
	power_source = {nature=true},
	name = "troll-hide ", prefix=true, instant_resolve=true,
	keywords = {troll=true},
	level_range = {10, 50},
	greater_ego = 1,
	rarity = 20,
	cost = 14,
	wielder = {
		healing_factor = resolvers.mbonus_material(10, 10, function(e, v) v=v/100 return 0, v end), -- copied from robe.lua
		life_regen = resolvers.mbonus_material(120, 30, function(e, v) v=v/10 return 0, v end),
		max_life=resolvers.mbonus_material(40, 30),
	},
}

newEntity{
	power_source = {technique=true},
	name = "nimble ", prefix=true, instant_resolve=true,
	keywords = {nimble=true},
	level_range = {25, 50},
	greater_ego = 1,
	rarity = 22,
	cost = 35,
	wielder = {
		combat_def = resolvers.mbonus_material(14, 2),
		movement_speed = 0.2,
		inc_stats = { [Stats.STAT_DEX] = resolvers.mbonus_material(8, 2), },
	},
}

newEntity{
	power_source = {technique=true},
	name = "marauder's ", prefix=true, instant_resolve=true,
	keywords = {marauder=true},
	level_range = {20, 50},
	greater_ego = 1,
	rarity = 20,
	cost = 40,
	wielder = {
		inc_stats = {
			[Stats.STAT_STR] = resolvers.mbonus_material(7, 3),
			[Stats.STAT_DEX] = resolvers.mbonus_material(7, 3),
		},
		combat_def = resolvers.mbonus_material(8, 2),
		combat_physresist = resolvers.mbonus_material(15, 5),
	},
}

newEntity{
	power_source = {technique=true},
	name = "duelist's ", prefix=true, instant_resolve=true,
	keywords = {duelist=true},
	level_range = {20, 50},
	greater_ego = 1,
	rarity = 20,
	cost = 40,
	wielder = {
		inc_stats = {
			[Stats.STAT_CUN] = resolvers.mbonus_material(7, 3),
			[Stats.STAT_DEX] = resolvers.mbonus_material(7, 3),
		},
		combat_def = resolvers.mbonus_material(8, 2),
		combat_armor = resolvers.mbonus_material(8, 2),
	},
}

-- From Doctornull
newEntity{
   power_source = {nature=true},
   name = "volcanic ", prefix=true, instant_resolve=true,
   keywords = {volcanic=true},
   level_range = {20, 50},
   greater_ego = 1,
   rarity = 20,
   cost = 35,
   wielder = {
	  combat_armor = resolvers.mbonus_material(10, 5),
	  resists={
	 [DamageType.FIRE] = resolvers.mbonus_material(20, 10),
	 [DamageType.PHYSICAL] = resolvers.mbonus_material(20, 10),
	  },
	  melee_project={
	 [DamageType.FIRE] = resolvers.mbonus_material(5, 5),
	  },
	  ranged_project={
	 [DamageType.FIRE] = resolvers.mbonus_material(5, 5),
	  },
   },
}

-- Doctornull
newEntity{
   power_source = {arcane=true},
   name = " of the void", suffix=true, instant_resolve=true,
   keywords = {void=true},
   level_range = {30, 50},
   greater_ego = 1,
   rarity = 30,
   cost = 65,
   wielder = {
	  resist_all_on_teleport = resolvers.mbonus_material(20, 10),
	  defense_on_teleport = resolvers.mbonus_material(20, 10),
	  effect_reduction_on_teleport = resolvers.mbonus_material(20, 10),

	  resists={
		 [DamageType.TEMPORAL] = resolvers.mbonus_material(20, 10),
		 [DamageType.DARKNESS] = resolvers.mbonus_material(20, 10),
	  },

	  melee_project={
		[DamageType.DARKNESS] = resolvers.mbonus_material(5, 5),
	  },
	  ranged_project={
		[DamageType.DARKNESS] = resolvers.mbonus_material(5, 5),
	  },
   },

   charm_power = resolvers.mbonus_material(80, 20),
   charm_power_def = {add=5, max=10, floor=true},
   resolvers.charm("blink to a nearby random location (rad %d)", 25, function(self, who)
		game.logSeen(who, "%s uses %s %s!", who.name:capitalize(), who:his_her(), self:getName{no_add_name=true, do_color=true})
		game.level.map:particleEmitter(who.x, who.y, 1, "teleport")
		who:teleportRandom(who.x, who.y, self:getCharmPower(who))
		game.level.map:particleEmitter(who.x, who.y, 1, "teleport")
		return {id=true, used=true}
   end,
   "T_GLOBAL_CD",
   {tactical = {ESCAPE = 2}}),
}

newEntity{
	power_source = {technique=true},
	name = " of Toknor", suffix=true, instant_resolve=true,
	keywords = {toknor=true},
	level_range = {20, 50},
	greater_ego = 1,
	rarity = 16,
	cost = 30,
	wielder = {
		combat_dam = resolvers.mbonus_material(5, 5),
		combat_physcrit = resolvers.mbonus_material(3, 3),
		combat_critical_power = resolvers.mbonus_material(10, 10),
	},
}

newEntity{
	power_source = {technique=true},
	name = " of the wind", suffix=true, instant_resolve=true,
	keywords = {wind=true},
	level_range = {30, 50},
	greater_ego = 1,
	rarity = 30,
	cost = 80,
	resolvers.charmt(Talents.T_SECOND_WIND, {3,4,5}, 35),
	wielder = {
		combat_def = resolvers.mbonus_material(8, 2),
		combat_physcrit = resolvers.mbonus_material(7, 3),
		combat_apr = resolvers.mbonus_material(15, 5),
		combat_def = resolvers.mbonus_material(10, 5),
		stamina_regen = resolvers.mbonus_material(10, 5, function(e, v) v=v/10 return 0, v end),
	},
}

newEntity{
	power_source = {nature=true},
	name = "multi-hued ", prefix=true, instant_resolve=true,
	keywords = {multihued=true},
	level_range = {30, 50},
	greater_ego = 1,
	rarity = 29,
	cost = 47,
	wielder = {
		resists={
			[DamageType.ACID] = resolvers.mbonus_material(15, 5),
			[DamageType.LIGHTNING] = resolvers.mbonus_material(15, 5),
			[DamageType.FIRE] = resolvers.mbonus_material(15, 5),
			[DamageType.COLD] = resolvers.mbonus_material(15, 5),
			[DamageType.PHYSICAL] = resolvers.mbonus_material(15, 5),
		},
		combat_mindpower = resolvers.mbonus_material(10, 5),

	},
}

newEntity{
	power_source = {technique=true},
	name = " of alacrity", suffix=true, instant_resolve=true,
	keywords = {alacrity=true},
	level_range = {40, 50},
	greater_ego = 1,
	rarity = 30,
	cost = 80,
	wielder = {
		combat_physspeed = 0.15,
		combat_mindspeed = 0.15,
		combat_spellspeed = 0.15,
	},
}

newEntity{
	power_source = {technique=true, arcane=true, nature=true},
	name = " of the hero ", suffix=true, instant_resolve=true,
	keywords = {hero=true},
	level_range = {25, 50},
	greater_ego = 1,
	rarity = 30,
	cost = 35,
	wielder = {
		inc_stats = {
			[Stats.STAT_STR] = resolvers.mbonus_material(6, 3),
			[Stats.STAT_DEX] = resolvers.mbonus_material(6, 3),
			[Stats.STAT_WIL] = resolvers.mbonus_material(6, 3),
			[Stats.STAT_CUN] = resolvers.mbonus_material(6, 3),
			[Stats.STAT_MAG] = resolvers.mbonus_material(6, 3),
		},
		max_life=resolvers.mbonus_material(40, 30),
	},
}
