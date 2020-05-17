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
	name = "Earthen Missiles",
	type = {"spell/stone",1},
	require = spells_req_high1,
	points = 5,
	random_ego = "attack",
	mana = 10,
	cooldown = 6,
	is_body_of_stone_affected = true,
	tactical = { ATTACK = { PHYSICAL = 1, cut = 1} },
	range = 10,
	direct_hit = true,
	reflectable = true,
	proj_speed = 20,
	requires_target = true,
	allow_for_arcane_combat = true,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 200) end,
	action = function(self, t)
		local tg = {type="bolt", range=self:getTalentRange(t), talent=t, display={particle="arrow", particle_args={tile="particles_images/earthen_missiles"}}}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local damage = t.getDamage(self, t)
		self:projectile(tg, x, y, DamageType.SPLIT_BLEED, self:spellCrit(damage), nil)
		game:playSoundNear(self, "talents/earth")
		--missile #2
		local tg2 = {type="bolt", range=self:getTalentRange(t), talent=t, display={particle="arrow", particle_args={tile="particles_images/earthen_missiles"}}}
		local x, y = self:getTarget(tg2)
		if x and y then
			self:projectile(tg2, x, y, DamageType.SPLIT_BLEED, self:spellCrit(damage), nil)
			game:playSoundNear(self, "talents/earth")
		end
		--missile #3 (Talent Level 5 Bonus Missile)
		if self:getTalentLevel(t) >= 5 then
			local tg3 = {type="bolt", range=self:getTalentRange(t), talent=t, display={particle="arrow", particle_args={tile="particles_images/earthen_missiles"}}}
			local x, y = self:getTarget(tg3)
			if x and y then
				self:projectile(tg3, x, y, DamageType.SPLIT_BLEED, self:spellCrit(damage), nil)
			end
		else end
		return true
	end,
	info = function(self, t)
		local count = 2
		if self:getTalentLevel(t) >= 5 then
			count = count + 1
		end
		local damage = t.getDamage(self, t)
		return ([[Conjures %d missile-shaped rocks that you target individually at any target or targets in range.  Each missile deals %0.2f physical damage, and an additional %0.2f bleeding damage every turn for 5 turns.
		At talent level 5, you can conjure one additional missile.
		The damage will increase with your Spellpower.]]):format(count,damDesc(self, DamageType.PHYSICAL, damage/2), damDesc(self, DamageType.PHYSICAL, damage/12))
	end,
}

newTalent{
	name = "Body of Stone",
	type = {"spell/stone",2},
	require = spells_req_high2,
	points = 5,
	mode = "sustained",
	sustain_mana = 70,
	cooldown = 12,
	no_energy = true,
	no_npc_use = true,
	tactical = { BUFF = 2 },
	getFireRes = function(self, t) return self:combatTalentSpellDamage(t, 5, 80) end,
	getLightningRes = function(self, t) return self:combatTalentSpellDamage(t, 5, 50) end,
	getAcidRes = function(self, t) return self:combatTalentSpellDamage(t, 5, 20) end,
	getStunRes = function(self, t) return self:getTalentLevel(t)/10 end,
	getCooldownReduction = function(self, t) return self:combatTalentLimit(t, 50, 16.7, 35.7) end,  -- Limit to < 50%
	activate = function(self, t)
		local cdr = t.getCooldownReduction(self, t)
		game:playSoundNear(self, "talents/earth")

		local cd_recution = {}
		for cdtid, _ in pairs(self.talents) do
			local cdt = self:getTalentFromId(cdtid)
			if cdt.is_body_of_stone_affected then
				cd_recution[cdtid] = math.floor(cdr*(self:getTalentCooldown(cdt) or 0)/100)
			end
		end

		return {
			particle = self:addParticles(Particles.new("stone_skin", 1)),
			move = self:addTemporaryValue("never_move", 1),
			stun = self:addTemporaryValue("stun_immune", t.getStunRes(self, t)),
			cdred = self:addTemporaryValue("talent_cd_reduction", cd_recution),
			
			res = self:addTemporaryValue("resists", {
				[DamageType.FIRE] = t.getFireRes(self, t),
				[DamageType.LIGHTNING] = t.getLightningRes(self, t),
				[DamageType.ACID] = t.getAcidRes(self, t),
			}),
		}
	end,
	deactivate = function(self, t, p)
		self:removeParticles(p.particle)
		self:removeTemporaryValue("never_move", p.move)
		self:removeTemporaryValue("stun_immune", p.stun)
		self:removeTemporaryValue("talent_cd_reduction", p.cdred)
		self:removeTemporaryValue("resists", p.res)
		return true
	end,
	info = function(self, t)
		local fireres = t.getFireRes(self, t)
		local lightningres = t.getLightningRes(self, t)
		local acidres = t.getAcidRes(self, t)
		local cooldownred = t.getCooldownReduction(self, t)
		local stunres = t.getStunRes(self, t)
		return ([[You root yourself into the earth, and transform your flesh into stone.  While this spell is sustained, you may not move, and any forced movement will end the effect.
		Your stone form and your affinity with the earth while the spell is active has the following effects:
		* Reduces the cooldown of Earthen Missiles, Pulverizing Auger, Earthquake, and Mudslide by %d%%.
		* Grants %d%% Fire Resistance, %d%% Lightning Resistance, %d%% Acid Resistance, and %d%% Stun Resistance.
		Resistances scale with your Spellpower.]])
		:format(cooldownred, fireres, lightningres, acidres, stunres*100)
	end,
}

