#!/usr/bin/env lua

local args = {...}
local function exec(cmd)
        os.execute(cmd)
end

local function playSound()
        exec("mpv /home/jrestivo/.config/sway/gilfoyle.m4a & disown")
end

local function playSoundAlt()
        exec("mpv /home/jrestivo/.config/sway/discordo.mp3 --volume=60 & disown")
end

local function discord(b,s)
        --local usr = string.lower(b)
        --local msg = s
        --local ignored = {"nulluser","zack"}
        --local IGN=false
        --for k,v in pairs(ignored) do
                --if usr:find(string.lower(v)) then
                        --IGN=true
                        --break
                --end
        --end
        --if not IGN then
        exec("mpv /home/jrestivo/.config/sway/gilfoyle.m4a & disown")
        --end
end
local function slack()
        playSound()
end


local app = args[1]
local body = args[2]
local summary = args[3]
local apps = {Slack=slack,discord=discord}
if apps[args[1]] then
        apps[app](body,summary)
end
local file = io.open("/tmp/notif","a")
file:write(app.." "..body.." "..summary.."\n")
file:flush()
file:close()
