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
local Talents = require "engine.interface.ActorTalents"

--[=[
newEntity{ base = "BASE_GEM", define_as = "ANCIENT_STORM_SAPHIR",
	power_source = {unknown=true},
	unique = true,
	unided_name = "strange sapphire",
	name = "Ancient Storm Sapphire", subtype = "blue", image = "object/ancient_storm_saphir.png",
	color = colors.ROYAL_BLUE,
	level_range = {30, 50},
	desc = [[This seemingly normal sapphire seems to be charged with the destructive power of a raging storm.]],
	rarity = 300,
	cost = 0,
	material_level = 4,
	identified = false,
}
]=]

-- Not a random drop, used by the quest started above
newEntity{ base = "BASE_SCROLL", define_as = "JEWELER_SUMMON", subtype="tome", no_unique_lore=true,
	power_source = {unknown=true},
	unique = true, quest=true, identified=true,
	name = "Scroll of Summoning (Limmir the Jeweler)",
	color = colors.VIOLET,
	fire_proof = true,

	max_power = 1, power_regen = 1,
	use_power = { name = "summon Limmir the jeweler at the center of the lake of the moon", power = 1,
		use = function(self, who) who:hasQuest("master-jeweler"):summon_limmir(who) return {id=true, used=true} end
	},
}

