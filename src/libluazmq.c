

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>
#include <ctype.h>

#include <lua.h>
#include <lauxlib.h>

#include <zmq.h>

int l_zmq_ctx_new(lua_State *L)
{
    void *ptr = zmq_ctx_new();
    lua_pushlightuserdata(L, ptr);
    return 1;
}

int l_zmq_ctx_term(lua_State *L)
{
    void *ptr = lua_touserdata(L, 1);
    int flag = zmq_ctx_term(ptr);
    if (flag)
        luaL_error(L, zmq_strerror(zmq_errno()));

    return 0;
}

const struct luaL_Reg libluazmq[] = {
    {"ctx_new", l_zmq_ctx_new},
    {"ctx_term", l_zmq_ctx_term},
    {NULL, NULL} /* sentinel */
};

int luaopen_libluazmq(lua_State *L) // the initialization function of the module.
{
    luaL_newlib(L, libluazmq);

    lua_newtable(L);

    lua_pushlightuserdata(L, NULL);
    lua_setfield(L, -2, "NULL");

    lua_setfield(L, -2, "C");

    return 1;
}