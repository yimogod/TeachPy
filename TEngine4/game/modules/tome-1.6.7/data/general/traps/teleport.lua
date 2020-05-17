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

newEntity{ define_as = "TRAP_TELEPORT",
	type = "annoy", subtype="teleport", id_by_type=true, unided_name = "trap",
	display = '^',
	triggered = function() end,
}

newEntity{ base = "TRAP_TELEPORT",
	name = "teleport trap", auto_id = true, image = "trap/trap_teleport_01.png",
	desc = [[Teleports the victim away.  How does anyone get close enough to disarm this trap...?]],
	detect_power = resolvers.mbonus(5, 40), disarm_power = resolvers.mbonus(10, 50),
	rarity = 5, level_range = {5, nil},
	color=colors.UMBER,
	pressure_trap = true,
	message = "@Target@ shimmers briefly.",
	unided_name = "shimmering floor switch",
	triggered = function(self, x, y, who)
		if who:canBe("teleport") then
			game:onTickEnd(function()
					game.logSeen(who, "%s is teleported away!", who.name:capitalize())
					who:teleportRandom(x, y, 100) 
				end)
			return true
		else
			game.logSeen(who, "%s resists being teleported!", who.name:capitalize())
		end
	end
}
