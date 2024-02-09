

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

    lua_pushvalue(L, 1);

    return 1;
}

int l_zmq_connect(lua_State *L)
{
    void *socket = lua_touserdata(L, 1);
    const char *endpoint = luaL_checkstring(L, 2);

    int error_flag = zmq_connect(socket, endpoint);

    if (error_flag)
        raise_zmq_errno(L);

    lua_pushvalue(L, 1);

    return 1;
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

    int v;
    size_t l = sizeof(v);

    n = zmq_getsockopt(socket, ZMQ_RCVMORE, &v, &l);

    if (n == -1)
        raise_zmq_errno(L);

    lua_pushboolean(L, v);

    return 2;
}

int l_zmq_recv_more(lua_State *L)
{
    void *socket = lua_touserdata(L, 1);
    lua_Integer size = luaL_checkinteger(L, 2);
    int flags = luaL_checkinteger(L, 3);

    char *buffer = (char *)malloc(size);

    int n, v = 1;
    size_t l = sizeof(v);

    luaL_Buffer b;

    luaL_buffinit(L, &b);

    while (v)
    {
        n = zmq_recv(socket, buffer, size, flags);

        if (n == -1)
        {
            free(buffer);
            raise_zmq_errno(L);
        }

        luaL_addlstring(&b, buffer, n > size ? size : n);

        n = zmq_getsockopt(socket, ZMQ_RCVMORE, &v, &l);

        if (n == -1)
        {
            free(buffer);
            raise_zmq_errno(L);
        }
    }

    luaL_pushresult(&b);
    free(buffer);

    return 1;
}

int l_zmq_msg_send(lua_State *L)
{
    void *socket = lua_touserdata(L, 1);
    size_t size;
    const char *str = luaL_checklstring(L, 2, &size);
    int flags = lua_type(L, 3) == LUA_TNUMBER ? luaL_checkinteger(L, 3) : 0;

    zmq_msg_t msg;
    int s = zmq_msg_init_size(&msg, size);

    if (s == -1)
    {
        raise_zmq_errno(L);
    }

    memcpy(zmq_msg_data(&msg), str, size);
    s = zmq_msg_send(&msg, socket, flags);

    zmq_msg_close(&msg);

    if (s == -1)
    {
        raise_zmq_errno(L);
    }

    if (s != size)
    {
        luaL_error(L, "zmq_msg_send: sent %d bytes instead of %d.", s, size);
    }

    lua_pushvalue(L, 1);

    return 1;
}

int l_zmq_msg_recv_more(lua_State *L)
{
    void *socket = lua_touserdata(L, 1);
    int flags = lua_type(L, 2) == LUA_TNUMBER ? luaL_checkinteger(L, 2) : 0;

    zmq_msg_t msg;

    int n, more = 1;

    luaL_Buffer b;

    luaL_buffinit(L, &b);

    while (more)
    {
        n = zmq_msg_init(&msg);

        if (n == -1)
        {
            raise_zmq_errno(L);
        }

        n = zmq_msg_recv(&msg, socket, flags);

        if (n == -1)
        {
            zmq_msg_close(&msg);
            raise_zmq_errno(L);
        }

        size_t size = zmq_msg_size(&msg);
        const char *data = zmq_msg_data(&msg);

        luaL_addlstring(&b, data, size);

        more = zmq_msg_more(&msg);
    }

    luaL_pushresult(&b);

    return 1;
}

int l_zmq_send(lua_State *L)
{
    void *socket = lua_touserdata(L, 1);
    size_t size;
    const char *str = luaL_checklstring(L, 2, &size);
    int flags = luaL_checkinteger(L, 3);

    int n = zmq_send(socket, str, size, flags);

    if (n == -1)
    {
        raise_zmq_errno(L);
    }

    if (n != size)
    {
        luaL_error(L, "zmq_send: sent %d bytes instead of %d.", n, size);
    }

    lua_pushvalue(L, 1);

    return 1;
}

int l_zmq_version(lua_State *L)
{
    int major, minor, patch;
    zmq_version(&major, &minor, &patch);

    lua_pushinteger(L, major);
    lua_pushinteger(L, minor);
    lua_pushinteger(L, patch);

    return 3;
}

