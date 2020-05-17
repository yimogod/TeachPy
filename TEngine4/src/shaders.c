/*
    TE4 - T-Engine 4
    Copyright (C) 2009 - 2018 Nicolas Casalini

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Nicolas Casalini "DarkGod"
    darkgod@te4.org
*/
#include "display.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "types.h"
#include "script.h"
#include "useshader.h"
#include "main.h"
#include "shaders.h"
#include "libtcod.h"

bool shaders_active = TRUE;

void useShader(shader_type *p, int x, int y, int w, int h, float tx, float ty, float tw, float th, float r, float g, float b, float a)
{
	tglUseProgramObject(p->shader);
	GLfloat t = cur_frame_tick;
	glUniform1fvARB(p->p_tick, 1, &t);
	GLfloat d[4];
	d[0] = r;
	d[1] = g;
	d[2] = b;
	d[3] = a;
	glUniform4fvARB(p->p_color, 1, d);

	GLfloat c[2];
	c[0] = x;
	c[1] = y;
	glUniform2fvARB(p->p_mapcoord, 1, c);

	c[0] = w;
	c[1] = h;
	glUniform2fvARB(p->p_texsize, 1, c);

	d[0] = tx;
	d[1] = ty;
	d[2] = tw;
	d[3] = th;
	glUniform4fvARB(p->p_texcoord, 1, d);

	shader_reset_uniform *ru = p->reset_uniforms;
	while (ru) {
		switch (ru->kind) {
			case UNIFORM_NUMBER:
				glUniform1fvARB(ru->p, 1, &ru->data.number);
				break;
			case UNIFORM_VEC2:
				glUniform2fvARB(ru->p, 1, ru->data.vec2);
				break;
			case UNIFORM_VEC3:
				glUniform3fvARB(ru->p, 1, ru->data.vec3);
				break;
			case UNIFORM_VEC4:
				glUniform4fvARB(ru->p, 1, ru->data.vec4);
				break;
		}
		ru = ru->next;
	}
}

static GLuint loadShader(const char* code, GLuint type)
{
	GLuint v = glCreateShaderObjectARB(type);
	glShaderSourceARB(v, 1, &code, 0);
	glCompileShaderARB(v);
	CHECKGLSLCOMPILE(v, "inline");
	printf("New GL Shader %d of type %d\n", v, type);
	return v;
}

static int shader_new(lua_State *L)
{
	if (!shaders_active) return 0;
	const char *code = luaL_checkstring(L, 1);
	bool vertex = lua_toboolean(L, 2);

	GLuint *s = (GLuint*)lua_newuserdata(L, sizeof(GLuint));
	auxiliar_setclass(L, "gl{shader}", -1);

	*s = loadShader(code, vertex ? GL_VERTEX_SHADER : GL_FRAGMENT_SHADER);

	return 1;
}

static int shader_free(lua_State *L)
{
	GLuint *s = (GLuint*)auxiliar_checkclass(L, "gl{shader}", 1);

	glDeleteObjectARB(*s);

	lua_pushnumber(L, 1);
	return 1;
}

static int program_new(lua_State *L)
{
	if (!shaders_active) return 0;

	shader_type *p = (shader_type*)lua_newuserdata(L, sizeof(shader_type));
	auxiliar_setclass(L, "gl{program}", -1);

	p->shader = glCreateProgramObjectARB();
	p->reset_uniforms = NULL;
	p->clone = FALSE;

	printf("New GL Shader program %d\n", p->shader);

	return 1;
}

static int program_free(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);

	printf("Deleting shader %d (is clone %d)\n", p->shader, p->clone);
	if (!p->clone) glDeleteObjectARB(p->shader);

	while (p->reset_uniforms) {
		shader_reset_uniform *ru = p->reset_uniforms;
		p->reset_uniforms = p->reset_uniforms->next;
		free(ru);
	}

	lua_pushnumber(L, 1);
	return 1;
}

static int program_remove_resets(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);

	while (p->reset_uniforms) {
		shader_reset_uniform *ru = p->reset_uniforms;
		p->reset_uniforms = p->reset_uniforms->next;
		free(ru);
	}

	return 0;
}

static int program_attach(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	GLuint *s = (GLuint*)auxiliar_checkclass(L, "gl{shader}", 2);

	glAttachObjectARB(p->shader, *s);

	return 0;
}

