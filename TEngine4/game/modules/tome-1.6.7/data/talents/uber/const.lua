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
	name = "Draconic Body",
	mode = "passive",
	cooldown = 15,
	require = { special={desc="Be close to the draconic world", fct=function(self) return game.state.birth.ignore_prodigies_special_reqs or (self:attr("drake_touched") and self:attr("drake_touched") >= 2) end} },
	trigger = function(self, t, value)
		if self.life - value < self.max_life * 0.3 and not self:isTalentCoolingDown(t) then
			self:heal(self.max_life * 0.4, t)
			self:startTalentCooldown(t)
			game.logSeen(self,"%s's draconic body hardens and heals!",self.name)
		end
	end,
	info = function(self, t)
		return ([[Your body hardens and recovers quickly. When pushed below 30%% life, you instantly restore 40%% of your total life.]])
		:format()
	end,
}

uberTalent{
	name = "Bloodspring",
	mode = "passive",
	cooldown = 12,
	require = { special={desc="Have let Melinda be sacrificed", fct=function(self) return game.state.birth.ignore_prodigies_special_reqs or (self:hasQuest("kryl-feijan-escape") and self:hasQuest("kryl-feijan-escape"):isStatus(engine.Quest.FAILED)) end} },
	trigger = function(self, t)
		-- Add a lasting map effect
		game.level.map:addEffect(self,
			self.x, self.y, 4,
			DamageType.BLOODSPRING, {dam={dam=100 + self:getCon() * 3, healfactor=0.5}, x=self.x, y=self.y, st=DamageType.DRAINLIFE, power=50 + self:getCon() * 2},
			1,
			5, nil,
			MapEffect.new{color_br=255, color_bg=20, color_bb=20, effect_shader="shader_images/darkness_effect.png"},
			function(e, update_shape_only)
				if not update_shape_only then e.radius = e.radius + 0.5 end
				return true
			end,
			false
		)
		game:playSoundNear(self, "talents/tidalwave")
		self:startTalentCooldown(t)
	end,
	info = function(self, t)
		return ([[When a single blow deals more than 15%% of your total life, a torrent of blood gushes from your body, creating a bloody tidal wave for 4 turns that deals %0.2f blight damage, heals you for 50%% of the damage done, and knocks foes back.
		The damage increases with your Constitution.]])
		:format(100 + self:getCon() * 3)
	end,
}

uberTalent{
	name = "Eternal Guard",
	mode = "passive",
	require = { special={desc="Know the Block talent", fct=function(self) return self:knowTalent(self.T_BLOCK) end} },
	info = function(self, t)
		return ([[Your Block talent now lasts for 2 game turns and you can apply Counterstrike to any number of enemies.]])
		:format()
	end,
}

uberTalent{
	name = "Never Stop Running",
	mode = "sustained",
	cooldown = 8,
	sustain_stamina = 10,
	tactical = { CLOSEIN = 0.5, ESCAPE = 0.5, STAMINA = -0.5, SPECIAL = -0.5}, -- values small for instant use
	no_energy = true,
	require = { special={desc="Know at least 20 levels of stamina-using talents", fct=function(self) return knowRessource(self, "stamina", 20) end} },
	activate = function(self, t)
		local ret = {}
		self:talentTemporaryValue(ret, "move_stamina_instead_of_energy", 12)
		return ret
	end,
	deactivate = function(self, t, p)
		return true
	end,
	info = function(self, t)
		return ([[While this talent is active, you dig deep into your stamina reserves, allowing you to move without taking a turn. However, this costs 12 stamina for each tile that you cross.]]):format()
	end,
}

uberTalent{
	name = "Armour of Shadows",
	mode = "passive",
	require = { special={desc="Have dealt over 50000 darkness damage", fct=function(self) return
		self.damage_log and (
			(self.damage_log[DamageType.DARKNESS] and self.damage_log[DamageType.DARKNESS] >= 50000)
		)
	end} },
	-- called by _M:combatArmor in mod\class\interface\Combat.lua
	ArmourBonus = function(self, t) return math.max(30, 0.5*self:getCon()) end,
	getStealth = function(self, t) return 30 end,
	passives = function(self, t, p)
		self:talentTemporaryValue(p, "inc_stealth", t.getStealth(self, t))
		self:talentTemporaryValue(p, "darkness_darkens", 1)
	end,
	info = function(self, t)
		return ([[You know how to protect yourself with the deepest shadows. As long as you stand on an unlit tile you gain %d armour, 50%% armour hardiness, and 20%% evasion.
		Any time you deal darkness damage, you will unlight both the target tile and yours.
		Passively increases your stealth rating by %d.
		The armor bonus scales with your Constitution.]])
		:format(t.ArmourBonus(self,t), t.getStealth(self, t))
	end,
}

