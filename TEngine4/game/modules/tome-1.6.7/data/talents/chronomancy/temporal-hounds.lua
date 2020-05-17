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

-- Ode to Angband/Tome 2 and all the characters I lost to Time Hounds
summonTemporalHound = function(self, t)  
	if game.zone.wilderness then return false end
	if self.summoner then return false end
	if not game.level then return false end
	local x, y = util.findFreeGrid(self.x, self.y, 8, true, {[Map.ACTOR]=true})
	if not x then
		return false
	end
	
	local m = require("mod.class.NPC").new{
		type = "animal", subtype = "canine",
		display = "C", color=colors.LIGHT_DARK, image = ("npc/temp_hound_0%d.png"):format(rng.range(1, 12)),
		shader = "shadow_simulacrum", shader_args = { color = {0.4, 0.4, 0.1}, base = 0.8, time_factor = 1500 },
		name = "temporal hound", faction = self.faction,
		desc = [[A trained hound that appears to be all at once a little puppy and a toothless old dog.]],
		sound_moam = {"creatures/wolves/wolf_hurt_%d", 1, 2}, sound_die = {"creatures/wolves/wolf_hurt_%d", 1, 1},
		
		autolevel = "none",
		ai = "summoned", ai_real = "tactical", ai_state = { ai_move="move_complex", talent_in=5, }, -- Temporal Hounds are smart but have no talents of their own
		stats = {str=0, dex=0, con=0, cun=0, wil=0, mag=0},
		inc_stats = t.incStats(self, t),
		level_range = {self.level, self.level}, exp_worth = 0,
		global_speed_base = 1.2,
		
		no_auto_resists = true,

		max_life = 50,
		life_rating = 12,
		infravision = 10,

		combat_armor = 2, combat_def = 4,
		combat = { dam=self:getTalentLevel(t) * 10, atk=10, apr=10, dammod={str=0.8, mag=0.8}, damtype=DamageType.WARP, sound="creatures/wolves/wolf_attack_1" },
		
		summoner = self, summoner_gain_exp=true,
		resolvers.sustains_at_birth(),
	}
	
	m.unused_stats = 0
	m.unused_talents = 0
	m.unused_generics = 0
	m.unused_talents_types = 0
	m.no_inventory_access = true
	m.no_points_on_levelup = true
	
	-- Never flee
	m.ai_tactic = m.ai_tactic or {}
	m.ai_tactic.escape = 0

	m:resolve()
	m:resolve(nil, true)
	
	-- Gain damage, resistances, and immunities
	m.inc_damage = table.clone(self.inc_damage, true)
	m.resists = { [DamageType.PHYSICAL] = t.getResists(self, t)/2, [DamageType.TEMPORAL] = math.min(100, t.getResists(self, t)*2) }
	if self:knowTalent(self.T_COMMAND_BLINK) then
		m:attr("defense_on_teleport", self:callTalent(self.T_COMMAND_BLINK, "getDefense"))
		m:attr("resist_all_on_teleport", self:callTalent(self.T_COMMAND_BLINK, "getDefense"))
	end
	if self:knowTalent(self.T_TEMPORAL_VIGOUR) then
		m:attr("stun_immune", self:callTalent(self.T_TEMPORAL_VIGOUR, "getImmunities"))
		m:attr("blind_immune", self:callTalent(self.T_TEMPORAL_VIGOUR, "getImmunities"))
		m:attr("pin_immune", self:callTalent(self.T_TEMPORAL_VIGOUR, "getImmunities"))
		m:attr("confusion_immune", self:callTalent(self.T_TEMPORAL_VIGOUR, "getImmunities"))
	end
	if self:knowTalent(self.T_COMMAND_BREATHE) then
		m.damage_affinity = { [DamageType.TEMPORAL] = self:callTalent(self.T_COMMAND_BREATHE, "getResists") }
	end
	
	-- Quality of life stuff
	m.life_regen = 1
	m.lite = 1
	m.no_breath = 1
	m.move_others = true
	
	-- Hounds are immune to hostile teleports, mostly so they don't get in the way of banish
	m.teleport_immune = 1
	
	-- Make sure to update sustain counter when we die
	m.on_die = function(self)
		if not self.summoner then return end
		local p = self.summoner:isTalentActive(self.summoner.T_TEMPORAL_HOUNDS)
		local tid = self.summoner:getTalentFromId(self.summoner.T_TEMPORAL_HOUNDS)
		if p then
			if p.rest_count == 0 then p.rest_count = self.summoner:getTalentCooldown(tid) end
		end
	end
	-- Make sure hounds stay close
	m.on_act = function(self)
		if not self.summoner then return end
		local x, y = self.summoner.x, self.summoner.y
		if game.level:hasEntity(self.summoner) and core.fov.distance(self.x, self.y, x, y) > 10 then
			-- Clear it's targeting on teleport
			if self:teleportRandom(x, y, 0) then
				game.level.map:particleEmitter(x, y, 1, "temporal_teleport")
				self:setTarget(nil)
			end
		end
		-- clean up
		if self.summoner.dead or not game.level:hasEntity(self.summoner) then
			self:die(self)
		end
	end
	-- Unravel?
	m.on_takehit = function(self, value, src)
		if not self.summoner then return end
		if value >= self.life and self.summoner:knowTalent(self.summoner.T_TEMPORAL_VIGOUR) then
			self.summoner:callTalent(self.summoner.T_TEMPORAL_VIGOUR, "doUnravel", self, value)
		end
		return value
	end,
	
	-- Make it look and sound nice :)
	game.zone:addEntity(game.level, m, "actor", x, y)
	game.level.map:particleEmitter(x, y, 1, "temporal_teleport")
	game:playSoundNear(self, "creatures/wolves/wolf_howl_3")
	
	-- And add them to the party
	if game.party:hasMember(self) then
		m.remove_from_party_on_death = true
		game.party:addMember(m, {
			control="no",
			type="hound",
			title="temporal-hound",
			orders = {target=true, leash=true, anchor=true, talents=true},
		})
	end
	
