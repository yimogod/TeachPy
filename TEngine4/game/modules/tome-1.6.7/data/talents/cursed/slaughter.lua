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

local Stats = require "engine.interface.ActorStats"

newTalent{
	name = "Slash",
	type = {"cursed/slaughter", 1},
	require = cursed_str_req1,
	points = 5,
	cooldown = 8,
	hate = 2,
	tactical = { ATTACK = { PHYSICAL = 2 } },
	requires_target = true,
	is_melee = true,
	range = 1,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t), talent=t} end,
	-- note that EFF_CURSED_WOUND in mod.data.timed_effects.physical.lua has a cap of -75% healing per application
	getDamageMultiplier = function(self, t, hate) 
		return 1 + self:combatTalentIntervalDamage(t, "str", 0.3, 1.5, 0.4) * getHateMultiplier(self, 0.3, 1, false, hate)
	end,
	getHealFactorChange = function(self, t)
		local level = math.max(3 * self:getTalentTypeMastery(t.type[1]), self:getTalentLevel(t))
		return -self:combatLimit(math.max(0,(level-2)^0.5), 1.5, 0, 0, 0.39, 1.73)  -- Limit < -150%
	end,
	getWoundDuration = function(self, t)
		return 15
	end,
	on_pre_use = function(self, t, silent) if not self:hasMHWeapon() then if not silent then game.logPlayer(self, "You require a mainhand weapon to use this talent.") end return false end return true end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end

		local damageMultiplier = t.getDamageMultiplier(self, t)

		-- We need to alter behavior slightly to accomodate shields since they aren't used in attackTarget
		local shield, shield_combat = self:hasShield()
		local weapon = self:hasMHWeapon() and self:hasMHWeapon().combat or self.combat
		local hit = false
		if not shield then
			hit = self:attackTarget(target, nil, damageMultiplier, true)
		else
			hit = self:attackTargetWith(target, weapon, nil, damageMultiplier)
			if self:attackTargetWith(target, shield_combat, nil, damageMultiplier) or hit then hit = true end
		end
		if hit and not target.dead then
			local level = self:getTalentLevel(t)
			if target:canBe("cut") and level >= 3 then
				local healFactorChange = t.getHealFactorChange(self, t)
				local woundDuration = t.getWoundDuration(self, t)
				target:setEffect(target.EFF_CURSED_WOUND, woundDuration, { healFactorChange=healFactorChange, totalDuration=woundDuration })
			end
		end

		return true
	end,
	info = function(self, t)
		local healFactorChange = t.getHealFactorChange(self, t)
		local woundDuration = t.getWoundDuration(self, t)
		return ([[You slash wildly at your target for %d%% (at 0 Hate) to %d%% (at 100+ Hate) damage.
		At level 3, any wound you inflict with this carries a part of your curse, reducing the effectiveness of healing by %d%% for %d turns. The effect will stack.
		The damage multiplier increases with your Strength.

		This talent will also attack with your shield, if you have one equipped.]]):format(t.getDamageMultiplier(self, t, 0) * 100, t.getDamageMultiplier(self, t, 100) * 100, -healFactorChange * 100, woundDuration)
	end,
}

