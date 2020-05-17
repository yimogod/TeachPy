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
	name = "Draconic Will",
	cooldown = 15,
	no_energy = true,
	requires_target = true,
	fixed_cooldown = true,
	tactical = { DEFEND = 1}, -- instant talent
	action = function(self, t)
		self:setEffect(self.EFF_DRACONIC_WILL, 5, {})
		return true
	end,
	require = { special={desc="Be close to the draconic world", fct=function(self) return game.state.birth.ignore_prodigies_special_reqs or (self:attr("drake_touched") and self:attr("drake_touched") >= 2) end} },
	info = function(self, t)
		return ([[Your body is like that of a drake, easily resisting detrimental effects.
		For 5 turns, no detrimental effects may target you.]])
		:format()
	end,
}

uberTalent{
	name = "Meteoric Crash",
	mode = "passive",
	cooldown = 15,
	getDamage = function(self, t) return math.max(50 + self:combatSpellpower() * 5, 50 + self:combatMindpower() * 5) end,
	getLava = function(self, t) return math.max(self:combatSpellpower() + 30, self:combatMindpower() + 30) end,
	require = { special={desc="Have witnessed a meteoric crash", fct=function(self) return game.state.birth.ignore_prodigies_special_reqs or self:attr("meteoric_crash") end} },
	passives = function(self, t, tmptable)
		self:talentTemporaryValue(tmptable, "auto_highest_inc_damage", {[DamageType.FIRE] = 1})
		self:talentTemporaryValue(tmptable, "auto_highest_resists_pen", {[DamageType.FIRE] = 1})
		self:talentTemporaryValue(tmptable, "inc_damage", {[DamageType.FIRE] = 0.00001})  -- 0 so that it shows up in the UI
		self:talentTemporaryValue(tmptable, "resists_pen", {[DamageType.FIRE] = 0.00001})
	end,	
	trigger = function(self, t, target)
		self:startTalentCooldown(t)
		local terrains = t.terrains or mod.class.Grid:loadList("/data/general/grids/lava.lua")
		t.terrains = terrains -- cache

		local lava_dam = t.getLava(self, t)
		local dam = t.getDamage(self, t)
		if self:combatMindCrit() > self:combatSpellCrit() then 
			_dam = self:mindCrit(dam)
			lava_dam = self:mindCrit(lava_dam)
		else 
			dam = self:spellCrit(dam)
			lava_dam = self:spellCrit(lava_dam)
		end
		local meteor = function(src, x, y, dam)
			game.level.map:particleEmitter(x, y, 10, "meteor", {x=x, y=y})
				game.level.map:particleEmitter(x, y, 10, "fireflash", {radius=2})
				game:playSoundNear(game.player, "talents/fireflash")

				local grids = {}
				for i = x-3, x+3 do for j = y-3, y+3 do
					local oe = game.level.map(i, j, engine.Map.TERRAIN)
					-- Create "patchy" lava, but guarantee that the center tiles are lava
					if oe and not oe:attr("temporary") and not oe.special and not game.level.map:checkEntity(i, j, engine.Map.TERRAIN, "block_move") and (core.fov.distance(x, y, i, j) < 1 or rng.percent(40)) then
						local g = terrains.LAVA_FLOOR:clone()
						g:resolve() g:resolve(nil, true)
						game.zone:addEntity(game.level, g, "terrain", i, j)
						grids[#grids+1] = {x=i,y=j,oe=oe}
					end
				end end
				for i = x-3, x+3 do for j = y-3, y+3 do
					game.nicer_tiles:updateAround(game.level, i, j)
				end end
				for _, spot in ipairs(grids) do
					local i, j = spot.x, spot.y
					local g = game.level.map(i, j, engine.Map.TERRAIN)

					g.mindam = lava_dam
					g.maxdam = lava_dam
					g.faction = src.faction -- Don't hit self or allies
					g.temporary = 8
					g.x = i g.y = j
					g.canAct = false
					g.energy = { value = 0, mod = 1 }
					g.old_feat = spot.oe
					g.useEnergy = mod.class.Trap.useEnergy
					g.act = function(self)
						self:useEnergy()
						self.temporary = self.temporary - 1
						if self.temporary <= 0 then
							game.level.map(self.x, self.y, engine.Map.TERRAIN, self.old_feat)
							game.level:removeEntity(self, true)
							game.nicer_tiles:updateAround(game.level, self.x, self.y)
						end
					end
					g:altered()
					game.level:addEntity(g)
				end

				src:project({type="ball", radius=2, selffire=false, friendlyfire=false}, x, y, engine.DamageType.METEOR, dam)
				src:project({type="ball", radius=2, selffire=false, friendlyfire=false}, x, y, function(px, py)
					local target = game.level.map(px, py, engine.Map.ACTOR)
					if target then
						if target:canBe("stun") then
							target:setEffect(target.EFF_STUNNED, 3, {apply_power=math.max(src:combatSpellpower(), src:combatMindpower())})
						else
							game.logSeen(target, "%s resists the stun!", target.name:capitalize())
						end
					end
				end)
				if core.shader.allow("distort") then game.level.map:particleEmitter(x, y, 2, "shockwave", {radius=2}) end
				game:getPlayer(true):attr("meteoric_crash", 1)
			end

		local dam = t.getDamage(self, t)
		if self:combatMindCrit() > self:combatSpellCrit() then dam = self:mindCrit(dam)
		else dam = self:spellCrit(dam)
		end
		meteor(self, target.x, target.y, dam)

		return true
	end,
	info = function(self, t)
		local dam = t.getDamage(self, t)/2
		return ([[When casting damaging spells or mind attacks, the release of your willpower can call forth a meteor to crash down near your foes.
		The meteor deals %0.2f fire and %0.2f physical damage in radius 2 and stuns enemies for 3 turns.
		Lava is created in radius 3 around the impact dealing %0.2f fire damage per turn for 8 turns.  This will overwrite tiles that already have modified terrain.
		You and your allies take no damage from either effect.

		Additionally, your fire damage bonus and resistance penetration is set to your current highest damage bonus and resistance penetration. This applies to all fire damage you deal.
		The damage scales with your Spellpower or Mindpower.]])
		:format(damDesc(self, DamageType.FIRE, dam), damDesc(self, DamageType.PHYSICAL, dam), damDesc(self, DamageType.FIRE, t.getLava(self, t)))
	end,
}

uberTalent{
	name = "Garkul's Revenge",
	mode = "passive",
	on_learn = function(self, t)
		self.inc_damage_actor_type = self.inc_damage_actor_type or {}
		self.inc_damage_actor_type.construct = (self.inc_damage_actor_type.construct or 0) + 1000
		self.inc_damage_actor_type.humanoid = (self.inc_damage_actor_type.humanoid or 0) + 20
		self.inc_damage_actor_type.humanoid = (self.inc_damage_actor_type.giant or 0) + 20
	end,
	on_unlearn = function(self, t)
		self.inc_damage_actor_type.construct = (self.inc_damage_actor_type.construct or 0) - 1000
		self.inc_damage_actor_type.humanoid = (self.inc_damage_actor_type.humanoid or 0) - 20
		self.inc_damage_actor_type.humanoid = (self.inc_damage_actor_type.giant or 0) - 20
	end,
	require = { special={desc="Possess and wear two of Garkul's artifacts and know all about Garkul's life", fct=function(self)
		local o1 = self:findInAllInventoriesBy("define_as", "SET_GARKUL_TEETH")
		local o2 = self:findInAllInventoriesBy("define_as", "HELM_OF_GARKUL")
		return o1 and o2 and o1.wielded and o2.wielded and (game.state.birth.ignore_prodigies_special_reqs or (
			game.party:knownLore("garkul-history-1") and
			game.party:knownLore("garkul-history-2") and
			game.party:knownLore("garkul-history-3") and
			game.party:knownLore("garkul-history-4") and
			game.party:knownLore("garkul-history-5")
			))
	end} },
	info = function(self, t)
		return ([[Garkul's spirit is with you. You now deal 1000%% more damage to constructs and 20%% more damage to humanoids and giants.]])
		:format()
	end,
}

uberTalent{
	name = "Hidden Resources",
	cooldown = 15,
	no_energy = true,
	tactical = function(self, t, aitarget) -- build a tactical table for all defined resources the first time this is called.
		local tacs = {special = -1}
		for i, res_def in ipairs(self.resources_def) do
			if res_def.talent then tacs[res_def.short_name] = 0.5 end
		end
		t.tactical = tacs
		return tacs
	end,
	action = function(self, t)
		self:setEffect(self.EFF_HIDDEN_RESOURCES, 5, {})
		return true
	end,
	require = { special={desc="Have been close to death(killed a foe while below 1 HP)", fct=function(self) return self:attr("barely_survived") end} },
	info = function(self, t)
		return ([[You focus your mind on the task at hand, regardless of how dire the situation is.
		For 5 turns, none of your talents use any resources.]])
		:format()
	end,
}

uberTalent{
	name = "Lucky Day",
	mode = "passive",
	require = { special={desc="Be lucky already (at least +5 luck)", fct=function(self) return self:getLck() >= 55 end} },
	on_learn = function(self, t)
		self.inc_stats[self.STAT_LCK] = (self.inc_stats[self.STAT_LCK] or 0) + 40
		self:onStatChange(self.STAT_LCK, 40)
		self:attr("phase_shift", 0.1)
	end,
	on_unlearn = function(self, t)
		self.inc_stats[self.STAT_LCK] = (self.inc_stats[self.STAT_LCK] or 0) - 40
		self:onStatChange(self.STAT_LCK, -40)
		self:attr("phase_shift", -0.1)
	end,
	info = function(self, t)
		return ([[Every day is your lucky day! You gain a permanent +40 luck bonus and 10%% to move out of the way of every attack.]])
		:format()
	end,
}

uberTalent{
	name = "Unbreakable Will",
	mode = "passive",
	cooldown = 5,
	trigger = function(self, t)
		self:startTalentCooldown(t)
		game.logSeen(self, "#LIGHT_BLUE#%s's unbreakable will shrugs off the effect!", self.name:capitalize())
		return true
	end,
	info = function(self, t)
		return ([[Your will is so strong that you simply ignore mental effects used against you.
		This effect can only occur once every 5 turns.]])
		:format()
	end,
}

uberTalent{
	name = "Spell Feedback",
	mode = "passive",
	cooldown = 9,
	require = { special={desc="Antimagic", fct=function(self) return self:knowTalentType("wild-gift/antimagic") end} },
	trigger = function(self, t, target, source_t)
		self:startTalentCooldown(t)
		self:logCombat(target, "#LIGHT_BLUE##Source# punishes #Target# for casting a spell!", self.name:capitalize(), target.name)
		DamageType:get(DamageType.MIND).projector(self, target.x, target.y, DamageType.MIND, 20 + self:getWil() * 2)

		local dur = target:getTalentCooldown(source_t)
		if dur and dur > 0 then
			target:setEffect(target.EFF_SPELL_FEEDBACK, dur, {power=35})
		end
		return true
	end,
	info = function(self, t)
		return ([[Your will is a shield against assaults from crazed arcane users.
		Each time that you take damage from a spell, you punish the spellcaster with %0.2f mind damage.
		Also, they will suffer a 35%% spell failure chance (with duration equal to the cooldown of the spell they used on you).
		Note: this talent has a cooldown.]])
		:format(damDesc(self, DamageType.MIND, 20 + self:getWil() * 2))
	end,
}

uberTalent{
	name = "Mental Tyranny",
	mode = "sustained",
	require = { },
	cooldown = 20,
	tactical = { BUFF = 3 },
	require = { special={desc="Have dealt over 50000 mind damage", fct=function(self) return 
		self.damage_log and (
			(self.damage_log[DamageType.MIND] and self.damage_log[DamageType.MIND] >= 50000)
		)
	end} },
	activate = function(self, t)
		game:playSoundNear(self, "talents/distortion")
		return {
			converttype = self:addTemporaryValue("all_damage_convert", DamageType.MIND),
			convertamount = self:addTemporaryValue("all_damage_convert_percent", 33),
			dam = self:addTemporaryValue("inc_damage", {[DamageType.MIND] = 10}),
			resist = self:addTemporaryValue("resists_pen", {[DamageType.MIND] = 30}),
		}
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("all_damage_convert", p.converttype)
		self:removeTemporaryValue("all_damage_convert_percent", p.convertamount)
		self:removeTemporaryValue("inc_damage", p.dam)
		self:removeTemporaryValue("resists_pen", p.resist)
		return true
	end,
	info = function(self, t)
		return ([[Transcend the physical and rule over all with an iron will!
		While this sustain is active, 33%% of your damage is converted into mind damage.
		Additionally, you gain +30%% mind resistance penetration, and +10%% mind damage.]]):
		format()
	end,
}
