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
	name = "Bow Mastery",
	type = {"technique/archery-bow", 1},
	points = 5,
	require = { stat = { dex=function(level) return 12 + level * 6 end }, },
	mode = "passive",
	getDamage = function(self, t) return 30 end,
	getPercentInc = function(self, t) return math.sqrt(self:getTalentLevel(t) / 5) / 1.5 end,
	ammo_mastery_reload = function(self, t)
		return math.floor(self:combatTalentScale(t, 0, 2.7, "log"))
	end,
	passives = function(self, t, p)
		self:talentTemporaryValue(p, 'ammo_mastery_reload', t.ammo_mastery_reload(self, t))
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local inc = t.getPercentInc(self, t)
		local reloads = t.ammo_mastery_reload(self, t)
		return ([[Increases weapon damage by %d%% and physical power by 30 when using bows.
		Also, increases your reload rate by %d.]]):format(inc * 100, reloads)
	end,
}

newTalent{
	name = "Piercing Arrow",
	type = {"technique/archery-bow", 2},
	no_energy = "fake",
	points = 5,
	cooldown = 8,
	stamina = 15,
	require = techs_dex_req2,
	range = archery_range,
	tactical = { ATTACK = { weapon = 2 } },
	requires_target = true,
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent, "bow") end,
	action = function(self, t)
		if not self:hasArcheryWeapon("bow") then game.logPlayer(self, "You must wield a bow!") return nil end

		local targets = self:archeryAcquireTargets({type="beam"}, {one_shot=true})
		if not targets then return end
		self:archeryShoot(targets, t, {type="beam"}, {mult=self:combatTalentWeaponDamage(t, 1, 1.5), apr=1000})
		return true
	end,
	info = function(self, t)
		return ([[You fire an arrow that cuts right through anything, piercing multiple targets if possible with nigh infinite armor penetration, doing %d%% damage.]]):format(100 * self:combatTalentWeaponDamage(t, 1, 1.5))
	end,
}

newTalent{
	name = "Dual Arrows",
	type = {"technique/archery-bow", 3},
	no_energy = "fake",
	points = 5,
	cooldown = 8,
	require = techs_dex_req3,
	range = archery_range,
	radius = 1,
	tactical = { ATTACKAREA = { weapon = 1 } },
	requires_target = true,
	target = function(self, t)
		return {type="ball", radius=self:getTalentRadius(t), range=self:getTalentRange(t)}
	end,
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent, "bow") end,
	action = function(self, t)
		if not self:hasArcheryWeapon("bow") then game.logPlayer(self, "You must wield a bow!") return nil end

		local tg = self:getTalentTarget(t)
		local targets = self:archeryAcquireTargets(tg, {limit_shots=2})
		if not targets then return end
		self:archeryShoot(targets, t, nil, {mult=self:combatTalentWeaponDamage(t, 1.2, 1.9)})
		return true
	end,
	info = function(self, t)
		return ([[You fire two arrows at your target, hitting it and a nearby foe if possible, doing %d%% damage
		This talent does not use any stamina.]]):format(100 * self:combatTalentWeaponDamage(t, 1.2, 1.9))
	end,
}

newTalent{
	name = "Volley of Arrows",
	type = {"technique/archery-bow", 4},
	no_energy = "fake",
	points = 5,
	cooldown = 12,
	stamina = 35,
	require = techs_dex_req4,
	range = archery_range,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 2.3, 3.7)) end,
	direct_hit = true,
	tactical = { ATTACKAREA = { weapon = 2 } },
	requires_target = true,
	target = function(self, t)
		return {type="ball", radius=self:getTalentRadius(t), range=self:getTalentRange(t), selffire=false}
	end,
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent, "bow") end,
	action = function(self, t)
		if not self:hasArcheryWeapon("bow") then game.logPlayer(self, "You must wield a bow!") return nil end

		local tg = self:getTalentTarget(t)
		local targets = self:archeryAcquireTargets(tg)
		if not targets then return end
		self:archeryShoot(targets, t, {type="bolt", selffire=false}, {mult=self:combatTalentWeaponDamage(t, 0.6, 1.3)})
		return true
	end,
	info = function(self, t)
		return ([[You fire multiple arrows at an area of %d radius, doing %d%% damage with each arrow.]])
		:format(self:getTalentRadius(t), 100 * self:combatTalentWeaponDamage(t, 0.6, 1.3))
	end,
}
