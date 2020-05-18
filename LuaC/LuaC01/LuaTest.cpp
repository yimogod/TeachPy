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

int lua_global_add(int x, int y)
{
	int sum = 0;

	//获取方法入栈
	int t = lua_getglobal(L, "global_add");
	cout << "global_add type is " << t << endl;
	LuaHelper::stackDump(L);

	//压入参数
	lua_pushinteger(L, x);
	lua_pushinteger(L, y);
	LuaHelper::stackDump(L);

	//调用lua的方法
	//两个参数一个返回值
	//方法调用后, 把方法指针和参数都出栈, 然后结果入栈
	//如果返回的参数个数与实际不符, 会抛弃返回值或者用nil补齐
	if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
		cout << "call global_add error " << endl;
		return 0;
	}
	LuaHelper::stackDump(L);

	return sum;
}

//测试堆栈
int main(int argc, char* argv[])
{
	L = luaL_newstate();
	luaL_openlibs(L);

	cout << "----------------------测试lua的堆栈---------------------" << endl;
	lua_pushboolean(L, 1);
	lua_pushinteger(L, 10);
	lua_pushnil(L);
	lua_pushstring(L, "hello");
	LuaHelper::stackDump(L);

	//	auto result = lua_checkstack(L, 2);
	//cout << "statck enougth for 2 --" << result << endl;

	cout << "----------------------测试c调用lua---------------------" << endl;
	luaL_dofile(L, "Test.lua");
	auto sum = lua_global_add(2014, 15);
	cout << "get sum by lua is " << sum << endl;

	cout << "----------------------测试lua调用c---------------------" << endl;

	lua_close(L);
	/* pause */
	printf("Press enter to exit...");
	getchar();

	return 0;
}
