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
local Map = require "engine.Map"

module(..., package.seeall, class.make)

local NB_VARIATIONS = 30

function _M:init()
	self.repo = {}
	self.repl = {}
	self.edits = {}
end

local function doclone(g, full)
	local saveinstead = g.__SAVEINSTEAD
	if full then g = g:cloneFull()
	else g = g:clone() end
	g.__SAVEINSTEAD = saveinstead
	return g
end

function _M:getTile(name, baseid)
	if not name then return end

	if type(name) == "table" then
		local n = name[1]
		if type(n) == "table" then n = n[baseid] end
		if rng.percent(name[2]) then n = n..rng.range(name[3], name[4]) end
		name = n
	end

	local e
	if self.repo[name] then e = self.repo[name]
	else
		self.repo[name] = game.zone:makeEntityByName(game.level, "terrain", name)
		e = self.repo[name]
	end
	if e and e.force_clone then
		e = doclone(e)
	end
	return e
end

function _M:replace(i, j, g)
	if g then
		self.repl[#self.repl+1] = {i, j, g}
	end
end

function _M:edit(i, j, id, e)
	if not e then return end
	self.edits[i] = self.edits[i] or {}
	self.edits[i][j] = self.edits[i][j] or {}
	local ee = self.edits[i][j]
	ee[#ee+1] = {use_id=id, add_displays=e.add_displays, add_mos=e.add_mos, add_mos_shader=e.add_mos_shader, image=e.image, min=e.min, max=e.max, z=e.z, copy_base=e.copy_base}
end

function _M:handle(level, i, j, use_ntl)
	local g = level.map(i, j, Map.TERRAIN)
	if g and Map.tiles.nicer_tiles then
		if g.nice_tiler or g.nice_editer or g.nice_editer2 then
			if use_ntl and not g.__ntl then return end

			if g.define_as and not g.__SAVEINSTEAD then
				local cg
				if self.saveinstead_store then
					if self.saveinstead_store[g] then
						cg = self.saveinstead_store[g]
					else
						cg = g:cloneFull()
						cg.__ntl = true
						self.saveinstead_store[g] = cg
					end
				else
					cg = g:cloneFull()
					cg.__ntl = true
				end

				g.__SAVEINSTEAD = cg
			end
			if g.nice_tiler then self["niceTile"..g.nice_tiler.method:capitalize()](self, level, i, j, g, g.nice_tiler) end
			if g.nice_editer then self["editTile"..g.nice_editer.method:capitalize()](self, level, i, j, g, g.nice_editer) end
			if g.nice_editer2 then self["editTile"..g.nice_editer2.method:capitalize()](self, level, i, j, g, g.nice_editer2) end
		end
	end
end

function _M:replaceAll(level)
	local overlay = function(self, level, mode, i, j, g) return g end
	if level.data.nicer_tiler_overlay then
		overlay = self['overlay'..level.data.nicer_tiler_overlay]
	end

	for i = 1, #self.repl do
		local r = self.repl[i]
		-- Safety check
		local og = level.map(r[1], r[2], Map.TERRAIN)
		if og and (og.change_zone or og.change_level) then
			print("[NICE TILER] *warning* refusing to remove zone/level changer at ", r[1], r[2], og.change_zone, og.change_level)
		else
			local no = overlay(self, level, "replace", r[1], r[2], r[3])
			if og.__SAVEINSTEAD then no.__SAVEINSTEAD = og.__SAVEINSTEAD end
			level.map(r[1], r[2], Map.TERRAIN, no)
		end
	end
	self.repl = {}

	-- In-place entities edition, now this is becoming tricky, but powerful
	for i, jj in pairs(self.edits) do for j, ee in pairs(jj) do
		local g = level.map(i, j, Map.TERRAIN)
		if g.__nice_tile_base then
			local base = g.__nice_tile_base
			g = doclone(base)
			g:removeAllMOs()
			g.__nice_tile_base = base
		else
			g = doclone(g)
			g:removeAllMOs()
			g.__nice_tile_base = doclone(g)
		end

		local id = {g.name or "???"}
		for __, e in ipairs(ee) do
			if not e.use_id then id = nil break end
			id[#id+1] = e.use_id
		end
		if id then id = table.concat(id, "|") end

		-- If we made this one already, use it
		if self.edit_entity_store and self.edit_entity_store[id] then
			level.map(i, j, Map.TERRAIN, self.edit_entity_store[id])
		-- Otherwise compute this new combo and store the entity
		else
			local cloned = false
			if not g.force_clone or not self.edit_entity_store then g = doclone(g, true) g.force_clone = true cloned = true end

			g:removeAllMOs(true)

			-- Edit the first add_display entity, or add a dummy if none
			if not g.__edit_d then
				g.add_displays = g.add_displays or {}
				g.add_displays[#g.add_displays+1] = require(g.__CLASSNAME).new{image="invis.png", force_clone=true}
				g.__edit_d = #g.add_displays
			end
			local gd = g.add_displays[g.__edit_d]

			for __, e in ipairs(ee) do
				local gd = gd
				if e.z then
					if g.__edit_d_z and g.__edit_d_z[e.z] and g.add_displays[g.__edit_d_z[e.z]] then
						gd = g.add_displays[g.__edit_d_z[e.z]]
					else
						g.__edit_d_z = g.__edit_d_z or {}
						g.add_displays[#g.add_displays+1] = require(g.__CLASSNAME).new{image="invis.png", force_clone=true, z=e.z}
						g.__edit_d_z[e.z] = #g.add_displays
						gd = g.add_displays[g.__edit_d_z[e.z]]
					end
				end
				if e.copy_base then gd.image = g.image end
				if e.add_mos then
					-- Add all the mos
					gd.add_mos = gd.add_mos or {}
					local mos = gd.add_mos
					for i = 1, #e.add_mos do
						mos[#mos+1] = table.clone(e.add_mos[i])
						mos[#mos].image = mos[#mos].image:format(rng.range(e.min or 1, e.max or 1))
					end
					if e.add_mos_shader then gd.shader = e.add_mos_shader end
					gd._mo = nil
					gd._last_mo = nil
				end
				if e.add_displays then
					g.add_displays = g.add_displays or {}
					for i = 1, #e.add_displays do
						 g.add_displays[#g.add_displays+1] = require(g.__CLASSNAME).new(e.add_displays[i])
						g.add_displays[#g.add_displays].image = g.add_displays[#g.add_displays].image:format(rng.range(e.min or 1, e.max or 1))
					end
				end
				if e.image then g.image = e.image:format(rng.range(e.min or 1, e.max or 1)) end
			end

			level.map(i, j, Map.TERRAIN, g)
			level.map:updateMap(i, j)
			if self.edit_entity_store then self.edit_entity_store[id] = g end
		end
	end end
	self.edits = {}
end

function _M:postProcessLevelTiles(level)
	if not Map.tiles.nicer_tiles then return end

	self.edit_entity_store = {}
	self.saveinstead_store = {}
	self.repo = {}

	for i = 0, level.map.w - 1 do for j = 0, level.map.h - 1 do
		self:handle(level, i, j, false)
	end end

	self:replaceAll(level)

	self.edit_entity_store = nil
	self.saveinstead_store = nil
end

function _M:postProcessLevelTilesOnLoad(level)
	if not Map.tiles.nicer_tiles then return end

	self.edit_entity_store = {}
	self.saveinstead_store = {}
	self.repo = {}

	for i = 0, level.map.w - 1 do for j = 0, level.map.h - 1 do
		self:handle(level, i, j, true)
	end end

	self:replaceAll(level)

	self.edit_entity_store = nil
	self.saveinstead_store = nil
end

function _M:updateAround(level, x, y)
	if not Map.tiles.nicer_tiles then return end

	self.edit_entity_store = nil
	self.saveinstead_store = nil
	self.repo = {}

	for i = x-1, x+1 do for j = y-1, y+1 do
		self:handle(level, i, j, false)
	end end

	self:replaceAll(level)
end

----------------------------------------------------------
-- Load overlays
----------------------------------------------------------
loadfile("/mod/class/NicerTilesOverlays.lua")(_M)
----------------------------------------------------------
----------------------------------------------------------

--- Make walls have a pseudo 3D effect
function _M:niceTileWall3d(level, i, j, g, nt)
	local s = (level.map:checkEntity(i, j, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i, j, Map.TERRAIN, "subtype") or "floor")
	local gn = (level.map:checkEntity(i, j-1, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i, j-1, Map.TERRAIN, "subtype") or "floor")
	local gs = (level.map:checkEntity(i, j+1, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i, j+1, Map.TERRAIN, "subtype") or "floor")
	local gw = (level.map:checkEntity(i-1, j, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i-1, j, Map.TERRAIN, "subtype") or "floor")
	local ge = (level.map:checkEntity(i+1, j, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i+1, j, Map.TERRAIN, "subtype") or "floor")
	local dn = level.map:checkEntity(i, j-1, Map.TERRAIN, "is_door")
	local ds = level.map:checkEntity(i, j+1, Map.TERRAIN, "is_door")

	if gs ~= s and gn ~= s and gw ~= s and ge ~= s then self:replace(i, j, self:getTile(nt.small_pillar))
	elseif gs ~= s and gn ~= s and gw ~= s and ge == s then self:replace(i, j, self:getTile(nt.pillar_4))
	elseif gs ~= s and gn ~= s and gw == s and ge ~= s then self:replace(i, j, self:getTile(nt.pillar_6))
	elseif gs == s and gn ~= s and gw ~= s and ge ~= s then self:replace(i, j, self:getTile(nt.pillar_8))
	elseif gs ~= s and gn == s and gw ~= s and ge ~= s then self:replace(i, j, self:getTile(nt.pillar_2))
	elseif gs ~= s and gn ~= s then self:replace(i, j, self:getTile(nt.north_south))
	elseif gs == s and ds and gn ~= s then self:replace(i, j, self:getTile(nt.north_south))
	elseif gs ~= s and gn == s and dn then self:replace(i, j, self:getTile(nt.north_south))
	elseif gs ~= s then self:replace(i, j, self:getTile(nt.south))
	elseif gs == s and ds then self:replace(i, j, self:getTile(nt.south))
	elseif gn ~= s then self:replace(i, j, self:getTile(nt.north))
	elseif gn == s and dn then self:replace(i, j, self:getTile(nt.north))
	elseif nt.inner then self:replace(i, j, self:getTile(nt.inner))
	end
end

--- Make walls have a more elaborate pseudo 3D effect:
function _M:niceTileWall3dSus(level, i, j, g, nt)
	local s = (level.map:checkEntity(i, j, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i, j, Map.TERRAIN, "subtype") or "floor")
	local gn = (level.map:checkEntity(i, j-1, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i, j-1, Map.TERRAIN, "subtype") or "floor")
	local gs = (level.map:checkEntity(i, j+1, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i, j+1, Map.TERRAIN, "subtype") or "floor")
	local gw = (level.map:checkEntity(i-1, j, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i-1, j, Map.TERRAIN, "subtype") or "floor")
	local ge = (level.map:checkEntity(i+1, j, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i+1, j, Map.TERRAIN, "subtype") or "floor")
	local gse = (level.map:checkEntity(i+1, j+1, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i+1, j+1, Map.TERRAIN, "subtype") or "floor")
	local gsw = (level.map:checkEntity(i-1, j+1, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i-1, j+1, Map.TERRAIN, "subtype") or "floor")
	local gne = (level.map:checkEntity(i+1, j-1, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i+1, j-1, Map.TERRAIN, "subtype") or "floor")
	local gnw = (level.map:checkEntity(i-1, j-1, Map.TERRAIN, "type") or "wall").."/"..(level.map:checkEntity(i-1, j-1, Map.TERRAIN, "subtype") or "floor")
	
	local ws = gs == s		--true if there is a wall to the south
	local wn = gn == s      --true if there is a wall to the north
	local ww = gw == s      --true if there is a wall to the west
	local we = ge == s      --true if there is a wall to the east
	local wse = gse == s    --true if there is a wall to the southeast
	local wsw = gsw == s    --true if there is a wall to the southwest
	local wne = gne == s	--true if there is a wall to the northeast
	local wnw = gnw == s	--true if there is a wall to the northwest

	local fs = not ws       --true if there is a floor to the south
	local fn = not wn       --true if there is a floor to the north
	local fw = not ww       --true if there is a floor to the west
	local fe = not we       --true if there is a floor to the east
	local fse = not wse     --true if there is a floor to the southeast
	local fsw = not wsw     --true if there is a floor to the southwest
	local fne = not wne     --true if there is a floor to the northeast
	local fnw = not wnw     --true if there is a floor to the northwest
	
	local dn = level.map:checkEntity(i, j-1, Map.TERRAIN, "is_door")		--true if there is a door to the north
	local ds = level.map:checkEntity(i, j+1, Map.TERRAIN, "is_door")		--true if there is a door to the south
	local dw = level.map:checkEntity(i-1, j, Map.TERRAIN, "is_door")		--true if there is a door to the west
	local de = level.map:checkEntity(i+1, j, Map.TERRAIN, "is_door")		--true if there is a door to the east
	local dne = level.map:checkEntity(i+1, j-1, Map.TERRAIN, "is_door")		--true if there is a door to the northeast
	local dse = level.map:checkEntity(i+1, j+1, Map.TERRAIN, "is_door")		--true if there is a door to the southeast
	local dnw = level.map:checkEntity(i-1, j-1, Map.TERRAIN, "is_door")		--true if there is a door to the northwest
	local dsw = level.map:checkEntity(i-1, j+1, Map.TERRAIN, "is_door")		--true if there is a door to the southwest
	
	local cornl = ww and fsw
		--cornl for a tile X indicates this configuration: 	#X
		--													.#
	local cornr = we and fse
		--cornr for a tile X indicates this configuration: 	X#
		--													#.

		
	-- And now all the cases. There are a lot :(
	
	if ws and not ds and wn and (ww or dw) and (we or de) then --(inner walls, with walls to the north, south, east, and west)
		if wsw and wse then self:replace(i, j, self:getTile(nt.inner))
		elseif fsw and wse then self:replace(i, j, self:getTile(nt.inner_cornl))
		elseif wsw and fse then self:replace(i, j, self:getTile(nt.inner_cornr))
		elseif fsw and fse then self:replace(i, j, self:getTile(nt.inner_cornl_cornr))
		end
	elseif ws and not ds and wn and fe and fw then --(west-east walls. These have floor the west and east)
		if (wsw or dsw) and (wse or dse) then self:replace(i, j, self:getTile(nt.wewall_sw_se))
		elseif (wsw or dsw) and fse then self:replace(i, j, self:getTile(nt.wewall_sw))
		elseif fsw and (wse or dse) then self:replace(i, j, self:getTile(nt.wewall_se))
		elseif fsw and fse then self:replace(i, j, self:getTile(nt.wewall))
		end
	elseif ws and not ds and wn and we and fw then -- west walls (floor to the west only)
		if (wsw or dsw) and wse then self:replace(i, j, self:getTile(nt.wwall_sw))
		elseif (wsw or dsw) and fse then self:replace(i, j, self:getTile(nt.wwall_sw_cornr))
		elseif fsw and wse then self:replace(i, j, self:getTile(nt.wwall))
		elseif fsw and fse then self:replace(i, j, self:getTile(nt.wwall_cornr))
		end
	elseif ws and not ds and wn and fe and ww then -- east walls (floor to the east only)
		if (wse or dse) and wsw then self:replace(i, j, self:getTile(nt.ewall_se))
		elseif (wse or dse) and fsw then self:replace(i, j, self:getTile(nt.ewall_se_cornl))
		elseif fse and wsw then self:replace(i, j, self:getTile(nt.ewall))
		elseif fse and fsw then self:replace(i, j, self:getTile(nt.ewall_cornl))
		end
	elseif ws and not ds and (fn or dn) then --(north walls... not north-south; those are later)
		-- north walls whose cap bends up at the left side (because there's a wall to the northwest that we want to join up with):
		if ww and wnw and not dnw and we and wne and not dne then
			if cornl and cornr then self:replace(i, j, self:getTile(nt.nwall_cap_lup_rup_cornl_cornr))
			elseif cornl then self:replace(i, j, self:getTile(nt.nwall_cap_lup_rup_cornl))
			elseif cornr then self:replace(i, j, self:getTile(nt.nwall_cap_lup_rup_cornr))
			else self:replace(i, j, self:getTile(nt.nwall_cap_lup_rup))
			end
		elseif ww and wnw and not dnw and we and (fne or dne) then
			if cornl and cornr then self:replace(i, j, self:getTile(nt.nwall_cap_lup_cornl_cornr))
			elseif cornl then self:replace(i, j, self:getTile(nt.nwall_cap_lup_cornl))
			elseif cornr then self:replace(i, j, self:getTile(nt.nwall_cap_lup_cornr))
			else self:replace(i, j, self:getTile(nt.nwall_cap_lup))
			end
		elseif ww and wnw and not dnw and fe and fse then 
			if cornl then self:replace(i, j, self:getTile(nt.nwall_cap_lup_rdn_cornl))
			else self:replace(i, j, self:getTile(nt.nwall_cap_lup_rdn))
			end
		elseif ww and wnw and not dnw and fe and wse then
			if cornl then self:replace(i, j, self:getTile(nt.nwall_cap_lup_rdn_se_cornl))
			else self:replace(i, j, self:getTile(nt.nwall_cap_lup_rdn_se))
			end
			
		-- north walls with a cap that doesn't bend up or down on the left side; there's a floor or door to the northwest, so we don't want to do any curving:
		elseif ww and (fnw or dnw) and we and wne and not dne then
			if cornl and cornr then self:replace(i, j, self:getTile(nt.nwall_cap_rup_cornl_cornr))
			elseif cornl then self:replace(i, j, self:getTile(nt.nwall_cap_rup_cornl))
			elseif cornr then self:replace(i, j, self:getTile(nt.nwall_cap_rup_cornr))
			else self:replace(i, j, self:getTile(nt.nwall_cap_rup))
			end
		elseif ww and (fnw or dnw) and we and (fne or dne) then self:replace(i, j, self:getTile(nt.nwall)) 
			if cornl and cornr then self:replace(i, j, self:getTile(nt.nwall_cornl_cornr))
			elseif cornl then self:replace(i, j, self:getTile(nt.nwall_cornl))
			elseif cornr then self:replace(i, j, self:getTile(nt.nwall_cornr))
			else self:replace(i, j, self:getTile(nt.nwall))
			end
		elseif ww and (fnw or dnw) and fe and fse then 
			if cornl then self:replace(i, j, self:getTile(nt.nwall_cap_rdn_cornl))
			else self:replace(i, j, self:getTile(nt.nwall_cap_rdn))
			end
		elseif ww and (fnw or dnw) and fe and wse then
			if cornl then self:replace(i, j, self:getTile(nt.nwall_cap_rdn_se_cornl))
			else self:replace(i, j, self:getTile(nt.nwall_cap_rdn_se))
			end		
		
		-- north walls whose cap bends down at the left side (because there's a floor to the west):
		elseif fw and we and wne and not dne and fsw then 
			if cornr then self:replace(i, j, self:getTile(nt.nwall_cap_ldn_rup_cornr))
			else self:replace(i, j, self:getTile(nt.nwall_cap_ldn_rup))
			end
		elseif fw and we and wne and not dne and wsw then 
			if cornr then self:replace(i, j, self:getTile(nt.nwall_cap_ldn_rup_sw_cornr))
			else self:replace(i, j, self:getTile(nt.nwall_cap_ldn_rup_sw))
			end
		elseif fw and we and (fne or dne) and fsw then
			if cornr then self:replace(i, j, self:getTile(nt.nwall_cap_ldn_cornr)) 
			else self:replace(i, j, self:getTile(nt.nwall_cap_ldn)) 
			end
		elseif fw and we and (fne or dne) and wsw then
			if cornr then self:replace(i, j, self:getTile(nt.nwall_cap_ldn_sw_cornr)) 
			else self:replace(i, j, self:getTile(nt.nwall_cap_ldn_sw)) 
			end
		
		elseif fw and fe and fsw and fse then self:replace(i, j, self:getTile(nt.nwall_cap_ldn_rdn)) 
		elseif fw and fe and wsw and fse then self:replace(i, j, self:getTile(nt.nwall_cap_ldn_rdn_sw)) 
		elseif fw and fe and fsw and wse then self:replace(i, j, self:getTile(nt.nwall_cap_ldn_rdn_se)) 
		elseif fw and fe and wsw and wse then self:replace(i, j, self:getTile(nt.nwall_cap_ldn_rdn_sw_se)) 
		end
	elseif wn and (fs or ds) then --(south walls... not north-south; those are later):
		if fw and fe then self:replace(i, j, self:getTile(nt.swall_lup_rup)) --Sandstone_21
		elseif fw and we and (fse or dse) then self:replace(i, j, self:getTile(nt.swall_lup)) 
		elseif fw and we and wse then self:replace(i, j, self:getTile(nt.swall_lup_rdn)) 

		elseif ww and (fsw or dsw) and fe then self:replace(i, j, self:getTile(nt.swall_rup)) 
		elseif ww and we and (fsw or dsw) and (fse or dse) then self:replace(i, j, self:getTile(nt.swall)) 
		elseif ww and (fsw or dsw) and we and wse and not dse then self:replace(i, j, self:getTile(nt.swall_rdn)) 
		
		elseif ww and wsw and not dsw and fe then self:replace(i, j, self:getTile(nt.swall_ldn_rup)) 
		elseif ww and wsw and not dsw and we and (fse or dse) then self:replace(i, j, self:getTile(nt.swall_ldn)) 
		elseif ww and wsw and not dsw and we and wse and not dse then self:replace(i, j, self:getTile(nt.swall_ldn_rdn)) 
		end

	elseif (fn or dn) and (fs or ds) then --(north-south walls):
		if fw and fe then self:replace(i, j, self:getTile(nt.nswall_lup_rup)) 
		
		elseif fw and we and (fse or dse) and (fne or dne) then self:replace(i, j, self:getTile(nt.nswall_lup)) 
		elseif fw and we and (fse or dse) and wne and not dne then self:replace(i, j, self:getTile(nt.nswall_lup_cap_rup)) 
		
		elseif fw and we and wse and (fne or dne) then self:replace(i, j, self:getTile(nt.nswall_lup_rdn)) 
		elseif fw and we and wse and wne and not dne then self:replace(i, j, self:getTile(nt.nswall_lup_rdn_cap_rup)) 
	 
	 
		elseif ww and (fsw or dsw) and fe and (fnw or dnw) then self:replace(i, j, self:getTile(nt.nswall_rup)) 
		elseif ww and (fsw or dsw) and fe and wnw and not dnw then self:replace(i, j, self:getTile(nt.nswall_rup_cap_lup)) 
		
		elseif ww and we and (fsw or dsw) and (fse or dse) and (fnw or dnw) and (fne or dne) then self:replace(i, j, self:getTile(nt.nswall)) 
		elseif ww and we and (fsw or dsw) and (fse or dse) and wnw and not dnw and (fne or dne) then self:replace(i, j, self:getTile(nt.nswall_cap_lup)) 
		elseif ww and we and (fsw or dsw) and (fse or dse) and (fnw or dnw) and wne and not dne then self:replace(i, j, self:getTile(nt.nswall_cap_rup)) 
		elseif ww and we and (fsw or dsw) and (fse or dse) and wnw and not dnw and wne and not dne then self:replace(i, j, self:getTile(nt.nswall_cap_lup_rup)) 
		
		elseif ww and (fsw or dsw) and we and wse and not dse and (fnw or dnw) and (fne or dne) then self:replace(i, j, self:getTile(nt.nswall_rdn)) 
		elseif ww and (fsw or dsw) and we and wse and not dse and wnw and not dnw and (fne or dne) then self:replace(i, j, self:getTile(nt.nswall_rdn_cap_lup)) 
		elseif ww and (fsw or dsw) and we and wse and not dse and (fnw or dnw) and wne and not dne then self:replace(i, j, self:getTile(nt.nswall_rdn_cap_rup)) 
		elseif ww and (fsw or dsw) and we and wse and not dse and wnw and not dnw and wne and not dne then self:replace(i, j, self:getTile(nt.nswall_rdn_cap_lup_rup)) 

		
		elseif ww and wsw and not dsw and fe then self:replace(i, j, self:getTile(nt.nswall_ldn_rup)) 
		elseif ww and wsw and not dsw and fe and wnw and not dnw and (fne or dne) then self:replace(i, j, self:getTile(nt.nswall_ldn_rup_cap_lup)) 
		
		elseif ww and wsw and not dsw and we and (fse or dse) and (fnw or dnw) and (fne or dne) then self:replace(i, j, self:getTile(nt.nswall_ldn)) 
		elseif ww and wsw and not dsw and we and (fse or dse) and wnw and not dnw and (fne or dne) then self:replace(i, j, self:getTile(nt.nswall_ldn_cap_lup)) 
		elseif ww and wsw and not dsw and we and (fse or dse) and (fnw or dnw) and wne and not dne then self:replace(i, j, self:getTile(nt.nswall_ldn_cap_rup)) 
		elseif ww and wsw and not dsw and we and (fse or dse) and wnw and not dnw and wne and not dne then self:replace(i, j, self:getTile(nt.nswall_ldn_cap_lup_rup)) 
		
		elseif ww and wsw and not dsw and we and wse and not dse and (fnw or dnw) and (fne or dne) then self:replace(i, j, self:getTile(nt.nswall_ldn_rdn)) 
		elseif ww and wsw and not dsw and we and wse and not dse and wnw and not dnw and (fne or dne) then self:replace(i, j, self:getTile(nt.nswall_ldn_rdn_cap_lup)) 
		elseif ww and wsw and not dsw and we and wse and not dse and (fnw or dnw) and wne and not dne then self:replace(i, j, self:getTile(nt.nswall_ldn_rdn_cap_rup)) 
		elseif ww and wsw and not dsw and we and wse and not dse and wnw and not dnw and wne and not dne then self:replace(i, j, self:getTile(nt.nswall_ldn_rdn_cap_lup_rup)) 
		end

	end

end

--- Make doors have a more elaborate pseudo 3D effect:
function _M:niceTileDoor3dSus(level, i, j, g, nt)
	local gn = level.map:checkEntity(i, j-1, Map.TERRAIN, "type") or "wall"
	local gs = level.map:checkEntity(i, j+1, Map.TERRAIN, "type") or "wall"
	local gw = level.map:checkEntity(i-1, j, Map.TERRAIN, "type") or "wall"
	local ge = level.map:checkEntity(i+1, j, Map.TERRAIN, "type") or "wall"
	local gse = level.map:checkEntity(i+1, j+1, Map.TERRAIN, "type") or "wall"
	local gsw = level.map:checkEntity(i-1, j+1, Map.TERRAIN, "type") or "wall"
	local gne = level.map:checkEntity(i+1, j-1, Map.TERRAIN, "type") or "wall"
	local gnw = level.map:checkEntity(i-1, j-1, Map.TERRAIN, "type") or "wall"

	local ws = gs == "wall"		--true if there is a wall to the south
	local wn = gn == "wall"      --true if there is a wall to the north
	local ww = gw == "wall"      --true if there is a wall to the west
	local we = ge == "wall"      --true if there is a wall to the east
	local wse = gse == "wall"    --true if there is a wall to the southeast
	local wsw = gsw == "wall"    --true if there is a wall to the southwest
	local wne = gne == "wall"	--true if there is a wall to the northeast
	local wnw = gnw == "wall"	--true if there is a wall to the northwest

	local fs = not ws       --true if there is a floor to the south
	local fn = not wn       --true if there is a floor to the north
	local fw = not ww       --true if there is a floor to the west
	local fe = not we       --true if there is a floor to the east
	local fse = not wse     --true if there is a floor to the southeast
	local fsw = not wsw     --true if there is a floor to the southwest
	local fne = not wne     --true if there is a floor to the northeast
	local fnw = not wnw     --true if there is a floor to the northwest
	
	local dn = level.map:checkEntity(i, j-1, Map.TERRAIN, "is_door")
	local ds = level.map:checkEntity(i, j+1, Map.TERRAIN, "is_door")
	local dw = level.map:checkEntity(i-1, j, Map.TERRAIN, "is_door")
	local de = level.map:checkEntity(i+1, j, Map.TERRAIN, "is_door")
	local dse = level.map:checkEntity(i+1, j+1, Map.TERRAIN, "is_door")
	local dsw = level.map:checkEntity(i-1, j+1, Map.TERRAIN, "is_door")

	if ws and wn then 
		if wsw and wse and wnw and wne then self:replace(i, j, self:getTile(nt.vert)) 
		elseif wsw and wse and fnw and wne then self:replace(i, j, self:getTile(nt.vert_cap_lup)) 
		elseif wsw and wse and wnw and fne then self:replace(i, j, self:getTile(nt.vert_cap_rup)) 
		elseif wsw and wse and fnw and fne then self:replace(i, j, self:getTile(nt.vert_cap_lup_rup)) 
		
		elseif fsw and wse and wnw and wne then self:replace(i, j, self:getTile(nt.vert_ldn)) 
		elseif fsw and wse and fnw and wne then self:replace(i, j, self:getTile(nt.vert_ldn_cap_lup)) 
		elseif fsw and wse and wnw and fne then self:replace(i, j, self:getTile(nt.vert_ldn_cap_rup)) 
		elseif fsw and wse and fnw and fne then self:replace(i, j, self:getTile(nt.vert_ldn_cap_lup_rup)) 
		
		elseif wsw and fse and wnw and wne then self:replace(i, j, self:getTile(nt.vert_rdn)) 
		elseif wsw and fse and fnw and wne then self:replace(i, j, self:getTile(nt.vert_rdn_cap_lup)) 
		elseif wsw and fse and wnw and fne then self:replace(i, j, self:getTile(nt.vert_rdn_cap_rup)) 
		elseif wsw and fse and fnw and fne then self:replace(i, j, self:getTile(nt.vert_rdn_cap_lup_rup)) 
		
		elseif fsw and fse and wnw and wne then self:replace(i, j, self:getTile(nt.vert_ldn_rdn)) 
		elseif fsw and fse and fnw and wne then self:replace(i, j, self:getTile(nt.vert_ldn_rdn_cap_lup)) 
		elseif fsw and fse and wnw and fne then self:replace(i, j, self:getTile(nt.vert_ldn_rdn_cap_rup)) 
		elseif fsw and fse and fnw and fne then self:replace(i, j, self:getTile(nt.vert_ldn_rdn_cap_lup_rup)) 
		end
	elseif ww and we then 
		if (fnw or dnw) and (fne or dne) and fsw and fse then self:replace(i, j, self:getTile(nt.horiz))
		elseif (fnw or dnw) and (fne or dne) and wsw and fse then self:replace(i, j, self:getTile(nt.horiz_ldn))
		elseif (fnw or dnw) and (fne or dne) and fsw and wse then self:replace(i, j, self:getTile(nt.horiz_rdn))
		elseif (fnw or dnw) and (fne or dne) and wsw and wse then self:replace(i, j, self:getTile(nt.horiz_ldn_rdn))
		
		elseif wnw and (fne or dne) and fsw and fse then self:replace(i, j, self:getTile(nt.horiz_cap_lup))
		elseif wnw and (fne or dne) and wsw and fse then self:replace(i, j, self:getTile(nt.horiz_ldn_cap_lup))
		elseif wnw and (fne or dne) and fsw and wse then self:replace(i, j, self:getTile(nt.horiz_rdn_cap_lup))
		elseif wnw and (fne or dne) and wsw and wse then self:replace(i, j, self:getTile(nt.horiz_ldn_rdn_cap_lup))
		
		elseif (fnw or dnw) and wne and fsw and fse then self:replace(i, j, self:getTile(nt.horiz_cap_rup))
		elseif (fnw or dnw) and wne and wsw and fse then self:replace(i, j, self:getTile(nt.horiz_ldn_cap_rup))
		elseif (fnw or dnw) and wne and fsw and wse then self:replace(i, j, self:getTile(nt.horiz_rdn_cap_rup))
		elseif (fnw or dnw) and wne and wsw and wse then self:replace(i, j, self:getTile(nt.horiz_ldn_rdn_cap_rup))
		
		elseif wnw and wne and fsw and fse then self:replace(i, j, self:getTile(nt.horiz_cap_lup_rup))
		elseif wnw and wne and wsw and fse then self:replace(i, j, self:getTile(nt.horiz_ldn_cap_lup_rup))
		elseif wnw and wne and fsw and wse then self:replace(i, j, self:getTile(nt.horiz_rdn_cap_lup_rup))
		elseif wnw and wne and wsw and wse then self:replace(i, j, self:getTile(nt.horiz_ldn_rdn_cap_lup_rup))
		end
	elseif nt.default == "north_south" then self:replace(i, j, self:getTile(nt.north_south)) print("niceTileDoor3dUnearth case 3")
	elseif nt.default == "west_east" then self:replace(i, j, self:getTile(nt.west_east)) print("niceTileDoor3dUnearth case 4")
	
	end
end


function _M:niceTileSingleWall(level, i, j, g, nt)
	local type = nt.type
	local kind = nt.use_subtype and "subtype" or "type"
	local g5 = level.map:checkEntity(i, j,   Map.TERRAIN, kind) or type
	local g8 = level.map:checkEntity(i, j-1, Map.TERRAIN, kind) or type
	local g2 = level.map:checkEntity(i, j+1, Map.TERRAIN, kind) or type
	local g4 = level.map:checkEntity(i-1, j, Map.TERRAIN, kind) or type
	local g6 = level.map:checkEntity(i+1, j, Map.TERRAIN, kind) or type

	if     g5 ~= g4 and g5 == g6 and g5 == g8 and g5 == g2 then self:replace(i, j, self:getTile(nt["e_cross"]))
	elseif g5 == g4 and g5 ~= g6 and g5 == g8 and g5 == g2 then self:replace(i, j, self:getTile(nt["w_cross"]))
	elseif g5 == g4 and g5 == g6 and g5 ~= g8 and g5 == g2 then self:replace(i, j, self:getTile(nt["s_cross"]))
	elseif g5 == g4 and g5 == g6 and g5 == g8 and g5 ~= g2 then self:replace(i, j, self:getTile(nt["n_cross"]))

	elseif g5 ~= g4 and g5 == g6 and g5 == g8 and g5 ~= g2 then self:replace(i, j, self:getTile(nt["ne"]))
	elseif g5 == g4 and g5 ~= g6 and g5 == g8 and g5 ~= g2 then self:replace(i, j, self:getTile(nt["nw"]))
	elseif g5 ~= g4 and g5 == g6 and g5 ~= g8 and g5 == g2 then self:replace(i, j, self:getTile(nt["se"]))
	elseif g5 == g4 and g5 ~= g6 and g5 ~= g8 and g5 == g2 then self:replace(i, j, self:getTile(nt["sw"]))

	elseif g5 == g4 and g5 == g6 and g5 == g8 and g5 == g2 then self:replace(i, j, self:getTile(nt["cross"]))

	elseif g5 ~= g4 and g5 ~= g6 and g5 == g8 and g5 == g2 then self:replace(i, j, self:getTile(nt["v_full"]))
	elseif g5 == g4 and g5 == g6 and g5 ~= g8 and g5 ~= g2  then self:replace(i, j, self:getTile(nt["h_full"]))
	end
end

--- Make walls have a pseudo 3D effect & rounded corners
function _M:niceTileRoundwall3d(level, i, j, g, nt)
	local s = level.map:checkEntity(i, j, Map.TERRAIN, "type") or "wall"
	local g8 = level.map:checkEntity(i, j-1, Map.TERRAIN, "type") or "wall"
	local g2 = level.map:checkEntity(i, j+1, Map.TERRAIN, "type") or "wall"
	local g4 = level.map:checkEntity(i-1, j, Map.TERRAIN, "type") or "wall"
	local g6 = level.map:checkEntity(i+1, j, Map.TERRAIN, "type") or "wall"
	local g1 = level.map:checkEntity(i-1, j+1, Map.TERRAIN, "type") or "wall"
	local g3 = level.map:checkEntity(i+1, j+1, Map.TERRAIN, "type") or "wall"
	local g7 = level.map:checkEntity(i-1, j-1, Map.TERRAIN, "type") or "wall"
	local g9 = level.map:checkEntity(i+1, j-1, Map.TERRAIN, "type") or "wall"

	-- Pillar
	if     g2 ~= s and g8 ~= s and g4 ~= s and g6 ~= s then self:replace(i, j, self:getTile(nt.pillar_small))
	elseif g8 ~= s and g4 == s and g6 == s and g7 == s and g9 == s then self:replace(i, j, self:getTile(nt.hole8))
	elseif g2 ~= s and g4 == s and g6 == s and g1 == s and g3 == s then self:replace(i, j, self:getTile(nt.hole2))
	elseif g8 ~= s and g4 ~= s and g6 ~= s then self:replace(i, j, self:getTile(nt.pillar8))
	elseif g2 ~= s and g4 ~= s and g6 ~= s then self:replace(i, j, self:getTile(nt.pillar2))
	elseif g4 ~= s and g8 ~= s and g2 ~= s then self:replace(i, j, self:getTile(nt.pillar4))
	elseif g6 ~= s and g8 ~= s and g2 ~= s then self:replace(i, j, self:getTile(nt.pillar6))
	-- Sides
	elseif g2 ~= s and g6 ~= s and g4 == s and g1 == s then self:replace(i, j, self:getTile(nt.wall19d))
	elseif g2 ~= s and g4 ~= s and g6 == s and g3 == s then self:replace(i, j, self:getTile(nt.wall37d))
	elseif g8 ~= s and g6 ~= s and g4 == s and g7 == s then self:replace(i, j, self:getTile(nt.wall73d))
	elseif g8 ~= s and g4 ~= s and g6 == s and g9 == s then self:replace(i, j, self:getTile(nt.wall91d))
	elseif g8 ~= s and g4 == s and g7 == s then self:replace(i, j, self:getTile(nt.wall7d))
	elseif g8 ~= s and g6 == s and g9 == s then self:replace(i, j, self:getTile(nt.wall9d))
	elseif g2 ~= s and g4 == s and g1 == s then self:replace(i, j, self:getTile(nt.wall1d))
	elseif g2 ~= s and g6 == s and g3 == s then self:replace(i, j, self:getTile(nt.wall3d))
	-- Top
	elseif g2 ~= s and g8 ~= s then self:replace(i, j, self:getTile(nt.wall82))
	elseif g8 ~= s and g4 ~= s then self:replace(i, j, self:getTile(nt.wall7))
	elseif g8 ~= s and g6 ~= s then self:replace(i, j, self:getTile(nt.wall9))
	elseif g8 ~= s then self:replace(i, j, self:getTile(nt.wall8))
	-- Bottom
	elseif g2 ~= s and g4 ~= s then self:replace(i, j, self:getTile(nt.wall1))
	elseif g2 ~= s and g6 ~= s then self:replace(i, j, self:getTile(nt.wall3))
	elseif g2 ~= s then self:replace(i, j, self:getTile(nt.wall2))
	elseif nt.inner then self:replace(i, j, self:getTile(nt.inner))
	end
end

--- Make doors have a pseudo 3D effect
function _M:niceTileDoor3d(level, i, j, g, nt)
	local gn = level.map:checkEntity(i, j-1, Map.TERRAIN, "type") or "wall"
	local gs = level.map:checkEntity(i, j+1, Map.TERRAIN, "type") or "wall"
	local gw = level.map:checkEntity(i-1, j, Map.TERRAIN, "type") or "wall"
	local ge = level.map:checkEntity(i+1, j, Map.TERRAIN, "type") or "wall"
	--print("niceTileDoor3d report:")
	--print(" gn:", tostring(gn))
	--print(" gs:", tostring(gs))
	--print(" gw:", tostring(gw))
	--print(" ge:", tostring(ge))
	if gs == "wall" and gn == "wall" then self:replace(i, j, self:getTile(nt.north_south)) --print(" case 1")
	elseif gw == "wall" and ge == "wall" then self:replace(i, j, self:getTile(nt.west_east)) --print(" case 2")
	elseif nt.default == "north_south" then self:replace(i, j, self:getTile(nt.north_south)) --print(" case 3")
	elseif nt.default == "west_east" then self:replace(i, j, self:getTile(nt.west_east)) --print(" case 4")
	
	end
end

--- Randomize tiles
function _M:niceTileReplace(level, i, j, g, nt)
	self:replace(i, j, self:getTile(nt.base))
end

function _M:niceTileReplaceVisible(level, i, j, g, nt)
	local g8 = not level.map:checkEntity(i, j-1, Map.TERRAIN, "block_sight")
	local g2 = not level.map:checkEntity(i, j+1, Map.TERRAIN, "block_sight")
	local g4 = not level.map:checkEntity(i-1, j, Map.TERRAIN, "block_sight")
	local g6 = not level.map:checkEntity(i+1, j, Map.TERRAIN, "block_sight")
	local g7 = not level.map:checkEntity(i-1, j-1, Map.TERRAIN, "block_sight")
	local g9 = not level.map:checkEntity(i+1, j-1, Map.TERRAIN, "block_sight")
	local g1 = not level.map:checkEntity(i-1, j+1, Map.TERRAIN, "block_sight")
	local g3 = not level.map:checkEntity(i+1, j+1, Map.TERRAIN, "block_sight")

	if g1 or g2 or g3 or g4 or g6 or g7 or g8 or g9 then
		self:replace(i, j, self:getTile(nt.base, 2))
	else
		self:replace(i, j, self:getTile(nt.base, 1))
	end
end


--- Make water have nice transition to other stuff
function _M:niceTileGenericBorders(level, i, j, g, nt, type, allow, outside)
	local g8 = level.map:checkEntity(i, j-1, Map.TERRAIN, "subtype") or type
	local g2 = level.map:checkEntity(i, j+1, Map.TERRAIN, "subtype") or type
	local g4 = level.map:checkEntity(i-1, j, Map.TERRAIN, "subtype") or type
	local g6 = level.map:checkEntity(i+1, j, Map.TERRAIN, "subtype") or type
	local g7 = level.map:checkEntity(i-1, j-1, Map.TERRAIN, "subtype") or type
	local g9 = level.map:checkEntity(i+1, j-1, Map.TERRAIN, "subtype") or type
	local g1 = level.map:checkEntity(i-1, j+1, Map.TERRAIN, "subtype") or type
	local g3 = level.map:checkEntity(i+1, j+1, Map.TERRAIN, "subtype") or type

	if outside then
		if not level.map:isBound(i, j-1) then g8 = outside end
		if not level.map:isBound(i, j+1) then g2 = outside end
		if not level.map:isBound(i-1, j) then g4 = outside end
		if not level.map:isBound(i+1, j) then g6 = outside end
		if not level.map:isBound(i-1, j-1) then g7 = outside end
		if not level.map:isBound(i+1, j-1) then g9 = outside end
		if not level.map:isBound(i-1, j+1) then g1 = outside end
		if not level.map:isBound(i+1, j+1) then g3 = outside end
	end

	-- Sides
	if     g4==type and g6==type and allow[g8] then self:replace(i, j, self:getTile(nt[g8.."8"]))
	elseif g4==type and g6==type and allow[g2] then self:replace(i, j, self:getTile(nt[g2.."2"]))
	elseif g8==type and g2==type and allow[g4] then self:replace(i, j, self:getTile(nt[g4.."4"]))
	elseif g8==type and g2==type and allow[g6] then self:replace(i, j, self:getTile(nt[g6.."6"]))
	-- Corners
	elseif allow[g4] and allow[g7] and allow[g8] then self:replace(i, j, self:getTile(nt[g7.."7"]))
	elseif allow[g4] and allow[g1] and allow[g2] then self:replace(i, j, self:getTile(nt[g1.."1"]))
	elseif allow[g2] and allow[g3] and allow[g6] then self:replace(i, j, self:getTile(nt[g3.."3"]))
	elseif allow[g6] and allow[g9] and allow[g8] then self:replace(i, j, self:getTile(nt[g9.."9"]))
	-- Inner corners
	elseif g4==type and allow[g7] and g8==type then self:replace(i, j, self:getTile(nt["inner_"..g7.."3"]))
	elseif g4==type and allow[g1] and g2==type then self:replace(i, j, self:getTile(nt["inner_"..g1.."9"]))
	elseif g2==type and allow[g3] and g6==type then self:replace(i, j, self:getTile(nt["inner_"..g3.."7"]))
	elseif g6==type and allow[g9] and g8==type then self:replace(i, j, self:getTile(nt["inner_"..g9.."1"]))
	-- Full
	elseif (g1==type or not allow[g1]) and (g2==type or not allow[g2]) and (g3==type or not allow[g3]) and (g4==type or not allow[g4]) and (g6==type or not allow[g6]) and (g7==type or not allow[g7]) and (g8==type or not allow[g8]) and (g9==type or not allow[g9]) then self:replace(i, j, self:getTile(nt[type]))
	end
end

function _M:niceTileWater(level, i, j, g, nt)
	self:niceTileGenericBorders(level, i, j, g, nt, "water", {grass=true, sand=true})
end

function _M:niceTileGrassSand(level, i, j, g, nt)
	self:niceTileGenericBorders(level, i, j, g, nt, "sand", {grass=true})
end

function _M:niceTileOuterSpace(level, i, j, g, nt)
	self:niceTileGenericBorders(level, i, j, g, nt, "rocks", {void=true}, "void")
end

local defs = {
grass = { method="borders", type="grass", forbid={lava=true, rock=true, dark_grass=true},
	default8={add_mos={{image="terrain/grass/grass_2_%02d.png", display_y=-1}}, min=1, max=2},
	default2={add_mos={{image="terrain/grass/grass_8_%02d.png", display_y=1}}, min=1, max=2},
	default4={add_mos={{image="terrain/grass/grass_6_%02d.png", display_x=-1}}, min=1, max=2},
	default6={add_mos={{image="terrain/grass/grass_4_%02d.png", display_x=1}}, min=1, max=2},

	default1={add_mos={{image="terrain/grass/grass_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	default3={add_mos={{image="terrain/grass/grass_7_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	default7={add_mos={{image="terrain/grass/grass_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	default9={add_mos={{image="terrain/grass/grass_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},

	default1i={add_mos={{image="terrain/grass/grass_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3i={add_mos={{image="terrain/grass/grass_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7i={add_mos={{image="terrain/grass/grass_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=2},
	default9i={add_mos={{image="terrain/grass/grass_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=2},

	water8={add_mos={{image="terrain/grass/grass_2_%02d.png", display_y=-1}}, min=1, max=1},
	water2={add_mos={{image="terrain/grass/grass_8_%02d.png", display_y=1}}, min=1, max=1},
	water4={add_mos={{image="terrain/grass/grass_6_%02d.png", display_x=-1}}, min=1, max=1},
	water6={add_mos={{image="terrain/grass/grass_4_%02d.png", display_x=1}}, min=1, max=1},

	water1={add_mos={{image="terrain/grass/grass_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	water3={add_mos={{image="terrain/grass/grass_7_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	water7={add_mos={{image="terrain/grass/grass_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	water9={add_mos={{image="terrain/grass/grass_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},

	water1i={add_mos={{image="terrain/grass/grass_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	water3i={add_mos={{image="terrain/grass/grass_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	water7i={add_mos={{image="terrain/grass/grass_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	water9i={add_mos={{image="terrain/grass/grass_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},
},
autumn_grass = { method="borders", type="autumn_grass", forbid={grass=true, lava=true, rock=true},
	default8={add_mos={{image="terrain/grass/autumn_grass_2_%02d.png", display_y=-1}}, min=1, max=2},
	default2={add_mos={{image="terrain/grass/autumn_grass_8_%02d.png", display_y=1}}, min=1, max=2},
	default4={add_mos={{image="terrain/grass/autumn_grass_6_%02d.png", display_x=-1}}, min=1, max=2},
	default6={add_mos={{image="terrain/grass/autumn_grass_4_%02d.png", display_x=1}}, min=1, max=2},

	default1={add_mos={{image="terrain/grass/autumn_grass_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	default3={add_mos={{image="terrain/grass/autumn_grass_7_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	default7={add_mos={{image="terrain/grass/autumn_grass_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	default9={add_mos={{image="terrain/grass/autumn_grass_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},

	default1i={add_mos={{image="terrain/grass/autumn_grass_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3i={add_mos={{image="terrain/grass/autumn_grass_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7i={add_mos={{image="terrain/grass/autumn_grass_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=2},
	default9i={add_mos={{image="terrain/grass/autumn_grass_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=2},

	water8={add_mos={{image="terrain/grass/autumn_grass_2_%02d.png", display_y=-1}}, min=1, max=1},
	water2={add_mos={{image="terrain/grass/autumn_grass_8_%02d.png", display_y=1}}, min=1, max=1},
	water4={add_mos={{image="terrain/grass/autumn_grass_6_%02d.png", display_x=-1}}, min=1, max=1},
	water6={add_mos={{image="terrain/grass/autumn_grass_4_%02d.png", display_x=1}}, min=1, max=1},

	water1={add_mos={{image="terrain/grass/autumn_grass_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	water3={add_mos={{image="terrain/grass/autumn_grass_7_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	water7={add_mos={{image="terrain/grass/autumn_grass_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	water9={add_mos={{image="terrain/grass/autumn_grass_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},

	water1i={add_mos={{image="terrain/grass/autumn_grass_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	water3i={add_mos={{image="terrain/grass/autumn_grass_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	water7i={add_mos={{image="terrain/grass/autumn_grass_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	water9i={add_mos={{image="terrain/grass/autumn_grass_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},
},
snowy_grass = { method="borders", type="snowy_grass", forbid={grass=true, lava=true, rock=true},
	default8={add_mos={{image="terrain/grass/snowy_grass_2_%02d.png", display_y=-1}}, min=1, max=2},
	default2={add_mos={{image="terrain/grass/snowy_grass_8_%02d.png", display_y=1}}, min=1, max=2},
	default4={add_mos={{image="terrain/grass/snowy_grass_6_%02d.png", display_x=-1}}, min=1, max=2},
	default6={add_mos={{image="terrain/grass/snowy_grass_4_%02d.png", display_x=1}}, min=1, max=2},

	default1={add_mos={{image="terrain/grass/snowy_grass_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	default3={add_mos={{image="terrain/grass/snowy_grass_7_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	default7={add_mos={{image="terrain/grass/snowy_grass_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	default9={add_mos={{image="terrain/grass/snowy_grass_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},

	default1i={add_mos={{image="terrain/grass/snowy_grass_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3i={add_mos={{image="terrain/grass/snowy_grass_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7i={add_mos={{image="terrain/grass/snowy_grass_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=2},
	default9i={add_mos={{image="terrain/grass/snowy_grass_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=2},

	water8={add_mos={{image="terrain/grass/snowy_grass_2_%02d.png", display_y=-1}}, min=1, max=1},
	water2={add_mos={{image="terrain/grass/snowy_grass_8_%02d.png", display_y=1}}, min=1, max=1},
	water4={add_mos={{image="terrain/grass/snowy_grass_6_%02d.png", display_x=-1}}, min=1, max=1},
	water6={add_mos={{image="terrain/grass/snowy_grass_4_%02d.png", display_x=1}}, min=1, max=1},

	water1={add_mos={{image="terrain/grass/snowy_grass_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	water3={add_mos={{image="terrain/grass/snowy_grass_7_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	water7={add_mos={{image="terrain/grass/snowy_grass_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	water9={add_mos={{image="terrain/grass/snowy_grass_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},

	water1i={add_mos={{image="terrain/grass/snowy_grass_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	water3i={add_mos={{image="terrain/grass/snowy_grass_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	water7i={add_mos={{image="terrain/grass/snowy_grass_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	water9i={add_mos={{image="terrain/grass/snowy_grass_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},
},
dark_grass = { method="borders", type="dark_grass", forbid={grass=true, lava=true, rock=true},
	default8={add_mos={{image="terrain/grass/dark_grass_2_%02d.png", display_y=-1}}, min=1, max=2},
	default2={add_mos={{image="terrain/grass/dark_grass_8_%02d.png", display_y=1}}, min=1, max=2},
	default4={add_mos={{image="terrain/grass/dark_grass_6_%02d.png", display_x=-1}}, min=1, max=2},
	default6={add_mos={{image="terrain/grass/dark_grass_4_%02d.png", display_x=1}}, min=1, max=2},

	default1={add_mos={{image="terrain/grass/dark_grass_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	default3={add_mos={{image="terrain/grass/dark_grass_7_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	default7={add_mos={{image="terrain/grass/dark_grass_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	default9={add_mos={{image="terrain/grass/dark_grass_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},

	default1i={add_mos={{image="terrain/grass/dark_grass_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3i={add_mos={{image="terrain/grass/dark_grass_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7i={add_mos={{image="terrain/grass/dark_grass_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=2},
	default9i={add_mos={{image="terrain/grass/dark_grass_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=2},

	water8={add_mos={{image="terrain/grass/dark_grass_2_%02d.png", display_y=-1}}, min=1, max=1},
	water2={add_mos={{image="terrain/grass/dark_grass_8_%02d.png", display_y=1}}, min=1, max=1},
	water4={add_mos={{image="terrain/grass/dark_grass_6_%02d.png", display_x=-1}}, min=1, max=1},
	water6={add_mos={{image="terrain/grass/dark_grass_4_%02d.png", display_x=1}}, min=1, max=1},

	water1={add_mos={{image="terrain/grass/dark_grass_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	water3={add_mos={{image="terrain/grass/dark_grass_7_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	water7={add_mos={{image="terrain/grass/dark_grass_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	water9={add_mos={{image="terrain/grass/dark_grass_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},

	water1i={add_mos={{image="terrain/grass/dark_grass_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	water3i={add_mos={{image="terrain/grass/dark_grass_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	water7i={add_mos={{image="terrain/grass/dark_grass_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	water9i={add_mos={{image="terrain/grass/dark_grass_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},
},
jungle_grass = { method="borders", type="jungle_grass", forbid={lava=true, rock=true, grass=true},
	default8={add_mos={{image="terrain/jungle/jungle_grass_2_%02d.png", display_y=-1}}, min=1, max=5},
	default2={add_mos={{image="terrain/jungle/jungle_grass_8_%02d.png", display_y=1}}, min=1, max=5},
	default4={add_mos={{image="terrain/jungle/jungle_grass_6_%02d.png", display_x=-1}}, min=1, max=5},
	default6={add_mos={{image="terrain/jungle/jungle_grass_4_%02d.png", display_x=1}}, min=1, max=4},

	default1={add_mos={{image="terrain/jungle/jungle_grass_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=3},
	default3={add_mos={{image="terrain/jungle/jungle_grass_7_%02d.png", display_x=1, display_y=1}}, min=1, max=3},
	default7={add_mos={{image="terrain/jungle/jungle_grass_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=3},
	default9={add_mos={{image="terrain/jungle/jungle_grass_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=3},

	default1i={add_mos={{image="terrain/jungle/jungle_grass_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=3},
	default3i={add_mos={{image="terrain/jungle/jungle_grass_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=3},
	default7i={add_mos={{image="terrain/jungle/jungle_grass_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=3},
	default9i={add_mos={{image="terrain/jungle/jungle_grass_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=3},
},
gloomy_creep = { method="borders", type="gloomy_creep", forbid={lava=true, rock=true, grass=true},
	default8={add_mos={{image="terrain/mushrooms/creep_gloomy_mushrooms_2_%02d.png", display_y=-1}}, min=1, max=2},
	default2={add_mos={{image="terrain/mushrooms/creep_gloomy_mushrooms_8_%02d.png", display_y=1}}, min=1, max=2},
	default4={add_mos={{image="terrain/mushrooms/creep_gloomy_mushrooms_6_%02d.png", display_x=-1}}, min=1, max=2},
	default6={add_mos={{image="terrain/mushrooms/creep_gloomy_mushrooms_4_%02d.png", display_x=1}}, min=1, max=2},

	-- default1={add_mos={{image="terrain/mushrooms/creep_gloomy_mushrooms_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	-- default3={add_mos={{image="terrain/mushrooms/creep_gloomy_mushrooms_7_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	-- default7={add_mos={{image="terrain/mushrooms/creep_gloomy_mushrooms_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	-- default9={add_mos={{image="terrain/mushrooms/creep_gloomy_mushrooms_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},

	default1i={add_mos={{image="terrain/mushrooms/creep_gloomy_mushrooms_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3i={add_mos={{image="terrain/mushrooms/creep_gloomy_mushrooms_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7i={add_mos={{image="terrain/mushrooms/creep_gloomy_mushrooms_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=2},
	default9i={add_mos={{image="terrain/mushrooms/creep_gloomy_mushrooms_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=2},
},
dreamy_creep = { method="borders", type="dreamy_creep", forbid={lava=true, rock=true, grass=true},
	default8={add_mos={{image="terrain/mushrooms/creep_dreamy_mushrooms_2_%02d.png", display_y=-1}}, min=1, max=2},
	default2={add_mos={{image="terrain/mushrooms/creep_dreamy_mushrooms_8_%02d.png", display_y=1}}, min=1, max=2},
	default4={add_mos={{image="terrain/mushrooms/creep_dreamy_mushrooms_6_%02d.png", display_x=-1}}, min=1, max=2},
	default6={add_mos={{image="terrain/mushrooms/creep_dreamy_mushrooms_4_%02d.png", display_x=1}}, min=1, max=2},

	-- default1={add_mos={{image="terrain/mushrooms/creep_dreamy_mushrooms_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	-- default3={add_mos={{image="terrain/mushrooms/creep_dreamy_mushrooms_7_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	-- default7={add_mos={{image="terrain/mushrooms/creep_dreamy_mushrooms_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	-- default9={add_mos={{image="terrain/mushrooms/creep_dreamy_mushrooms_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},

	default1i={add_mos={{image="terrain/mushrooms/creep_dreamy_mushrooms_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3i={add_mos={{image="terrain/mushrooms/creep_dreamy_mushrooms_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7i={add_mos={{image="terrain/mushrooms/creep_dreamy_mushrooms_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=2},
	default9i={add_mos={{image="terrain/mushrooms/creep_dreamy_mushrooms_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=2},
},
slimy_creep = { method="borders", type="slimy_creep", forbid={lava=true, rock=true, grass=true},
	default8={add_mos={{image="terrain/mushrooms/creep_slimy_mushrooms_2_%02d.png", display_y=-1}}, min=1, max=1},
	default2={add_mos={{image="terrain/mushrooms/creep_slimy_mushrooms_8_%02d.png", display_y=1}}, min=1, max=1},
	default4={add_mos={{image="terrain/mushrooms/creep_slimy_mushrooms_6_%02d.png", display_x=-1}}, min=1, max=1},
	default6={add_mos={{image="terrain/mushrooms/creep_slimy_mushrooms_4_%02d.png", display_x=1}}, min=1, max=1},

	-- default1={add_mos={{image="terrain/mushrooms/creep_slimy_mushrooms_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	-- default3={add_mos={{image="terrain/mushrooms/creep_slimy_mushrooms_7_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	-- default7={add_mos={{image="terrain/mushrooms/creep_slimy_mushrooms_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	-- default9={add_mos={{image="terrain/mushrooms/creep_slimy_mushrooms_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},

	default1i={add_mos={{image="terrain/mushrooms/creep_slimy_mushrooms_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	default3i={add_mos={{image="terrain/mushrooms/creep_slimy_mushrooms_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	default7i={add_mos={{image="terrain/mushrooms/creep_slimy_mushrooms_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	default9i={add_mos={{image="terrain/mushrooms/creep_slimy_mushrooms_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},
},
sand = { method="borders", type="sand", forbid={grass=true, jungle_grass=true, lava=true,},
	default8={add_mos={{image="terrain/sand/sand_2_%02d.png", display_y=-1}}, min=1, max=5},
	default2={add_mos={{image="terrain/sand/sand_8_%02d.png", display_y=1}}, min=1, max=5},
	default4={add_mos={{image="terrain/sand/sand_6_%02d.png", display_x=-1}}, min=1, max=5},
	default6={add_mos={{image="terrain/sand/sand_4_%02d.png", display_x=1}}, min=1, max=4},

	default1={add_mos={{image="terrain/sand/sand_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=3},
	default3={add_mos={{image="terrain/sand/sand_7_%02d.png", display_x=1, display_y=1}}, min=1, max=3},
	default7={add_mos={{image="terrain/sand/sand_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=3},
	default9={add_mos={{image="terrain/sand/sand_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=3},

	default1i={add_mos={{image="terrain/sand/sand_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=3},
	default3i={add_mos={{image="terrain/sand/sand_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=3},
	default7i={add_mos={{image="terrain/sand/sand_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=3},
	default9i={add_mos={{image="terrain/sand/sand_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=3},
},
ice = { method="borders", type="ice", forbid={grass=true, jungle_grass=true, sand=true, lava=true},
	default8={add_mos={{image="terrain/ice/frozen_ground_2_%02d.png", display_y=-1}}, min=1, max=4},
	default2={add_mos={{image="terrain/ice/frozen_ground_8_%02d.png", display_y=1}}, min=1, max=3},
	default4={add_mos={{image="terrain/ice/frozen_ground_6_%02d.png", display_x=-1}}, min=1, max=4},
	default6={add_mos={{image="terrain/ice/frozen_ground_4_%02d.png", display_x=1}}, min=1, max=4},

	default1={add_mos={{image="terrain/ice/frozen_ground_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3={add_mos={{image="terrain/ice/frozen_ground_7_%02d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7={add_mos={{image="terrain/ice/frozen_ground_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=2},
	default9={add_mos={{image="terrain/ice/frozen_ground_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=2},

	default1i={add_mos={{image="terrain/ice/frozen_ground_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3i={add_mos={{image="terrain/ice/frozen_ground_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7i={add_mos={{image="terrain/ice/frozen_ground_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=2},
	default9i={add_mos={{image="terrain/ice/frozen_ground_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=2},
},
blackcracks = { method="borders", type="ice", forbid={grass=true, jungle_grass=true, sand=true, lava=true},
	default8={add_mos={{image="terrain/cracks/ground_8_%02d.png", display_y=-1}}, min=1, max=3},
	default2={add_mos={{image="terrain/cracks/ground_2_%02d.png", display_y=1}}, min=1, max=4},
	default4={add_mos={{image="terrain/cracks/ground_4_%02d.png", display_x=-1}}, min=1, max=4},
	default6={add_mos={{image="terrain/cracks/ground_6_%02d.png", display_x=1}}, min=1, max=4},

	default1={add_mos={{image="terrain/cracks/ground_inner_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3={add_mos={{image="terrain/cracks/ground_inner_7_%02d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7={add_mos={{image="terrain/cracks/ground_inner_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=2},
	default9={add_mos={{image="terrain/cracks/ground_inner_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=2},

	default1i={add_mos={{image="terrain/cracks/ground_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3i={add_mos={{image="terrain/cracks/ground_3_%02d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7i={add_mos={{image="terrain/cracks/ground_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=2},
	default9i={add_mos={{image="terrain/cracks/ground_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=2},
},
lava = { method="borders", type="lava", forbid={},
	default8={add_mos={{image="terrain/lava/lava_floor_2_%02d.png", display_y=-1}}, min=1, max=8},
	default2={add_mos={{image="terrain/lava/lava_floor_8_%02d.png", display_y=1}}, min=1, max=8},
	default4={add_mos={{image="terrain/lava/lava_floor_6_%02d.png", display_x=-1}}, min=1, max=8},
	default6={add_mos={{image="terrain/lava/lava_floor_4_%02d.png", display_x=1}}, min=1, max=8},

	default1={add_mos={{image="terrain/lava/lava_floor_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=4},
	default3={add_mos={{image="terrain/lava/lava_floor_7_%02d.png", display_x=1, display_y=1}}, min=1, max=4},
	default7={add_mos={{image="terrain/lava/lava_floor_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=4},
	default9={add_mos={{image="terrain/lava/lava_floor_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=4},

	default1i={add_mos={{image="terrain/lava/lava_floor_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=4},
	default3i={add_mos={{image="terrain/lava/lava_floor_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=4},
	default7i={add_mos={{image="terrain/lava/lava_floor_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=4},
	default9i={add_mos={{image="terrain/lava/lava_floor_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=4},
},
molten_lava = { method="borders", type="molten_lava", forbid={grass=true, jungle_grass=true, sand=true, lava=true, ice=true},
	default8={add_mos_shader="lava", add_mos={{image="terrain/lava/molten_lava_2_%02d.png", display_y=-1}}, min=1, max=2},
	default2={add_mos_shader="lava", add_mos={{image="terrain/lava/molten_lava_8_%02d.png", display_y=1}}, min=1, max=2},
	default4={add_mos_shader="lava", add_mos={{image="terrain/lava/molten_lava_6_%02d.png", display_x=-1}}, min=1, max=2},
	default6={add_mos_shader="lava", add_mos={{image="terrain/lava/molten_lava_4_%02d.png", display_x=1}}, min=1, max=2},

	default1={add_mos_shader="lava", add_mos={{image="terrain/lava/molten_lava_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3={add_mos_shader="lava", add_mos={{image="terrain/lava/molten_lava_7_%02d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7={add_mos_shader="lava", add_mos={{image="terrain/lava/molten_lava_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=3},
	default9={add_mos_shader="lava", add_mos={{image="terrain/lava/molten_lava_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=2},

	default1i={add_mos_shader="lava", add_mos={{image="terrain/lava/molten_lava_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3i={add_mos_shader="lava", add_mos={{image="terrain/lava/molten_lava_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7i={add_mos_shader="lava", add_mos={{image="terrain/lava/molten_lava_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=2},
	default9i={add_mos_shader="lava", add_mos={{image="terrain/lava/molten_lava_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=2},
},
mountain = { method="borders", type="mountain", forbid={}, use_type=true,
	default8={z=3, copy_base=true, add_displays={{image="terrain/mountain8.png", display_y=-1, z=16}}, min=1, max=1},
	default2={z=3, copy_base=true, add_mos={{image="terrain/mountain2.png", display_y=1}}, min=1, max=1},
	default4={z=3, copy_base=true, add_mos={{image="terrain/mountain4.png", display_x=-1}}, min=1, max=1},
	default6={z=3, copy_base=true, add_mos={{image="terrain/mountain6.png", display_x=1}}, min=1, max=1},

	default1={z=3, copy_base=true, add_mos={{image="terrain/mountain9i.png", display_x=-1, display_y=1}}, min=1, max=1},
	default3={z=3, copy_base=true, add_mos={{image="terrain/mountain7i.png", display_x=1, display_y=1}}, min=1, max=1},
	default7={z=3, copy_base=true, add_mos={{image="terrain/mountain3i.png", display_x=-1, display_y=-1}}, min=1, max=1},
	default9={z=3, copy_base=true, add_mos={{image="terrain/mountain1i.png", display_x=1, display_y=-1}}, min=1, max=1},

	default1i={z=3, copy_base=true, add_mos={{image="terrain/mountain1.png", display_x=-1, display_y=1}}, min=1, max=1},
	default3i={z=3, copy_base=true, add_mos={{image="terrain/mountain3.png", display_x=1, display_y=1}}, min=1, max=1},
	default7i={z=3, copy_base=true, add_displays={{image="terrain/mountain7.png", display_x=-1, display_y=-1, z=17}}, min=1, max=1},
	default9i={z=3, copy_base=true, add_displays={{image="terrain/mountain9.png", display_x=1, display_y=-1, z=18}}, min=1, max=1},
},
gold_mountain = { method="borders", type="gold_mountain", forbid={}, use_type=true,
	default8={z=3, copy_base=true, add_displays={{image="terrain/golden_mountain8.png", display_y=-1, z=16}}, min=1, max=1},
	default2={z=3, copy_base=true, add_mos={{image="terrain/golden_mountain2.png", display_y=1}}, min=1, max=1},
	default4={z=3, copy_base=true, add_mos={{image="terrain/golden_mountain4.png", display_x=-1}}, min=1, max=1},
	default6={z=3, copy_base=true, add_mos={{image="terrain/golden_mountain6.png", display_x=1}}, min=1, max=1},

	default1={z=3, copy_base=true, add_mos={{image="terrain/golden_mountain9i.png", display_x=-1, display_y=1}}, min=1, max=1},
	default3={z=3, copy_base=true, add_mos={{image="terrain/golden_mountain7i.png", display_x=1, display_y=1}}, min=1, max=1},
	default7={z=3, copy_base=true, add_mos={{image="terrain/golden_mountain3i.png", display_x=-1, display_y=-1}}, min=1, max=1},
	default9={z=3, copy_base=true, add_mos={{image="terrain/golden_mountain1i.png", display_x=1, display_y=-1}}, min=1, max=1},

	default1i={z=3, copy_base=true, add_mos={{image="terrain/golden_mountain1.png", display_x=-1, display_y=1}}, min=1, max=1},
	default3i={z=3, copy_base=true, add_mos={{image="terrain/golden_mountain3.png", display_x=1, display_y=1}}, min=1, max=1},
	default7i={z=3, copy_base=true, add_displays={{image="terrain/golden_mountain7.png", display_x=-1, display_y=-1, z=17}}, min=1, max=1},
	default9i={z=3, copy_base=true, add_displays={{image="terrain/golden_mountain9.png", display_x=1, display_y=-1, z=18}}, min=1, max=1},
},
lava_mountain = { method="borders", type="lava_mountain", forbid={}, use_type=true,
	default8={z=3, copy_base=true, add_displays={{image="terrain/lava/lava_mountain8.png", display_y=-1, z=16}}, min=1, max=1},
	default2={z=3, copy_base=true, add_mos={{image="terrain/lava/lava_mountain2_%d.png", display_y=1}}, min=1, max=2},
	default4={z=3, copy_base=true, add_mos={{image="terrain/lava/lava_mountain4_%d.png", display_x=-1}}, min=1, max=2},
	default6={z=3, copy_base=true, add_mos={{image="terrain/lava/lava_mountain6.png", display_x=1}}, min=1, max=1},

	default1={z=3, copy_base=true, add_mos={{image="terrain/lava/lava_mountain9i%d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3={z=3, copy_base=true, add_mos={{image="terrain/lava/lava_mountain7i%d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7={z=3, copy_base=true, add_mos={{image="terrain/lava/lava_mountain3i%d.png", display_x=-1, display_y=-1}}, min=1, max=2},
	default9={z=3, copy_base=true, add_mos={{image="terrain/lava/lava_mountain1i%d.png", display_x=1, display_y=-1}}, min=1, max=2},

	default1i={z=3, copy_base=true, add_mos={{image="terrain/lava/lava_mountain1.png", display_x=-1, display_y=1}}, min=1, max=1},
	default3i={z=3, copy_base=true, add_mos={{image="terrain/lava/lava_mountain3.png", display_x=1, display_y=1}}, min=1, max=1},
	default7i={z=3, copy_base=true, add_displays={{image="terrain/lava/lava_mountain7.png", display_x=-1, display_y=-1, z=17}}, min=1, max=1},
	default9i={z=3, copy_base=true, add_displays={{image="terrain/lava/lava_mountain9.png", display_x=1, display_y=-1, z=18}}, min=1, max=1},
},
slime_wall = { method="borders", type="slime_wall", forbid={}, use_type=true,
	default8={add_displays={{image="terrain/slime/slime_wall_V2_top_01.png", display_y=-1, z=18}}, min=1, max=1},
	default2={image="terrain/slime/slime_wall_V2_8_01.png", min=1, max=2, add_displays={{image="terrain/slime/floor_wall_slime_%02d.png", display_y=1}}},
	default4={add_mos={{image="terrain/slime/slime_edge_vertical_left_01.png", display_x=-0.03125}}, min=1, max=1},
	default6={add_mos={{image="terrain/slime/slime_edge_vertical_right_01.png", display_x=0.03125}}, min=1, max=1},

	default6i={add_mos={{image="terrain/slime/slime_corner_topleft_going_right_01.png", display_y=-1, display_x=0.03125}, {image="terrain/slime/slime_corner_bottomleft_going_right_01.png", display_x=0.03125}}, min=1, max=1},
	default4i={add_mos={{image="terrain/slime/slime_corner_topright_going_left_01.png", display_y=-1, display_x=-0.03125}, {image="terrain/slime/slime_corner_bottomright_going_left_01.png", display_x=-0.03125}}, min=1, max=1},

	default3={add_mos={{image="terrain/slime/slime_corner_topleft_going_right_01.png", display_y=-1, display_x=0.03125}, {image="terrain/slime/slime_edge_vertical_right_01.png", display_x=0.03125}}, min=1, max=1},
	default1={add_mos={{image="terrain/slime/slime_corner_topright_going_left_01.png", display_y=-1, display_x=-0.03125}, {image="terrain/slime/slime_edge_vertical_left_01.png", display_x=-0.03125}}, min=1, max=1},
	default9={add_mos={{image="terrain/slime/slime_corner_bottomleft_going_right_01.png", display_x=0.03125}}, min=1, max=1},
	default7={add_mos={{image="terrain/slime/slime_corner_bottomright_going_left_01.png", display_x=-0.03125}}, min=1, max=1},

	default7i={add_mos={{image="terrain/slime/slime_edge_upper_left_01.png", display_y=-1, display_x=-0.03125}}, min=1, max=1},
	default9i={add_mos={{image="terrain/slime/slime_edge_upper_right_01.png", display_y=-1, display_x=0.03125}}, min=1, max=1},
},
slime_wall_ochre = { method="borders", type="slime_wall", forbid={}, use_type=true,
	default8={add_displays={{image="terrain/slime/ochre/slime_wall_V2_top_01.png", display_y=-1, z=18}}, min=1, max=1},
	default2={image="terrain/slime/ochre/slime_wall_V2_8_01.png", min=1, max=2, add_displays={{image="terrain/slime/ochre/floor_wall_slime_%02d.png", display_y=1}}},
	default4={add_mos={{image="terrain/slime/ochre/slime_edge_vertical_left_01.png", display_x=-0.03125}}, min=1, max=1},
	default6={add_mos={{image="terrain/slime/ochre/slime_edge_vertical_right_01.png", display_x=0.03125}}, min=1, max=1},

	default6i={add_mos={{image="terrain/slime/ochre/slime_corner_topleft_going_right_01.png", display_y=-1, display_x=0.03125}, {image="terrain/slime/ochre/slime_corner_bottomleft_going_right_01.png", display_x=0.03125}}, min=1, max=1},
	default4i={add_mos={{image="terrain/slime/ochre/slime_corner_topright_going_left_01.png", display_y=-1, display_x=-0.03125}, {image="terrain/slime/ochre/slime_corner_bottomright_going_left_01.png", display_x=-0.03125}}, min=1, max=1},

	default3={add_mos={{image="terrain/slime/ochre/slime_corner_topleft_going_right_01.png", display_y=-1, display_x=0.03125}, {image="terrain/slime/ochre/slime_edge_vertical_right_01.png", display_x=0.03125}}, min=1, max=1},
	default1={add_mos={{image="terrain/slime/ochre/slime_corner_topright_going_left_01.png", display_y=-1, display_x=-0.03125}, {image="terrain/slime/ochre/slime_edge_vertical_left_01.png", display_x=-0.03125}}, min=1, max=1},
	default9={add_mos={{image="terrain/slime/ochre/slime_corner_bottomleft_going_right_01.png", display_x=0.03125}}, min=1, max=1},
	default7={add_mos={{image="terrain/slime/ochre/slime_corner_bottomright_going_left_01.png", display_x=-0.03125}}, min=1, max=1},

	default7i={add_mos={{image="terrain/slime/ochre/slime_edge_upper_left_01.png", display_y=-1, display_x=-0.03125}}, min=1, max=1},
	default9i={add_mos={{image="terrain/slime/ochre/slime_edge_upper_right_01.png", display_y=-1, display_x=0.03125}}, min=1, max=1},
},
sandwall = { method="walls", type="sandwall", forbid={}, use_type=true, extended=true,
	default8={add_displays={{image="terrain/sand/sandwall_8_1.png", display_y=-1, z=16}}, min=1, max=1},
	default8p={add_displays={{image="terrain/sand/sand_V3_pillar_top_01.png", display_y=-1, z=16}}, min=1, max=1},
	default7={add_displays={{image="terrain/sand/sand_V3_inner_7_01.png", display_y=-1, z=16}}, min=1, max=1},
	default9={add_displays={{image="terrain/sand/sand_V3_inner_9_01.png", display_y=-1, z=16}}, min=1, max=1},
	default7i={add_displays={{image="terrain/sand/sand_V3_3_01.png", display_y=-1, z=16}}, min=1, max=1},
	default8i={add_displays={{image="terrain/sand/sandwall_8h_1.png", display_y=-1, z=16}}, min=1, max=1},
	default9i={add_displays={{image="terrain/sand/sand_V3_1_01.png", display_y=-1, z=16}}, min=1, max=1},
	default73i={add_displays={{image="terrain/sand/sandwall_91d_1.png", display_y=-1, z=16}}, min=1, max=1},
	default91i={add_displays={{image="terrain/sand/sandwall_73d_1.png", display_y=-1, z=16}}, min=1, max=1},

	default2={image="terrain/sand/sand_V3_8_01.png", min=1, max=1},
	default2p={image="terrain/sand.png", add_mos={{image="terrain/sand/sand_V3_pillar_bottom_01.png"}}, min=1, max=1},
	default1={image="terrain/sand.png", add_mos={{image="terrain/sand/sand_V3_inner_1_01.png"}}, min=1, max=1},
	default3={image="terrain/sand.png", add_mos={{image="terrain/sand/sand_V3_inner_3_01.png"}}, min=1, max=1},
	default1i={image="terrain/sand/sand_V3_7_01.png", min=1, max=1},
	default2i={image="terrain/sand/sandwall_2h_1.png", min=1, max=1},
	default3i={image="terrain/sand/sand_V3_9_01.png", min=1, max=1},
	default19i={image="terrain/sand/sandwall_19d_1.png", min=1, max=1},
	default37i={image="terrain/sand/sandwall_37d_1.png", min=1, max=1},

	default4={add_displays={{image="terrain/sand/sand_ver_edge_left_01.png", display_x=-1}}, min=1, max=1},
	default6={add_displays={{image="terrain/sand/sand_ver_edge_right_01.png", display_x=1}}, min=1, max=1},
},
cavewall = { method="walls", type="cavewall", forbid={}, use_type=true, extended=true,
	default8={add_displays={{image="terrain/cave/cavewall_8_1.png", display_y=-1, z=16}}, min=1, max=1},
	default8p={add_displays={{image="terrain/cave/cave_V3_pillar_top_01.png", display_y=-1, z=16}}, min=1, max=1},
	default7={add_displays={{image="terrain/cave/cave_V3_inner_7_01.png", display_y=-1, z=16}}, min=1, max=1},
	default9={add_displays={{image="terrain/cave/cave_V3_inner_9_01.png", display_y=-1, z=16}}, min=1, max=1},
	default7i={add_displays={{image="terrain/cave/cave_V3_3_01.png", display_y=-1, z=16}}, min=1, max=1},
	default8i={add_displays={{image="terrain/cave/cavewall_8h_1.png", display_y=-1, z=16}}, min=1, max=1},
	default9i={add_displays={{image="terrain/cave/cave_V3_1_01.png", display_y=-1, z=16}}, min=1, max=1},
	default73i={add_displays={{image="terrain/cave/cavewall_91d_1.png", display_y=-1, z=16}}, min=1, max=1},
	default91i={add_displays={{image="terrain/cave/cavewall_73d_1.png", display_y=-1, z=16}}, min=1, max=1},

	default2={image="terrain/cave/cave_V3_8_0%d.png", min=1, max=3},
	default2p={image="terrain/cave/cave_floor_1_01.png", add_mos={{image="terrain/cave/cave_V3_pillar_bottom_01.png"}}, min=1, max=1},
	default1={image="terrain/cave/cave_floor_1_01.png", add_mos={{image="terrain/cave/cave_V3_inner_1_01.png"}}, min=1, max=1},
	default3={image="terrain/cave/cave_floor_1_01.png", add_mos={{image="terrain/cave/cave_V3_inner_3_01.png"}}, min=1, max=1},
	default1i={image="terrain/cave/cave_V3_7_01.png", min=1, max=1},
	default2i={image="terrain/cave/cavewall_2h_1.png", min=1, max=1},
	default3i={image="terrain/cave/cave_V3_9_01.png", min=1, max=1},
	default19i={image="terrain/cave/cavewall_19d_1.png", min=1, max=1},
	default37i={image="terrain/cave/cavewall_37d_1.png", min=1, max=1},

	default4={add_displays={{image="terrain/cave/cave_ver_edge_left_01.png", display_x=-1}}, min=1, max=1},
	default6={add_displays={{image="terrain/cave/cave_ver_edge_right_01.png", display_x=1}}, min=1, max=1},
},
icecavewall = { method="walls", type="icecavewall", forbid={}, use_type=true, extended=true, consider_diagonal_doors=true,
	default8={add_displays={{image="terrain/icecave/icecavewall_8_%d.png", display_y=-1, z=16}}, min=1, max=3},
	default8p={add_displays={{image="terrain/icecave/icecave_V3_pillar_top_0%d.png", display_y=-1, z=16}}, min=1, max=1},
	default7={add_displays={{image="terrain/icecave/icecave_V3_inner_7_01.png", display_y=-1, z=16}}, min=1, max=1},
	default9={add_displays={{image="terrain/icecave/icecave_V3_inner_9_01.png", display_y=-1, z=16}}, min=1, max=1},
	default7i={add_displays={{image="terrain/icecave/icecave_V3_3_01.png", display_y=-1, z=16}}, min=1, max=1},
	default8i={add_displays={{image="terrain/icecave/icecavewall_8h_1.png", display_y=-1, z=16}}, min=1, max=1},
	default9i={add_displays={{image="terrain/icecave/icecave_V3_1_01.png", display_y=-1, z=16}}, min=1, max=1},
	default73i={add_displays={{image="terrain/icecave/icecavewall_91d_1.png", display_y=-1, z=16}}, min=1, max=1},
	default91i={add_displays={{image="terrain/icecave/icecavewall_73d_1.png", display_y=-1, z=16}}, min=1, max=1},

	default2={image="terrain/icecave/icecave_floor_1_01.png", add_mos={{image="terrain/icecave/icecave_V3_8_0%d.png"}}, min=1, max=3},
	default2p={image="terrain/icecave/icecave_floor_1_01.png", add_mos={{image="terrain/icecave/icecave_V3_pillar_bottom_0%d.png"}}, min=1, max=3},
	default1={image="terrain/icecave/icecave_floor_1_01.png", add_mos={{image="terrain/icecave/icecave_V3_inner_1_01.png"}}, min=1, max=1},
	default3={image="terrain/icecave/icecave_floor_1_01.png", add_mos={{image="terrain/icecave/icecave_V3_inner_3_01.png"}}, min=1, max=1},
	default1i={image="terrain/icecave/icecave_floor_1_01.png", add_mos={{image="terrain/icecave/icecave_V3_7_01.png"}}, min=1, max=1},
	default2i={image="terrain/icecave/icecave_floor_1_01.png", add_mos={{image="terrain/icecave/icecavewall_2h_1.png"}}, min=1, max=1},
	default3i={image="terrain/icecave/icecave_floor_1_01.png", add_mos={{image="terrain/icecave/icecave_V3_9_01.png"}}, min=1, max=1},
	default19i={image="terrain/icecave/icecave_floor_1_01.png", add_mos={{image="terrain/icecave/icecavewall_19d_1.png"}}, min=1, max=1},
	default37i={image="terrain/icecave/icecave_floor_1_01.png", add_mos={{image="terrain/icecave/icecavewall_37d_1.png"}}, min=1, max=1},

	default4={add_displays={{image="terrain/icecave/icecave_ver_edge_left_01.png", display_x=-1}}, min=1, max=1},
	default6={add_displays={{image="terrain/icecave/icecave_ver_edge_right_01.png", display_x=1}}, min=1, max=1},
},
bonewall = { method="walls", type="bonewall", forbid={}, use_type=true, extended=true, consider_diagonal_doors=true,
	default8={add_displays={{image="terrain/bone/bonewall_8_1.png", display_y=-1, z=16}}, min=1, max=1},
	default8p={add_displays={{image="terrain/bone/bone_V3_pillar_top_0%d.png", display_y=-1, z=16}}, min=1, max=4},
	default7={add_displays={{image="terrain/bone/bone_V3_inner_7_01.png", display_y=-1, z=16}}, min=1, max=1},
	default9={add_displays={{image="terrain/bone/bone_V3_inner_9_01.png", display_y=-1, z=16}}, min=1, max=1},
	default7i={add_displays={{image="terrain/bone/bone_V3_3_01.png", display_y=-1, z=16}}, min=1, max=1},
	default8i={add_displays={{image="terrain/bone/bonewall_8h_1.png", display_y=-1, z=16}}, min=1, max=1},
	default9i={add_displays={{image="terrain/bone/bone_V3_1_01.png", display_y=-1, z=16}}, min=1, max=1},
	default73i={add_displays={{image="terrain/bone/bonewall_91d_1.png", display_y=-1, z=16}}, min=1, max=1},
	default91i={add_displays={{image="terrain/bone/bonewall_73d_1.png", display_y=-1, z=16}}, min=1, max=1},

	default2={image="terrain/bone/bone_floor_1_01.png", add_mos={{image="terrain/bone/bone_V3_8_0%d.png"}}, min=1, max=8},
	default2p={image="terrain/bone/bone_floor_1_01.png", add_mos={{image="terrain/bone/bone_V3_pillar_bottom_0%d.png"}}, min=1, max=3},
	default1={image="terrain/bone/bone_floor_1_01.png", add_mos={{image="terrain/bone/bone_V3_inner_1_01.png"}}, min=1, max=1},
	default3={image="terrain/bone/bone_floor_1_01.png", add_mos={{image="terrain/bone/bone_V3_inner_3_01.png"}}, min=1, max=1},
	default1i={image="terrain/bone/bone_floor_1_01.png", add_mos={{image="terrain/bone/bone_V3_7_01.png"}}, min=1, max=1},
	default2i={image="terrain/bone/bone_floor_1_01.png", add_mos={{image="terrain/bone/bonewall_2h_1.png"}}, min=1, max=1},
	default3i={image="terrain/bone/bone_floor_1_01.png", add_mos={{image="terrain/bone/bone_V3_9_01.png"}}, min=1, max=1},
	default19i={image="terrain/bone/bone_floor_1_01.png", add_mos={{image="terrain/bone/bonewall_19d_1.png"}}, min=1, max=1},
	default37i={image="terrain/bone/bone_floor_1_01.png", add_mos={{image="terrain/bone/bonewall_37d_1.png"}}, min=1, max=1},

	default4={add_displays={{image="terrain/bone/bone_ver_edge_left_01.png", display_x=-1}}, min=1, max=1},
	default6={add_displays={{image="terrain/bone/bone_ver_edge_right_01.png", display_x=1}}, min=1, max=1},
},
rift = { method="walls", type="riftwall", forbid={}, use_type=true, extended=true,
	default8={add_displays={{image="terrain/rift/riftwall_8_1.png", display_y=-1, z=16}}, min=1, max=1},
	default8p={add_displays={{image="terrain/rift/rift_V3_pillar_top_01.png", display_y=-1, z=16}}, min=1, max=1},
	default7={add_displays={{image="terrain/rift/rift_V3_inner_7_01.png", display_y=-1, z=16}}, min=1, max=1},
	default9={add_displays={{image="terrain/rift/rift_V3_inner_9_01.png", display_y=-1, z=16}}, min=1, max=1},
	default7i={add_displays={{image="terrain/rift/rift_V3_3_01.png", display_y=-1, z=16}}, min=1, max=1},
	default8i={add_displays={{image="terrain/rift/riftwall_8h_1.png", display_y=-1, z=16}}, min=1, max=1},
	default9i={add_displays={{image="terrain/rift/rift_V3_1_01.png", display_y=-1, z=16}}, min=1, max=1},
	default73i={add_displays={{image="terrain/rift/riftwall_91d_1.png", display_y=-1, z=16}}, min=1, max=1},
	default91i={add_displays={{image="terrain/rift/riftwall_73d_1.png", display_y=-1, z=16}}, min=1, max=1},

	default2={image="terrain/rift/rift_V3_8_0%d.png", min=1, max=1},
	default2p={image="invis.png", add_mos={{image="terrain/rift/rift_V3_pillar_bottom_01.png"}}, min=1, max=1},
	default1={image="invis.png", add_mos={{image="terrain/rift/rift_V3_inner_1_01.png"}}, min=1, max=1},
	default3={image="invis.png", add_mos={{image="terrain/rift/rift_V3_inner_3_01.png"}}, min=1, max=1},
	default1i={image="terrain/rift/rift_V3_7_01.png", min=1, max=1},
	default2i={image="terrain/rift/riftwall_2h_1.png", min=1, max=1},
	default3i={image="terrain/rift/rift_V3_9_01.png", min=1, max=1},
	default19i={image="terrain/rift/riftwall_19d_1.png", min=1, max=1},
	default37i={image="terrain/rift/riftwall_37d_1.png", min=1, max=1},

	default4={add_displays={{image="terrain/rift/rift_ver_edge_left_01.png", display_x=-1}}, min=1, max=1},
	default6={add_displays={{image="terrain/rift/rift_ver_edge_right_01.png", display_x=1}}, min=1, max=1},
},

grass_wm = { method="borders", type="grass", forbid={lava=true, rock=true},
	default8={add_mos={{image="terrain/grass_worldmap/grass_2_%02d.png", display_y=-1}}, min=1, max=2},
	default2={add_mos={{image="terrain/grass_worldmap/grass_8_%02d.png", display_y=1}}, min=1, max=2},
	default4={add_mos={{image="terrain/grass_worldmap/grass_6_%02d.png", display_x=-1}}, min=1, max=2},
	default6={add_mos={{image="terrain/grass_worldmap/grass_4_%02d.png", display_x=1}}, min=1, max=2},

	default1={z=3,add_mos={{image="terrain/grass_worldmap/grass_9_%02d.png", display_x=-1, display_y=1}}, min=1, max=1},
	default3={z=3,add_mos={{image="terrain/grass_worldmap/grass_7_%02d.png", display_x=1, display_y=1}}, min=1, max=1},
	default7={z=3,add_mos={{image="terrain/grass_worldmap/grass_3_%02d.png", display_x=-1, display_y=-1}}, min=1, max=1},
	default9={z=3,add_mos={{image="terrain/grass_worldmap/grass_1_%02d.png", display_x=1, display_y=-1}}, min=1, max=1},

	default1i={add_mos={{image="terrain/grass_worldmap/grass_inner_1_%02d.png", display_x=-1, display_y=1}}, min=1, max=2},
	default3i={add_mos={{image="terrain/grass_worldmap/grass_inner_3_%02d.png", display_x=1, display_y=1}}, min=1, max=2},
	default7i={add_mos={{image="terrain/grass_worldmap/grass_inner_7_%02d.png", display_x=-1, display_y=-1}}, min=1, max=2},
	default9i={add_mos={{image="terrain/grass_worldmap/grass_inner_9_%02d.png", display_x=1, display_y=-1}}, min=1, max=2},
},
psitechwall = { method="walls", type="psitechwall", forbid={}, use_type=true, extended=true, consider_diagonal_doors=true,
	default8={add_displays={{image="terrain/psicave/psitechwall_8_%d.png", display_y=-1, z=16}}, min=1, max=1},
	default8p={add_displays={{image="terrain/psicave/psitech_V3_pillar_top_0%d.png", display_y=-1, z=16}}, min=1, max=1},
	default7={add_displays={{image="terrain/psicave/psitech_V3_inner_7_01.png", display_y=-1, z=16}}, min=1, max=1},
	default9={add_displays={{image="terrain/psicave/psitech_V3_inner_9_01.png", display_y=-1, z=16}}, min=1, max=1},
	default7i={add_displays={{image="terrain/psicave/psitech_V3_3_01.png", display_y=-1, z=16}}, min=1, max=1},
	default8i={add_displays={{image="terrain/psicave/psitechwall_8h_1.png", display_y=-1, z=16}}, min=1, max=1},
	default9i={add_displays={{image="terrain/psicave/psitech_V3_1_01.png", display_y=-1, z=16}}, min=1, max=1},
	default73i={add_displays={{image="terrain/psicave/psitechwall_91d_1.png", display_y=-1, z=16}}, min=1, max=1},
	default91i={add_displays={{image="terrain/psicave/psitechwall_73d_1.png", display_y=-1, z=16}}, min=1, max=1},

	default2={image="terrain/psicave/psitech_floor_1_01.png", add_mos={{image="terrain/psicave/psitech_V3_8_0%d.png"}}, min=1, max=3},
	default2p={image="terrain/psicave/psitech_floor_1_01.png", add_mos={{image="terrain/psicave/psitech_V3_pillar_bottom_0%d.png"}}, min=1, max=2},
	default1={image="terrain/psicave/psitech_floor_1_01.png", add_mos={{image="terrain/psicave/psitech_V3_inner_1_01.png"}}, min=1, max=1},
	default3={image="terrain/psicave/psitech_floor_1_01.png", add_mos={{image="terrain/psicave/psitech_V3_inner_3_01.png"}}, min=1, max=1},
	default1i={image="terrain/psicave/psitech_floor_1_01.png", add_mos={{image="terrain/psicave/psitech_V3_7_01.png"}}, min=1, max=1},
	default2i={image="terrain/psicave/psitech_floor_1_01.png", add_mos={{image="terrain/psicave/psitechwall_2h_1.png"}}, min=1, max=1},
	default3i={image="terrain/psicave/psitech_floor_1_01.png", add_mos={{image="terrain/psicave/psitech_V3_9_01.png"}}, min=1, max=1},
	default19i={image="terrain/psicave/psitech_floor_1_01.png", add_mos={{image="terrain/psicave/psitechwall_19d_1.png"}}, min=1, max=1},
	default37i={image="terrain/psicave/psitech_floor_1_01.png", add_mos={{image="terrain/psicave/psitechwall_37d_1.png"}}, min=1, max=1},

	default4={add_displays={{image="terrain/psicave/psitech_ver_edge_left_01.png", display_x=-1}}, min=1, max=1},
	default6={add_displays={{image="terrain/psicave/psitech_ver_edge_right_01.png", display_x=1}}, min=1, max=1},
},
}
_M.generic_borders_defs = defs


--- Make water have nice transition to other stuff
local gtype = type
function _M:editTileGenericBorders(level, i, j, g, nt, type)
	local kind
	if gtype(nt.use_type) == "string" then kind = nt.use_type
	else kind = nt.use_type and "type" or "subtype"
	end
	local g5 = level.map:checkEntity(i, j,   Map.TERRAIN, kind) or type
	local g8 = level.map:checkEntity(i, j-1, Map.TERRAIN, kind) or type
	local g2 = level.map:checkEntity(i, j+1, Map.TERRAIN, kind) or type
	local g4 = level.map:checkEntity(i-1, j, Map.TERRAIN, kind) or type
	local g6 = level.map:checkEntity(i+1, j, Map.TERRAIN, kind) or type
	local g7 = level.map:checkEntity(i-1, j-1, Map.TERRAIN, kind) or type
	local g9 = level.map:checkEntity(i+1, j-1, Map.TERRAIN, kind) or type
	local g1 = level.map:checkEntity(i-1, j+1, Map.TERRAIN, kind) or type
	local g3 = level.map:checkEntity(i+1, j+1, Map.TERRAIN, kind) or type
	if nt.forbid then
		if nt.forbid[g5] then g5 = type end
		if nt.forbid[g4] then g4 = type end
		if nt.forbid[g6] then g6 = type end
		if nt.forbid[g8] then g8 = type end
		if nt.forbid[g2] then g2 = type end
		if nt.forbid[g1] then g1 = type end
		if nt.forbid[g3] then g3 = type end
		if nt.forbid[g7] then g7 = type end
		if nt.forbid[g9] then g9 = type end
	end

	local id = rng.range(1,NB_VARIATIONS).."genbord:"..table.concat({g.define_as or "--",type,tostring(g1==g5),tostring(g2==g5),tostring(g3==g5),tostring(g4==g5),tostring(g5==g5),tostring(g6==g5),tostring(g7==g5),tostring(g8==g5),tostring(g9==g5)}, ",")

	-- Sides
	if g5 ~= g8 then self:edit(i, j, id, nt[g8.."8"] or nt["default8"]) end
	if g5 ~= g2 then self:edit(i, j, id, nt[g2.."2"] or nt["default2"]) end
	if g5 ~= g4 then self:edit(i, j, id, nt[g4.."4"] or nt["default4"]) end
	if g5 ~= g6 then self:edit(i, j, id, nt[g6.."6"] or nt["default6"]) end
	-- Corners
	if g5 ~= g7 and g5 == g4 and g5 == g8 then self:edit(i, j, id, nt[g7.."7"] or nt["default7"]) end
	if g5 ~= g9 and g5 == g6 and g5 == g8 then self:edit(i, j, id, nt[g9.."9"] or nt["default9"]) end
	if g5 ~= g1 and g5 == g4 and g5 == g2 then self:edit(i, j, id, nt[g1.."1"] or nt["default1"]) end
	if g5 ~= g3 and g5 == g6 and g5 == g2 then self:edit(i, j, id, nt[g3.."3"] or nt["default3"]) end
	-- Inner corners
	if g5 ~= g7 and g5 ~= g4 and g5 ~= g8 then self:edit(i, j, id, nt[g7.."7i"] or nt["default7i"]) end
	if g5 ~= g9 and g5 ~= g6 and g5 ~= g8 then self:edit(i, j, id, nt[g9.."9i"] or nt["default9i"]) end
	if g5 ~= g1 and g5 ~= g4 and g5 ~= g2 then self:edit(i, j, id, nt[g1.."1i"] or nt["default1i"]) end
	if g5 ~= g3 and g5 ~= g6 and g5 ~= g2 then self:edit(i, j, id, nt[g3.."3i"] or nt["default3i"]) end
end

--- Make water have nice transition to other stuff
function _M:editTileGenericWalls(level, i, j, g, nt, type)
	local kind = nt.use_type and "type" or "subtype"
	local g5 = level.map:checkEntity(i, j,   Map.TERRAIN, kind) or type
	local g8 = level.map:checkEntity(i, j-1, Map.TERRAIN, kind) or type
	local g2 = level.map:checkEntity(i, j+1, Map.TERRAIN, kind) or type
	local g4 = level.map:checkEntity(i-1, j, Map.TERRAIN, kind) or type
	local g6 = level.map:checkEntity(i+1, j, Map.TERRAIN, kind) or type
	local g7 = level.map:checkEntity(i-1, j-1, Map.TERRAIN, kind) or type
	local g9 = level.map:checkEntity(i+1, j-1, Map.TERRAIN, kind) or type
	local g1 = level.map:checkEntity(i-1, j+1, Map.TERRAIN, kind) or type
	local g3 = level.map:checkEntity(i+1, j+1, Map.TERRAIN, kind) or type
	if nt.forbid then
		if nt.forbid[g5] then g5 = type end
		if nt.forbid[g4] then g4 = type end
		if nt.forbid[g6] then g6 = type end
		if nt.forbid[g8] then g8 = type end
		if nt.forbid[g2] then g2 = type end
		if nt.forbid[g1] then g1 = type end
		if nt.forbid[g3] then g3 = type end
		if nt.forbid[g7] then g7 = type end
		if nt.forbid[g9] then g9 = type end
	end

	local id = rng.range(1,NB_VARIATIONS).."genwall:"..table.concat({g.define_as or "--",type,tostring(g1==g5),tostring(g2==g5),tostring(g3==g5),tostring(g4==g5),tostring(g5==g5),tostring(g6==g5),tostring(g7==g5),tostring(g8==g5),tostring(g9==g5)}, ",")

	-- Sides
	if     g5 ~= g8 then self:edit(i, j, id, nt[g8.."8"] or nt["default8"]) end
	if     g5 ~= g2 then self:edit(i, j, id, nt[g2.."2"] or nt["default2"]) end

	if     g5 ~= g4 and g5 ~= g7 and g5 ~= g1 then self:edit(i, j, id, nt[g4.."4"] or nt["default4"])
	elseif g5 ~= g4 and g5 == g7 and g5 ~= g1 then self:edit(i, j, id, nt[g1.."1"] or nt["default1"])
	elseif g5 ~= g4 and g5 ~= g7 and g5 == g1 then self:edit(i, j, id, nt[g7.."7"] or nt["default7"])
	elseif g5 ~= g4 and g5 == g7 and g5 == g1 then self:edit(i, j, id, nt[g4.."4i"] or nt["default4i"])
	end

	if     g5 ~= g6 and g5 ~= g9 and g5 ~= g3 then self:edit(i, j, id, nt[g6.."6"] or nt["default6"])
	elseif g5 ~= g6 and g5 == g9 and g5 ~= g3 then self:edit(i, j, id, nt[g3.."3"] or nt["default3"])
	elseif g5 ~= g6 and g5 ~= g9 and g5 == g3 then self:edit(i, j, id, nt[g9.."9"] or nt["default9"])
	elseif g5 ~= g6 and g5 == g9 and g5 == g3 then self:edit(i, j, id, nt[g6.."6i"] or nt["default6i"])
	end

	-- Tops
	if     g5 ~= g4 and g5 ~= g7 and g5 ~= g8 then self:edit(i, j, id, nt[g7.."7i"] or nt["default7i"]) end
	if     g5 ~= g6 and g5 ~= g9 and g5 ~= g8 then self:edit(i, j, id, nt[g9.."9i"] or nt["default9i"]) end
end

--- Make water have nice transition to other stuff
function _M:editTileGenericSandWalls(level, i, j, g, nt, type)
	local kind = nt.use_type and "type" or "subtype"
	local g5 = level.map:checkEntity(i, j,   Map.TERRAIN, kind) or type
	local g8 = level.map:checkEntity(i, j-1, Map.TERRAIN, kind) or type
	local g2 = level.map:checkEntity(i, j+1, Map.TERRAIN, kind) or type
	local g4 = level.map:checkEntity(i-1, j, Map.TERRAIN, kind) or type
	local g6 = level.map:checkEntity(i+1, j, Map.TERRAIN, kind) or type
	local g7 = level.map:checkEntity(i-1, j-1, Map.TERRAIN, kind) or type
	local g9 = level.map:checkEntity(i+1, j-1, Map.TERRAIN, kind) or type
	local g1 = level.map:checkEntity(i-1, j+1, Map.TERRAIN, kind) or type
	local g3 = level.map:checkEntity(i+1, j+1, Map.TERRAIN, kind) or type
	local g2d = level.map:checkEntity(i, j+1, Map.TERRAIN, "is_door")
	local g7d = nil
	local g1d = nil
	local g3d = nil
	local g9d = nil
	if g2d then g2 = "floor" end
	if nt.consider_diagonal_doors then
		g7d = level.map:checkEntity(i-1, j-1, Map.TERRAIN, "is_door")
		g1d = level.map:checkEntity(i-1, j+1, Map.TERRAIN, "is_door")
		g3d = level.map:checkEntity(i+1, j+1, Map.TERRAIN, "is_door")
		g9d = level.map:checkEntity(i+1, j-1, Map.TERRAIN, "is_door")

		if g7d then g7 = "floor" end
		if g9d then g9 = "floor" end
		if g3d then g3 = "floor" end
		if g1d then g1 = "floor" end
	end
	if nt.forbid then
		if nt.forbid[g5] then g5 = type end
		if nt.forbid[g4] then g4 = type end
		if nt.forbid[g6] then g6 = type end
		if nt.forbid[g8] then g8 = type end
		if nt.forbid[g2] then g2 = type end
		if nt.forbid[g1] then g1 = type end
		if nt.forbid[g3] then g3 = type end
		if nt.forbid[g7] then g7 = type end
		if nt.forbid[g9] then g9 = type end
	end

	local id = rng.range(1,NB_VARIATIONS).."sandwall:"..table.concat({g.define_as or "--",type,tostring(g1==g5),tostring(g2==g5),tostring(g3==g5),tostring(g4==g5),tostring(g5==g5),tostring(g6==g5),tostring(g7==g5),tostring(g8==g5),tostring(g9==g5)}, ",")

	-- Sides
	if     g5 ~= g8 and g5 ~= g7 and g5 ~= g9 then
		if     g5 ~= g4 and g5 ~= g6 then self:edit(i, j, id, nt[g8.."8p"] or nt["default8p"])
		elseif g5 == g4 and g5 == g6 then self:edit(i, j, id, nt[g8.."8"] or nt["default8"])
		elseif g5 ~= g4 and g5 == g6 then self:edit(i, j, id, nt[g7.."7"] or nt["default7"])
		elseif g5 == g4 and g5 ~= g6 then self:edit(i, j, id, nt[g9.."9"] or nt["default9"])
		end
	elseif g5 ~= g8 and g5 ~= g7 and g5 == g9 then
		if     g5 == g4 then self:edit(i, j, id, nt[g7.."7i"] or nt["default7i"])
		elseif g5 ~= g4 then self:edit(i, j, id, nt[g7.."73i"] or nt["default73i"])
		end
	elseif g5 ~= g8 and g5 == g7 and g5 ~= g9 then
		if     g5 == g6 then self:edit(i, j, id, nt[g9.."9i"] or nt["default9i"])
		elseif g5 ~= g6 then self:edit(i, j, id, nt[g9.."91i"] or nt["default91i"])
		end
	elseif g5 ~= g8 and g5 == g7 and g5 == g9 then self:edit(i, j, id, nt[g8.."8i"] or nt["default8i"])
	end

	if     g5 ~= g2 and g5 ~= g1 and g5 ~= g3 then
		if     g5 ~= g4 and g5 ~= g6 then self:edit(i, j, id, nt[g2.."2p"] or nt["default2p"])
		elseif g5 == g4 and g5 == g6 then self:edit(i, j, id, nt[g2.."2"] or nt["default2"])
		elseif g5 ~= g4 and g5 == g6 then self:edit(i, j, id, nt[g1.."1"] or nt["default1"])
		elseif g5 == g4 and g5 ~= g6 then self:edit(i, j, id, nt[g3.."3"] or nt["default3"])
		end
	elseif g5 ~= g2 and g5 ~= g1 and g5 == g3 then
		if     g5 == g4 then self:edit(i, j, id, nt[g3.."3i"] or nt["default3i"])
		elseif g5 ~= g4 then self:edit(i, j, id, nt[g3.."37i"] or nt["default37i"])
		end
	elseif g5 ~= g2 and g5 == g1 and g5 ~= g3 then
		if     g5 == g6 then self:edit(i, j, id, nt[g1.."1i"] or nt["default1i"])
		elseif g5 ~= g6 then self:edit(i, j, id, nt[g1.."19i"] or nt["default19i"])
		end
	elseif g5 ~= g2 and g5 == g1 and g5 == g3 then self:edit(i, j, id, nt[g2.."2i"] or nt["default2i"])
	end

	if     g5 ~= g4 and g5 == g2 and g5 ~= g1 then self:edit(i, j, id, nt[g4.."4"] or nt["default4"]) end
	if     g5 ~= g6 and g5 == g2 and g5 ~= g3 then self:edit(i, j, id, nt[g6.."6"] or nt["default6"]) end
end

function _M:editTileBorders(level, i, j, g, nt)
	self:editTileGenericBorders(level, i, j, g, nt, nt.type or "grass")
end
function _M:editTileBorders_def(level, i, j, g, nt)
	self:editTileGenericBorders(level, i, j, g, defs[nt.def], defs[nt.def].type or "grass")
end
function _M:editTileWalls_def(level, i, j, g, nt)
	self:editTileGenericWalls(level, i, j, g, defs[nt.def], defs[nt.def].type or "grass")
end
function _M:editTileSandWalls_def(level, i, j, g, nt)
	self:editTileGenericSandWalls(level, i, j, g, defs[nt.def], defs[nt.def].type or "grass")
end

function _M:editTileSingleWall(level, i, j, g, nt, type)
	type = type or nt.type
	local kind = nt.use_subtype and "subtype" or "type"
	local g5 = level.map:checkEntity(i, j,   Map.TERRAIN, kind) or type
	local g8 = level.map:checkEntity(i, j-1, Map.TERRAIN, kind) or type
	local g2 = level.map:checkEntity(i, j+1, Map.TERRAIN, kind) or type
	local g4 = level.map:checkEntity(i-1, j, Map.TERRAIN, kind) or type
	local g6 = level.map:checkEntity(i+1, j, Map.TERRAIN, kind) or type

	local id = rng.range(1,NB_VARIATIONS).."swv:"..table.concat({g.define_as or "--",type,tostring(g1==g5),tostring(g2==g5),tostring(g8==g5),tostring(g4==g5),tostring(g6==g5)}, ",")

	if     g5 ~= g4 and g5 == g6 and g5 == g8 and g5 == g2 then self:edit(i, j, id, nt["e_cross"])
	elseif g5 == g4 and g5 ~= g6 and g5 == g8 and g5 == g2 then self:edit(i, j, id, nt["w_cross"])
	elseif g5 == g4 and g5 == g6 and g5 ~= g8 and g5 == g2 then self:edit(i, j, id, nt["s_cross"])
	elseif g5 == g4 and g5 == g6 and g5 == g8 and g5 ~= g2 then self:edit(i, j, id, nt["n_cross"])

	elseif g5 ~= g4 and g5 == g6 and g5 == g8 and g5 ~= g2 then self:edit(i, j, id, nt["ne"])
	elseif g5 == g4 and g5 ~= g6 and g5 == g8 and g5 ~= g2 then self:edit(i, j, id, nt["nw"])
	elseif g5 ~= g4 and g5 == g6 and g5 ~= g8 and g5 == g2 then self:edit(i, j, id, nt["se"])
	elseif g5 == g4 and g5 ~= g6 and g5 ~= g8 and g5 == g2 then self:edit(i, j, id, nt["sw"])

	elseif g5 == g4 and g5 == g6 and g5 == g8 and g5 == g2 then self:edit(i, j, id, nt["cross"])

	elseif g5 ~= g4 and g5 ~= g6 and g5 == g8 and g5 == g2 then self:edit(i, j, id, nt["v_full"])
	elseif g5 == g4 and g5 == g6 and g5 ~= g8 and g5 ~= g2  then self:edit(i, j, id, nt["h_full"])
	end
end

local defs = {
oldstone = { method="road", marker="road",
	default82={add_mos={{image="terrain/road_oldstone/road_vertical_a_%02d.png"}}, min=1, max=3},
	default46={add_mos={{image="terrain/road_oldstone/road_horizontal_a_%02d.png"}}, min=1, max=3},

	default8246={add_mos={{image="terrain/road_oldstone/road_cross_a_%02d.png"}}, min=1, max=1},

	default846={add_mos={{image="terrain/road_oldstone/road_t_section_c_%02d.png"}}, min=1, max=1},
	default246={add_mos={{image="terrain/road_oldstone/road_t_section_a_%02d.png"}}, min=1, max=1},
	default824={add_mos={{image="terrain/road_oldstone/road_t_section_b_%02d.png"}}, min=1, max=1},
	default826={add_mos={{image="terrain/road_oldstone/road_t_section_d_%02d.png"}}, min=1, max=1},

	default84={add_mos={{image="terrain/road_oldstone/road_turn_c_%02d.png"}}, min=1, max=2},
	default86={add_mos={{image="terrain/road_oldstone/road_turn_d_%02d.png"}}, min=1, max=2},
	default26={add_mos={{image="terrain/road_oldstone/road_turn_a_%02d.png"}}, min=1, max=2},
	default24={add_mos={{image="terrain/road_oldstone/road_turn_b_%02d.png"}}, min=1, max=2},

	default4={add_mos={{image="terrain/road_oldstone/road_end_a_02.png"}}, min=1, max=1},
	default6={add_mos={{image="terrain/road_oldstone/road_end_a_01.png"}}, min=1, max=1},
	default2={add_mos={{image="terrain/road_oldstone/road_end_a_03.png"}}, min=1, max=1},
	default8={add_mos={{image="terrain/road_oldstone/road_end_a_04.png"}}, min=1, max=1},
},
dirt = { method="road", marker="road",
	default82={add_mos={{image="terrain/road_dirt/road_vertical_a_%02d.png"}}, min=1, max=3},
	default46={add_mos={{image="terrain/road_dirt/road_horizontal_a_%02d.png"}}, min=1, max=3},

	default8246={add_mos={{image="terrain/road_dirt/road_cross_a_%02d.png"}}, min=1, max=1},

	default846={add_mos={{image="terrain/road_dirt/road_t_section_c_%02d.png"}}, min=1, max=1},
	default246={add_mos={{image="terrain/road_dirt/road_t_section_a_%02d.png"}}, min=1, max=1},
	default824={add_mos={{image="terrain/road_dirt/road_t_section_b_%02d.png"}}, min=1, max=1},
	default826={add_mos={{image="terrain/road_dirt/road_t_section_d_%02d.png"}}, min=1, max=1},

	default84={add_mos={{image="terrain/road_dirt/road_turn_c_%02d.png"}}, min=1, max=2},
	default86={add_mos={{image="terrain/road_dirt/road_turn_d_%02d.png"}}, min=1, max=2},
	default26={add_mos={{image="terrain/road_dirt/road_turn_a_%02d.png"}}, min=1, max=2},
	default24={add_mos={{image="terrain/road_dirt/road_turn_b_%02d.png"}}, min=1, max=2},

	default4={add_mos={{image="terrain/road_dirt/road_end_a_02.png"}}, min=1, max=1},
	default6={add_mos={{image="terrain/road_dirt/road_end_a_01.png"}}, min=1, max=1},
	default2={add_mos={{image="terrain/road_dirt/road_end_a_03.png"}}, min=1, max=1},
	default8={add_mos={{image="terrain/road_dirt/road_end_a_04.png"}}, min=1, max=1},
},
wooden_barricade = { method="road", marker="barricade",
	default82={add_mos={{image="terrain/wooden_barricade/barricade_vertical_a_%02d.png"}}, min=1, max=3},
	default46={add_mos={{image="terrain/wooden_barricade/barricade_horizontal_a_%02d.png"}}, min=1, max=3},

	default8246={add_mos={{image="terrain/wooden_barricade/barricade_cross_a_%02d.png"}}, min=1, max=1},

	default846={add_mos={{image="terrain/wooden_barricade/barricade_t_section_c_%02d.png"}}, min=1, max=1},
	default246={add_mos={{image="terrain/wooden_barricade/barricade_t_section_a_%02d.png"}}, min=1, max=1},
	default824={add_mos={{image="terrain/wooden_barricade/barricade_t_section_b_%02d.png"}}, min=1, max=1},
	default826={add_mos={{image="terrain/wooden_barricade/barricade_t_section_d_%02d.png"}}, min=1, max=1},

	default84={add_mos={{image="terrain/wooden_barricade/barricade_turn_c_%02d.png"}}, min=1, max=2},
	default86={add_mos={{image="terrain/wooden_barricade/barricade_turn_d_%02d.png"}}, min=1, max=2},
	default26={add_mos={{image="terrain/wooden_barricade/barricade_turn_a_%02d.png"}}, min=1, max=2},
	default24={add_mos={{image="terrain/wooden_barricade/barricade_turn_b_%02d.png"}}, min=1, max=2},

	default4={add_mos={{image="terrain/wooden_barricade/barricade_end_a_02.png"}}, min=1, max=1},
	default6={add_mos={{image="terrain/wooden_barricade/barricade_end_a_01.png"}}, min=1, max=1},
	default2={add_mos={{image="terrain/wooden_barricade/barricade_end_a_03.png"}}, min=1, max=1},
	default8={add_mos={{image="terrain/wooden_barricade/barricade_end_a_04.png"}}, min=1, max=1},
},
}
_M.generic_roads_defs = defs

--- Make water have nice transition to other stuff
function _M:editTileGenericRoad(level, i, j, g, nt, type)
	local kind = nt.marker
	local g5 = level.map:checkEntity(i, j,   Map.TERRAIN, kind) or type
	local g8 = level.map:checkEntity(i, j-1, Map.TERRAIN, kind) or type
	local g2 = level.map:checkEntity(i, j+1, Map.TERRAIN, kind) or type
	local g4 = level.map:checkEntity(i-1, j, Map.TERRAIN, kind) or type
	local g6 = level.map:checkEntity(i+1, j, Map.TERRAIN, kind) or type
	local g7 = level.map:checkEntity(i-1, j-1, Map.TERRAIN, kind) or type
	local g9 = level.map:checkEntity(i+1, j-1, Map.TERRAIN, kind) or type
	local g1 = level.map:checkEntity(i-1, j+1, Map.TERRAIN, kind) or type
	local g3 = level.map:checkEntity(i+1, j+1, Map.TERRAIN, kind) or type

	local id = "genroad:"..table.concat({g.define_as or "--",type,tostring(g1==g5),tostring(g2==g5),tostring(g3==g5),tostring(g4==g5),tostring(g5==g5),tostring(g6==g5),tostring(g7==g5),tostring(g8==g5),tostring(g9==g5)}, ",")

	-- Cross & semi cross
	if     g5 == g8 and g5 == g2 and g5 == g4 and g5 == g6 then self:edit(i, j, id, nt["default8246"])
	elseif g5 ~= g8 and g5 == g2 and g5 == g4 and g5 == g6 then self:edit(i, j, id, nt["default246"])
	elseif g5 == g8 and g5 ~= g2 and g5 == g4 and g5 == g6 then self:edit(i, j, id, nt["default846"])
	elseif g5 == g8 and g5 == g2 and g5 ~= g4 and g5 == g6 then self:edit(i, j, id, nt["default826"])
	elseif g5 == g8 and g5 == g2 and g5 == g4 and g5 ~= g6 then self:edit(i, j, id, nt["default824"])

	-- Corners
	elseif g5 == g8 and g5 ~= g2 and g5 ~= g4 and g5 == g6 then self:edit(i, j, id, nt["default86"])
	elseif g5 == g8 and g5 ~= g2 and g5 == g4 and g5 ~= g6 then self:edit(i, j, id, nt["default84"])
	elseif g5 ~= g8 and g5 == g2 and g5 == g4 and g5 ~= g6 then self:edit(i, j, id, nt["default24"])
	elseif g5 ~= g8 and g5 == g2 and g5 ~= g4 and g5 == g6 then self:edit(i, j, id, nt["default26"])

	-- Main
	elseif g5 == g8 and g5 == g2 then self:edit(i, j, id, nt["default82"])
	elseif g5 == g4 and g5 == g6 then self:edit(i, j, id, nt["default46"])

	-- Ends
	elseif g5 == g4 and g5 ~= g6 then self:edit(i, j, id, nt["default4"])
	elseif g5 ~= g4 and g5 == g6 then self:edit(i, j, id, nt["default6"])
	elseif g5 == g2 and g5 ~= g8 then self:edit(i, j, id, nt["default2"])
	elseif g5 ~= g2 and g5 == g8 then self:edit(i, j, id, nt["default8"])

	end
end

function _M:editTileRoads_def(level, i, j, g, nt)
	self:editTileGenericRoad(level, i, j, g, defs[nt.def], defs[nt.def].type or "defaultroad")
end


-- This array is precomputed, it holds the possible combinations of walls and the nice tile they generate
-- The data is bit-encoded
local full_wall3d = {
	[0x00000000] = 'pillar',
	[0x000001e4] = 'wall1',
	[0x000001e8] = 'wall2',
	[0x000001ec] = 'wall2',
	[0x00000002] = 'pillar8',
	[0x00000008] = 'pillar6',
	[0x00000020] = 'pillar4',
	[0x00000080] = 'pillar2',
	[0x00000082] = 'pillar82',
	[0x0000008a] = 'wall6',
	[0x00000009] = 'pillar6',
	[0x0000008e] = 'wall6',
	[0x00000126] = 'wall7',
	[0x000001a9] = 'wall2',
	[0x000001ad] = 'wall2',
	[0x00000027] = 'wall7',
	[0x00000028] = 'pillar46',
	[0x000000a2] = 'wall4',
	[0x0000002a] = 'wall8',
	[0x000000a8] = 'wall2',
	[0x0000002b] = 'wall8',
	[0x000000ac] = 'wall2',
	[0x000001e9] = 'wall2',
	[0x000001ed] = 'wall2',
	[0x0000002f] = 'wall8',
	[0x000000c0] = 'pillar2',
	[0x0000018a] = 'wall6',
	[0x0000018e] = 'wall6',
	[0x000000ca] = 'wall6',
	[0x000000ce] = 'wall6',
	[0x000001a2] = 'wall4',
	[0x000001a6] = 'wall4',
	[0x0000012b] = 'wall8',
	[0x0000012f] = 'wall8',
	[0x000000e2] = 'wall4',
	[0x000000e6] = 'wall4',
	[0x000000e8] = 'wall2',
	[0x000000ec] = 'wall2',
	[0x00000003] = 'pillar8',
	[0x0000016e] = 'wall8',
	[0x000001e2] = 'wall4',
	[0x000001e6] = 'wall4',
	[0x0000016b] = 'wall8',
	[0x0000016f] = 'wall8',
	[0x0000000b] = 'wall9',
	[0x0000000f] = 'wall9',
	[0x00000124] = 'pillar4',
	[0x0000004b] = 'wall9',
	[0x000001ee] = 'inner_wall9',
	[0x000001e0] = 'wall1',
	[0x0000018b] = 'wall6',
	[0x0000018f] = 'wall6',
	[0x0000008b] = 'wall6',
	[0x000001ca] = 'wall6',
	[0x0000008f] = 'wall6',
	[0x00000049] = 'pillar6',
	[0x000001a3] = 'wall4',
	[0x000001a7] = 'wall4',
	[0x000001a4] = 'wall1',
	[0x000001af] = 'inner_wall3',
	[0x000000a6] = 'wall4',
	[0x0000004f] = 'wall9',
	[0x00000120] = 'pillar4',
	[0x00000024] = 'pillar4',
	[0x000000a3] = 'wall4',
	[0x000000c8] = 'wall3',
	[0x000001cb] = 'wall6',
	[0x000000a9] = 'wall2',
	[0x0000012a] = 'wall8',
	[0x000000ad] = 'wall2',
	[0x000001c9] = 'wall3',
	[0x0000012e] = 'wall8',
	[0x000001e3] = 'wall4',
	[0x000001e7] = 'wall4',
	[0x000001eb] = 'inner_wall7',
	[0x000001ef] = 'base',
	[0x00000006] = 'pillar8',
	[0x00000048] = 'pillar6',
	[0x00000007] = 'pillar8',
	[0x00000180] = 'pillar2',
	[0x00000026] = 'wall7',
	[0x00000127] = 'wall7',
	[0x000001cf] = 'wall6',
	[0x000000c9] = 'wall3',
	[0x000000cb] = 'wall6',
	[0x0000002e] = 'wall8',
	[0x000000cf] = 'wall6',
	[0x000001a0] = 'wall1',
	[0x0000006a] = 'wall8',
	[0x0000006b] = 'wall8',
	[0x000001ac] = 'wall2',
	[0x000001ce] = 'wall6',
	[0x0000006e] = 'wall8',
	[0x0000006f] = 'wall8',
	[0x0000016a] = 'wall8',
	[0x000001c0] = 'pillar2',
	[0x000000e3] = 'wall4',
	[0x000001c8] = 'wall3',
	[0x000000e7] = 'wall4',
	[0x000000e9] = 'wall2',
	[0x000001a8] = 'wall2',
	[0x000000ed] = 'wall2',
	[0x000000ef] = 'inner_wall1',
	[0x000000a7] = 'wall4',
}

--- Make walls have a pseudo 3D effect
function _M:niceTileMountain3d(level, i, j, g, nt)
	local s = level.map:checkEntity(i, j, Map.TERRAIN, "type") or "wall"
	local g1 = level.map:checkEntity(i-1, j+1, Map.TERRAIN, "type") == s and 1 or 0
	local g2 = level.map:checkEntity(i, j+1, Map.TERRAIN, "type")   == s and 2 or 0
	local g3 = level.map:checkEntity(i+1, j+1, Map.TERRAIN, "type") == s and 4 or 0
	local g4 = level.map:checkEntity(i-1, j, Map.TERRAIN, "type")   == s and 8 or 0
	local g6 = level.map:checkEntity(i+1, j, Map.TERRAIN, "type")   == s and 32 or 0
	local g7 = level.map:checkEntity(i-1, j-1, Map.TERRAIN, "type") == s and 64 or 0
	local g8 = level.map:checkEntity(i, j-1, Map.TERRAIN, "type")   == s and 128 or 0
	local g9 = level.map:checkEntity(i+1, j-1, Map.TERRAIN, "type") == s and 256 or 0

	-- We compute a single number whose 9 first bits represent the walls
	local v = bit.bor(g1, g2, g3, g4, g6, g7, g8, g9)
	if full_wall3d[v] then self:replace(i, j, self:getTile(nt[full_wall3d[v]])) end
end


--------------------------------------------------------------------------
-- Uncommand to use: the generator for the predefined wall indices
--------------------------------------------------------------------------
--[=[
local names = {
-- Full
[ [[
111
1 1
111]] ] = "base",

-- Borders
[ [[
*0*
1 1
*1*]] ] = "wall8",

[ [[
*1*
1 1
*0*]] ] = "wall2",

[ [[
*1*
0 1
*1*]] ] = "wall4",

[ [[
*1*
1 0
*1*]] ] = "wall6",

-- Corners
[ [[
11*
1 0
*00]] ] = "wall3",

[ [[
00*
0 1
*11]] ] = "wall7",

[ [[
*11
0 1
00*]] ] = "wall1",

[ [[
*00
1 0
11*]] ] = "wall9",

-- Inner walls
[ [[
111
1 1
110]] ] = "inner_wall7",

[ [[
011
1 1
111]] ] = "inner_wall3",

[ [[
110
1 1
111]] ] = "inner_wall1",

[ [[
111
1 1
011]] ] = "inner_wall9",


-- Pillar
[ [[
000
0 0
000]] ] = "pillar",


-- Smalls
[ [[
00*
0 1
00*]] ] = 'pillar4',
[ [[
000
1 1
000]] ] = 'pillar46',
[ [[
*00
1 0
*00]] ] = 'pillar6',
[ [[
000
0 0
*1*]] ] = 'pillar8',
[ [[
010
0 0
010]] ] = 'pillar82',
[ [[
*1*
0 0
000]] ] = 'pillar2',

}

local function bitprint(v)
	local r = ""
	for i = 1, 16 do
		if bit.band(v, bit.lshift(1, i-1)) ~= 0 then r = r.."1" else r = r.."0" end
	end
	return r
end

local res = {}
string.get = function(self, x) return self:sub(x,x) end
local function strssub(str, x, c)
	return str:sub(1,x-1)..c..str:sub(x+1)
end

local function run(names)
	for test, name in pairs(names) do
		repeat
		local v = 0
		local dont = false
		if test:get(1) == "1" then v = bit.bor(v, bit.lshift(1, 7-1))
		elseif test:get(1) == "*" then run{[strssub(test, 1, "1")]=name, [strssub(test, 1, "0")]=name} dont=true end
		if test:get(2) == "1" then v = bit.bor(v, bit.lshift(1, 8-1))
		elseif test:get(2) == "*" then run{[strssub(test, 2, "1")]=name, [strssub(test, 2, "0")]=name} dont=true end
		if test:get(3) == "1" then v = bit.bor(v, bit.lshift(1, 9-1))
		elseif test:get(3) == "*" then run{[strssub(test, 3, "1")]=name, [strssub(test, 3, "0")]=name} dont=true end
		if test:get(5) == "1" then v = bit.bor(v, bit.lshift(1, 4-1))
		elseif test:get(5) == "*" then run{[strssub(test, 5, "1")]=name, [strssub(test, 5, "0")]=name} dont=true end
		if test:get(7) == "1" then v = bit.bor(v, bit.lshift(1, 6-1))
		elseif test:get(7) == "*" then run{[strssub(test, 7, "1")]=name, [strssub(test, 7, "0")]=name} dont=true end
		if test:get(9) == "1" then v = bit.bor(v, bit.lshift(1, 1-1))
		elseif test:get(9) == "*" then run{[strssub(test, 9, "1")]=name, [strssub(test, 9, "0")]=name} dont=true end
		if test:get(10) == "1" then v = bit.bor(v, bit.lshift(1, 2-1))
		elseif test:get(10) == "*" then run{[strssub(test, 10, "1")]=name, [strssub(test, 10, "0")]=name} dont=true end
		if test:get(11) == "1" then v = bit.bor(v, bit.lshift(1, 3-1))
		elseif test:get(11) == "*" then run{[strssub(test, 11, "1")]=name, [strssub(test, 11, "0")]=name} dont=true end

		if not dont then
			res[v] = name
		end
		until true
	end
end

run(names)


for v, name in pairs(res) do
--	print(name,"=>", bitprint(v))
	print(("	[0x%s] = '%s',"):format(bit.tohex(v), name))
end
--os.exit()
]=]