static int program_detach(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	GLuint *s = (GLuint*)auxiliar_checkclass(L, "gl{shader}", 2);

	glDetachObjectARB(p->shader, *s);

	return 0;
}

static int program_clone(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);

	shader_type *np = (shader_type*)lua_newuserdata(L, sizeof(shader_type)); // 2
	auxiliar_setclass(L, "gl{program}", -1);

	np->clone = TRUE;
	np->shader = p->shader;
	np->p_tick = p->p_tick;
	np->p_color = p->p_color;
	np->p_mapcoord = p->p_mapcoord;
	np->p_texsize = p->p_texsize;
	np->p_texcoord = p->p_texcoord;
	np->reset_uniforms = NULL;

	lua_getmetatable(L, 1); // 3
	lua_newtable(L); // 4

	// Iterate old table and copy to new table
	lua_pushnil(L);
	while (lua_next(L, 3) != 0) {
		lua_pushvalue(L, -2);
		lua_pushvalue(L, -2);
		lua_rawset(L, 4);
		lua_pop(L, 1);
	}

	// Capture a reference to the parent so it is not GC'ed before us
	lua_pushstring(L, "_parent_clone");
	lua_pushvalue(L, 1);
	lua_rawset(L, 4);

	lua_setmetatable(L, 2);
	lua_pop(L, 1);

	printf("Cloned shader %d\n", p->shader);

	return 1;
}

static int program_set_uniform_number(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	const char *var = luaL_checkstring(L, 2);
	bool change = gl_c_shader != p->shader;

	if (change) tglUseProgramObject(p->shader);

	// Uniform array
	if (lua_istable(L, 3)) {
		int nb = lua_objlen(L, 3);
		int i;
		GLfloat is[nb];
		for (i = 0; i < nb; i++) {
			lua_rawgeti(L, 3, i + 1); is[i*4+0] = lua_tonumber(L, -1); lua_pop(L, 1);
		}
		glUniform1fvARB(glGetUniformLocationARB(p->shader, var), nb, is);
	} else {
		GLfloat i = luaL_checknumber(L, 3);
		glUniform1fvARB(glGetUniformLocationARB(p->shader, var), 1, &i);
	}

	if (change) tglUseProgramObject(0);
	return 0;
}

static int program_set_uniform_number2(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	const char *var = luaL_checkstring(L, 2);
	bool change = gl_c_shader != p->shader;

	if (change) tglUseProgramObject(p->shader);

	// Uniform array
	if (lua_istable(L, 3)) {
		int nb = lua_objlen(L, 3);
		int i;
		GLfloat is[2*nb];
		for (i = 0; i < nb; i++) {
			lua_rawgeti(L, 3, i + 1);
			lua_rawgeti(L, -1, 1); is[i*2+0] = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_rawgeti(L, -1, 2); is[i*2+1] = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pop(L, 1);
		}
		glUniform2fvARB(glGetUniformLocationARB(p->shader, var), nb, is);
	} else {
		GLfloat i[2];
		i[0] = luaL_checknumber(L, 3);
		i[1] = luaL_checknumber(L, 4);

		glUniform2fvARB(glGetUniformLocationARB(p->shader, var), 1, i);
	}
	if (change) tglUseProgramObject(0);
	return 0;
}

static int program_set_uniform_number3(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	const char *var = luaL_checkstring(L, 2);
	bool change = gl_c_shader != p->shader;
	if (change) tglUseProgramObject(p->shader);

	// Uniform array
	if (lua_istable(L, 3)) {
		int nb = lua_objlen(L, 3);
		int i;
		GLfloat is[3*nb];
		for (i = 0; i < nb; i++) {
			lua_rawgeti(L, 3, i + 1);
			lua_rawgeti(L, -1, 1); is[i*3+0] = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_rawgeti(L, -1, 2); is[i*3+1] = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_rawgeti(L, -1, 3); is[i*3+2] = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pop(L, 1);
		}
		glUniform3fvARB(glGetUniformLocationARB(p->shader, var), nb, is);
	} else {
		GLfloat i[3];
		i[0] = luaL_checknumber(L, 3);
		i[1] = luaL_checknumber(L, 4);
		i[2] = luaL_checknumber(L, 5);

		glUniform3fvARB(glGetUniformLocationARB(p->shader, var), 1, i);
	}

	if (change) tglUseProgramObject(0);
	return 0;
}

