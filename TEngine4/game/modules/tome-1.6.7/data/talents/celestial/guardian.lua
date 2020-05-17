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

-- Core offensive scaler for 1H/S as we have no Shield Mastery
-- Core defense roughly to be compared with Absorption Strike, but in truth 1H/S gets a lot of its defense from cooldown management+Suncloak/etc
-- Its important that this can crit but its also spamming the combat log, unsure of solution
-- Flag if its a crit once for each turn then calculate damage manually?
newTalent{
	name = "Shield of Light",
	type = {"celestial/guardian", 1},
	mode = "sustained",
	require = divi_req_high1,
	points = 5,
	cooldown = 10,
	sustain_positive = 10,
	tactical = { BUFF = 2 },
	range = 10,
	getHeal = function(self, t) return self:combatTalentSpellDamage(t, 5, 22) end,
	getShieldDamage = function(self, t) return self:combatTalentWeaponDamage(t, 0.1, 0.8, self:getTalentLevel(self.T_SHIELD_EXPERTISE)) end,
	on_pre_use = function(self, t) return self:hasShield() and true or false end,
	activate = function(self, t)
		game:playSoundNear(self, "talents/spell_generic2")
		local ret = {
		}
		return ret
	end,
	deactivate = function(self, t, p)
		return true
	end,
	callbackOnMeleeAttack = function(self, t, target, hitted, crit, weapon, damtype, mult, dam)
		local shield = self:hasShield()
		if hitted and not target.dead and shield and not self.turn_procs.shield_of_light then
			self.turn_procs.shield_of_light = true
			self:attackTargetWith(target, shield.special_combat, DamageType.LIGHT, t.getShieldDamage(self, t))
		end
	end,
	info = function(self, t)
		local heal = t.getHeal(self, t)
		return ([[Infuse your shield with light, healing you for %0.2f each time you take damage at the expense of up to 2 positive energy.
		If you do not have any positive energy, the effect will not trigger.
		Additionally, once per turn successful melee attacks will trigger a bonus attack with your shield dealing %d%% light damage.
		The healing done will increase with your Spellpower.]]):
		format(heal, t.getShieldDamage(self, t)*100)
	end,
}

-- Shield of Light means 1H/Shield builds actually care about positive energy, so we can give this a meaningful cost and power
-- Spamming Crusade+whatever is always more energy efficient than this
newTalent{
	name = "Brandish",
	type = {"celestial/guardian", 2},
	require = divi_req_high2,
	points = 5,
	cooldown = 8,
	positive = 15,
	tactical = { ATTACK = {LIGHT = 2} },
	requires_target = true,
	range = 1,
	is_melee = true,
	getWeaponDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1, 1.8) end,
	getShieldDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1, 1.8, self:getTalentLevel(self.T_SHIELD_EXPERTISE)) end,
	getLightDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 300) end,
	radius = function(self, t) return math.min(math.floor(self:combatTalentScale(t, 2.5, 4.5), 8)) end,
	action = function(self, t)
		local shield, shield_combat = self:hasShield()
		if not shield then
			game.logPlayer(self, "You cannot use Brandish without a shield!")
			return nil
		end

		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not target then return nil end
		if not self:canProject(tg, x, y) then return nil end

		-- First attack with weapon
		self:attackTarget(target, nil, t.getWeaponDamage(self, t), true)
		-- Second attack with shield
		local speed, hit = self:attackTargetWith(target, shield_combat, nil, t.getShieldDamage(self, t))

		-- Light Burst
		if hit then
			local tg = {type="ball", range=1, selffire=true, radius=self:getTalentRadius(t), talent=t}
			self:project(tg, x, y, DamageType.LITE, 1)
			tg.selffire = false
			local grids = self:project(tg, x, y, DamageType.LIGHT, self:spellCrit(t.getLightDamage(self, t)))
			game.level.map:particleEmitter(x, y, tg.radius, "sunburst", {radius=tg.radius, grids=grids, tx=x, ty=y, max_alpha=80})
			game:playSoundNear(self, "talents/flame")
		end

		return true
	end,
	info = function(self, t)
		local weapondamage = t.getWeaponDamage(self, t)
		local shielddamage = t.getShieldDamage(self, t)
		local lightdamage = t.getLightDamage(self, t)
		local radius = self:getTalentRadius(t)
		return ([[Hits the target with your weapon doing %d%% damage, and with a shield strike doing %d%% damage. If the shield strike connects, your shield will explode in a burst of light that inflicts %0.2f light damage on all targets except yourself within radius %d of the target, and light up all tiles in that radius.
		The light damage will increase with your Spellpower.]]):
		format(100 * weapondamage, 100 * shielddamage, damDesc(self, DamageType.LIGHT, lightdamage), radius)
	end,
}