newTalent{
	name = "Frenzy",
	type = {"cursed/slaughter", 2},
	require = cursed_str_req2,
	points = 5,
	tactical = { ATTACKAREA = { PHYSICAL = 2 } },
	is_melee = true,
	random_ego = "attack",
	cooldown = 12,
	hate = 2,
	getDamageMultiplier = function(self, t, hate)
		return self:combatTalentIntervalDamage(t, "str", 0.25, 0.8, 0.4) * getHateMultiplier(self, 0.5, 1, false, hate)
	end,
	getDefenseChange = function(self, t)
		return self:combatTalentIntervalDamage(t, "str", 6, 45)
	end,
	range = 0,
	radius = 1,
	target = function(self, t)
		return {type="ball", range=self:getTalentRange(t), selffire=false, radius=self:getTalentRadius(t)}
	end,
	on_pre_use = function(self, t, silent) if not self:hasMHWeapon() then if not silent then game.logPlayer(self, "You require a mainhand weapon to use this talent.") end return false end return true end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)

		local targets = {}
		self:project(tg, self.x, self.y, function(px, py, tg, self)
			local target = game.level.map(px, py, Map.ACTOR)
			if target and self:reactionToward(target) < 0 then
				targets[#targets+1] = target
			end
		end)

		if #targets <= 0 then return nil end

		local damageMultiplier = t.getDamageMultiplier(self, t)
		local defenseChange = t.getDefenseChange(self, t)

		local effStalker = self:hasEffect(self.EFF_STALKER)
		if effStalker and core.fov.distance(self.x, self.y, effStalker.target.x, effStalker.target.y) > 1 then effStalker = nil end
		for i = 1, 4 do
			local target
			if effStalker and not effStalker.target.dead then
				target = effStalker.target
			else
				target = rng.table(targets)
			end

			-- We need to alter behavior slightly to accomodate shields since they aren't used in attackTarget
			local shield, shield_combat = self:hasShield()
			local weapon = self:hasMHWeapon() and self:hasMHWeapon().combat or self.combat
			local hit = false
			if not shield then
				hit = self:attackTarget(target, nil, damageMultiplier, true)
			else
				hit = self:attackTargetWith(target, weapon, nil, damageMultiplier)
				if self:attackTargetWith(target, shield_combat, nil, damageMultiplier) or hit then hit = true end
			end

			if hit and self:getTalentLevel(t) >= 3 and not target:hasEffect(target.EFF_OVERWHELMED) then
				target:setEffect(target.EFF_OVERWHELMED, 4, {src=self, defenseChange=defenseChange})
			end
		end

		return true
	end,
	info = function(self, t)
		local defenseChange = t.getDefenseChange(self, t)
		return ([[Assault nearby foes with 4 fast attacks for %d%% (at 0 Hate) to %d%% (at 100+ Hate) damage each. Stalked prey are always targeted if nearby.
		At level 3 the intensity of your assault overwhelms anyone who is struck, reducing their Defense by %d for 4 turns.
		The damage multiplier and Defense reduction increase with your Strength.

		This talent will also attack with your shield, if you have one equipped.]]):format(t.getDamageMultiplier(self, t, 0) * 100, t.getDamageMultiplier(self, t, 100) * 100, -defenseChange)
	end,
}

