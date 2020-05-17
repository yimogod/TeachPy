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

-- EDGE TODO: Particles, Timed Effect Particles, Mine Tiles

local Trap = require "mod.class.Trap"

makeWarpMine = function(self, t, x, y, type, dam)
	-- Mine values
	local duration = self:callTalent(self.T_WARP_MINES, "getDuration")
	local detect = math.floor(self:callTalent(self.T_WARP_MINES, "trapPower") * 0.8)
	local disarm = math.floor(self:callTalent(self.T_WARP_MINES, "trapPower"))
	local power = getParadoxSpellpower(self, t)
	local dest_power = getParadoxSpellpower(self, t, 0.3)
	
	-- Our Mines
	local mine = Trap.new{
		name = ("warp mine: %s"):format(type),
		type = "temporal", id_by_type=true, unided_name = "trap",
		display = '^', color=colors.BLUE, image = ("trap/chronomine_%s_0%d.png"):format(type == "toward" and "blue" or "red", rng.avg(1, 4, 3)),
		shader = "shadow_simulacrum", shader_args = { color = {0.2, 0.2, 0.2}, base = 0.8, time_factor = 1500 },
		temporary = duration,
		x = x, y = y, type = type,
		faction = self.faction,
		summoner = self, summoner_gain_exp = true,
		disarm_power = disarm,	detect_power = detect,
		dam = dam, talent=t, power = power, dest_power = dest_power,
		canTrigger = function(self, x, y, who)
			if who:reactionToward(self.summoner) < 0 then return mod.class.Trap.canTrigger(self, x, y, who) end
			return false
		end,
		triggered = function(self, x, y, who)
			-- Project our damage
			self.summoner:project({type="hit",x=x,y=y, talent=self.talent}, x, y, engine.DamageType.WARP, self.dam)
			
			-- Teleport?
			if not who.dead then
				-- Does our teleport hit?
				local hit = self.summoner:checkHit(self.power, who:combatSpellResist() + (who:attr("continuum_destabilization") or 0)) and who:canBe("teleport")
				if hit then
					game.level.map:particleEmitter(who.x, who.y, 1, "temporal_teleport")
					local teleport_done = false
					
					if self.type == "toward" then
						-- since we're using a precise teleport we'll look for a free grid first
						local tx, ty = util.findFreeGrid(self.summoner.x, self.summoner.y, 5, true, {[engine.Map.ACTOR]=true})
						if tx and ty then
							game.level.map:particleEmitter(who.x, who.y, 1, "temporal_teleport")
							if not who:teleportRandom(self.summoner.x, self.summoner.y, 1, 0) then
								game.logSeen(self, "The teleport fizzles!")
							else
								teleport_done = true
							end
						end
					elseif self.type == "away" then
						game.level.map:particleEmitter(who.x, who.y, 1, "temporal_teleport")
						if not who:teleportRandom(self.summoner.x, self.summoner.y, 10, 5) then
							game.logSeen(self, "The teleport fizzles!")
						else
							teleport_done = true
						end
					end
					
					-- Destabailize?
					if teleport_done then
						who:setEffect(who.EFF_CONTINUUM_DESTABILIZATION, 100, {power=self.dest_power})
						game.level.map:particleEmitter(who.x, who.y, 1, "temporal_teleport")
						game:playSoundNear(self, "talents/teleport")
					end
				else
					game.logSeen(who, "%s resists the teleport!", who.name:capitalize())
				end					
			end
	
			return true, true
		end,
		canAct = false,
		energy = {value=0},
		act = function(self)
			self:useEnergy()
			self.temporary = self.temporary - 1
			if self.temporary <= 0 then
				if game.level.map(self.x, self.y, engine.Map.TRAP) == self then game.level.map:remove(self.x, self.y, engine.Map.TRAP) end
				game.level:removeEntity(self)
			end
		end,
	}
	
	return mine
end

