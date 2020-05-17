#include "LuaHelper.h"

void LuaHelper::stackDump(lua_State* L)
{
	int i;
	int top = lua_gettop(L); //��ȡջ��Ԫ�ظ���
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
		case LUA_TNUMBER: { //TNUMBER������������ float��integer
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