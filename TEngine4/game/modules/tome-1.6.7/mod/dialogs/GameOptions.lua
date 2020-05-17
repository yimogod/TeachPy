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

require "engine.class"
local Dialog = require "engine.ui.Dialog"
local TreeList = require "engine.ui.TreeList"
local Textzone = require "engine.ui.Textzone"
local Separator = require "engine.ui.Separator"
local GetQuantity = require "engine.dialogs.GetQuantity"
local GetQuantitySlider = require "engine.dialogs.GetQuantitySlider"
local Tabs = require "engine.ui.Tabs"
local GraphicMode = require("mod.dialogs.GraphicMode")
local FontPackage = require "engine.FontPackage"

module(..., package.seeall, class.inherit(Dialog))

function _M:init()
	-- we can be called from the boot menu, so make sure to load initial settings in this case
	dofile("/mod/settings.lua")

	Dialog.init(self, "Game Options", game.w * 0.8, game.h * 0.8)

	self.vsep = Separator.new{dir="horizontal", size=self.ih - 10}
	self.c_desc = Textzone.new{width=math.floor((self.iw - self.vsep.w)/2), height=self.ih, text=""}

	local tabs = {
		{title="UI", kind="ui"},
		{title="Gameplay", kind="gameplay"},
		{title="Online", kind="online"},
		{title="Misc", kind="misc"}
	}
	self:triggerHook{"GameOptions:tabs", tab=function(title, fct)
		local id = #tabs+1
		tabs[id] = {title=title, kind="hooktab"..id}
		self['generateListHooktab'..id] = fct
	end}

	self.c_tabs = Tabs.new{width=self.iw - 5, tabs=tabs, on_change=function(kind) self:switchTo(kind) end}

	self:loadUI{
		{left=0, top=0, ui=self.c_tabs},
		{left=0, top=self.c_tabs.h, ui=self.c_list},
		{right=0, top=self.c_tabs.h, ui=self.c_desc},
		{hcenter=0, top=5+self.c_tabs.h, ui=self.vsep},
	}
	self:setFocus(self.c_list)
	self:setupUI()

	self.key:addBinds{
		EXIT = function() game:unregisterDialog(self) end,
	}
end

function _M:select(item)
	if item and self.uis[3] then
		self:replaceUI(self.uis[3].ui, item.zone)
	end
end

function _M:isTome()
	return game.__mod_info.short_name == "tome"
end

function _M:switchTo(kind)
	self['generateList'..kind:capitalize()](self)
	self:triggerHook{"GameOptions:generateList", list=self.list, kind=kind}

	self.c_list = TreeList.new{width=math.floor((self.iw - self.vsep.w)/2), height=self.ih - 10, scrollbar=true, columns={
		{width=60, display_prop="name"},
		{width=40, display_prop="status"},
	}, tree=self.list, fct=function(item) end, select=function(item, sel) self:select(item) end}
	if self.uis and self.uis[2] then
		self:replaceUI(self.uis[2].ui, self.c_list)
	end
end

