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

-- EDGE TODO: Particles, Timed Effect Particles

newTalent{
	name = "Rethread",
	type = {"chronomancy/timeline-threading", 1},
	require = chrono_req_high1,
	points = 5,
	cooldown = 4,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	tactical = { ATTACKAREA = {TEMPORAL = 2}},
	range = 10,
	direct_hit = true,
	reflectable = true,
	requires_target = true,
	target = function (self, t)
		return {type="ball", selffire=false, friendlyfire=50, radius=10, range=self:getTalentRange(t), talent = t} -- fake target parameters for ai only, to estimate # targets hit
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 230, getParadoxSpellpower(self, t)) end,
	getTargetCount = function(self, t) return 3 end,
	action = function(self, t)
		local tg = {type="bolt", range=self:getTalentRange(t), talent=t} -- actual target parameters
		local fx, fy = self:getTarget(tg)
		if not fx or not fy then return nil end

		local nb = t.getTargetCount(self, t)
		local affected = {}
		local braid_targets = {}
		local first = nil
		
		self:project(tg, fx, fy, function(dx, dy)
			local actor = game.level.map(dx, dy, Map.ACTOR)
			if actor and not affected[actor] then
				affected[actor] = true
				first = actor

				self:project({type="ball", selffire=false, x=dx, y=dy, radius=10, range=0}, dx, dy, function(bx, by)
					local actor = game.level.map(bx, by, Map.ACTOR)
					if actor and not affected[actor] and self:reactionToward(actor) < 0 then
						affected[actor] = true
					end
				end)
				return true
			end
		end)

		if not first then return end
		local targets = { first }
		affected[first] = nil
		local possible_targets = table.listify(affected)

		for i = 2, nb do
			if #possible_targets == 0 then break end
			local act = rng.tableRemove(possible_targets)
			targets[#targets+1] = act[1]
		end

		local sx, sy = self.x, self.y
		local damage = self:spellCrit(t.getDamage(self, t))
		for i, actor in ipairs(targets) do
			local tgr = {type="beam", range=self:getTalentRange(t), selffire=false, talent=t, x=sx, y=sy}
			self:project(tgr, actor.x, actor.y, function(px, py)
				DamageType:get(DamageType.TEMPORAL).projector(self, px, py, DamageType.TEMPORAL, damage)

				-- Get our braid targets
				local target = game.level.map(px, py, Map.ACTOR)
				if target and not target.dead and self:knowTalent(self.T_BRAID_LIFELINES) then
					braid_targets[#braid_targets+1] = target
				end
			end)

			if core.shader.active() then 
				game.level.map:particleEmitter(sx, sy, math.max(math.abs(actor.x-sx), math.abs(actor.y-sy)), "temporalbeam", {tx=actor.x-sx, ty=actor.y-sy}, {type="lightning"})
			else
				game.level.map:particleEmitter(sx, sy, math.max(math.abs(actor.x-sx), math.abs(actor.y-sy)), "temporalbeam", {tx=actor.x-sx, ty=actor.y-sy}) 
			end
			sx, sy = actor.x, actor.y
		end
		
		-- Braid them
		if #braid_targets > 1 then
			for i = 1, #braid_targets do
				local target = braid_targets[i]
				local t = self:getTalentFromId(self.T_BRAID_LIFELINES)
				target:setEffect(target.EFF_BRAIDED, t.getDuration(self, t), {power=t.getBraid(self, t), src=self, targets=braid_targets})
			end
		end
		
		game:playSoundNear(self, "talents/heal")
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local targets = t.getTargetCount(self, t)
		return ([[Rethread the timeline, dealing %0.2f temporal damage to the target before moving on to a second target.
		Rethread can hit up to %d targets up to 10 grids apart, and will never hit the same one twice; nor will it hit the caster.
		The damage will increase with your Spellpower.]]):
		format(damDesc(self, DamageType.TEMPORAL, damage), targets)
	end,
}

newTalent{
	name = "Temporal Fugue",
	type = {"chronomancy/timeline-threading", 2},
	require = chrono_req_high2,
	points = 5,
	cooldown = 24,
	paradox = function(self, t) return getParadoxCost(self, t, 24) end,
	tactical = { ATTACK = 2, DISABLE = 2 },
	unlearn_on_clone = true,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 3, 8))) end,
	on_pre_use = function(self, t, silent) if self:hasEffect(self.EFF_TEMPORAL_FUGUE) then return false end return true end,
	action = function(self, t)
		local clones = {self}
		
		 -- Clone the caster
		local function makeFugueClone(self, t)
			local m = makeParadoxClone(self, self, t.getDuration(self, t))
			-- Add and change some values
			m.name = self.name.."'s Fugue Clone"
			m.desc = ([[The real %s... or so %s says.]]):format(self.name, self:he_she())
			
			-- Handle some AI stuff
			m.ai_state = { talent_in=1, ally_compassion=10 }
			m.ai_state.tactic_leash = 10
			-- Try to use stored AI talents to preserve tweaking over multiple summons
			m.ai_talents = self.stored_ai_talents and self.stored_ai_talents[m.name] or {}
					
			return m
		end
		
		-- Add our clones
		for i = 1, 2 do
			local tx, ty = util.findFreeGrid(self.x, self.y, 5, true, {[Map.ACTOR]=true})
			if tx and ty then
				-- Make our clone and add to the party
				local m = makeFugueClone(self, t)
				if game.party:hasMember(self) then
					game.party:addMember(m, {
						control="full",
						type="fugue clone",
						title="Fugue Clone",
						orders = {target=true, leash=true, anchor=true, talents=true},
					})
				end
				
				-- and the level
				game.zone:addEntity(game.level, m, "actor", tx, ty)
				game.level.map:particleEmitter(m.x, m.y, 1, "temporal_teleport")
				clones[#clones+1] = m
			end
		end
		
		-- No clones?  Exit the spell
		if #clones < 2 then
			game.logPlayer(self, "Not enough space to summon!")
			return
		end
		
		-- Link them
		for i = 1, #clones do
			local target = clones[i]
			target:setEffect(target.EFF_TEMPORAL_FUGUE, 10, {targets=clones})
		end
		
		game:playSoundNear(self, "talents/spell_generic")
		
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		return ([[For the next %d turns two alternate versions of you enter your timeline.  While the effect is active all damage done by you or your copies is reduced by two thirds and all damage received is split between the three of you.
		Temporal Fugue does not normally cooldown while active.  You may take direct control of your clones, give them orders, and set their talent usage.
		Damage you deal to Fugue Clones or that they deal to you or each other is reduced to zero.]]):
		format(duration)
	end,
}