newTalent{
	name = "Earthquake",
	type = {"spell/stone",3},
	require = spells_req_high3,
	points = 5,
	random_ego = "attack",
	mana = 50,
	cooldown = 30,
	is_body_of_stone_affected = true,
	tactical = { ATTACKAREA = { PHYSICAL = 2 }, DISABLE = { stun = 3 } },
	range = 10,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 2.5, 4.5)) end,
	direct_hit = true,
	requires_target = true,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t)}
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 15, 80) end,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 4, 8)) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, _, _, x, y = self:canProject(tg, x, y)
		-- Add a lasting map effect
		game.level.map:addEffect(self,
			x, y, t.getDuration(self, t),
			DamageType.PHYSICAL_STUN, self:spellCrit(t.getDamage(self, t)),
			self:getTalentRadius(t),
			5, nil,
			{type="quake"},
			nil, self:spellFriendlyFire()
		)

		game:playSoundNear(self, "talents/earth")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local radius = self:getTalentRadius(t)
		local duration = t.getDuration(self, t)
		return ([[Causes a violent earthquake that deals %0.2f physical damage in a radius of %d each turn for %d turns, and potentially stuns any and all creatures it affects.
		The damage will increase with your Spellpower.]]):
		format(damDesc(self, DamageType.PHYSICAL, damage), radius, duration)
	end,
}

newTalent{
	name = "Crystalline Focus",
	type = {"spell/stone",4},
	require = spells_req_high4,
	points = 5,
	mode = "sustained",
	sustain_mana = 50,
	cooldown = 30,
	tactical = { BUFF = 2 },
	getPhysicalDamageIncrease = function(self, t) return self:combatTalentScale(t, 2.5, 10) end,
	getResistPenalty = function(self, t) return self:combatTalentLimit(t, 60, 17, 50, true) end,  -- Limit to < 60%
	getSaves = function(self, t) return self:getTalentLevel(t) * 5 end,
	activate = function(self, t)
		game:playSoundNear(self, "talents/earth")
		local particle
		if core.shader.active(4) then
			particle = self:addParticles(Particles.new("shader_ring_rotating", 1, {rotation=-0.01, radius=1.1}, {type="stone", hide_center=1, xy={self.x, self.y}}))
		else
			particle = self:addParticles(Particles.new("crystalline_focus", 1))
		end
		return {
			dam = self:addTemporaryValue("inc_damage", {[DamageType.PHYSICAL] = t.getPhysicalDamageIncrease(self, t)}),
			resist = self:addTemporaryValue("resists_pen", {[DamageType.PHYSICAL] = t.getResistPenalty(self, t)}),
			psave = self:addTemporaryValue("combat_physresist", t.getSaves(self, t)),
			ssave = self:addTemporaryValue("combat_spellresist", t.getSaves(self, t)),
			particle = particle,
		}
	end,
	deactivate = function(self, t, p)
		self:removeParticles(p.particle)
		self:removeTemporaryValue("inc_damage", p.dam)
		self:removeTemporaryValue("resists_pen", p.resist)
		self:removeTemporaryValue("combat_physresist", p.psave)
		self:removeTemporaryValue("combat_spellresist", p.ssave)
		return true
	end,
	info = function(self, t)
		local damageinc = t.getPhysicalDamageIncrease(self, t)
		local ressistpen = t.getResistPenalty(self, t)
		local saves = t.getSaves(self, t)
		return ([[Concentrate on maintaining a Crystalline Focus, increasing all your physical damage by %0.1f%% and ignoring %d%% physical resistance of your targets.
		Also raises your physical and magical saves by %d.]])
		:format(damageinc, ressistpen, saves)
	end,
}
