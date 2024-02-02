
local libluazmq = require "libluazmq"

local zmq = {
    ctx = {
        new = libluazmq.ctx_new,
        term = libluazmq.ctx_term,
        shutdown = libluazmq.ctx_shutdown,
    },
    close = libluazmq.zmq_close,
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

return zmq