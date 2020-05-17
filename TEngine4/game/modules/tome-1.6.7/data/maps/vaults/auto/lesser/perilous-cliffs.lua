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

specialList("actor", {
   "/data/general/npcs/snow-giant.lua",
})

specialList("terrain", {
	"/data/general/grids/mountain.lua",
})

rotates = {"default", "90", "180", "270", "flipx", "flipy"}

defineTile('#', "HARDMOUNTAIN_WALL")
defineTile('.', "ROCKY_GROUND")
defineTile('v', "CLIFFSIDE")
defineTile('!', "DOOR_VAULT")

defineTile('$', "ROCKY_GROUND", {random_filter={add_levels=20, type="money"}})

defineTile('T', "ROCKY_GROUND", {random_filter={add_levels=5, tome_mod="gvault"}}, {random_filter={add_levels=8, name = "snow giant thunderer"}} )
defineTile('G', "ROCKY_GROUND", nil, {random_filter={add_levels=5, name = "snow giant boulder thrower"}} )

return {
 [[###########]],
 [[#.........#]],
 [[#.vvvvvvv.#]],
 [[#.v.....v.#]],
 [[#.v.vGT.v.#]],
 [[#.v.v$G.v.#]],
 [[#.v.vvvvv.#]],
 [[#.v.......#]],
 [[#!#########]],
}
