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
	name = "Wraithform",
	type = {"corruption/shadowflame", 1},
	require = corrs_req1,
	points = 5,
	vim = 12,
	cooldown = 30,
	no_energy = true,
	tactical = { DEFEND = 1, ESCAPE = 1, CLOSEIN = 1 },
	getDuration = function(self, t) return math.floor(self:combatTalentLimit(t, 15, 5, 9)) end, -- Limit < 30 (make sure they can't hide forever)
	getDefs = function(self, t) return self:combatTalentScale(t, 5, 20), self:combatTalentScale(t, 5, 16) end,
	action = function(self, t)
		local def, armor = t.getDefs(self, t)
		self:setEffect(self.EFF_WRAITHFORM, t.getDuration(self, t), {def=def, armor=armor})
		return true
	end,
	info = function(self, t)
		return ([[Turn into a wraith, allowing you to walk through walls and removing the need to breath for %d turns.
		Also increases your defense and armour by %d and %d, respectively.
		If you are still in a wall when the effect ends you will randomly teleport.
		]]):
		format(t.getDuration(self, t), t.getDefs(self, t))
	end,
}

newTalent{
	name = "Darkfire",
	type = {"corruption/shadowflame", 2},
	require = corrs_req2,
	points = 5,
	cooldown = 8,
	vim = 15,
	requires_target = true,
	range = 6,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 2, 6)) end,
	proj_speed = 4,
	tactical = { ATTACKAREA = {FIRE = 1, DARKNESS = 1} },
	direct_hit = true,
	requires_target = true,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), selffire=self:spellFriendlyFire(), talent=t, display={particle="bolt_fire", trail="firetrail"}}
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		self:projectile(tg, x, y, DamageType.SHADOWFLAME, self:spellCrit(self:combatTalentSpellDamage(t, 28, 220)), function(self, tg, x, y, grids)
			game.level.map:particleEmitter(x, y, tg.radius, "fireflash", {radius=tg.radius, grids=grids, tx=x, ty=y})
			game.level.map:particleEmitter(x, y, tg.radius, "shadow_flash", {radius=tg.radius, grids=grids, tx=x, ty=y})
			game.level.map:particleEmitter(x, y, tg.radius, "circle", {zdepth=6, oversize=1, a=130, appear=8, limit_life=12, speed=5, img="demon_flames_circle", radius=tg.radius})
		end)
		game:playSoundNear(self, "talents/fireflash")
		return true
	end,
	info = function(self, t)
		return ([[Conjures up a bolt of shadowflame that moves toward the target and explodes into a flash of darkness and fire, doing %0.2f fire damage and %0.2f darkness damage in a radius of %d.
		The damage will increase with your Spellpower.]]):format(
			damDesc(self, DamageType.FIRE, self:combatTalentSpellDamage(t, 28, 220) / 2),
			damDesc(self, DamageType.DARKNESS, self:combatTalentSpellDamage(t, 28, 220) / 2),
			self:getTalentRadius(t)
		)
	end,
}

newTalent{
	name = "Flame of Urh'Rok",
	type = {"corruption/shadowflame", 3},
	require = corrs_req3,
	mode = "sustained",
	points = 5,
	sustain_vim = 90,
	cooldown = 30,
	tactical = { DEFEND = 1, BUFF = 2 },
	getSpeed = function(self, t) return self:combatTalentScale(t, 0.03, 0.15, 0.75) end,
	activate = function(self, t)
		game:playSoundNear(self, "talents/flame")
		self.__old_type = {self.type, self.subtype}
		self.type, self.subtype = "demon", "major"
		local power = t.getSpeed(self, t)
		return {
			demon = self:addTemporaryValue("demon", 1),
			speed = self:addTemporaryValue("global_speed_add", power),
			res = self:addTemporaryValue("resists", {[DamageType.FIRE]=self:combatTalentSpellDamage(t, 20, 30), [DamageType.DARKNESS]=self:combatTalentSpellDamage(t, 20, 35)}),
			particle = self:addParticles(Particles.new("shadowfire", 1)),
		}
	end,
	deactivate = function(self, t, p)
		self.type, self.subtype = unpack(self.__old_type)
		self.__old_type = nil
		self:removeTemporaryValue("resists", p.res)
		self:removeTemporaryValue("global_speed_add", p.speed)
		self:removeTemporaryValue("demon", p.demon)
		self:removeParticles(p.particle)
		return true
	end,
	info = function(self, t)
		return ([[Call upon the essence of the supreme demon overlord Urh'Rok to turn into a demon.
		While in demon form, you gain %d%% fire resistance, %d%% darkness resistance, and your global speed is increased by %d%%.
		The flames of the Fearscape will heal you while in demon form.
		The resistances and heal will increase with your Spellpower.]]):
		format(self:combatTalentSpellDamage(t, 20, 30), self:combatTalentSpellDamage(t, 20, 35), t.getSpeed(self, t)*100)
	end,
}

