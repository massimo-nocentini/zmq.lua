
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
            local socket = zmq.socket (ctx, zmq.REP)
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
                zmq.socket.pcall (ctx, zmq.REP, function (socket)
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
                zmq.socket.pcall (ctx, zmq.REP, function (socket)
                    
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

    unittest.assert.istrue 'Block not called' (
        zmq.ctx.pcall (function (ctx)
            zmq.socket.pcall (ctx, zmq.REP, function (server)
                zmq.socket.pcall (ctx, zmq.REQ, function (client)

                    zmq.bind (server, { transport = 'tcp', host = '*', port = port })
                    zmq.connect (client, { transport = 'tcp', host = 'localhost', port = port })
                    
                    local thread_s = pthread.create {} (function () return zmq.recv (server, 10) end)
                    
                    assert (zmq.send (client, 'Hello') == 5, 'Cannot send message')
                     
                    unittest.assert.equals 'Cannot receive message' (true, 'Hello') (
                        pthread.join (thread_s))

                end)
            end)
        end)
    )
end

function T:test_zmq_recv_send ()
    
    local port = 5555

    unittest.assert.equals 'Block not called' (true, true, true) (
        zmq.ctx.pcall (function (ctx)
            return zmq.socket.pcall (ctx, zmq.REP, function (server)
                return zmq.socket.pcall (ctx, zmq.REQ, function (client)
    
                    zmq.bind (server, { port = port })
                    zmq.connect (client, { port = port })
    
                    local thread_s = pthread.create {} (function ()
                        local msg = zmq.recv (server, 10)
                        assert (zmq.send (server, 'world') == 5)
                        return msg
                    end)
    
                    local thread_c = pthread.create {} (function ()
                        assert (zmq.send (client, 'hello') == 5)
                        return zmq.recv (client, 10)
                    end)
    
                    local flag_c, msg_from_server = pthread.join (thread_c)
                    local flag_s, msg_from_client = pthread.join (thread_s)
                    
                    unittest.assert.equals 'All ok' (true, true) (flag_s, flag_c)
                    unittest.assert.equals 'Cannot receive message' ('hello', 'world') (msg_from_client, msg_from_server)
    
                end)
            end)
        end)
    )
end


function T:test_zmq_recv_send_loop ()
    
    local port, n = 5555, 10

    unittest.assert.equals 'Block not called' (true, true, true) (
        zmq.ctx.pcall (function (ctx)
            return zmq.socket.pcall (ctx, zmq.REP, function (server)
                return zmq.socket.pcall (ctx, zmq.REQ, function (client)
    
                    zmq.bind (server, { port = port })
                    zmq.connect (client, { port = port })
    
                    local thread_s = pthread.create { create_detached = true } (function ()
                        while true do
                            local msg = zmq.recv (server, 10)
                            if msg == 'quit' then break end
                            assert (zmq.send (server, 'world') == 5)
                        end
                    end)
    
                    local thread_c = pthread.create {} (function ()
                        local tbl = {}
                        for i = 1, n do
                            assert (zmq.send (client, 'hello') == 5)
                            tbl[i] = zmq.recv (client, 10)
                        end
                        assert (zmq.send (client, 'quit') == 4)
                        return tbl
                    end)
                    
                    
                    unittest.assert.equals 'Cannot receive message' (true, {
                        'world', 'world', 'world', 'world', 'world', 'world', 'world', 'world', 'world', 'world'
                    }) (pthread.join (thread_c))
                    -- unittest.assert.istrue 'Cannot receive message' (pthread.join (thread_s))
    
                end)
            end)
        end)
    )
end


print (unittest.api.suite (T))