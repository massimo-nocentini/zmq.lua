
local unittest = require "unittest"
local zmq = require "zmq"
local libc = require 'libc'
local pthread = libc.pthread

local T = {}

function T:setup () 
    self.ctx = zmq.ctx.new () 
    self.witness = {}
end

function T:teardown () zmq.ctx.shutdown (self.ctx); zmq.ctx.term (self.ctx) end

function T:test_zmq_version ()
    unittest.assert.equals 'zmq has always a version.' (4, 3, 5) (zmq.version ())
end

function T:test_zmq_ctx_new ()
    unittest.assert.istrue 'Failed in creating the context.' (self.ctx ~= libc.stddef.NULL)
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
    local socket = zmq.socket (self.ctx, zmq.REP)
    unittest.assert.istrue 'Cannot create a socket' (socket ~= libc.stddef.NULL)
    zmq.close (socket)
end

function T:test_zmq_ctx_socket_pcall ()
    
    unittest.assert.equals 'Cannot create a socket' (true, self.witness) (
        zmq.socket.pcall (self.ctx, zmq.REP, function (socket)
            unittest.assert.istrue 'Cannot create a socket' (socket ~= libc.stddef.NULL)
            return self.witness
        end)
    )
end

function T:test_zmq_bind ()
    
    unittest.assert.equals 'Cannot create a socket' (true, self.witness) (
        zmq.socket.pcall (self.ctx, zmq.REP, function (socket)
            zmq.bind (socket, { port = 5555 })
            return self.witness
        end)
    )
end

function T:test_zmq_recv ()
    
    local port, msg = 5555, 'Hello'

    unittest.assert.equals 'Block not called' (true, true) (
        zmq.socket.pcall (self.ctx, zmq.REP, function (server)
            return zmq.socket.pcall (self.ctx, zmq.REQ, function (client)

                zmq.bind (server, { port = port })
                zmq.connect (client, { port = port })
                
                local thread_s = pthread.create {} (function () return zmq.recv (server, 10) end)
                
                zmq.send (client, msg) -- blocking call, that's why we need to start the server pthread first.
                 
                unittest.assert.equals 'Not the same message.' (true, msg, false) (pthread.join (thread_s))
            end)
        end)
    )
end

function T:test_zmq_recv_big_msg_tbl ()
    
    local port = 5555

    unittest.assert.equals 'Block not called' (true, true) (
        zmq.socket.pcall (self.ctx, zmq.REP, function (server)
            return zmq.socket.pcall (self.ctx, zmq.REQ, function (client)

                zmq.bind (server, { port = port })
                zmq.connect (client, { port = port })
                
                local thread_s = pthread.create {} (function () 
                    return zmq.recv_more {
                        socket = server, 
                        max_bytes = 10,
                        handler = false
                    }
                end)
                
                zmq.send (client, 'Hello', zmq.SNDMORE)
                zmq.send (client, 'World')
                
                unittest.assert.equals 'Cannot receive message' 
                    (true, { 'Hello', 'World' }) (pthread.join (thread_s))

            end)
        end)
    )
end


function T:test_zmq_recv_big_msg_str ()
    
    local port = 5555

    unittest.assert.equals 'Block not called' (true, true) (
        zmq.socket.pcall (self.ctx, zmq.REP, function (server)
            return zmq.socket.pcall (self.ctx, zmq.REQ, function (client)

                zmq.bind (server, { port = port })
                zmq.connect (client, { port = port })
                
                local thread_s = pthread.create {} (function () 
                    return zmq.recv_more {
                        socket = server,
                        max_bytes = 10,
                    }
                end)
                
                zmq.send (client, 'Hello', zmq.SNDMORE)
                zmq.send (client, ' ', zmq.SNDMORE)
                zmq.send (client, 'World')
                
                unittest.assert.equals 'Cannot receive message' 
                    (true, 'Hello World' ) (pthread.join (thread_s))

            end)
        end)
    )
end

function T:test_zmq_recv_send ()
    
    local port = 5555

    unittest.assert.equals 'Block not called' (true, true) (
        zmq.socket.pcall (self.ctx, zmq.REP, function (server)
            return zmq.socket.pcall (self.ctx, zmq.REQ, function (client)

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
                unittest.assert.equals 'Cannot receive message' 
                    ('hello', 'world') (msg_from_client, msg_from_server)

            end)
        end)
    )
end


function T:test_zmq_recv_send_loop ()
    
    local port, n = 5555, 10

    unittest.assert.equals 'Block not called' (true, true) (
        zmq.socket.pcall (self.ctx, zmq.REP, function (server)
            return zmq.socket.pcall (self.ctx, zmq.REQ, function (client)

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

            end)
        end)
    )
end


function T:test_zmq_recv_pub_sub ()
    
    local port, n = 5555, 10

    unittest.assert.equals 'Block not called' (true, true, true) (
        zmq.socket.pcall (self.ctx, zmq.PUB, function (server)
            return zmq.socket.pcall (self.ctx, zmq.SUB, function (client)
                return zmq.socket.pcall (self.ctx, zmq.SUB, function (another)

                    local continue = true

                    zmq.bind (server, { port = port })
                    zmq.connect (client, { port = port })
                    zmq.connect (another, { port = port })
    
                    zmq.setsockopt.subscribe (client, '10001 ')
                    zmq.setsockopt.subscribe (another, '10002 ')

                    local thread_s = pthread.create { } (function ()
                        while continue do
                            local zipcode, temperature, relhumidity;
                            zipcode     = math.random (100000);
                            temperature = math.random (215) - 80;
                            relhumidity = math.random (50) + 10;
                            local msg = string.format ("%05d %d %d", zipcode, temperature, relhumidity)
                            zmq.send (server, msg)
                        end
                    end)
    
                    local thread_c = pthread.create {} (function ()
                        local tbl = {}
                        for i = 1, n do tbl[i] = zmq.recv (client, 20) end
                        return tbl
                    end)

                    local thread_a = pthread.create {} (function ()
                        local tbl = {}
                        for i = 1, n do tbl[i] = zmq.recv (another, 20) end
                        return tbl
                    end)

                    local flag, tblc = pthread.join (thread_c)
                    unittest.assert.equals 'Cannot receive message' (true, n) (flag, #tblc)

                    local flag, tbla = pthread.join (thread_a)
                    unittest.assert.equals 'Cannot receive message' (true, n) (flag, #tbla)
    
                    continue = false -- stop the server

                    unittest.assert.istrue 'Cannot join the publisher pthread.' (pthread.join (thread_s))
                end)
            end)
        end)
    )
end


print (unittest.api.suite (T))