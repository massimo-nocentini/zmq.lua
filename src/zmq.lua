
local libluazmq = require "libluazmq"

local zmq = {
    ctx = {
        new = libluazmq.ctx_new,
        term = libluazmq.ctx_term,
    },
}

function zmq.ctx.pcall (f)
    local ctx = zmq.ctx.new ()
    local function R (...)
        zmq.ctx.term (ctx)
        return ...
    end
    return R (pcall (f, ctx))
end

setmetatable (zmq, {
    __index = libluazmq,
})

return zmq