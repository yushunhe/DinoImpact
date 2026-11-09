-- State machine and glue. The C# bootstrap calls Game.init() and Game.update(dt).
local Config = require("config")
local U = require("util")
local I = require("input")
local E = require("entities")
local W = require("world")
local P = require("player")
local O = require("obstacles")
local M = require("modes")
local UI = require("ui")

local Game = {
    state = "boot",
    ready = false,
    modeKey = nil,
    muted = false,
    menuAngle = 0,
    menuIndex = 1,
    countdown = 0,
    countdownNum = 3,
    go = false,
    goTimer = 0,
    transitionT = 0,
    resultsLock = 0,
    pending = nil,
}

local function loadBests()
    local bests = {}
    for i = 1, #Config.modeOrder do
        local key = Config.modeOrder[i]
        bests[key] = Host.save.getInt("best_" .. key, 0)
    end
    return bests
end

local function setMenuSelection(i)
    UI.setMenuSelection(i)
    Game.menuIndex = UI.getMenuSelection()
end

local function beginTransition(kind, mode)
    if Game.state == "transition" then return end
    Game.pending = { kind = kind, mode = mode }
    Game.state = "transition"
    Game.transitionT = .3
    UI.setPauseVisible(false)
    UI.fadeTo(1, "#000000", .3)
end

-- lifecycle ----------------------------------------------------------------

function Game.startRun(modeKey)
    if not Config.modes[modeKey] then modeKey = "classic" end
    Game.modeKey = modeKey

    M.cleanup()
    P.stopVisual()
    E.clear()

    P.reset(modeKey)
    O.reset(modeKey)
    M.start(modeKey)
    W.reset(P)

    UI.resetRun()
    Host.audio.music(true)
    Host.audio.ambient(true)
    Host.ui.setVignette(false)
    UI.vig = false

    Game.state = "countdown"
    Game.countdown = 3.0
    Game.countdownNum = 3
    Game.go = false
    Game.goTimer = 0
    Game.resultsLock = 0
    UI.showCountdown("3")
    UI.toast(Config.modes[modeKey].blurb, Config.colors.accent2, 2.2)
    Host.audio.play("tick", .7)
end

function Game.enterMenu()
    Game.state = "menu"
    Game.modeKey = nil
    M.cleanup()
    P.stopVisual()
    E.clear()

    UI.setHudVisible(false)
    UI.setPauseVisible(false)
    UI.setResultsVisible(false)
    UI.setMenuVisible(true)
    UI.clearToasts()
    UI.hideCountdown()
    Host.ui.setVignette(false)
    UI.vig = false

    UI.setBests(loadBests())
    setMenuSelection(Game.menuIndex or 1)

    W.menuReset({ x = 0, z = 0 })
    Host.audio.music(true)
    Host.audio.ambient(true)
    Game.menuAngle = math.random() * U.tau
end

function Game.init()
    UI.init()
    UI.onAction = function(a) Game.onAction(a) end
    Game.muted = Host.save.getInt("muted", 0) == 1
    Host.audio.mute(Game.muted)
    Host.audio.music(true)
    Host.audio.ambient(true)
    Game.ready = true
    Game.enterMenu()
    UI.fadeTo(0, "#000000", 1.0)
end

-- pause --------------------------------------------------------------------

function Game.enterPause()
    Game.state = "paused"
    UI.setPauseSelection(1)
    UI.setPauseVisible(true)
    Host.audio.play("click", .8)
end

function Game.resume()
    UI.setPauseVisible(false)
    Game.state = "playing"
    UI.hideCountdown()
end

local function pauseAction(i)
    if i == 1 then
        Game.resume()
    elseif i == 2 then
        beginTransition("run", Game.modeKey)
    else
        beginTransition("menu")
    end
end

-- results ------------------------------------------------------------------

