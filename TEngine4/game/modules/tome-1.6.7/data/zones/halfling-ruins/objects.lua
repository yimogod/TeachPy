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

load("/data/general/objects/objects-maj-eyal.lua")

for i = 1, 4 do
newEntity{ base = "BASE_LORE",
	define_as = "NOTE"..i,
	name = "research log of halfling mage Hompalan", lore="halfling-research-note-"..i,
	desc = [[A very faded research note, nearly unreadable.]],
	rarity = false,
	encumberance = 0,
}
end
newEntity{ base = "BASE_LORE",
	define_as = "DIRECTOR_HOMPALAN_ORDER",
	name = "order for Director Hompalan", lore="conclave-vault-start",
	desc = [[A very faded note, nearly unreadable.]],
	rarity = false,
	encumberance = 0,
}

newEntity{ base = "BASE_CLOTH_ARMOR",
	power_source = {psionic=true},
	unique = true,
	name = "Yeek-fur Robe", color = colors.WHITE, image = "object/artifact/yeek_fur_robe.png",
	unided_name = "sleek fur robe",
	desc = [[A beautifully soft robe of fine white fur. It looks designed for a halfling noble, with glorious sapphires sewn across the hems. But entrancing as it is, you can't help but feel a little queasy wearing it.]],
	level_range = {16, 30},
	rarity = 20,
	cost = 250,
	material_level = 3,
	wielder = {
		esp = { humanoid=1 },
		combat_def = 10,
		combat_armor = 5,
		combat_mindpower = 10,
		combat_mindcrit = 5,
		combat_mentalresist = 10,
		confusion_immune = 0.35,
		inc_damage={
			[DamageType.MIND] = 20,},
		resists= {
			[DamageType.MIND] = 20,
			[DamageType.COLD] = 20,}
	},
	on_wear = function(self, who)
		if who.descriptor and who.descriptor.race == "Yeek" then
			local Talents = require "engine.interface.ActorStats"
			self:specialWearAdd({"wielder","combat_mindpower"}, -20)
			self:specialWearAdd({"wielder","combat_mindcrit"}, -10)
			self:specialWearAdd({"wielder","combat_mentalresist"}, -25)
			self:specialWearAdd({"wielder","confusion_immune"}, -0.35)
			self:specialWearAdd({"wielder","resists"}, {[engine.DamageType.MIND] = -30,}) --Yeek REALLY doesn't like wearing this
			game.logPlayer(who, "#RED#You feel disgusted touching this thing!")
		end
		if who.descriptor and who.descriptor.race == "Halfling" then
			local Talents = require "engine.interface.ActorStats"
			self:specialWearAdd({"wielder","resists"}, {[engine.DamageType.MIND] = 15,})
			self:specialWearAdd({"wielder","confusion_immune"}, 0.65)
			self:specialWearAdd({"wielder","combat_mentalresist"}, 10)
			game.logPlayer(who, "#LIGHT_BLUE#You feel this robe was made for you!")
		end
	end,
}
