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

newTalent{
	name = "Jelly Spread", short_name = "JELLY_PBAOE",
	type = {"wild-gift/other",1},
	points = 5,
	equilibrium = 10,
	message = "@source@ oozes over the ground!!",
	cooldown = 15,
	tactical = { ATTACKAREA = { SLIME = 4} },
	range = 0,
	radius = 1,
	target = function(self, t)
		return {type="ball", range=0, radius=1, selffire=false}
	end,
	getDamage = function(self, t) return self:combatTalentStatDamage(t, "con", 40, 140) end,
	getDuration = function(self, t) return 4 end,
	action = function(self, t)
		-- Add a lasting map effect
		game.level.map:addEffect(self,
			self.x, self.y, t.getDuration(self, t),
			DamageType.NATURE, t.getDamage(self, t),
			1,
			5, nil,
			MapEffect.new{color_br=25, color_bg=140, color_bb=40, effect_shader="shader_images/retch_effect.png"},
				function(e, update_shape_only)
					if not update_shape_only then e.radius = e.radius end
					return true
				end,
			false,
			false
		)
		game:playSoundNear(self, "talents/slime")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local duration = t.getDuration(self, t)
		return ([[Ooze over the floor, spreading caustic jelly in a radius of 1 lasting %d turns and dealing %d nature damage per turn to hostile creatures caught within.]]):format(duration, damDesc(self, DamageType.NATURE, damage))
	end,
}

newTalent{
	name = "Mitotic Split", short_name = "JELLY_MITOTIC_SPLIT",
	type = {"wild-gift/other",1},
	mode = "passive",
	points = 5,
	getDamage = function(self,t) return self:combatTalentLimit(t, 5, 20, 8) end,
	getChance = function(self,t) return self:combatTalentLimit(t, 85, 50, 75) end,
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "clone_on_hit", {min_dam_pct=t.getDamage(self,t), chance=t.getChance(self,t)})
	end,
	info = function(self, t)
		return ([[%d%% chance to split upon taking a single hit dealing at least %d%% of your maximum life.]]):format(t.getChance(self, t), t.getDamage(self, t))
	end,
}

