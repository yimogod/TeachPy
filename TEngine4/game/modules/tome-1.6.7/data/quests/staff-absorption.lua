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

use_ui = "quest-main"

-- Main quest: the Staff of Absorption
name = "A mysterious staff"
desc = function(self, who)
	local desc = {}
	desc[#desc+1] = "Deep in the Dreadfell you fought and destroyed the Master, a powerful vampire."
	if self:isCompleted("ambush") and not self:isCompleted("ambush-died") then
		desc[#desc+1] = "On your way out of the Dreadfell you were ambushed by a band of orcs."
		desc[#desc+1] = "They asked about the staff."
	elseif self:isCompleted("ambush-died") and not self:isCompleted("survived-ukruk") then
		desc[#desc+1] = "On your way out of the Dreadfell you were ambushed by a band of orcs and left for dead."
		desc[#desc+1] = "They asked about the staff and stole it from you."
		desc[#desc+1] = "#LIGHT_GREEN#Go at once to Last Hope to report those events!"
	elseif not self:isCompleted("ambush-died") and self:isCompleted("survived-ukruk") then
		desc[#desc+1] = "On your way out of the Dreadfell you were ambushed by a band of orcs."
		desc[#desc+1] = "They asked about the staff and stole it from you."
		desc[#desc+1] = "You told them nothing and vanquished them."
		desc[#desc+1] = "#LIGHT_GREEN#Go at once to Last Hope to report those events!"
	else
		desc[#desc+1] = "In its remains, you found a strange staff. It radiates power and danger and you dare not use it yourself."
		desc[#desc+1] = "You should bring it to the elders of Last Hope in the southeast."
	end
	return table.concat(desc, "\n")
end

on_grant = function(self, who)
	game.party:learnLore("master-slain")
	game.logPlayer(who, "#00FFFF#You can feel the power of this staff just by carrying it. This is both ancient and dangerous.")
	game.logPlayer(who, "#00FFFF#It should be shown to the wise elders in Last Hope!")
end

start_ambush = function(self, who)
	game.logPlayer(who, "#VIOLET#As you come out of the Dreadfell, you encounter a band of orcs!")
	who:setQuestStatus("staff-absorption", engine.Quest.COMPLETED, "ambush")

	-- Next time the player dies (and he WILL die) he wont really die
	who.die = function(self)
		self.dead = false
		self.die = nil
		self.life = self.max_life
		for _, e in pairs(game.level.entities) do
			if not game.party:hasMember(e) then
				game.level:removeEntity(e, true)
				e.dead = true
			end
		end

		-- Go through all effects and disable them
		local effs = {}
		for eff_id, p in pairs(self.tmp) do
			local e = self.tempeffect_def[eff_id]
			effs[#effs+1] = {"effect", eff_id}
		end
		while #effs > 0 do
			local eff = rng.tableRemove(effs)
			self:removeEffect(eff[2])
		end

		-- Protect from other hits on the same turn
		self:setEffect(self.EFF_DAMAGE_SHIELD, 3, {power=1000000})
		self:removeEffectsFilter{status="detrimental"}

		local carry, o, item, inven_id = game.party:findInAllInventoriesBy("define_as", "STAFF_ABSORPTION")
		if carry and o then
			carry:removeObject(inven_id, item, true)
			o:removed()
		end

		require("engine.ui.Dialog"):simpleLongPopup("Ambush", [[You wake up after a few hours, surprised to be alive, but the staff is gone!
#VIOLET#Go at once to Last Hope to report those events!]], 600)
		
		local oe = game.level.map(self.x, self.y, engine.Map.TERRAIN)
		if oe:attr("temporary") and oe.old_feat then 
			oe.old_feat = game.level.map(self.x, self.y, game.level.map.TERRAIN, game.zone.grid_list.GRASS_UP_WILDERNESS)
		else
			game.level.map(self.x, self.y, game.level.map.TERRAIN, game.zone.grid_list.GRASS_UP_WILDERNESS)
		end

		self:setQuestStatus("staff-absorption", engine.Quest.COMPLETED, "ambush-died")
	end

	local Chat = require("engine.Chat")
	local chat = Chat.new("dreadfell-ambush", {name="Ukruk the Fierce"}, who)
	chat:invoke()
end

killed_ukruk = function(self, who)
	game.player.die = nil

	require("engine.ui.Dialog"):simpleLongPopup("Ambush", [[You are surprised to still be alive.
#VIOLET#Go at once to Last Hope to report those events!]], 600)

	local oe = game.level.map(who.x, who.y, engine.Map.TERRAIN)
	if oe:attr("temporary") and oe.old_feat then 
		oe.old_feat = game.level.map(who.x, who.y, game.level.map.TERRAIN, game.zone.grid_list.GRASS_UP_WILDERNESS)
	else
		game.level.map(who.x, who.y, game.level.map.TERRAIN, game.zone.grid_list.GRASS_UP_WILDERNESS)
	end
	
	who:setQuestStatus("staff-absorption", engine.Quest.COMPLETED, "survived-ukruk")
end
