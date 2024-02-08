
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

    socket:close ()
end

function T:test_zmq_ctx_socket_pcall ()
    
    local socket <close> = zmq.socket (self.ctx, zmq.REP)
    unittest.assert.istrue 'Cannot create a socket' (socket ~= libc.stddef.NULL)
end

function T:test_zmq_bind ()
    
    local socket <close> = zmq.socket (self.ctx, zmq.REP)
    socket:bind { port = 5555 }
end

function T:test_zmq_recv ()
    
    local port, msg = 5555, 'Hello'

    local server <close> = zmq.socket (self.ctx, zmq.REP)
    local client <close> = zmq.socket (self.ctx, zmq.REQ)

    server:bind { port = port }
    client:connect { port = port }
    
    local thread_s = pthread.create (function () return zmq.recv (server, 10) end)
    
    client:send (msg) -- blocking call, that's why we need to start the server pthread first.
        
    unittest.assert.equals 'Not the same message.' (true, msg, false) (pthread.join (thread_s))
end



function T:test_zmq_recv_big_msg_tbl ()
    
    local port = 5555

    local server <close> = zmq.socket (self.ctx, zmq.REP)
    local client <close> = zmq.socket (self.ctx, zmq.REQ)

    server:bind { port = port }
    client:connect { port = port }
    
    local thread_s = pthread.create (function () 
        return zmq.recv_more {
            socket = server, 
            max_bytes = 10,
            handler = false
        }
    end)
    
    client:send ('Hello', zmq.SNDMORE)
    client:send 'World'
    
    unittest.assert.equals 'Cannot receive message' 
        (true, { 'Hello', 'World' }) (pthread.join (thread_s))

end



function T:test_zmq_recv_big_msg_str ()
    
    local port = 5555

    local server <close> = zmq.socket (self.ctx, zmq.REP)
    local client <close> = zmq.socket (self.ctx, zmq.REQ)

    server:bind { port = port }
    client:connect { port = port }
    
    local thread_s = pthread.create (function () 
        return zmq.recv_more {
            socket = server,
            max_bytes = 10,
        }
    end)
    
    client:send ('Hello', zmq.SNDMORE)
    client:send (' ', zmq.SNDMORE)
    client:send 'World'
    
    unittest.assert.equals 'Cannot receive message' 
        (true, 'Hello World' ) (pthread.join (thread_s))

end



function T:test_zmq_recv_send ()
    
    local port = 5555

    local server <close> = zmq.socket (self.ctx, zmq.REP)
    local client <close> = zmq.socket (self.ctx, zmq.REQ)
    
    server:bind { port = port }
    client:connect { port = port }

    local thread_s = pthread.create (function ()
        local msg = zmq.recv (server, 10)
        server:send 'world'
        return msg
    end)

    local thread_c = pthread.create (function ()
        client:send 'hello'
        return zmq.recv (client, 10)
    end)

    local flag_c, msg_from_server = pthread.join (thread_c)
    local flag_s, msg_from_client = pthread.join (thread_s)
    
    unittest.assert.equals 'All ok' (true, true) (flag_s, flag_c)
    unittest.assert.equals 'Cannot receive message' 
        ('hello', 'world') (msg_from_client, msg_from_server)

end


function T:test_zmq_recv_send_loop ()
    
    local port, n = 5555, 10

    local server <close> = zmq.socket (self.ctx, zmq.REP)
    local client <close> = zmq.socket (self.ctx, zmq.REQ)

    server:bind { port = port }
    client:connect { port = port }

    local thread_s = pthread.create (function ()
        local continue = true
        while continue do
            local msg = zmq.recv (server, 10)
            if msg == 'quit' then continue = false
            else server:send 'world' end
        end
    end)

    local thread_c = pthread.create (function ()
        local tbl = {}
        for i = 1, n do
            client:send 'hello'
            tbl[i] = zmq.recv (client, 10)
        end
        client:send 'quit'
        return tbl
    end)
    
    unittest.assert.equals 'Cannot receive message' (true, {
        'world', 'world', 'world', 'world', 'world', 'world', 'world', 'world', 'world', 'world'
    }) (pthread.join (thread_c))

    unittest.assert.istrue 'Cannot receive message' (pthread.join (thread_s))

end



function T:test_zmq_recv_pub_sub ()
    
    local port, n = 5555, 10

    local server <close> = zmq.socket (self.ctx, zmq.PUB)
    local client <close> = zmq.socket (self.ctx, zmq.SUB)
    local another <close> = zmq.socket (self.ctx, zmq.SUB)

    local continue = true

    server:bind { port = port }
    client:connect { port = port }
    another:connect { port = port }

    zmq.setsockopt.subscribe (client, '10001 ')
    zmq.setsockopt.subscribe (another, '10002 ')

    local thread_s = pthread.create (function ()
        while continue do
            local zipcode, temperature, relhumidity;
            zipcode     = math.random (100000);
            temperature = math.random (215) - 80;
            relhumidity = math.random (50) + 10;
            local msg = string.format ("%05d %d %d", zipcode, temperature, relhumidity)
            server:send (msg)
        end
    end)

    local thread_c = pthread.create (function ()
        local tbl = {}
        for i = 1, n do tbl[i] = zmq.recv (client, 20) end
        return tbl
    end)

    local thread_a = pthread.create (function ()
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
end


print (unittest.api.suite (T))