newTalent{
	name = "Warp Mine Toward",
	type = {"chronomancy/other", 1},
	points = 1,
	cooldown = 10,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	tactical = { ATTACKAREA = { TEMPORAL = 1, PHYSICAL = 1 }, CLOSEIN = 2  },
	requires_target = true,
	range = function(self, t) return self:callTalent(self.T_WARP_MINES, "getRange") or 5 end,
	no_unlearn_last = true,
	target = function(self, t) return {type="ball", nowarning=true, range=self:getTalentRange(t), radius=1, nolock=true, talent=t} end,	
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local tx, ty = self:getTarget(tg)
		if not tx or not ty then return nil end
		local __, tx, ty = self:canProject(tg, tx, ty)
	
		-- Lay the mines in a ball
		local dam = self:spellCrit(self:callTalent(self.T_WARP_MINES, "getDamage"))
		self:project(tg, tx, ty, function(px, py)
			local target_trap = game.level.map(px, py, Map.TRAP)
			if target_trap then return end
			if game.level.map:checkEntity(px, py, Map.TERRAIN, "block_move") then return end
			
			-- Make our mine
			local trap = makeWarpMine(self, t, px, py, "toward", dam)
			
			-- Add the mine
			game.level:addEntity(trap)
			trap:identify(true)
			trap:setKnown(self, true)
			game.zone:addEntity(game.level, trap, "trap", px, py)
		end)

		game:playSoundNear(self, "talents/warp")
		
		return true
	end,
	info = function(self, t)
		local damage = self:callTalent(self.T_WARP_MINES, "getDamage")/2
		local duration = self:callTalent(self.T_WARP_MINES, "getDuration")
		local detect = self:callTalent(self.T_WARP_MINES, "trapPower") * 0.8
		local disarm = self:callTalent(self.T_WARP_MINES, "trapPower")
		return ([[Lay Warp Mines in a radius of 1 that teleport enemies to you and inflict %0.2f physical and %0.2f temporal (warp) damage.
		The mines are hidden traps (%d detection and %d disarm power based on your Magic) and last for %d turns.
		The damage caused by your Warp Mines will improve with your Spellpower.]]):
		format(damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage), detect, disarm, duration)
	end,
}

newTalent{
	name = "Warp Mine Away",
	type = {"chronomancy/other", 1},
	points = 1,
	cooldown = 10,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	tactical = { ATTACKAREA = { TEMPORAL = 1, PHYSICAL = 1 }, ESCAPE = 2  },
	requires_target = true,
	range = function(self, t) return self:callTalent(self.T_WARP_MINES, "getRange") or 5 end,
	no_unlearn_last = true,
	target = function(self, t) return {type="ball", nowarning=true, range=self:getTalentRange(t), radius=1, nolock=true, talent=t} end,	
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local tx, ty = self:getTarget(tg)
		if not tx or not ty then return nil end
		local _ _, tx, ty = self:canProject(tg, tx, ty)
		
		-- Lay the mines in a ball
		local dam = self:spellCrit(self:callTalent(self.T_WARP_MINES, "getDamage"))
		self:project(tg, tx, ty, function(px, py)
			local target_trap = game.level.map(px, py, Map.TRAP)
			if target_trap then return end
			if game.level.map:checkEntity(px, py, Map.TERRAIN, "block_move") then return end
			
			-- Make our mine
			local trap = makeWarpMine(self, t, px, py, "away", dam)
			
			-- Add the mine
			game.level:addEntity(trap)
			trap:identify(true)
			trap:setKnown(self, true)
			game.zone:addEntity(game.level, trap, "trap", px, py)
		end)

		game:playSoundNear(self, "talents/warp")
		
		return true
	end,
	info = function(self, t)
		local damage = self:callTalent(self.T_WARP_MINES, "getDamage")/2
		local duration = self:callTalent(self.T_WARP_MINES, "getDuration")
		local detect = self:callTalent(self.T_WARP_MINES, "trapPower") * 0.8
		local disarm = self:callTalent(self.T_WARP_MINES, "trapPower")
		return ([[Lay Warp Mines in a radius of 1 that teleport enemies away from you and inflict %0.2f physical and %0.2f temporal (warp) damage.
		The mines are hidden traps (%d detection and %d disarm power based on your Magic) and last for %d turns.
		The damage caused by your Warp Mines will improve with your Spellpower.]]):
		format(damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage), detect, disarm, duration) 
	end,
}

