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

local Particles = require "engine.Particles"

newBirthDescriptor{
	type = "class",
	name = "Psionic",
	locked = function() return profile.mod.allow_build.psionic end,
	locked_desc = "Weakness of flesh can be overcome by mental prowess. Find the way and fight for the way to open the key to your mind.",
	desc = {
		"Psionics find their power within themselves. Their highly trained minds can harness energy from many different sources and manipulate it to produce physical effects.",
	},
	descriptor_choices =
	{
		subclass =
		{
			__ALL__ = "disallow",
			Mindslayer = "allow",
			Solipsist = "allow",
		},
	},
	copy = {
		psi_regen = 0.2,
	},
}

newBirthDescriptor{
	type = "subclass",
	name = "Mindslayer",
	locked = function() return profile.mod.allow_build.psionic_mindslayer end,
	locked_desc = "A thought can inspire; a thought can kill. After centuries of oppression, years of imprisonment, a thought shall break us free and vengeance will strike from our darkest dreams.",
	desc = {
		"Mindslayers specialize in direct and brutal application of mental forces to their immediate surroundings.",
		"When Mindslayers do battle, they will most often be found in the thick of the fighting, vast energies churning around them and telekinetically-wielded weapons hewing nearby foes at the speed of thought.",
		"Their most important stats are: Willpower and Cunning",
		"#GOLD#Stat modifiers:",
		"#LIGHT_BLUE# * +1 Strength, +0 Dexterity, +0 Constitution",
		"#LIGHT_BLUE# * +0 Magic, +4 Willpower, +4 Cunning",
		"#GOLD#Life per level:#LIGHT_BLUE# -2",
	},
	power_source = {psionic=true, technique=true},
	stats = { str=1, wil=4, cun=4, },
	birth_example_particles = {
		function(actor)
			if core.shader.active(4) then actor:addParticles(Particles.new("shader_shield", 1, {size_factor=1.1, img="shield5"}, {type="shield", ellipsoidalFactor=1, time_factor=-10000, llpow=1, aadjust=3, color={1, 0, 0.3}}))
			else actor:addParticles(Particles.new("generic_shield", 1, {r=1, g=0, b=0.3, a=0.5}))
			end
		end,
		function(actor)
			if core.shader.active(4) then actor:addParticles(Particles.new("shader_shield", 1, {size_factor=1.1, img="shield5"}, {type="shield", ellipsoidalFactor=1, time_factor=-10000, llpow=1, aadjust=3, color={0.3, 1, 1}}))
			else actor:addParticles(Particles.new("generic_shield", 1, {r=0.3, g=1, b=1, a=0.5}))
			end
		end,
		function(actor)
			if core.shader.active(4) then actor:addParticles(Particles.new("shader_shield", 1, {size_factor=1.1, img="shield5"}, {type="shield", ellipsoidalFactor=1, time_factor=-10000, llpow=1, aadjust=3, color={0.8, 1, 0.2}}))
			else actor:addParticles(Particles.new("generic_shield", 1, {r=0.8, g=1, b=0.2, a=0.5}))
			end
		end,
	},
	talents_types = {
		--Level 0 trees:
		["psionic/absorption"]={true, 0.3},
		["psionic/projection"]={true, 0.3},
		["psionic/psi-fighting"]={true, 0.3},
		["psionic/focus"]={true, 0.3},
		["psionic/voracity"]={true, 0.3},
		["psionic/augmented-mobility"]={true, 0.3},
		["psionic/augmented-striking"]={true, 0.3},
		["psionic/finer-energy-manipulations"]={true, 0.3},
		--Level 10 trees:
		["psionic/kinetic-mastery"]={false, 0.3},
		["psionic/thermal-mastery"]={false, 0.3},
		["psionic/charged-mastery"]={false, 0.3},
		--Miscellaneous trees:
		["cunning/survival"]={true, 0},
		["technique/combat-training"]={true, 0},
	},
	talents = {
		[ActorTalents.T_KINETIC_SHIELD] = 1,
		[ActorTalents.T_KINETIC_AURA] = 1,
		[ActorTalents.T_SKATE] = 1,
		[ActorTalents.T_TELEKINETIC_SMASH] = 1,
	},
	copy = {
		max_life = 110,
		resolvers.auto_equip_filters{
			MAINHAND = {type="weapon", special=function(e, filter) -- Allow standard 2H strength weapons
				local who = filter._equipping_entity
				if who and e.subtype and (e.subtype == "battleaxe" or e.subtype == "greatsword" or e.subtype == "greatmaul") then return true end
			end},
			OFFHAND = {special=function(e, filter) -- only allow if there is already a weapon in MAINHAND
				local who = filter._equipping_entity
				if who then
					local mh = who:getInven(who.INVEN_MAINHAND) mh = mh and mh[1]
					if mh and (not mh.slot_forbid or not who:slotForbidCheck(e, who.INVEN_MAINHAND)) then return true end
				end
				return false
			end},
		},
		resolvers.equipbirth{ id=true,
			{type="armor", subtype="cloth", name="linen robe", autoreq=true, ego_chance=-1000},
			{type="weapon", subtype="greatsword", name="iron greatsword", autoreq=true, ego_chance=-1000},
			{type="weapon", subtype="greatsword", name="iron greatsword", autoreq=true, ego_chance=-1000, force_inven = "PSIONIC_FOCUS"}
		},
		resolvers.inventorybirth{ id=true,
			{type="weapon", subtype="mindstar", name="mossy mindstar", autoreq=true, ego_chance=-1000},
			{type="weapon", subtype="mindstar", name="mossy mindstar", autoreq=true, ego_chance=-1000},
			{type="gem",},
		},
	},
	copy_add = {
		life_rating = -2,
	},
}