newTalent{
	name = "Braid Lifelines",
	type = {"chronomancy/timeline-threading", 3},
	require = chrono_req_high3,
	mode = "passive",
	points = 5,
	getBraid = function(self, t) return self:combatTalentSpellDamage(t, 25, 40, getParadoxSpellpower(self, t)) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 3, 7))) end,
	info = function(self, t)
		local braid = t.getBraid(self, t)
		local duration = t.getDuration(self, t)
		return ([[Your Rethread now braids the lifelines of all targets it hits for %d turns.  Braided targets take %d%% of all damage dealt to other braided targets.
		The amount of damage shared will scale with your Spellpower.]])
		:format(duration, braid)
	end
}

newTalent{
	name = "Cease to Exist",
	type = {"chronomancy/timeline-threading", 4},
	require = chrono_req_high4,
	points = 5,
	cooldown = 24,
	paradox = function (self, t) return getParadoxCost(self, t, 24) end,
	range = 10,
	tactical = { ATTACK = 2 },
	requires_target = true,
	no_npc_use = true,
	direct_hit = true,
	getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 5, 9)) end,
	getPower = function(self, t) return self:combatTalentScale(t, 20, 50) end,
	target = function(self, t)
		return {type="hit", range=self:getTalentRange(t), talent=t}
	end,
	on_pre_use = function(self, t, silent)
		if checkTimeline(self) then
			if not silent then
				game.logPlayer(self, "The timeline is too fractured to do this now.")
			end
			return false
		end
		return true
	end,
	do_instakill = function(self, t)
		-- search for target because it's ID will change when the chrono restore takes place
		local target
		for _, act in pairs(game.level.entities) do
			if act.hasEffect and act:hasEffect(act.EFF_CEASE_TO_EXIST) then target = act end
		end
		
		if target then
			game:onTickEnd(function()
				target:removeEffect(target.EFF_CEASE_TO_EXIST)
				game.logSeen(target, "#LIGHT_BLUE#%s never existed, this never happened!", target.name:capitalize())
				target:die(self)
			end)
		end
	end,
	action = function(self, t)
		-- get our target
		local tg = self:getTalentTarget(t)
		local tx, ty = self:getTarget(tg)
		if not tx or not ty then return nil end
		local _ _, tx, ty = self:canProject(tg, tx, ty)
		
		local target = game.level.map(tx, ty, Map.ACTOR)
		if not target then return end

		if target == self then
			game.logSeen(self, "#LIGHT_STEEL_BLUE#%s tries to remove %sself from existance!", self.name, string.his_her(self))
			self:incParadox(400)
			game.level.map:particleEmitter(self.x, self.y, 1, "ball_temporal", {radius=1, tx=self.x, ty=self.y})
			return true
		end
		
		-- does the spell hit?  if not nothing happens
		if not self:checkHit(getParadoxSpellpower(self, t), target:combatSpellResist()) then
			game.logSeen(target, "%s resists!", target.name:capitalize())
			return true
		end
	
		-- Manualy start cooldown before the chronoworld is made
		game.player:startTalentCooldown(t)
		
		-- set up chronoworld next, we'll load it when the target dies in class\actor
		game:onTickEnd(function()
			game:chronoClone("cease_to_exist")
		end)
		
		-- Set our effect
		target:setEffect(target.EFF_CEASE_TO_EXIST, t.getDuration(self,t), {src=self, power=t.getPower(self,t)})
		game:playSoundNear(self, "talents/arcane")
		
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local power = t.getPower(self, t)
		return ([[Over the next %d turns, you attempt to remove the target from the timeline, lowering its resistance to physical and temporal damage by %d%%.
		If you manage to kill the target while the spell is in effect, you'll be returned to the point in time you cast this spell and the target will be slain.
		This spell splits the timeline.  Attempting to use another spell that also splits the timeline while this effect is active will be unsuccessful.
		The resistance penalty will scale with your Spellpower.]])
		:format(duration, power)
	end,
}