function _M:generateListUi()
	-- Makes up the list
	local list = {}
	local i = 0

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Select the graphical mode to display the world.\nDefault is 'Modern'.\nWhen you change it, make a new character or it may look strange."}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Graphic Mode#WHITE##{normal}#", status=function(item)
		local ts = GraphicMode.tiles_packs[config.settings.tome.gfx.tiles]
		local size = config.settings.tome.gfx.size or "???x???"
		return (ts and ts.name or "???").." <"..size..">"
	end, fct=function(item)
		game:registerDialog(GraphicMode.new())
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Make the movement of creatures and projectiles 'smooth'. When set to 0 movement will be instantaneous.\nThe higher this value the slower the movements will appear.\n\nNote: This does not affect the turn-based idea of the game. You can move again while your character is still moving, and it will correctly update and compute a new animation."}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Smooth creatures movement#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.smooth_move)
	end, fct=function(item)
		game:registerDialog(GetQuantity.new("Enter movement speed(lower is faster)", "From 0 to 60", config.settings.tome.smooth_move, 60, function(qty)
			game:saveSettings("tome.smooth_move", ("tome.smooth_move = %d\n"):format(qty))
			config.settings.tome.smooth_move = qty
			if self:isTome() then engine.Map.smooth_scroll = qty end
			self.c_list:drawItem(item)
		end))
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Enables or disables 'twitch' movement.\nWhen enabled creatures will do small bumps when moving and attacking.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Twitch creatures movement and attack#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.twitch_move and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.twitch_move = not config.settings.tome.twitch_move
		game:saveSettings("tome.twitch_move", ("tome.twitch_move = %s\n"):format(tostring(config.settings.tome.twitch_move)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Enables smooth fog-of-war.\nDisabling it will make the fog of war look 'blocky' but might gain a slight performance increase.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Smooth fog of war#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.smooth_fov and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.smooth_fov = not config.settings.tome.smooth_fov
		game:saveSettings("tome.smooth_fov", ("tome.smooth_fov = %s\n"):format(tostring(config.settings.tome.smooth_fov)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Select the interface look. Metal is the default one. Simple is basic but takes less screen space.\nYou must restart the game for the change to take effect."}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Interface Style#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.ui_theme3):capitalize()
	end, fct=function(item)
		local uis = {{name="Dark", ui="dark"}, {name="Metal", ui="metal"}, {name="Stone", ui="stone"}, {name="Simple", ui="simple"}}
		self:triggerHook{"GameOptions:UIs", uis=uis}
		Dialog:listPopup("Interface style", "Select style", uis, 300, 200, function(sel)
			if not sel or not sel.ui then return end
			game:saveSettings("tome.ui_theme3", ("tome.ui_theme3 = %q\n"):format(sel.ui))
			config.settings.tome.ui_theme3 = sel.ui
			self.c_list:drawItem(item)
		end)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Select the HUD look. 'Minimalist' is the default one.\n#LIGHT_RED#This will take effect on next restart."}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#HUD Style#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.uiset_mode):capitalize()
	end, fct=function(item)
		local huds = {{name="Minimalist", ui="Minimalist"}, {name="Classic", ui="Classic"}}
		self:triggerHook{"GameOptions:HUDs", huds=huds}
		Dialog:listPopup("HUD style", "Select style", huds, 300, 200, function(sel)
			if not sel or not sel.ui then return end
			game:saveSettings("tome.uiset_mode", ("tome.uiset_mode = %q\n"):format(sel.ui))
			config.settings.tome.uiset_mode = sel.ui
			self.c_list:drawItem(item)
		end)
	end,}

	if self:isTome() and game.uiset:checkGameOption("log_lines") then	
		local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"The number of lines to display in the combat log (for the Classic HUD)."}
		list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Log lines#WHITE##{normal}#", status=function(item)
			return tostring(config.settings.tome.log_lines)
		end, fct=function(item)
			game:registerDialog(GetQuantity.new("Log lines", "From 5 to 50", config.settings.tome.log_lines, 50, function(qty)
				qty = util.bound(qty, 5, 50)
				game:saveSettings("tome.log_lines", ("tome.log_lines = %d\n"):format(qty))
				config.settings.tome.log_lines = qty
				if self:isTome() then
					game.uiset.logdisplay.resizeToLines()
				end
				self.c_list:drawItem(item)
			end, 0))
		end,}
	end

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Draw faint lines to separate each grid, making visual positioning easier to see.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Display map grid lines#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.show_grid_lines and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.show_grid_lines = not config.settings.tome.show_grid_lines
		game:saveSettings("tome.show_grid_lines", ("tome.show_grid_lines = %s\n"):format(tostring(config.settings.tome.show_grid_lines)))
		self.c_list:drawItem(item)
		if self:isTome() then game:createMapGridLines() end
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Select the fonts look. Fantasy is the default one. Basic is simplified and smaller.\nYou must restart the game for the change to take effect."}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Font Style#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.fonts.type):capitalize()
	end, fct=function(item)
		local list = FontPackage:list()
		Dialog:listPopup("Font style", "Select font", list, 300, 200, function(sel)
			if not sel or not sel.id then return end
			game:saveSettings("tome.fonts", ("tome.fonts = { type = %q, size = %q }\n"):format(sel.id, config.settings.tome.fonts.size))
			config.settings.tome.fonts.type = sel.id
			self.c_list:drawItem(item)
		end)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Select the fonts size.\nYou must restart the game for the change to take effect."}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Font Size#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.fonts.size):capitalize()
	end, fct=function(item)
		Dialog:listPopup("Font size", "Select font", {{name="Normal", size="normal"},{name="Small", size="small"},{name="Big", size="big"},}, 300, 200, function(sel)
			if not sel or not sel.size then return end
			game:saveSettings("tome.fonts", ("tome.fonts = { type = %q, size = %q }\n"):format(config.settings.tome.fonts.type, sel.size))
			config.settings.tome.fonts.size = sel.size
			self.c_list:drawItem(item)
		end)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"How many seconds before log and chat lines begin to fade away.\nIf set to 0 the logs will never fade away."}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Log fade time#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.log_fade)
	end, fct=function(item)
		game:registerDialog(GetQuantity.new("Fade time (in seconds)", "From 0 to 20", config.settings.tome.log_fade, 20, function(qty)
			qty = util.bound(qty, 0, 20)
			game:saveSettings("tome.log_fade", ("tome.log_fade = %d\n"):format(qty))
			config.settings.tome.log_fade = qty
			if self:isTome() then
				game.uiset.logdisplay:enableFading(config.settings.tome.log_fade)
				profile.chat:enableFading(config.settings.tome.log_fade)
			end
			self.c_list:drawItem(item)
		end, 0))
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"How long will flying text messages be visible on screen.\nThe range is 1 (very short) to 100 (10x slower) than the normal duration, which varies with each individual message."}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Duration of flying text#WHITE##{normal}#", status=function(item)
		return tostring((config.settings.tome.flyers_fade_time or 10) )
	end, fct=function(item)
		game:registerDialog(GetQuantity.new("Relative duration", "From 1 to 100", (config.settings.tome.flyers_fade_time or 10), 100, function(qty)
			qty = util.bound(qty, 1, 100)
			config.settings.tome.flyers_fade_time = qty
			game:saveSettings("tome.flyers_fade_time", ("tome.flyers_fade_time = %d\n"):format(qty))
			self.c_list:drawItem(item)
		end, 1))
	end,}

	if self:isTome() then
		if game.uiset:checkGameOption("icons_temp_effects") then
			local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Uses the icons for status effects instead of text.#WHITE#"}
			list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Icons status effects#WHITE##{normal}#", status=function(item)
				return tostring(config.settings.tome.effects_icons and "enabled" or "disabled")
			end, fct=function(item)
				config.settings.tome.effects_icons = not config.settings.tome.effects_icons
				game:saveSettings("tome.effects_icons", ("tome.effects_icons = %s\n"):format(tostring(config.settings.tome.effects_icons)))
				if self:isTome() then game.player.changed = true end
				self.c_list:drawItem(item)
			end,}
		end

		if game.uiset:checkGameOption("icons_hotkeys") then
			local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Uses the icons hotkeys toolbar or the textual one.#WHITE#"}
			list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Icons hotkey toolbar#WHITE##{normal}#", status=function(item)
				return tostring(config.settings.tome.hotkey_icons and "enabled" or "disabled")
			end, fct=function(item)
				config.settings.tome.hotkey_icons = not config.settings.tome.hotkey_icons
				game:saveSettings("tome.hotkey_icons", ("tome.hotkey_icons = %s\n"):format(tostring(config.settings.tome.hotkey_icons)))
				if self:isTome() then game.player.changed = true game:resizeIconsHotkeysToolbar() end
				self.c_list:drawItem(item)
			end,}
		end

		if game.uiset:checkGameOption("hotkeys_rows") then
			local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Number of rows to show in the icons hotkeys toolbar.#WHITE#"}
			list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Icons hotkey toolbar rows#WHITE##{normal}#", status=function(item)
				return tostring(config.settings.tome.hotkey_icons_rows)
			end, fct=function(item)
				game:registerDialog(GetQuantity.new("Number of icons rows", "From 1 to 4", config.settings.tome.hotkey_icons_rows, 4, function(qty)
					qty = util.bound(qty, 1, 4)
					game:saveSettings("tome.hotkey_icons_rows", ("tome.hotkey_icons_rows = %d\n"):format(qty))
					config.settings.tome.hotkey_icons_rows = qty
					if self:isTome() then game:resizeIconsHotkeysToolbar() end
					self.c_list:drawItem(item)
				end, 1))
			end,}
		end
	end

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"When you activate a hotkey, either by keyboard or click a visual feedback will appear over it in the hotkeys bar.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Visual hotkeys feedback#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.visual_hotkeys and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.visual_hotkeys = not config.settings.tome.visual_hotkeys
		game:saveSettings("tome.visual_hotkeys", ("tome.visual_hotkeys = %s\n"):format(tostring(config.settings.tome.visual_hotkeys)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"When the player or an NPC uses a talent shows a quick popup with the talent's icon and name over its head.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Talents activations map display#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.talents_flyers and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.talents_flyers = not config.settings.tome.talents_flyers
		game:saveSettings("tome.talents_flyers", ("tome.talents_flyers = %s\n"):format(tostring(config.settings.tome.talents_flyers)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Size of the icons in the hotkeys toolbar.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Icons hotkey toolbar icon size#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.hotkey_icons_size)
	end, fct=function(item)
		game:registerDialog(GetQuantity.new("Icons size", "From 32 to 64", config.settings.tome.hotkey_icons_size, 64, function(qty)
			qty = util.bound(qty, 32, 64)
			game:saveSettings("tome.hotkey_icons_size", ("tome.hotkey_icons_size = %d\n"):format(qty))
			config.settings.tome.hotkey_icons_size = qty
			if self:isTome() then game:resizeIconsHotkeysToolbar() end
			self.c_list:drawItem(item)
		end, 32))
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"If disabled lore popups will only appear the first time you see the lore on your profile.\nIf enabled it will appear the first time you see it with each character.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Always show lore popup#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.lore_popup and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.lore_popup = not config.settings.tome.lore_popup
		game:saveSettings("tome.lore_popup", ("tome.lore_popup = %s\n"):format(tostring(config.settings.tome.lore_popup)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"If disabled items with activations will not be auto-added to your hotkeys, you will need to manualty drag them from the inventory screen.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Always add objects to hotkeys#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.auto_hotkey_object and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.auto_hotkey_object = not config.settings.tome.auto_hotkey_object
		game:saveSettings("tome.auto_hotkey_object", ("tome.auto_hotkey_object = %s\n"):format(tostring(config.settings.tome.auto_hotkey_object)))
		self.c_list:drawItem(item)
	end,}

	if self:isTome() then
		local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString[[Toggles between various tactical information display:
- Combined healthbar and small tactical frame
- Combined healthbar and big tactical frame
- Only healthbar
- No tactical information at all

#{italic}#You can also change this directly ingame by pressing shift+T.#{normal}##WHITE#]]}
		list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Tactical overlay#WHITE##{normal}#", status=function(item)
			local vs = "Combined Small"
			if game.always_target == "old" then
				vs = "Combined Big"
			elseif game.always_target == "health" then
				vs = "Only Healthbars"
			elseif game.always_target == nil then
				vs = "Nothing"
			elseif game.always_target == true then
				vs = "Combined Small"
			end
			return vs
		end, fct=function(item)
			Dialog:listPopup("Tactical overlay", "Select overlay mode", {
				{name="Combined Small", mode=true},
				{name="Combined Big", mode="old"},
				{name="Only Healthbars", mode="health"},
				{name="Nothing", mode=nil},
			}, 300, 200, function(sel)
				if not sel then return end
				game:setTacticalMode(sel.mode)
				self.c_list:drawItem(item)
			end)
		end,}
	end

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Toggles between a normal or flagpost tactical bars.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Flagpost tactical bars#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.flagpost_tactical and "Enabled" or "Disabled")
	end, fct=function(item)
		config.settings.tome.flagpost_tactical = not config.settings.tome.flagpost_tactical
		game:saveSettings("tome.flagpost_tactical", ("tome.flagpost_tactical = %s\n"):format(tostring(config.settings.tome.flagpost_tactical)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Toggles between a bottom or side display for tactial healthbars.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Healthbars position#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.small_frame_side and "Sides" or "Bottom")
	end, fct=function(item)
		config.settings.tome.small_frame_side = not config.settings.tome.small_frame_side
		game:saveSettings("tome.small_frame_side", ("tome.small_frame_side = %s\n"):format(tostring(config.settings.tome.small_frame_side)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"If disabled you will not get a fullscreen notification of stun/daze effects. Beware.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Fullscreen stun/daze notification#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.fullscreen_stun and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.fullscreen_stun = not config.settings.tome.fullscreen_stun
		game:saveSettings("tome.fullscreen_stun", ("tome.fullscreen_stun = %s\n"):format(tostring(config.settings.tome.fullscreen_stun)))
		self.c_list:drawItem(item)
		if self:isTome() then if game.player.updateMainShader then game.player:updateMainShader() end end
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"If disabled you will not get a fullscreen notification of confusion effects. Beware.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Fullscreen confusion notification#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.fullscreen_confusion and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.fullscreen_confusion = not config.settings.tome.fullscreen_confusion
		game:saveSettings("tome.fullscreen_confusion", ("tome.fullscreen_confusion = %s\n"):format(tostring(config.settings.tome.fullscreen_confusion)))
		self.c_list:drawItem(item)
		if self:isTome() then if game.player.updateMainShader then game.player:updateMainShader() end end
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Toggles advanced weapon statistics display.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Advanced Weapon Statistics#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.advanced_weapon_stats and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.advanced_weapon_stats = not config.settings.tome.advanced_weapon_stats
		game:saveSettings("tome.advanced_weapon_stats", ("tome.advanced_weapon_stats = %s\n"):format(tostring(config.settings.tome.advanced_weapon_stats)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Always display the combat properties of gloves even if you don't know unarmed attack talents.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Always show glove combat properties#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.display_glove_stats and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.display_glove_stats = not config.settings.tome.display_glove_stats
		game:saveSettings("tome.display_glove_stats", ("tome.display_glove_stats = %s\n"):format(tostring(config.settings.tome.display_glove_stats)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Always display combat properties of shields even if you don't know shield attack talents.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Always show shield combat properties#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.display_shield_stats and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.display_shield_stats = not config.settings.tome.display_shield_stats
		game:saveSettings("tome.display_shield_stats", ("tome.display_shield_stats = %s\n"):format(tostring(config.settings.tome.display_shield_stats)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"When you do a mouse gesture (right click + drag) a color coded trail is displayed.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Display mouse gesture trails#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.hide_gestures and "disabled" or "enabled")
	end, fct=function(item)
		config.settings.hide_gestures = not config.settings.hide_gestures
		game:saveSettings("hide_gestures", ("hide_gestures = %s\n"):format(tostring(config.settings.hide_gestures)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"If enabled new quests and quests updates will display a big popup, if not a simple line of text will fly on the screen.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Big Quest Popups#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.quest_popup and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.quest_popup = not config.settings.tome.quest_popup
		game:saveSettings("tome.quest_popup", ("tome.quest_popup = %s\n"):format(tostring(config.settings.tome.quest_popup)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Sharpen Visuals, set to 0 to disable.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Sharpen Visuals#WHITE##{normal}#", status=function(item)
		return tostring((config.settings.tome.sharpen_display or 0))
	end, fct=function(item)
		game:registerDialog(GetQuantitySlider.new("Enter Sharpen Power", "From 0(disable) to 10", math.floor(config.settings.tome.sharpen_display or 0), 0, 10, 1, function(qty)
			qty = util.bound(qty, 0, 10)
			game:saveSettings("tome.sharpen_display", ("tome.sharpen_display = %f\n"):format(qty))
			config.settings.tome.sharpen_display = qty
			self.c_list:drawItem(item)
			if self:isTome() and game.player then game.player:updateMainShader() end
		end))
	end,}

	self.list = list
end

function _M:generateListGameplay()
	-- Makes up the list
	local list = {}
	local i = 0

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Defines the distance from the screen edge at which scrolling will start. If set high enough the game will always center on the player.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Scroll distance#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.scroll_dist)
	end, fct=function(item)
		game:registerDialog(GetQuantity.new("Scroll distance", "From 1 to 50", config.settings.tome.scroll_dist, 50, function(qty)
			qty = util.bound(qty, 1, 50)
			game:saveSettings("tome.scroll_dist", ("tome.scroll_dist = %d\n"):format(qty))
			config.settings.tome.scroll_dist = qty
			self.c_list:drawItem(item)
		end, 1))
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"If you loose more than this percentage of life in a turn, a warning will display and all key/mouse input will be ignored for 2 seconds to prevent mistakes.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Life Lost Warning#WHITE##{normal}#", status=function(item)
		return (not config.settings.tome.life_lost_warning or config.settings.tome.life_lost_warning == 100) and "disabled" or tostring(config.settings.tome.life_lost_warning).."%"
	end, fct=function(item)
		game:registerDialog(GetQuantity.new("Life lost percentage (out of max life)", "From 1 to 99 (100 to disable)", config.settings.tome.life_lost_warning or 100, 100, function(qty)
			qty = util.bound(qty, 1, 100)
			game:saveSettings("tome.life_lost_warning", ("tome.life_lost_warning = %d\n"):format(qty))
			config.settings.tome.life_lost_warning = qty
			self.c_list:drawItem(item)
		end, 1))
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Enables or disables weather effects in some zones.\nDisabling it can gain some performance. It will not affect previously visited zones.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Weather effects#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.weather_effects and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.weather_effects = not config.settings.tome.weather_effects
		game:saveSettings("tome.weather_effects", ("tome.weather_effects = %s\n"):format(tostring(config.settings.tome.weather_effects)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Enables or disables day/night light variations effects..#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Day/night light cycle#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.daynight and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.daynight = not config.settings.tome.daynight
		game:saveSettings("tome.daynight", ("tome.daynight = %s\n"):format(tostring(config.settings.tome.daynight)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Enables easy movement using the mouse by left-clicking on the map.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Use mouse to move#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.mouse_move and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.mouse_move = not config.settings.mouse_move
		game:saveSettings("mouse_move", ("mouse_move = %s\n"):format(tostring(config.settings.mouse_move)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Enables quick melee targeting.\nTalents that require a melee target will automatically target when pressing a direction key instead of requiring a confirmation.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Quick melee targeting#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.immediate_melee_keys and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.immediate_melee_keys = not config.settings.tome.immediate_melee_keys
		game:saveSettings("tome.immediate_melee_keys", ("tome.immediate_melee_keys = %s\n"):format(tostring(config.settings.tome.immediate_melee_keys)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Enables quick melee targeting auto attacking.\nTalents that require a melee target will automatically target and confirm if there is only one hostile creatue around.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Quick melee targeting auto attack#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.immediate_melee_keys_auto and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.immediate_melee_keys_auto = not config.settings.tome.immediate_melee_keys_auto
		game:saveSettings("tome.immediate_melee_keys_auto", ("tome.immediate_melee_keys_auto = %s\n"):format(tostring(config.settings.tome.immediate_melee_keys_auto)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Enables mouse targeting. If disabled mouse movements will not change the target when casting a spell or using a talent.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Mouse targeting#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.disable_mouse_targeting and "disabled" or "enabled")
	end, fct=function(item)
		config.settings.tome.disable_mouse_targeting = not config.settings.tome.disable_mouse_targeting
		game:saveSettings("tome.disable_mouse_targeting", ("tome.disable_mouse_targeting = %s\n"):format(tostring(config.settings.tome.disable_mouse_targeting)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Auto-validate targets. If you fire an arrow/talent/... it will automatically use the default target without asking\n#LIGHT_RED#This is dangerous. Do not enable unless you know exactly what you are doing.#WHITE#\n\nDefault target is always either one of:\n - The last creature hovered by the mouse\n - The last attacked creature\n - The closest creature"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Auto-accept target#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.auto_accept_target and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.auto_accept_target = not config.settings.auto_accept_target
		game:saveSettings("auto_accept_target", ("auto_accept_target = %s\n"):format(tostring(config.settings.auto_accept_target)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"New games begin with some talent points auto-assigned.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Auto-assign talent points at birth#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.autoassign_talents_on_birth and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.autoassign_talents_on_birth = not config.settings.tome.autoassign_talents_on_birth
		game:saveSettings("tome.autoassign_talents_on_birth", ("tome.autoassign_talents_on_birth = %s\n"):format(tostring(config.settings.tome.autoassign_talents_on_birth)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Always rest to full before auto-exploring.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Rest before auto-explore#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.rest_before_explore and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.rest_before_explore = not config.settings.tome.rest_before_explore
		game:saveSettings("tome.rest_before_explore", ("tome.rest_before_explore = %s\n"):format(tostring(config.settings.tome.rest_before_explore)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"When swaping an item with a tinker attached, swap the tinker to the newly worn item automatically.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Swap tinkers#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.tinker_auto_switch and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.tinker_auto_switch = not config.settings.tome.tinker_auto_switch
		game:saveSettings("tome.tinker_auto_switch", ("tome.tinker_auto_switch = %s\n"):format(tostring(config.settings.tome.tinker_auto_switch)))
		self.c_list:drawItem(item)
	end,}

	self.list = list
end

function _M:generateListOnline()
	-- Makes up the list
	local list = {}
	local i = 0

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Configure the chat filters to select what kind of messages to see.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Chat message filters#WHITE##{normal}#", status=function(item)
		return "select to configure"
	end, fct=function(item)
		game:registerDialog(require("engine.dialogs.ChatFilter").new({
			{name="Deaths", kind="death"},
			{name="Object & Creatures links", kind="link"},
		}))
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Configure the chat ignore filter.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Chat ignore list#WHITE##{normal}#", status=function(item)
		return "select to configure"
	end, fct=function(item)	game:registerDialog(require("engine.dialogs.ChatIgnores").new()) end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Configure the chat channels to listen to.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Chat channels#WHITE##{normal}#", status=function(item)
		return "select to configure"
	end, fct=function(item)	game:registerDialog(require("engine.dialogs.ChatChannels").new()) end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Open links in external browser instead of the embedded one.\nThis does not affect addons browse and installation which always stays ingame."}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Open links in external browser#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.open_links_external and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.open_links_external = not config.settings.open_links_external
		game:saveSettings("open_links_external", ("open_links_external = %s\n"):format(tostring(config.settings.open_links_external)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Enable Discord's Rich Presence integration to show your current character on your currently playing profile on Discord (restart the game to apply).\n#ANTIQUE_WHITE#If you do not use Discord this option doesn't do anything in either state."}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Discord's Rich Presence#WHITE##{normal}#", status=function(item)
		return tostring(not config.settings.disable_discord and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.disable_discord = not config.settings.disable_discord
		game:saveSettings("disable_discord", ("disable_discord = %s\n"):format(tostring(config.settings.disable_discord)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Keep a copy of your character sheets (not the whole savefile) on the online vault at te4.org.\nFor each character you will be given a link to this online character sheet so that you can brag about your heroic deeds or sad deaths to your friends or the whole community.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Upload characters sheets to the online vault#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.upload_charsheet and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.upload_charsheet = not config.settings.upload_charsheet
		game:saveSettings("tome.upload_charsheet", ("tome.upload_charsheet = %s\n"):format(tostring(config.settings.upload_charsheet)))
		self.c_list:drawItem(item)

	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Allow various events that are pushed by the server when playing online\n#{bold}#All#{normal}#: Allow all server events (bonus zones, random events, ...)\n#{bold}#Technical help only#{normal}#: Allow administrator to help in case of bugs or weirdness and allows website services (data reset, steam achievements push, ...) to work.\n#{bold}#Disabled#{normal}#: Disallow all.\n#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Allow online events#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.allow_online_events == true and "all" or (config.settings.allow_online_events == "limited" and "technical help only" or "disabled"))
	end, fct=function(item)
		if config.settings.allow_online_events == true then config.settings.allow_online_events = "limited"
		elseif config.settings.allow_online_events == "limited" then config.settings.allow_online_events = false
		else config.settings.allow_online_events = true end
		game:saveSettings("allow_online_events", ("allow_online_events = %s\n"):format(config.settings.allow_online_events == "limited" and "'limited'" or tostring(config.settings.allow_online_events)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, scrollbar=true, text=string.toTString[[Disables all connectivity to the network.
This includes, but is not limited to:
- Player profiles: You will not be able to login, register
- Characters vault: You will not be able to upload any character to the online vault to show your glory
- Item's Vault: You will not be able to access the online item's vault, this includes both storing and retrieving items.
- Ingame chat: The ingame chat requires to connect to the server to talk to other players, this will not be possible.
- Purchaser / Donator benefits: The base game being free, the only way to give donators their bonuses fairly is to check their online profile. This will thus be disabled.
- Easy addons downloading & installation: You will not be able to see ingame the list of available addons, nor to one-click install them. You may still do so manually.
- Version checks: Addons will not be checked for new versions.
- Discord: If you use Discord Rich Presence integration this will also be disabled by this setting.
- Ingame game news: The main menu will stop showing you info about new updates to the game.

Note that this setting only affects the game itself. If you use the game launcher, whose sole purpose is to make sure the game is up to date, it will still do so.
If you do not want that, simply run the game directly: the #{bold}#only#{normal}# use of the launcher is to update the game.

#{bold}##CRIMSON#This is an extremely restrictive setting. It is recommended you only activate it if you have no other choice as it will remove many fun and acclaimed features.
A full exit and restart of the game is neccessary to apply this setting.#{normal}#]]}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Disable all connectivity#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.disable_all_connectivity and "yes" or "no")
	end, fct=function(item)
		config.settings.disable_all_connectivity = not config.settings.disable_all_connectivity
		game:saveSettings("disable_all_connectivity", ("disable_all_connectivity = %s\n"):format(tostring(config.settings.disable_all_connectivity)))
		self.c_list:drawItem(item)
	end,}

	self.list = list
end

function _M:generateListMisc()
	-- Makes up the list
	local list = {}
	local i = 0

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Saves in the background, allowing you to continue playing.\n#LIGHT_RED#Disabling it is not recommended.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Save in the background#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.background_saves and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.background_saves = not config.settings.background_saves
		game:saveSettings("background_saves", ("background_saves = %s\n"):format(tostring(config.settings.background_saves)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Forces the game to save each level instead of each zone.\nThis makes it save more often but the game will use less memory when deep in a dungeon.\n\n#LIGHT_RED#Changing this option will not affect already visited zones.\n*THIS DOES NOT MAKE A FULL SAVE EACH LEVEL*.\n#LIGHT_RED#Disabling it is not recommended#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Zone save per level#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.save_zone_levels and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.save_zone_levels = not config.settings.tome.save_zone_levels
		game:saveSettings("tome.save_zone_levels", ("tome.save_zone_levels = %s\n"):format(tostring(config.settings.tome.save_zone_levels)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Disallow boot images that could be found 'offensive'.#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Censor boot#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.censor_boot and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.censor_boot = not config.settings.censor_boot
		game:saveSettings("censor_boot", ("censor_boot = %s\n"):format(tostring(config.settings.censor_boot)))
		self.c_list:drawItem(item)
	end,}

	local zone = Textzone.new{width=self.c_desc.w, height=self.c_desc.h, text=string.toTString"Replace headwear images by cloak hoods if a cloak is worn#WHITE#"}
	list[#list+1] = { zone=zone, name=string.toTString"#GOLD##{bold}#Show cloak hoods#WHITE##{normal}#", status=function(item)
		return tostring(config.settings.tome.show_cloak_hoods and "enabled" or "disabled")
	end, fct=function(item)
		config.settings.tome.show_cloak_hoods = not config.settings.tome.show_cloak_hoods
		game:saveSettings("tome.show_cloak_hoods", ("tome.show_cloak_hoods = %s\n"):format(tostring(config.settings.tome.show_cloak_hoods)))
		self.c_list:drawItem(item)
		if self:isTome() and game.level then
			for uid, e in pairs(game.level.entities) do
				if e.updateModdableTile then e:updateModdableTile() end
			end
		end
	end,}

	self.list = list
end
