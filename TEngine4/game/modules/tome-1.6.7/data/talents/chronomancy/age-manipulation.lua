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
	name = "Turn Back the Clock",
	type = {"chronomancy/age-manipulation", 1},
	require = chrono_req1,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 4,
	tactical = { ATTACK = {TEMPORAL = 2}, DISABLE = 2 },
	range = 10,
	reflectable = true,
	requires_target = true,
	proj_speed = 5,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 15, 150, getParadoxSpellpower(self, t)) end,
	getDamageStat = function(self, t) return 2 + math.ceil(t.getDamage(self, t) / 15) end,
	action = function(self, t)
		local tg = {type="bolt", range=self:getTalentRange(t), talent=t, display={particle="temporal_bolt"}}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		
		self:projectile(tg, x, y, DamageType.CLOCK, {dam=self:spellCrit(t.getDamage(self, t)), stat=t.getDamageStat(self, t), apply=getParadoxSpellpower(self, t)})
		game:playSoundNear(self, "talents/spell_generic2")

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local damagestat = t.getDamageStat(self, t)
		return ([[Projects a bolt of temporal energy that deals %0.2f temporal damage, and reduces the targets three highest stats by %d for 3 turns.
		The damage dealt will scale with your Spellpower.]]):format(damDesc(self, DamageType.TEMPORAL, damage), damagestat)
	end,
}

newTalent{
	name = "Temporal Fugue Old",
	type = {"chronomancy/age-manipulation", 2},
	require = chrono_req2,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 30) end,
	cooldown = 14,
	tactical = { ATTACKAREA = 2, DISABLE= 2 },
	range = 0,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 4.5, 6.5)) end,
	requires_target = true,
	direct_hit = true,
	target = function(self, t)
		return {type="cone", range=self:getTalentRange(t), radius=self:getTalentRadius(t), selffire=false, talent=t}
	end,
	getConfuseDuration = function(self, t) return math.floor(self:combatScale((self:getTalentLevel(t) + 2), 2, 2, 7, 7)) end,
	getConfuseEfficency = function(self, t) return math.min(50, self:getTalentLevelRaw(t) * 10) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end

		self:project(tg, x, y, DamageType.CONFUSION, {
			dur = t.getConfuseDuration(self, t),
			dam = t.getConfuseEfficency(self, t)
		})
		game.level.map:particleEmitter(self.x, self.y, tg.radius, "temporal_breath", {radius=tg.radius, tx=x-self.x, ty=y-self.y})
		game:playSoundNear(self, "talents/tidalwave")
		return true
	end,
	info = function(self, t)
		local duration = t.getConfuseDuration(self, t)
		local radius = self:getTalentRadius(t)
		return ([[Reverts the minds of all creatures in a radius %d cone to an infantile state, in effect confusing them (%d%% to act randomly) for %d turns.]]):
		format(radius, t.getConfuseEfficency(self, t), duration)
	end,
}

newTalent{
	name = "Ashes to Ashes",
	type = {"chronomancy/age-manipulation",3},
	require = chrono_req3,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 40) end,
	cooldown = 14,
	tactical = { ATTACKAREA = {TEMPORAL = 2} },
	range = 0,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 3.25, 4.25)) end,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), selffire=false}
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 8, 135, getParadoxSpellpower(self, t)) end,
	getDuration = function(self, t) return 5 + math.ceil(self:getTalentLevel(t)) end,
	direct_hit = true,
	requires_target = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		game.level.map:addEffect(self,
			self.x, self.y, t.getDuration(self, t),
			DamageType.WASTING, t.getDamage(self, t),
			tg.radius,
			5, nil,
			engine.MapEffect.new{color_br=180, color_bg=100, color_bb=255, effect_shader="shader_images/magic_effect.png"},
			function(e)
				e.x = e.src.x
				e.y = e.src.y
				return true
			end,
			tg.selffire
		)
		game:playSoundNear(self, "talents/cloud")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local duration = t.getDuration(self, t)
		local radius = self:getTalentRadius(t)
		return ([[You surround yourself with a radius %d distortion of time, which deals %0.2f stacking temporal damage over 3 turns to all other creatures.  The effect lasts %d turns.
		The damage dealt will scale with your Spellpower.]]):format(radius, damDesc(self, DamageType.TEMPORAL, damage), duration)
	end,
}

newTalent{
	name = "Body Reversion",
	type = {"chronomancy/age-manipulation", 4},
	require = chrono_req4,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 20) end,
	cooldown = 10,
	tactical = { HEAL = 2, CURE = function(self, t, target)
		local nb = 0
		for eff_id, p in pairs(self.tmp) do
			local e = self.tempeffect_def[eff_id]
			if e.status == "detrimental" and e.type == "physical" then
				nb = nb + 1
			end
		end
		return nb
	end },
	is_heal = true,
	getHeal = function(self, t) return self:combatTalentSpellDamage(t, 40, 440, getParadoxSpellpower(self, t)) end,
	getRemoveCount = function(self, t) return math.floor(self:combatTalentScale(t, 1, 5, "log")) end,
	action = function(self, t)
		self:attr("allow_on_heal", 1)
		self:heal(self:spellCrit(t.getHeal(self, t)), self)
		if core.shader.active(4) then
			self:addParticles(Particles.new("shader_shield_temp", 1, {toback=true ,size_factor=1.5, y=-0.3, img="healparadox", life=25}, {type="healing", time_factor=3000, beamsCount=15, noup=2.0, beamColor1={0xb6/255, 0xde/255, 0xf3/255, 1}, beamColor2={0x5c/255, 0xb2/255, 0xc2/255, 1}}))
			self:addParticles(Particles.new("shader_shield_temp", 1, {toback=false,size_factor=1.5, y=-0.3, img="healparadox", life=25}, {type="healing", time_factor=3000, beamsCount=15, noup=1.0, beamColor1={0xb6/255, 0xde/255, 0xf3/255, 1}, beamColor2={0x5c/255, 0xb2/255, 0xc2/255, 1}}))
		end
		self:attr("allow_on_heal", -1)

		local target = self

		local effs = {}
		-- Go through all spell effects
		for eff_id, p in pairs(target.tmp) do
			local e = target.tempeffect_def[eff_id]
			if e.type == "physical" then
				effs[#effs+1] = {"effect", eff_id}
			end
		end

		for i = 1, t.getRemoveCount(self, t) do
			if #effs == 0 then break end
			local eff = rng.tableRemove(effs)

			if eff[1] == "effect" then
				target:removeEffect(eff[2])
			end
		end
		game:playSoundNear(self, "talents/heal")
		return true
	end,
	info = function(self, t)
		local heal = t.getHeal(self, t)
		local count = t.getRemoveCount(self, t)
		return ([[You revert your body to a previous state, healing yourself for %0.2f life and removing %d physical status effects (both good and bad).
		The amount of life healed will scale with your Spellpower.]]):
		format(heal, count)
	end,
}