-- This was a really cool affect but the game really assumes that the player is on the map
-- I suspect there's a lot of unforseen bugs in this code but I'm leaving it here incase someone else wants to attempt to do something similar in the future
--[=[newTalent{
	name = "Temporal Fugue",
	type = {"chronomancy/timeline-threading", 2},
	require = chrono_req_high2,
	points = 5,
	cooldown = 12,
	paradox = function (self, t) return getParadoxCost(self, t, 15) end,
	tactical = { DISABLE = 3 },
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 4, 8))) end,
	getDamagePenalty = function(self, t) return 80 - self:combatTalentLimit(t, 0, 20, 40)end,
	getClones = function(self, t) return 3 end,
	on_pre_use = function(self, t, silent) if self ~= game.player and self.fugue_clones then return false end return true end,
	action = function(self, t)
		-- If the spell is active cancel the effect	
		if self.fugue_clones then
			for _, e in pairs(game.level.entities) do
				if e.summoner and e.summoner == self.summoner and e.fugue_clones and e ~= self then
					e:die()
				end
			end
			return true
		end
		
		-- Remove the player
		local x, y = self.x, self.y
		game.level.map:particleEmitter(self.x, self.y, 1, "temporal_teleport")
		game.level:removeEntity(self, true)
		
		-- Setup our Fugue Clones
		local fugue_count = 0
		local function makeFugueClone(self, t, x, y)
			local m = makeParadoxClone(self, self, t.getDuration(self, t))
			
			-- Flavor :)
			local sex = self.female and "she" or "he"
			m.name = self.name
			m.desc = [[The real ]]..self.name:capitalize()..[[... or so ]]..sex..[[ says.]]
			m.shader = nil
			m.shader_args = nil
			 
			-- Add and change some values
			m.generic_damage_penalty = t.getDamagePenalty(self, t)
			m.max_life = m.max_life * (100 - t.getDamagePenalty(self, t))/100
			m.life = m.max_life
			m.remove_from_party_on_death = true
			m.timetravel_immune = 1
			
			-- Handle some AI stuff
			m.ai_state = { talent_in=2, ally_compassion=10 }
			
			-- Track clones when we die
			m.on_die = function(self)
				-- If we're the last return the caster
				if self.fugue_clones <= 1 then
					-- don't level up on return
					local old_levelup = self.summoner.forceLevelup
					local old_check = self.summoner.check
					self.summoner.forceLevelup = function() end
					self.summoner.check = function() end
					game.zone:addEntity(game.level, self.summoner, "actor", self.x, self.y)
					self.summoner.forceLevelup = old_levelup
					self.summoner.check = old_check
					if game.party:hasMember(self) then
						game.party:setPlayer(self.summoner)
					end
				else
					-- find fellow clones and update the clone count
					for _, e in pairs(game.level.entities) do
						if e.summoner and e.summoner == self.summoner and e.fugue_clones then
							e.fugue_clones = e.fugue_clones - 1
							if e.fugue_clones <= 1 then
								e.summon_time = 0
							end
						end
					end
				end
				local add_paradox = math.max(0, self:getParadox() - self.summoner:getParadox())
				self.summoner:incParadox(add_paradox/3)
			end
	
			return m
		end
		
		-- Add the primary clone to the game
		local m = makeFugueClone(self, t, x, y)
		if game.party:hasMember(self) then
			game.party:addMember(m, {
				control="full",
				type="fugue clone",
				title="Fugue Clone",
				orders = {target=true},
			})
		end
		game.zone:addEntity(game.level, m, "actor", x, y)
		local fugue_count = 1
		
		-- Swap control to the primary clone
		if game.party:hasMember(self) then
			game.party:setPlayer(m)
			m.summon_time = m.summon_time + 1
		end
		
		m:resetCanSeeCache()
		
		-- Make the rest of our clones
		for i = 1, t.getClones(self, t)-1 do
			local m = makeFugueClone(self, t, x, y)
			
			local poss = {}
			local range = t.getClones(self, t)
			for i = x - range, x + range do
				for j = y - range, y + range do
					if game.level.map:isBound(i, j) and
						core.fov.distance(x, y, i, j) <= range and -- make sure they're within range
						self:canMove(i, j) and self:hasLOS(i, j) then  -- keep them in line of sight
						poss[#poss+1] = {i,j}
					end
				end
			end
			if #poss == 0 then break  end
			local pos = poss[rng.range(1, #poss)]
			tx, ty = pos[1], pos[2]

			-- And add to the party
			if game.party:hasMember(self) then
				game.party:addMember(m, {
					control="full",
					type="fugue clone",
					title="Fugue Clone",
					orders = {target=true},
				})
			end
			
			-- Add us to the level
			game.zone:addEntity(game.level, m, "actor", tx, ty)
			game.level.map:particleEmitter(m.x, m.y, 1, "temporal_teleport")
			fugue_count = fugue_count + 1
		end
		
		-- Add the fugue counter
		for _, e in pairs(game.level.entities) do
			if e.summoner and e.summoner == self then
				e.fugue_clones = fugue_count
			end
		end
		
		game.level.map:particleEmitter(m.x, m.y, 1, "temporal_teleport")
		game:playSoundNear(m, "talents/teleport")
		
		return true
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local damage_penalty = t.getDamagePenalty(self, t)
		return ([[Split yourself into three fugue clones.  The clones have %d%% of your maximum life, deal %d%% less damage, and last %d turns.
		Each clone that dies will increase your Paradox by 33%% of the difference between its Paradox and your own.  This will never reduce your Paradox.
		When only one clone is left, or if you cast the spell while in the fugue state, the spell will end, returning you to the position of the last active clone.
		The life and damage penalties will be reduced by your Spellpower.]]):
		format(100 - damage_penalty, damage_penalty, duration)
	end,
}]=]--