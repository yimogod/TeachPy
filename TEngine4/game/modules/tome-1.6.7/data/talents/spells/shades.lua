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
	name = "Shadow Tunnel",
	type = {"spell/shades",1},
	require = spells_req_high1,
	points = 5,
	random_ego = "attack",
	mana = 25,
	cooldown = 20,
	range = 10,
	tactical = { DEFEND = 2 },
	requires_target = true,
	getChance = function(self, t) return 20 + self:combatTalentSpellDamage(t, 15, 60) end,
	action = function(self, t)
		local list = {}
		if game.party and game.party:hasMember(self) then
			for act, def in pairs(game.party.members) do
				if act.summoner and act.summoner == self and act.necrotic_minion then list[#list+1] = act end
			end
		else
			for uid, act in pairs(game.level.entities) do
				if act.summoner and act.summoner == self and act.necrotic_minion then list[#list+1] = act end
			end
		end

		local empower = necroEssenceDead(self)
		for i, m in ipairs(list) do
			local x, y = util.findFreeGrid(self.x, self.y, 5, true, {[Map.ACTOR]=true})
			if x and y then
				m:move(x, y, true)
				game.level.map:particleEmitter(x, y, 1, "summon")
			end
			m:setEffect(m.EFF_EVASION, 5, {chance=t.getChance(self, t)})
			if empower then
				m:heal(m.max_life * 0.3)
				if core.shader.active(4) then
					m:addParticles(Particles.new("shader_shield_temp", 1, {toback=true , size_factor=1.5, y=-0.3, img="healdark", life=25}, {type="healing", time_factor=6000, beamsCount=15, noup=2.0, beamColor1={0xcb/255, 0xcb/255, 0xcb/255, 1}, beamColor2={0x35/255, 0x35/255, 0x35/255, 1}}))
					m:addParticles(Particles.new("shader_shield_temp", 1, {toback=false, size_factor=1.5, y=-0.3, img="healdark", life=25}, {type="healing", time_factor=6000, beamsCount=15, noup=1.0, beamColor1={0xcb/255, 0xcb/255, 0xcb/255, 1}, beamColor2={0x35/255, 0x35/255, 0x35/255, 1}}))
				end
			end
		end
		if empower then empower() end

		game:playSoundNear(self, "talents/spell_generic")
		return true
	end,
	info = function(self, t)
		local chance = t.getChance(self, t)
		return ([[Surround your minions in a veil of darkness. The darkness will teleport them to you, and grant them %d%% evasion for 5 turns.
		The evasion chance will increase with your Spellpower.]]):
		format(chance)
	end,
}

newTalent{
	name = "Curse of the Meek",
	type = {"spell/shades",2},
	require = spells_req_high2,
	points = 5,
	mana = 50,
	cooldown = 30,
	range = 10,
	tactical = { DEFEND = 3 },
	action = function(self, t)
		local nb = math.ceil(self:getTalentLevel(t))
		for i = 1, nb do
			local x, y = util.findFreeGrid(self.x, self.y, 5, true, {[Map.ACTOR]=true})
			if x and y then
				local NPC = require "mod.class.NPC"
				local m = NPC.new{
					type = "humanoid", display = "p",
					color=colors.WHITE,

					combat = { dam=resolvers.rngavg(1,2), atk=2, apr=0, dammod={str=0.4} },

					body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1, QUIVER=1 },
					lite = 3,

					life_rating = 10,
					rank = 2,
					size_category = 3,

					autolevel = "warrior",
					stats = { str=12, dex=8, mag=6, con=10 },
					ai = "summoned", ai_real = "dumb_talented_simple", ai_state = { talent_in=2, },
					level_range = {1, 3},

					max_life = resolvers.rngavg(30,40),
					combat_armor = 2, combat_def = 0,

					summoner = self,
					summoner_gain_exp=false,
					summon_time = 8,
				}

				m.level = 1
				local race = 5 -- rng.range(1, 5)
				if race == 1 then
					m.name = "human farmer"
					m.subtype = "human"
					m.image = "npc/humanoid_human_human_farmer.png"
					m.desc = [[A weather-worn human farmer, looking at a loss as to what's going on.]]
				elseif race == 2 then
					m.name = "halfling gardener"
					m.subtype = "halfling"
					m.desc = [[A rugged halfling gardener, looking quite confused as to what he's doing here.]]
					m.image = "npc/humanoid_halfling_halfling_gardener.png"
				elseif race == 3 then
					m.name = "shalore scribe"
					m.subtype = "shalore"
					m.desc = [[A scrawny elven scribe, looking bewildered at his surroundings.]]
					m.image = "npc/humanoid_shalore_shalore_rune_master.png"
				elseif race == 4 then
					m.name = "dwarven lumberjack"
					m.subtype = "dwarf"
					m.desc = [[A brawny dwarven lumberjack, looking a bit upset at his current situation.]]
					m.image = "npc/humanoid_dwarf_lumberjack.png"
				elseif race == 5 then
					m.name = "cute bunny"
					m.type = "vermin" m.subtype = "rodent"
					m.desc = [[It is so cute!]]
					m.image = "npc/vermin_rodent_cute_little_bunny.png"
				end
				m.faction = self.faction
				m.no_necrotic_soul = true

				m:resolve() m:resolve(nil, true)
				m:forceLevelup(self.level)
				game.zone:addEntity(game.level, m, "actor", x, y)
				game.level.map:particleEmitter(x, y, 1, "summon")
				m:setEffect(m.EFF_CURSE_HATE, 100, {src=self})
				m.on_die = function(self, src)
					local p = self.summoner:isTalentActive(self.summoner.T_NECROTIC_AURA)
					if p and src and src.reactionToward and src:reactionToward(self) < 0 and rng.percent(70) then
						self.summoner:incSoul(1)
						self.summoner.changed = true
					end
				end
			end
		end
		game:playSoundNear(self, "talents/spell_generic")
		return true
	end,
	info = function(self, t)
		return ([[Reaches through the shadows into quieter places, summoning %d harmless creatures.
		Those creatures are then cursed with a Curse of Hate, making all hostile foes try to kill them.
		If the summoned creatures are killed by hostile foes, you have 70%% chance to gain a soul.]]):
		format(math.ceil(self:getTalentLevel(t)))
	end,
}

newTalent{
	name = "Forgery of Haze",
	type = {"spell/shades",3},
	require = spells_req_high3,
	points = 5,
	mana = 70,
	cooldown = 30,
	range = 10,
	tactical = { ATTACK = 2, },
	requires_target = true,
	unlearn_on_clone = true,
	getDuration = function(self, t) return math.floor(self:combatTalentLimit(t, 30, 4, 8.1)) end, -- Limit <30
	getHealth = function(self, t) return self:combatLimit(self:combatTalentSpellDamage(t, 20, 500), 1.0, 0.2, 0, 0.58, 384) end,  -- Limit health < 100%
	getDam = function(self, t) return self:combatLimit(self:combatTalentSpellDamage(t, 10, 500), 1.40, 0.4, 0, 0.76, 361) end,  -- Limit damage < 140%
	action = function(self, t)
		-- Find space
		local x, y = util.findFreeGrid(self.x, self.y, 1, true, {[Map.ACTOR]=true})
		if not x then
			game.logPlayer(self, "Not enough space to summon!")
			return
		end
		local hfct = t.getHealth(self, t)
		local m = require("mod.class.NPC").new(self:cloneActor{
			shader = "shadow_simulacrum",
			faction = self.faction, exp_worth = 0,
			max_life = self.max_life*hfct, die_at = self.die_at*hfct,
			life = util.bound(self.life*hfct, self.die_at*hfct, self.max_life*hfct),
			max_level = self.level,
			summoner = self, summoner_gain_exp=true, summon_time = t.getDuration(self, t),
			
			ai_target = {actor=table.NIL_MERGE},
			ai = "summoned", ai_real = "tactical",
			name = "Forgery of Haze ("..self.name..")",
			desc = ([[A dark shadowy shape whose form resembles %s.]]):format(self.name),
		})

		m:removeTimedEffectsOnClone()
		m:unlearnTalentsOnClone()

		m.inc_damage.all = ((100 + (m.inc_damage.all or 0)) * t.getDam(self, t)) - 100

		game.zone:addEntity(game.level, m, "actor", x, y)
		game.level.map:particleEmitter(x, y, 1, "shadow")

		if game.party:hasMember(self) then
			game.party:addMember(m, {
				control="no",
				type="minion",
				title="Forgery of Haze",
				orders = {target=true},
			})
		end

		game:playSoundNear(self, "talents/spell_generic2")
		return true
	end,
	info = function(self, t)
		return ([[Through the shadows, you forge a temporary copy of yourself, existing for %d turns.
		The copy possesses your exact talents and stats, has %d%% life and deals %d%% damage.]]):
		format(t.getDuration(self, t), t.getHealth(self, t) * 100, t.getDam(self, t) * 100)
	end,
}

newTalent{
	name = "Frostdusk",
	type = {"spell/shades",4},
	require = spells_req_high4,
	points = 5,
	mode = "sustained",
	sustain_mana = 50,
	cooldown = 30,
	tactical = { BUFF = 2 },
	getDamageIncrease = function(self, t) return self:combatTalentScale(t, 2.5, 10) end,
	getResistPenalty = function(self, t) return self:combatTalentLimit(t, 100, 17, 50, true) end,  -- Limit to < 100%
	getAffinity = function(self, t) return self:combatTalentLimit(t, 100, 10, 50) end, -- Limit < 100%
	activate = function(self, t)
		game:playSoundNear(self, "talents/spell_generic")
		local ret = {
			dam = self:addTemporaryValue("inc_damage", {[DamageType.DARKNESS] = t.getDamageIncrease(self, t), [DamageType.COLD] = t.getDamageIncrease(self, t)}),
			resist = self:addTemporaryValue("resists_pen", {[DamageType.DARKNESS] = t.getResistPenalty(self, t)}),
			affinity = self:addTemporaryValue("damage_affinity", {[DamageType.DARKNESS] = t.getAffinity(self, t)}),
		}
		local particle
		if core.shader.active(4) then
			ret.particle1 = self:addParticles(Particles.new("shader_ring_rotating", 1, {rotation=0, radius=1.1, img="spinningwinds_black"}, {type="spinningwinds", ellipsoidalFactor={1,1}, time_factor=6000, noup=2.0, verticalIntensityAdjust=-3.0}))
			ret.particle1.toback = true
			ret.particle2 = self:addParticles(Particles.new("shader_ring_rotating", 1, {rotation=0, radius=1.1, img="spinningwinds_black"}, {type="spinningwinds", ellipsoidalFactor={1,1}, time_factor=6000, noup=1.0, verticalIntensityAdjust=-3.0}))
		else
			ret.particle1 = self:addParticles(Particles.new("ultrashield", 1, {rm=0, rM=0, gm=0, gM=0, bm=10, bM=100, am=70, aM=180, radius=0.4, density=60, life=14, instop=20}))
		end
		return ret
	end,
	deactivate = function(self, t, p)
		if p.particle1 then self:removeParticles(p.particle1) end
		if p.particle2 then self:removeParticles(p.particle2) end
		self:removeTemporaryValue("inc_damage", p.dam)
		self:removeTemporaryValue("resists_pen", p.resist)
		self:removeTemporaryValue("damage_affinity", p.affinity)
		return true
	end,
	info = function(self, t)
		local damageinc = t.getDamageIncrease(self, t)
		local ressistpen = t.getResistPenalty(self, t)
		local affinity = t.getAffinity(self, t)
		return ([[Surround yourself with Frostdusk, increasing all your darkness and cold damage by %0.1f%%, and ignoring %d%% of the darkness resistance of your targets.
		In addition, all darkness damage you take heals you for %d%% of the damage.]])
		:format(damageinc, ressistpen, affinity)
	end,
}
