

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>
#include <ctype.h>

#include <lua.h>
#include <lauxlib.h>

#include <zmq.h>

int raise_zmq_errno(lua_State *L)
{
    return luaL_error(L, zmq_strerror(zmq_errno()));
}

int l_zmq_ctx_new(lua_State *L)
{
    void *ctx = zmq_ctx_new();
    lua_pushlightuserdata(L, ctx);
    return 1;
}

int l_zmq_ctx_shutdown(lua_State *L)
{
    void *ctx = lua_touserdata(L, 1);
    int flag = zmq_ctx_shutdown(ctx);

    if (flag)
        raise_zmq_errno(L);

    return 0;
}

int l_zmq_ctx_term(lua_State *L)
{
    void *ctx = lua_touserdata(L, 1);
    int flag = zmq_ctx_term(ctx);

    if (flag)
        raise_zmq_errno(L);

    return 0;
}

int l_zmq_socket(lua_State *L)
{
    void *ptr = lua_touserdata(L, 1);
    lua_Integer type_ = luaL_checkinteger(L, 2);

    void *socket = zmq_socket(ptr, type_);

    if (socket == NULL)
        raise_zmq_errno(L);

    lua_pushlightuserdata(L, socket);

    return 1;
}

int l_zmq_close(lua_State *L)
{
    void *socket = lua_touserdata(L, 1);

    int error_flag = zmq_close(socket);

    if (error_flag)
        raise_zmq_errno(L);

    return 0;
}

int l_zmq_bind(lua_State *L)
{
    void *socket = lua_touserdata(L, 1);
    const char *endpoint = luaL_checkstring(L, 2);

    int error_flag = zmq_bind(socket, endpoint);

    if (error_flag)
        raise_zmq_errno(L);

    return 0;
}

int l_zmq_connect(lua_State *L)
{
    void *socket = lua_touserdata(L, 1);
    const char *endpoint = luaL_checkstring(L, 2);

    int error_flag = zmq_connect(socket, endpoint);

    if (error_flag)
        raise_zmq_errno(L);

    return 0;
}

int l_zmq_recv(lua_State *L)
{
    void *socket = lua_touserdata(L, 1);
    lua_Integer size = luaL_checkinteger(L, 2);
    int flags = luaL_checkinteger(L, 3);

    char *buffer = (char *)malloc(size);

    int n = zmq_recv(socket, buffer, size, flags);

    if (n == -1)
    {
        free(buffer);
        raise_zmq_errno(L);
    }

    lua_pushlstring(L, buffer, n > size ? size : n);

    free(buffer);

    return 1;
}


int l_zmq_send(lua_State *L)
{
    void *socket = lua_touserdata(L, 1);
    size_t size;
    const char* str = luaL_checklstring(L, 2, &size);
    int flags = luaL_checkinteger(L, 3);

    int n = zmq_send(socket, str, size, flags);

    if (n == -1)
    {
        raise_zmq_errno(L);
    }

    lua_pushinteger(L, n);

    return 1;
}

const struct luaL_Reg libluazmq[] = {
    {"ctx_new", l_zmq_ctx_new},
    {"ctx_shutdown", l_zmq_ctx_shutdown},
    {"ctx_term", l_zmq_ctx_term},
    {"zmq_socket", l_zmq_socket},
    {"zmq_close", l_zmq_close},
    {"zmq_bind", l_zmq_bind},
    {"zmq_connect", l_zmq_connect},
    {"zmq_recv", l_zmq_recv},
    {"zmq_send", l_zmq_send},
    {NULL, NULL} /* sentinel */
};

void push_C_table(lua_State *L)
{
    lua_newtable(L);

    lua_pushlightuserdata(L, NULL);
    lua_setfield(L, -2, "NULL");

    lua_setfield(L, -2, "C");
}

void push_socket_types_table(lua_State *L)
{
    lua_pushinteger(L, ZMQ_PAIR);
    lua_setfield(L, -2, "PAIR");

    lua_pushinteger(L, ZMQ_PUB);
    lua_setfield(L, -2, "PUB");

    lua_pushinteger(L, ZMQ_SUB);
    lua_setfield(L, -2, "SUB");

    lua_pushinteger(L, ZMQ_REQ);
    lua_setfield(L, -2, "REQ");

    lua_pushinteger(L, ZMQ_REP);
    lua_setfield(L, -2, "REP");

    lua_pushinteger(L, ZMQ_DEALER);
    lua_setfield(L, -2, "DEALER");

    lua_pushinteger(L, ZMQ_ROUTER);
    lua_setfield(L, -2, "ROUTER");

    lua_pushinteger(L, ZMQ_PULL);
    lua_setfield(L, -2, "PULL");

    lua_pushinteger(L, ZMQ_PUSH);
    lua_setfield(L, -2, "PUSH");

    lua_pushinteger(L, ZMQ_XPUB);
    lua_setfield(L, -2, "XPUB");

    lua_pushinteger(L, ZMQ_XSUB);
    lua_setfield(L, -2, "XSUB");

    lua_pushinteger(L, ZMQ_STREAM);
    lua_setfield(L, -2, "STREAM");

    lua_pushinteger(L, ZMQ_XREQ);
    lua_setfield(L, -2, "XREQ");

    lua_pushinteger(L, ZMQ_XREP);
    lua_setfield(L, -2, "XREP");
}

int luaopen_libluazmq(lua_State *L) // the initialization function of the module.
{
    luaL_newlib(L, libluazmq);

    push_C_table(L);
    push_socket_types_table(L);

    return 1;
}