newTalent{
	name = "Warp Mines",
	type = {"chronomancy/spacetime-folding", 1},
	points = 5,
	mode = "passive",
	require = chrono_req1,
	getRange = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9, 0.5, 0, 1)) end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 200, getParadoxSpellpower(self, t)) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 6, 10))) end, -- Duration of mines
	trapPower = function(self,t) return math.max(1,self:combatScale(self:getTalentLevel(t) * self:getMag(15, true), 0, 0, 75, 75)) end, -- Used to determine detection and disarm power, about 75 at level 50
	on_learn = function(self, t)
		local lev = self:getTalentLevelRaw(t)
		if lev == 1 then
			self:learnTalent(self.T_WARP_MINE_TOWARD, true, nil, {no_unlearn=true})
			self:learnTalent(self.T_WARP_MINE_AWAY, true, nil, {no_unlearn=true})
		end
	end,
	on_unlearn = function(self, t)
		local lev = self:getTalentLevelRaw(t)
		if lev == 0 then
			self:unlearnTalent(self.T_WARP_MINE_TOWARD)
			self:unlearnTalent(self.T_WARP_MINE_AWAY)
		end
	end,
	info = function(self, t)
		local range = t.getRange(self, t)
		local damage = t.getDamage(self, t)/2
		local detect = t.trapPower(self,t)*0.8
		local disarm = t.trapPower(self,t)
		local duration = t.getDuration(self, t)
		return ([[Learn to lay Warp Mines in a radius of 1.  Warp Mines teleport targets that trigger them either toward you or away from you depending on the type of mine used and inflict %0.2f physical and %0.2f temporal (warp) damage.
		The mines are hidden traps (%d detection and %d disarm power based on your Magic), last for %d turns, and each have a ten turn cooldown.
		Investing in this talent improves the range of all Spacetime Folding talents and the damage caused by your Warp Mines will improve with your Spellpower.
		
		Current Spacetime Folding Range: %d]]):
		format(damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage), detect, disarm, duration, range) --I5
	end,
}

