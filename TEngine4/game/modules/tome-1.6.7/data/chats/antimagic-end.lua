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

local ogretext = ""
if player.descriptor and player.descriptor.subrace == "Ogre" then
	ogretext = "\n\n#{italic}##LIGHT_GREEN#*As you drink the potion, your runes start to burn as they fade away, and a terrible agony seems to sink through your skin to your bones, muscles, and heart.  You black out from the pain, and come to a bit later, the runes gone forever.  You feel very ill, and yet...  cleansed.*#{normal}##WHITE#"
end

newChat{ id="welcome",
	text = ([[Excellent! You truly prove that no mage-wrought flame or storm can stand against blade and arrow! Come, learn our ways. You are ready.
#LIGHT_GREEN#*he gives you a potion.*#WHITE#
Drink this. We extract it from a very rare kind of drake. It will grant you powers to fight and cancel magic, but never again will you be able to use magic.%s]]):format(ogretext),
	answers = {
		{"Thank you. I shall not let magic triumph! #LIGHT_GREEN#[you drink the potion]", action=function(npc, player) player:setQuestStatus("antimagic", engine.Quest.COMPLETED) end},
	}
}

return "welcome"