static int program_set_uniform_number4(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	const char *var = luaL_checkstring(L, 2);
	bool change = gl_c_shader != p->shader;

	if (change) tglUseProgramObject(p->shader);

	// Uniform array
	if (lua_istable(L, 3)) {
		int nb = lua_objlen(L, 3);
		int i;
		GLfloat is[4*nb];
		for (i = 0; i < nb; i++) {
			lua_rawgeti(L, 3, i + 1);
			lua_rawgeti(L, -1, 1); is[i*4+0] = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_rawgeti(L, -1, 2); is[i*4+1] = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_rawgeti(L, -1, 3); is[i*4+2] = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_rawgeti(L, -1, 4); is[i*4+3] = lua_tonumber(L, -1); lua_pop(L, 1);
			lua_pop(L, 1);
		}
		glUniform4fvARB(glGetUniformLocationARB(p->shader, var), nb, is);
	} else {
		GLfloat i[4];
		i[0] = luaL_checknumber(L, 3);
		i[1] = luaL_checknumber(L, 4);
		i[2] = luaL_checknumber(L, 5);
		i[3] = luaL_checknumber(L, 6);

		glUniform4fvARB(glGetUniformLocationARB(p->shader, var), 1, i);
	}

	if (change) tglUseProgramObject(0);
	return 0;
}

static int program_reset_uniform_number(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	const char *var = luaL_checkstring(L, 2);
	
	shader_reset_uniform *ru = malloc(sizeof(shader_reset_uniform));
	ru->next = p->reset_uniforms;
	p->reset_uniforms = ru;
	ru->p = glGetUniformLocationARB(p->shader, var);
	ru->kind = UNIFORM_NUMBER;
	ru->data.number = luaL_checknumber(L, 3);
	return 0;
}

static int program_reset_uniform_number2(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	const char *var = luaL_checkstring(L, 2);

	shader_reset_uniform *ru = malloc(sizeof(shader_reset_uniform));
	ru->next = p->reset_uniforms;
	p->reset_uniforms = ru;
	ru->p = glGetUniformLocationARB(p->shader, var);
	ru->kind = UNIFORM_VEC2;
	ru->data.vec2[0] = luaL_checknumber(L, 3);
	ru->data.vec2[1] = luaL_checknumber(L, 4);
	return 0;
}

static int program_reset_uniform_number3(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	const char *var = luaL_checkstring(L, 2);

	shader_reset_uniform *ru = malloc(sizeof(shader_reset_uniform));
	ru->next = p->reset_uniforms;
	p->reset_uniforms = ru;
	ru->p = glGetUniformLocationARB(p->shader, var);
	ru->kind = UNIFORM_VEC3;
	ru->data.vec3[0] = luaL_checknumber(L, 3);
	ru->data.vec3[1] = luaL_checknumber(L, 4);
	ru->data.vec3[2] = luaL_checknumber(L, 5);
	return 0;
}

static int program_reset_uniform_number4(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	const char *var = luaL_checkstring(L, 2);

	shader_reset_uniform *ru = malloc(sizeof(shader_reset_uniform));
	ru->next = p->reset_uniforms;
	p->reset_uniforms = ru;
	ru->p = glGetUniformLocationARB(p->shader, var);
	ru->kind = UNIFORM_VEC4;
	ru->data.vec4[0] = luaL_checknumber(L, 3);
	ru->data.vec4[1] = luaL_checknumber(L, 4);
	ru->data.vec4[2] = luaL_checknumber(L, 5);
	ru->data.vec4[3] = luaL_checknumber(L, 6);
	return 0;
}

static int program_set_uniform_texture(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	const char *var = luaL_checkstring(L, 2);
	GLint i = luaL_checknumber(L, 3);

	bool change = gl_c_shader != p->shader;

	if (change) tglUseProgramObject(p->shader);
	glUniform1ivARB(glGetUniformLocationARB(p->shader, var), 1, &i);
	if (change) tglUseProgramObject(0);
	return 0;
}

static int program_set_uniform_number_fast(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	GLfloat i = luaL_checknumber(L, 2);
	bool change = gl_c_shader != p->shader;

	GLint pos = lua_tonumber(L, lua_upvalueindex(1));

	if (change) tglUseProgramObject(p->shader);
	glUniform1fvARB(pos, 1, &i);
	if (change) tglUseProgramObject(0);
	return 0;
}