newTalent{
	name = "Spatial Tether",
	type = {"chronomancy/spacetime-folding", 2},
	require = chrono_req2,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 12) end,
	cooldown = 8,
	tactical = { DISABLE = 2 },
	range = function(self, t) return self:callTalent(self.T_WARP_MINES, "getRange") or 5 end,
	requires_target = true,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 1, 2)) end,
	getDuration = function (self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 6, 8))) end,
	getChance = function(self, t) return 15 end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 200, getParadoxSpellpower(self, t)) end,
	target = function(self, t)
		return {type="hit", range=self:getTalentRange(t), talent=t, nowarning=true}
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		local target = game.level.map(x, y, Map.ACTOR)
		if not target then return end
		if game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then return end
		
		-- Tether values
		local power = getParadoxSpellpower(self, t)
		local dest_power = getParadoxSpellpower(self, t, 0.3)
		local dam = self:spellCrit(t.getDamage(self, t))
		local chance = t.getChance(self, t)
		local tg2 = {type="ball", range=0, radius=self:getTalentRadius(t), talent=t, friendlyfire=false}
		
		-- Store the old terrain
		local oe = game.level.map(x, y, Map.TERRAIN+1)
		if (oe and oe:attr("temporary")) or game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then game.logPlayer(self, "You can't place a tether here") return nil end
	
		-- Make our tether
		local tether = mod.class.Object.new{
			old_feat = oe, type = "temporal", subtype = "tether",
			name = self.name:capitalize() .. "'s spatial tether", add_mos = {{image="object/temporal_instability.png"}},
			display = '&', color=colors.LIGHT_BLUE,
			temporary = t.getDuration(self, t), 
			power = power, dest_power = dest_power, chance = chance,
			x = x, y = y, target = target, tg = tg2, dam = dam,
			summoner = self, summoner_gain_exp = true,
			canAct = false,
			energy = {value=0},
			act = function(self)
				self:useEnergy()
				self.temporary = self.temporary - 1
				
				-- Checks for target viability
				local target = self.target
				local tether = target:hasEffect(target.EFF_BEN_TETHER) or target:hasEffect(target.EFF_DET_TETHER)
				local trigger = rng.percent(self.chance * core.fov.distance(self.x, self.y, target.x, target.y))
				
				if game.level and game.level:hasEntity(target) and tether and not target.dead then
					self.temporary = tether.dur
				end

				if game.level and game.level:hasEntity(target) and tether and trigger and not target.dead then
					-- Primary blast, even if the teleport is resisted or fails this triggers

					local tg = self.tg
					tg.start_x, tg.start_y = target.x, target.y
				
					self.summoner.__project_source = self
					self.summoner:project(tg, target.x, target.y, engine.DamageType.WARP, self.dam)
					self.summoner.__project_source = nil
					if core.shader.allow("distort") then
						game.level.map:particleEmitter(target.x, target.y, self.tg.radius, "ball_physical", {radius=self.tg.radius, tx=target.x, ty=target.y})
					end

								
					-- Do we hit?
					local hit = target:hasEffect(target.EFF_BEN_TETHER) or self.summoner:checkHit(self.power, target:combatSpellResist() + (target:attr("continuum_destabilization") or 0), 0, 95) and target:canBe("teleport")
					
					if hit then
						
						-- Can we teleport?
						if not target:teleportRandom(self.x, self.y, 0, 0) then
							game.logSeen(self, "The teleport fizzles!")
						else
							if target:hasEffect(target.EFF_DET_TETHER) then 
								target:setEffect(target.EFF_CONTINUUM_DESTABILIZATION, 100, {power=self.dest_power})
							end
							game:playSoundNear(self, "talents/teleport")
							game.logSeen(target, "#CRIMSON#%s has been yanked back to the tether!", target.name:capitalize())
						end
						
						-- Secondary blast, this occurs as long as the teleport is not resisted, even if it fails, say from Anchor
						local tg = self.tg
						tg.start_x, tg.start_y = target.x, target.y
						
						self.summoner.__project_source = self
						self.summoner:project(tg, target.x, target.y, engine.DamageType.WARP, self.dam)
						self.summoner.__project_source = nil
						if core.shader.allow("distort") then
							game.level.map:particleEmitter(target.x, target.y, tg.radius, "ball_physical", {radius=tg.radius, tx=target.x, ty=target.y})
						end

					else
						game.logSeen(target, "%s resists the teleport!", target.name:capitalize())
					end
					
				end
				
				-- End the effect?
				if self.temporary <= 0 or target.dead or not tether then
					if self.old_feat then game.level.map(self.x, self.y, engine.Map.TERRAIN+1, self.old_feat)
					else game.level.map:remove(self.x, self.y, engine.Map.TERRAIN+1) end
					game.level.map:removeParticleEmitter(self.particles)
					game.nicer_tiles:updateAround(game.level, self.x, self.y)
					game.level:removeEntity(self)
				end
			end,
		}
		
		-- add our tether to the map
		local particle = Particles.new("wormhole", 1, {image="shockbolt/terrain/temporal_instability_blue", speed=1})
		particle.zdepth = 6
		tether.particles = game.level.map:addParticleEmitter(particle, x, y)
		game.level:addEntity(tether)
		game.level.map(x, y, Map.TERRAIN+1, tether)
		game.level.map:updateMap(x, y)
		game:playSoundNear(self, "talents/warp")
		
		-- Dummy timed effect, so players can remove the tether
		if self:reactionToward(target) >= 0 then
			target:setEffect(target.EFF_BEN_TETHER, t.getDuration(self, t), {chance=chance, dam=dam, x=x, y=y})
		else
			target:setEffect(target.EFF_DET_TETHER, t.getDuration(self, t), {chance=chance, dam=dam, x=x, y=y})
		end

		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local chance = t.getChance(self, t)
		local damage = t.getDamage(self, t)/2
		local radius = self:getTalentRadius(t)
		return ([[Tether the target to the location for %d turns.  
		Each turn the target has a %d%% chance per tile it's travelled away from the tether to be teleported back, inflicting %0.2f physical and %0.2f temporal (warp) damage to all enemies in a radius of %d at both the entrance and exit locations.
		The damage will scale with your Spellpower.]])
		:format(duration, chance, damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage), radius)
	end,
}

