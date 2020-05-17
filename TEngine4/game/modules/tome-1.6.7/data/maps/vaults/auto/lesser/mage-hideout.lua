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

setStatusAll{no_teleport=true, no_vaulted=true}
border = 0 -- override normal vault border
roomCheck(function(room, zone, level, map)
   return resolvers.current_level <= 20
end)
specialList("actor", {
   "/data/general/npcs/skeleton.lua",
   "/data/general/npcs/troll.lua",
   "/data/general/npcs/thieve.lua",
   "/data/general/npcs/spider.lua",
   "/data/general/npcs/ghoul.lua",
})
specialList("terrain", {
   "/data/general/grids/forest.lua",
}, true)
local mobs = {
   "skeleton mage",
   "skeleton magus",
   "cave troll",
   "thief",
   "spitting spider",
   "weaver young",
   "ghast",
}
local mob = rng.tableRemove(mobs)
local Floor = data.floor or data['.'] or "GRASS"
rotates = {"default", "90", "180", "270", "flipx", "flipy"}
defineTile(',', Floor)
defineTile('#', "HARDWALL")
defineTile('X', data.wall or data['#'] or "TREE")
defineTile('+', "DOOR")
defineTile('s', Floor, nil, {random_filter={name=mob, add_levels=6}})
defineTile('$', "FLOOR", {random_filter={type="scroll", add_levels=5, ego_chance=60}}, nil)
defineTile('*', "FLOOR", {random_filter={mod="vault", add_levels=5, ego_chance=30}}, nil)
startx = 1
starty = 7

return {
[[XXXXXXXXXXX]],
[[X,,X,,,X,X,]],
[[X,X,,,,,,XX]],
[[X,X,,s####X]],
[[X,X,,,#*$#X]],
[[X,XX,,+$*#X]],
[[X,,XX,####X]],
[[X,,,XXXXXXX]],
}
