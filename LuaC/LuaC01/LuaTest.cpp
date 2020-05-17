#include <stdio.h>

extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

static void stackDump(lua_State* L) {
	int i;
	int top = lua_gettop(L); //获取栈上元素个数
	for (i = 1; i <= top; i++) {
		int t = lua_type(L, i);
		switch (t) {
		case LUA_TSTRING: {
			printf("'%s'", lua_tostring(L, i));
			break;
		}
		case LUA_TBOOLEAN: {
			printf(lua_toboolean(L, i) ? "true" : "false");
			break;
		}
		case LUA_TNUMBER: { //TNUMBER包含两种类型 float和integer
			if (lua_isinteger(L, i)) //integer
				printf("%lld", lua_tointeger(L, i));
			else
				printf("%g", lua_tonumber(L, i));
			break;
		}
		default: {
			printf("%s", lua_typename(L, t));
			break;
		}
			   printf("  ");
		}
		printf("\n");
	}
}

lua_State* L;

//测试堆栈
int main(int argc, char *argv[])
{
	L = luaL_newstate();

	lua_pushboolean(L, 1);
	lua_pushinteger(L, 10);
	lua_pushnil(L);
	lua_pushstring(L, "hello");
	stackDump(L);



	/* cleanup Lua */
	lua_close(L);

	/* pause */
	printf("Press enter to exit...");
	getchar();

	return 0;
}