function Game.finishRun()
    if Game.state == "results" then return end
    Game.state = "results"
    P.stopVisual()

    local win = M.finishReason == "course"
    local score = P.totalScore()
    local key = Game.modeKey or M.mode
    local oldBest = Host.save.getInt("best_" .. key, 0)
    local newBest = score > oldBest and score > 0
    if newBest then
        Host.save.setInt("best_" .. key, score)
    end
    if key == "zigzag" then
        local bs = Host.save.getInt("bestStreak_zigzag", 0)
        if M.bestStreak > bs then Host.save.setInt("bestStreak_zigzag", M.bestStreak) end
    end

    local title, reason
    if win then
        title = "COURSE CLEAR"
        reason = "ALL " .. M.goal .. " CHECKPOINTS CLEARED"
    elseif M.mode == "timeTrial" then
        title = "TIME'S UP"
        reason = "CHECKPOINTS " .. M.gates .. " / " .. M.goal
    else
        title = "WIPEOUT"
        if M.mode == "classic" then
            reason = P.lastHit == "kraken" and "THE KRAKEN GOT YOU" or "OUT OF LIVES"
        elseif M.mode == "zigzag" then
            reason = "BEST STREAK x" .. M.bestStreak
        else
            reason = "COINS COLLECTED " .. P.tokens
        end
    end

    local tricks = math.floor(P.trickScore / Config.player.trickPoints)
    local detail
    if M.mode == "timeTrial" then
        detail = "CHECKPOINTS " .. M.gates .. " / " .. M.goal .. "    COINS " .. P.tokens
    elseif M.mode == "zigzag" then
        detail = "DISTANCE " .. U.comma(P.distance) .. " m    BEST STREAK x" .. M.bestStreak .. "    COINS " .. P.tokens
    elseif M.mode == "collector" then
        detail = "COINS " .. P.tokens .. "    DISTANCE " .. U.comma(P.distance) .. " m"
    else
        detail = "DISTANCE " .. U.comma(P.distance) .. " m    COINS " .. P.tokens .. "    TRICKS " .. tricks
    end

    UI.setHudVisible(false)
    UI.setPauseVisible(false)
    UI.showResults({
        title = title,
        reason = reason,
        score = score,
        detail = detail,
        best = math.max(oldBest, score),
        newBest = newBest,
        win = win,
    })
    Game.resultsLock = .45
    Host.audio.music(false)
    Host.audio.play(win and "win" or "gameover", 1.0)
end

local function resultsAction(i)
    if i == 1 then
        beginTransition("run", Game.modeKey)
    else
        beginTransition("menu")
    end
end

-- action routing (mouse + keyboard) ---------------------------------------

function Game.onAction(a)
    if Game.state == "menu" and a:sub(1, 5) == "mode:" then
        local key = a:sub(6)
        if Config.modes[key] then beginTransition("run", key) end
    elseif Game.state == "paused" then
        if a == "resume" then Game.resume()
        elseif a == "restart" then beginTransition("run", Game.modeKey)
        elseif a == "menu" then beginTransition("menu") end
    elseif Game.state == "results" then
        if Game.resultsLock > 0 then return end
        if a == "retry" then beginTransition("run", Game.modeKey)
        elseif a == "menu" then beginTransition("menu") end
    end
end

-- per-state updates ---------------------------------------------------------

local function updateMenu(dt)
    Game.menuAngle = Game.menuAngle + dt * .05
    local a = Game.menuAngle
    local r = 33 + math.sin(a * 1.3) * 3
    Host.camera.set(math.sin(a) * r, 11 + math.sin(a * .9) * 1.4, math.cos(a) * r, 0, 2.0, 0, 55)
    W.update(dt, { x = 0, z = 0 }, false)

    if I.up() or I.left() then
        setMenuSelection(UI.getMenuSelection() - 1)
        Host.audio.play("click", .5)
    elseif I.down() or I.right() then
        setMenuSelection(UI.getMenuSelection() + 1)
        Host.audio.play("click", .5)
    end
    for n = 1, #Config.modeOrder do
        if I.number(n) then
            beginTransition("run", Config.modeOrder[n])
            return
        end
    end
    if I.confirm() then
        local key = Config.modeOrder[UI.getMenuSelection()]
        beginTransition("run", key)
    end
end

local function updateTransition(dt)
    Game.transitionT = Game.transitionT - dt
    if Game.transitionT > 0 then return end
    local p = Game.pending
    Game.pending = nil
    if p then
        if p.kind == "run" then
            Game.startRun(p.mode)
        else
            Game.enterMenu()
        end
    end
    UI.fadeTo(0, "#000000", .5)
end

local function updateCountdown(dt)
    W.update(dt, P, false)
    P.updateCamera(dt, false)
    UI.updateHud(P, M, dt)
    Game.countdown = Game.countdown - dt

    if Game.countdown > 0 then
        local n = math.ceil(Game.countdown)
        if n ~= Game.countdownNum then
            Game.countdownNum = n
            UI.showCountdown(tostring(n))
            Host.audio.play("tick", .7)
        end
    elseif not Game.go then
        Game.go = true
        Game.goTimer = .7
        UI.showCountdown("GO!")
        Host.audio.play("tick", 1.0)
        Game.state = "playing"
    end
end

