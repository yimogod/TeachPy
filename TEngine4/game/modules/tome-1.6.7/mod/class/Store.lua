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
local Store = require "engine.Store"
local Dialog = require "engine.ui.Dialog"

module(..., package.seeall, class.inherit(Store))

_M.stores_def = {}

function _M:loadStores(f)
	self:loadList(f, nil, self.stores_def)
end

function _M:init(t, no_default)
	t.store.buy_percent = t.store.buy_percent or function(self, o) if o.type == "gem" then return 40 else return 5 end end
	t.store.sell_percent = t.store.sell_percent or function(self, o) -- Store prices goes up with item level
			return mod.class.interface.Combat:combatTalentScale(math.max(1, o.__store_level or 1), 123, 135, "log") 
		end
	t.store.nb_fill = t.store.nb_fill or 10
	t.store.purse = t.store.purse or 20
	Store.init(self, t, no_default)
--	self.name = self.name .. (" (Max buy %0.2f gold)"):format(self.store.purse)
	if not self.store.actor_filter then
		self.store.actor_filter = function(o)
			return not o.quest and not o.lore and o.cost and o.cost > 0
		end
	end
end

--- Called when a new object is stocked
function _M:stocked_object(o)
	o.__store_level = game.zone.base_level + game.level.level - 1
end

--- Restock based on player level
function _M:canRestock()
	local s = self.store
	if self.last_filled and self.last_filled >= game.state.stores_restock then
		print("[STORE] not restocking yet [stores_restock]", game.state.stores_restock, s.restock_every, self.last_filled)
		return false
	end
	return true
end

--- Fill the store with goods
-- @param level the level to generate for (instance of type engine.Level)
-- @param zone the zone to generate for
function _M:loadup(level, zone)
	local oldlev = zone.base_level
	local old_minml = zone.min_material_level
	local old_maxml = zone.max_material_level

	self.last_filled = self.last_filled or 0

	while self.last_filled < game.state.stores_restock do
		local lev = (game.state.stores_restock_levels and game.state.stores_restock_levels[self.last_filled]) or 8
		if zone.store_levels_by_restock then
			zone.base_level = zone.store_levels_by_restock[self.last_filled] or zone.base_level
		end

		-- Increment material level every 10 levels with a special case at level 5
		if self.store.player_material_level then
			if lev == 5 then
				zone.min_material_level = 1
				zone.max_material_level = 2
			else
				zone.max_material_level = math.min(5, math.floor(lev / 10) + 1)
				zone.min_material_level = math.max(1, zone.max_material_level - 1)
			end
		end

		-- ignore_material_levels gets priority over other systems
		if self.store.ignore_material_levels then
			zone.min_material_level = 1
			zone.max_material_level = 5
		end

		-- Engine.store.loadup sets last_filled to something silly so we have to save it
		local old_last_filled = self.last_filled
		if Store.loadup(self, level, zone, self.store.nb_fill) then
			self.last_filled = old_last_filled + 1
		end

		zone.min_material_level = old_minml
		zone.max_material_level = old_maxml
		zone.base_level = oldlev

		-- clear chrono worlds and their various effects
		if game._chronoworlds then
			game.log("#CRIMSON#Your timetravel has no effect on pre-determined outcomes such as this.")
			game._chronoworlds = nil
		end
	end
end

--- Checks if the given entity is allowed
function _M:allowStockObject(e)
	local price = self:getObjectPrice(e, "buy")
	return price > 0
end

--- Called on object purchase try
-- @param who the actor buying
-- @param o the object trying to be purchased
-- @param item the index in the inventory
-- @param nb number of items (if stacked) to buy
-- @return true if allowed to buy
function _M:tryBuy(who, o, item, nb)
	local price, nb = self:getObjectPrice(o, "buy", nb)
	if who.money >= price then
		return nb, price
	else
		Dialog:simplePopup("Not enough gold", ("You do not have the %0.2f gold needed!"):format(price))
	end
end

--- Called on object sale try
-- @param who the actor selling
-- @param o the object trying to be sold
-- @param item the index in the inventory
-- @param nb number of items (if stacked) to sell
-- @return number to sell, price if allowed to sell
function _M:trySell(who, o, item, nb)
	if o.__tagged then return end
	if nb <= 0 then return end
	local price = 0
	price, nb = self:getObjectPrice(o, "sell", nb)
	if price <= 0 then return end
	return nb, price
end

--- Called on object purchase
-- @param who the actor buying
-- @param o the object trying to be purchased
-- @param item the index in the inventory
-- @param nb number of items (if stacked) to buy
-- @param before true if this happens before removing the item
-- @return true if allowed to buy
function _M:onBuy(who, o, item, nb, before)
	if before then return end
	o:forAllStack(function(so) -- clear sales flags
		so.__force_store_forget = nil
		end)
end

