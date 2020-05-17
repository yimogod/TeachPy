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

uberTalent{
	name = "Giant Leap",
	mode = "activated",
	require = { special={desc="Have dealt over 50000 damage with any weapon or unarmed", fct=function(self) return
		self.damage_log and (
			(self.damage_log.weapon.twohanded and self.damage_log.weapon.twohanded >= 50000) or
			(self.damage_log.weapon.shield and self.damage_log.weapon.shield >= 50000) or
			(self.damage_log.weapon.dualwield and self.damage_log.weapon.dualwield >= 50000) or
			(self.damage_log.weapon.other and self.damage_log.weapon.other >= 50000)
		)
	end} },
	cooldown = 20,
	radius = 1,
	range = 10,
	is_melee = true,
	requires_target = true,
	no_energy = true,
	tactical = { CLOSEIN = 2, ATTACKAREA = { weapon = 2 }, DISABLE = { stun = 1 } },
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), selffire=false, radius=self:getTalentRadius(t)}
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)

		if game.level.map(x, y, Map.ACTOR) then
			x, y = util.findFreeGrid(x, y, 1, true, {[Map.ACTOR]=true})
			if not x then return end
		end

		if game.level.map:checkAllEntities(x, y, "block_move") then return end

		local ox, oy = self.x, self.y
		self:move(x, y, true)
		if config.settings.tome.smooth_move > 0 then
			self:resetMoveAnim()
			self:setMoveAnim(ox, oy, 8, 5)
		end

		self:removeEffectsFilter({subtype={stun=true, daze=true, pin=true, pinned=true, pinning=true}}, 50)

		self:project(tg, self.x, self.y, function(px, py, tg, self)
			local target = game.level.map(px, py, Map.ACTOR)
			if target and target ~= self then
				local hit = self:attackTarget(target, nil, 2, true)
				if hit and target:canBe("stun") then
					target:setEffect(target.EFF_DAZED, 3, {})
				end
			end
		end)

		return true
	end,
	info = function(self, t)
		return ([[You accurately jump to the target and deal 200%% weapon damage to all foes within radius 1 on impact as well as dazing them for 3 turns.
		When you jump you free yourself from any stun, daze and pinning effects.]])
		:format()
	end,
}

uberTalent{
	name = "You Shall Be My Weapon!", short_name="TITAN_S_SMASH", image = "talents/titan_s_smash.png",
	mode = "activated",
	require = { special={desc="Be of size category 'big' or larger. This is also required to use it.", fct=function(self) return self.size_category and self.size_category >= 4 end} },
	requires_target = true,
	tactical = { ATTACK = 3, DISABLE = {stun = 1}, ESCAPE = {knockback = 1} },
	on_pre_use = function(self, t) return self.size_category and self.size_category >= 4 end,
	cooldown = 10,
	is_melee = true,
	range = 1,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end

		local hit = self:attackTarget(target, nil, 3.5 + 0.8 * (self.size_category - 4), true)

		if target:attr("dead") or not hit then return true end

		local dx, dy = (target.x - self.x), (target.y - self.y)
		local dir = util.coordToDir(dx, dy, 0)
		local sides = util.dirSides(dir, 0)

		target:knockback(self.x, self.y, 5, function(t2)
			if sides then
				local d = rng.chance(2) and sides.hard_left or sides.hard_right
				local sx, sy = util.coordAddDir(t2.x, t2.y, d)
				local ox, oy = t2.x, t2.y
				t2:knockback(sx, sy, 2, function(t3) return true end)
			end
			if t2:canBe("stun") then t2:setEffect(t2.EFF_STUNNED, 3, {}) end
		end)
		if target:canBe("stun") then target:setEffect(target.EFF_STUNNED, 3, {}) end
		return true
	end,
	info = function(self, t)
		return ([[You deal a massive blow to your foe, smashing it for 350%% weapon damage, knocking it back 5 tiles, and knocking aside all foes in its path.
		All targets affected are stunned for 3 turns.
		For each size category over 'big' you gain an additional +80%% weapon damage.]])
		:format()
	end,
}

uberTalent{
	name = "Massive Blow",
	mode = "activated",
	require = { special={desc="Have dug at least 30 walls/trees/etc. and have dealt over 50000 damage with two-handed weapons", fct=function(self) return
		self.dug_times and self.dug_times >= 30 and
		self.damage_log and self.damage_log.weapon.twohanded and self.damage_log.weapon.twohanded >= 50000
	end} },
	requires_target = true,
	tactical = { ATTACK = 4 },
	cooldown = 10,
	is_melee = true,
	range = 1,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end

		local destroyed = false
		target:knockback(self.x, self.y, 4, nil, function(g, x, y)
			if g:attr("dig") and not destroyed then
				DamageType:get(DamageType.DIG).projector(self, x, y, DamageType.DIG, 1)
				destroyed = true
			end
		end)

		if self:attackTarget(target, nil, 1.5 + (destroyed and 3.5 or 0), true) then
			target:setEffect(target.EFF_COUNTERSTRIKE, 2, {power=20, no_ct_effect=true, src=self, nb=1})
		end
		return true
	end,
	info = function(self, t)
		return ([[You deal a massive blow to your foe, smashing it for 150%% weapon damage and knocking it back 4 tiles (ignoring knockback resistance or physical save).
		If the knockback makes it hit a wall, it will smash down the wall, deal an additional 350%% weapon damage and apply the Counterstrike effect.]])
		:format()
	end,
}

