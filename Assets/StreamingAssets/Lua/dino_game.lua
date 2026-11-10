-- DINO IMPACT - state machine and glue. The C# bootstrap calls init/update.
local Config = require("dino_config")
local U = require("util")
local I = require("input")
local fx = require("fx")
local P = require("dino_player")
local W = require("dino_world")
local T = require("dino_track")
local Dino = require("dino_dinos")
local M = require("dino_mount")
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
    Dino.clear()
    W.clear()
    P.clear()
    Host.entity.clear()
end

local function currentScore()
    local S = Config.spawn
    return math.floor(P.distance + .5) + P.eggs * S.eggValue
        + Dino.kills * S.killValue + M.mountCount * S.mountValue
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
    M.reset(P)
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
    M.reset(P)              -- default mount: compsognathus (1.2.7)
    W.reset(P)
    T.reset(P)
    T.onPickup = function(kind) M.onFruit(kind) end
    Game.state = "playing"
    Game.resultsLock = 0
    Game.score = 0
    UI.resetRun()
    UI.updateHud(P, M)
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
        reason = reason or P.deathReason or "You hit an obstacle.",
        score = Game.score,
        distance = P.distance,
        eggs = P.eggs,
        kills = Dino.kills,
        mounts = M.mountCount,
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
        T.update(dt, P)      -- obstacles, items, enemies, arrows
        M.update(dt, P, T)   -- mount prompt, J swap, Space skill, passives
        UI.updateHud(P, M)

        if not P.alive then
            Game.finish(P.deathReason)
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
        heading = P.heading,
        distance = P.distance,
        hp = P.hp,
        eggs = P.eggs,
        arrows = P.arrows,
        kills = Dino.kills,
        mounts = M.mountCount,
        mount = M.current.key,
        uses = M.current.uses,
        score = currentScore(),
        best = Game.best,
        entities = Host.entity.count(),
        track = #T.items,
        enemies = Dino.countEnemies(),
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

function Game.debugSpawnMount(key, x, y)
    return T.addSleepDino(key or "trike", x or (P.x + 1), y or (P.y + 1))
end

function Game.debugSpawnEnemy(kind, x, y)
    Dino.spawnEvent(kind, P, y or (P.y + 1))
    -- for tests: reposition the last spawned event exactly where asked
    local last = Dino.enemies[#Dino.enemies]
    if last and x then last.x = x end
    return last
end

function Game.debugGetPlayer()
    return P
end

function Game.debugClearTrack()
    T.clear()
    Dino.clear()
    T.nextObstacle = 1e9
    T.nextEgg = 1e9
    T.nextEnemy = 1e9
end

-- Re-arm the spawn director after debugClearTrack, so a test run can watch
-- natural rows appear (row placement tests, long-run sims).
-- what = "all" (default) | "eggs" | "obstacles" | "enemies"
function Game.debugEnableSpawning(what)
    what = what or "all"
    if what == "all" or what == "eggs" then T.nextEgg = P.y + 4.5 end
    if what == "all" or what == "obstacles" then
        T.nextObstacle = P.y + Config.spawn.safeStart
    end
    if what == "all" or what == "enemies" then
        T.nextEnemy = P.y + Config.spawn.safeStart + 14
    end
end

Game.debugGetTrack = function() return T end
Game.debugGetDinos = function() return Dino end
Game.debugGetMount = function() return M end

return Game
