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

load("/data/general/npcs/shade.lua", rarity(0))
load("/data/general/npcs/orc-rak-shor.lua", rarity(10))

load("/data/general/npcs/all.lua", function(e) if e.rarity then e.shade_rarity, e.rarity = e.rarity, nil end end)

local Talents = require("engine.interface.ActorTalents")

newEntity{ base="BASE_NPC_ORC_RAK_SHOR", define_as = "CULTIST_RAK_SHOR",
	name = "Rak'Shor Cultist", color=colors.VIOLET, unique = true,
	desc = [[An old orc, wearing black robes. He seems to be responsible for the creation of the shades.]],
	killer_message = "but nobody knew why #sex# suddenly became evil",
	level_range = {35, nil}, exp_worth = 2,
	rank = 4,
	max_life = 150, life_rating = 17, fixed_rating = true,
	infravision = 10,
	stats = { str=15, dex=10, cun=42, mag=16, con=14 },
	move_others=true,

	instakill_immune = 1,
	disease_immune = 1,
	confusion_immune = 1,
	combat_armor = 10, combat_def = 10,

	open_door = true,

	autolevel = "caster",
	ai = "tactical", ai_state = { talent_in=1, ai_move="move_astar", },
	ai_tactic = resolvers.tactic"ranged",
	resolvers.inscriptions(3, "rune"),

	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },

	resolvers.equip{
		{type="weapon", subtype="staff", force_drop=true, tome_drops="boss", forbid_power_source={antimagic=true}, autoreq=true},
	},
	resolvers.drops{chance=20, nb=1, {defined="JEWELER_TOME"} },
	resolvers.drops{chance=100, nb=1, {defined="LIFE_DRINKER", random_art_replace={chance=75}} },
	resolvers.drops{chance=100, nb=5, {tome_drops="boss"} },

	inc_damage = {[DamageType.BLIGHT] = -30},

	resolvers.talents{
		[Talents.T_STAFF_MASTERY]={base=3, every=7, max=5},
		[Talents.T_SOUL_ROT]={base=5, every=10, max=7},
		[Talents.T_BLOOD_GRASP]={base=5, every=10, max=7},
		[Talents.T_BONE_SHIELD]={base=5, every=10, max=7},
		[Talents.T_EVASION]={base=5, every=10, max=7},
		[Talents.T_VIRULENT_DISEASE]={base=5, every=10, max=7},
		[Talents.T_CYST_BURST]={base=3, every=10, max=7},
		[Talents.T_EPIDEMIC]={base=4, every=10, max=7},
		[Talents.T_WORM_ROT]={base=4, every=10, max=7},
	},
	resolvers.sustains_at_birth(),

	on_takehit = function(self, value, src)
		local p = self.sustain_talents[self.T_BONE_SHIELD]

		-- When the bone shield is taken down, copy the player
		if (not p or p.nb <= 0) and not self.copied_player then
			local Talents = require("engine.interface.ActorTalents")
			local a = mod.class.NPC.new{}
			local plr = game.player:resolveSource()

			local is_yeek = false
			if plr.descriptor and plr.descriptor.subrace == "Yeek" then is_yeek = true end

			a:replaceWith(plr:cloneActor({rank=4,
				level_range=self.level_range,
				is_player_doomed_shade = true,
				faction = is_yeek and plr.faction or self.faction,
				life=plr.max_life*1.2,	max_life=plr.max_life*1.2, die_at=plr.die_at*1.2,
				max_level=table.NIL_MERGE,
				name = is_yeek and ("Wayist Shade of %s"):format(plr.name) or ("Doomed Shade of %s"):format(plr.name),
				desc = is_yeek and ([[%s under the mental protection of The Way could not be swayed and sided with you against the Cultist!]]):format(plr.name) or ([[The Dark Side of %s, completely consumed by hate...]]):format(plr.name),
				killer_message = "but nobody knew why #sex# suddenly became evil",
				color_r = 150, color_g = 150, color_b = 150,
				ai = "tactical", ai_state = {talent_in=1},
				}))
			mod.class.NPC.castAs(a)
			engine.interface.ActorAI.init(a, a)
			a.inc_damage.all = (a.inc_damage.all or 0) - 40
			a.on_die = function(self)
				world:gainAchievement("SHADOW_CLONE", game.player)
				game:setAllowedBuild("afflicted")
				game:setAllowedBuild("afflicted_doomed", true)
				game.level.map(self.x, self.y, game.level.map.TERRAIN, game.zone.grid_list.UP_WILDERNESS)
				game.logSeen(self, "As your shade dies, the magical veil protecting the stairs out vanishes.")
			end

			-- Remove any disallowed talents
			a:unlearnTalentsOnClone()
			-- Add some hate-based talents
			table.insert(a, resolvers.talents{
				[Talents.T_UNNATURAL_BODY]={base=5, every=10, max=7},
				[Talents.T_RELENTLESS]={base=5, every=10, max=7},
				[Talents.T_FEED_POWER]={base=5, every=10, max=5},
				[Talents.T_FEED_STRENGTHS]={base=5, every=10, max=5},
				[Talents.T_DARK_TENDRILS]={base=5, every=10, max=5},
				[Talents.T_WILLFUL_STRIKE]={base=5, every=10, max=7},
				[Talents.T_REPROACH]={base=5, every=10, max=5},
				[Talents.T_CALL_SHADOWS]={base=5, every=10, max=5},
			})
			a:incStat("wil", a.level)
			a:removeTimedEffectsOnClone()
			local x, y = util.findFreeGrid(self.x, self.y, 10, true, {[engine.Map.ACTOR]=true})
			if x and y then
				self:logCombat(game.player, "#GREY#The #Source# looks deep into your eyes. You feel torn apart!")
				self:doEmote("Ra'kk kor merk ZUR!!!", 120)
				game.zone:addEntity(game.level, a, "actor", x, y)
				a:resolve()
				if is_yeek then
					a:doEmote("FOR THE WAY! Die cultist!", 120)
					a.can_talk = "shadow-crypt-yeek-clone"
					self:logCombat(game.player, "#PURPLE#The #Source# looks afraid, he did not plan on his creation turning against him!")
				end
				self.copied_player = true
			end

			if plr.alchemy_golem then
				a.alchemy_golem = nil
				local t = a:getTalentFromId(a.T_REFIT_GOLEM)
				t.action(a, t)
			end
		end
		return value
	end,
}
