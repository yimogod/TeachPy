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
	name = "Freeze",
	type = {"spell/ice", 1},
	require = spells_req_high1,
	points = 5,
	random_ego = "attack",
	mana = 14,
	cooldown = 8,
	tactical = { ATTACK = { COLD = 2.5 }, DISABLE = { stun = 1.5 } },
	range = 10,
	direct_hit = true,
	reflectable = true,
	requires_target = true,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 30, 300) end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 3, 7)) end,
	target = function(self, t)
		if necroEssenceDead(self, true) then
			return {type="ball", radius=2, range=self:getTalentRange(t), talent=t}
		else
			return {type="hit", range=self:getTalentRange(t), talent=t}
		end
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		if not x or not y then return nil end

		if necroEssenceDead(self, true) then
			self:projectApply(tg, x, y, Map.ACTOR, function(target) target:setEffect(target.EFF_WET, t.getDuration(self, t), {apply_power=self:combatSpellpower()}) end)
			local empower = necroEssenceDead(self)
			if empower then empower() end
		end

		local dam = self:spellCrit(t.getDamage(self, t))
		self:project(tg, x, y, DamageType.COLD, dam, {type="freeze"})
		self:project(tg, x, y, DamageType.FREEZE, {dur=t.getDuration(self, t), hp=70 + dam * 1.5})

		tg.type = "hit"
		self:projectApply(tg, x, y, Map.ACTOR, function(target)
			if self:reactionToward(target) >= 0 then
				game:onTickEnd(function() self:alterTalentCoolingdown(t.id, -math.floor((self.talents_cd[t.id] or 0) * 0.33)) end)
			end
		end)

		game:playSoundNear(self, "talents/water")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		return ([[Condenses ambient water on a target, freezing it for %d turns and damaging it for %0.2f.
		If this is used on a friendly target the cooldown is reduced by 33%%.%s
		The damage will increase with your Spellpower.]]):format(t.getDuration(self, t), damDesc(self, DamageType.COLD, damage), necroEssenceDead(self, true) and "\nAffects all creatures in radius 2." or "")
	end,
}

newTalent{
	name = "Frozen Ground",
	type = {"spell/ice",2},
	require = spells_req_high2,
	points = 5,
	mana = 25,
	cooldown = 10,
	requires_target = true,
	tactical = { ATTACKAREA = { COLD = 2 }, DISABLE = { stun = 1 } },
	range = 0,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 2, 6)) end,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), selffire=false, talent=t}
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 10, 280) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local grids = self:project(tg, self.x, self.y, DamageType.COLDNEVERMOVE, {shatter_reduce=2, dur=4, dam=self:spellCrit(t.getDamage(self, t))})
--		game.level.map:particleEmitter(self.x, self.y, tg.radius, "ball_ice", {radius=tg.radius})
		game.level.map:particleEmitter(self.x, self.y, tg.radius, "circle", {oversize=1.1, a=255, limit_life=16, grow=true, speed=0, img="ice_nova", radius=tg.radius})
		game:playSoundNear(self, "talents/ice")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local radius = self:getTalentRadius(t)
		return ([[Blast a wave of cold all around you with a radius of %d, doing %0.2f cold damage and freezing creatures to the ground for 4 turns.
		Affected creatures can still act, but cannot move.
		For each affected creature that is also wet the cooldown of Shatter decreases by 2.
		The damage will increase with your Spellpower.]]):format(radius, damDesc(self, DamageType.COLD, damage))
	end,
}

