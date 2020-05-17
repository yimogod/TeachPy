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
chat_level = player:getTalentLevelRaw(chat_talent)
trap_mastery = chat_talent.getTrapMastery(player, chat_talent)
local old_trap_primed = player.trap_primed
local new_trap_primed = old_trap_primed
local base_chat
local function generate_traps()
	local answers = {{"[Cancel]", tier=0}}
		for i, tid in pairs(trapping_tids) do
			local t = npc:getTalentFromId(tid)
			local tier = t.trap_mastery_level
			local canlearn, unlearnable = player:canLearnTalent(t)
			if t.allow_primed_trigger and tier <= chat_level then -- trap can be primed
				local toggle_project = function(npc, player, chat)
					base_chat = base_chat or chat
--					game.log("toggling %s", tid)
					if new_trap_primed == tid then
						new_trap_primed = nil
					else
						if not canlearn then game.logPlayer(player, "#LIGHT_BLUE#You cannot prepare this trap: %s.", unlearnable) return end
						new_trap_primed = tid
					end
					player:talentDialogReturn(new_trap_primed, old_trap_primed)
				end
				local text, color = "#WHITE#", "Not Prepared"
				if player.trap_primed == tid then color, text = "#LIGHT_BLUE#", "Primed Trigger"
				elseif unlearnable then color, text = "#GREY#", "Not Usable"
				elseif player:knowTalent(tid) then color, text = "#SALMON#", "Normal Trigger"
				end
				local label = ("%s[%s: %s]#LAST#"):format(color, text, t.name)

				answers[#answers+1] = {label,
					tier = tier,
					unlearnable = unlearnable,
					action=toggle_project,
					on_select=function(npc, player)
						local mastery = nil
						game.tooltip_x, game.tooltip_y = 1, 1
						player.turn_procs.trap_mastery_tid = chat_talent.id
						game:tooltipDisplayAtMap(game.w, game.h, "#GOLD#"..t.name.."#LAST#\n"..tostring(player:getTalentFullDescription(t, 1, {force_level=1})))
						player.turn_procs.trap_mastery_tid = nil
					end,
				}
			end
		end
		table.sort(answers, function(a, b) return a.tier < b.tier end)

	return answers
end

newChat{ id="welcome",
	text = [[Choose a trap to prepare with a primed (instant) trigger or to dismantle.
#YELLOW#Newly prepared traps are placed on cooldown.#LAST#]],
	answers = generate_traps(),
}

return "welcome"