static int program_set_uniform_number2_fast(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	GLfloat i[2];
	i[0] = luaL_checknumber(L, 2);
	i[1] = luaL_checknumber(L, 3);

	bool change = gl_c_shader != p->shader;

	GLint pos = lua_tonumber(L, lua_upvalueindex(1));

	if (change) tglUseProgramObject(p->shader);
	glUniform2fvARB(pos, 1, i);
	if (change) tglUseProgramObject(0);
	return 0;
}

static int program_set_uniform_number3_fast(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	GLfloat i[3];
	i[0] = luaL_checknumber(L, 2);
	i[1] = luaL_checknumber(L, 3);
	i[2] = luaL_checknumber(L, 4);

	bool change = gl_c_shader != p->shader;

	GLint pos = lua_tonumber(L, lua_upvalueindex(1));

	if (change) tglUseProgramObject(p->shader);
	glUniform2fvARB(pos, 1, i);
	if (change) tglUseProgramObject(0);
	return 0;
}

static int program_set_uniform_number4_fast(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	GLfloat i[4];
	i[0] = luaL_checknumber(L, 2);
	i[1] = luaL_checknumber(L, 3);
	i[2] = luaL_checknumber(L, 4);
	i[3] = luaL_checknumber(L, 5);

	bool change = gl_c_shader != p->shader;

	GLint pos = lua_tonumber(L, lua_upvalueindex(1));

	if (change) tglUseProgramObject(p->shader);
	glUniform2fvARB(pos, 1, i);
	if (change) tglUseProgramObject(0);
	return 0;
}

static int program_set_uniform_texture_fast(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	GLint i = luaL_checknumber(L, 2);

	bool change = gl_c_shader != p->shader;

	GLint pos = lua_tonumber(L, lua_upvalueindex(1));

	if (change) tglUseProgramObject(p->shader);
	glUniform1ivARB(pos, 1, &i);
	if (change) tglUseProgramObject(0);
	return 0;
}

static int program_compile(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);

	glLinkProgramARB(p->shader);
	CHECKGLSLLINK(p->shader);

	CHECKGLSLVALID(p->shader);

	char buffer[256];
	int count;
	int dummysize;
	int length;
	GLenum dummytype;

	// New metatable -- stack index 2
	lua_newtable(L);

	// Add GC method
	lua_pushstring(L, "__gc");
	lua_pushcfunction(L, program_free);
	lua_rawset(L, -3);
	
	// New Index -- stack index 4
	lua_pushstring(L, "__index");
	lua_newtable(L);

	// Grab current index table -- stack index 5
	lua_getmetatable(L, 1);
	lua_pushstring(L, "__index");
	lua_rawget(L, -2);
	lua_remove(L, -2);

	// Iterate old index table and copy to new table
	lua_pushnil(L);
	while (lua_next(L, 5) != 0) {
		lua_pushvalue(L, -2);
		lua_pushvalue(L, -2);
		lua_rawset(L, 4);
		lua_pop(L, 1);
	}

	// Pop the old index
	lua_pop(L, 1);

	glGetObjectParameterivARB(p->shader, GL_ACTIVE_UNIFORMS, &count);
	int i;
	for(i = 0; i<count;++i)
	{
		GLint uniLoc;
		glGetActiveUniformARB(p->shader, i, 256, &length, &dummysize, &dummytype, buffer);
		uniLoc = glGetUniformLocationARB(p->shader, buffer);
		if(uniLoc>=0)	// Test for valid uniform location
		{
			printf("*p %i: Uniform: %i: %X %s\n", p->shader,uniLoc, dummytype, buffer);
			// Add a C closure to define the uniform
			if (dummytype == GL_FLOAT) {
				// Compute the name
				lua_pushstring(L, "uni");
				buffer[0] = toupper(buffer[0]);
				lua_pushstring(L, buffer);
				lua_concat(L, 2);
				// Push a closure with the uniform location
				lua_pushnumber(L, uniLoc);
				lua_pushcclosure(L, program_set_uniform_number_fast, 1);
				// Set it in the index table
				lua_rawset(L, 4);
			} else if (dummytype == GL_FLOAT_VEC2) {
				// Compute the name
				lua_pushstring(L, "uni");
				buffer[0] = toupper(buffer[0]);
				lua_pushstring(L, buffer);
				lua_concat(L, 2);
				// Push a closure with the uniform location
				lua_pushnumber(L, uniLoc);
				lua_pushcclosure(L, program_set_uniform_number2_fast, 1);
				// Set it in the index table
				lua_rawset(L, 4);
			} else if (dummytype == GL_FLOAT_VEC3) {
				// Compute the name
				lua_pushstring(L, "uni");
				buffer[0] = toupper(buffer[0]);
				lua_pushstring(L, buffer);
				lua_concat(L, 2);
				// Push a closure with the uniform location
				lua_pushnumber(L, uniLoc);
				lua_pushcclosure(L, program_set_uniform_number3_fast, 1);
				// Set it in the index table
				lua_rawset(L, 4);
			} else if (dummytype == GL_FLOAT_VEC4) {
				// Compute the name
				lua_pushstring(L, "uni");
				buffer[0] = toupper(buffer[0]);
				lua_pushstring(L, buffer);
				lua_concat(L, 2);
				// Push a closure with the uniform location
				lua_pushnumber(L, uniLoc);
				lua_pushcclosure(L, program_set_uniform_number4_fast, 1);
				// Set it in the index table
				lua_rawset(L, 4);
			} else if (dummytype == GL_SAMPLER_2D) {
				// Compute the name
				lua_pushstring(L, "uni");
				buffer[0] = toupper(buffer[0]);
				lua_pushstring(L, buffer);
				lua_concat(L, 2);
				// Push a closure with the uniform location
				lua_pushnumber(L, uniLoc);
				lua_pushcclosure(L, program_set_uniform_texture_fast, 1);
				// Set it in the index table
				lua_rawset(L, 4);
			}
		}
	}

	// Set the index in the metatable
	lua_rawset(L, 2);

	// Set it up (the metatable)
	lua_setmetatable(L, 1);

	p->p_tick = glGetUniformLocationARB(p->shader, "tick");
	p->p_color = glGetUniformLocationARB(p->shader, "displayColor");
	p->p_mapcoord = glGetUniformLocationARB(p->shader, "mapCoord");
	p->p_texsize = glGetUniformLocationARB(p->shader, "texSize");
	p->p_texcoord = glGetUniformLocationARB(p->shader, "texCoord");

	lua_pushboolean(L, TRUE);
	return 1;
}