local function consumeEvents()
    local pevents = P.drainEvents()
    for i = 1, #pevents do
        local ev = pevents[i]
        UI.toast(ev.text, ev.color, ev.duration)
    end

    local oevents = O.drainEvents()
    for i = 1, #oevents do
        local ev = oevents[i]
        M.handleEvent(ev)
        if ev.kind == "ramp" then
            UI.toast("RAMP!", Config.colors.accent2, .8)
        end
    end

    local mevents = M.drainEvents()
    for i = 1, #mevents do
        local ev = mevents[i]
        UI.toast(ev.text, ev.color, 1.6)
    end
end

local function updatePlaying(dt)
    if Game.goTimer > 0 then
        Game.goTimer = Game.goTimer - dt
        if Game.goTimer <= 0 then UI.hideCountdown() end
    end

    if I.pause() then Game.enterPause(); return end
    if I.restart() then beginTransition("run", Game.modeKey); return end

    P.update(dt)
    O.update(dt, P, Game.modeKey)
    E.update(dt, P)
    M.update(dt, P)
    consumeEvents()
    UI.updateHud(P, M, dt)
    W.update(dt, P, true)

    if M.finished then Game.finishRun(); return end
    if not P.alive then Game.finishRun(); return end
end

local function updatePaused(dt)
    if I.pause() or I.back() then
        Game.resume()
        return
    end
    if I.restart() then
        beginTransition("run", Game.modeKey)
        return
    end
    if I.up() then
        UI.setPauseSelection(UI.getPauseSelection() - 1)
        Host.audio.play("click", .5)
    elseif I.down() then
        UI.setPauseSelection(UI.getPauseSelection() + 1)
        Host.audio.play("click", .5)
    end
    if I.confirm() then pauseAction(UI.getPauseSelection()) end
    UI.updateHud(P, M, dt)
end

local function updateResults(dt)
    if Game.resultsLock > 0 then
        Game.resultsLock = Game.resultsLock - dt
    else
        if I.restart() then
            beginTransition("run", Game.modeKey)
            return
        end
        if I.back() then
            beginTransition("menu")
            return
        end
        if I.up() or I.left() then
            UI.setResultsSelection(UI.getResultsSelection() - 1)
            Host.audio.play("click", .5)
        elseif I.down() or I.right() then
            UI.setResultsSelection(UI.getResultsSelection() + 1)
            Host.audio.play("click", .5)
        end
        if I.confirm() then resultsAction(UI.getResultsSelection()) end
    end
    W.update(dt, P, false)
end

-- main update ----------------------------------------------------------------

function Game.update(dt)
    if not Game.ready then return end
    dt = U.clamp(dt, 0, .05)

    if I.mute() then
        Game.muted = not Game.muted
        Host.audio.mute(Game.muted)
        Host.save.setInt("muted", Game.muted and 1 or 0)
        UI.toast(Game.muted and "SOUND OFF" or "SOUND ON", Config.colors.muted, 1.0)
    end

    UI.update(dt)

    if Game.state == "menu" then
        updateMenu(dt)
    elseif Game.state == "transition" then
        updateTransition(dt)
    elseif Game.state == "countdown" then
        updateCountdown(dt)
    elseif Game.state == "playing" then
        updatePlaying(dt)
    elseif Game.state == "paused" then
        updatePaused(dt)
    elseif Game.state == "results" then
        updateResults(dt)
    end
end

-- debug / test hooks ---------------------------------------------------------

function Game.debugStart(mode)
    Game.startRun(mode or "classic")
    Game.state = "playing"
    Game.go = false
    Game.goTimer = 0
    UI.hideCountdown()
    return Game.state
end

function Game.debugState()
    return {
        state = Game.state,
        mode = Game.modeKey,
        score = P.totalScore(),
        lives = P.lives,
        distance = P.distance,
        coins = P.tokens,
        timeLeft = M.timeLeft,
        gates = M.gates,
        streak = M.streak,
        finished = M.finished,
        finishReason = M.finishReason,
        entities = E.count(),
    }
end

function Game.debugSetPlayer(fields)
    for k, v in pairs(fields) do
        if P[k] ~= nil then P[k] = v end
    end
end

function Game.debugAdvance(seconds)
    local left = math.max(0, seconds or 0)
    while left > 0 do
        local step = math.min(.05, left)
        Game.update(step)
        left = left - step
    end
    return Game.debugState()
end

function Game.debugSpawn(kind, dist)
    local d = dist or 12
    local x = P.x + math.sin(P.heading) * d
    local z = P.z + math.cos(P.heading) * d
    local obj = E.new(kind, x, z, { float = 0, tilt = false })
    return obj.id
end

function Game.debugFinish(reason)
    M.finish(reason or "timeout")
    Game.finishRun()
    return Game.state
end

function Game.debugGetPlayer()
    return P
end

function Game.debugGetModes()
    return M
end

return Game
