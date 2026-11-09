-- Mode rules: classic kraken chase, time trial clock, zigzag streaks, collector stats.
local Config = require("config")
local U = require("util")
local W = require("world")
local Player = require("player")

local M = {
    mode = "classic",
    events = {},
    timeLeft = 0,
    gates = 0,
    goal = 0,
    streak = 0,
    bestStreak = 0,
    coins = 0,
    finished = false,
    finishReason = nil,
    kraken = nil,
    krakenTimer = 0,
    warning = false,
    krakenDistance = 0,
}

local function push(kind, text, color)
    M.events[#M.events + 1] = { kind = kind, text = text, color = color }
end

function M.drainEvents()
    local events = M.events
    M.events = {}
    return events
end

local function cfg()
    return Config.modes[M.mode] or Config.modes.classic
end

function M.cleanup()
    if M.kraken then
        Host.entity.kill(M.kraken.id)
        M.kraken = nil
    end
    M.warning = false
    M.krakenDistance = 0
end

function M.start(mode)
    M.cleanup()
    M.mode = mode or "classic"
    M.events = {}
    M.timeLeft = cfg().timer or 0
    M.gates = 0
    M.goal = cfg().gateGoal or 0
    M.streak = 0
    M.bestStreak = 0
    M.coins = 0
    M.finished = false
    M.finishReason = nil
    M.krakenTimer = (M.mode == "classic") and 22 or 0
    M.warning = false
end

function M.finish(reason)
    if M.finished then return end
    M.finished = true
    M.finishReason = reason
end

function M.isFinished()
    return M.finished
end

local function spawnKraken(player)
    local fx, fz = math.sin(player.heading), math.cos(player.heading)
    local x = player.x - fx * 42
    local z = player.z - fz * 42
    local y = W.height(x, z) + .1
    local id = Host.entity.new("kraken", x, y, z, 0)
    Host.entity.setScale(id, 1.15)
    Host.entity.setAnim(id, .25)
    Host.audio.play("kraken", 1.0)
    M.kraken = {
        id = id,
        x = x,
        z = z,
        y = y,
        aggro = .25,
        roar = 0,
    }
    M.warning = false
    push("kraken", "THE KRAKEN RISES", Config.colors.red)
end

local function updateKraken(dt, player)
    local k = M.kraken
    if not k then return end
    local dx, dz = player.x - k.x, player.z - k.z
    local dist = math.sqrt(dx * dx + dz * dz)
    M.krakenDistance = dist

    local desired = 24
    local extra = U.clamp((dist - desired) * .38, -6, 16)
    if dist > 150 then extra = 30 end
    local speed = math.max(6, player.speed + extra)
    if dist > .05 then
        local step = math.min(speed * dt, dist)
        k.x = k.x + dx / dist * step
        k.z = k.z + dz / dist * step
    end

    k.y = W.height(k.x, k.z) + .1 + math.sin(Host.time() * 1.6) * .12
    Host.entity.setPos(k.id, k.x, k.y, k.z)
    Host.entity.setRot(k.id, 0, math.deg(U.atan2(dx, dz)), 0)

    local aggro = U.clamp01(1 - (dist - 6) / 55)
    if math.abs(aggro - k.aggro) > .02 then
        k.aggro = aggro
        Host.entity.setAnim(k.id, aggro)
    end

    if dist < 4.3 and player.alive then
        if Player.hit("kraken") then
            -- the hit buys the surfer a little room
            local fx, fz = math.sin(player.heading), math.cos(player.heading)
            k.x = player.x - fx * 23
            k.z = player.z - fz * 23
            k.y = W.height(k.x, k.z) + .1
            Host.entity.setPos(k.id, k.x, k.y, k.z)
            k.aggro = .2
            Host.entity.setAnim(k.id, .2)
            push("krakenHit", "THE KRAKEN LUNGED", Config.colors.red)
        end
    end
end

function M.update(dt, player)
    if M.finished then return end

    if M.mode == "classic" then
        if not M.kraken then
            M.krakenTimer = M.krakenTimer - dt
            if M.krakenTimer <= 6 and M.krakenTimer > 0 and not M.warning then
                M.warning = true
                push("warning", "SOMETHING STIRS BENEATH...", Config.colors.red)
            end
            if M.krakenTimer <= 0 then
                spawnKraken(player)
            end
        else
            updateKraken(dt, player)
        end
    elseif M.mode == "timeTrial" then
        M.timeLeft = M.timeLeft - dt
        if M.timeLeft <= 0 then
            M.timeLeft = 0
            M.finish("timeout")
        end
    end
end

function M.handleEvent(ev)
    local c = cfg()
    if ev.kind == "coin" then
        M.coins = M.coins + 1
        if M.mode == "timeTrial" then
            M.timeLeft = M.timeLeft + 1
        end
    elseif ev.kind == "checkpoint" then
        if M.mode == "timeTrial" then
            M.gates = M.gates + 1
            M.timeLeft = M.timeLeft + (c.gateTime or 8)
            Player.addScore("gate", c.gateScore or 150)
            push("checkpoint", "CHECKPOINT  +" .. (c.gateTime or 8) .. "s", Config.colors.accent2)
            if M.gates >= M.goal and M.goal > 0 then
                M.finish("course")
            end
        end
    elseif ev.kind == "checkpointMissed" then
        if M.mode == "timeTrial" then
            push("miss", "CHECKPOINT MISSED", Config.colors.red)
        end
    elseif ev.kind == "gatePassed" then
        if M.mode == "zigzag" then
            M.streak = M.streak + 1
            if M.streak > M.bestStreak then M.bestStreak = M.streak end
            local accuracy = math.floor((1 - U.clamp01((ev.lateral or 0) / 7.7)) * 100)
            local points = 100 + (M.streak - 1) * 25 + accuracy
            Player.addScore("gate", points)
            push("gate", "STREAK x" .. M.streak .. "  +" .. U.comma(points), Config.colors.accent2)
        end
    elseif ev.kind == "gateMissed" then
        if M.mode == "zigzag" then
            if M.streak > 0 then
                push("miss", "GATE MISSED  -  STREAK LOST", Config.colors.red)
            end
            M.streak = 0
        end
    elseif ev.kind == "obstacleHit" then
        if M.mode == "timeTrial" then
            M.timeLeft = math.max(0, M.timeLeft - 3)
            push("timeLost", "-3s", Config.colors.red)
        end
    end
end

function M.updateHud()
    M.gateInfo = nil
end

function M.hud()
    return {
        mode = M.mode,
        timeLeft = M.timeLeft,
        gates = M.gates,
        goal = M.goal,
        streak = M.streak,
        bestStreak = M.bestStreak,
        coins = M.coins,
        krakenActive = M.kraken ~= nil,
        krakenWarning = M.warning or (M.kraken == nil and M.mode == "classic" and M.krakenTimer <= 6 and M.krakenTimer > 0),
        krakenDistance = M.krakenDistance,
        finished = M.finished,
        finishReason = M.finishReason,
    }
end

return M