static int program_use(lua_State *L)
{
	shader_type *p = (shader_type*)lua_touserdata(L, 1);
	bool active = lua_toboolean(L, 2);

	if (active)
	{
		tglUseProgramObject(p->shader);
		// GLfloat t = SDL_GetTicks();
		GLfloat t = cur_frame_tick;
		glUniform1fvARB(p->p_tick, 1, &t);
	}
	else
	{
		tglUseProgramObject(0);
	}

	return 0;
}

static int shader_is_active(lua_State *L)
{
	if (lua_isnumber(L, 1)) {
		if (lua_tonumber(L, 1) == 4) {
			lua_pushboolean(L, shaders_active && GLEW_EXT_gpu_shader4);
			return 1;
		}
	}
	lua_pushboolean(L, shaders_active);
	return 1;
}
static int shader_disable(lua_State *L)
{
	shaders_active = FALSE;
	return 0;
}

static const struct luaL_Reg shaderlib[] =
{
	{"newShader", shader_new},
	{"newProgram", program_new},
	{"active", shader_is_active},
	{"disable", shader_disable},
	{NULL, NULL},
};

static const struct luaL_Reg program_reg[] =
{
	{"__gc", program_free},
	{"clone", program_clone},
	{"compile", program_compile},
	{"attach", program_attach},
	{"detach", program_detach},
	{"paramNumber", program_set_uniform_number},
	{"paramNumber2", program_set_uniform_number2},
	{"paramNumber3", program_set_uniform_number3},
	{"paramNumber4", program_set_uniform_number4},
	{"paramTexture", program_set_uniform_texture},
	{"resetClean", program_remove_resets},
	{"resetParamNumber", program_reset_uniform_number},
	{"resetParamNumber2", program_reset_uniform_number2},
	{"resetParamNumber3", program_reset_uniform_number3},
	{"resetParamNumber4", program_reset_uniform_number4},
	{"use", program_use},
	{NULL, NULL},
};

static const struct luaL_Reg shader_reg[] =
{
	{"__gc", shader_free},
	{NULL, NULL},
};

int luaopen_shaders(lua_State *L)
{
	auxiliar_newclass(L, "gl{shader}", shader_reg);
	auxiliar_newclass(L, "gl{program}", program_reg);
	luaL_openlib(L, "core.shader", shaderlib, 0);

	lua_pop(L, 1);
	return 1;
}
