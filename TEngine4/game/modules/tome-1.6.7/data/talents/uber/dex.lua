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
	name = "Flexible Combat",
	mode = "passive",
	on_learn = function(self, t)
		self:attr("unharmed_attack_on_hit", 1)
		self:attr("show_gloves_combat", 1)
	end,
	on_unlearn = function(self, t)
		self:attr("unharmed_attack_on_hit", -1)
		self:attr("show_gloves_combat", -1)
	end,
	info = function(self, t)
		return ([[Each time that you make a melee attack you have a 50%% chance to execute an additional unarmed strike.]])
		:format()
	end,
}

uberTalent{
	name = "Through The Crowd",
	require = { special={desc="Have had at least 6 party members at the same time", fct=function(self)
		return self:attr("huge_party")
	end} },
	mode = "sustained",
	on_learn = function(self, t)
		self:attr("bump_swap_speed_divide", 10)
	end,
	on_unlearn = function(self, t)
		self:attr("bump_swap_speed_divide", -10)
	end,
	tactical = {DEFEND = 2, ESCAPE = 2, CLOSEIN = 2},
	callbackOnAct = function(self, t)
		local nb_friends = 0
		local act
		for i = 1, #self.fov.actors_dist do
			act = self.fov.actors_dist[i]
			if act and self:reactionToward(act) > 0 and self:canSee(act) then nb_friends = nb_friends + 1 end
		end
		if nb_friends > 1 then
			nb_friends = math.min(nb_friends, 5)
			self:setEffect(self.EFF_THROUGH_THE_CROWD, 4, {power=nb_friends})
		end
	end,
	callbackOnPartyAdd = function(self, t, actor)
		if not self.player then return end
		if actor:knowTalent(actor.T_THROUGH_THE_CROWD) then return end
		actor:learnTalent(actor.T_THROUGH_THE_CROWD, true)
		actor:forceUseTalent(actor.T_THROUGH_THE_CROWD, {ignore_cooldown=true, ignore_energy=true})
	end,
	activate = function(self, t)
		local ret = {}
		self:talentTemporaryValue(ret, "nullify_all_friendlyfire", 1)
		if game.party:hasMember(self) then
			for i, actor in ipairs(game.party.m_list) do if actor ~= self then
				t.callbackOnPartyAdd(self, t, actor)
			end end
		end
		return ret
	end,
	deactivate = function(self, t, p)
		return true
	end,
	info = function(self, t)
		return ([[You are used to a crowded party:
		- you can swap places with friendly creatures in just one tenth of a turn as a passive effect.
		- you can never damage your friends or neutral creatures while this talent is active.
		- you love being surrounded by friends; for each friendly creature in sight you gain +10 to all saves and +3%% to global speed (max 15%%)
		- every party member is also automatically granted Through The Crowd]])
		:format()
	end,
}

uberTalent{
	name = "Swift Hands",
	mode = "passive",
	on_learn = function(self, t)
		self:attr("quick_weapon_swap", 1)
		self:attr("quick_equip_cooldown", 1)
		self:attr("quick_wear_takeoff", 1)
	end,
	on_unlearn = function(self, t)
		self:attr("quick_weapon_swap", -1)
		self:attr("quick_equip_cooldown", -1)
		self:attr("quick_wear_takeoff", -1)
	end,
	info = function(self, t)
		return ([[You have very agile hands; swapping equipment sets (default q key) takes no time, nor does equipping/unequipping items.
		The free item switch may only happen once per turn.
		The cooldown for equipping activatable equipment is removed.]])
		:format()
	end,
}

uberTalent{
	name = "Windblade",
	mode = "activated",
	require = { special={desc="Have dealt over 50000 damage with dual wielded weapons", fct=function(self) return self.damage_log and self.damage_log.weapon.dualwield and self.damage_log.weapon.dualwield >= 50000 end} },
	cooldown = 12,
	radius = 4,
	range = 0,
	tactical = { ATTACKAREA = {  weapon = 2  }, DISABLE = { disarm = 2 } },
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), selffire=false, radius=self:getTalentRadius(t)}
	end,
	is_melee = true,
	requires_target = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		self:project(tg, self.x, self.y, function(px, py, tg, self)
			local target = game.level.map(px, py, Map.ACTOR)
			if target and target ~= self then
				local hit = self:attackTarget(target, nil, 3.2, true)
				if hit and target:canBe("disarm") then
					target:setEffect(target.EFF_DISARMED, 4, {})
				end
			end
		end)
		self:addParticles(Particles.new("meleestorm", 1, {radius=4, img="spinningwinds_blue"}))

		return true
	end,
	info = function(self, t)
		return ([[You spin madly, generating a sharp gust of wind with your weapons that deals 320%% weapon damage to all targets within radius 4 and disarms them for 4 turns.]])
		:format()
	end,
}

