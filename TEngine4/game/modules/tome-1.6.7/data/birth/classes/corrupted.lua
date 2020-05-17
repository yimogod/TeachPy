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
	name = "Defiler",
	locked = function() return profile.mod.allow_build.corrupter end,
	locked_desc = "Dark thoughts, black bloods, vile deeds... Those who spill their brethren's blood will find its power.",
	desc = {
		"Defilers are touched by the mark of evil. They are a blight on the world. Working to promote the cause of evil, they serve their masters, or themselves become masters.",
	},
	descriptor_choices =
	{
		subclass =
		{
			__ALL__ = "disallow",
			Reaver = "allow",
			Corruptor = "allow",
		},
	},
	copy = {
		max_life = 120,
	},
}

newBirthDescriptor{
	type = "subclass",
	name = "Reaver",
	locked = function() return profile.mod.allow_build.corrupter_reaver end,
	locked_desc = "Reap thee the souls of thine enemies, and the powers of darkness shall enter thy flesh.",
	desc = {
		"Reavers are terrible foes, charging their enemies with a weapon in each hand.",
		"They can harness the blight of evil, infecting their foes with terrible contagious diseases while crushing their skulls with devastating combat techniques.",
		"Their most important stats are: Strength and Magic",
		"#GOLD#Stat modifiers:",
		"#LIGHT_BLUE# * +4 Strength, +1 Dexterity, +0 Constitution",
		"#LIGHT_BLUE# * +4 Magic, +0 Willpower, +0 Cunning",
		"#GOLD#Life per level:#LIGHT_BLUE# +2",
	},
	birth_example_particles = {
		function(actor)
			if core.shader.allow("adv") then actor:addParticles(Particles.new("shader_ring_rotating", 1, {toback=true, a=0.5, rotation=0, radius=1.5, img="bone_shield"}, {type="boneshield", chargesCount=4})) end
		end,
	},
	power_source = {arcane=true, technique=true},
	stats = { str=4, mag=4, dex=1, },
	talents_types = {
		["technique/combat-training"]={true, 0.3},
		["cunning/survival"]={false, 0.0},
		["corruption/sanguisuge"]={true, 0.0},
		["corruption/reaving-combat"]={true, 0.3},
		["corruption/scourge"]={true, 0.3},
		["corruption/plague"]={true, 0.3},
		["corruption/hexes"]={false, 0.3},
		["corruption/curses"]={false, 0.3},
		["corruption/bone"]={true, 0.3},
		["corruption/torment"]={true, 0.3},
		["corruption/vim"]={true, 0.0},
		["corruption/rot"]={false, 0.3},
		["corruption/vile-life"]={false, 0.0},

	},
	talents = {
		[ActorTalents.T_CORRUPTED_STRENGTH] = 1,
		[ActorTalents.T_WEAPON_COMBAT] = 1,
		[ActorTalents.T_WEAPONS_MASTERY] = 1,
		[ActorTalents.T_DRAIN] = 1,
		[ActorTalents.T_ARMOUR_TRAINING] = 1,
	},
	copy = {
		resolvers.auto_equip_filters{
			MAINHAND = {type="weapon", not_properties={"twohanded"}, special=function(e, filter) -- Allow standard 1H strength weapons and 1H staves, not currently working with ogre
				local who = filter._equipping_entity
				if who and e.subtype and (e.subtype == "staff" or e.subtype == "waraxe" or e.subtype == "longsword" or e.subtype == "mace") then return true end
			end},
			OFFHAND = {type="weapon", not_properties={"twohanded"}, special=function(e, filter)
				local who = filter._equipping_entity
				if who then
					local mh = who:getInven(who.INVEN_MAINHAND) mh = mh and mh[1]
					if mh and (not mh.slot_forbid or not who:slotForbidCheck(e, who.INVEN_MAINHAND)) and e.subtype and (e.subtype == "staff" or e.subtype == "waraxe" or e.subtype == "longsword" or e.subtype == "mace") then return true end
				end
			end},
		},
		resolvers.equipbirth{ id=true,
			{type="weapon", subtype="waraxe", name="iron waraxe", autoreq=true, ego_chance=-1000},
			{type="weapon", subtype="waraxe", name="iron waraxe", autoreq=true, ego_chance=-1000},
			{type="armor", subtype="heavy", name="iron mail armour", autoreq=true, ego_chance=-1000}
		},
	},
	copy_add = {
		life_rating = 1,
	},
}

newBirthDescriptor{
	type = "subclass",
	name = "Corruptor",
	locked = function() return profile.mod.allow_build.corrupter_corruptor end,
	locked_desc = "Blight and depravity hold the greatest powers. Accept temptation and become one with corruption.",
	desc = {
		"A corruptor is a terrible foe, wielding dark magics that can sap the very soul of her target.",
		"They can harness the blight of evil, crushing souls, stealing life force to replenish themselves.",
		"The most powerful corruptors can even take on some demonic aspects for themselves.",
		"Their most important stats are: Magic and Willpower",
		"#GOLD#Stat modifiers:",
		"#LIGHT_BLUE# * +0 Strength, +0 Dexterity, +2 Constitution",
		"#LIGHT_BLUE# * +4 Magic, +3 Willpower, +0 Cunning",
		"#GOLD#Life per level:#LIGHT_BLUE# +0",
	},
	power_source = {arcane=true},
	stats = { mag=4, wil=3, con=2, },
	birth_example_particles = {
		function(actor)	if core.shader.active(4) then actor:addParticles(Particles.new("shadowfire", 1)) end end,
		function(actor) if core.shader.active(4) then local x, y = actor:attachementSpot("back", true) actor:addParticles(Particles.new("shader_wings", 1, {infinite=1, x=x, y=y, img="bloodwings", flap=28, a=0.6})) end
		end,
	},
	talents_types = {
		["cunning/survival"]={false, 0.0},
		["corruption/sanguisuge"]={true, 0.3},
		["corruption/hexes"]={true, 0.3},
		["corruption/curses"]={true, 0.3},
		["corruption/bone"]={false, 0.3},
		["corruption/plague"]={true, 0.3},
		["corruption/shadowflame"]={false, 0.3},
		["corruption/blood"]={true, 0.3},
		["corruption/vim"]={true, 0.3},
		["corruption/blight"]={true, 0.3},
		["corruption/torment"]={true, 0.3},
	},
	talents = {
		[ActorTalents.T_DRAIN] = 1,
		[ActorTalents.T_BLOOD_SPRAY] = 1,
		[ActorTalents.T_SOUL_ROT] = 1,
		[ActorTalents.T_PACIFICATION_HEX] = 1,
	},
	copy = {
		resolvers.auto_equip_filters{
			MAINHAND = {type="weapon", subtype="staff"},
			OFFHAND = {special=function(e, filter) -- only allow if there is a 1H weapon in MAINHAND
				local who = filter._equipping_entity
				if who then
					local mh = who:getInven(who.INVEN_MAINHAND) mh = mh and mh[1]
					if mh and (not mh.slot_forbid or not who:slotForbidCheck(e, who.INVEN_MAINHAND)) then return true end
				end
				return false
			end}
		},
		resolvers.equipbirth{ id=true,
			{type="weapon", subtype="staff", name="elm staff", autoreq=true, ego_chance=-1000},
			{type="armor", subtype="cloth", name="linen robe", autoreq=true, ego_chance=-1000}
		},
	},
}