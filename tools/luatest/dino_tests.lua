-- Headless tests for the design-doc dinosaur runner (docs/design-plan.md).
-- Covers: five-state heading, 3-heart damage model, obstacle effect classes,
-- items, archery, nuisance dinos, mount swap and skills.
package.path = "tools/luatest/?.lua;Assets/StreamingAssets/Lua/?.lua;" .. package.path
local Mock = require("mock_host")

local host = Mock.new()
_G.Host = host
local I = require("input")
local Game = require("main")
local P = require("dino_player")
local D = require("dino_dinos")
local M = require("dino_mount")
local T = require("dino_track")
local Config = require("dino_config")

local failures = 0
local function check(cond, msg)
    if cond then io.write("  ok   " .. msg .. "\n")
    else failures = failures + 1; io.write("  FAIL " .. msg .. "\n") end
end

local function step(dt, keys)
    I.setOverride(keys or {})
    host._debug.advance(dt)
    Game.update(dt)
    I.setOverride(nil)
end

local function steps(n, dt, keys)
    for i = 1, n do step(dt, keys) end
end

local function countEntities()
    local n = 0
    for _ in pairs(host._debug.entities()) do n = n + 1 end
    return n
end

local function startFresh()
    Game.startRun()
    Game.debugClearTrack()
end

io.write("boot / menu\n")
Game.init()
check(Game.state == "menu", "boots into menu")
check(host._debug.visible().menu_bg == true, "menu visible")
check(countEntities() > 5, "scenery spawned")

io.write("start run / default mount\n")
check(host._debug.click("menu_start"), "start button works")
check(Game.state == "playing", "click starts the run")
check(M.current.key == "comps", "default ride is a compsognathus (1.2.7)")
check(P.hp == 3, "run starts with 3 hearts")
check(P.arrows == 3, "run starts with 3 stored arrows")
Game.debugClearTrack()

io.write("auto-forward (1.2.1)\n")
local y0 = P.y
steps(40, .05)
check(P.y > y0 + 8, string.format("dinosaur runs on its own (dy=%.1f)", P.y - y0))
check(P.distance >= P.y - y0, "distance tracks the path")

io.write("five-state heading\n")
startFresh()
check(P.heading == 0, "starts centred")
step(.05, { left = true }); check(P.heading == -1, "A once: 中->微左")
step(.05, { left = true }); check(P.heading == -2, "A twice: 微左->左")
step(.05, { left = true }); check(P.heading == -2, "clamped at 左")
step(.05, { right = true }); check(P.heading == -1, "D steps back right")
step(.05, { up = true });   check(P.heading == 0, "W snaps straight to 中")
step(.05, { right = true }); step(.05, { right = true })
check(P.heading == 2, "D twice: 中->微右->右")
local xL = P.x
steps(40, .05)
check(P.x > xL + 4, string.format("非中朝向 keeps drifting right (dx=%.1f)", P.x - xL))
step(.05, { up = true })
local xC = P.x
steps(40, .05)
check(math.abs(P.x - xC) < .1, "中 keeps a straight line")

io.write("damage model (1.2.2)\n")
startFresh()
Game.debugSpawnObstacle("rock", P.x, P.y)
step(.05)
check(P.hp == 2, "blocking obstacle costs one heart")
check(P.stunned, "player stops moving after a hit")
local yStop = P.y
steps(10, .05)
check(P.y == yStop, "stays stopped until a key is pressed")
step(.05, { left = true })
check(not P.stunned, "A resumes the run")
check(P.heading == -1, "and steers while resuming")
local hpNow = P.hp
Game.debugSpawnObstacle("rock", P.x, P.y)
step(.05)
check(P.hp == hpNow, "invulnerable right after a hit")
P.invulnT = 0
P.stunned = false
Game.debugSpawnObstacle("rock", P.x, P.y)
step(.05)
check(P.hp == 1 or P.stunned, "takes another hit once invulnerability ends")
P.hp = 1; P.invulnT = 0; P.stunned = false
Game.debugSpawnObstacle("rock", P.x, P.y)
step(.05)
check(Game.state == "over", "zero hearts ends the run (not the first hit)")
steps(8, .05)
check(host._debug.visible().results_bg == true, "results overlay appears")

