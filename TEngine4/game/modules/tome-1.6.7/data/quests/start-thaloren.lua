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

name = "Madness of the Ages"
desc = function(self, who)
	local desc = {}
	desc[#desc+1] = "The Thaloren forest is disrupted. Corruption is spreading. Norgos the guardian bear is said to have gone mad.\n"
	desc[#desc+1] = "On the western border of the forest a gloomy aura has been set up. Things inside are... twisted.\n"
	if self:isCompleted("norgos") then
		if self:isCompleted("norgos-invaded") then
			desc[#desc+1] = "#LIGHT_GREEN#* You have explored Norgos' Lair and stopped the shivgoroth invasion.#WHITE#"
		else
			desc[#desc+1] = "#LIGHT_GREEN#* You have explored Norgos' Lair and put it to rest.#WHITE#"
		end
	else
		desc[#desc+1] = "#SLATE#* You must explore Norgos' Lair.#WHITE#"
	end
	if self:isCompleted("heart-gloom") then
		if self:isCompleted("heart-gloom-purified") then
			desc[#desc+1] = "#LIGHT_GREEN#* You have explored the Heart of the Gloom and slain the Dreaming One.#WHITE#"
		else
			desc[#desc+1] = "#LIGHT_GREEN#* You have explored the Heart of the Gloom and slain the Withering Thing.#WHITE#"
		end
	else
		desc[#desc+1] = "#SLATE#* You must explore the Heart of the Gloom.#WHITE#"
	end
	return table.concat(desc, "\n")
end

on_status_change = function(self, who, status, sub)
	if sub then
		if self:isCompleted("norgos") and self:isCompleted("heart-gloom") then
			who:setQuestStatus(self.id, engine.Quest.DONE)
			who:grantQuest("starter-zones")
		end
	end
end