uberTalent{
	name = "Spine of the World",
	mode = "passive",
	trigger = function(self, t)
		if self:hasEffect(self.EFF_SPINE_OF_THE_WORLD) then return end
		self:setEffect(self.EFF_SPINE_OF_THE_WORLD, 5, {})
	end,
	info = function(self, t)
		return ([[Your back is as hard as stone. Each time that you are affected by a physical effect, your body hardens, making you immune to all other physical effects for 5 turns.]])
		:format()
	end,
}

uberTalent{
	name = "Fungal Blood",
	require = { special={desc="Be able to use infusions", fct=function(self)
		return 
			(not self.inscription_restrictions or self.inscription_restrictions['inscriptions/infusions']) and
			(not self.inscription_forbids or not self.inscription_forbids['inscriptions/infusions'])
	end} },
	tactical = { HEAL = function(self) return not self:hasEffect(self.EFF_FUNGAL_BLOOD) and 0 or math.ceil(self:hasEffect(self.EFF_FUNGAL_BLOOD).power / 150) end },
	healmax = function(self, t) return self.max_life * self:combatStatLimit("con", 0.5, 0.1, 0.25) end, -- Limit < 50% max life
	fungalPower = function(self, t) return self:getCon()*2 + self.max_life * self:combatStatLimit("con", 0.05, 0.005, 0.01) end,
	on_pre_use = function(self, t) return self:hasEffect(self.EFF_FUNGAL_BLOOD) and self:hasEffect(self.EFF_FUNGAL_BLOOD).power > 0 and not self:attr("undead") end,
	trigger = function(self, t)
		if self.inscription_restrictions and not self.inscription_restrictions['inscriptions/infusions'] then return end
		if self.inscription_forbids and self.inscription_forbids['inscriptions/infusions'] then return end
		self:setEffect(self.EFF_FUNGAL_BLOOD, 6, {power=t.fungalPower(self, t)})
	end,
	no_energy = true,
	-- decay handed by "FUNGAL_BLOOD" effect in mod.data.timed_effects.physical.lua
	action = function(self, t)
		local eff = self:hasEffect(self.EFF_FUNGAL_BLOOD)
		self:attr("allow_on_heal", 1)
		self:heal(math.min(eff.power, t.healmax(self,t)), eff)
		self:attr("allow_on_heal", -1)
		if core.shader.active(4) then
			self:addParticles(Particles.new("shader_shield_temp", 1, {toback=true , size_factor=1.5, y=-0.3, img="healgreen", life=25}, {type="healing", time_factor=2000, beamsCount=20, noup=2.0, circleDescendSpeed=3.5}))
			self:addParticles(Particles.new("shader_shield_temp", 1, {toback=false, size_factor=1.5, y=-0.3, img="healgreen", life=25}, {type="healing", time_factor=2000, beamsCount=20, noup=1.0, circleDescendSpeed=3.5}))
		end
		self:removeEffectsFilter({status="detrimental", type="magical"}, 10)
		self:removeEffect(self.EFF_FUNGAL_BLOOD)
		return true
	end,
	info = function(self, t)
		return ([[Fungal spores have colonized your blood, so that each time you use an infusion you store %d fungal power.
		You may use this prodigy to release the power as a heal (never more than %d life) and remove up to 10 detrimental magical effects.
		Fungal power lasts for up to 6 turns, losing the greater of 10 potency or 10%% of its power each turn.
		The amount of fungal power produced and the maximum heal possible increase with your Constitution and maximum life.]])
		:format(t.fungalPower(self, t), t.healmax(self,t))
	end,
}

uberTalent{
	name = "Corrupted Shell",
	mode = "passive",
	require = { special={desc="Have received at least 7500 blight damage and destroyed Zigur with the Grand Corruptor.", fct=function(self) return
		(self.damage_intake_log and self.damage_intake_log[DamageType.BLIGHT] and self.damage_intake_log[DamageType.BLIGHT] >= 7500) and
		(game.state.birth.ignore_prodigies_special_reqs or (
			self:hasQuest("anti-antimagic") and 
			self:hasQuest("anti-antimagic"):isStatus(engine.Quest.DONE) and
			not self:hasQuest("anti-antimagic"):isStatus(engine.Quest.COMPLETED, "grand-corruptor-treason")
		))
	end} },
	on_learn = function(self, t)
		self.max_life = self.max_life + 500
		self.combat_armor_hardiness = self.combat_armor_hardiness + 20
	end,
	on_unlearn = function(self, t)
		self.max_life = self.max_life - 500
		self.combat_armor_hardiness = self.combat_armor_hardiness - 20
	end,
	info = function(self, t)
		return ([[Thanks to your newfound knowledge of corruption, you've learned some tricks for toughening your body... but only if you are healthy enough to withstand the strain from the changes.
		Improves your life by 500, your defense by %d, your armour by %d, your armour hardiness by 20%% and your saves by %d as your natural toughness and reflexes are pushed beyond their normal limits.
		Your saves armour and defense will improve with your Constitution.]])
		:format(self:getCon() / 3, self:getCon() / 3.5, self:getCon() / 3)
	end,
}