newTalent{
	name = "Reckless Charge",
	type = {"cursed/slaughter", 3},
	require = cursed_str_req3,
	points = 5,
	random_ego = "attack",
	cooldown = 15,
	hate = 5,
	range = function(self, t) return math.floor(self:combatTalentScale(t, 4, 8)) end,
	tactical = { CLOSEIN = 2 },
	is_melee = true,
	requires_target = true,
	getDamageMultiplier = function(self, t, hate)
		return 0.7 * getHateMultiplier(self, 0.5, 1, false, hate)
		--return self:combatTalentIntervalDamage(t, "str", 0.8, 1.7, 0.4) * getHateMultiplier(self, 0.5, 1, false, hate)
	end,
	getMaxAttackCount = function(self, t) return math.floor(self:combatTalentScale(t, 2, 6, "log")) end,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t), nolock=true} end,
	action = function(self, t)
		local targeting = self:getTalentTarget(t)
		local targetX, targetY, actualTarget = self:getTarget(targeting)
		if not self:canProject(targeting, targetX, targetY) then return nil end

		local block_actor = function(_, bx, by) return game.level.map:checkEntity(bx, by, Map.TERRAIN, "block_move", target) end
		local lineFunction = core.fov.line(self.x, self.y, targetX, targetY, block_actor)
		local nextX, nextY, is_corner_blocked = lineFunction:step()
		local currentX, currentY = self.x, self.y

		local attackCount = 0
		local maxAttackCount = t.getMaxAttackCount(self, t)

		while nextX and nextY and not is_corner_blocked do
			local blockingTarget = game.level.map(nextX, nextY, Map.ACTOR)
			if blockingTarget and self:reactionToward(blockingTarget) < 0 then
				-- attempt a knockback
				local level = self:getTalentLevelRaw(t)
				local maxSize = 2
				if level >= 5 then
					maxSize = 4
				elseif level >= 3 then
					maxSize = 3
				end

				local blocked = true
				if blockingTarget.size_category <= maxSize then
					if blockingTarget:checkHit(self:combatPhysicalpower(), blockingTarget:combatPhysicalResist(), 0, 95, 15) and blockingTarget:canBe("knockback") then
						blockingTarget:crossTierEffect(blockingTarget.EFF_OFFBALANCE, self:combatPhysicalpower())
						-- determine where to move the target (any adjacent square that isn't next to the attacker)
						local start = rng.range(0, 8)
						for i = start, start + 8 do
							local x = nextX + (i % 3) - 1
							local y = nextY + math.floor((i % 9) / 3) - 1
							if core.fov.distance(currentY, currentX, x, y) > 1
									and game.level.map:isBound(x, y)
									and not game.level.map:checkAllEntities(x, y, "block_move", self) then
								blockingTarget:move(x, y, true)
								self:logCombat(blockingTarget, "#Source# knocks back #Target#!")
								blocked = false
								break
							end
						end
					end
				end

				if blocked then
					self:logCombat(blockingTarget, "#Target# blocks #Source#!")
				end
			end

			-- check that we can move
			if not game.level.map:isBound(nextX, nextY) or game.level.map:checkAllEntities(nextX, nextY, "block_move", self) then break end

			-- allow the move
			currentX, currentY = nextX, nextY
			nextX, nextY, is_corner_blocked = lineFunction:step()

			-- attack adjacent targets
			for i = 0, 8 do
				local x = currentX + (i % 3) - 1
				local y = currentY + math.floor((i % 9) / 3) - 1
				local target = game.level.map(x, y, Map.ACTOR)
				if target and self:reactionToward(target) < 0 and attackCount < maxAttackCount then
					local damageMultiplier = t.getDamageMultiplier(self, t)
					self:attackTarget(target, nil, damageMultiplier, true)
					attackCount = attackCount + 1

					game.level.map:particleEmitter(x, y, 1, "blood", {})
					game:playSoundNear(self, "actions/melee")
				end
			end
		end

		self:move(currentX, currentY, true)

		return true
	end,
	info = function(self, t)
		local level = self:getTalentLevelRaw(t)
		local maxAttackCount = t.getMaxAttackCount(self, t)
		local size
		if level >= 5 then
			size = "Big"
		elseif level >= 3 then
			size = "Medium-sized"
		else
			size = "Small"
		end
		return ([[Charge through your opponents, attacking anyone near your path for %d%% (at 0 Hate) to %d%% (at 100+ Hate) damage. %s opponents may be knocked away from your path. You can attack a maximum of %d times, and can hit targets along your path more than once.]]):format(t.getDamageMultiplier(self, t, 0) * 100, t.getDamageMultiplier(self, t, 100) * 100, size, maxAttackCount)
	end,
}