newTalent{
	name = "Banish",
	type = {"chronomancy/spacetime-folding", 3},
	require = chrono_req3,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 12) end,
	cooldown = 4,
	tactical = { ESCAPE = 2, DISABLE = 2 },
	range = function(self, t) return self:callTalent(self.T_WARP_MINES, "getRange") or 5 end,
	radius = 3,
	getTeleport = function(self, t) return math.floor(self:combatTalentScale(t, 8, 16)) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 2, 4))) end,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), radius=self:getTalentRadius(t), friendlyfire=false, nowarning=true, talent=t}
	end,
	no_energy = true,
	requires_target = true,
	direct_hit = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, _, _, x, y = self:canProject(tg, x, y)

		self:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, Map.ACTOR)
			if not target then return end
			game.level.map:particleEmitter(target.x, target.y, 1, "temporal_teleport")
			if self:checkHit(getParadoxSpellpower(self, t), target:combatSpellResist() + (target:attr("continuum_destabilization") or 0)) and target:canBe("teleport") then
				if not target:teleportRandom(self.x, self.y, t.getTeleport(self, t), t.getTeleport(self, t)/2) then
					game.logSeen(target, "The spell fizzles on %s!", target.name:capitalize())
				else
					target:setEffect(target.EFF_CONTINUUM_DESTABILIZATION, 100, {power=getParadoxSpellpower(self, t, 0.3)})
					game.level.map:particleEmitter(target.x, target.y, 1, "temporal_teleport")
					game.logSeen(target, "#CRIMSON#%s has been banished!", target.name:capitalize())
				end
			else
				game.logSeen(target, "%s resists the banishment!", target.name:capitalize())
			end
			-- random warp
			DamageType:get(DamageType.RANDOM_WARP).projector(self, target.x, target.y, DamageType.RANDOM_WARP, {dur=t.getDuration(self, t), apply_power=getParadoxSpellpower(self, t)})
		end)

		game:playSoundNear(self, "talents/teleport")

		return true
	end,
	info = function(self, t)
		local range = t.getTeleport(self, t)
		local duration = t.getDuration(self, t)
		return ([[Randomly teleports all enemies within a radius of three.  Enemies will be teleported between %d and %d tiles from you and may be stunned, blinded, confused, or pinned for %d turns.
		The chance of teleportion will scale with your Spellpower.]]):format(range / 2, range, duration)
	end,
}

newTalent{
	name = "Dimensional Anchor",
	type = {"chronomancy/spacetime-folding", 4},
	require = chrono_req4,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 20) end,
	cooldown = 10,
	tactical = { DISABLE = 2 },
	range = function(self, t) return self:callTalent(self.T_WARP_MINES, "getRange") or 5 end,
	radius = 3,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 230, getParadoxSpellpower(self, t)) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 6, 10))) end,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), friendlyfire=false, nowarning=true, radius=self:getTalentRadius(t), talent=t}
	end,
	requires_target = true,
	direct_hit = true,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, _, _, x, y = self:canProject(tg, x, y)

		local dam = self:spellCrit(t.getDamage(self, t))
		-- Project our daze and initial anchor, no save on the daze
		self:project(tg, x, y, function(px, py, tg, self)
			local target = game.level.map(px, py, Map.ACTOR)
			if not target then return end
			if target:canBe("stun") then
				target:setEffect(target.EFF_DAZED, 2, {})
			end
			target:setEffect(target.EFF_DIMENSIONAL_ANCHOR, 1, {damage=dam, src=self, dur=1, apply_power=getParadoxSpellpower(self, t), no_ct_effect=true})
		end)

		-- Add a lasting map effect
		local particle = MapEffect.new{zdepth=6, overlay_particle={zdepth=6, only_one=true, type="circle", args={appear=8, oversize=0, img="moon_circle", radius=self:getTalentRadius(t)}}, color_br=255, color_bg=255, color_bb=255, effect_shader="shader_images/magic_effect.png"}
		game.level.map:addEffect(self,
			x, y, t.getDuration(self,t),
			DamageType.DIMENSIONAL_ANCHOR, {dam=dam, src=self, apply=getParadoxSpellpower(self, t)},
			self:getTalentRadius(t),
			5, nil,
			particle,
			nil, false, false
		)

		game:playSoundNear(self, "talents/warp")

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)/2
		local duration = t.getDuration(self, t)
		return ([[Create a radius three anti-teleport field for %d turns and daze all enemies in the area of effect for two turns.
		Enemies attempting to teleport while anchored take %0.2f physical and %0.2f temporal (warp) damage.
		The damage will scale with your Spellpower.]]):format(duration, damDesc(self, DamageType.PHYSICAL, damage), damDesc(self, DamageType.TEMPORAL, damage))
	end,
}