int l_zmq_getsockopt_int(lua_State *L)
{
    void *socket = lua_touserdata(L, 1);
    lua_Integer opt = lua_tointeger(L, 2);

    lua_Integer v;
    size_t size;

    int s = zmq_getsockopt(socket, opt, &v, &size);

    if (s == -1)
    {
        raise_zmq_errno(L);
    }

    lua_pushinteger(L, v);

    return 1;
}

int l_zmq_setsockopt_string(lua_State *L)
{
    void *socket = lua_touserdata(L, 1);
    lua_Integer opt = lua_tointeger(L, 2);

    size_t size;
    const char *v = luaL_checklstring(L, 3, &size);

    int s = zmq_setsockopt(socket, opt, v, size);

    if (s == -1)
    {
        raise_zmq_errno(L);
    }

    lua_pushvalue(L, 1);
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
    {"zmq_version", l_zmq_version},
    {"zmq_getsockopt_int", l_zmq_getsockopt_int},
    {"zmq_setsockopt_string", l_zmq_setsockopt_string},
    {"zmq_msg_recv_more", l_zmq_msg_recv_more},
    {"zmq_msg_send", l_zmq_msg_send},
    {"zmq_recv_more", l_zmq_recv_more},
    {NULL, NULL} /* sentinel */
};

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

    lua_pushinteger(L, ZMQ_AFFINITY);
    lua_setfield(L, -2, "AFFINITY");

    lua_pushinteger(L, ZMQ_ROUTING_ID);
    lua_setfield(L, -2, "ROUTING_ID");

    lua_pushinteger(L, ZMQ_SUBSCRIBE);
    lua_setfield(L, -2, "SUBSCRIBE");

    lua_pushinteger(L, ZMQ_UNSUBSCRIBE);
    lua_setfield(L, -2, "UNSUBSCRIBE");

    lua_pushinteger(L, ZMQ_RATE);
    lua_setfield(L, -2, "RATE");

    lua_pushinteger(L, ZMQ_RECOVERY_IVL);
    lua_setfield(L, -2, "RECOVERY_IVL");

    lua_pushinteger(L, ZMQ_SNDBUF);
    lua_setfield(L, -2, "SNDBUF");

    lua_pushinteger(L, ZMQ_RCVBUF);
    lua_setfield(L, -2, "RCVBUF");

    lua_pushinteger(L, ZMQ_RCVMORE);
    lua_setfield(L, -2, "RCVMORE");

    lua_pushinteger(L, ZMQ_FD);
    lua_setfield(L, -2, "FD");

    lua_pushinteger(L, ZMQ_EVENTS);
    lua_setfield(L, -2, "EVENTS");

    lua_pushinteger(L, ZMQ_TYPE);
    lua_setfield(L, -2, "TYPE");

    lua_pushinteger(L, ZMQ_LINGER);
    lua_setfield(L, -2, "LINGER");

    lua_pushinteger(L, ZMQ_RECONNECT_IVL);
    lua_setfield(L, -2, "RECONNECT_IVL");

    lua_pushinteger(L, ZMQ_BACKLOG);
    lua_setfield(L, -2, "BACKLOG");

    lua_pushinteger(L, ZMQ_RECONNECT_IVL_MAX);
    lua_setfield(L, -2, "RECONNECT_IVL_MAX");

    lua_pushinteger(L, ZMQ_MAXMSGSIZE);
    lua_setfield(L, -2, "MAXMSGSIZE");

    lua_pushinteger(L, ZMQ_SNDHWM);
    lua_setfield(L, -2, "SNDHWM");

    lua_pushinteger(L, ZMQ_RCVHWM);
    lua_setfield(L, -2, "RCVHWM");

    lua_pushinteger(L, ZMQ_MULTICAST_HOPS);
    lua_setfield(L, -2, "MULTICAST_HOPS");

    lua_pushinteger(L, ZMQ_RCVTIMEO);
    lua_setfield(L, -2, "RCVTIMEO");

    lua_pushinteger(L, ZMQ_SNDTIMEO);
    lua_setfield(L, -2, "SNDTIMEO");

    lua_pushinteger(L, ZMQ_LAST_ENDPOINT);
    lua_setfield(L, -2, "LAST_ENDPOINT");

    lua_pushinteger(L, ZMQ_ROUTER_MANDATORY);
    lua_setfield(L, -2, "ROUTER_MANDATORY");

    lua_pushinteger(L, ZMQ_TCP_KEEPALIVE);
    lua_setfield(L, -2, "TCP_KEEPALIVE");

    lua_pushinteger(L, ZMQ_TCP_KEEPALIVE_CNT);
    lua_setfield(L, -2, "TCP_KEEPALIVE_CNT");

    lua_pushinteger(L, ZMQ_TCP_KEEPALIVE_IDLE);
    lua_setfield(L, -2, "TCP_KEEPALIVE_IDLE");

    lua_pushinteger(L, ZMQ_TCP_KEEPALIVE_INTVL);
    lua_setfield(L, -2, "TCP_KEEPALIVE_INTVL");

    lua_pushinteger(L, ZMQ_IMMEDIATE);
    lua_setfield(L, -2, "IMMEDIATE");

    lua_pushinteger(L, ZMQ_XPUB_VERBOSE);
    lua_setfield(L, -2, "XPUB_VERBOSE");

    lua_pushinteger(L, ZMQ_ROUTER_RAW);
    lua_setfield(L, -2, "ROUTER_RAW");

    lua_pushinteger(L, ZMQ_IPV6);
    lua_setfield(L, -2, "IPV6");

    lua_pushinteger(L, ZMQ_MECHANISM);
    lua_setfield(L, -2, "MECHANISM");

    lua_pushinteger(L, ZMQ_PLAIN_SERVER);
    lua_setfield(L, -2, "PLAIN_SERVER");

    lua_pushinteger(L, ZMQ_PLAIN_USERNAME);
    lua_setfield(L, -2, "PLAIN_USERNAME");

    lua_pushinteger(L, ZMQ_PLAIN_PASSWORD);
    lua_setfield(L, -2, "PLAIN_PASSWORD");

    lua_pushinteger(L, ZMQ_CURVE_SERVER);
    lua_setfield(L, -2, "CURVE_SERVER");

    lua_pushinteger(L, ZMQ_CURVE_PUBLICKEY);
    lua_setfield(L, -2, "CURVE_PUBLICKEY");

    lua_pushinteger(L, ZMQ_CURVE_SECRETKEY);
    lua_setfield(L, -2, "CURVE_SECRET");

    lua_pushinteger(L, ZMQ_CURVE_SERVERKEY);
    lua_setfield(L, -2, "CURVE_SERVERKEY");

    lua_pushinteger(L, ZMQ_PROBE_ROUTER);
    lua_setfield(L, -2, "PROBE_ROUTER");

    lua_pushinteger(L, ZMQ_REQ_CORRELATE);
    lua_setfield(L, -2, "REQ_CORRELATE");

    lua_pushinteger(L, ZMQ_REQ_RELAXED);
    lua_setfield(L, -2, "REQ_RELAXED");

    lua_pushinteger(L, ZMQ_CONFLATE);
    lua_setfield(L, -2, "CONFLATE");

    lua_pushinteger(L, ZMQ_ZAP_DOMAIN);
    lua_setfield(L, -2, "ZAP_DOMAIN");

    lua_pushinteger(L, ZMQ_ROUTER_HANDOVER);
    lua_setfield(L, -2, "ROUTER_HANDOVER");

    lua_pushinteger(L, ZMQ_TOS);
    lua_setfield(L, -2, "TOS");

    lua_pushinteger(L, ZMQ_CONNECT_ROUTING_ID);
    lua_setfield(L, -2, "CONNECT_ROUTING_ID");

    lua_pushinteger(L, ZMQ_GSSAPI_SERVER);
    lua_setfield(L, -2, "GSSAPI_SERVER");

    lua_pushinteger(L, ZMQ_GSSAPI_PRINCIPAL);
    lua_setfield(L, -2, "GSSAPI_PRINCIPAL");

    lua_pushinteger(L, ZMQ_GSSAPI_SERVICE_PRINCIPAL);
    lua_setfield(L, -2, "GSSAPI_SERVICE_PRINCIPAL");

    lua_pushinteger(L, ZMQ_GSSAPI_PLAINTEXT);
    lua_setfield(L, -2, "GSSAPI_PLAINTEXT");

    lua_pushinteger(L, ZMQ_HANDSHAKE_IVL);
    lua_setfield(L, -2, "HANDSHAKE_IVL");

    lua_pushinteger(L, ZMQ_SOCKS_PROXY);
    lua_setfield(L, -2, "SOCKS_PROXY");

    lua_pushinteger(L, ZMQ_XPUB_NODROP);
    lua_setfield(L, -2, "XPUB_NODROP");

    lua_pushinteger(L, ZMQ_BLOCKY);
    lua_setfield(L, -2, "BLOCKY");

    lua_pushboolean(L, ZMQ_XPUB_MANUAL);
    lua_setfield(L, -2, "XPUB_MANUAL");

    lua_pushinteger(L, ZMQ_XPUB_WELCOME_MSG);
    lua_setfield(L, -2, "XPUB_WELCOME_MSG");

    lua_pushinteger(L, ZMQ_STREAM_NOTIFY);
    lua_setfield(L, -2, "STREAM_NOTIFY");

    lua_pushinteger(L, ZMQ_INVERT_MATCHING);
    lua_setfield(L, -2, "INVERT_MATCHING");

    lua_pushinteger(L, ZMQ_HEARTBEAT_IVL);
    lua_setfield(L, -2, "HEARTBEAT_IVL");

    lua_pushinteger(L, ZMQ_HEARTBEAT_TTL);
    lua_setfield(L, -2, "HEARTBEAT_TTL");

    lua_pushinteger(L, ZMQ_HEARTBEAT_TIMEOUT);
    lua_setfield(L, -2, "HEARTBEAT_TIMEOUT");

    lua_pushinteger(L, ZMQ_XPUB_VERBOSER);
    lua_setfield(L, -2, "XPUB_VERBOSER");

    lua_pushinteger(L, ZMQ_CONNECT_TIMEOUT);
    lua_setfield(L, -2, "CONNECT_TIMEOUT");

    lua_pushinteger(L, ZMQ_TCP_MAXRT);
    lua_setfield(L, -2, "TCP_MAXRT");

    lua_pushinteger(L, ZMQ_THREAD_SAFE);
    lua_setfield(L, -2, "THREAD_SAFE");

    lua_pushinteger(L, ZMQ_MULTICAST_MAXTPDU);
    lua_setfield(L, -2, "MULTICAST_MAXTPDU");

    lua_pushinteger(L, ZMQ_VMCI_BUFFER_SIZE);
    lua_setfield(L, -2, "VMCI_BUFFER_SIZE");

    lua_pushinteger(L, ZMQ_VMCI_BUFFER_MIN_SIZE);
    lua_setfield(L, -2, "VMCI_BUFFER_MIN_SIZE");

    lua_pushinteger(L, ZMQ_VMCI_BUFFER_MAX_SIZE);
    lua_setfield(L, -2, "VMCI_BUFFER_MAX_SIZE");

    lua_pushinteger(L, ZMQ_VMCI_CONNECT_TIMEOUT);
    lua_setfield(L, -2, "VMCI_CONNECT_TIMEOUT");

    lua_pushinteger(L, ZMQ_USE_FD);
    lua_setfield(L, -2, "USE_FD");

    lua_pushinteger(L, ZMQ_GSSAPI_PRINCIPAL_NAMETYPE);
    lua_setfield(L, -2, "GSSAPI_PRINCIPAL_NAMETYPE");

    lua_pushinteger(L, ZMQ_GSSAPI_SERVICE_PRINCIPAL_NAMETYPE);
    lua_setfield(L, -2, "GSSAPI_SERVICE_PRINCIPAL_NAMETYPE");

    lua_pushinteger(L, ZMQ_BINDTODEVICE);
    lua_setfield(L, -2, "BINDTODEVICE");

    lua_pushinteger(L, ZMQ_MORE);
    lua_setfield(L, -2, "MORE");

    lua_pushinteger(L, ZMQ_SHARED);
    lua_setfield(L, -2, "SHARED");

    lua_pushinteger(L, ZMQ_DONTWAIT);
    lua_setfield(L, -2, "DONTWAIT");

    lua_pushinteger(L, ZMQ_SNDMORE);
    lua_setfield(L, -2, "SNDMORE");
}

int luaopen_libluazmq(lua_State *L) // the initialization function of the module.
{
    luaL_newlib(L, libluazmq);

    push_socket_types_table(L);

    return 1;
}