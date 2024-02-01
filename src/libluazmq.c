

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>
#include <ctype.h>

#include <lua.h>
#include <lauxlib.h>

#include <zmq.h>

int a (lua_State *L) {
    printf("a\n");
    return 0;
}

const struct luaL_Reg libluazmq[] = {
    {"a", a},
    {NULL, NULL} /* sentinel */
};

int luaopen_libluazmq(lua_State *L) // the initialization function of the module.
{
    luaL_newlib(L, libluazmq);

    return 1;
}