newTalent{
	name = "Fearscape", short_name = "DEMON_PLANE",
	type = {"corruption/shadowflame", 4},
	require = corrs_req4,
	mode = "sustained",
	points = 5,
	sustain_vim = 5,
	drain_vim = function(self, t) -- automatically updated while active
		local drain = 5
		local p = self:isTalentActive(t.id)
		drain = drain + (p and p.drain_add or 0)
		return drain
	end,
	remove_on_zero = true,
	requires_target = true,
	cooldown = 60,
	no_sustain_autoreset = true,
	random_boss_rarity = 10,
	tactical = {
		-- heals (negative attack) demons hurts others
		ATTACKAREA = {FIRE = function(self, t, target) return target:attr("demon") and -2 or 2 end},
		-- heals self if demon, otherwise hurts
		SELF = {HEAL = function(self, t, target) return self:attr("demon") and 2 end,
			 ATTACK = {FIRE = function(self, t, target)
				return not self:attr("demon") and self.ai_state.self_compassion ~= false and -2*(self.ai_state.self_compassion or 5) end
			 }
		}
	},
	target = function(self, t)
		if self:isTalentActive(t.id) then -- always hit enemies while in the Fearscape (affects AI)
			return {type="ball", nolock=true, pass_terrain=true, nowarning=true, range=20, radius=20, requires_knowledge=false, selffire=false, block_path=false, block_radius=false}
		else -- always hit the primary target
			local tgt = self.ai_target.actor
			return {type="hit", range=self:getTalentRange(t), talent=t, x=tgt and tgt.x, y=tgt and tgt.y}
		end
	end,
	range = 5,
	on_pre_use = function(self, t) return not (game.zone.is_demon_plane or game.zone.no_planechange) and self:canBe("planechange") and self:getVim() > 11 end,
	-- only use against the player
	on_pre_use_ai = function(self, t) return self.ai_target.actor and self.ai_target.actor.game_ender or self.sustain_talents[t.id] end,
	callbackOnActBase = function(self, t) -- update vim regeneration
		local p = self:isTalentActive(t.id)
		if not p then return end
		p.drain_add = (p.drain_add or 0) + 1
	end,
	activate = function(self, t)
		if game.zone.is_demon_plane then
			game.logPlayer(self, "This spell cannot be used from within the Fearscape.")
			return
		end
		if game.zone.no_planechange then
			game.logPlayer(self, "This spell cannot be cast here.")
			return
		end

		local tg = self:getTalentTarget(t)
		local tx, ty, target = self:getTarget(tg)
		if not tx or not ty or not target then return nil end
		local _ _, tx, ty = self:canProject(tg, tx, ty)
		if not tx or not ty or not target then return nil end
		target = game.level.map(tx, ty, Map.ACTOR)
		if not tx or not ty or not target then return nil end
		if not (target.player and target.game_ender) and not (self.player and self.game_ender) then return nil end
		if target == self then return end
		if target:attr("negative_status_effect_immune") or target:attr("status_effect_immune") then return nil end

		if not self:canBe("planechange") or target.summon_time or target.summon then
			game.logPlayer(self, "The spell fizzles...")
			return
		end

		game:playSoundNear(self, "talents/flame")
		local dam = self:combatTalentSpellDamage(t, 12, 140)

		game:onTickEnd(function()
			if self:attr("dead") then return end
			local oldzone = game.zone
			local oldlevel = game.level

			-- Remove them before making the new level, this way party members are not removed from the old level
			if oldlevel:hasEntity(self) then oldlevel:removeEntity(self) end
			if oldlevel:hasEntity(target) then oldlevel:removeEntity(target) end

			oldlevel.no_remove_entities = true
			local zone = mod.class.Zone.new("demon-plane-spell")
			local level = zone:getLevel(game, 1, 0)
			oldlevel.no_remove_entities = nil
			level.demonfire_dam = dam
			level.plane_owner = self

			level:addEntity(self)
			level:addEntity(target)

			level.source_zone = oldzone
			level.source_level = oldlevel
			game.zone = zone
			game.level = level
			game.zone_name_s = nil

			local x1, y1 = util.findFreeGrid(4, 6, 20, true, {[Map.ACTOR]=true})
			if x1 then
				self:move(x1, y1, true)
				game.level.map:particleEmitter(x1, y1, 1, "demon_teleport")
			end
			local x2, y2 = util.findFreeGrid(8, 6, 20, true, {[Map.ACTOR]=true})
			if x2 then
				target:move(x2, y2, true)
				game.level.map:particleEmitter(x2, y2, 1, "demon_teleport")
			end

			target:setTarget(self)
			target.demon_plane_trapper = self
			target.demon_plane_on_die = target.on_die
			target.on_die = function(self, ...)
				self.demon_plane_trapper:forceUseTalent(self.T_DEMON_PLANE, {ignore_energy=true})
				local args = {...}
				game:onTickEnd(function()
					if self.demon_plane_on_die then self:demon_plane_on_die(unpack(args)) end
					self.on_die, self.demon_plane_on_die = self.demon_plane_on_die, nil
				end)
			end

			self.demon_plane_on_die = self.on_die
			self.on_die = function(self, ...)
				self:forceUseTalent(self.T_DEMON_PLANE, {ignore_energy=true})
				local args = {...}
				game:onTickEnd(function()
					if self.demon_plane_on_die then self:demon_plane_on_die(unpack(args)) end
					self.on_die, self.demon_plane_on_die = self.demon_plane_on_die, nil
					if not game.party:hasMember(self) then world:gainAchievement("FEARSCAPE", game:getPlayer(true)) end
				end)
			end

			game.logPlayer(game.player, "#LIGHT_RED#You are taken to the Fearscape!")
			game.party:learnLore("fearscape-entry")
			level.allow_demon_plane_damage = true
		end)

		local particle
		if core.shader.active(4) then
			local bx, by = self:attachementSpot("back", true)
			particle = self:addParticles(Particles.new("shader_wings", 1, {infinite=1, x=bx, y=by, img="bloodwings", flap=28, a=0.6}))
		end
		local ret = {
			target = target,
			x = self.x, y = self.y,
			particle = particle,
			drain_add = 0,
		}
		return ret
	end,
	deactivate = function(self, t, p)
		-- If we're a clone of the original Fearscaper, just deactivate
		if not self.on_die then return true end
		
		if p.particle then self:removeParticles(p.particle) end

		game:onTickEnd(function()
			-- Collect objects
			local objs = {}
			for i = 0, game.level.map.w - 1 do for j = 0, game.level.map.h - 1 do
				for z = game.level.map:getObjectTotal(i, j), 1, -1 do
					objs[#objs+1] = game.level.map:getObject(i, j, z)
					game.level.map:removeObject(i, j, z)
				end
			end end

			local oldzone = game.zone
			local oldlevel = game.level
			local zone = game.level.source_zone
			local level = game.level.source_level

			if not self.dead then
				oldlevel:removeEntity(self, true)
				level:addEntity(self)
			end

			game.zone = zone
			game.level = level
			game.zone_name_s = nil

			local x1, y1 = util.findFreeGrid(p.x, p.y, 20, true, {[Map.ACTOR]=true})
			if x1 then
				if not self.dead then
					self:move(x1, y1, true)
					self.on_die, self.demon_plane_on_die = self.demon_plane_on_die, nil
					game.level.map:particleEmitter(x1, y1, 1, "demon_teleport")
				else
					self.x, self.y = x1, y1
				end
			end
			local x2, y2 = util.findFreeGrid(p.x, p.y, 20, true, {[Map.ACTOR]=true})
			if not p.target.dead then
				if x2 then
					p.target:move(x2, y2, true)
					p.target.on_die, p.target.demon_plane_on_die = p.target.demon_plane_on_die, nil
					game.level.map:particleEmitter(x2, y2, 1, "demon_teleport")
				end
				if oldlevel:hasEntity(p.target) then oldlevel:removeEntity(p.target, true) end
				level:addEntity(p.target)
			else
				p.target.x, p.target.y = x2, y2
			end

			-- Add objects back
			for i, o in ipairs(objs) do
				if self.dead then
					game.level.map:addObject(p.target.x, p.target.y, o)
				else
					game.level.map:addObject(self.x, self.y, o)
				end
			end

			-- Remove all npcs in the fearscape
			for uid, e in pairs(oldlevel.entities) do
				if e ~= self and e ~= p.target and e.die then e:die() end
			end

			-- Reload MOs
			game.level.map:redisplay()
			game.level.map:recreate()
			game.uiset:setupMinimap(game.level)
			game.nicer_tiles:postProcessLevelTilesOnLoad(game.level)

			game.logPlayer(game.player, "#LIGHT_RED#You are brought back from the Fearscape!")
		end)

		return true
	end,
	info = function(self, t)
		return ([[Summon a part of the Fearscape to intersect with the current level.
		You and your target are taken to the Fearscape, trapped there until you end the spell or until your target dies.
		While inside, a constant aura of flames will burn both of you for %0.2f fire damage (demons are healed instead) each turn.
		When the spell ends, only you and the target (if still alive) plus any loose objects are taken back to your home plane; all summons are left in the Fearscape.
		This powerful spell drains 5 vim per turn initially, increasing by +1 for each turn it has been active, and ends when your vim is depleted.
		It has no effect if cast from within the Fearscape.
		The damage will increase with your Spellpower.]]):format(damDesc(self, DamageType.FIRE, self:combatTalentSpellDamage(t, 12, 140)))
	end,
}
