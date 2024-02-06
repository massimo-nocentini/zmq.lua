
local libluazmq = require "libluazmq"

local zmq = {
    ctx = {
        new = libluazmq.ctx_new,
        term = libluazmq.ctx_term,
        shutdown = libluazmq.ctx_shutdown,
    },
    socket = {},
    getsockopt = {
        rcvmore = function (socket) 
            return libluazmq.zmq_getsockopt_int (socket, libluazmq.RCVMORE) == 1 
        end,
    },
    setsockopt = {
        subscribe = function (socket, filter) 
            return libluazmq.zmq_setsockopt_string (socket, libluazmq.SUBSCRIBE, filter or '')
        end,
    },
    close = libluazmq.zmq_close,
    version = libluazmq.zmq_version,
}

setmetatable (zmq, {
    __index = libluazmq
})

setmetatable(zmq.socket, {
    __call = function (self, ctx, socket_type)
        return libluazmq.zmq_socket (ctx, socket_type)
    end
})

function zmq.ctx.pcall (f)
    local ctx = zmq.ctx.new ()
    local function R (...)
        zmq.ctx.shutdown (ctx)
        zmq.ctx.term (ctx)
        return ...
    end
    return R (pcall (f, ctx))
end

function zmq.socket.pcall (ctx, socket_type, f)
    local socket = zmq.socket (ctx, socket_type)
    local function R (...)
        zmq.close (socket)
        return ...
    end
    return R (pcall (f, socket))
end

function zmq.bind (socket, endpoint_tbl)
    return libluazmq.zmq_bind (socket, 
        string.format ('%s://%s:%d', 
            endpoint_tbl.transport or 'tcp',
            endpoint_tbl.host or '*',
            endpoint_tbl.port
        )
    )
end

function zmq.connect (socket, endpoint_tbl)
    return libluazmq.zmq_connect (socket, 
        string.format ('%s://%s:%d', 
            endpoint_tbl.transport or 'tcp',
            endpoint_tbl.host or 'localhost',
            endpoint_tbl.port
        )
    )
end

function zmq.recv (socket, len, flags) 
    return libluazmq.zmq_recv (socket, len, flags or 0)
end

function zmq.recv_more (socket, len, flags, return_str)

    if return_str == nil then return_str = true end

    if return_str then
        return libluazmq.zmq_recv_more (socket, len, flags or 0)
    else
        local tbl, recvmore = {}, true
        while recvmore do tbl[#tbl + 1], recvmore = zmq.recv (socket, len, flags or 0) end
        return tbl
    end
end

function zmq.send (socket, str, flags) 
    return libluazmq.zmq_send (socket, str, flags or 0)
end

return zmq