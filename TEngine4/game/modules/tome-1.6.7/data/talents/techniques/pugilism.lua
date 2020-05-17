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

getRelentless = function(self, cd)
	local cd = 1
	if self:knowTalent(self.T_RELENTLESS_STRIKES) then
		local t = self:getTalentFromId(self.T_RELENTLESS_STRIKES)
		cd = 1 - t.getCooldownReduction(self, t)
	end
		return cd
	end,

newTalent{
	name = "Striking Stance",
	type = {"technique/unarmed-other", 1},
	mode = "sustained",
	hide = true,
	points = 1,
	cooldown = 12,
	tactical = { BUFF = 2 },
	type_no_req = true,
	--no_npc_use = true, -- They dont need it since it auto switches anyway
	no_unlearn_last = true,
	getAttack = function(self, t) return self:getDex(25, true) end,
	getDamage = function(self, t) return self:combatStatScale("dex", 25, 60) end,
	getFlatReduction = function(self, t) 
		if self:knowTalent(self.T_REFLEX_DEFENSE) then
			return math.min(35, self:combatStatScale("str", 1, 30, 0.75)) * (1 + (self:callTalent(self.T_REFLEX_DEFENSE, "getFlatReduction")/100) )
		else
			return math.min(35, self:combatStatScale("str", 1, 30, 0.75))
		end	
	end,
	-- 13 Strength = 2, 20 = 5, 30 = 9, 40 = 12, 50 = 16, 55 = 17, 70 = 22, 80 = 25
	activate = function(self, t)
		cancelStances(self)
		local ret = {
			atk = self:addTemporaryValue("combat_atk", t.getAttack(self, t)),
			flat = self:addTemporaryValue("flat_damage_armor", {all = t.getFlatReduction(self, t)})
		}
		return ret
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("combat_atk", p.atk)
		self:removeTemporaryValue("flat_damage_armor", p.flat)
		return true
	end,
	info = function(self, t)
		local attack = t.getAttack(self, t)
		local damage = t.getDamage(self, t)
		return ([[Increases your Accuracy by %d, the damage multiplier of your striking talents (Pugilism and Finishing Moves) by %d%%, and reduces all damage taken by %d.
		The offensive bonuses scale with your Dexterity and the damage reduction with your Strength.]]):
		format(attack, damage, t.getFlatReduction(self, t))
	end,
}