end

countHounds = function(self)
	local hounds = 0
	if not game.level then return 0 end
	for _, e in pairs(game.level.entities) do
		if e and e.summoner and e.summoner == self and e.name == "temporal hound" then 
			hounds = hounds + 1 
		end
	end
	return hounds
end

newTalent{
	name = "Temporal Hounds",
	type = {"chronomancy/temporal-hounds", 1},
	require = chrono_req_high1,
	mode = "sustained",
	points = 5,
	sustain_paradox = 48,
	no_sustain_autoreset = true,
	unlearn_on_clone = true,
	cooldown = function(self, t) return math.ceil(self:combatTalentLimit(t, 10, 45, 15)) end, -- Limit >10
	tactical = { BUFF = 2 },
	callbackOnActBase = function(self, t)
		local p = self:isTalentActive(t.id)
		if p.rest_count > 0 then p.rest_count = p.rest_count - 1 end
		if p.rest_count == 0 then
			local hounds = countHounds(self)
			if hounds < p.max_hounds then
				summonTemporalHound(self, t)
				p.rest_count = self:getTalentCooldown(t)
			end
		end
	end,
	iconOverlay = function(self, t, p)
		local val = p.rest_count or 0
		if val <= 0 then return "" end
		local fnt = "buff_font"
		return tostring(math.ceil(val)), fnt
	end,
	incStats = function(self, t,fake)
		local mp = self:combatTalentStatDamage(t, "mag", 10, 150) -- Uses magic to avoid Paradox cheese
		return {
			str=10 + (fake and mp or mp),
			dex=10 + (fake and mp or mp),
			con=10 + (fake and mp or mp),
			mag=10 + (fake and mp or mp),
			wil=10 + (fake and mp or mp),
			cun=10 + (fake and mp or mp),
		}
	end,
	getResists = function(self, t)
		return self:combatTalentLimit(t, 100, 15, 50) -- Limit <100%
	end,
	activate = function(self, t)
		-- Let loose the hounds of war!
		summonTemporalHound(self, t)
		
		return {
			rest_count = self:getTalentCooldown(t), 
			max_hounds = 3
		}
	end,
	deactivate = function(self, t, p)
		-- unsummon the hounds :(
		if game.party:hasMember(self) then
			for i, e in ripairs(game.party.m_list) do
				if e and e.summoner and e.summoner == self and e.name == "temporal hound" then
					e.summon_time = 0
					game.party:removeMember(e, true)
				end
			end
		end
		for _, e in pairs(game.level.entities) do
			if e and e.summoner and e.summoner == self and e.name == "temporal hound" then
				e.summon_time = 0
			end
		end
		return true
	end,
	info = function(self, t)
		local incStats = t.incStats(self, t, true)
		local cooldown = self:getTalentCooldown(t)
		local resists = t.getResists(self, t)
		return ([[Upon activation summon a Temporal Hound.  Every %d turns another hound will be summoned, up to a maximum of three hounds. If a hound dies you'll summon a new hound in %d turns.  
		Your hounds inherit your increased damage percent, have %d%% physical resistance and %d%% temporal resistance, and are immune to teleportation effects.
		Hounds will get, %d Strength, %d Dexterity, %d Constitution, %d Magic, %d Willpower, and %d Cunning, based on your Magic stat.]])
		:format(cooldown, cooldown, resists/2, math.min(100, resists*2), incStats.str + 1, incStats.dex + 1, incStats.con + 1, incStats.mag + 1, incStats.wil +1, incStats.cun + 1)
	end
}

newTalent{
	name = "Command Hounds: Blink", short_name="COMMAND_BLINK",
	type = {"chronomancy/temporal-hounds", 2},
	require = chrono_req_high2,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 10,
	tactical = { ATTACK=2 },
	range = function(self, t) return math.floor(self:combatTalentScale(t, 5, 10, 0.5, 0, 1)) end,
	requires_target = true,
	on_pre_use = function(self, t, silent)
		local p = self:isTalentActive(self.T_TEMPORAL_HOUNDS)
		if not p then
			if not silent then
				game.logPlayer(self, "Temporal Hounds must be sustained to cast this spell.")
			end
			return false
		end
		return true
	end,
	target = function(self, t)
		return {type="hit", range=self:getTalentRange(t), nolock=true, nowarning=true}
	end,
	direct_hit = true,
	getDefense = function(self, t)
		return self:combatTalentSpellDamage(t, 10, 40, getParadoxSpellpower(self, t))
	end,
	action = function(self, t)
		-- Pick our target
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not x or not y then return nil end
		if not self:hasLOS(x, y) or game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then
			game.logPlayer(self, "You do not have line of sight.")
			return nil
		end
		local __, x, y = self:canProject(tg, x, y)
	
		-- Summon a new Hound
		if self:getTalentLevel(t) >=5 then
			local p = self:isTalentActive(self.T_TEMPORAL_HOUNDS)
			local talent = self:getTalentFromId(self.T_TEMPORAL_HOUNDS)
			if countHounds(self) < p.max_hounds then
				summonTemporalHound(self, talent)
			end
		end
	
		-- Find our hounds
		local hnds = {}
		for _, e in pairs(game.level.entities) do
			if e.summoner and e.summoner == self and e.name == "temporal hound" then
				hnds[#hnds+1] = e
			end
		end
		
		-- Blink our hounds
		for i = 1, #hnds do
			if #hnds <= 0 then return nil end
			local a, id = rng.table(hnds)
			table.remove(hnds, id)
			
			game.level.map:particleEmitter(a.x, a.y, 1, "temporal_teleport")
			
			if a:teleportRandom(x, y, 0) then
				if self:knowTalent(self.T_TEMPORAL_VIGOUR) then
					self:callTalent(self.T_TEMPORAL_VIGOUR, "doBlink", a)
				end
				
				game.level.map:particleEmitter(a.x, a.y, 1, "temporal_teleport")
			else
				game.logSeen(self, "The spell fizzles!")
			end
			
			-- Set the target so we feel like a wolf pack
			if target and self:reactionToward(target) < 0 then
				a:setTarget(target)
			else
				a:setTarget(nil)
			end
			
		end
		game:playSoundNear(self, "talents/teleport")
		
		return true
	end,
	info = function(self, t)
		local defense = t.getDefense(self, t)
		return ([[Command your Temporal Hounds to teleport to the targeted location.  If you target an enemy your hounds will set that enemy as their target.
		When you learn this talent, your hounds gain %d defense and %d%% resist all after any teleport.
		At talent level five, if you're not at your maximum number of hounds when you cast this spell a new one will be summoned.
		The teleportation bonuses scale with your Spellpower.]]):format(defense, defense, defense/2, defense/2)
	end,
}

newTalent{
	name = "Temporal Vigour",
	type = {"chronomancy/temporal-hounds", 3},
	require = chrono_req_high3,
	points = 5,
	mode = "passive",
	getImmunities = function(self, t)
		return self:combatTalentLimit(t, 1, 0.15, 0.50) -- Limit <100%
	end,
	getRegen = function(self, t) return self:combatTalentSpellDamage(t, 10, 50, getParadoxSpellpower(self, t)) end,
	getHaste = function(self, t) return self:combatTalentLimit(t, 80, 20, 50)/100 end,
	getDuration = function(self, t) return getExtensionModifier(self, t, math.floor(self:combatTalentScale(t, 1, 3))) end,
	doBlink = function(self, t, hound)  -- Triggered when the hounds is hit
		local regen, haste = t.getRegen(self, t), t.getHaste(self, t)
		if hound:hasEffect(hound.EFF_UNRAVEL) then
			regen = regen * 2
			haste = haste * 2
		end
		hound:setEffect(hound.EFF_REGENERATION, 5, {power=regen}) 
		hound:setEffect(hound.EFF_SPEED, 5, {power=haste})
	end,
	doUnravel = function(self, t, hound, value)
		local die_at = hound.life - value -1
		print("Unravel", die_at)
		hound:setEffect(hound.EFF_UNRAVEL, t.getDuration(self, t), {power=50, die_at=die_at})
		return
	end,
	info = function(self, t)
		local duration = t.getDuration(self, t)
		local regen = t.getRegen(self, t)
		local haste = t.getHaste(self, t) * 100
		local immunities = t.getImmunities(self, t) * 100
		return ([[Your hounds can now survive for up to %d turns after their hit points are reduced below 1.  While in this state they deal 50%% less damage but are immune to additional damage.
		Command Blink will now regenerate your hounds for %d life per turn and increase their global speed by %d%% for five turns.  Hounds below 1 life when this effect occurs will have the bonuses doubled.
		When you learn this talent, your hounds gain %d%% stun, blind, confusion, and pin resistance.
		The regeneration scales with your Spellpower.]]):format(duration, regen, haste, immunities)
	end
}

newTalent{
	name = "Command Hounds: Breathe", short_name= "COMMAND_BREATHE",  -- Turn Back the Clock multi-breath attack
	type = {"chronomancy/temporal-hounds", 4},
	require = chrono_req_high4,
	points = 5,
	paradox = function (self, t) return getParadoxCost(self, t, 10) end,
	cooldown = 10,
	tactical = { ATTACKAREA = {TEMPORAL = 2}, DISABLE = 2 },
	range = 10,
	radius = function(self, t) return math.floor(self:combatTalentScale(t, 4.5, 6.5)) end,
	requires_target = true,
	direct_hit = true,
	on_pre_use = function(self, t, silent)
		local p = self:isTalentActive(self.T_TEMPORAL_HOUNDS)
		if not p or countHounds(self) < 1 then
			if not silent then
				game.logPlayer(self, "You must have temporal hounds to use this talent.")
			end
			return false
		end
		return true
	end,
	getResists = function(self, t)
		return self:combatTalentLimit(t, 100, 15, 50) -- Limit <100%
	end,
	getDamage = function(self, t) return self:combatTalentSpellDamage(t, 20, 200, getParadoxSpellpower(self, t)) end,
	getDamageStat = function(self, t) return 2 + math.ceil(t.getDamage(self, t) / 15) end,
	getDuration = function(self, t) return getExtensionModifier(self, t, 3) end,
	target = function(self, t)
		return {type="cone", range=0, radius=self:getTalentRadius(t), selffire=false, talent=t}
	end,
	action = function(self, t)
		-- Grab our hounds and build our multi-targeting display; thanks grayswandir for making this possible
		local tg = {multiple=true}
		local hounds = {}
		local grids = core.fov.circle_grids(self.x, self.y, self:getTalentRange(t), true)
		for x, yy in pairs(grids) do for y, _ in pairs(grids[x]) do
			local a = game.level.map(x, y, Map.ACTOR)
			if a and a.summoner == self and a.name == "temporal hound" then
				hounds[#hounds+1] = a
				tg[#tg+1] = {type="cone", range=0, radius=self:getTalentRadius(t), start_x=a.x, start_y=a.y, selffire=false, talent=t}
			end
		end end
		
		-- Pick a target
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		
		-- Switch our targeting type back
		local tg = self:getTalentTarget(t)
		
		-- Now...  we breath time >:)
		for i = 1, #hounds do
			if #hounds <= 0 then break end
			local a, id = rng.table(hounds)
			table.remove(hounds, id)
			
			tg.start_x, tg.start_y = a.x, a.y
			local dam = a:spellCrit(t.getDamage(self, t)) -- hound crit but our spellpower, mostly so it looks right
			
			a:project(tg, x, y, function(px, py)
				local target = game.level.map(px, py, Map.ACTOR)
				if target and target ~= a.summoner then
					DamageType:get(DamageType.TEMPORAL).projector(a, px, py, DamageType.TEMPORAL, dam)
					-- Don't turn back the clock other hounds
					if target.name ~= "temporal hound" then
						target:setEffect(target.EFF_REGRESSION, t.getDuration(self, t), {power=t.getDamageStat(self, t), apply_power=a:combatSpellpower(),  min_dur=1, no_ct_effect=true})	
					end
				end
			end)
			
			game.level.map:particleEmitter(a.x, a.y, tg.radius, "breath_time", {radius=tg.radius, tx=x-a.x, ty=y-a.y})
		end
		
		game:playSoundNear(self, "talents/breath")
		
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local radius = self:getTalentRadius(t)
		local stat_damage = t.getDamageStat(self, t)
		local duration =t.getDuration(self, t)
		local affinity = t.getResists(self, t)
		return ([[Command your Temporal Hounds to breathe time, dealing %0.2f temporal damage and reducing the three highest stats of all targets in a radius %d cone.
		Affected targets will have their stats reduced by %d for %d turns.  You are immune to the breath of your own hounds and your hounds are immune to stat damage from other hounds.
		When you learn this talent, your hounds gain %d%% temporal damage affinity.]]):format(damDesc(self, DamageType.TEMPORAL, damage), radius, stat_damage, duration, affinity)
	end,
}
