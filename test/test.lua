
local unittest = require "unittest"
local zmq = require "zmq"

local T = {}

function T:test_zmq_ctx_new ()
    local ctx = zmq.ctx.new ()
    unittest.assert.istrue 'Failed in creating the context.' (ctx ~= zmq.C.NULL)
    zmq.ctx.term (ctx)
end

function T:test_zmq_ctx_call ()
    
    unittest.assert.equals 'Block not called' (true, true) (
        zmq.ctx.pcall (function (ctx) 
            unittest.assert.istrue 'Failed in creating the context.' (ctx ~= zmq.C.NULL)
            return true
        end)
    )
end



print (unittest.api.suite (T))