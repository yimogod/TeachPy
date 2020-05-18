#include <stdio.h>
#include <iostream>

using namespace std;

extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}
#include "LuaHelper.h"

lua_State* L;

//测试堆栈
int main(int argc, char* argv[])
{
	L = luaL_newstate();

	lua_pushboolean(L, 1);
	lua_pushinteger(L, 10);
	lua_pushnil(L);
	lua_pushstring(L, "hello");
	LuaHelper::stackDump(L);


	auto result = lua_checkstack(L, 2);
	cout << "statck enougth for 2 --" << result << endl;

	auto num = lua_gettop(L);//返回栈上元素的个数
	cout << "statck num is " << num << endl;

	lua_close(L);
	/* pause */
	printf("Press enter to exit...");
	getchar();

	return 0;
}
