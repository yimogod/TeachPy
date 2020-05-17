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
load("/data/general/npcs/horror.lua")
load("/data/general/npcs/feline.lua", function(e) e.rarity = nil end)

local Talents = require("engine.interface.ActorTalents")

newEntity{ base = "BASE_NPC_HORROR", define_as="WEIRDLING_BEAST",
	name = "Weirdling Beast", color=colors.VIOLET, unique = true,
	desc = "A roughly humanoid creature, with tentacle-like appendages in the place of arms and legs. You gasp in horror as you notice it has no head. Putrid warts form quickly on its skin and explode as quickly.",
	killer_message = "and slowly consumed",
	level_range = {19, nil}, exp_worth = 3,
	rank = 3.5,
	autolevel = "caster",
	max_life = 300, life_rating = 16,
	combat_armor = 10, combat_def = 0,

	ai = "tactical", ai_state = { talent_in=2, ai_move="move_astar", },

	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1, QUIVER=1 },

	resists = {[DamageType.ARCANE] = -10, [DamageType.BLIGHT] = 10, [DamageType.PHYSICAL] = 10},

	disease_immune = 1,
	blind_immune = 1,
	fear_immune = 1,
	see_invisible = 100,
	vim_regen = 20,
	negative_regen = 15,

	resolvers.equip{
		{type="weapon", subtype="staff", autoreq=true, force_drop=true, forbid_power_source={antimagic=true}, tome_drops="boss"},
		{type="armor", subtype="light", autoreq=true, force_drop=true, forbid_power_source={antimagic=true}, tome_drops="boss"}
	},
	resolvers.drops{chance=100, nb=3, {tome_drops="boss"} },

	resolvers.talents{
		[Talents.T_STAFF_MASTERY]= {base=2, every=10, max=5},
		[Talents.T_ACID_BLOOD]={base=4, every=8, max=5},
		[Talents.T_BONE_GRAB]={base=4, every=8, max=5},
		[Talents.T_BONE_SHIELD]={base=3, every=10, max=5},
		[Talents.T_MIND_SEAR]={base=4, every=8, max=5},
		[Talents.T_TELEKINETIC_BLAST]={base=4, every=8, max=5},
		[Talents.T_GLOOM]={base=5, every=10, max=6},
		[Talents.T_SOUL_ROT]={base=3, every=10, max=5},
		[Talents.T_CORRUPTED_NEGATION]={base=4, every=8, max=5},
		[Talents.T_TIME_PRISON]={base=1, every=10, max=5},
		[Talents.T_STARFALL]={base=3, every=10, max=5},
		[Talents.T_MANATHRUST]={base=4, every=8, max=5},
		[Talents.T_FREEZE]={base=2, every=9, max=5},
	},
	max_inscriptions = 6,
	resolvers.inscription("INFUSION:_HEALING", {cooldown=6, dur=5, heal=400}),
	resolvers.inscription("INFUSION:_REGENERATION", {cooldown=10, dur=5, heal=400}),
	resolvers.inscription("INFUSION:_WILD", {cooldown=8, what={physical=true}, dur=4, power=45}),
	resolvers.inscription("RUNE:_SHIELDING", {cooldown=10, dur=5, power=500}),
	resolvers.inscription("TAINT:_DEVOURER", {cooldown=10, effects=4, heal=75}),
	resolvers.inscriptions(1, {"manasurge rune"}),

	
	-- The theme of this boss confuses me, I assume its supposed to just feel very random and weird, so, ADHD classes it is
	auto_classes={
		{class="Anorithil", start_level=22, level_rate=25},
		{class="Doomed", start_level=22, level_rate=25},
		{class="Corruptor", start_level=22, level_rate=25},
		{class="Archmage", start_level=22, level_rate=25},
	},

	resolvers.sustains_at_birth(),

	on_die = function()
		-- Open the door, destroy the stairs
		local g = game.zone:makeEntityByName(game.level, "terrain", "OLD_FLOOR")
		local spot = game.level:pickSpot{type="door", subtype="weirdling"}
		if spot then
			game.zone:addEntity(game.level, g, "terrain", spot.x, spot.y)
			game.log("#LIGHT_RED#As the Weirdling beast falls it shrieks one last time and the door behind it shatters and explodes, revealing the room behind it. The stair up vanishes!")
		end
		local spot = game.level:pickSpot{type="stair", subtype="up"}
		if spot then
			game.zone:addEntity(game.level, g, "terrain", spot.x, spot.y)
		end

		-- Change the in/out spots for later
		local spot = game.level:pickSpot{type="portal", subtype="back"}
		if spot then game.level.default_up.x, game.level.default_up.y = spot.x, spot.y end
		local spot = game.level:pickSpot{type="portal", subtype="back"}
		if spot then game.level.default_down.x, game.level.default_down.y = spot.x, spot.y end

		-- Update the worldmap with a shortcut to here
		game:onLevelLoad("wilderness-1", function(zone, level)
			local g = mod.class.Grid.new{
				show_tooltip=true, always_remember = true,
				name="Teleportation portal to the Sher'Tul Fortress",
				display='>', color=colors.ANTIQUE_WHITE, image = "terrain/grass.png", add_mos = {{image = "terrain/maze_teleport.png"}},
				notice = true,
				change_level=1, change_zone="shertul-fortress",
			}
			g:resolve() g:resolve(nil, true)
			local spot = level:pickSpot{type="zone-pop", subtype="shertul-fortress"}
			game.zone:addEntity(level, g, "terrain", spot.x, spot.y)
			game.nicer_tiles:updateAround(game.level, spot.x, spot.y)
			game.player.wild_x = spot.x
			game.player.wild_y = spot.y
		end)

		-- Update quest
		game.player:setQuestStatus("shertul-fortress", engine.Quest.COMPLETED, "weirdling")
	end,
}

