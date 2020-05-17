local helper = require("helper.meta_helper")


local src = {}
print("src metatable is ")
print(getmetatable(src)) -- now is nil

local mt = {}
setmetatable(src, mt)
print("src metatable is ")
print(getmetatable(src)) -- now is nil

local mt2 = {}
setmetatable(src, mt2)
print("src metatable is ")
print(getmetatable(src)) -- now is nil

local a = helper.A
print(a)

helper.Show()