newTalent{
	name = "War Hound",
	type = {"wild-gift/summon-melee", 1},
	require = gifts_req1,
	points = 5,
	random_ego = "attack",
	message = "@Source@ summons a War Hound!",
	equilibrium = 3,
	cooldown = 15,
	range = 5,
	radius = 5, -- used by the the AI as additional range to the target
	requires_target = true,
	is_summon = true,
	target = SummonTarget,
	onAIGetTarget = onAIGetTargetSummon,
	aiSummonGrid = aiSummonGridMelee,
	tactical = { ATTACK = { PHYSICAL = 2 } },
--	detonate_tactical = {attack = -1, attackarea = {PHYSICAL = 2}} -- WIP for use with detonate
	on_pre_use = function(self, t, silent)
		if not self:canBe("summon") and not silent then game.logPlayer(self, "You cannot summon; you are suppressed!") return end
		return not checkMaxSummon(self, silent)
	end,
	on_pre_use_ai = aiSummonPreUse,
	on_detonate = function(self, t, m)
		local tg = {type="ball", range=self:getTalentRange(t), friendlyfire=false, radius=self:getTalentRadius(t), talent=t, x=m.x, y=m.y}
		local explodeBleed = self:callTalent(self.T_DETONATE, "explodeBleed")
		self:project(tg, m.x, m.y, DamageType.BLEED, self:mindCrit(explodeBleed), {type="flame"})
	end,
	on_arrival = function(self, t, m)
		local tg = {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), talent=t, x=m.x, y=m.y}
		local duration = self:callTalent(self.T_GRAND_ARRIVAL,"effectDuration")
		local reduction = self:callTalent(self.T_GRAND_ARRIVAL,"resReduction")
		self:project(tg, m.x, m.y, DamageType.TEMP_EFFECT, {foes=true, eff=self.EFF_LOWER_PHYSICAL_RESIST, dur=duration, p={power=reduction}})
		game.level.map:particleEmitter(m.x, m.y, tg.radius, "shout", {size=4, distorion_factor=0.3, radius=tg.radius, life=30, nb_circles=8, rm=0.8, rM=1, gm=0.8, gM=1, bm=0.1, bM=0.2, am=0.6, aM=0.8})
	end,
	summonTime = function(self, t) return math.floor(self:combatScale(self:getTalentLevel(t), 5, 0, 10, 5)) + self:callTalent(self.T_RESILIENCE, "incDur") end,
	incStats = function(self, t,fake)
		local mp = self:combatMindpower()
		return{
			str=15 + (fake and mp or self:mindCrit(mp)) * 2 * self:combatTalentScale(t, 0.2, 1, 0.75) + self:combatTalentScale(t, 2, 10, 0.75),
			dex=15 + (fake and mp or self:mindCrit(mp)) * 1 * self:combatTalentScale(t, 0.2, 1, 0.75) + self:combatTalentScale(t, 2, 10, 0.75),
			con=15
		}
	end,
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, talent=t}
		--print("war hound targeting:") table.print(tg) -- debugging
		local tx, ty, target = self:getTarget(tg)
		if not tx or not ty then return nil end
		local _ _, _, _, tx, ty = self:canProject(tg, tx, ty)
		target = self.ai_target.actor
		if target == self then target = nil end
		-- Find space
		local x, y = util.findFreeGrid(tx, ty, 5, true, {[Map.ACTOR]=true})
		if not x then
			game.logPlayer(self, "Not enough space to summon!")
			return
		end
		local NPC = require "mod.class.NPC"
		local m = NPC.new{
			type = "animal", subtype = "canine",
			display = "C", color=colors.LIGHT_DARK, image = "npc/summoner_wardog.png",
			name = "war hound", faction = self.faction,
			desc = [[]],
			autolevel = "none",
			ai = "summoned", ai_real = "dumb_talented_simple", ai_state = { talent_in=5, },
			stats = {str=0, dex=0, con=0, cun=0, wil=0, mag=0},
			inc_stats = t.incStats(self, t),
			level_range = {self.level, self.level}, exp_worth = 0,
			global_speed_base = 1.2,

			max_life = resolvers.rngavg(25,50),
			life_rating = 6,
			infravision = 10,

			combat_armor = 2, combat_def = 4,
			combat = { dam=self:getTalentLevel(t) * 10 + rng.avg(12,25), atk=10, apr=10, dammod={str=0.8} },

			wild_gift_detonate = t.id,

			summoner = self, summoner_gain_exp=true, wild_gift_summon=true,
			summon_time = t.summonTime(self, t),
			ai_target = {actor=target}
		}
		if self:attr("wild_summon") and rng.percent(self:attr("wild_summon")) then
			m.name = m.name.." (wild summon)"
			m[#m+1] = resolvers.talents{ [self.T_TOTAL_THUGGERY]=self:getTalentLevelRaw(t) }
		end
		m.is_nature_summon = true
		setupSummon(self, m, x, y)

		if self:knowTalent(self.T_RESILIENCE) then
			local incLife = self:callTalent(self.T_RESILIENCE, "incLife") + 1
			m.max_life = m.max_life * incLife
			m.life = m.max_life
		end

		game:playSoundNear(self, "talents/spell_generic")
		return true
	end,
	info = function(self, t)
		local incStats = t.incStats(self, t, true)
		return ([[Summon a War Hound for %d turns to attack your foes. War hounds are good basic melee attackers.
		It will get %d Strength, %d Dexterity and %d Constitution.
		Your summons inherit some of your stats: increased damage%%, resistance penetration %%, stun/pin/confusion/blindness resistance, armour penetration.
		The hound's Strength and Dexterity will increase with your Mindpower.]])
		:format(t.summonTime(self, t), incStats.str, incStats.dex, incStats.con)
	end,
}

newTalent{
	name = "Jelly",
	type = {"wild-gift/summon-melee", 2},
	require = gifts_req2,
	points = 5,
	random_ego = "attack",
	message = "@Source@ summons a Jelly!",
	equilibrium = 2,
	cooldown = 10,
	range = 5,
	radius = 1, -- used by the the AI as additional range to the target
	requires_target = true,
	is_summon = true,
	target = SummonTarget,
	onAIGetTarget = onAIGetTargetSummon,
	aiSummonGrid = aiSummonGridMelee,
	tactical = { ATTACK = { NATURE = 1 }, EQUILIBRIUM = 1, },
	on_pre_use = function(self, t, silent)
		if not self:canBe("summon") and not silent then game.logPlayer(self, "You cannot summon; you are suppressed!") return end
		return not checkMaxSummon(self, silent)
	end,
	on_pre_use_ai = aiSummonPreUse,
	on_detonate = function(self, t, m)
		local tg = {type="ball", range=self:getTalentRange(t), friendlyfire=false, radius=self:getTalentRadius(t), talent=t, x=m.x, y=m.y}
		local explodeDamage = self:callTalent(self.T_DETONATE, "explodeSecondary")
		local jellySlow = self:callTalent(self.T_DETONATE, "jellySlow")
		self:project(tg, m.x, m.y, DamageType.SLIME, {dam=self:mindCrit(explodeDamage), power=jellySlow}, {type="slime"})
	end,
	on_arrival = function(self, t, m)
		local tg = {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), talent=t, x=m.x, y=m.y}
		local duration = self:callTalent(self.T_GRAND_ARRIVAL,"effectDuration")
		local reduction = self:callTalent(self.T_GRAND_ARRIVAL,"resReduction")
		self:project(tg, m.x, m.y, DamageType.TEMP_EFFECT, {foes=true, eff=self.EFF_LOWER_NATURE_RESIST, dur=duration, p={power=reduction}}, {type="flame"})
	end,
	summonTime = function(self, t) return math.floor(self:combatScale(self:getTalentLevel(t), 5, 0, 10, 5)) + self:callTalent(self.T_RESILIENCE, "incDur") end,
	incStats = function(self, t, fake)
		local mp = self:combatMindpower()
		return{
			con=10 + (fake and mp or self:mindCrit(mp)) * 1.6 * self:combatTalentScale(t, 0.2, 1, 0.75),
			str=10 + self:combatTalentScale(t, 2, 10, 0.75)
		}
	end,
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, talent=t}
		local tx, ty, target = self:getTarget(tg)
		if not tx or not ty then return nil end
		local _ _, _, _, tx, ty = self:canProject(tg, tx, ty)
		target = self.ai_target.actor
		if target == self then target = nil end

		-- Find space
		local x, y = util.findFreeGrid(tx, ty, 5, true, {[Map.ACTOR]=true})
		if not x then
			game.logPlayer(self, "Not enough space to summon!")
			return
		end

		local NPC = require "mod.class.NPC"
		local m = NPC.new{
			type = "immovable", subtype = "jelly", image = "npc/jelly-darkgrey.png",
			display = "j", color=colors.BLACK,
			desc = "A strange blob on the dungeon floor.",
			name = "black jelly",
			autolevel = "none", faction=self.faction,
			stats = {str=0, dex=0, con=0, cun=0, wil=0, mag=0},
			inc_stats = t.incStats(self, t),
			resists = { [DamageType.LIGHT] = -50 },
			ai = "summoned", ai_real = "dumb_talented_simple", ai_state = { talent_in=5, },
			level_range = {self.level, self.level}, exp_worth = 0,

			max_life = resolvers.rngavg(25,50),
			life_rating = 15,
			infravision = 10,

			combat_armor = 1, combat_def = 1,
			never_move = 1,
			resolvers.talents{ [Talents.T_JELLY_PBAOE]=self:getTalentLevelRaw(t) },

			combat = { dam=8, atk=15, apr=5, damtype=DamageType.NATURE, dammod={str=0.7} },

			wild_gift_detonate = t.id,

			summoner = self, summoner_gain_exp=true, wild_gift_summon=true,
			summon_time = t.summonTime(self, t),
			ai_target = {actor=target},

			on_takehit = function(self, value, src)
				local p = value * 0.10
				if self.summoner and not self.summoner.dead then
					self.summoner:incEquilibrium(-p)
					game:delayedLogMessage(self.summoner, self, "jelly", "#GREEN##Target# absorbs some damage. #Source# is closer to nature.")
				end
				return value - p
			end,
		}
		if self:attr("wild_summon") and rng.percent(self:attr("wild_summon")) then
			m.name = m.name.." (wild summon)"
			m[#m+1] = resolvers.talents{ [self.T_JELLY_MITOTIC_SPLIT]=self:getTalentLevelRaw(t) }
		end
		m.is_nature_summon = true
		setupSummon(self, m, x, y)

		if self:knowTalent(self.T_RESILIENCE) then
			local incLife = self:callTalent(self.T_RESILIENCE, "incLife") + 1
			m.max_life = m.max_life * incLife
			m.life = m.max_life
		end

		game:playSoundNear(self, "talents/spell_generic")
		return true
	end,
	info = function(self, t)
		local incStats = t.incStats(self, t, true)
		return ([[Summon a Jelly for %d turns to attack your foes. Jellies do not move, but your equilibrium will be reduced by 10%% of all damage received by the jelly.
		It will get %d Constitution and %d Strength.
		Your summons inherit some of your stats: increased damage%%, resistance penetration %%, stun/pin/confusion/blindness resistance, armour penetration.
		The jelly's Constitution will increase with your Mindpower.]])
		:format(t.summonTime(self, t), incStats.con, incStats.str)
       end,
}

newTalent{
	name = "Minotaur",
	type = {"wild-gift/summon-melee", 3},
	require = gifts_req3,
	points = 5,
	random_ego = "attack",
	message = "@Source@ summons a Minotaur!",
	equilibrium = 10,
	cooldown = 15,
	range = 5,
	radius = 5, -- used by the the AI as additional range to the target
	is_summon = true,
	target = SummonTarget,
	onAIGetTarget = onAIGetTargetSummon,
	aiSummonGrid = aiSummonGridMelee,
	requires_target = true,
	tactical = { ATTACK = { PHYSICAL = 2 }, DISABLE = { confusion = 1, stun = 1 } },
	on_pre_use = function(self, t, silent)
		if not self:canBe("summon") and not silent then game.logPlayer(self, "You cannot summon; you are suppressed!") return end
		return not checkMaxSummon(self, silent)
	end,
	on_pre_use_ai = aiSummonPreUse,
	on_detonate = function(self, t, m)
		local tg = {type="ball", range=self:getTalentRange(t), friendlyfire=false, radius=self:getTalentRadius(t), talent=t, x=m.x, y=m.y}
		local confusePower = self:callTalent(self.T_DETONATE,"minotaurConfuse")
		self:project(tg, m.x, m.y, DamageType.TEMP_EFFECT, {foes=true, eff=self.EFF_CONFUSED, check_immune="confusion", dur=5, p={minotaurConfuse}}, {type="flame"})
	end,
	on_arrival = function(self, t, m)
		local tg = {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), talent=t, x=m.x, y=m.y}
		local duration = self:callTalent(self.T_GRAND_ARRIVAL,"effectDuration")
		local slowdown = self:callTalent(self.T_GRAND_ARRIVAL,"slowStrength") / 100 --divide by 100 to change percent to decimal
		self:project(tg, m.x, m.y, DamageType.TEMP_EFFECT, {foes=true, eff=self.EFF_SLOW_MOVE, dur=duration, p={power=slowdown}}, {type="flame"})
	end,
	summonTime = function(self, t) return math.floor(self:combatScale(self:getTalentLevel(t), 2, 0, 7, 5)) + self:callTalent(self.T_RESILIENCE, "incDur") end,
	incStats = function(self, t,fake)
		local mp = self:combatMindpower()
		return{
			str=25 + (fake and mp or self:mindCrit(mp)) * 2.1 * self:combatTalentScale(t, 0.2, 1, 0.75) + self:combatTalentScale(t, 2, 10, 0.75),
			dex=10 + (fake and mp or self:mindCrit(mp)) * 1.8 * self:combatTalentScale(t, 0.2, 1, 0.75) + self:combatTalentScale(t, 2, 10, 0.75),
			con=10 + self:combatTalentScale(t, 2, 10, 0.75)
		}
	end,
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, talent=t}
		local tx, ty, target = self:getTarget(tg)
		if not tx or not ty then return nil end
		local _ _, _, _, tx, ty = self:canProject(tg, tx, ty)
		target = self.ai_target.actor
		if target == self then target = nil end

		-- Find space
		local x, y = util.findFreeGrid(tx, ty, 5, true, {[Map.ACTOR]=true})
		if not x then
			game.logPlayer(self, "Not enough space to summon!")
			return
		end

		local NPC = require "mod.class.NPC"
		local m = NPC.new{
			type = "giant", subtype = "minotaur",
			display = "H",
			name = "minotaur", color=colors.UMBER, resolvers.nice_tile{image="invis.png", add_mos = {{image="npc/giant_minotaur_minotaur.png", display_h=2, display_y=-1}}},

			body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },

			max_stamina = 100,
			life_rating = 13,
			max_life = resolvers.rngavg(50,80),
			infravision = 10,

			autolevel = "none",
			ai = "summoned", ai_real = "dumb_talented_simple", ai_state = { talent_in=2, },
			global_speed_base=1.2,
			stats = {str=0, dex=0, con=0, cun=0, wil=0, mag=0},
			inc_stats = t.incStats(self, t),
			desc = [[It is a cross between a human and a bull.]],
			resolvers.equip{ {type="weapon", subtype="battleaxe", auto_req=true}, },
			level_range = {self.level, self.level}, exp_worth = 0,

			combat_armor = 13, combat_def = 8,
			resolvers.talents{ [Talents.T_WARSHOUT]=3, [Talents.T_STUNNING_BLOW]=3, [Talents.T_SUNDER_ARMOUR]=2, [Talents.T_SUNDER_ARMS]=2, },

			wild_gift_detonate = t.id,

			faction = self.faction,
			summoner = self, summoner_gain_exp=true, wild_gift_summon=true,
			summon_time = t.summonTime(self,t),
			ai_target = {actor=target}
		}
		if self:attr("wild_summon") and rng.percent(self:attr("wild_summon")) then
			m.name = m.name.." (wild summon)"
			m[#m+1] = resolvers.talents{ [self.T_RUSH]=self:getTalentLevelRaw(t) }
		end
		m.is_nature_summon = true
		setupSummon(self, m, x, y)

		if self:knowTalent(self.T_RESILIENCE) then
			local incLife = self:callTalent(self.T_RESILIENCE, "incLife") + 1
			m.max_life = m.max_life * incLife
			m.life = m.max_life
		end

		game:playSoundNear(self, "talents/spell_generic")
		return true
	end,
	info = function(self, t)
		local incStats = t.incStats(self, t, true)
		return ([[Summon a Minotaur for %d turns to attack your foes. Minotaurs cannot stay summoned for long, but they deal high damage.
		It will get %d Strength, %d Constitution and %d Dexterity.
		Your summons inherit some of your stats: increased damage%%, resistance penetration %%, stun/pin/confusion/blindness resistance, armour penetration.
		The minotaur's Strength and Dexterity will increase with your Mindpower.]])
		:format(t.summonTime(self,t), incStats.str, incStats.con, incStats.dex)
	end,
}

newTalent{
	name = "Stone Golem",
	type = {"wild-gift/summon-melee", 4},
	require = gifts_req4,
	points = 5,
	random_ego = "attack",
	message = "@Source@ summons a Stone Golem!",
	equilibrium = 15,
	cooldown = 20,
	range = 5,
	radius = 5, -- used by the the AI as additional range to the target
	is_summon = true,
	target = SummonTarget,
	onAIGetTarget = onAIGetTargetSummon,
	aiSummonGrid = aiSummonGridMelee,
	tactical = { ATTACK = { PHYSICAL = 2 }, DISABLE = { knockback = 1, stun = 1 } },
	on_pre_use = function(self, t, silent)
		if not self:canBe("summon") and not silent then game.logPlayer(self, "You cannot summon; you are suppressed!") return end
		return not checkMaxSummon(self, silent)
	end,
	on_pre_use_ai = aiSummonPreUse,
	on_detonate = function(self, t, m)
		local tg = {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), talent=t, x=m.x, y=m.y, ignore_nullify_all_friendlyfire=true}
		local golemArmour = self:callTalent(self.T_DETONATE,"golemArmour")
		local golemHardiness = self:callTalent(self.T_DETONATE,"golemHardiness")
		self:project(tg, m.x, m.y, function(px, py)
			local target = game.level.map(px, py, Map.ACTOR)
			if not target or self:reactionToward(target) < 0 then return end
			target:setEffect(target.EFF_THORNY_SKIN, 5, {ac=golemArmour, hard=golemHardiness})
		end, nil, {type="flame"})
	end,
	on_arrival = function(self, t, m)
		local tg = {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), talent=t, x=m.x, y=m.y}
		local duration = self:callTalent(self.T_GRAND_ARRIVAL,"effectDuration")
		self:project(tg, m.x, m.y, DamageType.TEMP_EFFECT, {foes=true, eff=self.EFF_DAZED, check_immune="stun", dur=duration, p={}}, {type="flame"})
	end,
	requires_target = true,
	summonTime = function(self, t) return math.floor(self:combatScale(self:getTalentLevel(t), 5, 0, 10, 5)) + self:callTalent(self.T_RESILIENCE, "incDur") end,
	incStats = function(self, t,fake)
		local mp = self:combatMindpower()
		return{
			str=15 + (fake and mp or self:mindCrit(mp)) * 2 * self:combatTalentScale(t, 0.2, 1, 0.75) + self:combatTalentScale(t, 2, 10, 0.75),
			dex=15 + (fake and mp or self:mindCrit(mp)) * 1.9 * self:combatTalentScale(t, 0.2, 1, 0.75) + self:combatTalentScale(t, 2, 10, 0.75),
			con=10 + self:combatTalentScale(t, 2, 10, 0.75)
		}
	end,
	action = function(self, t)
		local tg = {type="bolt", nowarning=true, range=self:getTalentRange(t), nolock=true, talent=t}
		local tx, ty, target = self:getTarget(tg)
		if not tx or not ty then return nil end
		local _ _, _, _, tx, ty = self:canProject(tg, tx, ty)
		target = self.ai_target.actor
		if target == self then target = nil end

		-- Find space
		local x, y = util.findFreeGrid(tx, ty, 5, true, {[Map.ACTOR]=true})
		if not x then
			game.logPlayer(self, "Not enough space to summon!")
			return
		end

		local NPC = require "mod.class.NPC"
		local m = NPC.new{
			type = "golem", subtype = "stone",
			display = "g",
			name = "stone golem", color=colors.WHITE, image = "npc/summoner_golem.png",

			body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },

			max_stamina = 800,
			life_rating = 13,
			max_life = resolvers.rngavg(50,80),
			infravision = 10,

			autolevel = "none",
			ai = "summoned", ai_real = "dumb_talented_simple", ai_state = { talent_in=2, },
			stats = {str=0, dex=0, con=0, cun=0, wil=0, mag=0},
			inc_stats = t.incStats(self, t),
			desc = [[It is a massive animated statue.]],
			level_range = {self.level, self.level}, exp_worth = 0,

			combat_armor = 25, combat_def = -20,
			combat = { dam=25 + self:getWil(), atk=20, apr=5, dammod={str=0.9} },
			resolvers.talents{ [Talents.T_UNSTOPPABLE]=3, [Talents.T_STUN]=3, },

			poison_immune=1, cut_immune=1, fear_immune=1, blind_immune=1,

			wild_gift_detonate = t.id,

			faction = self.faction,
			summoner = self, summoner_gain_exp=true, wild_gift_summon=true,
			summon_time = t.summonTime(self, t),
			ai_target = {actor=target},
			resolvers.sustains_at_birth(),
		}
		if self:attr("wild_summon") and rng.percent(self:attr("wild_summon")) then
			m.name = m.name.." (wild summon)"
			m[#m+1] = resolvers.talents{ [self.T_DISARM]=self:getTalentLevelRaw(t) }
		end
		m.is_nature_summon = true
		setupSummon(self, m, x, y)

		if self:knowTalent(self.T_RESILIENCE) then
			local incLife = self:callTalent(self.T_RESILIENCE, "incLife") + 1
			m.max_life = m.max_life * incLife
			m.life = m.max_life
		end

		game:playSoundNear(self, "talents/spell_generic")
		return true
	end,
	info = function(self, t)
		local incStats = t.incStats(self, t,true)
		return ([[Summon a Stone Golem for %d turns to attack your foes. Stone golems are formidable foes that can become unstoppable.
		It will get %d Strength, %d Constitution and %d Dexterity.
		Your summons inherit some of your stats: increased damage%%, resistance penetration %%, stun/pin/confusion/blindness resistance, armour penetration.
		The golem's Strength and Dexterity will increase with your Mindpower.]])
		:format(t.summonTime(self, t), incStats.str, incStats.con, incStats.dex)
	end,
}