newTalent{
	name = "Shatter",
	type = {"spell/ice",3},
	require = spells_req_high3,
	points = 5,
	mana = 25,
	cooldown = 15,
	tactical = { ATTACKAREA = { COLD = function(self, t, target) if target:attr("frozen") then return 2 end return 0 end } },
	range = 10,
	requires_target = true,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 10, 320) end,
	getTargetCount = function(self, t) return math.ceil(self:getTalentLevel(t) + 2) end,
	action = function(self, t)
		if self:hasEffect(self.EFF_FROZEN) then self:removeEffect(self.EFF_FROZEN) end

		local max = t.getTargetCount(self, t)
		for i, act in ipairs(self.fov.actors_dist) do
			if self:reactionToward(act) < 0 then
				if act:attr("frozen") then
					-- Instakill critters
					if act.rank <= 1 then
						if act:canBe("instakill") then
							game.logSeen(act, "%s shatters!", act.name:capitalize())
							act:die(self)
						end
					end

					if not act.dead then
						act:setEffect(act.EFF_WET, 5, {apply_power=self:combatSpellpower()})

						local add_crit = 0
						if act.rank == 2 then add_crit = 50
						elseif act.rank >= 3 then add_crit = 25 end
						local tg = {type="hit", friendlyfire=false, talent=t}
						local grids = self:project(tg, act.x, act.y, DamageType.COLD, self:spellCrit(t.getDamage(self, t), add_crit))
						game.level.map:particleEmitter(act.x, act.y, tg.radius, "ball_ice", {radius=1})
					end

					max = max - 1
					if max <= 0 then break end
				end
			end
		end
		game:playSoundNear(self, "talents/ice")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local targetcount = t.getTargetCount(self, t)
		return ([[Shatter all frozen targets in your line of sight, doing %0.2f cold damage.
		Depending on the target's rank, there will also be an additional effect:
		* Critters will be instantly killed
		* +50%% critical chance against Normal rank
		* +25%% critical chance against Elites or Bosses
		All affected foes will get the wet effect.
		At most, it will affect %d foes.
		If you are yourself Frozen, it will instantly be destroyed.
		The damage will increase with your Spellpower.]]):
		format(damDesc(self, DamageType.COLD, damage), targetcount)
	end,
}

newTalent{
	name = "Uttercold",
	type = {"spell/ice",4},
	require = spells_req_high4,
	points = 5,
	mode = "sustained",
	sustain_mana = 50,
	cooldown = 30,
	tactical = { BUFF = 2 },
	getColdDamageIncrease = function(self, t) return self:combatTalentScale(t, 2.5, 10) end,
	getResistPenalty = function(self, t) return self:combatTalentLimit(t, 60, 17, 50) end, -- Limit < 60
	getPierce = function(self, t) return math.min(100, self:getTalentLevelRaw(t) * 20) end, 
	activate = function(self, t)
		game:playSoundNear(self, "talents/ice")

		local ret = {
			dam = self:addTemporaryValue("inc_damage", {[DamageType.COLD] = t.getColdDamageIncrease(self, t)}),
			resist = self:addTemporaryValue("resists_pen", {[DamageType.COLD] = t.getResistPenalty(self, t)}),
			pierce = self:addTemporaryValue("iceblock_pierce", t.getPierce(self, t)),
		}
		local particle
		if core.shader.active(4) then
			ret.particle1 = self:addParticles(Particles.new("shader_ring_rotating", 1, {rotation=0, radius=1.1, img="coldgeneric"}, {type="circular_flames", ellipsoidalFactor={1,2}, time_factor=22000, noup=2.0, verticalIntensityAdjust=-3.0}))
			ret.particle1.toback = true
			ret.particle2 = self:addParticles(Particles.new("shader_ring_rotating", 1, {rotation=0, radius=1.1, img="coldgeneric"}, {type="circular_flames", ellipsoidalFactor={1,2}, time_factor=22000, noup=1.0, verticalIntensityAdjust=-3.0}))
		else
			ret.particle1 = self:addParticles(Particles.new("uttercold", 1))
		end
		return ret
	end,
	deactivate = function(self, t, p)
		if p.particle1 then self:removeParticles(p.particle1) end
		if p.particle2 then self:removeParticles(p.particle2) end
		self:removeTemporaryValue("inc_damage", p.dam)
		self:removeTemporaryValue("resists_pen", p.resist)
		self:removeTemporaryValue("iceblock_pierce", p.pierce)
		return true
	end,
	info = function(self, t)
		local damageinc = t.getColdDamageIncrease(self, t)
		local ressistpen = t.getResistPenalty(self, t)
		local pierce = t.getPierce(self, t)
		return ([[Surround yourself with Uttercold, increasing all your cold damage by %0.1f%% and ignoring %d%% cold resistance of your targets
		In addition you pierce through iceblocks easily, reducing damage absorbed from your attacks by iceblocks by %d%%.]])
		:format(damageinc, ressistpen, pierce)
	end,
}
