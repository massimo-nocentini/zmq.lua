
local unittest = require "unittest"
local zmq = require "zmq"
local libc = require 'libc'
local pthread = libc.pthread

local T = {}


function T:test_zmq_version ()
    unittest.assert.equals '' (4, 3, 5) (zmq.version ())
end


function T:test_zmq_ctx_new ()
    local ctx = zmq.ctx.new ()
    unittest.assert.istrue 'Failed in creating the context.' (ctx ~= libc.stddef.NULL)
    zmq.ctx.term (ctx)
end

function T:test_zmq_ctx_call ()
    
    unittest.assert.equals 'Block not called' (true, true) (
        zmq.ctx.pcall (function (ctx) 
            unittest.assert.istrue 'Failed in creating the context.' (ctx ~= libc.stddef.NULL)
            return true
        end)
    )
end

function T:test_zmq_ctx_socket ()
    
    unittest.assert.equals 'Block not called' (true, true) (
        zmq.ctx.pcall (function (ctx)
            local socket = zmq.socket (ctx, zmq.REP)
            unittest.assert.istrue 'Cannot create a socket' (socket ~= libc.stddef.NULL)
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
                    unittest.assert.istrue 'Cannot create a socket' (socket ~= libc.stddef.NULL)
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
                    
                    unittest.assert.istrue 'Cannot create a socket' (socket ~= libc.stddef.NULL)
                    return v
                end)
            )

            return w
        end)
    )
end


function T:test_zmq_recv ()
    
    local port = 5555

    unittest.assert.equals 'Block not called' (true, true, true) (
        zmq.ctx.pcall (function (ctx)
            return zmq.socket.pcall (ctx, zmq.REP, function (server)
                return zmq.socket.pcall (ctx, zmq.REQ, function (client)

                    zmq.bind (server, { port = port })
                    zmq.connect (client, { port = port })
                    
                    local thread_s = pthread.create {} (function () return zmq.recv (server, 10) end)
                    
                    zmq.send (client, 'Hello')
                     
                    unittest.assert.equals 'Cannot receive message' (true, 'Hello', false) (
                        pthread.join (thread_s))

                end)
            end)
        end)
    )
end

function T:test_zmq_recv_big_msg_tbl ()
    
    local port = 5555

    unittest.assert.equals 'Block not called' (true, true, true) (
        zmq.ctx.pcall (function (ctx)
            return zmq.socket.pcall (ctx, zmq.REP, function (server)
                return zmq.socket.pcall (ctx, zmq.REQ, function (client)

                    zmq.bind (server, { port = port })
                    zmq.connect (client, { port = port })
                    
                    local thread_s = pthread.create {} (function () return zmq.recv_more (server, 10, nil, false) end)
                    
                    zmq.send (client, 'Hello', zmq.SNDMORE)
                    zmq.send (client, 'World')
                    
                    unittest.assert.equals 'Cannot receive message' (true, { 'Hello', 'World' }) (
                        pthread.join (thread_s))

                end)
            end)
        end)
    )
end


function T:test_zmq_recv_big_msg_str ()
    
    local port = 5555

    unittest.assert.equals 'Block not called' (true, true, true) (
        zmq.ctx.pcall (function (ctx)
            return zmq.socket.pcall (ctx, zmq.REP, function (server)
                return zmq.socket.pcall (ctx, zmq.REQ, function (client)

                    zmq.bind (server, { port = port })
                    zmq.connect (client, { port = port })
                    
                    local thread_s = pthread.create {} (function () return zmq.recv_more (server, 10) end)
                    
                    zmq.send (client, 'Hello', zmq.SNDMORE)
                    zmq.send (client, ' ', zmq.SNDMORE)
                    zmq.send (client, 'World')
                    
                    unittest.assert.equals 'Cannot receive message' (true, 'Hello World' ) (
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
                        zmq.send (server, 'world')
                        return msg
                    end)
    
                    local thread_c = pthread.create {} (function ()
                        zmq.send (client, 'hello')
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
    
                    local thread_s = pthread.create {} (function ()
                        while true do
                            local msg = zmq.recv (server, 10)
                            if msg == 'quit' then break end
                            zmq.send (server, 'world')
                        end
                    end)
    
                    local thread_c = pthread.create {} (function ()
                        local tbl = {}
                        for i = 1, n do
                            zmq.send (client, 'hello')
                            tbl[i] = zmq.recv (client, 10)
                        end
                        zmq.send (client, 'quit')
                        return tbl
                    end)
                    
                    
                    unittest.assert.equals 'Cannot receive message' (true, {
                        'world', 'world', 'world', 'world', 'world', 'world', 'world', 'world', 'world', 'world'
                    }) (pthread.join (thread_c))
                    unittest.assert.istrue 'Cannot receive message' (pthread.join (thread_s))
    
                    os.execute 'sleep 0.2s'
                end)
            end)
        end)
    )
end


print (unittest.api.suite (T))