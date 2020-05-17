-- TE4 - T-Engine 4
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

require "engine.class"
local Dialog = require "engine.ui.Dialog"
local Birther = require "engine.Birther"
local List = require "engine.ui.List"
local TreeList = require "engine.ui.TreeList"
local ListColumns = require "engine.ui.ListColumns"
local Button = require "engine.ui.Button"
local Dropdown = require "engine.ui.Dropdown"
local Textbox = require "engine.ui.Textbox"
local Checkbox = require "engine.ui.Checkbox"
local Textzone = require "engine.ui.Textzone"
local ImageList = require "engine.ui.ImageList"
local TextzoneList = require "engine.ui.TextzoneList"
local Separator = require "engine.ui.Separator"
local NameGenerator = require "engine.NameGenerator"
local NameGenerator2 = require "engine.NameGenerator2"
local Savefile = require "engine.Savefile"
local Module = require "engine.Module"
local Tiles = require "engine.Tiles"
local Particles = require "engine.Particles"
local CharacterVaultSave = require "engine.CharacterVaultSave"
local Object = require "mod.class.Object"
local OptionTree = require "mod.dialogs.OptionTree"
local Entity = require "engine.Entity"

module(..., package.seeall, class.inherit(Birther))

_M.cosmetic_options_config = {
	hairs = "single",
	skin = "single",
	facial_features = "multiple",
	tatoos = "single",
	horns = "single",
	special = "multiple",
	golem = "single",
}

function _M:setSubclassIcon(t)
	t.image32 = "class-icons/"..(t.name:lower():gsub("[^a-z0-9]", "_")).."_32_bg.png"
	t.image128 = "class-icons/"..(t.name:lower():gsub("[^a-z0-9]", "_")).."_128_bg.png"
	if not fs.exists(Tiles.baseImageFile(t.image32)) then
		t.image32 = "class-icons/unknown_32_bg.png"
		t.image128 = "class-icons/unknown_128_bg.png"
	end
	t.display_entity32 = Entity.new{image=t.image32}
	t.display_entity128 = Entity.new{image=t.image128}
end
for _, t in pairs(_M.birth_descriptor_def.subclass) do _M:setSubclassIcon(t) end

