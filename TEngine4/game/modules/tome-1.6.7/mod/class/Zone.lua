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
local Zone = require "engine.Zone"
local Map = require "engine.Map"

module(..., package.seeall, class.inherit(Zone))

_M:enableLastPersistZones(3)

 -- retain the room map after level generation (for runPostGeneration callbacks)
_M._retain_level_room_map = true

-- object ego fields that are appended as a list when the ego is applied
-- overridden by mod.class.Object._special_ego_rules (defined here for backwards compatibility)
_M._object_special_ego_rules = {special_on_hit=true, special_on_crit=true, special_on_kill=true}

_M.update_base_level_on_enter = true -- Always update base level on zone load

-- Merge special_on_crit values.
_M:addEgoRule("object", function(dvalue, svalue, key, dst, src, rules, state)
	-- Only apply to some special fields
	local special_rule_egos = mod.class.Object._special_ego_rules or _M._object_special_ego_rules
	if not special_rule_egos[key] then return end
	-- If the special isn't a table, make it an empty one.
	if type(dvalue) ~= 'table' then dvalue = {} end
	if type(svalue) ~= 'table' then svalue = {} end
	-- If the special is a single special, wrap it to allow multiple.
	if dvalue.fct then dvalue = {dvalue} end
	if svalue.fct then svalue = {svalue} end
	-- Update
	dst[key] = dvalue
	-- Recurse with always append
	rules = table.clone(rules)
	table.insert(rules, 1, table.rules.append)
	return table.rules.recurse(dvalue, svalue, key, dst, src, rules, state)
end)

--- Called when the zone file is loaded
function _M:onLoadZoneFile(basedir)
	-- Load events if they exist
	if basedir and fs.exists(basedir.."events.lua") then
		local f = loadfile(basedir.."events.lua")
		setfenv(f, setmetatable({self=self}, {__index=_G}))
		self.events = f()

		self:triggerHook{"Zone:loadEvents", zone=self.short_name, events=self.events}
	else
		local evts = self.events or {}
		self:triggerHook{"Zone:loadEvents", zone=self.short_name, events=evts}
		if next(evts) then self.events = evts end
	end
end

--- Make it work for high levels
function _M:adjustComputeRaritiesLevel(level, type, lev)
	return 500*lev/(lev+450) -- Prevent probabilities from vanishing at high levels
end

--- Quake a zone
-- Moves randomly each grid to an other grid
function _M:doQuake(rad, x, y, check)
	local w = game.level.map.w
	local locs = {}
	local ms = {}

	core.fov.calc_circle(x, y, game.level.map.w, game.level.map.h, rad,
		function(_, lx, ly) if not game.level.map:isBound(lx, ly) then return true end end,
		function(_, tx, ty)
			if check(tx, ty) then
				locs[#locs+1] = {x=tx,y=ty}
				ms[#ms+1] = {map=game.level.map.map[tx + ty * w], attrs=game.level.map.attrs[tx + ty * w]}
			end
		end,
	nil)

	local savelocs = table.clone(locs)
	while #locs > 0 do
		local l = rng.tableRemove(locs)
		local m = rng.tableRemove(ms)

		game.level.map.map[l.x + l.y * w] = m.map
		game.level.map.attrs[l.x + l.y * w] = m.attrs
		for z, e in pairs(m.map or {}) do
			if e.move then
				e:move(l.x, l.y, true)
			end
		end
	end

	locs = savelocs
	while #locs > 0 do
		local l = rng.tableRemove(locs)
		game.nicer_tiles:updateAround(game.level, l.x, l.y)
	end

	game.level.map:cleanFOV()
	game.level.map.changed = true
	game.level.map:redisplay()
end
