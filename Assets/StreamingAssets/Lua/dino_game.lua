-- DINO IMPACT - state machine and glue. The C# bootstrap calls init/update.
local Config = require("dino_config")
local U = require("util")
local I = require("input")
local fx = require("fx")
local P = require("dino_player")
local W = require("dino_world")
local T = require("dino_track")
local UI = require("dino_ui")

local Game = {
    state = "boot",
    best = 0,
    resultsLock = 0,
    score = 0,
    muted = false,
}

local function clearWorld()
    T.clear()
    W.clear()
    P.clear()
    Host.entity.clear()
end

local function currentScore()
    return math.floor(P.distance + .5) + P.eggs * Config.spawn.eggValue
end

function Game.init()
    UI.init()
    UI.onAction = function(a) Game.onAction(a) end
    Game.best = Host.save.getInt("best", 0)
    UI.setBest(Game.best)
    Host.audio.music(true)
    Host.audio.ambient(true)
    Game.enterMenu()
end

function Game.enterMenu()
    clearWorld()
    Game.state = "menu"
    Game.resultsLock = 0
    P.reset()
    W.reset(P)
    UI.setBest(Game.best)
    UI.showMenu(true)
    UI.showHud(false)
    UI.showPause(false)
    UI.showResults(false)
    Host.ui.setVignette(false)
    UI.transitionIn(.3)
end

function Game.startRun()
    clearWorld()
    P.reset()
    W.reset(P)
    T.reset(P)
    Game.state = "playing"
    Game.resultsLock = 0
    Game.score = 0
    UI.resetRun()
    UI.updateHud(P)
    Host.ui.setVignette(false)
end

function Game.pause()
    if Game.state ~= "playing" then return end
    Game.state = "paused"
    UI.showPauseOverlay()
    fx.sound("tick", .6)
end

function Game.resume()
    if Game.state ~= "paused" then return end
    Game.state = "playing"
    UI.showPause(false)
    UI.showHud(true)
end

function Game.finish(reason)
    if Game.state == "over" then return end
    Game.state = "over"
    Game.score = currentScore()
    P.alive = false
    P.stop()
    local newBest = Game.score > Game.best
    if newBest then
        Game.best = Game.score
        Host.save.setInt("best", Game.best)
    end
    UI.setBest(Game.best)

    -- impact juice: freeze the frame, shake, flash, particles, then show results
    fx.sound("crash", .9)
    fx.shake(Config.juice.shake, Config.juice.shakeTime)
    fx.event("impact", P.x, P.y + .4, 1.5)
    UI.flash("#FFF3D8", .3)
    Host.ui.setVignette(true)

    Game.resultsLock = .45 + Config.juice.hitStop
    local data = {
        title = "GAME OVER",
        reason = reason or "You hit an obstacle.",
        score = Game.score,
        distance = P.distance,
        eggs = P.eggs,
        best = Game.best,
        newBest = newBest,
    }
    fx.after(Config.juice.hitStop, function()
        if Game.state ~= "over" then return end
        UI.showResultsPanel(data)
        fx.sound("gameover", .7)
        Host.ui.setVignette(false)
    end, "showresults")
end

function Game.onAction(a)
    if a == "start" then
        if Game.state == "menu" then Game.startRun() end
    elseif a == "resume" then
        Game.resume()
    elseif a == "restart" or a == "retry" then
        if Game.state == "paused" or Game.state == "over" then Game.startRun() end
    elseif a == "menu" then
        Game.enterMenu()
    end
end

function Game.update(dt)
    fx.update(dt)
    UI.update(dt)

    if I.mute() then
        Game.muted = not Game.muted
        Host.audio.mute(Game.muted)
    end

    if Game.state == "menu" then
        P.idleAnim(dt)
        UI.updateMenu(dt)
        UI.handleNav()
        if I.confirm() then UI.activateSelected() end
        return
    end

    if Game.state == "playing" then
        if I.pause() then
            Game.pause()
            return
        end
        if I.restart() then
            Game.startRun()
            return
        end

        P.update(dt)
        W.update(dt, P)
        local hit = T.update(dt, P)
        UI.updateHud(P)
        if hit then
            Game.finish("You hit an obstacle.")
        end
        return
    end

    if Game.state == "paused" then
        UI.handleNav()
        if I.pause() then
            Game.resume()
        elseif I.restart() then
            Game.startRun()
        elseif I.confirm() then
            UI.activateSelected()
        end
        return
    end

    if Game.state == "over" then
        if Game.resultsLock > 0 then
            Game.resultsLock = Game.resultsLock - dt
        else
            UI.handleNav()
            if I.confirm() then
                UI.activateSelected()
            elseif I.restart() then
                Game.startRun()
            elseif I.back() then
                Game.enterMenu()
            end
        end
    end
end

-- Debug hooks used by the headless Lua tests --------------------------------

function Game.debugState()
    return {
        state = Game.state,
        x = P.x,
        y = P.y,
        vx = P.vx,
        vy = P.vy,
        distance = P.distance,
        eggs = P.eggs,
        score = currentScore(),
        best = Game.best,
        entities = Host.entity.count(),
        track = #T.items,
        bestSaved = Host.save.getInt("best", 0),
    }
end

function Game.debugStart()
    Game.startRun()
end

function Game.debugSetPlayer(fields)
    for k, v in pairs(fields) do
        if P[k] ~= nil then P[k] = v end
    end
    P.syncVisual()
end

function Game.debugSpawnObstacle(kind, x, y)
    return T.addObstacle(kind or "rock", x or P.x, y or (P.y + 1))
end

function Game.debugSpawnEgg(x, y)
    return T.addEgg(x or P.x, y or (P.y + 1))
end

function Game.debugGetPlayer()
    return P
end

function Game.debugClearTrack()
    T.clear()
    T.nextObstacle = 1e9
    T.nextEgg = 1e9
end

Game.debugGetTrack = function() return T end

return Game
