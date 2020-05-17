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
	name = "Skate",
	type = {"psionic/augmented-mobility", 1},
	require = psi_wil_req1,
	points = 5,
	mode = "sustained",
	cooldown = 0,
	sustain_psi = 10,
	no_energy = true,
	tactical = { SELF = { ESCAPE = 1 }, CLOSEIN = 1},
	getSpeed = function(self, t) return self:combatTalentScale(t, 0.2, 0.5, 0.75) end,
	getKBVulnerable = function(self, t) return 1 - self:combatTalentLimit(t, 1, 0.3, 0.7) end,
	activate = function(self, t)
		return {
			speed = self:addTemporaryValue("movement_speed", t.getSpeed(self, t)),
			knockback = self:addTemporaryValue("knockback_immune", -t.getKBVulnerable(self, t))
		}
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("movement_speed", p.speed)
		self:removeTemporaryValue("knockback_immune", p.knockback)
		return true
	end,
	info = function(self, t)
		return ([[You telekinetically float just off the ground.
		This allows you to slide around the battle quickly, increasing your movement speed by %d%%.
		It also makes you more vulnerable to being pushed around (-%d%% knockback resistance).]]):
		format(t.getSpeed(self, t)*100, t.getKBVulnerable(self, t)*100)
	end,
}

newTalent{
	name = "Quick as Thought",
	type = {"psionic/augmented-mobility", 2},
	require = psi_wil_req2,
	points = 5,
	random_ego = "utility",
	cooldown = 20,
	psi = 30,
	no_energy = true,
	tactical = { BUFF = 2 },
	getDuration = function(self, t) return math.floor(self:combatLimit(self:combatMindpower(0.1), 10, 4, 0, 6, 6)) end, -- Limit < 10
	speed = function(self, t) return self:combatTalentScale(t, 0.1, 0.4, 0.75) end,
	getBoost = function(self, t)
		return self:combatScale(self:combatTalentMindDamage(t, 20, 60), 0, 0, 50, 100, 0.75)
	end,
	action = function(self, t)
		self:setEffect(self.EFF_QUICKNESS, t.getDuration(self, t), {power=t.speed(self, t)})
		self:setEffect(self.EFF_CONTROL, t.getDuration(self, t), {power=t.getBoost(self, t)})
		return true
	end,
	info = function(self, t)
		local inc = t.speed(self, t)
		local percentinc = 100 * inc
		local boost = t.getBoost(self, t)
		return ([[Encase your body in a sheath of thought-quick forces, allowing you to control your body's movements directly without the inefficiency of dealing with crude mechanisms like nerves and muscles.
		Increases Accuracy by %d, your critical strike chance by %0.1f%% and your global speed by %d%% for %d turns.
		The duration improves with your Mindpower.]]):
		format(boost, 0.5*boost, percentinc, t.getDuration(self, t))
	end,
}

newTalent{
	name = "Mindhook",
	type = {"psionic/augmented-mobility", 3},
	require = psi_wil_req3,
	cooldown = function(self, t) return math.ceil(self:combatTalentLimit(t, 5, 18, 10)) end, -- Limit to >5
	psi = 10,
	points = 5,
	tactical = { CLOSEIN = 2 },
	range = function(self, t) return math.floor(self:combatTalentLimit(t, 10, 3, 7)) end, -- Limit base range to 10
	target = function(self, t) return {type="bolt", range=self:getTalentRange(t)} end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		local target = game.level.map(x, y, engine.Map.ACTOR)
		if not target then
			game.logPlayer(self, "The target is out of range")
			return
		end
		target:pull(self.x, self.y, tg.range)
		target:setEffect(target.EFF_DAZED, 1, {apply_power=self:combatMindpower()})
		game:playSoundNear(self, "talents/arcane")

		return true
	end,
	info = function(self, t)
		local range = self:getTalentRange(t)
		return ([[Briefly extend your telekinetic reach to grab an enemy and haul them towards you.
		Works on enemies up to %d squares away.
		The cooldown decreases, and the range increases, with additional talent points spent.]]):
		format(range)
	end,
}

newTalent{
	name = "Telekinetic Leap",
	type = {"psionic/augmented-mobility", 4},
	require = psi_wil_req4,
	cooldown = 15,
	psi = 10,
	points = 5,
	tactical = { SELF = { ESCAPE = 1 }, CLOSEIN = 2},
	range = function(self, t)
		return math.floor(math.max(1, self:combatTalentLimit(t, 10, 2, 7.5))) -- Limit < 10
	end,
	message = "@Source@ performs a telekinetically enhanced leap!",
	target = function(self, t)
		local range=self:getTalentRange(t)
		local tg = {talent=t, type="hit", nolock=true, pass_terrain=false, nowarning=true, range=range}
		if not self.player then
			tg.grid_params = {want_range=self.ai_state.tactic == "escape" and self:getTalentCooldown(t) + 11 or self.ai_tactic.safe_range or 0, max_delta=-1}
		end
		return tg
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTargetLimitedWallStop(tg)
		if not x then return end
		if x == self.x and y == self.y then return end
		if target then game.logPlayer(self, "You can not jump onto a creature.") return end
		
		return self:move(x, y, true)
	end,
	info = function(self, t)
		local range = self:getTalentRange(t)
		return ([[You perform a precise, telekinetically-enhanced leap, landing up to %d squares from your starting point.]]):
		format(range)
	end,
}
