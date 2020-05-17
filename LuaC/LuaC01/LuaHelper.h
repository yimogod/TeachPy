#pragma once
extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

class LuaHelper
{
public:
	static void stackDump(lua_State* L);
};