--- Called on object sale
-- @param who the actor selling
-- @param o the object trying to be sold
-- @param item the index in the inventory
-- @param nb number of items (if stacked) to sell
-- @param before true if this happens before removing the item
-- @return true if allowed to sell
function _M:onSell(who, o, item, nb, before)
	if before then o:identify(true) return end
	if nb <= 0 then return end
	o:forAllStack(function(so)
		so.__price_level_mod = nil -- Greedy Merchants!
		so.__force_store_forget = true  -- Make sure this gets replaced on restock
		end)
end

--- Override the default
function _M:doBuy(who, o, item, nb, store_dialog)
	nb = math.min(nb, o:getNumber())
	local price
	nb, price = self:tryBuy(who, o, item, nb)
	if nb then
		local avg = nb > 1 and (" (%0.2f each)"):format(price/nb) or ""
		Dialog:yesnoPopup("Buy", ("Buy %d %s for %0.2f gold%s?"):format(nb, o:getName{do_color=true, no_count=true}, price, avg), function(ok) if ok then
			self:onBuy(who, o, item, nb, true)
			-- Learn lore ?
			if who.player and o.lore then
				self:removeObject(self:getInven("INVEN"), item)
				game.party:learnLore(o.lore)
			else
				self:transfer(self, who, item, nb)
				o, item = who:findInInventory(who:getInven("INVEN"), o:getName()) or o
			end
			if o then
				if who.money >= price then
					who:incMoney(- price)
					game.log("Bought: %s %s for %0.2f gold.", nb>1 and nb or "", o:getName{do_color=true, no_count = true}, price)
				end
				self:onBuy(who, o, item, nb, false)
			end
			if store_dialog then store_dialog:updateStore() end
		end end, "Buy", "Cancel")
	end
end

--- Override the default
function _M:doSell(who, o, item, nb, store_dialog)
	nb = math.min(nb, o:getNumber())
	local price
	nb, price = self:trySell(who, o, item, nb)
	if nb then
		local avg = nb > 1 and (" (%0.2f each)"):format(price/nb) or ""
		Dialog:yesnoPopup("Sell", ("Sell %d %s for %0.2f gold%s?"):format(nb, o:getName{do_color=true, no_count=true}, price, avg), function(ok) if ok then
			self:onSell(who, o, item, nb, true)
			self:transfer(who, self, item, nb)
			local o, item = self:findInInventory(self:getInven("INVEN"), o:getName()) or o
			if o then
				self:onSell(who, o, item, nb, false)
				who:incMoney(price)
				game.log("Sold: %s %s for %0.2f gold.", nb>1 and nb or "", o:getName{do_color=true, no_count = true}, price)
			end
			if store_dialog then store_dialog:updateStore() end
		end end, "Sell", "Cancel")
	end
end

--- Called to describe an object, being to sell or to buy
-- @param who the actor
-- @param what either "sell" or "buy"
-- @param o the object
-- @return a string (possibly multiline) describing the object
function _M:descObject(who, what, o)
	if what == "buy" then
		local desc = tstring({"font", "bold"}, {"color", "GOLD"}, ("Buy for: %0.2f gold (You have %0.2f gold)"):format(self:getObjectPrice(o, "buy"), who.money), {"font", "normal"}, {"color", "LAST"}, true, true)
		desc:merge(o:getDesc())
		return desc
	else
		local desc = tstring({"font", "bold"}, {"color", "GOLD"}, ("Sell for: %0.2f gold (You have %0.2f gold)"):format(self:getObjectPrice(o, "sell"), who.money), {"font", "normal"}, {"color", "LAST"}, true, true)
		desc:merge(o:getDesc())
		return desc
	end
end

--- Called to calculate the object's price for either selling or buying
-- @param o the object
-- @param what either "sell" or "buy"
-- @param nb the number from a stack (all)
-- @return the price, number to sell
function _M:getObjectPrice(o, what, nb)
	local price_limit = what == "sell" and self.store.purse or math.huge
	local price_mult = util.getval(what == "buy" and self.store.sell_percent or self.store.buy_percent, self, o) / 100 
	local price = 0
	if o.stacked then -- note transfer moves stacked objects from the top first
		nb = math.min(nb or 1, #o.stacked + 1)
		o:forAllStack(function(so, i)
			if (i or 0) > #o.stacked - nb then
				price = price + math.min(so:getPrice()*price_mult, price_limit)
			end
		end)
	else
		nb = 1
		price = math.min(o:getPrice()*price_mult, price_limit)
	end
	return math.round(price, .01), nb -- round to the nearest 0.1 gold
end

--- Called to describe an object's price, being to sell or to buy
-- @param who the actor
-- @param what either "sell" or "buy"
-- @param o the object
-- @param nb the number from a stack (all)
-- @return the price, actor.money
function _M:descObjectPrice(who, what, o, nb)
	return self:getObjectPrice(o, what, nb), who.money
end

--- Actor interacts with the store
-- @param who the actor who interacts
function _M:interact(who, name)
	-- Lore-ize me?
	if who.level < (self.store.minimum_level or 0) then 
		game.logPlayer(who, "You must be level %d to access this shop.", self.store.minimum_level or 0) 
		return
	end
	who:sortInven()
	Store.interact(self, who, name)
end
