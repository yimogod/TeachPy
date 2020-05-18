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

int c_sub(lua_State* L)
{
	cout << "start invoke csub" << endl;
	LuaHelper::stackDump(L);
	int x = lua_tonumber(L, -2);
	int y = lua_tonumber(L, -1);
	int r = x - y;

	lua_pushnumber(L, r);
	LuaHelper::stackDump(L);

	return 1;
}

int c_mul(lua_State* L)
{
	cout << "start invoke c mul" << endl;
	LuaHelper::stackDump(L);
	int x = lua_tonumber(L, -2);
	int y = lua_tonumber(L, -1);
	int r = x * y;

	lua_pushnumber(L, r);
	LuaHelper::stackDump(L);

	return 1;
}

static const luaL_Reg CLib[] = {
	{"c_sub",c_sub},
	{"c_mul",c_mul	},
	{NULL,NULL}
};

int luaopen_CLib(lua_State* L) {
	luaL_newlib(L, CLib);
	return 1;
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
	luaL_dofile(L, "Test01.lua");
	auto sum = lua_global_add(2014, 15);
	cout << "get sum by lua is " << sum << endl;

	cout << "----------------------测试lua调用c---------------------" << endl;
	lua_register(L, "c_sub", c_sub);
	luaL_requiref(L, "CLib", luaopen_CLib, 1);
	luaL_dofile(L, "Test02.lua");

	cout << "----------------------测试c访问lua的变量---------------------" << endl;
	luaL_dofile(L, "Test03.lua");
	LuaHelper::stackDump(L);
	//lua_settop(L, 0);
	lua_getglobal(L, "name");
	cout << "name form lua is " << lua_tostring(L, -1) << endl;

	//c++端修改了一下名字
	lua_pushstring(L, "my name is lua modify ");
	lua_setfield(L, LUA_REGISTRYINDEX, "name");
	lua_getglobal(L, "name");
	cout << "name form lua modified is " << lua_tostring(L, -1) << endl;
	LuaHelper::stackDump(L);


	lua_getglobal(L, "nameTable");

	LuaHelper::stackDump(L);

	lua_close(L);
	/* pause */
	printf("Press enter to exit...");
	getchar();

	return 0;
}