newTalent{
	name = "Double Strike", -- no stamina cost attack that will replace the bump attack under certain conditions
	type = {"technique/pugilism", 1},
	require = techs_dex_req1,
	points = 5,
	random_ego = "attack",
	--cooldown = function(self, t) return math.ceil(3 * getRelentless(self, cd)) end,
	cooldown = 3,
	message = "@Source@ throws two quick punches.",
	tactical = { ATTACK = { weapon = 2 } },
	requires_target = true,
	is_melee = true,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	range = 1,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 0.5, 0.8) + getStrikingStyle(self, dam) end,
	-- Learn the appropriate stance
	on_learn = function(self, t)
		if not self:knowTalent(self.T_STRIKING_STANCE) then
			self:learnTalent(self.T_STRIKING_STANCE, true, nil, {no_unlearn=true})
		end
	end,
	on_unlearn = function(self, t)
		if not self:knowTalent(t) then
			self:unlearnTalent(self.T_STRIKING_STANCE)
		end
	end,
	-- Called by Attack to see if it wants to use this talent.
	can_alternate_attack = function(self, t)
		return self:isTalentActive(self.T_STRIKING_STANCE) and not self:isTalentCoolingDown(t)
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end

		-- force stance change
		if target and not self:isTalentActive(self.T_STRIKING_STANCE) then
			self:forceUseTalent(self.T_STRIKING_STANCE, {ignore_energy=true, ignore_cd = true})
		end

		-- breaks active grapples if the target is not grappled
		local grappled
		if target:isGrappled(self) then
			grappled = true
		else
			self:breakGrapples()
		end

		local hit1 = false
		local hit2 = false

		hit1 = self:attackTarget(target, nil, t.getDamage(self, t), true)
		hit2 = self:attackTarget(target, nil, t.getDamage(self, t), true)

		-- build combo points
		local combo = false

		if self:getTalentLevel(t) >= 4 then
			combo = true
		end

		if combo then
			if hit1 then
				self:buildCombo()
			end
			if hit2 then
				self:buildCombo()
			end
		elseif hit1 or hit2 then
			self:buildCombo()
		end

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t) * 100
		return ([[Deliver two quick punches that deal %d%% damage each, and switch your stance to Striking Stance. If you already have Striking Stance active and Double Strike isn't on cooldown, this talent will automatically replace your normal attacks (and trigger the cooldown).
		If either jab connects, you earn one combo point. At talent level 4 or greater, if both jabs connect, you'll earn two combo points.]])
		:format(damage)
	end,
}



newTalent{
	 name = "Spinning Backhand",
	type = {"technique/pugilism", 2},
	require = techs_dex_req2,
	points = 5,
	random_ego = "attack",
	--cooldown = function(self, t) return math.ceil(12 * getRelentless(self, cd)) end,
	cooldown = 8,
	stamina = 12,
	is_melee = true,
	target = function(self, t) return {type="bolt", range=self:getTalentRange(t)} end,
	range = function(self, t) return math.ceil(2 + self:combatTalentScale(t, 2.2, 4.3)) end, -- being able to use this over rush without massive investment is much more fun
	chargeBonus = function(self, t, dist) return self:combatScale(dist, 0.15, 1, 0.50, 5) end,
	message = "@Source@ lashes out with a spinning backhand.",
	tactical = { ATTACKAREA = { weapon = 2 }, CLOSEIN = 1 },
	requires_target = true,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 1.0, 1.7) + getStrikingStyle(self, dam) end,
	on_pre_use = function(self, t) return not self:attr("never_move") end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end

		-- bonus damage for charging
		local charge = t.chargeBonus(self, t, (core.fov.distance(self.x, self.y, x, y) - 1))
		local damage = t.getDamage(self, t) + charge

		-- do the rush
		local block_actor = function(_, bx, by) return game.level.map:checkEntity(bx, by, Map.TERRAIN, "block_move", self) end
		local l = self:lineFOV(x, y, block_actor)
		local lx, ly, is_corner_blocked = l:step()
		local tx, ty = self.x, self.y
		while lx and ly do
			if is_corner_blocked or game.level.map:checkAllEntities(lx, ly, "block_move", self) then break end
			tx, ty = lx, ly
			lx, ly, is_corner_blocked = l:step()
		end

		local ox, oy = self.x, self.y
		self:move(tx, ty, true)
		if config.settings.tome.smooth_move > 0 then
			self:resetMoveAnim()
			self:setMoveAnim(ox, oy, 8, 5)
		end

		local hit1 = false
		local hit2 = false
		local hit3 = false

		-- do the backhand
		if core.fov.distance(self.x, self.y, x, y) == 1 then
			-- get left and right side
			local dir = util.getDir(x, y, self.x, self.y)
			local lx, ly = util.coordAddDir(self.x, self.y, util.dirSides(dir, self.x, self.y).left)
			local rx, ry = util.coordAddDir(self.x, self.y, util.dirSides(dir, self.x, self.y).right)
			local lt, rt = game.level.map(lx, ly, Map.ACTOR), game.level.map(rx, ry, Map.ACTOR)

			hit1 = self:attackTarget(target, nil, damage, true)

			--left hit
			if lt then
				hit2 = self:attackTarget(lt, nil, damage, true)
			end
			--right hit
			if rt then
				hit3 = self:attackTarget(rt, nil, damage, true)
			end

		end

		-- remove grappls
		self:breakGrapples()

		-- build combo points
		local combo = false

		if self:getTalentLevel(t) >= 4 then
			combo = true
		end

		if hit1 or hit2 or hit3 then
			local a = util.dirToAngle(util.getDir(x, self.y, self.x, y))
			game.level.map:particleEmitter(target.x, target.y, 2, "circle", {appear_size=0, y=0.33, base_rot=90 + a, a=250, appear=6, limit_life=6, speed=0, img="spinning_backhand_on_hit", radius=0})
		end

		if combo then
			if hit1 then
				self:buildCombo()
			end
			if hit2 then
				self:buildCombo()
			end
			if hit3 then
				self:buildCombo()
			end
		elseif hit1 or hit2 or hit3 then
			self:buildCombo()
		end

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t) * 100
		local charge =t.chargeBonus(self, t, t.range(self, t)-1)*100
		return ([[Attack your foes in a frontal arc with a spinning backhand, doing %d%% damage. If you're not adjacent to the target, you'll step forward as you spin, gaining up to %d%% bonus damage, which increases the farther you move.
		This attack will remove any grapples you're maintaining, and earn one combo point (or one combo point per attack that connects, if the talent level is 4 or greater).]])
		:format(damage, charge)
	end,
}

newTalent{
	name = "Axe Kick",
	type = {"technique/pugilism", 3},
	require = techs_dex_req3,
	points = 5,
	stamina = 20,
	random_ego = "attack",
	cooldown = function(self, t)
		return 20
	end,
	getDuration = function(self, t)
		return self:combatTalentLimit(t, 5, 1, 4)
	end,
	is_melee = true,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	range = 1,
	message = "@Source@ raises their leg and snaps it downward in a devastating axe kick.",
	tactical = { ATTACK = { weapon = 2 } },
	requires_target = true,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 0.8, 2) + getStrikingStyle(self, dam) end, -- low damage scaling, investment gets the extra CP
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end

		-- breaks active grapples if the target is not grappled
		if not target:isGrappled(self) then
			self:breakGrapples()
		end

		local hit1 = false

		hit1 = self:attackTarget(target, nil, t.getDamage(self, t), true)

		if hit1 and target:canBe("confusion") then
			target:setEffect(target.EFF_DELIRIOUS_CONCUSSION, t.getDuration(self, t), {})
		end

		-- build combo points
		if hit1 then
			self:buildCombo()
			self:buildCombo()

			local a = util.dirToAngle(util.getDir(target.x, self.y, self.x, target.y))
			game.level.map:particleEmitter(target.x, target.y, 2, "circle", {appear_size=0, base_rot=45 + a, a=250, appear=6, limit_life=4, speed=0, img="axe_kick_on_hit", radius=-0.3})
		end
		return true

	end,
	info = function(self, t)
		local damage = t.getDamage(self, t) * 100
		return ([[Deliver a devastating axe kick dealing %d%% damage. If the blow connects your target is brain damaged, causing all talents to fail for %d turns and earning 2 combo points.
		This effect cannot be saved against, though it can be dodged and checks confusion immunity.]])
		:format(damage, t.getDuration(self, t))
	end,
}

newTalent{
	name = "Flurry of Fists",
	type = {"technique/pugilism", 4},
	require = techs_dex_req4,
	points = 5,
	random_ego = "attack",
	cooldown = 16,
	stamina = 15,
	message = "@Source@ lashes out with a flurry of fists.",
	tactical = { ATTACK = { weapon = 2 } },
	requires_target = true,
	is_melee = true,
	target = function(self, t) return {type="hit", range=self:getTalentRange(t)} end,
	range = 1,
	getDamage = function(self, t) return self:combatTalentWeaponDamage(t, 0.3, 1) + getStrikingStyle(self, dam) end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end

		-- breaks active grapples if the target is not grappled
		if not target:isGrappled(self) then
			self:breakGrapples()
		end

		local hit1 = false
		local hit2 = false
		local hit3 = false

		hit1 = self:attackTarget(target, nil, t.getDamage(self, t), true)
		hit2 = self:attackTarget(target, nil, t.getDamage(self, t), true)
		hit3 = self:attackTarget(target, nil, t.getDamage(self, t), true)

		--build combo points
		local combo = false

		if self:getTalentLevel(t) >= 4 then
			combo = true
		end

		if combo then
			if hit1 then
				self:buildCombo()
			end
			if hit2 then
				self:buildCombo()
			end
			if hit3 then
				self:buildCombo()
			end
		elseif hit1 or hit2 or hit3 then
			self:buildCombo()
		end

		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t) * 100
		return ([[Lashes out at the target with three quick punches that each deal %d%% damage.
		Earns one combo point. If your talent level is 4 or greater, this instead earns one combo point per blow that connects.]])
		:format(damage)
	end,
}
