
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
    local socket = zmq.socket (self.ctx,zmq.REP)
   
    unittest.assert.istrue 'Cannot create a socket' (socket ~= libc.stddef.NULL)

    socket:close ()
end

function T:test_zmq_bind ()
    
    local socket = zmq.socket (self.ctx, zmq.REP)
    socket:bind { port = 5555 }
    socket:close ()
end

function T:test_zmq_recv ()
    
    local port, msg = 5555, 'Hello'

    local server = zmq.socket (self.ctx, zmq.REP)
    local client = zmq.socket (self.ctx, zmq.REQ)

    server:bind { port = port }
    client:connect { port = port }
    
    local thread_s = pthread.create (function () return server:recv (10) end)
    
    client:send (msg) -- blocking call, that's why we need to start the server pthread first.
        
    unittest.assert.equals 'Not the same message.' (true, msg, false) (pthread.join (thread_s))

    server:close ()
    client:close ()
end

function T:test_zmq_recv_big_msg_tbl ()
    
    local port = 5555

    local server = zmq.socket (self.ctx, zmq.REP)
    local client = zmq.socket (self.ctx, zmq.REQ)

    server:bind { port = port }
    client:connect { port = port }
    
    local thread_s = pthread.create (function () return server:recv_more { max_bytes = 10, handler = {} } end)
    
    client:send ('Hello', zmq.SNDMORE)
    client:send 'World'
    
    unittest.assert.equals 'Cannot receive message' 
        (true, { 'Hello', 'World' }) (pthread.join (thread_s))

    server:close ()
    client:close ()

end

function T:test_zmq_recv_big_msg_str ()
    
    local port = 5555

    local server  = zmq.socket (self.ctx, zmq.REP)
    local client  = zmq.socket (self.ctx, zmq.REQ)

    server:bind { port = port }
    client:connect { port = port }
    
    local thread_s = pthread.create (function () return server:recv_more { max_bytes = 10 } end)
    
    client:send ('Hello', zmq.SNDMORE)
    client:send (' ', zmq.SNDMORE)
    client:send 'World'
    
    unittest.assert.equals 'Cannot receive message' 
        (true, 'Hello World' ) (pthread.join (thread_s))

    server:close ()
    client:close ()

end

function T:test_zmq_recv_send ()
    
    local port = 5555

    local server = zmq.socket (self.ctx, zmq.REP)
    local client = zmq.socket (self.ctx, zmq.REQ)
    
    server:bind { port = port }
    client:connect { port = port }

    local thread_s = pthread.create (function ()
        local msg = server:recv (10)
        server:send 'world'
        return msg
    end)

    local thread_c = pthread.create (function ()
        client:send 'hello'
        return client:recv (10)
    end)

    local flag_c, msg_from_server = pthread.join (thread_c)
    local flag_s, msg_from_client = pthread.join (thread_s)
    
    unittest.assert.equals 'All ok' (true, true) (flag_s, flag_c)
    unittest.assert.equals 'Cannot receive message' 
        ('hello', 'world') (msg_from_client, msg_from_server)

    
    server:close ()
    client:close ()
end


function T:test_zmq_recv_send_loop ()
    
    local port, n = 5555, 10

    local server = zmq.socket (self.ctx, zmq.REP)
    local client = zmq.socket (self.ctx, zmq.REQ)

    server:bind { port = port }
    client:connect { port = port }

    local thread_s = pthread.create (function ()
        local continue = true
        while continue do
            local msg = server:recv (10)
            if msg == 'quit' then continue = false
            else server:send 'world' end
        end
    end)

    local thread_c = pthread.create (function ()
        local tbl = {}
        for i = 1, n do
            client:send 'hello'
            tbl[i] = client:recv (10)
        end
        client:send 'quit'
        return tbl
    end)
    
    unittest.assert.equals 'Cannot receive message' (true, {
        'world', 'world', 'world', 'world', 'world', 'world', 'world', 'world', 'world', 'world'
    }) (pthread.join (thread_c))

    unittest.assert.istrue 'Cannot receive message' (pthread.join (thread_s))

    server:close ()
    client:close ()

end

function T:test_zmq_recv_pub_sub ()
    
    local port, n = 5555, 10

    local server  = zmq.socket (self.ctx, zmq.PUB)
    local client  = zmq.socket (self.ctx, zmq.SUB)
    local another  = zmq.socket (self.ctx, zmq.SUB)

    local continue = true

    server:bind { port = port }
    client:connect { port = port }
    another:connect { port = port }

    client:subscribe '10001 '
    another:subscribe '10002 '

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
        for i = 1, n do tbl[i] = client:recv (20) end
        return tbl
    end)

    local thread_a = pthread.create (function ()
        local tbl = {}
        for i = 1, n do tbl[i] = another:recv (20) end
        return tbl
    end)

    local flag, tblc = pthread.join (thread_c)
    unittest.assert.equals 'Cannot receive message' (true, n) (flag, #tblc)

    local flag, tbla = pthread.join (thread_a)
    unittest.assert.equals 'Cannot receive message' (true, n) (flag, #tbla)

    continue = false -- stop the server

    unittest.assert.istrue 'Cannot join the publisher pthread.' (pthread.join (thread_s))

    server:close ()
    client:close ()
    another:close ()
end


function T:test_zmq_ventilator ()
    
    local port_server, port_sink = 5557, 5558

    local workers = {}

    local continue = true

    local pth_sink = pthread.create (function () 
        local sink = zmq.socket (self.ctx, zmq.PULL)
        sink:bind { port = port_sink }
        sink:recv (10)
        local total_msec = os.time ()
        for task = 1, 100 do
            sink:recv (10)
            if task % 10 == 0 then print (':') else print ('.') end
        end
        sink:close ()
        continue = false
        return os.time () - total_msec
    end)

    local pth_server = pthread.create (function ()

        local sender  = zmq.socket (self.ctx, zmq.PUSH)
        local sink  = zmq.socket (self.ctx, zmq.PUSH)
    
        sender:bind { port = port_server }
        sink:connect { port = port_sink }

        sink:send '0' -- signals the start of the batch

        local total_msec = 0
        for task = 1, 100 do
            local msec = math.random (100)
            total_msec = total_msec + msec
            sender:send (tostring (msec))
        end
        
        print ('Total elapsed time: ' .. total_msec .. ' msec')

        sender:close ()
        sink:close ()

        return total_msec
    end)

    local function W ()
        local receiver = zmq.socket (self.ctx, zmq.PULL)
        local sender = zmq.socket (self.ctx, zmq.PUSH)
        receiver:connect { port = port_server }
        sender:connect { port = port_sink }
        while continue do
            local msg = receiver:recv (10)
            os.execute ('sleep 0.' .. msg .. 's')
            sender:send ''
        end
        receiver:close ()
        sender:close ()
    end

    for i = 1, 100 do workers[i] = pthread.create (W) end

    print ('sink: ', pthread.join (pth_sink))
    --for i = 1, 10 do print ('worker: ', i, pthread.join (workers[i])) end
    print ('server: ', pthread.join (pth_server))
    
end

print (unittest.api.suite (T))
