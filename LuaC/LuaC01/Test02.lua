print "Hello, Lua 02!"

local s = c_sub(40, 2);
print("40 - 2 =", s)

s = CLib.c_sub(40, 3);
print("40 - 3 =", s)

s = CLib.c_mul(10, 10)
print("10 x 10 = ", s)