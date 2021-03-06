local helper = require("helper.meta_helper")


local src = {}
print("src metatable is ")
print(getmetatable(src)) -- now is nil

local mt = {}
setmetatable(src, mt)
print("src metatable is ")
print(getmetatable(src)) -- now is meta1

local mt2 = {}
setmetatable(src, mt2)
print("src metatable is ")
print(getmetatable(src)) -- now is mt2


--测试meta的meta
src = {}

local mt_mt = {}
mt_mt.__index = function(table, key)
    return mt_mt[key]
end


mt = {}
mt.__index = function(table, key)
    return mt[key]
end

mt_mt.dd = 1
--mt.dd = 2

setmetatable(mt, mt_mt)
setmetatable(src, mt)


local s1 = getmetatable(src)
local s2 = getmetatable(s1)
print("src meta is ")
print(s1)

print("meta meta is ")
print(s2)

print("src dd is ")
print(src.dd)

