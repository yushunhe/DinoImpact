-- Player: free movement upward, lateral steering, and stopping. No reverse.
local Config = require("dino_config")
local I = require("input")
local U = require("util")

local C = Config.player
local P = {
    x = 0, y = 0, vx = 0, vy = 0,
    distance = 0, eggs = 0,
    radius = C.radius,
    alive = true,
    moving = false,
    animT = 0,
    frame = 0,
    id = nil,
    shadowId = nil,
    -- smoothed camera state (the world is endless in every direction)
    cam = { x = 0, y = Config.camera.yOffset, size = Config.camera.size },
}

-- Animation frames, in order. Config entries that are missing (nil) are
-- skipped so an older dino_config.lua still works.
local runSprites = {}
for _, name in ipairs({
    Config.sprites.playerRun0,
    Config.sprites.playerRun1,
    Config.sprites.playerRun2,
    Config.sprites.playerRun3,
}) do
    if name then runSprites[#runSprites + 1] = name end
end
if #runSprites == 0 then runSprites[1] = "dino_run0" end

local idleSprites = {}
for _, name in ipairs({
    Config.sprites.playerIdle,
    Config.sprites.playerIdle2,
}) do
    if name then idleSprites[#idleSprites + 1] = name end
end
if #idleSprites == 0 then idleSprites[1] = "dino_idle" end

local function setPlayerSprite(name)
    if P.spriteName == name then return end
    P.spriteName = name
    if P.id then Host.entity.setSprite(P.id, name) end
end

-- Camera: follows the player on both axes and pulls in slightly at full speed.
local function cameraTarget()
    local run = math.min(1, P.speed() / C.forwardMax)
    return P.x, P.y + Config.camera.yOffset, Config.camera.size - Config.camera.zoomRun * run
end

local function cameraSnap()
    P.cam.x, P.cam.y, P.cam.size = cameraTarget()
    Host.camera.set2d(P.cam.x, P.cam.y, P.cam.size)
end

local function cameraFollow(dt)
    local tx, ty, ts = cameraTarget()
    P.cam.x = U.lerp(P.cam.x, tx, U.expSmooth(Config.camera.followRate, dt))
    P.cam.y = U.lerp(P.cam.y, ty, U.expSmooth(Config.camera.followRate, dt))
    P.cam.size = U.lerp(P.cam.size, ts, U.expSmooth(Config.camera.sizeLerp, dt))
    Host.camera.set2d(P.cam.x, P.cam.y, P.cam.size)
end

function P.clear()
    if P.id then Host.entity.kill(P.id); P.id = nil end
    if P.shadowId then Host.entity.kill(P.shadowId); P.shadowId = nil end
    P.spriteName = nil
end

function P.reset()
    P.x, P.y = 0, 0
    P.vx, P.vy = 0, 0
    P.distance, P.eggs = 0, 0
    P.alive = true
    P.moving = false
    P.animT = 0
    P.frame = 0
    P.spriteName = nil

    P.clear()
    P.shadowId = Host.entity.new(Config.sprites.shadow, P.x, P.y + .04, .2)
    Host.entity.setScale(P.shadowId, 1.05, .9, 1)
    P.id = Host.entity.new(Config.sprites.playerIdle, P.x, P.y, 0)
    Host.entity.setScale(P.id, 1.08, 1.08, 1)
    Host.entity.setRot(P.id, 0, 0, 0)
    cameraSnap()
    setPlayerSprite(Config.sprites.playerIdle)
end

function P.syncVisual()
    if P.id then Host.entity.setPos(P.id, P.x, P.y, 0) end
    if P.shadowId then Host.entity.setPos(P.shadowId, P.x, P.y + .04, .2) end
    cameraSnap()
end

function P.speed()
    return math.sqrt(P.vx * P.vx + P.vy * P.vy)
end

function P.collectEgg()
    P.eggs = P.eggs + 1
end

function P.stop()
    P.vx, P.vy = 0, 0
    P.moving = false
    if P.id then
        Host.entity.setRot(P.id, 0, 0, 0)
        setPlayerSprite(Config.sprites.playerIdle)
    end
end

function P.update(dt)
    if not P.alive then return end

    local h, v = I.h(), I.v()

    -- W/up runs forward; S/down brakes but never reverses.
    if v > .05 then
        P.vy = P.vy + C.forwardAccel * dt
    elseif v < -.05 then
        P.vy = P.vy - C.brake * dt
    else
        P.vy = U.approach(P.vy, 0, C.drag * dt)
    end
    P.vy = U.clamp(P.vy, 0, C.forwardMax)

    if math.abs(h) > .05 then
        P.vx = U.approach(P.vx, h * C.lateralMax, C.lateralAccel * dt)
    else
        P.vx = U.approach(P.vx, 0, C.lateralDrag * dt)
    end

    -- The world is endless to the left and right: x is never clamped.
    P.x = P.x + P.vx * dt

    P.y = P.y + P.vy * dt
    if P.y < 0 then P.y = 0; P.vy = 0 end
    P.distance = math.max(P.distance, P.y)

    local speed = P.speed()
    P.moving = speed > .15

    if P.moving then
        P.animT = P.animT + dt
        if P.animT >= C.animRate then
            P.animT = P.animT - C.animRate
            P.frame = (P.frame + 1) % #runSprites
            setPlayerSprite(runSprites[P.frame + 1])
        end
    else
        P.animT = 0
        setPlayerSprite(Config.sprites.playerIdle)
    end

    -- subtle lean while strafing
    if P.id then
        Host.entity.setRot(P.id, 0, 0, -P.vx * 2.0)
        Host.entity.setPos(P.id, P.x, P.y, 0)
    end
    if P.shadowId then
        local stretch = 1.0 + math.min(.25, speed * .025)
        Host.entity.setPos(P.shadowId, P.x, P.y + .04, .2)
        Host.entity.setScale(P.shadowId, 1.05 * stretch, .9, 1)
    end
    cameraFollow(dt)
end

-- Used on the title screen so the little dinosaur still breathes.
function P.idleAnim(dt)
    P.animT = P.animT + dt
    if P.animT >= .45 then
        P.animT = 0
        P.frame = (P.frame + 1) % #idleSprites
        setPlayerSprite(idleSprites[P.frame + 1])
    end
    if P.id then Host.entity.setRot(P.id, 0, 0, 0) end
    P.syncVisual()
end

return P