uberTalent{
	name = "Windtouched Speed",
	mode = "passive",
	require = { special={desc="Know at least 10 talent levels of equilibrium-using talents", fct=function(self) return knowRessource(self, "equilibrium", 10) end} },
	on_learn = function(self, t)
		self:attr("global_speed_add", 0.2)
		self:attr("avoid_pressure_traps", 1)
		self.talent_cd_reduction.allpct = (self.talent_cd_reduction.allpct or 0) + 0.1
		self:recomputeGlobalSpeed()
	end,
	on_unlearn = function(self, t)
		self:attr("global_speed_add", -0.2)
		self:attr("avoid_pressure_traps", -1)
		self.talent_cd_reduction.allpct = self.talent_cd_reduction.allpct - 0.1
		self:recomputeGlobalSpeed()
	end,
	info = function(self, t)
		return ([[You are attuned with Nature, and she helps you in your fight against the arcane forces.
		You gain 20%% permanent global speed, 10%% cooldowns reduction and do not trigger pressure traps.]])
		:format()
	end,
}

uberTalent{
	name = "Crafty Hands",
	mode = "passive",
	no_npc_use = true,
	cant_steal = true,
	require = { special={desc="Know Imbue Item to level 5", fct=function(self)
		return self:getTalentLevelRaw(self.T_IMBUE_ITEM) >= 5
	end} },
	info = function(self, t)
		return ([[You are very crafty. You can now also embed gems into helms and belts.]])
		:format()
	end,
}

uberTalent{
	name = "Roll With It",
	mode = "sustained",
	cooldown = 10,
	tactical = function(self, t, aitarget)
		if self:attr("never_move") then return
		else return {ESCAPE = 2, DEFEND = 2}
		end
	end,
	require = { special={desc="Have been knocked around at least 50 times", fct=function(self) return self:attr("knockback_times") and self:attr("knockback_times") >= 50 end} },
	-- Called by default projector in mod.data.damage_types.lua
	getMult = function(self, t) return self:combatLimit(self:getDex(), 0.7, 0.9, 50, 0.85, 100) end, -- Limit > 70% damage taken
	activate = function(self, t)
		local ret = {}
		self:talentTemporaryValue(ret, "knockback_on_hit", 1)
		self:talentTemporaryValue(ret, "movespeed_on_hit", {speed=3, dur=1})
		return ret
	end,
	deactivate = function(self, t, p)
		return true
	end,
	info = function(self, t)
		return ([[You have learned to take a few hits when needed and can flow with the tide of battle.
		So long as you can move, you find a way to dodge, evade, deflect or otherwise reduce physical damage against you by %d%%.
		Once per turn, when you get hit by a melee or archery attack you move back one tile for free and gain 200%% movement speed for a turn.
		The damage avoidance scales with your Dexterity and applies after resistances.]])
		:format(100*(1-t.getMult(self, t)))
	end,
}

uberTalent{
	name = "Vital Shot",
	no_energy = "fake",
	cooldown = 10,
	range = archery_range,
	require = { special={desc="Have dealt over 50000 damage with ranged weapons", fct=function(self) return self.damage_log and self.damage_log.weapon.archery and self.damage_log.weapon.archery >= 50000 end} },
	tactical = { ATTACK = { weapon = 3 }, DISABLE = {2, stun = 2}},
	requires_target = true,
	on_pre_use = function(self, t, silent) return archerPreUse(self, t, silent) end,
	archery_onhit = function(self, t, target, x, y)
		if target:canBe("stun") then
			target:setEffect(target.EFF_STUNNED, 5, {apply_power=self:combatAttack()})
		end
		target:setEffect(target.EFF_CRIPPLE, 5, {speed=0.50, apply_power=self:combatAttack()})
	end,
	action = function(self, t)
		local targets = self:archeryAcquireTargets(nil, {one_shot=true})
		if not targets then return end
		self:archeryShoot(targets, t, nil, {mult=4.5})
		return true
	end,
	info = function(self, t)
		return ([[You fire a shot straight at your enemy's vital areas, wounding them terribly.
		Enemies hit by this shot will take 450%% weapon damage and will be stunned and crippled (losing 50%% physical, magical and mental attack speeds) for five turns due to the devastating impact of the shot.
		The stun and cripple chances increase with your Accuracy.]]):format()
	end,
}