uberTalent{
	name = "Steamroller",
	mode = "passive",
	require = { special={desc="Know the Rush talent", fct=function(self) return self:knowTalent(self.T_RUSH) end} },
	info = function(self, t)
		return ([[When you rush, the creature you rush to is marked. If you kill it in the next two turns then your rush cooldown is reset.
		Each time that this effect triggers you gain a stacking +20%% damage buff, up to 100%%.
		Rush now only costs 2 stamina.]])
		:format()
	end,
}

uberTalent{
	name = "Irresistible Sun",
	cooldown = 25,
	requires_target = true,
	range = 5,
	tactical = { ATTACKAREA = {LIGHT = 2, FIRE = 2, PHYSICAL = 2}, CLOSEIN = 2 },
	target = {type="ball", range=0, friendlyfire=false, radius=5},
	require = { special={desc="Have dealt over 50000 light or fire damage", fct=function(self) return
		self.damage_log and (
			(self.damage_log[DamageType.FIRE] and self.damage_log[DamageType.FIRE] >= 50000) or
			(self.damage_log[DamageType.LIGHT] and self.damage_log[DamageType.LIGHT] >= 50000)
		)
	end} },
	action = function(self, t)
		self:setEffect(self.EFF_IRRESISTIBLE_SUN, 8, {dam=35 + self:getStr() * 1.3})
		return true
	end,
	info = function(self, t)
		local dam = (35 + self:getStr() * 1.3) / 3
		return ([[For 8 turns you gain the mass and power of a star, drawing all creatures within radius 5 toward you and dealing %0.2f fire, %0.2f light and %0.2f physical damage to all foes and reducing their damage dealt by 30%%.
		Foes closer to you take up to 150%% damage.
		The damage will increase with your Strength.]])
		:format(damDesc(self, DamageType.FIRE, dam), damDesc(self, DamageType.LIGHT, dam), damDesc(self, DamageType.PHYSICAL, dam))
	end,
}

uberTalent{
	name = "I Can Carry The World!", short_name = "NO_FATIGUE",
	mode = "passive",
	require = { special={desc="Be able to use massive armours", fct=function(self) return self:getTalentLevelRaw(self.T_ARMOUR_TRAINING) >= 3 end} },
	on_learn = function(self, t)
		self:attr("size_category", 1)
		self:attr("max_encumber", 500)
		self:incIncStat(self.STAT_STR, 50)
	end,
	on_unlearn = function(self, t)
		self:attr("size_category", -1)
		self:attr("max_encumber", -500)
		self:incIncStat(self.STAT_STR, -50)
	end,
	info = function(self, t)
		return ([[Your strength is legendary; fatigue and physical exertion mean nothing to you.
		Your fatigue is permanently set to 0, carrying capacity increased by 500, and strength increased by 50 and you gain a size category.]])
		:format()
	end,
}

uberTalent{
	name = "Legacy of the Naloren",
	mode = "passive",
	require = { special={desc="Have sided with Slasul and killed Ukllmswwik", fct=function(self)
		if game.state.birth.ignore_prodigies_special_reqs then return true end
		local q = self:hasQuest("temple-of-creation")
		return q and not q:isCompleted("kill-slasul") and q:isCompleted("kill-drake")
	end} },
	cant_steal = true,
	-- _M:levelup function in mod.class.Actor.lua updates the talent levels with character level
	bonusLevel = function(self, t) return math.ceil(self.level/10) end,
	callbackOnLevelup = function(self, t, new_level)
		return t.updateTalent(self, t)
	end,
	updateTalent = function(self, t)
		local p = self.talents_learn_vals[t.id] or {}
		if p.__tmpvals then
			for i = 1, #p.__tmpvals do
				self:removeTemporaryValue(p.__tmpvals[i][1], p.__tmpvals[i][2])
			end
			p.__tmpvals = nil
		end
		self:talentTemporaryValue(p, "can_breath", {water = 1})
		self.__show_special_talents[self.T_EXOTIC_WEAPONS_MASTERY] = true
		self:talentTemporaryValue(p, "talents_inc_cap", {T_EXOTIC_WEAPONS_MASTERY=t.bonusLevel(self,t)})
		self:talentTemporaryValue(p, "talents", {T_EXOTIC_WEAPONS_MASTERY=t.bonusLevel(self,t)})
		self:talentTemporaryValue(p, "talents_inc_cap", {T_SPIT_POISON=t.bonusLevel(self,t)})
		self:talentTemporaryValue(p, "talents", {T_SPIT_POISON=t.bonusLevel(self,t)})
	end,
	passives = function(self, t, p)
		-- talents_inc_cap field referenced by _M:getMaxTPoints in mod.dialogs.LevelupDialog.lua
		self.talents_inc_cap = self.talents_inc_cap or {}
		t.callbackOnLevelup(self, t)
	end,
	on_learn = function(self, t)
		require("engine.ui.Dialog"):simplePopup("Legacy of the Naloren", "Slasul will be happy to know your faith in his cause. You should return to speak to him.")
	end,
	info = function(self, t)
		local level = t.bonusLevel(self,t)
		return ([[You have sided with Slasul and helped him vanquish Ukllmswwik. You are now able to breathe underwater with ease.
		You have also learned to use tridents and other exotic weapons easily (talent level %d of Exotic Weapon Mastery), and can Spit Poison (talent level %d) as nagas do. These are bonus talent levels that increase with your character level.
		In addition, should Slasul still live, he may have a further reward for you as thanks...]])
		:format(level, level)
	end,
}

uberTalent{
	name = "Superpower",
	mode = "passive",
	info = function(self, t)
		return ([[A strong body is key to a strong mind, and a strong mind can be powerful enough to make a strong body.
		This prodigy grants a Mindpower bonus equal to 60%% of your Strength.
		Additionally, you treat all weapons as having an additional 40%% Willpower modifier.]])
		:format()
	end,
}
