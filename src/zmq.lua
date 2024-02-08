
local libluazmq = require "libluazmq"

local zmq = {
    ctx = {
        new = libluazmq.ctx_new,
        term = libluazmq.ctx_term,
        shutdown = libluazmq.ctx_shutdown,
    },
    setsockopt = {
        subscribe = function (socket, filter) 
            return libluazmq.zmq_setsockopt_string (socket, libluazmq.SUBSCRIBE, filter or '')
        end,
    },
    version = libluazmq.zmq_version,
}

setmetatable (zmq, {
    __index = libluazmq
})

local socket_mt = {
    __close = libluazmq.zmq_close,
    __index = {
        close = libluazmq.zmq_close,
        bind = function (socket, endpoint_tbl) 
            return libluazmq.zmq_bind (socket,
                string.format ('%s://%s:%d', 
                    endpoint_tbl.transport or 'tcp',
                    endpoint_tbl.host or '*',
                    endpoint_tbl.port
                )
            )
        end,
        connect = function (socket, endpoint_tbl) 
            return libluazmq.zmq_connect (socket, 
                string.format ('%s://%s:%d', 
                    endpoint_tbl.transport or 'tcp',
                    endpoint_tbl.host or 'localhost',
                    endpoint_tbl.port
                )
            )
        end,
    },
}

function zmq.socket (ctx, socket_type)
    local socket = libluazmq.zmq_socket (ctx, socket_type)
    return debug.setmetatable (socket, socket_mt)
end

function zmq.ctx.pcall (f)
    local ctx = zmq.ctx.new ()
    local function R (...)
        zmq.ctx.shutdown (ctx)
        zmq.ctx.term (ctx)
        return ...
    end
    return R (pcall (f, ctx))
end

function zmq.recv (socket, len, flags) 
    return libluazmq.zmq_recv (socket, len, flags or 0)
end

function zmq.recv_more (tbl)

    local socket, len, flags, return_str = tbl.socket, tbl.max_bytes, tbl.flags or 0, tbl.handler

    if return_str == nil then return_str = true end

    if return_str then
        return libluazmq.zmq_recv_more (socket, len, flags)
    else
        local tbl, recvmore = {}, true
        while recvmore do tbl[#tbl + 1], recvmore = zmq.recv (socket, len, flags) end
        return tbl
    end
end

function zmq.send (socket, str, flags) 
    return libluazmq.zmq_send (socket, str, flags or 0)
end

return zmq