newTalent{
	name = "Retribution",
	type = {"celestial/guardian", 3},
	require = divi_req_high3, no_sustain_autoreset = true,
	points = 5,
	mode = "sustained",
	sustain_positive = 20,
	cooldown = 10,
	range = function(self, t) return math.floor(self:combatTalentScale(t, 2, 6)) end,
	tactical = { DEFEND = 2 },
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 40, 400) end,
	iconOverlay = function(self, t, p)
		local val = self.retribution_absorb or 0
		if val <= 0 then return "" end
		local fnt = "buff_font_small"
		if val >= 1000 then fnt = "buff_font_smaller" end
		return "#RED#"..tostring(math.ceil(val)).."#LAST#", fnt
	end,
	activate = function(self, t)
		local shield = self:hasShield()
		if not shield then
			game.logPlayer(self, "You cannot use Retribution without a shield!")
			return nil
		end
		local power = t.getDamage(self, t)
		self.retribution_absorb = power
		self.retribution_strike = power
		game:playSoundNear(self, "talents/generic")
		return {
			shield = self:addTemporaryValue("retribution", power),
		}
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("retribution", p.shield)
		self.retribution_absorb = nil
		self.retribution_strike = nil
		return true
	end,
	callbackOnRest = function(self, t)  -- Make sure we've actually started resting/running before disabling the sustain
		if self.resting.cnt and self.resting.cnt <= 0 then return end
		self.retribution_absorb = self.retribution		
	end,
	callbackOnRun = function(self, t)
		if self.running.cnt and self.running.cnt <= 0 then return end
		self.retribution_absorb = self.retribution		
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local absorb_string = ""
		if self.retribution_absorb and self.retribution_strike then
			absorb_string = ([[#RED#Absorb Remaining: %d]]):format(self.retribution_absorb)
		end

		return ([[Retribution negates half of all damage you take while it is active. Once Retribution has negated %0.2f damage, your shield will explode in a burst of light, inflicting damage equal to the amount negated in a radius of %d and deactivating the talent.
		The amount absorbed will increase with your Spellpower.
		%s]]):
		format(damage, self:getTalentRange(t), absorb_string)
	end,
}

-- Moderate damage but very short CD
-- Spamming this on cooldown keeps positive energy up and gives a lot of cooldown management
newTalent{
	name = "Crusade",
	type = {"celestial/guardian", 4},
	require = divi_req_high4,
	random_ego = "attack",
	points = 5,
	cooldown = 5,
	positive = -20,
	tactical = { ATTACK = {LIGHT = 2} },
	range = 1,
	requires_target = true,
	is_melee = true,
	target = function(self, t) return {type = 'hit', range = self:getTalentRange(t)} end,
	getWeaponDamage = function(self, t) return self:combatTalentWeaponDamage(t, 0.3, 1.2) end,
	getShieldDamage = function(self, t) return self:combatTalentWeaponDamage(t, 0.3, 1.2, self:getTalentLevel(self.T_SHIELD_EXPERTISE)) end,
	getCooldownReduction = function(self, t) return math.ceil(self:combatTalentScale(t, 1, 3)) end,
	getDebuff = function(self, t) return 1 end,
	action = function(self, t)
		local shield, shield_combat = self:hasShield()
		if not shield then
			game.logPlayer(self, "You cannot use Crusade without a shield!")
			return nil
		end

		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target then return nil end
		if not self:canProject(tg, x, y) then return nil end

		local hit = self:attackTarget(target, DamageType.LIGHT, t.getWeaponDamage(self, t), true)
		if hit then self:talentCooldownFilter(nil, 1, t.getCooldownReduction(self, t), true) end

		local hit2 = self:attackTargetWith(target, shield_combat, DamageType.LIGHT, t.getShieldDamage(self, t))
		if hit2 then self:removeEffectsFilter({status = "detrimental"}, t.getDebuff(self, t)) end

		return true
	end,
	info = function(self, t)
		local weapon = t.getWeaponDamage(self, t)*100
		local shield = t.getShieldDamage(self, t)*100
		local cooldown = t.getCooldownReduction(self, t)
		local cleanse = t.getDebuff(self, t)
		return ([[You demonstrate your dedication to the light with a measured attack striking once with your weapon for %d%% Light damage and once with your shield for %d%% Light damage.
			If the first strike connects %d random talent cooldowns are reduced by 1.
			If the second strike connects you are cleansed of %d debuffs.]]):
		format(weapon, shield, cooldown, cleanse)
	end,
}