newEntity{ base = "BASE_AMULET",
	power_source = {arcane=true},
	unique = true,
	name = "Pendant of the Sun and Moons", color = colors.LIGHT_SLATE, image = "object/artifact/amulet_pendant_of_sun_and_the_moon.png",
	unided_name = "a gray and gold pendant",
	desc = [[This small pendant depicts a hematite moon eclipsing a golden sun and according to legend was worn by one of the Sunwall's founders.]],
	level_range = {35, 45},
	rarity = 300,
	cost = 200,
	material_level = 4,
	special_desc = function(self) return "All your damage is converted and split into light and darkness." end,
	wielder = {
		twilight_mastery = 0.5,
		combat_spellpower = 8,
		combat_spellcrit = 5,
		inc_damage = { [DamageType.LIGHT]= 8,[DamageType.DARKNESS]= 8 },
		resists = { [DamageType.LIGHT]= 10, [DamageType.DARKNESS]= 10 },
		resists_cap = { [DamageType.LIGHT]= 5, [DamageType.DARKNESS]= 5 },
		resists_pen = { [DamageType.LIGHT]= 15, [DamageType.DARKNESS]= 15 },
	},
	max_power = 60, power_regen = 1,
	use_talent = { id = Talents.T_CIRCLE_OF_SANCTITY, level = 3, power = 30 },
}

newEntity{ base = "BASE_SHIELD", define_as = "SHIELD_UNSETTING",
	power_source = {arcane=true},
	unique = true,
	unided_name = "shimmering gold shield",
	name = "Unsetting Sun", image = "object/artifact/shield_unsetting_sun.png",
	moddable_tile = "special/%s_unsetting_sun",
	moddable_tile_big = true,
	desc = [[When Elmio Panason, captain of the Vanguard, first sought shelter for his shipwrecked crew, he reflected the last rays of the setting sun off his shield.  Where the beam hit they rested and built the settlement that would become the Sunwall.  In the dark days that followed the shield became a symbol of hope for a better future.]],
	color = colors.YELLOW,
	rarity = 300,
	level_range = {35, 45},
	require = { stat = { str=40 }, },
	cost = math.random(700,1100),
	material_level = 5,
	special_combat = {
		dam = 50,
		block = 280,
		physcrit = 4.5,
		dammod = {str=1},
		damtype = DamageType.LIGHT,
	},
	wielder = {
		lite = 2,
		combat_armor = 20,
		combat_def = 16,
		combat_def_ranged = 17,
		fatigue = 14,
		combat_spellresist = 19,
		resists = {[DamageType.BLIGHT] = 30, [DamageType.DARKNESS] = 30},
		learn_talent = { [Talents.T_BLOCK] = 1, },
	},
	set_list = { {"define_as","SWORD_DAWN"} },
	set_desc = {
		dawn = "Glows brightly in the light of dawn.",
	},
	on_set_complete = function(self, who)
		self:specialSetAdd({"wielder","life_regen"}, 5)
		self:specialSetAdd({"wielder","lite"}, 1)
	end,
	on_set_broken = function(self, who)
		
	end,
}

newEntity{ base = "BASE_HEAVY_BOOTS",
	power_source = {arcane=true},
	unique = true,
	name = "Scorched Boots", image = "object/artifact/scorched_boots.png",
	unided_name = "pair of blackened boots",
	desc = [[The master blood mage Ru'Khan was the first orc to experiment with the power of the Sher'Tul farportals in the Age of Pyre.  However, that first experiment was not particularly successful, and after the explosion of energy all that could be found of Ru'Khan was a pair of scorched boots.]],
	color = colors.DARK_GRAY,
	level_range = {30, 40},
	rarity = 250,
	cost = 200,
	material_level = 5,
	wielder = {
		combat_armor = 4,
		combat_def = 4,
		fatigue = 8,
		combat_spellpower = 13,
		combat_spellcrit = 6,
		inc_damage = { [DamageType.BLIGHT] = 15, [DamageType.FIRE] = 15, [DamageType.DARKNESS] = 15 },
	},

	max_power = 40, power_regen = 1,
	use_talent = { id = Talents.T_POISON_STORM, level = 3, power = 30 },
}

newEntity{ base = "BASE_GEM",
	power_source = {arcane=true},
	unique = true,
	unided_name = "unearthly black stone",
	name = "Goedalath Rock", subtype = "demonic", image = "object/artifact/goedalath_rock.png",
	define_as = 'GOEDALATH_ROCK',
	color = colors.PURPLE,
	level_range = {42, 50},
	desc = [[A small rock that seems from beyond this world, vibrating with a fierce energy.  It feels warped and terrible and evil... and yet oh so powerful.]],
	rarity = 300,
	cost = 300,
	material_level = 5,
	identified = false,
	auto_pickup = false,  -- why would you do such a thing.
	encumber = 0.1,  -- at least they'll see it on transmo screen.
	carrier = {
		on_melee_hit = {[DamageType.HEAL] = 34},
		life_regen = -2,
		lite = -2,
		combat_mentalresist = -18,
		healing_factor = -0.5,
	},
	imbue_powers = {
		combat_dam = 12,
		combat_spellpower = 16,
		see_invisible = 14,
		infravision = 3,
		inc_damage = {all = 9},
		inc_damage_type = {demon = 20},
		esp = {["demon/major"]=1, ["demon/minor"]=1},
		on_melee_hit = {[DamageType.DARKNESS] = 34},
		healing_factor = 0.5,
	},
	on_pickup = function(self, who)
		if who == game.player then
			who:runStop("evil touch")
			who:restStop("evil touch")
		end
	end,
	color_attributes = {damage_type = 'SHADOWFLAME',},}

newEntity{ base = "BASE_CLOAK",
	power_source = {arcane=true}, define_as = "THREADS_FATE",
	unique = true,
	name = "Threads of Fate", image = "object/artifact/cloak_threads_of_fate.png",
	unided_name = "a shimmering white cloak",
	desc = [[Untouched by the ravages of time, this fine spun white cloak appears to be crafted of an otherworldly material that shifts and shimmers in the light.]],
	level_range = {45, 50},
	color = colors.WHITE,
	rarity = 500,
	cost = 300,
	material_level = 5,

	wielder = {
		combat_def = 10,
		combat_spellpower = 8,
		confusion_immune = 0.4,
		inc_stats = { [Stats.STAT_MAG] = 6, [Stats.STAT_WIL] = 6, [Stats.STAT_LCK] = 10, },

		inc_damage = { [DamageType.TEMPORAL]= 10 },
		resists_cap = { [DamageType.TEMPORAL] = 10, },
		resists = { [DamageType.TEMPORAL] = 20, },
		combat_physresist = 20,
		combat_mentalresist = 20,
		combat_spellresist = 20,

		talents_types_mastery = {
			["chronomancy/timeline-threading"] = 0.1,
			["chronomancy/chronomancy"] = 0.1,
			["spell/divination"] = 0.1,
		},
	},

	max_power = 50, power_regen = 1,
	use_talent = { id = Talents.T_SEE_THE_THREADS, level = 1, power = 50 },
}

newEntity{ base = "BASE_LONGSWORD", define_as = "BLOODEDGE",
	power_source = {arcane=true},
	unique = true,
	name = "Blood-Edge", image = "object/artifact/sword_blood_edge.png",
	unided_name = "red crystalline sword",
	moddable_tile = "special/%s_sword_blood_edge",
	moddable_tile_big = true,
	level_range = {36, 48},
	color=colors.RED,
	rarity = 260,
	desc = [[This deep red sword weeps blood continuously. It was born in the labs of the orcish corrupter Hurik, who sought to make a crystal that would house his soul after death. But his plans were disrupted by a band of sun paladins, and though most died purging his keep of dread minions, their leader Raasul fought through to Hurik's lab, sword in hand. There the two did battle, blade against blood magic, till both fell to the floor with weeping wounds. The orc with his last strength crawled towards his fashioned phylactery, hoping to save himself, but Raasul saw his plans and struck the crystal with his light-bathed sword. It shattered, and in the sudden impulse of energies the steel, crystal and blood were fused into one.
Now the broken fragments of Raasul's soul are trapped in this terrible artifact, his mind warped beyond all sanity by decades of imprisonment. Only the taste of blood calls him forth, his soul stealing the lifeblood of others to take on physical form again, that he may thrash and wail against the living.]],
	cost = 1000,
	require = { stat = { mag=20, str=32,}, },
	metallic = false,
	material_level = 5,
	wielder = {
		esp = {["undead/blood"]=1,},
		combat_spellpower = 21,
		combat_spellcrit = 8,
		inc_damage={
			[DamageType.PHYSICAL] = 15,
			[DamageType.BLIGHT] = 15,
		},
		max_vim = 25,
	},

	max_power = 20, power_regen = 1,
	use_talent = { id = Talents.T_BLEEDING_EDGE, level = 4, power = 20 },
	combat = {
		dam = 46,
		apr = 7,
		physcrit = 6,
		dammod = {str=1, mag=0.1},
		convert_damage = {[DamageType.BLIGHT] = 50},
		lifesteal=5,
		special_on_hit = {desc="15% chance to animate a bleeding foe's blood", fct=function(combat, who, target)
			if not rng.percent(15) then return end
			local cut = false

			-- Go through all timed effects
			for eff_id, p in pairs(target.tmp) do
				local e = target.tempeffect_def[eff_id]
				if e.subtype.cut then
					cut = true
				end
			end

			if not (cut) then return end

			local tg = {type="hit", range=1}
			who:project(tg, target.x, target.y, engine.DamageType.DRAIN_VIM, 80)

			local x, y = util.findFreeGrid(target.x, target.y, 5, true, {[engine.Map.ACTOR]=true})
			local NPC = require "mod.class.NPC"
			local m = NPC.new{
				type = "undead", subtype = "blood",
				display = "L",
				name = "animated blood", color=colors.RED,
				resolvers.nice_tile{image="invis.png", add_mos = {{image="npc/undead_horror_animated_blood.png", display_h=1, display_y=0}}},
				desc = "A haze of blood, vibrant and pulsing through the air, possessed by a warped and cracked soul. Every now and then a scream or wail of agony garbles through it, telling of the mindless suffering undergone by its possessor.",
				body = { INVEN = 10, MAINHAND=1, OFFHAND=1, },
				rank = 3,
				life_rating = 10, exp_worth = 0,
				max_vim=200,
				max_life = resolvers.rngavg(50,90),
				infravision = 20,
				autolevel = "dexmage",
				ai = "summoned", ai_real = "tactical", ai_state = { talent_in=2, ally_compassion=10},
				stats = { str=15, dex=18, mag=18, wil=15, con=10, cun=18 },
				level_range = {1, nil}, exp_worth = 0,
				silent_levelup = true,
				combat_armor = 0, combat_def = 24,
				combat = { dam=resolvers.rngavg(10,13), atk=15, apr=15, dammod={mag=0.5, dex=0.5}, damtype=engine.DamageType.BLIGHT, },

				resists = { [engine.DamageType.BLIGHT] = 100, [engine.DamageType.NATURE] = -100, },

				negative_status_effect_immune = 1,

				on_melee_hit = {[engine.DamageType.DRAINLIFE]=resolvers.mbonus(10, 30)},
				melee_project = {[engine.DamageType.DRAINLIFE]=resolvers.mbonus(10, 30)},

				resolvers.talents{
					[who.T_WEAPON_COMBAT]={base=1, every=7, max=10},
					[who.T_EVASION]={base=3, every=8, max=7},

					[who.T_BLOOD_SPRAY]={base=1, every=6, max = 10},
					[who.T_BLOOD_GRASP]={base=1, every=5, max = 9},
					[who.T_BLOOD_BOIL]={base=1, every=7, max = 7},
					[who.T_BLOOD_FURY]={base=1, every=8, max = 6},
				},
				resolvers.sustains_at_birth(),
				faction = who.faction,
				summoner = who, summoner_gain_exp=true,
				summon_time = 9,
			}

			m:resolve()
			game.zone:addEntity(game.level, m, "actor", x, y)
			m.remove_from_party_on_death = true,
			game.party:addMember(m, {
				control=false,
				type="summon",
				title="Summon",
				orders = {target=true, leash=true, anchor=true, talents=true},
			})

			game.logSeen(who, "#GOLD#As the blade touches %s's spilt blood, the blood rises, animated!", target.name:capitalize())
			if who:knowTalent(who.T_VIM_POOL) then
				game.logSeen(who, "#GOLD#%s draws power from the spilt blood!", who.name:capitalize())
			end

		end},
	},
}

newEntity{ base = "BASE_LONGSWORD", define_as = "SWORD_DAWN",
	power_source = {arcane=true},
	unique = true,
	name = "Dawn's Blade",
	unided_name = "shining longsword",
	moddable_tile = "special/%s_dawn_blade",
	moddable_tile_big = true,
	level_range = {35, 42},
	color=colors.YELLOW, image = "object/artifact/dawn_blade.png",
	rarity = 260,
	desc = [[Said to have been forged in the earliest days of the Sunwall, this longsword shines with the light of daybreak, capable of banishing all shadows.]],
	cost = 1000,
	require = { stat = { mag=18, str=35,}, },
	material_level = 5,
	wielder = {
		combat_spellpower = 10,
		combat_spellcrit = 4,
		inc_damage={
			[DamageType.LIGHT] = 18,
		},
		resists_pen={
			[DamageType.LIGHT] = 25,
		},
		talents_types_mastery = {
			["celestial/sun"] = 0.2,
			["celestial/light"] = 0.2,
			["celestial/combat"] = 0.2,
		},
		talent_cd_reduction= {
			[Talents.T_HEALING_LIGHT] = 2,
			[Talents.T_BARRIER] = 2,
			[Talents.T_SUNCLOAK] = 3,
			[Talents.T_PROVIDENCE] = 4,
		},
		lite=2,
	},
	max_power = 35, power_regen = 1,
	use_power = {
		name = function(self, who) return ("invoke dawn, inflicting %0.2f light damage in radius %d (based on Magic) and lighting the area within radius %d"):format(engine.interface.ActorTalents.damDesc(who, engine.DamageType.LIGHT, self.use_power.damage(who)), self.use_power.radius, self.use_power.radius*2) end,
		power = 35,
		radius = 5,
		damage = function(who) return 75 + who:getMag()*2 end,
		use = function(self, who)
			local dam = self.use_power.damage(who)
			local blast = {type="ball", range=0, radius=self.use_power.radius, selffire=false}
			who:project(blast, who.x, who.y, engine.DamageType.LIGHT, dam)
			game.level.map:particleEmitter(who.x, who.y, blast.radius, "sunburst", {radius=blast.radius})
			who:project({type="ball", range=0, radius=self.use_power.radius*2}, who.x, who.y, engine.DamageType.LITE, dam/2)
			game:playSoundNear(self, "talents/fireflash")
			game.logSeen(who, "%s raises %s and sends out a burst of light!", who.name:capitalize(), self:getName())
			return {id=true, used=true}
		end
	},
	combat = {
		dam = 50,
		apr = 7,
		physcrit = 5,
		dammod = {str=0.8, mag=0.25},
		convert_damage = {[DamageType.LIGHT] = 30},
		inc_damage_type={
			undead=25,
			demon=25,
		},
	},
	on_wear = function(self, who)
		if who.descriptor and who.descriptor.subclass == "Sun Paladin" then
			self:specialWearAdd({"wielder", "positive_regen"}, 0.2)
			self:specialWearAdd({"wielder", "positive_regen_ref_mod"}, 0.2)
			game.logPlayer(who, "#GOLD#You feel a swell of positive energy!")
		end
	end,
	
	set_list = { {"define_as","SHIELD_UNSETTING"} },
	set_desc = {
		dawn = "If the sun doesn't set, dawn's power lasts forever.",
	},
	on_set_complete = function(self, who)
		self:specialSetAdd({"combat","melee_project"}, {[engine.DamageType.LIGHT]=15, [engine.DamageType.FIRE]=15})
		self:specialSetAdd({"wielder","inc_damage"}, {[engine.DamageType.LIGHT]=12, [engine.DamageType.FIRE]=10})
		game.logPlayer(who, "#GOLD#As you wield the sword and shield of the Sunwall, you feel the Sun's light radiating from your core.")
	end,
	on_set_broken = function(self, who)
		game.logPlayer(who, "#GOLD#You feel the Sun's light vanish from within you.")
	end,
}

newEntity{ base = "BASE_AMULET",
	power_source = {arcane=true},
	unique = true,
	name = "Zemekkys' Broken Hourglass", color = colors.WHITE,
	unided_name = "a broken hourglass", image="object/artifact/amulet_zemekkys_broken_hourglass.png",
	desc = [[This small broken hourglass hangs from a thin gold chain.  The glass is cracked and the sand has long since escaped.]],
	level_range = {30, 40},
	rarity = 300,
	cost = 200,
	material_level = 4,
	metallic = false,
	use_no_energy = true,
	wielder = {
		inc_stats = { [Stats.STAT_WIL] = 4, },
		inc_damage = { [DamageType.TEMPORAL]= 10 },
		resists = { [DamageType.TEMPORAL] = 20 },
		resists_cap = { [DamageType.TEMPORAL] = 5 },
		spell_cooldown_reduction = 0.1,
	},
	max_power = 80, power_regen = 1,
	use_talent = { id = Talents.T_TIME_STOP, level = 1, power = 50 },
}

newEntity{ base = "BASE_KNIFE", define_as = "MANDIBLE_UNGOLMOR",
	power_source = {nature=true},
	unique = true,
	name = "Mandible of Ungolmor", image = "object/artifact/mandible_of_ungolmor.png",
	unided_name = "curved, serrated black dagger",
	moddable_tile = "special/%s_mandible_of_ungolmor",
	moddable_tile_big = true,
	desc = [[This obsidian-crafted, curved blade is studded with the deadly fangs of the Ungolmor. It seems to drain light from the world around it.]],
	level_range = {40, 50},
	rarity = 270,
	require = { stat = { cun=38 }, },
	cost = math.random(700,1100),
	metallic = false,
	material_level = 5,
	combat = {
		dam = 40,
		apr = 12,
		physcrit = 22,
		dammod = {cun=0.30, str=0.35, dex=0.35},
		convert_damage ={[DamageType.DARKNESS] = 30},
		special_on_crit = {desc="inflicts spydric poison dealing 200 damage over 3 turns and pinning the target", fct=function(combat, who, target)
			if target:canBe("poison") then
				local tg = {type="hit", range=1}
				who:project(tg, target.x, target.y, engine.DamageType.SPYDRIC_POISON, {src=who, dam=200, dur=3})
			end
		end},
		talent_on_hit = { [Talents.T_BITE_POISON] = {level=3, chance=20} },
	},
	wielder = {
		inc_damage={[DamageType.NATURE] = 30, [DamageType.DARKNESS] = 20,},
		inc_stats = {[Stats.STAT_CUN] = 8, [Stats.STAT_DEX] = 4,},
		combat_armor = 15,
		poison_immune = 1,
		lite = -2,
		learn_talent = { [Talents.T_TOXIC_DEATH] = 5, },  -- Radius 3 at TL5
	},
}

newEntity{ base = "BASE_KNIFE", define_as = "KINETIC_SPIKE",
	power_source = {psionic=true},
	unique = true,
	name = "Kinetic Spike", image = "object/artifact/kinetic_spike.png",
	unided_name = "bladeless hilt",
	moddable_tile = "special/%s_kinetic_spike",
	moddable_tile_big = true,
	desc = [[A simple, rudely crafted stone hilt, this object manifests a blade of wavering, nearly invisible force, like a heat haze, as you grasp it. Despite its simple appearance, it is capable of shearing through solid granite, in the hands of those with the necessary mental fortitude to use it properly.]],
	level_range = {42, 50},
	rarity = 310,
	require = { stat = { wil=42 }, },
	cost = 450,
	metallic = false,
	material_level = 5,
	combat = {
		dam = 38,
		apr = 40, -- Hard to imagine much being harder to stop with armor.
		physcrit = 10,
		dammod = {wil=0.30, str=0.30, dex=0.40},
	},
	wielder = {
		combat_atk = 8,
		combat_dam = 15,
		resists_pen = {[DamageType.PHYSICAL] = 30},
		talents_types_mastery = {
			["psionic/augmented-striking"] = 0.2,
		},
	},
	max_power = 10, power_regen = 1,
	use_power = {
		name = function(self, who) return ("fire a bolt of kinetic force (range %d), dealing 150%% (physical) weapon damage"):format(self.use_power.range) end,
		power = 10,
		range = 8,
		use = function(self, who)
			local tg = {type="bolt", range=self.use_power.range}
			local x, y = who:getTarget(tg)
			if not x or not y then return nil end
			local _ _, x, y = who:canProject(tg, x, y)
			local target = game.level.map(x, y, engine.Map.ACTOR)
			if target then
				who:attackTarget(target, engine.DamageType.PHYSICAL, 1.5, true)
			game.logSeen(who, "The %s fires a bolt of kinetic force!", self:getName())
			else
				return
			end
			return {id=true, used=true}
		end
	},
}

newEntity{ base = "BASE_STAFF",
	power_source = {unknown=true},
	unique = true,
	name = "Rod of Sarrilon", image = "object/artifact/rod_of_sarrilon.png",
	unided_name = "ceremonial staff",
	flavor_name = "starstaff",
	level_range = {37, 50},
	color=colors.VIOLET,
	rarity = 250,
	desc = [[A plain looking ceremonial rod. It has connections with Time that even chronomancers do not yet understand.]],
	cost = math.random(700,1100),
	material_level = 5,

	require = { stat = { mag=48 }, },
	combat = {
		is_greater = true,
		dam = 30,
		apr = 4,
		dammod = {mag=0.8},
		element = DamageType.TEMPORAL,
	},
	wielder = {
		inc_stats = { [Stats.STAT_WIL] = 7, [Stats.STAT_MAG] = 8 },
		paradox_reduce_anomalies = 25,
		combat_spellpower = 40,
		combat_spellcrit = 15,
		inc_damage = { [DamageType.TEMPORAL] = 40,  },
		resists_pen = { [DamageType.TEMPORAL] = 30,  },
		teleport_immune = 1,
		talent_cd_reduction = {
			[Talents.T_CHRONO_TIME_SHIELD] = 3,
			[Talents.T_TIME_SHIELD] = 3,
			[Talents.T_STOP] = 2,
			[Talents.T_ATTENUATE] = 1,
		},
		talents_types_mastery = {
			["chronomancy/stasis"] = 0.1,
			["chronomancy/flux"] = 0.1,
			["spell/temporal"] = 0.1,
		},
	},
}