--- Instanciates a birther for the given actor
function _M:init(title, actor, order, at_end, quickbirth, w, h)
	self.quickbirth = quickbirth
	self.actor = actor:cloneFull()
	self.actor_base = actor
	self.order = order
	self.at_end = at_end
	self.selected_cosmetic_options = nil
	self.tiles = Tiles.new(64, 64, nil, nil, true, nil)

	Dialog.init(self, title and title or "Character Creation", w or 600, h or 400)

	self.obj_list = Object:loadList("/data/general/objects/objects.lua")
	self.obj_list_by_name = {}
	for i, e in ipairs(self.obj_list) do if e.name and (e.rarity or e.define_as) then self.obj_list_by_name[e.name] = e end end

	self.descriptors = {}
	self.descriptors_by_type = {}

	self.to_reset_cosmetic = {}

	self.c_ok = Button.new{text="     Play!     ", fct=function() self:atEnd("created") end}
	self.c_random = Button.new{text="Random!", fct=function() self:randomBirth() end}
	self.c_premade = Button.new{text="Load premade", fct=function() self:loadPremadeUI() end}
	self.c_tile = Button.new{text="Select custom tile", fct=function() self:selectTile() end}
	self.c_cancel = Button.new{text="Cancel", fct=function() self:atEnd("quit") end}
	self.c_tut = Button.new{text="Tutorial", fct=function() self:tutorial() end}
	self.c_options = Button.new{text="Customize", fct=function() self:customizeOptions() end}
	self.c_options.hide = true
	self.c_extra_options = Button.new{text="Extra Options", fct=function() self:extraOptions() end}
	self.c_extra_options.hide = not game.extra_birth_option_defs or #game.extra_birth_option_defs == 0

	self.c_name = Textbox.new{title="Name: ", text=(not config.settings.cheat and game.player_name == "player") and "" or game.player_name, chars=30, max_len=50, fct=function()
		if config.settings.cheat then self:makeDefault() end
	end, on_change=function() self:setDescriptor() end, on_mouse = function(button) if button == "right" then self:randomName() end end}

	self.c_female = Checkbox.new{title="Female", default=true,
		fct=function() end,
		on_change=function(s) self.c_male.checked = not s self:setDescriptor("sex", s and "Female" or "Male") end
	}
	self.c_male = Checkbox.new{title="Male", default=false,
		fct=function() end,
		on_change=function(s) self.c_female.checked = not s self:setDescriptor("sex", s and "Male" or "Female") end
	}

	self:generateCampaigns()
	self.c_campaign_text = Textzone.new{auto_width=true, auto_height=true, text="Campaign: "}
	self.c_campaign = Dropdown.new{width=400, fct=function(item) self:campaignUse(item) end, on_select=function(item) self:updateDesc(item) end, list=self.all_campaigns, nb_items=#self.all_campaigns}

	self:generateDifficulties()
	self.c_difficulty_text = Textzone.new{auto_width=true, auto_height=true, text="Difficulty: "}
	self.c_difficulty = Dropdown.new{width=100, fct=function(item) self:difficultyUse(item) end, on_select=function(item) self:updateDesc(item) end, list=self.all_difficulties, nb_items=#self.all_difficulties}

	self:generatePermadeaths()
	self.c_permadeath_text = Textzone.new{auto_width=true, auto_height=true, text="Permadeath: "}
	self.c_permadeath = Dropdown.new{width=150, fct=function(item) self:permadeathUse(item) end, on_select=function(item) self:updateDesc(item) end, list=self.all_permadeaths, nb_items=#self.all_permadeaths}

	self.c_desc = TextzoneList.new{width=math.floor(self.iw / 3 - 10), height=self.ih - self.c_female.h - self.c_ok.h - self.c_difficulty.h - self.c_campaign.h - 10, scrollbar=true, pingpong=20, no_color_bleed=true}

	self:setDescriptor("base", "base")
	self:setDescriptor("world", self.default_campaign)
	self:setDescriptor("difficulty", self.default_difficulty)
	self:setDescriptor("permadeath", self.default_permadeath)
	self:setDescriptor("sex", "Female")

	self:generateRaces()
	self.c_race = TreeList.new{width=math.floor(self.iw / 3 - 10), height=self.ih - self.c_female.h - self.c_ok.h - (self.c_extra_options.hide and 0 or self.c_extra_options.h) - self.c_difficulty.h - self.c_campaign.h - 10, scrollbar=true, columns={
		{width=100, display_prop="name"},
	}, tree=self.all_races,
		fct=function(item, sel, v) self:raceUse(item, sel, v) end,
		select=function(item, sel) self:updateDesc(item) end,
		on_expand=function(item) end,
	}

	self:generateClasses()
	self.c_class = TreeList.new{width=math.floor(self.iw / 3 - 10), height=self.ih - self.c_female.h - self.c_ok.h - self.c_difficulty.h - self.c_campaign.h - 10, scrollbar=true, columns={
		{width=100, display_prop="name"},
	}, tree=self.all_classes,
		fct=function(item, sel, v) self:classUse(item, sel, v) end,
		select=function(item, sel) self:updateDesc(item) end,
		on_expand=function(item) end,
		on_drawitem=function(item, s, startx, h)
			if not item.def or not item.def.display_entity32 then return startx end
			local sc = item.def.display_entity32:getEntityFinalSurface(self.tiles, h, h)
			if sc then s:merge(sc, startx, 0) end
			return startx + h
		end,
	}

	self.cur_order = 1
	self.sel = 1

	self:loadUI{
		-- First line
		{left=0, top=0, ui=self.c_name},
		{left=self.c_name, top=0, ui=self.c_female},
		{left=self.c_female, top=0, ui=self.c_male},

		-- Second line
		{left=0, top=self.c_name, ui=self.c_campaign_text},
		{left=self.c_campaign_text, top=self.c_name, ui=self.c_campaign},

		-- Third line
		{left=0, top=self.c_campaign, ui=self.c_difficulty_text},
		{left=self.c_difficulty_text, top=self.c_campaign, ui=self.c_difficulty},
		{left=self.c_difficulty, top=self.c_campaign, ui=self.c_permadeath_text},
		{left=self.c_permadeath_text, top=self.c_campaign, ui=self.c_permadeath},
		{right=0, top=self.c_name, ui=self.c_tut},

		-- Lists
		{left=0, top=self.c_permadeath, ui=self.c_race},
		{left=self.c_race, top=self.c_permadeath, ui=self.c_class},
		{right=0, top=self.c_permadeath, ui=self.c_desc},

		-- Buttons
		{left=0, bottom=0, ui=self.c_ok, hidden=true},
		{left=self.c_ok, bottom=0, ui=self.c_random},
		{left=self.c_random, bottom=0, ui=self.c_premade},
		{left=self.c_premade, bottom=0, ui=self.c_tile},
		{left=self.c_tile, bottom=0, ui=self.c_options},
		{right=0, bottom=0, ui=self.c_cancel},

		{left=0, bottom=self.c_ok, ui=self.c_extra_options},
	}
	self:setupUI()

	if self.descriptors_by_type.difficulty == "Tutorial" then
		self:permadeathUse(self.all_permadeaths[1], 1)
		self:raceUse(self.all_races[1], 1)
		self:raceUse(self.all_races[1].nodes[1], 2)
		self:classUse(self.all_classes[1], 1)
		self:classUse(self.all_classes[1].nodes[1], 2)
	end
	for i, item in ipairs(self.c_campaign.c_list.list) do if self.default_campaign == item.id then self.c_campaign.c_list.sel = i break end end
	for i, item in ipairs(self.c_difficulty.c_list.list) do if self.default_difficulty == item.id then self.c_difficulty.c_list.sel = i break end end
	for i, item in ipairs(self.c_permadeath.c_list.list) do if self.default_permadeath == item.id then self.c_permadeath.c_list.sel = i break end end
	if config.settings.tome.default_birth and config.settings.tome.default_birth.sex then
		self.c_female.checked = config.settings.tome.default_birth.sex == "Female"
		self.c_male.checked = config.settings.tome.default_birth.sex ~= "Female"
		self:setDescriptor("sex", self.c_female.checked and "Female" or "Male")
	end
	self:setFocus(self.c_campaign)
	self:setFocus(self.c_name)

	if not profile.mod.allow_build.tutorial_done then
		self:setFocus(self.c_tut)
		self.c_tut.glow = 0.70
	end
end

function _M:checkNew(fct)
	local function checkfct()
		local savename = self.c_name.text:gsub("[^a-zA-Z0-9_-.]", "_")
		if fs.exists(("/save/%s/game.teag"):format(savename)) then
			Dialog:yesnoPopup("Overwrite character?", "There is already a character with this name, do you want to overwrite it?", function(ret)
				if not ret then fct() end
			end, "No", "Yes")
		else
			fct()
		end
	end

	local is_antimagic, is_magic = false, false
	for i, d in ipairs(self.descriptors) do
		if d.copy then
			if d.copy.forbid_arcane then is_antimagic = true end
		end
		if d.talents_types then
			local tt = d.talents_types
			if type(tt) == "function" then tt = tt(self) end
			for t, v in pairs(tt) do
				local ttdef = self.actor:getTalentTypeFrom(t)
				if ttdef and ttdef.is_spell then is_magic = true break end
			end
		end
	end

	if is_magic and is_antimagic then
		Dialog:yesnoPopup("Antimagic Magic combo", "The selected race/class has both magic and antimagic, this is unlikely to work. Continue?", function(ret) if not ret then
			checkfct()
		end end, "No", "Yes I'm sure")
	else
		checkfct()
	end
end

function _M:applyingDescriptor(i, d)
	if d.unlockable_talents_types then
		for t, v in pairs(d.unlockable_talents_types) do
			if profile.mod.allow_build[v[3]] then
				local mastery
				if type(v) == "table" then
					v, mastery = v[1], v[2]
				else
					v, mastery = v, 0
				end
				self.actor:learnTalentType(t, v)
				self.actor.talents_types_mastery[t] = (self.actor.talents_types_mastery[t] or 0) + mastery
			end
		end
	end
	if d.party_copy then
		local copy = table.clone(d.party_copy, true)
		-- Append array part
		while #copy > 0 do
			local f = table.remove(copy)
			table.insert(game.party, f)
		end
		-- Copy normal data
		table.merge(game.party, copy, true)
	end
	self:applyGameState(d)
end

function _M:applyGameState(d)
	if d.game_state then
		local copy = table.clone(d.game_state, true)
		-- Append array part
		while #copy > 0 do
			local f = table.remove(copy)
			table.insert(game.state.birth, f)
		end
		-- Copy normal data
		table.merge(game.state.birth, copy, true)
	end
	if d.game_state_execute then
		d.game_state_execute()
	end
end

function _M:atEnd(v)
	if v == "created" and not self.ui_by_ui[self.c_ok].hidden then
		self:checkNew(function()
			local ps = self.actor:getParticlesList()
			for i, p in ipairs(ps) do self.actor:removeParticles(p) end
			self.actor:defineDisplayCallback()
			self.actor:removeAllMOs()

			game:unregisterDialog(self)
			self.actor = self.actor_base
			if self.has_custom_tile then
				self:setTile(self.has_custom_tile.f, self.has_custom_tile.w, self.has_custom_tile.h, true)
				self.actor.has_custom_tile = self.has_custom_tile.f
			end
			self:resetAttachementSpots()
			-- Prevent the game from auto-assigning talents if necessary.
			if (not config.settings.tome.autoassign_talents_on_birth) and not game.state.birth.always_learn_birth_talents then
				for _, d in pairs(self.descriptors) do
					local unlearned_talents = { }

					if (d.talents ~= nil and (d.type == "race" or d.type == "subrace" or d.type == "class" or d.type == "subclass")) then
						for t_id, t_level in pairs(d.talents) do
							local talent = self.actor:getTalentFromId(t_id)
							if (talent ~= nil and not talent.no_unlearn_last) then
								--[[ Award talent points based on the highest available level of the talent
								     This is in the potential case of a player selecting a race with two points in phase door
								     and Archmage as his class. Archmage starts with one point in phase door. Cases like this may
									 result in a conflict of what the player might expect to get back in points. The highest
									 amount of points is always awarded to the player (two, in this case).
								  ]]
								if (unlearned_talents[talent] == nil) then
									unlearned_talents[talent] = t_level
								elseif (unlearned_talents[talent] < t_level) then
									unlearned_talents[talent] = t_level
								end

								self.actor:learnPool(talent)
								print("[BIRTHER] Ignoring auto-assign for " .. t_id .. " (from " .. d.type .. " descriptor \"" .. d.name .. "\")")
								d.talents[t_id] = nil
							end
						end

						-- Give the player the appropriate amount of talent points
						for talent, t_level in pairs(unlearned_talents) do
							if (talent.generic == true) then
								self.actor.unused_generics = self.actor.unused_generics + t_level
							else
								self.actor.unused_talents = self.actor.unused_talents + t_level
							end
						end
					end
				end
			end
			self:apply()
			if self.has_custom_tile then
				self.actor.make_tile = nil
				self.actor.moddable_tile = nil
			end
			self:applyCosmeticActor(true)
			game:setPlayerName(self.c_name.text)

			local save = Savefile.new(game.save_name)
			save:delete()
			save:close()

			if self.actor.descriptor.difficulty ~= "Tutorial" then game:saveSettings("tome.default_birth", ("tome.default_birth = {permadeath=%q, difficulty=%q, sex=%q, campaign=%q}\n"):format(self.actor.descriptor.permadeath, self.actor.descriptor.difficulty, self.actor.descriptor.sex, self.actor.descriptor.world)) end

			self.at_end(false)
		end)
	elseif v == "loaded" then
		self:checkNew(function()
			game:unregisterDialog(self)
			game:setPlayerName(self.c_name.text)

			for type, kind in pairs(game.player.descriptor) do
				local d = self:getBirthDescriptor(type, kind)
				if d then self:applyGameState(d) end
			end

			self.at_end(true)
		end)
	elseif v == "quit" then
		util.showMainMenu()
	end
end

--- Make a default character when using cheat mode, for easier testing
function _M:makeDefault()
	self:setDescriptor("sex", "Female")
	self:setDescriptor("world", "Maj'Eyal")
	-- self:setDescriptor("world", "Infinite")
	self:setDescriptor("difficulty", "Normal")
	self:setDescriptor("permadeath", "Adventure")
	self:setDescriptor("race", "Human")
	self:setDescriptor("subrace", "Cornac")
	-- self:setDescriptor("class", "Mage")
	-- self:setDescriptor("subclass", "Archmage")
	self:setDescriptor("class", "Warrior")
	self:setDescriptor("subclass", "Berserker")
	__module_extra_info.no_birth_popup = true
	self:atEnd("created")
end

--- Run one of the tutorials
function _M:tutorial()
	local run = function(t)
		self:setDescriptor("sex", "Female")
		self:setDescriptor("world", "Maj'Eyal")
		self:setDescriptor("difficulty", "Tutorial")
		self:setDescriptor("permadeath", "Adventure")
		self:setDescriptor("race", "Tutorial Human")
		self:setDescriptor("subrace", "Tutorial "..t)
		self:setDescriptor("class", "Tutorial Adventurer")
		self:setDescriptor("subclass", "Tutorial Adventurer")
		self:randomName()
		self:atEnd("created")
	end

	local d = Dialog.new("Tutorials", 280, 100)
	local basic = Button.new{text="Basic Gameplay (recommended)", fct=function() run("Basic") d.key:triggerVirtual("EXIT") end}
--	local stats = Button.new{text="Stats and effects (advanced players)", fct=function() run("Stats") d.key:triggerVirtual("EXIT") end}
	local cancel = Button.new{text="Cancel", fct=function() d.key:triggerVirtual("EXIT") end}
	local sep = Separator.new{dir="vertical", size=230}

	d:loadUI{
		{hcenter=0, top=0, ui=basic},
--		{hcenter=0, top=basic.h, ui=stats},
		{hcenter=0, bottom=cancel.h, ui=sep},
		{hcenter=0, bottom=0, ui=cancel},
	}
	d:setupUI(false, true)
	d.key:addBind("EXIT", function() game:unregisterDialog(d) end)
	game:registerDialog(d)
end

function _M:randomBirth()
	-- Random sex
	local sex = rng.percent(50)
	self.c_male.checked = sex
	self.c_female.checked = not sex
	self:setDescriptor("sex", sex and "Male" or "Female")

	self.descriptors_by_type.race = nil
	self.descriptors_by_type.subrace = nil
	self.descriptors_by_type.class = nil
	self.descriptors_by_type.subclass = nil
--[[
	-- Random campaign
	local camp, camp_id = nil
	repeat camp, camp_id = rng.table(self.c_campaign.c_list.list)
	until not camp.locked
	self.c_campaign.c_list.sel = camp_id
	self:campaignUse(camp)

	-- Random difficulty
	local diff, diff_id = nil
	repeat diff, diff_id = rng.table(self.c_difficulty.c_list.list)
	until diff.name ~= "Tutorial" and not diff.locked
	self.c_difficulty.c_list.sel = diff_id
	self:difficultyUse(diff)
--]]
	-- Random race
	local race, race_id = nil
	repeat race, race_id = rng.table(self.all_races)
	until not race.locked
	self:raceUse(race)

	-- Random subrace
	local subrace, subrace_id = nil
	repeat subrace, subrace_id = rng.table(self.all_races[race_id].nodes)
	until not subrace.locked
	self:raceUse(subrace)

	-- Random class
	local class, class_id = nil
	repeat class, class_id = rng.table(self.all_classes)
	until not class or not class.locked
	self:classUse(class)

	-- Random subclass
	if class then
		local subclass, subclass_id = nil
		repeat subclass, subclass_id = rng.table(self.all_classes[class_id].nodes)
		until not subclass.locked
		self:classUse(subclass)
	end

	self:randomName()
end

function _M:randomName()
	if not self.descriptors_by_type.sex or not self.descriptors_by_type.subrace then return end
	local sex_def = self.birth_descriptor_def.sex[self.descriptors_by_type.sex]
	local race_def = self.birth_descriptor_def.race[self.descriptors_by_type.race]
	local subrace_def = self.birth_descriptor_def.subrace[self.descriptors_by_type.subrace]
	local name_def = nil
	if subrace_def.copy and subrace_def.copy.random_name_def then name_def = subrace_def
	elseif race_def.copy and race_def.copy.random_name_def then name_def = race_def end

	if name_def then
		local namegen = NameGenerator2.new("/data/languages/names/"..name_def.copy.random_name_def:gsub("#sex#", sex_def.copy.female and "female" or "male")..".txt")
		self.c_name:setText(namegen:generate(nil, name_def.copy.random_name_min_syllables, name_def.copy.random_name_max_syllables))
	else
		local namegen = NameGenerator.new((not sex_def.copy.female) and {
			phonemesVocals = "a, e, i, o, u, y",
			phonemesConsonants = "b, c, ch, ck, cz, d, dh, f, g, gh, h, j, k, kh, l, m, n, p, ph, q, r, rh, s, sh, t, th, ts, tz, v, w, x, z, zh",
			syllablesStart = "Aer, Al, Am, An, Ar, Arm, Arth, B, Bal, Bar, Be, Bel, Ber, Bok, Bor, Bran, Breg, Bren, Brod, Cam, Chal, Cham, Ch, Cuth, Dag, Daim, Dair, Del, Dr, Dur, Duv, Ear, Elen, Er, Erel, Erem, Fal, Ful, Gal, G, Get, Gil, Gor, Grin, Gun, H, Hal, Han, Har, Hath, Hett, Hur, Iss, Khel, K, Kor, Lel, Lor, M, Mal, Man, Mard, N, Ol, Radh, Rag, Relg, Rh, Run, Sam, Tarr, T, Tor, Tul, Tur, Ul, Ulf, Unr, Ur, Urth, Yar, Z, Zan, Zer",
			syllablesMiddle = "de, do, dra, du, duna, ga, go, hara, kaltho, la, latha, le, ma, nari, ra, re, rego, ro, rodda, romi, rui, sa, to, ya, zila",
			syllablesEnd = "bar, bers, blek, chak, chik, dan, dar, das, dig, dil, din, dir, dor, dur, fang, fast, gar, gas, gen, gorn, grim, gund, had, hek, hell, hir, hor, kan, kath, khad, kor, lach, lar, ldil, ldir, leg, len, lin, mas, mnir, ndil, ndur, neg, nik, ntir, rab, rach, rain, rak, ran, rand, rath, rek, rig, rim, rin, rion, sin, sta, stir, sus, tar, thad, thel, tir, von, vor, yon, zor",
			rules = "$s$v$35m$10m$e",
		} or {
			phonemesVocals = "a, e, i, o, u, y",
			syllablesStart = "Ad, Aer, Ar, Bel, Bet, Beth, Ce'N, Cyr, Eilin, El, Em, Emel, G, Gl, Glor, Is, Isl, Iv, Lay, Lis, May, Ner, Pol, Por, Sal, Sil, Vel, Vor, X, Xan, Xer, Yv, Zub",
			syllablesMiddle = "bre, da, dhe, ga, lda, le, lra, mi, ra, ri, ria, re, se, ya",
			syllablesEnd = "ba, beth, da, kira, laith, lle, ma, mina, mira, na, nn, nne, nor, ra, rin, ssra, ta, th, tha, thra, tira, tta, vea, vena, we, wen, wyn",
			rules = "$s$v$35m$10m$e",
		})
		self.c_name:setText(namegen:generate())
	end
end

function _M:on_focus(id, ui)
	if self.focus_ui and self.focus_ui.ui == self.c_name then self.c_desc:switchItem(self.c_name, "This is the name of your character.\nRight mouse click to generate a random name based on race and sex.")
	elseif self.focus_ui and self.focus_ui.ui == self.c_female then self.c_desc:switchItem(self.c_female, self.birth_descriptor_def.sex.Female.desc)
	elseif self.focus_ui and self.focus_ui.ui == self.c_male then self.c_desc:switchItem(self.c_male, self.birth_descriptor_def.sex.Male.desc)
	elseif self.focus_ui and self.focus_ui.ui == self.c_campaign then
		local item = self.c_campaign.c_list.list[self.c_campaign.c_list.sel]
		self.c_desc:switchItem(item, item.desc)
	elseif self.focus_ui and self.focus_ui.ui == self.c_difficulty then
		local item = self.c_difficulty.c_list.list[self.c_difficulty.c_list.sel]
		self.c_desc:switchItem(item, item.desc)
	elseif self.focus_ui and self.focus_ui.ui == self.c_permadeath then
		local item = self.c_permadeath.c_list.list[self.c_permadeath.c_list.sel]
		self.c_desc:switchItem(item, item.desc)
	end
end

function _M:updateDesc(item)
	if item and item.desc then
		self.c_desc:switchItem(item, item.desc)
	end
end

function _M:campaignUse(item)
	if not item then return end
	if item.locked then
		self.c_campaign.c_list.sel = self.c_campaign.previous
	else
		self:setDescriptor("world", item.id)

		self:generateDifficulties()
		self:generatePermadeaths()
		self:generateRaces()
		self:generateClasses()
	end
end

function _M:difficultyUse(item)
	if not item then return end
	if item.locked then
		self.c_difficulty.c_list.sel = self.c_difficulty.previous
	else
		self:setDescriptor("difficulty", item.id)

		self:generatePermadeaths()
		self:generateRaces()
		self:generateRaces()
		self:generateClasses()
	end
end

function _M:permadeathUse(item)
	if not item then return end
	if item.locked then
		self.c_permadeath.c_list.sel = self.c_permadeath.previous
		if item.locked_select then item.locked_select(self) end
	else
		self:setDescriptor("permadeath", item.id)

		self:generateRaces()
		self:generateClasses()
	end
end

function _M:raceUse(item, sel, v)
	if not item then return end
	if item.nodes then
		for i, item in ipairs(self.c_race.tree) do if item.shown then self.c_race:treeExpand(false, item) end end
		self.c_race:treeExpand(nil, item)
	elseif not item.locked and item.basename then
		if self.sel_race then
			self.sel_race.name = self.sel_race.basename
			self.c_race:drawItem(self.sel_race)
		end
		self:setDescriptor("race", item.pid)
		self:setDescriptor("subrace", item.id)
		self.sel_race = item
		self.sel_race.name = tstring{{"font","bold"}, {"color","LIGHT_GREEN"}, self.sel_race.basename:toString(), {"font","normal"}}
		self.c_race:drawItem(item)

		self:generateClasses()
	end
end

function _M:classUse(item, sel, v)
	if not item then return end
	if item.nodes then
		for i, item in ipairs(self.c_class.tree) do if item.shown then self.c_class:treeExpand(false, item) end end
		self.c_class:treeExpand(nil, item)
	elseif not item.locked and item.basename then
		if self.sel_class then
			self.sel_class.name = self.sel_class.basename
			self.c_class:drawItem(self.sel_class)
		end
		self:setDescriptor("class", item.pid)
		self:setDescriptor("subclass", item.id)
		self.sel_class = item
		self.sel_class.name = tstring{{"font","bold"}, {"color","LIGHT_GREEN"}, self.sel_class.basename:toString(), {"font","normal"}}
		self.c_class:drawItem(item)
	end
end

function _M:updateDescriptors()
	self.descriptors = {}
	table.insert(self.descriptors, self.birth_descriptor_def.base[self.descriptors_by_type.base])
	table.insert(self.descriptors, self.birth_descriptor_def.world[self.descriptors_by_type.world])
	table.insert(self.descriptors, self.birth_descriptor_def.difficulty[self.descriptors_by_type.difficulty])
	table.insert(self.descriptors, self.birth_descriptor_def.permadeath[self.descriptors_by_type.permadeath])
	table.insert(self.descriptors, self.birth_descriptor_def.sex[self.descriptors_by_type.sex])
	if self.descriptors_by_type.subrace then
		table.insert(self.descriptors, self.birth_descriptor_def.race[self.descriptors_by_type.race])
		table.insert(self.descriptors, self.birth_descriptor_def.subrace[self.descriptors_by_type.subrace])
	end
	if self.descriptors_by_type.subclass then
		table.insert(self.descriptors, self.birth_descriptor_def.class[self.descriptors_by_type.class])
		table.insert(self.descriptors, self.birth_descriptor_def.subclass[self.descriptors_by_type.subclass])
	end

	self.cosmetic_options = {}
	self.cosmetic_options_flat = {}
	for _, d in ipairs(self.descriptors) do if d.cosmetic_options then
		for kind, list in pairs(d.cosmetic_options) do
			local clist = {}
			local sublists = {}
			for _, data in ipairs(list) do
				if (not data.unlock or profile.mod.allow_build[data.unlock]) and (not data.check or data.check(self)) then
					local ok = true
					if data.addons then for i, v in ipairs(data.addons) do
						if not game:isAddonActive(v) then ok = false break end
					end end
					if data.only_for then for k, v in pairs(data.only_for) do
						if self.descriptors_by_type[k] ~= v then ok = false break end
					end end
					if data.birth_only and self.not_birthing then ok = false end
					if ok then
						data.kind = kind
						data.color = function(item)
							if item.selected then return colors.simple(colors.LIGHT_GREEN)
							else return colors.simple(colors.WHITE) end
						end
						if data.subkind then
							sublists[data.subkind] = sublists[data.subkind] or {}
							table.insert(sublists[data.subkind], data)
						else
							table.insert(clist, data)
						end
						table.insert(self.cosmetic_options_flat, data)
					end
				end
			end

			for name, list in pairs(sublists) do
				table.sort(list, function(a, b) return a.name < b.name end)
				table.insert(clist, {name=name, subkind=name, color=function() return colors.simple(colors.ROYAL_BLUE) end, nodes=list})
			end

			if #clist > 0 then
				table.sort(clist, function(a, b) return a.name < b.name end)
				table.insert(self.cosmetic_options, {name=kind:gsub("_", " "):capitalize(), kind=kind, color=function() return colors.simple(colors.GOLD) end, nodes=clist})
			end
		end
	end end
	table.sort(self.cosmetic_options, function(a, b) return a.name < b.name end)
	self.c_options.hide = #self.cosmetic_options == 0
	
	if self.old_cosmetic_sex ~= self.descriptors_by_type.sex or self.old_cosmetic_race ~= self.descriptors_by_type.race or self.old_cosmetic_subrace ~= self.descriptors_by_type.subrace then
		self.selected_cosmetic_options = nil
	end

	self.old_cosmetic_sex = self.descriptors_by_type.sex
	self.old_cosmetic_race = self.descriptors_by_type.race
	self.old_cosmetic_subrace = self.descriptors_by_type.subrace
end

function _M:selectRandomCosmetics(filters)
	self.selected_cosmetic_options = {}
	local function select(items)
		local item = rng.table(items)
		if item then
			if self.cosmetic_options_config[item.kind] == "single" then
				self.selected_cosmetic_options[item.kind] = item
			elseif self.cosmetic_options_config[item.kind] == "multiple" then
				self.selected_cosmetic_options[item.kind] = self.selected_cosmetic_options[item.kind] or {}
				table.insert(self.selected_cosmetic_options[item.kind], item)
			end
		end
	end

	for _, e in ipairs(filters) do
		if not e.percent or rng.percent(e.percent) then
			local items = {}

			if e.filter[1] == "all" then
				for _, item in ipairs(self.cosmetic_options_flat) do
					if (e.allow_mtx_pack or not item.mtx_pack) and item.kind == e.kind then items[#items+1] = item end
				end
			elseif e.filter[1] == "oneof" then
				local list = table.reverse(e.filter[2])
				for _, item in ipairs(self.cosmetic_options_flat) do
					if (e.allow_mtx_pack or not item.mtx_pack) and item.kind == e.kind and list[item.name] then items[#items+1] = item end
				end
			elseif e.filter[1] == "findname" then
				for _, item in ipairs(self.cosmetic_options_flat) do
					if (e.allow_mtx_pack or not item.mtx_pack) and item.kind == e.kind and item.name:find(e.filter[2]) then items[#items+1] = item end
				end
			end

			select(items)
		end
	end
end

function _M:isDescriptorSet(key, val)
	return self.descriptors_by_type[key] == val
end

function _M:setDescriptor(key, val)
	if key then
		self.descriptors_by_type[key] = val
		print("[BIRTHER] set descriptor", key, val)
	end
	self:updateDescriptors()
	self:setTile()

	local ok = self.c_name.text:len() >= 2
	for i, o in ipairs(self.order) do
		if not self.descriptors_by_type[o] then
			ok = false
			print("Missing ", o)
			break
		end
	end
	self:toggleDisplay(self.c_ok, ok)
end

function _M:isDescriptorAllowed(d, ignore_type)
	self:updateDescriptors()

	if type(ignore_type) == "string" then
		ignore_type = {[ignore_type] = true}
	end
	ignore_type = ignore_type or {}

	local allowed = true
	local type = d.type
	print("[BIRTHER] checking allowance for ", d.name, d.type, "::", table.serialize(ignore_type, nil, true))
	for j, od in ipairs(self.descriptors) do
		if od.descriptor_choices and od.descriptor_choices[type] and not ignore_type[type] then
			local what = util.getval(od.descriptor_choices[type][d.name], self) or util.getval(od.descriptor_choices[type].__ALL__, self)
			if what and what == "allow" then
				allowed = true
			elseif what and what == "nolore" then
				allowed = "nolore"
			elseif what and what == "allow-nochange" then
				if not allowed then allowed = true end
			elseif what and (what == "never" or what == "disallow") then
				allowed = false
			elseif what and what == "forbid" then
				allowed = nil
			end
			print("[BIRTHER] test against ", od.name, "=>", what, allowed)
			if allowed == nil then break end
		end
	end

	if d.special_check and not d.special_check(self) then return nil end

	-- Check it is allowed
	return allowed and not d.never_show
end

function _M:getLock(d)
	if not d.locked then return false end
	local ret = d.locked(self)
	if ret == "hide" then return "hide" end
	return not ret
end

function _M:generateCampaigns()
	local locktext = "\n\n#GOLD#This is a locked birth option. Performing certain actions and completing certain quests will make locked campaigns, races and classes permanently available."
	local list = {}

	for i, d in ipairs(self.birth_descriptor_def.world) do
		if self:isDescriptorAllowed(d, {difficulty=true, permadeath=true, race=true, subrace=true, class=true, subclass=true}) then
			local locked = self:getLock(d)
			if locked == true then
				list[#list+1] = { name = tstring{{"font", "italic"}, {"color", "GREY"}, "-- locked --", {"font", "normal"}}:toString(), id=d.name, locked=true, desc=util.getval(d.locked_desc, self)..locktext }
			elseif locked == false then
				local desc = d.desc
				if type(desc) == "table" then desc = table.concat(d.desc, "\n") end
				list[#list+1] = { name = tstring{d.display_name}:toString(), id=d.name, desc=desc }
				if util.getval(d.selection_default) then self.default_campaign = d.name end
			end
		end
	end

	self.all_campaigns = list
	if not self.default_campaign then self.default_campaign = list[1].id end
end

function _M:generateDifficulties()
	local locktext = "\n\n#GOLD#This is a locked birth option. Performing certain actions and completing certain quests will make locked campaigns, races and classes permanently available."
	local list = {}

	local oldsel = nil
	if self.c_difficulty then
		oldsel = self.c_difficulty.c_list.list[self.c_difficulty.c_list.sel].id
	end

	for i, d in ipairs(self.birth_descriptor_def.difficulty) do
		if self:isDescriptorAllowed(d, {permadeath=true, race=true, subrace=true, class=true, subclass=true}) then
			local locked = self:getLock(d)
			if locked == true then
				list[#list+1] = { name = tstring{{"font", "italic"}, {"color", "GREY"}, "-- locked --", {"font", "normal"}}:toString(), id=d.name, locked=true, desc=util.getval(d.locked_desc, self)..locktext }
			elseif locked == false then
				local desc = d.desc
				if type(desc) == "table" then desc = table.concat(d.desc, "\n") end
				list[#list+1] = { name = tstring{d.display_name}:toString(), id=d.name, desc=desc }
				if oldsel == d.name then oldsel = #list end
				if util.getval(d.selection_default) then self.default_difficulty = d.name end
			end
		end
	end

	self.all_difficulties = list
	if self.c_difficulty then
		self.c_difficulty.c_list.list = self.all_difficulties
		self.c_difficulty.c_list:generate()
		if type(oldsel) == "number" then self.c_difficulty.c_list.sel = oldsel end
	end
end

function _M:generatePermadeaths()
	local locktext = "\n\n#GOLD#This is a locked birth option. Performing certain actions and completing certain quests will make locked campaigns, races and classes permanently available."
	local list = {}

	local oldsel = nil
	if self.c_permadeath then
		oldsel = self.c_permadeath.c_list.list[self.c_permadeath.c_list.sel].id
	end

	for i, d in ipairs(self.birth_descriptor_def.permadeath) do
		if self:isDescriptorAllowed(d, {race=true, subrace=true, class=true, subclass=true}) then
			local locked = self:getLock(d)
			if locked == true then
				list[#list+1] = { name = tstring{{"font", "italic"}, {"color", "GREY"}, "-- locked --", {"font", "normal"}}:toString(), id=d.name, locked=true, desc=util.getval(d.locked_desc, self)..locktext, locked_select=d.locked_select }
			elseif locked == false then
				local desc = d.desc
				if type(desc) == "table" then desc = table.concat(d.desc, "\n") end
				list[#list+1] = { name = tstring{d.display_name}:toString(), id=d.name, desc=desc }
				if oldsel == d.name then oldsel = #list end
				if util.getval(d.selection_default) then self.default_permadeath = d.name end
			end
		end
	end

	self.all_permadeaths = list
	if self.c_permadeath then
		self.c_permadeath.c_list.list = self.all_permadeaths
		self.c_permadeath.c_list:generate()
		if type(oldsel) == "number" then self.c_permadeath.c_list.sel = oldsel end
	end
end

function _M:generateRaces()
	local locktext = "\n\n#GOLD#This is a locked birth option. Performing certain actions and completing certain quests will make locked campaigns, races and classes permanently available."

	local oldtree = {}
	for i, t in ipairs(self.all_races or {}) do oldtree[t.id] = t.shown end

	local tree = {}
	local newsel = nil
	for i, d in ipairs(self.birth_descriptor_def.race) do
		if self:isDescriptorAllowed(d, {class=true, subclass=true}) then
			local nodes = {}

			for si, sd in ipairs(self.birth_descriptor_def.subrace) do
				if d.descriptor_choices.subrace[sd.name] == "allow" then
					local locked = self:getLock(sd)
					if locked == true then
						nodes[#nodes+1] = { name = tstring{{"font", "italic"}, {"color", "GREY"}, "-- locked --", {"font", "normal"}}, id=sd.name, pid=d.name, locked=true, desc=util.getval(sd.locked_desc, self)..locktext }
					elseif locked == false then
						local desc = sd.desc
						if type(desc) == "table" then desc = table.concat(sd.desc, "\n") end
						nodes[#nodes+1] = { name = sd.display_name, basename = sd.display_name, id=sd.name, pid=d.name, desc=desc }
						if self.sel_race and self.sel_race.id == sd.name then newsel = nodes[#nodes] end
					end
				end
			end

			local locked = self:getLock(d)
			if locked == true then
				tree[#tree+1] = { name = tstring{{"font", "italic"}, {"color", "GREY"}, "-- locked --", {"font", "normal"}}, id=d.name, shown = oldtree[d.name], nodes = nodes, locked=true, desc=util.getval(d.locked_desc, self)..locktext }
			elseif locked == false then
				local desc = d.desc
				if type(desc) == "table" then desc = table.concat(d.desc, "\n") end
				tree[#tree+1] = { name = tstring{{"font", "italic"}, {"color", "LIGHT_SLATE"}, d.display_name, {"font", "normal"}}, id=d.name, shown = oldtree[d.name], nodes = nodes, desc=desc }
			end
		end
	end

	self.all_races = tree
	if self.c_race then
		self.c_race.tree = self.all_races
		self.c_race:generate()
		if newsel then self:raceUse(newsel)
		else
			self.sel_race = nil
			self:setDescriptor("race", nil)
			self:setDescriptor("subrace", nil)
		end
		if self.descriptors_by_type.difficulty == "Tutorial" then
			self:raceUse(tree[1], 1)
			self:raceUse(tree[1].nodes[1], 2)
		end
	end
end

function _M:generateClasses()
	local locktext = "\n\n#GOLD#This is a locked birth option. Performing certain actions and completing certain quests will make locked campaigns, races and classes permanently available."

	local oldtree = {}
	for i, t in ipairs(self.all_classes or {}) do oldtree[t.id] = t.shown end

	local tree = {}
	local newsel = nil
	for i, d in ipairs(self.birth_descriptor_def.class) do
		if self:isDescriptorAllowed(d, {subclass=true}) then
			local nodes = {}
			for si, sd in ipairs(self.birth_descriptor_def.subclass) do
				if (d.descriptor_choices.subclass[sd.name] == "allow" or d.descriptor_choices.subclass[sd.name] == "allow-nochange" or d.descriptor_choices.subclass[sd.name] == "nolore") and self:isDescriptorAllowed(sd, {subclass=true, class=true}) then
					local locked = self:getLock(sd)
					if locked == true then
						nodes[#nodes+1] = { name = tstring{{"font", "italic"}, {"color", "GREY"}, "-- locked --", {"font", "normal"}}, id=sd.name, pid=d.name, locked=true, desc=util.getval(sd.locked_desc, self)..locktext }
					elseif locked == false then
						local old = self.descriptors_by_type.subclass
						self.descriptors_by_type.subclass = nil
						local how = self:isDescriptorAllowed(sd, {class=true})
						self.descriptors_by_type.subclass = old
						local desc = sd.desc
						if type(desc) == "table" then desc = table.concat(sd.desc, "\n") end
						if how == "nolore" and self.descriptors_by_type.subrace then
							desc = "#CRIMSON#Playing this class with the race you selected does not make much sense lore-wise. You can still do it but might miss on some special quests/...#WHITE#\n" .. desc
						end
						nodes[#nodes+1] = { name = sd.display_name, basename=sd.display_name, id=sd.name, pid=d.name, desc=desc, def=sd }
						if self.sel_class and self.sel_class.id == sd.name then newsel = nodes[#nodes] end
					end
				end
			end

			local locked = self:getLock(d)
			if locked == true then
				tree[#tree+1] = { name = tstring{{"font", "italic"}, {"color", "GREY"}, "-- locked --", {"font", "normal"}}, id=d.name, shown=oldtree[d.name], nodes = nodes, locked=true, desc=util.getval(d.locked_desc, self)..locktext }
			elseif locked == false then
				local desc = d.desc
				if type(desc) == "table" then desc = table.concat(d.desc, "\n") end
				tree[#tree+1] = { name = tstring{{"font", "italic"}, {"color", "LIGHT_SLATE"}, d.display_name, {"font", "normal"}}, id=d.name, shown=oldtree[d.name], nodes = nodes, desc=desc }
			end
		end
	end

	self.all_classes = tree
	if self.c_class then
		self.c_class.tree = self.all_classes
		self.c_class:generate()
		if newsel then self:classUse(newsel)
		else
			self.sel_class = nil
			self:setDescriptor("class", nil)
			self:setDescriptor("subclass", nil)
		end
		if self.descriptors_by_type.difficulty == "Tutorial" then
			self:classUse(tree[1], 1)
			self:classUse(tree[1].nodes[1], 2)
		elseif tree[1].id == "None" then
			self:classUse(tree[1], 1)
			self:classUse(tree[1].nodes[1], 2)
		end
	end
end

function _M:loadPremade(pm)
	local fallback = pm.force_fallback

	-- Load the entities directly
	if not fallback and pm.module_version and pm.module_version[1] == game.__mod_info.version[1] and pm.module_version[2] == game.__mod_info.version[2] and pm.module_version[3] == game.__mod_info.version[3] then
		savefile_pipe:ignoreSaveToken(true)
		local qb = savefile_pipe:doLoad(pm.short_name, "entity", "engine.CharacterVaultSave", "character")
		savefile_pipe:ignoreSaveToken(false)

		-- Load the player directly
		if qb then
			game.party = qb
			game.player = nil
			game.party:setPlayer(1, true)
			self.c_name:setText(game.player.name)
			self:atEnd("loaded")
		else
			fallback = true
		end
	else
		fallback = true
	end

	-- Fill in the descriptors and validate
	if fallback then
		local ok = 0

		-- Name
		self.c_name:setText(pm.short_name)

		-- Sex
		self.c_male.checked = pm.descriptors.sex == "Male"
		self.c_female.checked = pm.descriptors.sex == "Female"
		self:setDescriptor("sex", pm.descriptors.sex and "Male" or "Female")

		-- Campaign
		for i, item in ipairs(self.all_campaigns) do if not item.locked and item.id == pm.descriptors.world then
			self:campaignUse(item)
			self.c_campaign.c_list.sel = i
			ok = ok + 1
			break
		end end

		-- Difficulty
		for i, item in ipairs(self.all_difficulties) do if not item.locked and item.id == pm.descriptors.difficulty then
			self:difficultyUse(item)
			self.c_difficulty.c_list.sel = i
			ok = ok + 1
			break
		end end

		-- Permadeath
		for i, item in ipairs(self.all_permadeaths) do if not item.locked and item.id == pm.descriptors.permadeath then
			self:permadeathUse(item)
			self.c_permadeath.c_list.sel = i
			ok = ok + 1
			break
		end end

		-- Race
		for i, pitem in ipairs(self.all_races) do
			for j, item in ipairs(pitem.nodes) do
				if not item.locked and item.id == pm.descriptors.subrace and pitem.id == pm.descriptors.race then
					self:raceUse(pitem)
					self:raceUse(item)
					ok = ok + 1
					break
				end
			end
		end

		-- Class
		for i, pitem in ipairs(self.all_classes) do
			for j, item in ipairs(pitem.nodes) do
				if not item.locked and item.id == pm.descriptors.subclass and pitem.id == pm.descriptors.class then
					self:classUse(pitem)
					self:classUse(item)
					ok = ok + 1
					break
				end
			end
		end

		if ok == 4 then self:atEnd("created") end
	end
end

function _M:loadPremadeUI()
	local lss = Module:listVaultSavesForCurrent()
	local d = Dialog.new("Characters Vault", 600, 550)

	local sel = nil
	local sep = Separator.new{dir="horizontal", size=400}
	local desc = TextzoneList.new{width=220, height=400}
	local list list = List.new{width=350, list=lss, height=400,
		fct=function(item)
			local oldsel, oldscroll = list.sel, list.scroll
			if sel == item then self:loadPremade(sel) game:unregisterDialog(d) end
			if sel then sel.color = nil end
			item.color = colors.simple(colors.LIGHT_GREEN)
			sel = item
			list:generate()
			list.sel, list.scroll = oldsel, oldscroll
		end,
		select=function(item) desc:switchItem(item, item.description) end
	}

	local load = Button.new{text=" Load ", fct=function() if sel then self:loadPremade(sel) game:unregisterDialog(d) end end}
	local del = Button.new{text="Delete", fct=function() if sel then
		self:yesnoPopup(sel.name, "Really delete premade: "..sel.name, function(ret) if ret then
			local vault = CharacterVaultSave.new(sel.short_name)
			vault:delete()
			vault:close()
			lss = Module:listVaultSavesForCurrent()
			list.list = lss
			list:generate()
			sel = nil
		end end)
	end end}

	d:loadUI{
		{left=0, top=0, ui=list},
		{left=list, top=0, ui=sep},
		{right=0, top=0, ui=desc},

		{left=0, bottom=0, ui=load},
		{right=0, bottom=0, ui=del},
	}
	d:setupUI(true, true)
	d.key:addBind("EXIT", function() game:unregisterDialog(d) end)
	game:registerDialog(d)
end

-- Disable stuff from the base Birther
function _M:updateList() end
function _M:selectType(type) end

function _M:on_register()
	if __module_extra_info.auto_quickbirth then
		local qb_short_name = __module_extra_info.auto_quickbirth:gsub("[^a-zA-Z0-9_-.]", "_")
		local lss = Module:listVaultSavesForCurrent()
		for i, pm in ipairs(lss) do
			if pm.short_name == qb_short_name then
				self:loadPremade(pm)
				break
			end
		end
	end
end

-- Display the player tile
function _M:innerDisplay(x, y, nb_keyframes)
	if self.actor.image then
		self.actor:toScreen(self.tiles, x + self.iw - 64, y, 64, 64)
	elseif self.actor.image and self.actor.add_mos then
		self.actor:toScreen(self.tiles, x + self.iw - 64, y - 64, 128, 64)
	end

	if self.descriptors_by_type.subclass then
		local sc = self.birth_descriptor_def.subclass[self.descriptors_by_type.subclass]
		if sc.display_entity128 then
			sc.display_entity128:toScreen(self.tiles, x + self.iw - self.c_desc.w, y + 16, 64, 64)
		end
	end
end

--- Fake a body & starting equipment
function _M:fakeEquip(v)
	-- if not v then
	-- 	self.actor.body = nil
	-- 	self.actor.inven = {}
	-- else
		self.actor.inven = {}
		local fake_body = { INVEN = 1000, QS_MAINHAND = 1, QS_OFFHAND = 1, MAINHAND = 1, OFFHAND = 1, FINGER = 2, NECK = 1, LITE = 1, BODY = 1, HEAD = 1, CLOAK = 1, HANDS = 1, BELT = 1, FEET = 1, TOOL = 1, QUIVER = 1 }
		self.actor.body = fake_body
		self.actor:initBody()

		local c = self.birth_descriptor_def.class[self.descriptors_by_type.class or "Warrior"]
		local sc = self.birth_descriptor_def.subclass[self.descriptors_by_type.subclass or "Berserker"]
		local function apply_equip(r)
			for i, f in ipairs(r[1]) do
				local o = self.obj_list_by_name[f.name]
				if o and o.slot then
					o = o:clone()
					o:resolve()
					o:resolve(nil, true)
					local inven = self.actor:getInven(o.slot)
					if inven[1] and o.offslot then inven = self.actor:getInven(o.offslot) end
					if not inven[1] then inven[1] = o end
				end
			end
		end

		if v then
			for _, r in pairs(c.copy or {}) do if type(r) == "table" and r.__resolver == "equip" then apply_equip(r) end end
			for _, r in pairs(sc.copy or {}) do if type(r) == "table" and r.__resolver == "equip" then apply_equip(r) end end
		end
	-- end
end

function _M:resetAttachementSpots()
	self.actor.attachement_spots = nil
	if self.has_custom_tile then
		self.actor.attachement_spots = self.has_custom_tile.f
		return
	end

	local dbr = self.birth_descriptor_def.race[self.descriptors_by_type.race or "Human"]
	local dr = self.birth_descriptor_def.subrace[self.descriptors_by_type.subrace or "Cornac"]
	local ds = self.birth_descriptor_def.sex[self.descriptors_by_type.sex or "Female"]

	local moddable_attachement_spots = dr.moddable_attachement_spots or dbr.moddable_attachement_spots
	local moddable_attachement_spots_sexless = dr.moddable_attachement_spots_sexless or dbr.moddable_attachement_spots_sexless
	if moddable_attachement_spots then
		if moddable_attachement_spots_sexless then self.actor.attachement_spots = "dolls_"..moddable_attachement_spots.."_all"
		elseif self.descriptors_by_type.sex == "Female" then self.actor.attachement_spots = "dolls_"..moddable_attachement_spots.."_female"
		else self.actor.attachement_spots = "dolls_"..moddable_attachement_spots.."_male"
		end
	end
end

function _M:setTile(f, w, h, last, nude)
	self.actor:removeAllMOs()
	if not f then
		if not self.has_custom_tile then
			local dbr = self.birth_descriptor_def.race[self.descriptors_by_type.race or "Human"]
			local dr = self.birth_descriptor_def.subrace[self.descriptors_by_type.subrace or "Cornac"]
			local ds = self.birth_descriptor_def.sex[self.descriptors_by_type.sex or "Female"]
			local drc = dr.copy or {}
			local dbrc = dbr.copy or {}
			self.actor.image = "player/"..(self.descriptors_by_type.subrace or "Cornac"):lower():gsub("[^a-z0-9_]", "_").."_"..(self.descriptors_by_type.sex or "Female"):lower():gsub("[^a-z0-9_]", "_")..".png"
			self.actor.add_mos = nil
			self.actor.female = ds.copy.female
			self.actor.male = ds.copy.male
			self.actor.moddable_tile = drc.moddable_tile
			self.actor.moddable_tile_base = drc.moddable_tile_base
			self.actor.moddable_tile_ornament = drc.moddable_tile_ornament
			self.actor.moddable_tile_ornament2 = drc.moddable_tile_ornament2
			self.actor.moddable_tile_nude = drc.moddable_tile_nude or dbrc.moddable_tile_nude
		end
	else
		self.actor.make_tile = nil
		self.actor.moddable_tile = nil
		if h > w then
			self.actor.image = "invis.png"
			self.actor.add_mos = {{image=f, display_h=2, display_y=-1}}
		else
			self.actor.add_mos = nil
			self.actor.image = f
		end
		self.has_custom_tile = {f=f,w=w,h=h}
	end
	self:resetAttachementSpots()

	if not last then
		-- Add an example particles if any
		local ps = self.actor:getParticlesList("all")
		for i, p in ipairs(ps) do self.actor:removeParticles(p) end
		if self.actor.shader_auras then self.actor.shader_auras = {} end
		self.replace_display = nil
		if not nude then
			if self.descriptors_by_type.subclass then
				local d = self.birth_descriptor_def.subclass[self.descriptors_by_type.subclass]
				if d and d.birth_example_particles then
					local p = d.birth_example_particles
					if type(p) == "table" then p = rng.table(p) end
					p = util.getval(p, self.actor, self)
					if type(p) == "string" then self.actor:addParticles(Particles.new(p, 1)) end
				end
			end
		end

		self:fakeEquip(not nude and true or false)
		self:applyCosmeticActor(false)
		self.actor:updateModdableTile()
		self:fakeEquip(false)
	else
		self:applyCosmeticActor(true)
	end
end


function _M:applyCosmeticActor(last)
	for i, d in ipairs(self.to_reset_cosmetic) do
		d(self.actor)
	end
	self.to_reset_cosmetic = {}

	self.actor.moddable_tile_hair = nil
	self.actor.moddable_tile_facial_features = nil
	self.actor.moddable_tile_tatoo = nil
	self.actor.moddable_tile_horn = nil

	-- Grab defaults if we have no custom selection
	local cosmetics = self.selected_cosmetic_options
	if not cosmetics then
		cosmetics = {}
		local function finder(kind, name, only_for)
			if only_for then for k, v in pairs(only_for) do
				if self.descriptors_by_type[k] ~= v then return end
			end end

			for i, d in ipairs(self.cosmetic_options_flat) do
				if d.kind == kind and d.name == name then return d end
			end
		end

		local dbr = self.birth_descriptor_def.race[self.descriptors_by_type.race or "Human"]
		local dr = self.birth_descriptor_def.subrace[self.descriptors_by_type.subrace or "Cornac"]
		local default_cosmetics = nil
		if dr.default_cosmetics then default_cosmetics = dr.default_cosmetics
		elseif dbr.default_cosmetics then default_cosmetics = dbr.default_cosmetics
		end

		if default_cosmetics then for _, d in ipairs(default_cosmetics) do
			if self.cosmetic_options_config[d[1]] == "single" then
				local c = finder(d[1], d[2], d[3])
				if c then cosmetics[d[1]] = c end
			elseif self.cosmetic_options_config[d[1]] == "multiple" then
				cosmetics[d[1]] = cosmetics[d[1]] or {}
				local c = finder(d[1], d[2], d[3])
				if c then table.insert(cosmetics[d[1]], c) end
			end
		end end
	end

	-- Apply!
	for kind, d in pairs(cosmetics) do
		if kind == "hairs" then
			self.actor.moddable_tile_hair = d.file
		elseif kind == "tatoos" then
			self.actor.moddable_tile_tatoo = d.file
		elseif kind == "horns" then
			self.actor.moddable_tile_horn = d.file
		elseif kind == "skin" then
			self.actor.moddable_tile_base = d.file..".png"
		elseif kind == "facial_features" then
			for _, dd in ipairs(d) do
				self.actor.moddable_tile_facial_features = self.actor.moddable_tile_facial_features or {}
				table.insert(self.actor.moddable_tile_facial_features, dd.file)
			end
		end

		if self.cosmetic_options_config[kind] == "multiple" then
			for _, dd in ipairs(d) do if dd.on_actor then
				dd.on_actor(self.actor, self, last)
				if not last and dd.reset then
					self.to_reset_cosmetic[#self.to_reset_cosmetic+1] = dd.reset
				end
			end end
		elseif self.cosmetic_options_config[kind] == "single" then
			if d.on_actor then
				d.on_actor(self.actor, self, last)
				if not last and d.reset then
					self.to_reset_cosmetic[#self.to_reset_cosmetic+1] = d.reset
				end
			end
		end
	end
end

function _M:selectExplorationNoDonations()
	Dialog:yesnoLongPopup("Exploration mode",
	[[Exploration mode provides the characters using it with infinite lives.
Tales of Maj'Eyal is meant to be a very replayable game in which you get better by learning from mistakes (and thus from dying too).
I realize this can not please everybody and after multiple requests I have decided to grant exploration mode to donators, because it will allow player that like the game to see it all if they wish.
Beware though, infinite lives does not mean the difficulty is reduced, only that you can try as much as you want without restarting.

If you'd like to use this feature and find this game good you should consider donating. It will help ensure its survival.
While this is a free game that I am doing for fun, if it can help feed my family a bit I certainly will not complain as real life can be harsh sometimes.
You will need an online profile active and connected for the tile selector to enable. If you choose to donate now you will need to restart the game to be granted access.

Donators will also gain access to the custom tiles for their characters.]], 400, function(ret)
		if not ret then
			game:registerDialog(require("mod.dialogs.Donation").new("exploration-mode"))
		end
	end, "Later", "Donate!")
end

function _M:selectTileNoDonations()
	Dialog:yesnoLongPopup("Custom tiles",
	[[Custom Tiles have been added as a thank you to everyone that has donated to ToME.
They are a fun cosmetic feature that allows you to choose a tile for your character from a list of nearly 180 (with more to be added over time), ranging from special humanoid tiles to downright wonky ones!

If you'd like to use this feature and find this game good you should consider donating. It will help ensure its survival.
While this is a free game that I am doing for fun, if it can help feed my family a bit I certainly will not complain as real life can be harsh sometimes.
You will need an online profile active and connected for the tile selector to enable. If you choose to donate now you will need to restart the game to be granted access.

Donators will also gain access to the Exploration Mode featuring infinite lives.]], 400, function(ret)
		if not ret then
			game:registerDialog(require("mod.dialogs.Donation").new("custom-tiles"))
		end
	end, "Later", "Donate!")
end

function _M:selectTile()
	local d = Dialog.new("Select a Tile", 600, 550)

	local list = {
		"npc/alchemist_golem.png",
		"npc/armored_skeleton_warrior.png",
		"npc/barrow_wight.png",
		"npc/construct_golem_alchemist_golem.png",
		"npc/degenerated_skeleton_warrior.png",
		"npc/elder_vampire.png",
		"npc/emperor_wight.png",
		"npc/forest_wight.png",
		"npc/golem.png",
		"npc/grave_wight.png",
		"npc/horror_corrupted_dremling.png",
		"npc/horror_corrupted_drem_master.png",
		"npc/horror_eldritch_headless_horror.png",
		"npc/horror_eldritch_luminous_horror.png",
		"npc/horror_eldritch_worm_that_walks.png",
		"npc/horror_temporal_cronolith_clone.png",
		"npc/humanoid_dwarf_dwarven_earthwarden.png",
		"npc/humanoid_dwarf_dwarven_guard.png",
		"npc/humanoid_dwarf_dwarven_paddlestriker.png",
		"npc/humanoid_dwarf_dwarven_summoner.png",
		"npc/humanoid_dwarf_lumberjack.png",
		"npc/humanoid_dwarf_norgan.png",
		"npc/humanoid_dwarf_ziguranth_warrior.png",
		"npc/humanoid_elenulach_thief.png",
		"npc/humanoid_elf_anorithil.png",
		"npc/humanoid_elf_elven_archer.png",
		"npc/humanoid_elf_elven_sun_mage.png",
		"npc/humanoid_elf_fillarel_aldaren.png",
		"npc/humanoid_elf_limmir_the_jeweler.png",
		"npc/humanoid_elf_star_crusader.png",
		"npc/humanoid_halfling_derth_guard.png",
		"npc/humanoid_halfling_halfling_citizen.png",
		"npc/humanoid_halfling_halfling_gardener.png",
		"npc/humanoid_halfling_halfling_guard.png",
		"npc/humanoid_halfling_halfling_slinger.png",
		"npc/humanoid_halfling_master_slinger.png",
		"npc/humanoid_halfling_protector_myssil.png",
		"npc/humanoid_halfling_sm_halfling.png",
		"npc/humanoid_human_alchemist.png",
		"npc/humanoid_human_aluin_the_fallen.png",
		"npc/humanoid_human_apprentice_mage.png",
		"npc/humanoid_human_arcane_blade.png",
		"npc/humanoid_human_argoniel.png",
		"npc/humanoid_human_assassin.png",
		"npc/humanoid_human_bandit_lord.png",
		"npc/humanoid_human_bandit.png",
		"npc/humanoid_human_ben_cruthdar__the_cursed.png",
		"npc/humanoid_human_blood_mage.png",
		"npc/humanoid_human_celia.png",
		"npc/humanoid_human_cryomancer.png",
		"npc/humanoid_human_cutpurse.png",
		"npc/humanoid_human_derth_guard.png",
		"npc/humanoid_human_enthralled_slave.png",
		"npc/humanoid_human_fallen_sun_paladin_aeryn.png",
		"npc/humanoid_human_fire_wyrmic.png",
		"npc/humanoid_human_fryjia_loren.png",
		"npc/humanoid_human_geomancer.png",
		"npc/humanoid_human_gladiator.png",
		"npc/humanoid_human_great_gladiator.png",
		"npc/humanoid_human_harno__herald_of_last_hope.png",
		"npc/humanoid_human_hexer.png",
		"npc/humanoid_human_high_gladiator.png",
		"npc/humanoid_human_high_slinger.png",
		"npc/humanoid_human_high_sun_paladin_aeryn.png",
		"npc/humanoid_human_high_sun_paladin_rodmour.png",
		"npc/humanoid_human_human_citizen.png",
		"npc/humanoid_human_human_farmer.png",
		"npc/humanoid_human_human_guard.png",
		"npc/humanoid_human_human_sun_paladin.png",
		"npc/humanoid_human_ice_wyrmic.png",
		"npc/humanoid_human_last_hope_guard.png",
		"npc/humanoid_human_linaniil_supreme_archmage.png",
		"npc/humanoid_human_lumberjack.png",
		"npc/humanoid_human_martyr.png",
		"npc/humanoid_human_master_alchemist.png",
		"npc/humanoid_human_multihued_wyrmic.png",
		"npc/humanoid_human_necromancer.png",
		"npc/humanoid_human_pyromancer.png",
		"npc/humanoid_human_reaver.png",
		"npc/humanoid_human_rej_arkatis.png",
		"npc/humanoid_human_riala_shalarak.png",
		"npc/humanoid_human_rogue.png",
		"npc/humanoid_human_sand_wyrmic.png",
		"npc/humanoid_human_shadowblade.png",
		"npc/humanoid_human_shady_cornac_man.png",
		"npc/humanoid_human_slave_combatant.png",
		"npc/humanoid_human_slinger.png",
		"npc/humanoid_human_spectator02.png",
		"npc/humanoid_human_spectator03.png",
		"npc/humanoid_human_spectator.png",
		"npc/humanoid_human_storm_wyrmic.png",
		"npc/humanoid_human_subject_z.png",
		"npc/humanoid_human_sun_paladin_guren.png",
		"npc/humanoid_human_tannen.png",
		"npc/humanoid_human_tempest.png",
		"npc/humanoid_human_thief.png",
		"npc/humanoid_human_trickster.png",
		"npc/humanoid_human_urkis__the_high_tempest.png",
		"npc/humanoid_human_valfred_loren.png",
		"npc/humanoid_human_ziguranth_wyrmic.png",
		"npc/humanoid_orc_brotoq_the_reaver.png",
		"npc/humanoid_orc_fiery_orc_wyrmic.png",
		"npc/humanoid_orc_golbug_the_destroyer.png",
		"npc/humanoid_orc_gorbat__supreme_wyrmic_of_the_pride.png",
		"npc/humanoid_orc_grushnak__battlemaster_of_the_pride.png",
		"npc/humanoid_orc_icy_orc_wyrmic.png",
		"npc/humanoid_orc_krogar.png",
		"npc/humanoid_orc_massok_the_dragonslayer.png",
		"npc/humanoid_orc_orc_archer.png",
		"npc/humanoid_orc_orc_assassin.png",
		"npc/humanoid_orc_orc_berserker.png",
		"npc/humanoid_orc_orc_blood_mage.png",
		"npc/humanoid_orc_orc_corruptor.png",
		"npc/humanoid_orc_orc_cryomancer.png",
		"npc/humanoid_orc_orc_elite_berserker.png",
		"npc/humanoid_orc_orc_elite_fighter.png",
		"npc/humanoid_orc_orc_fighter.png",
		"npc/humanoid_orc_orc_grand_master_assassin.png",
		"npc/humanoid_orc_orc_grand_summoner.png",
		"npc/humanoid_orc_orc_high_cryomancer.png",
		"npc/humanoid_orc_orc_high_pyromancer.png",
		"npc/humanoid_orc_orc_mage_hunter.png",
		"npc/humanoid_orc_orc_master_assassin.png",
		"npc/humanoid_orc_orc_master_wyrmic.png",
		"npc/humanoid_orc_orc_necromancer.png",
		"npc/humanoid_orc_orc_pyromancer.png",
		"npc/humanoid_orc_orc_soldier.png",
		"npc/humanoid_orc_orc_summoner.png",
		"npc/humanoid_orc_orc_warrior.png",
		"npc/humanoid_orc_rak_shor_cultist.png",
		"npc/humanoid_orc_rak_shor__grand_necromancer_of_the_pride.png",
		"npc/humanoid_orc_ukruk_the_fierce.png",
		"npc/humanoid_orc_vor__grand_geomancer_of_the_pride.png",
		"npc/humanoid_orc_warmaster_gnarg.png",
		"npc/humanoid_shalore_archmage_tarelion.png",
		"npc/humanoid_shalore_elandar.png",
		"npc/humanoid_shalore_elvala_guard.png",
		"npc/humanoid_shalore_elven_blood_mage.png",
		"npc/humanoid_shalore_elven_corruptor.png",
		"npc/humanoid_shalore_elven_cultist.png",
		"npc/humanoid_shalore_elven_elite_warrior.png",
		"npc/humanoid_shalore_elven_guard.png",
		"npc/humanoid_shalore_elven_mage.png",
		"npc/humanoid_shalore_elven_tempest.png",
		"npc/humanoid_shalore_elven_warrior.png",
		"npc/humanoid_shalore_grand_corruptor.png",
		"npc/humanoid_shalore_mean_looking_elven_guard.png",
		"npc/humanoid_shalore_rhaloren_inquisitor.png",
		"npc/humanoid_shalore_shalore_rune_master.png",
		"npc/humanoid_thalore_thalore_hunter.png",
		"npc/humanoid_thalore_thalore_wilder.png",
		"npc/humanoid_thalore_ziguranth_summoner.png",
		"npc/humanoid_yaech_blood_master.png",
		"npc/humanoid_yaech_murgol__the_yaech_lord.png",
		"npc/humanoid_yaech_slaver.png",
		"npc/humanoid_yaech_yaech_diver.png",
		"npc/humanoid_yaech_yaech_hunter.png",
		"npc/humanoid_yaech_yaech_mindslayer.png",
		"npc/humanoid_yaech_yaech_psion.png",
		"npc/humanoid_yeek_yeek_wayist.png",
		"npc/humanoid_yeek_yeek_summoner.png",
		"npc/humanoid_yeek_yeek_psionic.png",
		"npc/humanoid_yeek_yeek_mindslayer.png",
		"npc/humanoid_yeek_yeek_commoner_01.png",
		"npc/humanoid_yeek_yeek_commoner_02.png",
		"npc/humanoid_yeek_yeek_commoner_03.png",
		"npc/humanoid_yeek_yeek_commoner_04.png",
		"npc/humanoid_yeek_yeek_commoner_05.png",
		"npc/humanoid_yeek_yeek_commoner_06.png",
		"npc/humanoid_yeek_yeek_commoner_07.png",
		"npc/humanoid_yeek_yeek_commoner_08.png",
		"npc/jawa_01.png",
		"npc/lesser_vampire.png",
		"npc/master_skeleton_archer.png",
		"npc/master_skeleton_warrior.png",
		"npc/master_vampire.png",
		"npc/skeleton_archer.png",
		"npc/skeleton_mage.png",
		"npc/skeleton_warrior.png",
		"npc/undead_skeleton_cowboy.png",
		"npc/the_master.png",
		"npc/vampire_lord.png",
		"npc/vampire.png",
		"npc/undead_skeleton_filio_flightfond.png",
		"npc/undead_ghoul_borfast_the_broken.png",
		"npc/horror_eldritch_umbral_horror.png",
		"npc/demon_major_general_of_urh_rok.png",
		"npc/demon_major_shasshhiy_kaish.png",
		"npc/undead_vampire_arch_zephyr.png",
		"npc/undead_ghoul_rotting_titan.png",
		"npc/humanoid_human_townsfolk_aimless_looking_merchant01_64.png",
		"npc/humanoid_human_townsfolk_battlescarred_veteran01_64.png",
		"npc/humanoid_human_townsfolk_blubbering_idiot01_64.png",
		"npc/humanoid_human_townsfolk_boilcovered_wretch01_64.png",
		"npc/humanoid_human_townsfolk_farmer_maggot01_64.png",
		"npc/humanoid_human_townsfolk_filthy_street_urchin01_64.png",
		"npc/humanoid_human_townsfolk_mangy_looking_leper01_64.png",
		"npc/humanoid_human_townsfolk_meanlooking_mercenary01_64.png",
		"npc/humanoid_human_townsfolk_pitiful_looking_beggar01_64.png",
		"npc/humanoid_human_townsfolk_singing_happy_drunk01_64.png",
		"npc/humanoid_human_townsfolk_squinteyed_rogue01_64.png",
		"npc/humanoid_human_townsfolk_village_idiot01_64.png",
		"npc/humanoid_naga_lady_zoisla_the_tidebringer.png",
		"npc/humanoid_naga_naga_nereid.png",
		"npc/humanoid_naga_naga_tidecaller.png",
		"npc/humanoid_naga_naga_tidewarden.png",
		"npc/humanoid_naga_slasul.png",
		"npc/naga_myrmidon_2.png",
		"npc/naga_myrmidon_no_armor.png",
		"npc/naga_myrmidon.png",
		"npc/naga_psyren2_2.png",
		"npc/naga_psyren2.png",
		"npc/naga_psyren.png",
		"npc/naga_tide_huntress_2.png",
		"npc/naga_tide_huntress.png",
		"npc/snowman01.png",
		"npc/snaproot_pimp.png",
		"npc/R2D2_01.png",
		"npc/humanoid_female_sluttymaid.png",
		"npc/humanoid_male_sluttymaid.png",
		"player/ascii_player_dorfhelmet_01_64.png",
		"player/ascii_player_fedora_feather_04_64.png",
		"player/ascii_player_helmet_02_64.png",
		"player/ascii_player_mario_01_64.png",
		"player/ascii_player_rogue_cloak_01_64.png",
		"player/ascii_player_wizardhat_01_64.png",
		"player/ascii_player_gentleman_01_64.png",
		"player/ascii_player_red_hood_01.png",
		"player/ascii_player_pink_amazone_01.png",
		"player/ascii_player_bunny_01.png",
		"player/ascii_player_exotic_01.png",
		"player/ascii_player_shopper_01.png",
		"player/original_handdrawn_player.png",
	}

	fs.mkdir("/data/gfx/custom-tiles/")
	for file in fs.iterate("/data/gfx/custom-tiles/", function(file) return file:find("%.png") end) do
		list[#list+1] = "custom-tiles/"..file
	end

	self:triggerHook{"Birther:donatorTiles", list=list}
	local remove = Button.new{text="Use default tile", width=240, fct=function()
		game:unregisterDialog(d)
		self.has_custom_tile = nil
		self:setTile()
	end}
	local custom = Button.new{text="Use custom-made tile", width=240, fct=function()
		self:simpleLongPopup("Howto: Custom-made tiles", ([[You can use your own custom tiles if you are a donator.
For the game to use them you must simply respect a few rules:
- they must be 64x64 or 64x128 tiles
- they must be saved as PNG files
- you must place them in folder #LIGHT_BLUE#%s#WHITE#

Once you have done so, simply restart the game and the tiles will be listed at the bottom of the list.]]):format(fs.getRealPath("/data/gfx/custom-tiles/")), 500)
	end}
	local list = ImageList.new{width=500, height=500, tile_w=64, tile_h=64, padding=10, scrollbar=true, list=list, fct=function(item)
		game:unregisterDialog(d)
		if not self:isDonator() then
			self:selectTileNoDonations()
		else
			self:setTile(item.f, item.w, item.h)
		end
	end}
	d:loadUI{
		{left=0, top=0, ui=list},
		{left=0, bottom=0, ui=remove},
		{left=250, bottom=0, ui=custom},
	}
	d:setupUI(true, true)
	d.key:addBind("EXIT", function() game:unregisterDialog(d) end)
	game:registerDialog(d)
end

function _M:isDonator()
	return profile:isDonator(1)
end

function _M:customizeOptions(cosmetic_actor, on_exit, title)
	if not cosmetic_actor then
		cosmetic_actor = self.actor:cloneFull()
	end

	local function cosmeticSetTile(...)
		local oldactor = self.actor
		self.actor = cosmetic_actor
		self:setTile(...)
		self.actor = oldactor
	end

	local d = Dialog.new(title or "Cosmetic Options", 600, 550)

	local sel = nil
	local list list = TreeList.new{width=450, tree=self.cosmetic_options, height=400, scrollbar=true, all_clicks=true,
		columns={
			{name="Name", width=100, display_prop="name"},
		},
		fct=function(item, sel, button)
			if item.nodes then
				list:treeExpand(nil, item)
				return
			end
			if button == "right" then
				local function recurs(list)
					for _, ii in ipairs(list.nodes or list) do
						if ii == item then return list end
						if ii.nodes then local r = recurs(ii) if r then return r end end
					end
				end
				local ii = recurs(self.cosmetic_options)
				if ii then
					list:treeExpand(false, ii)
				end
				return
			end

			if not self:isDonator() then
				self:yesnoPopup("Donator Feature", "Cosmetic customization is a donator-only feature.", function(ret) if ret then
					game:registerDialog(require("mod.dialogs.Donation").new())
				end end, "I want to help!", "Dismiss")
			end

			local selected = false

			self.selected_cosmetic_options = self.selected_cosmetic_options or {}
			if self.cosmetic_options_config[item.kind] == "single" then
				if self.selected_cosmetic_options[item.kind] == item then selected = false self.selected_cosmetic_options[item.kind] = nil
				else selected = true self.selected_cosmetic_options[item.kind] = item end
			elseif self.cosmetic_options_config[item.kind] == "multiple" then
				self.selected_cosmetic_options[item.kind] = self.selected_cosmetic_options[item.kind] or {}
				if table.hasInList(self.selected_cosmetic_options[item.kind], item) then selected = false table.removeFromList(self.selected_cosmetic_options[item.kind], item)
				else selected = true table.insert(self.selected_cosmetic_options[item.kind], item) end
				if #self.selected_cosmetic_options[item.kind] == 0 then self.selected_cosmetic_options[item.kind] = nil end
			end

			item.selected = selected

			if self.cosmetic_options_config[item.kind] == "single" and selected then
				for _, ii in ipairs(self.cosmetic_options_flat) do
					if ii.kind == item.kind and item.name ~= ii.name and ii.selected then
						ii.selected = false
						list:drawItem(ii, 0)
					end
				end
			end

			list:drawItem(item, 0)
			cosmeticSetTile(nil, nil, nil, false, true)
		end,
	}
	function d.innerDisplay(this, x, y, nb_keyframes)
		if cosmetic_actor.image then
			cosmetic_actor:toScreen(self.tiles, x + this.iw - 90, y + 64, 128, 128)
		elseif cosmetic_actor.image and cosmetic_actor.add_mos then
			cosmetic_actor:toScreen(self.tiles, x + this.iw - 90, y + 64, 256, 128)
		end
	end

	d:loadUI{
		{left=0, top=0, ui=list},
	}
	d:setupUI(false, true)
	d.key:addBind("EXIT", function() self:setTile() if on_exit then on_exit(cosmetic_actor) end game:unregisterDialog(d) end)
	game:registerDialog(d)
	cosmeticSetTile(nil, nil, nil, false, true)
end

function _M:extraOptions()
	local options = OptionTree.new(game.extra_birth_option_defs, 'Birth Options', 600, 550)
	options:initialize()
	game:registerDialog(options)
end

--------------------------------------------------
-- Statics
--------------------------------------------------

function _M:showCosmeticCustomizer(actor, title, on_end)
	if not actor.descriptor or not actor.descriptor.sex or not actor.descriptor.race or not actor.descriptor.subrace then
		return nil, "no actor descriptor infos"
	end

	local clone_dummy = actor:cloneFull()
	local clone = actor:cloneFull()
	local birther = _M.new("", clone_dummy, {}, function() end, nil, nil, nil)
	birther.not_birthing = true

	birther:setDescriptor("sex", actor.descriptor.sex)
	birther:setDescriptor("race", actor.descriptor.race)
	birther:setDescriptor("subrace", actor.descriptor.subrace)

	birther:customizeOptions(clone, function()
		self:yesnoPopup("Confirm", "Apply the selected cosmetics to "..actor.name.."?", function(ret) if ret then
			local oldactor = birther.actor
			birther.actor = actor
			birther:applyCosmeticActor(true)
			birther.actor = oldactor
			actor:removeAllMOs()
			actor:updateModdableTile()
			if on_end then on_end() end
		end end)
	end, title)

	return true
end