--newTalent{
--	name = "Cleave",
--	type = {"cursed/slaughter", 4},
--	mode = "passive",
--	require = cursed_str_req4,
--	points = 5,
--	on_attackTarget = function(self, t, target, multiplier)
--		if inCleave then return end
--		inCleave = true
--
--		local chance = 28 + self:getTalentLevel(t) * 7
--		if rng.percent(chance) then
--			local start = rng.range(0, 8)
--			for i = start, start + 8 do
--				local x = self.x + (i % 3) - 1
--				local y = self.y + math.floor((i % 9) / 3) - 1
--				local secondTarget = game.level.map(x, y, Map.ACTOR)
--				if secondTarget and secondTarget ~= target and self:reactionToward(secondTarget) < 0 then
--					local multiplier = multiplier or 1 * self:combatTalentWeaponDamage(t, 0.2, 0.7) * getHateMultiplier(self, 0.5, 1.0, false)
--					game.logSeen(self, "%s cleaves through another foe!", self.name:capitalize())
--					self:attackTarget(secondTarget, nil, multiplier, true)
--					inCleave = false
--					return
--				end
--			end
--		end
--		inCleave = false
--
--	end,
--	info = function(self, t)
--		local chance = 28 + self:getTalentLevel(t) * 7
--		local multiplier = self:combatTalentWeaponDamage(t, 0.2, 0.7)
--		return ([[Every swing of your weapon has a %d%% chance of striking a second target for %d%% (at 0 Hate) to %d%% (at 100+ Hate) damage.]]):format(chance, multiplier * 50, multiplier * 100)
--	end,
--}

newTalent{
	name = "Cleave",
	type = {"cursed/slaughter", 4},
	mode = "sustained",
	require = cursed_str_req4,
	points = 5,
	cooldown = 6,
	no_energy = true,
	getDamageMultiplier = function(self, t, hate)
		local damageMultiplier = self:combatLimit(self:getTalentLevel(t) * self:getStr()*getHateMultiplier(self, 0.5, 1.0, false, hate), 1, 0, 0, 0.79, 500) -- Limit < 100%
		if self:hasTwoHandedWeapon() then
			damageMultiplier = damageMultiplier + 0.25
		end
		return damageMultiplier
	end,
	preUseTalent = function(self, t)
		-- prevent AI's from activating more than 1 talent
		if self ~= game.player and (self:isTalentActive(self.T_SURGE) or self:isTalentActive(self.T_REPEL)) then return false end
		return true
	end,
	sustain_slots = 'cursed_combat_style',
	activate = function(self, t)
		-- Place other talents on cooldown.
		if self:knowTalent(self.T_SURGE) and not self:isTalentActive(self.T_SURGE) then
			local tSurge = self:getTalentFromId(self.T_SURGE)
			self.talents_cd[self.T_SURGE] = tSurge.cooldown
		end

		if self:knowTalent(self.T_REPEL) and not self:isTalentActive(self.T_REPEL) then
			local tRepel = self:getTalentFromId(self.T_REPEL)
			self.talents_cd[self.T_REPEL] = tRepel.cooldown
		end

		return {
			luckId = self:addTemporaryValue("inc_stats", { [Stats.STAT_LCK] = -3 })
		}
	end,
	deactivate = function(self, t, p)
		if p.luckId then self:removeTemporaryValue("inc_stats", p.luckId) end

		return true
	end,
	on_attackTarget = function(self, t, target)
		if self.inCleave then return end
		self.inCleave = true
			local start = rng.range(0, 8)
			for i = start, start + 8 do
				local x = self.x + (i % 3) - 1
				local y = self.y + math.floor((i % 9) / 3) - 1
				local secondTarget = game.level.map(x, y, Map.ACTOR)
				if secondTarget and secondTarget ~= target and self:reactionToward(secondTarget) < 0 then
					local damageMultiplier = t.getDamageMultiplier(self, t)
					self:logCombat(secondTarget, "#Source# cleaves through #Target#!")
					self:attackTarget(secondTarget, nil, damageMultiplier, true)
					self.inCleave = false
					return
				end
			end
		self.inCleave = false
	end,
	info = function(self, t)
		return ([[While active, every swing of your weapon strikes strikes other adjacent enemies for %d%% (at 0 hate) to %d%% (at 100 hate) physical damage. The recklessness of your attacks brings you bad luck (luck -3).
		Cleave, Repel and Surge cannot be active simultaneously, and activating one will place the others in cooldown.
		Cleave will deal 25%% additional damage while using a two-handed weapon.
		The Cleave damage increases with your Strength.]]):
		format( t.getDamageMultiplier(self, t, 0) * 100, t.getDamageMultiplier(self, t, 100) * 100)
	end,
}
