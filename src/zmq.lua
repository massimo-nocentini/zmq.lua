
local libluazmq = require "libluazmq"

local ctx_mt = {
    __index = {
        socket = function (ctx, socket_type)
            local socket = libluazmq.zmq_socket (ctx, socket_type)
            return debug.setmetatable (socket, socket_mt)
        end        
    }
}

local zmq = {
    ctx = {
        new = libluazmq.ctx_new,
        term = libluazmq.ctx_term,
        shutdown = libluazmq.ctx_shutdown,
    },
    version = libluazmq.zmq_version,
}

setmetatable (zmq, {
    __index = libluazmq
})

local socket_mt = {
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
        send = function (socket, str, flags) 
            return libluazmq.zmq_send (socket, str, flags or 0)
        end,
        recv = function (socket, len, flags) 
            return libluazmq.zmq_recv (socket, len, flags or 0)
        end,
        subscribe = function (socket, filter) 
            return libluazmq.zmq_setsockopt_string (socket, libluazmq.SUBSCRIBE, filter or '')
        end,
        recv_more = function (socket, tbl)

            local len, flags, ret = tbl.max_bytes, tbl.flags or 0, tbl.handler
        
            if ret == nil then ret = '' end
        
            local typ = type(ret)
            if typ == 'string' then
                return libluazmq.zmq_recv_more (socket, len, flags)
            elseif typ == 'table' then
                local tbl, recvmore = ret, true
                while recvmore do tbl[#tbl + 1], recvmore = socket:recv (len, flags) end
                return tbl
            end
        end,
        send_msg = libluazmq.zmq_msg_send,
        recv_msg_more = libluazmq.zmq_msg_recv_more,
    },
}

function zmq.ctx.pcall (f)
    local ctx = zmq.ctx.new ()
    local function R (...)
        zmq.ctx.shutdown (ctx)
        zmq.ctx.term (ctx)
        return ...
    end
    return R (pcall (f, ctx))
end

function zmq.socket (ctx, socket_type)
    local socket = libluazmq.zmq_socket (ctx, socket_type)
    return debug.setmetatable (socket, socket_mt)
end   

return zmq