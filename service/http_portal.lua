local skynet = require "skynet"
local socket = require "skynet.socket"
require "skynet.manager"


local port, body_size_limit = ...

local CMD = {}
local agent = {}
local update_count = 0
local thread = tonumber(skynet.getenv("thread")) or 1
local listen_id 
local agent_num = thread * 2

function CMD.update()                           -- 热更新
    local old_agent = agent
    local new_agent = {}
    update_count = update_count + 1             -- 更新次数
    for i = 1, agent_num do 
        new_agent[i] = skynet.newservice("http_portal_agent", body_size_limit, "update:" .. update_count)
    end
    
    agent = new_agent
    for _, v in ipairs(old_agent) do
        skynet.send(v, "lua", "exit")
    end
end

function CMD.exit()
    socket.close(listen_id)
    for _, v in ipairs(agent) do
        skynet.send(v, "lua", "exit")
    end
end

skynet.start(function()
    skynet.register(SERVICE_NAME)
    body_size_limit = body_size_limit or 8192   
    for i= 1, agent_num do
        agent[i] = skynet.newservice("http_portal_agent", body_size_limit,  "update:" .. update_count)
    end

    skynet.dispatch("lua", function(session, _, command, ...)
        local f = CMD[command]
        if session == 0 then
            return f(...)
        end
        skynet.ret(skynet.pack(f(...)))
    end)
    
    local balance = 1
    local id = socket.listen("0.0.0.0", port)
    listen_id = id
    skynet.error("Listen web port ", port)
    socket.start(id , function(fd, addr)
        skynet.send(agent[balance], "lua", "socket", fd, addr)
        balance = balance + 1
        if balance > #agent then
            balance = 1
        end
    end)
end)