newBirthDescriptor{
	type = "subclass",
	name = "Solipsist",
	locked = function() return profile.mod.allow_build.psionic_solipsist end,
	locked_desc = "Some believe that the world is the collective dream of those that live in it.  Find and wake the sleeper and you'll unlock the potential of your dreams.",
	desc = {
		"The Solipsist believes that reality is malleable and nothing more than the collective vision of those that experience it.",
		"They wield this knowledge to both create and destroy, to invade the minds of others, and to manipulate the dreams of those around them.",
		"This knowledge comes with a heavy price and the Solipsist must guard his thoughts, lest he come to believe that the world exists only within his own mind.",
		"Their most important stats are: Willpower and Cunning",
		"#GOLD#Stat modifiers:",
		"#LIGHT_BLUE# * +0 Strength, +0 Dexterity, +0 Constitution",
		"#LIGHT_BLUE# * +0 Magic, +5 Willpower, +4 Cunning",
		"#GOLD#Life per level:#LIGHT_BLUE# -4 (*special*)",
	},
	power_source = {psionic=true},
	random_rarity = 3,
	stats = { str=0, wil=5, cun=4, },
	birth_example_particles = {
		function(actor)
			if core.shader.active(4) then actor:addParticles(Particles.new("shader_shield", 1, {size_factor=1.1}, {type="shield", time_factor=-8000, llpow=1, aadjust=7, color={1, 1, 0}}))
			else actor:addParticles(Particles.new("generic_shield", 1, {r=1, g=1, b=0, a=1}))
			end
		end,
	},
	talents_types = {
		-- class
		["psionic/distortion"]={true, 0.3},
		["psionic/dream-smith"]={true, 0.3},
		["psionic/psychic-assault"]={true, 0.3},
		["psionic/slumber"]={true, 0.3},
		["psionic/solipsism"]={true, 0.3},
		["psionic/thought-forms"]={true, 0.3},

		-- generic
		["psionic/dreaming"]={true, 0.3},
		["psionic/feedback"]={true, 0.3},
		["psionic/mentalism"]={true, 0.3},
		["cunning/survival"]={true, 0.0},

		-- locked trees
		["psionic/discharge"]={false, 0.3},
		["psionic/dream-forge"]={false, 0.3},
		["psionic/nightmare"]={false, 0.3},
	},
	talents = {
		[ActorTalents.T_SLEEP] = 1,

		[ActorTalents.T_MIND_SEAR] = 1,
		[ActorTalents.T_SOLIPSISM] = 1,
		[ActorTalents.T_THOUGHT_FORMS] = 1,
	},
	copy = {
		max_life = 90,
		resolvers.auto_equip_filters{
			MAINHAND = {type="weapon", subtype="mindstar"},
			OFFHAND = {type="weapon", subtype="mindstar"},
		},
		resolvers.equipbirth{ id=true,
			{type="armor", subtype="cloth", name="linen robe", autoreq=true, ego_chance=-1000},
			{type="weapon", subtype="mindstar", name="mossy mindstar", autoreq=true, ego_chance=-1000},
			{type="weapon", subtype="mindstar", name="mossy mindstar", autoreq=true, ego_chance=-1000},
		},
	},
	copy_add = {
		life_rating = -4,
	},
}
