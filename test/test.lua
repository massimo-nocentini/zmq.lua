
local unittest = require "unittest"
local zmq = require "zmq"
local pthread = require 'libc'.pthread

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
    
    local port = 5555

    unittest.assert.istrue 'Block not called' (true) (
        zmq.ctx.pcall (function (ctx)
            

            zmq.socket.pcall (ctx, zmq.socket.REP, function (server)
                zmq.socket.pcall (ctx, zmq.socket.REQ, function (client)

                    zmq.bind (server, { transport = 'tcp', host = '*', port = port })
                    zmq.connect (client, { transport = 'tcp', host = 'localhost', port = port })
    
                    local thread_s, pthread_s = pthread.create {} (function ()
                        local msg = zmq.recv (server, 10)
                        return msg
                    end)

                    local n = zmq.send (client, 'Hello')
                
                    local flag, msg = pthread.join (thread_s, pthread_s)
                
                    unittest.assert.equals 'Cannot receive message' ('Hello', msg)

                end)
            end)
        end)
    )
end

print (unittest.api.suite (T))