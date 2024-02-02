
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

function T:test_zmq_ctx_socket ()
    
    unittest.assert.equals 'Block not called' (true, true) (
        zmq.ctx.pcall (function (ctx)
            local socket = zmq.socket (ctx, zmq.socket.REP)
            unittest.assert.istrue 'Cannot create a socket' (socket ~= zmq.C.NULL)
            zmq.close (socket)
            return true
        end)
    )
end


function T:test_zmq_ctx_socket_pcall ()
    
    local w, v = {}, {}
    unittest.assert.equals 'Block not called' (true, w) (
        zmq.ctx.pcall (function (ctx)
            
            unittest.assert.equals 'Cannot create a socket' (true, v) (
                zmq.socket.pcall (ctx, zmq.socket.REP, function (socket)
                    unittest.assert.istrue 'Cannot create a socket' (socket ~= zmq.C.NULL)
                    return v
                end)
            )

            return w
        end)
    )
end

function T:test_zmq_bind ()
    
    local w, v = {}, {}
    unittest.assert.equals 'Block not called' (true, w) (
        zmq.ctx.pcall (function (ctx)
            
            unittest.assert.equals 'Cannot create a socket' (true, v) (
                zmq.socket.pcall (ctx, zmq.socket.REP, function (socket)
                    
                    zmq.bind (socket, { transport = 'tcp', host = '*', port = 5555 })
                    
                    unittest.assert.istrue 'Cannot create a socket' (socket ~= zmq.C.NULL)
                    return v
                end)
            )

            return w
        end)
    )
end


function T:test_zmq_recv ()
    
    local w, v = {}, {}
    unittest.assert.equals 'Block not called' (true, w) (
        zmq.ctx.pcall (function (ctx)
            
            unittest.assert.equals 'Cannot create a socket' (true, v) (
                zmq.socket.pcall (ctx, zmq.socket.REP, function (socket)

                    zmq.bind (socket, { transport = 'tcp', host = '*', port = 5555 })
                    local msg = zmq.recv (socket, 10)

                    unittest.assert.istrue 'Cannot create a socket' (socket ~= zmq.C.NULL)
                    return v
                end)
            )

            return w
        end)
    )
end

print (unittest.api.suite (T))