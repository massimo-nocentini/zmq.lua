
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
    -- very simple test, just to check if the function is working. Fluid interface.
    zmq.socket (self.ctx, zmq.REP):bind { port = 5555 }:close ()
end

function T:test_zmq_recv ()
    
    local port, msg = 5555, 'Hello'

    local client = zmq.socket (self.ctx, zmq.REQ):connect { port = port }:send (msg)
    local server = zmq.socket (self.ctx, zmq.REP):bind { port = port }

    unittest.assert.equals 'Not the same message.' (msg, false) (server:recv (10))

    server:close ()
    client:close ()
end

function T:test_zmq_recv_pthreaded ()
    
    local port, msg = 5555, 'Hello'

    local thread_s = pthread.create (function () 
        local server = zmq.socket (self.ctx, zmq.REP):bind { port = port }
        local more, v = server:recv (10)
        server:close ()
        return more, v
    end)
    
    local client = zmq.socket (self.ctx, zmq.REQ):connect { port = port }:send (msg)
        
    unittest.assert.equals 'Not the same message.' (true, msg, false) (pthread.join (thread_s))

    client:close ()
end

function T:test_zmq_recv_big_msg_tbl ()
    
    local port = 5555

    local server = zmq.socket (self.ctx, zmq.REP)
    local client = zmq.socket (self.ctx, zmq.REQ)

    server:bind { port = port }
    client:connect { port = port }
    
    local thread_s = pthread.create (function () return server:recv_more { max_bytes = 10, handler = {} } end)
    
    client
        :send ('Hello', zmq.SNDMORE)
        :send 'World'
    
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


function T:test_zmq_msg_send_without_threads ()

    local port = 5555

    local client  = zmq.socket (self.ctx, zmq.REQ):connect { port = port }

    client:send_msg ('Hello', zmq.SNDMORE)
    client:send_msg (' ', zmq.SNDMORE)
    client:send_msg 'World'

    local server  = zmq.socket (self.ctx, zmq.REP):bind { port = port }
    
    unittest.assert.equals 'Cannot receive message' 'Hello World' (server:recv_msg_more ())

    server:close ()
    client:close ()

    return [[

        This test is to check if the zmq_msg_send function is working properly.
        The zmq_msg_send function is a wrapper around the zmq_send function, and
        it is used to send a message part to a socket. The zmq_msg_send function
        is a non-blocking function, and it returns the number of bytes sent, or
        -1 if an error occurred.

    ]]

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


function T:ftest_zmq_ventilator ()
    
    local port_server, port_sink, nworkers, ntasks = 5557, 5558, 10, 100

    -- for the sink
    local sink_receiver_socket = zmq.socket (self.ctx, zmq.PULL):bind { port = port_sink }

    -- for the server
    local ventilator_sender_socket  = zmq.socket (self.ctx, zmq.PUSH):bind { port = port_server }
    local ventilator_sender_sink  = zmq.socket (self.ctx, zmq.PUSH):connect { port = port_sink }

    -- for the workers
    local w_sockets = {}
    for i = 1, nworkers do
        w_sockets[i] = {
            ventilator = zmq.socket (self.ctx, zmq.PULL):connect { port = port_server },
            sink = zmq.socket (self.ctx, zmq.PUSH):connect { port = port_sink },
        }
    end
    
    local workers = {}

    local continue = true


    local function W (i)
        return function ()

            local receiver = w_sockets[i].ventilator
            local sender = w_sockets[i].sink

            while continue do
                local msg = receiver:recv (10)
                print ('worker: ' .. i .. ' received: ' .. msg)
                os.execute ('sleep 0.' .. msg .. 's')
                sender:send ''
            end
            
            receiver:close ()
            sender:close ()
        end
    end

    for i = 1, nworkers do workers[i] = pthread.create (W (i)) end

    os.execute ('sleep 1s')

    local pth_sink = pthread.create (function ()
        
        local sink = sink_receiver_socket
        assert (sink:recv (10) == '0')
        local total_msec = os.time ()
        for task = 1, ntasks do sink:recv (10) end
        continue = false
        return os.time () - total_msec
    end)
    
    local pth_server = pthread.create (function ()

        local sender  = ventilator_sender_socket
        local sink  = ventilator_sender_sink

        sink:send '0' -- signals the start of the batch

        local total_msec = 0
        for task = 1, ntasks do
            local msec = math.random (100)
            total_msec = total_msec + msec
            sender:send (tostring (msec))
        end

        return total_msec
    end)

    print ('sink: ', pthread.join (pth_sink))
    print ('server: ', pthread.join (pth_server))

    for i = 1, nworkers do w_sockets[i].ventilator:close (); w_sockets[i].sink:close () end

    sink_receiver_socket:close ()
    ventilator_sender_socket:close ()
    ventilator_sender_sink:close ()
    
end

print (unittest.api.suite (T))