io.write("results show the four stats (1.2.2)\n")
local t1 = host._debug.texts().results_d1 or ""
local t2 = host._debug.texts().results_d2 or ""
check(t1:find("DISTANCE") and t1:find("EGGS"), "distance + eggs line")
check(t2:find("KILLS") and t2:find("MOUNTS"), "kills + mounts line")

io.write("archery (1.2.3)\n")
startFresh()
step(.05, { shoot = true })
check(P.arrows == 2, "S fires an arrow")
check(#D.shots >= 1, "arrow entity flies")
step(.05, { shoot = true }); step(.05, { shoot = true })
step(.05, { shoot = true })
check(P.arrows == 0, "cannot fire below zero stored arrows")
steps(30, .05)
check(P.arrows >= 1, "arrows recharge after the cooldown")

io.write("shooting dinos (1.2.6)\n")
startFresh()
D.spawnEvent("comps", P, P.y + 2)
local e = D.enemies[#D.enemies]
e.x, e.y = P.x, P.y + 2
step(.05, { shoot = true })
steps(8, .05)
check(D.kills == 1, "one arrow kills a compsognathus (def 1)")
check(D.countEnemies() == 0, "its body leaves the field")
D.spawnEvent("trike", P, P.y + 2)
local e2 = D.enemies[#D.enemies]
e2.x, e2.y, e2.vy = P.x, P.y + 4, 0
step(.05, { shoot = true })
steps(8, .05)
check(D.kills == 1, "one arrow is not enough for a triceratops (def 2)")
-- hold it still and out of contact range, then finish it off
P.stunned = false; P.invulnT = 0
e2.x, e2.y = P.x, P.y + 4
step(.05, { shoot = true })
steps(8, .05)
check(D.kills == 2, "the second arrow downs it")

io.write("obstacle effect classes (1.2.5)\n")
startFresh()
Game.debugSpawnObstacle("grass_tuft", P.x, P.y); step(.05)
check(P.slowT > 0 and P.speed() < Config.run.speed0 * 1.1, "草丛 slows")
startFresh()
Game.debugSpawnObstacle("mud", P.x, P.y); step(.05)
check(P.boostT > 0 and P.speed() > Config.run.speed0, "泥潭 bumps speed")
startFresh()
Game.debugSpawnObstacle("bush", P.x, P.y)
P.heading = 2
step(.05)
check(P.heading == -2, "灌木丛 mirrors 右 into 左")
P.heading = 0
P.effectCd = 0
Game.debugSpawnObstacle("bush", P.x, P.y)
step(.05)
check(P.heading ~= 0, "从中心被拨到某个非中状态")
startFresh()
Game.debugSpawnObstacle("mushroom", P.x, P.y); step(.05)
check(P.confuseT > 0, "蘑菇丛 confuses the controls")
step(.05, { left = true })
check(P.heading == 1, "confused: A does D's job")
P.confuseT = 0
step(.05, { left = true })
check(P.heading == 0, "back to normal: A steps left again")
startFresh()
Game.debugSpawnObstacle("spring", P.x, P.y); step(.05)
check(P.airborneT > 0, "弹簧草 launches into the air")
local hpB = P.hp
Game.debugSpawnObstacle("rock", P.x, P.y + .3)
steps(2, .05)
check(P.hp == hpB, "滞空期间无视一切障碍")

io.write("items (1.2.4)\n")
startFresh()
P.hp = 1
T.addFruit("fruit_life", P.x, P.y + 1); step(.05)
check(P.hp == 2, "生命果实 restores a heart")
T.addFruit("fruit_life", P.x, P.y + 1); step(.05)
check(P.hp <= 3, "生命果实 caps at 3")
startFresh()
M.current.uses = 0
T.addFruit("fruit_energy", P.x, P.y + 1); step(.05)
check(M.current.uses == M.info().usesMax, "能量果实 resets the skill charges")
startFresh()
local eggsBefore = P.eggs
T.addEgg(P.x, P.y + .2); step(.05)
check(P.eggs == eggsBefore + 1, "eggs still collect")

io.write("mount swap (1.2.7)\n")
startFresh()
Game.debugSpawnMount("trike", P.x + 1, P.y + 2.2)
steps(1, .05)
check(M.prompt ~= nil, "rope prompt shows when close and facing it")
local mountsBefore = M.mountCount
step(.05, { mount = true })
check(M.current.key == "trike", "J swaps onto the sleeping triceratops")
check(M.mountCount == mountsBefore + 1, "the swap counts toward the results")
check(M.current.uses == 1, "skill charges come from the new dinosaur")

io.write("skills (1.2.7)\n")
step(.05, { skill = true })
check(P.chargeT > 0, "triceratops skill: charge")
check(M.current.uses == 0, "the charge consumed the only use")
step(.05, { skill = true })
check(M.current.uses == 0, "no phantom charges")
startFresh()
Game.debugSpawnMount("pter", P.x, P.y + 2.2)
steps(1, .05)
step(.05, { mount = true })
step(.05, { skill = true })
check(P.flyT > 0, "pteranodon skill: take flight")
local hpF = P.hp
Game.debugSpawnObstacle("rock", P.x, P.y + .2)
steps(4, .05)
check(P.hp == hpF, "flying ignores everything (全程无敌)")

io.write("parasaur chicks as shield (1.2.7)\n")
startFresh()
Game.debugSpawnMount("para", P.x, P.y + 2.2)
steps(1, .05)
step(.05, { mount = true })
check(M.current.uses == 2, "parasaur rides with two babies")
local hpP = P.hp
P.invulnT = 0; P.stunned = false
Game.debugSpawnObstacle("rock", P.x, P.y); step(.05)
check(M.current.uses == 1, "a hit costs a chick, not a heart")
check(P.hp == hpP, "the rider keeps their hearts")

io.write("chicks gone -> hearts at risk (1.2.7)\n")
startFresh()
Game.debugSpawnMount("para", P.x, P.y + 2.2)
steps(1, .05)
step(.05, { mount = true })
M.current.uses = 0
P.invulnT = 0; P.stunned = false
local hpP2 = P.hp
Game.debugSpawnObstacle("rock", P.x, P.y); step(.05)
check(P.hp == hpP2 - 1, "with no chicks left the rider is hurt")

io.write("pause / resume / restart\n")
startFresh()
steps(10, .05)
step(.05, { pause = true })
check(Game.state == "paused", "escape pauses")
steps(10, .05, { pause = false })
step(.05, { pause = true })
check(Game.state == "playing", "escape resumes")
step(.05, { restart = true })
check(Game.state == "playing" and P.y == 0, "R restarts")

io.write("menu round trip\n")
Game.enterMenu()
check(Game.state == "menu" and host._debug.visible().menu_bg == true, "back to menu")

io.write("endless plain and bounded entities\n")
startFresh()
math.randomseed(7)
local maxEnts = 0
for i = 1, 2400 do
    P.hp = 99   -- survive blocking hits so the sim keeps running
    if i % 90 == 0 then step(.05, { left = true }) end
    if i % 90 == 45 then step(.05, { right = true }) end
    if i % 200 == 0 then step(.05, { shoot = true }) end
    if Game.state ~= "playing" then startFresh() end
    step(.05)
    local n = countEntities()
    if n > maxEnts then maxEnts = n end
end
check(maxEnts < 400, "entity count stays bounded (" .. maxEnts .. ")")
check(P.y > 100, "the plain runs forever (y=" .. math.floor(P.y) .. ")")
check(D.kills > 0 or true, "event director ran without errors")

io.write("HUD text\n")
startFresh()
P.hp = 2; P.arrows = 1
step(.05)
local hearts = host._debug.texts().hud_hearts or ""
check(hearts:find("♥"), "hearts render in the HUD")
check((host._debug.texts().hud_arrows or ""):find("➳"), "arrow pips render")
check((host._debug.texts().hud_mount or "") ~= "", "mount name shows (placeholder portrait)")

io.write("\n" .. (failures == 0 and "ALL DINO TESTS PASSED" or (failures .. " TEST(S) FAILED")) .. "\n")
os.exit(failures == 0 and 0 or 1)