newEntity{ base = "BASE_NPC_HORROR", define_as="BUTLER",
	subtype = "Sher'Tul",
	name = "Fortress Shadow", color=colors.GREY,
	desc = "The shadow created by the fortress, it resembles somewhat the horrors you saw previously, but it is not the same.",
	level_range = {19, nil}, exp_worth = 3,
	rank = 3,
	max_life = 300, life_rating = 16,
	invulnerable = 1, never_move = 1,
	faction = "neutral",
	never_anger = 1,
	immune_possession = 1,
	can_talk = "shertul-fortress-butler",
}

newEntity{ define_as="TRAINING_DUMMY",
	type = "training", subtype = "dummy",
	name = "Training Dummy", color=colors.GREY,
	desc = "Training dummy.", image = "npc/lure.png",
	level_range = {1, 1}, exp_worth = 0,
	rank = 3,
	max_life = 300000, life_rating = 0,
	life_regen = 300000,
	immune_possession = 1,
	never_move = 1,
	knockback_immune = 1,
	training_dummy = 1,
	on_takehit = function(self, value, src, infos)
		local data = game.zone.training_dummies
		if not data then return value end

		if not data.start_turn then data.start_turn = game.turn end

		data.total = data.total + value
		if infos and infos.damtype then
			data.damtypes.changed = true
			data.damtypes[infos.damtype] = (data.damtypes[infos.damtype] or 0) + value
		end
		data.changed = true

		if data.total > 1000000 then
			world:gainAchievement("TRAINING_DUMMY_1000000", game.player)
		end

		return value
	end,
}


newEntity{ base = "BASE_NPC_CAT", define_as = "KITTY",
	name = "Pumpkin, the little kitty", color=colors.ORANGE, unique = true,
	image="npc/sage_kitty.png",
	desc = [[An orange kitty with a white star blaze on his chest. Has a strange affinity for licking your face whenever possible.]],
	level_range = {1, nil}, exp_worth = 1,
	rarity = 4,
	immune_possession = 1,
	self_resurrect = 9,
	max_life = 50,
	invulnerable = 1,
	never_anger = true,
	movement_speed = 0.6,
	ai_state = { ai_move="move_snake", ai_target="target_player" },
	defineDisplayCallback = function() end,
}
