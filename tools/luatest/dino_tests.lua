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
local W = require("dino_world")
local Config = require("dino_config")
local Data = require("dino_data")

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

-- a real player resumes after every hit instead of sitting stunned
-- (keys default to W; pass {right=true} to resume while holding heading 右)
local function resumeSteps(n, keys)
    keys = keys or { up = true }
    for _ = 1, n do
        if P.stunned then step(.05, keys) else step(.05) end
    end
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

-- same, but the spawn director stays armed (natural rows appear)
local function startLive()
    startFresh()
    Game.debugEnableSpawning()
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
check(P.arrows == 2, "J fires an arrow")
check(#D.shots >= 1, "arrow entity flies")
step(.05, { shoot = true }); step(.05, { shoot = true })
step(.05, { shoot = true })
check(P.arrows == 0, "cannot fire below zero stored arrows")
steps(30, .05)
check(P.arrows == 0, "2 秒 CD 之前不回填（1.5 s 仍为空）")
steps(15, .05)
check(P.arrows >= 1, "arrows recharge after the 2 s cooldown")

io.write("arrow flight matches the heading (箭头朝向=玩家偏转方向)\n")
startFresh()
step(.05, { shoot = true })
check(math.abs(D.shots[#D.shots].rotZ - 90) < .01, "直行射击：箭尖指向前方（屏幕上方）")
step(.05, { right = true, shoot = true })   -- 微右 = +20°，箭应同步右倾
check(math.abs(D.shots[#D.shots].rotZ - 70) < .01, "偏右射击：箭尖沿当前朝向偏转")

io.write("shooting dinos (1.2.6)\n")
-- keep exactly one enemy on the field: events may roll lone stragglers or
-- full packs/walls, and leftover bodies would muddy the counts
local function keepOnlyLast()
    local e = D.enemies[#D.enemies]
    for i = #D.enemies - 1, 1, -1 do
        Host.entity.kill(D.enemies[i].id)
        table.remove(D.enemies, i)
    end
    return e
end
startFresh()
D.spawnEvent("comps", P, P.y + 2)
local e = keepOnlyLast()
e.x, e.y, e.vx, e.vy = P.x, P.y + 2, 0, 0
step(.05, { shoot = true })
steps(8, .05)
check(D.kills == 1, "one arrow kills a compsognathus (def 1)")
check(D.countEnemies() == 0, "its body leaves the field")
startFresh()
D.spawnEvent("trike", P, P.y + 2)
local e2 = keepOnlyLast()
e2.x, e2.y, e2.vy = P.x, P.y + 4, 0
step(.05, { shoot = true })
steps(8, .05)
check(D.kills == 0, "one arrow is not enough for a triceratops (def 2)")
-- hold it still and out of contact range, then finish it off
P.stunned = false; P.invulnT = 0
e2.x, e2.y = P.x, P.y + 4
step(.05, { shoot = true })
steps(8, .05)
check(D.kills == 1, "the second arrow downs it")

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

io.write("tree collision and one-shot obstacle cleanup\n")
startFresh()
check(Data.obstacles.tree.class == "block" and Data.obstacles.tree.radius <= 1.5,
    "tree is a blocking obstacle with a trunk-sized hitbox")
local hpTree = P.hp
local tree = Game.debugSpawnObstacle("tree", P.x + 1.2, P.y)
step(.05)
check(P.hp == hpTree - 1, "the tree damages the player")
check(not tree.dead and Host.entity.exists(tree.id), "blocking trees stay after impact")

io.write("grove field landmark\n")
startFresh()
local field = T.spawnGroveField(P.x, P.y + 8)
local blockers = 0
for i = 1, #T.items do
    if T.items[i].field then blockers = blockers + 1 end
end
local wantGrove = 0
for i = 1, #Config.groveField.rowCounts do
    wantGrove = wantGrove + Config.groveField.rowCounts[i]
end
check(blockers == wantGrove,
    "grove field spawns a full triangular grid of blocking groves")
check(T.isBlocked(P.x, P.y + 9), "grove field footprint is marked impassable")
check(not T.isBlocked(P.x + 40, P.y + 9), "outside the grove field stays open")
check(T.addEgg(P.x, P.y + 9) == nil, "eggs are not placed inside the grove field")
local fieldBefore = blockers
P.y = P.y + 8
step(.05)
local fieldAfter = 0
for i = 1, #T.items do
    if T.items[i].field then fieldAfter = fieldAfter + 1 end
end
check(fieldAfter == fieldBefore, "impact does not consume the grove field")
check(not P.stunned and P.blockT > 0,
    "the rider wades through the grove field slowly instead of stopping")

io.write("trees are permanent and the rider walks through them\n")
startFresh()
local hpW = P.hp
local treeW = Game.debugSpawnObstacle("tree", P.x, P.y)
step(.05)
check(P.hp == hpW - 1, "tree hit costs one heart")
check(not P.stunned and P.blockT > 0,
    "tree hit slows the rider instead of stunning")
local yW = P.y
steps(4, .05)
check(P.y > yW, "the rider keeps moving slowly inside the tree")
check(not treeW.dead and Host.entity.exists(treeW.id), "the tree stays in place")
P.invulnT = 0; P.blockT = 0; P.chargeT = 1
local chargedTree = Game.debugSpawnObstacle("tree", P.x, P.y)
step(.05)
check(not chargedTree.dead and Host.entity.exists(chargedTree.id),
    "charge cannot destroy a tree")
P.chargeT = 0

startFresh()
local bushHit = Game.debugSpawnObstacle("bush", P.x, P.y)
step(.05)
check(bushHit.dead and not Host.entity.exists(bushHit.id),
    "effect obstacles also disappear after contact")

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
check(M.current.key == "trike", "K swaps onto the sleeping triceratops")
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

io.write("flying pteranodon crosses the grove field\n")
startFresh()
P.flyT = 5
local flyHp = P.hp
T.spawnGroveField(P.x, P.y + 4)
local flyY0 = P.y
steps(20, .05)
check(P.hp == flyHp, "flying over the grove field costs nothing")
check(P.y > flyY0 + 4,
    "flying crosses the grove field instead of being pushed back")

io.write("flight still allows egg pickup and mount swaps\n")
startFresh()
Game.debugSpawnMount("pter", P.x, P.y + 2.2)
steps(1, .05)
step(.05, { mount = true })
step(.05, { skill = true })
check(P.flyT > 0, "test starts while airborne")
local eggsFly = P.eggs
T.addEgg(P.x, P.y + .2)
step(.05)
check(P.flyT > 0 and P.eggs == eggsFly + 1, "flying pterosaur can collect eggs")
local flyMount = Game.debugSpawnMount("trike", P.x, P.y + 2.2)
step(.05)
check(M.prompt == flyMount, "flying pterosaur sees the mount prompt")
local mountsFly = M.mountCount
step(.05, { mount = true })
check(M.current.key == "trike" and M.mountCount == mountsFly + 1,
    "flying pterosaur can swap mounts")
check(P.flyT == 0, "swapping lands on the new mount")

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

io.write("chick block still enters the invulnerable stun (1.2.7)\n")
startFresh()
Game.debugSpawnMount("para", P.x, P.y + 2.2)
steps(1, .05)
step(.05, { mount = true })
P.invulnT = 0; P.stunned = false
Game.debugSpawnObstacle("rock", P.x, P.y); step(.05)
check(P.stunned and P.invulnT > 0, "崽挡刀后玩家照常进入无敌+停顿")

io.write("charge ignores non-blocking obstacles (1.2.7)\n")
startFresh()
Game.debugSpawnMount("trike", P.x, P.y + 2.2)
steps(1, .05)
step(.05, { mount = true })
step(.05, { skill = true })
check(P.chargeT > 0, "triceratops is charging")
local hCharge = P.heading
Game.debugSpawnObstacle("bush", P.x, P.y); step(.05)
check(P.heading == hCharge, "转向灌木在冲锋期间不生效")
Game.debugSpawnObstacle("mushroom", P.x, P.y); step(.05)
check(P.confuseT == 0, "蘑菇丛在冲锋期间不生效")

io.write("T-Rex only ramps while you hold one heading (1.2.6)\n")
startFresh()
local rex = Game.debugSpawnEnemy("trex", P.x, P.y - 8)
steps(20, .05)   -- heading stays 中
check(rex and rex.steerT > .8, "保持方向不变：暴龙加速计时累积")
step(.05, { right = true })
check(rex and rex.steerT < .2, "换档立刻重置追逐加速")

io.write("pteranodon carpet-bombs the battlefield in waves\n")
startFresh()
P.flyT = 100   -- keep the test alive while inspecting the pattern
local ptero = Game.debugSpawnEnemy("ptero", P.x, P.y + 10)
local minX, maxX = math.huge, -math.huge
local minY, maxY = math.huge, -math.huge
local minAt, maxAt = math.huge, -math.huge
for _, spot in ipairs(ptero.bombs) do
    minX, maxX = math.min(minX, spot.x), math.max(maxX, spot.x)
    minY, maxY = math.min(minY, spot.y), math.max(maxY, spot.y)
    minAt, maxAt = math.min(minAt, spot.at), math.max(maxAt, spot.at)
end
check(#ptero.bombs >= 40, "poop pattern covers the screen with many drops")
check(maxX - minX >= 34 and maxY - minY >= 10, "poop pattern spans the full battlefield")
check(maxAt - minAt >= 2.5, "poops are staggered instead of landing simultaneously")
local ddCarpet = Game.debugGetDinos()
steps(4, .05)
check(#ddCarpet.their > 0 and #ddCarpet.their < #ptero.bombs,
    "only the early waves have landed")
steps(120, .05)
local dropped = 0
for _, spot in ipairs(ptero.bombs) do
    if spot.dropped then dropped = dropped + 1 end
end
check(dropped == #ptero.bombs, "every scheduled poop eventually lands")
local pteroGone = true
for _, e in ipairs(ddCarpet.enemies) do
    if e == ptero then pteroGone = false end
end
check(pteroGone, "pteranodon leaves after its carpet finishes")

io.write("sauropod feet are huge and cover the battlefield\n")
startFresh()
P.flyT = 100
local saur = Game.debugSpawnEnemy("sauropod", P.x, P.y + 10)
steps(50, .05)
local minLegX, maxLegX, maxLegR = math.huge, -math.huge, 0
for _, leg in ipairs(saur.legs) do
    minLegX, maxLegX = math.min(minLegX, leg.x), math.max(maxLegX, leg.x)
    maxLegR = math.max(maxLegR, leg.r)
end
check(#saur.legs == Config.sauropod.maxSteps, "a few giant stomps cover the attack")
check(maxLegX - minLegX >= 20, "stomps span the battlefield")
check(maxLegR >= 3.5, "stomp collision radius is several times the old foot")

io.write("ankylosaurus pursuit ignores the player's brake\n")
startFresh()
local ank = Game.debugSpawnEnemy("ankylo", P.x, P.y - 6)
local ankY, playerY = ank.y, P.y
steps(20, .05, { stop = true })
check(P.y == playerY, "player remains stopped while holding S")
check(ank.y > ankY + 2, "ankylosaurus keeps moving independently")

io.write("sleeping mounts are harmless + proximity-only mounting\n")
startFresh()
local hpS = P.hp
local sleepy = Game.debugSpawnMount("trike", P.x, P.y)   -- right on top of us
check(sleepy.ring ~= nil and Host.entity.exists(sleepy.ring), "睡觉龙脚下有换乘范围圈（反馈1）")
steps(4, .05)
check(P.hp == hpS, "撞睡觉恐龙不掉血（径直路过）")
check(M.prompt == sleepy, "重合时仍出绳索提示，按 K 能换")
-- mount from directly behind, heading 中: old facing rule is gone
startFresh()
Game.debugSpawnMount("pter", P.x, P.y - 3)
steps(1, .05)
check(M.prompt ~= nil, "背后 3 格也出提示（只看距离，不看朝向）")
local mountsS = M.mountCount
step(.05, { mount = true })
check(M.current.key == "pter" and M.mountCount == mountsS + 1, "进圈按 K 即换乘")

io.write("deinonychus passive: one arrow becomes a three-arrow fan (1113)\n")
startFresh()
local dd = Game.debugGetDinos()
Game.debugSpawnMount("dein", P.x, P.y + 2.2)
steps(1, .05)
step(.05, { mount = true })
check(P.shotSpread == true, "骑上驰龙切换三箭扇形")
local arrows0 = P.arrows
step(.05, { shoot = true })
check(#dd.shots == 3, "一次射击放出三箭")
check(P.arrows == arrows0 - 1, "仍然只消耗一支箭")

io.write("sleeping mounts are shootable targets (1113)\n")
startFresh()
local dd2 = Game.debugGetDinos()
local sleepy2 = Game.debugSpawnMount("ankylo", P.x + 3, P.y + 8)
local tgt
for _, e in ipairs(dd2.enemies) do
    if e.sleepMount and e.item == sleepy2 then tgt = e end
end
check(tgt ~= nil and tgt.def == 3 and tgt.hp == 3, "睡觉龙注册为可射击目标（甲龙防 3）")
local kills0 = dd2.kills
dd2.spawnArrow(tgt.x, tgt.y - 1, 0, 1)
steps(1, .05)
check(tgt.hp == 2, "一箭命中：3→2")
dd2.spawnArrow(tgt.x, tgt.y - 1, 0, 1)
steps(1, .05)
check(tgt.hp == 1, "两箭：2→1")
dd2.spawnArrow(tgt.x, tgt.y - 1, 0, 1)
steps(1, .05)
check(tgt.hp == 0 and dd2.kills == kills0 + 1, "三箭击杀并计入结算")
check(sleepy2.dead == true, "被射杀的睡觉龙从轨道上消失")

io.write("the chasing T-Rex gulps sleeping mounts (1113)\n")
startFresh()
local dd3 = Game.debugGetDinos()
local sleepy3 = Game.debugSpawnMount("comps", P.x + 3, P.y + 8)
local tgt3
for _, e in ipairs(dd3.enemies) do
    if e.sleepMount and e.item == sleepy3 then tgt3 = e end
end
local rex = Game.debugSpawnEnemy("trex", P.x + 3, P.y + 7)
rex.x, rex.y = tgt3.x, tgt3.y - 1
local kills1 = dd3.kills
steps(2, .05)
local stillThere = false
for _, e in ipairs(dd3.enemies) do if e == tgt3 then stillThere = true end end
check(not stillThere and sleepy3.dead, "路过一口吞掉睡觉的骑乘龙")
check(dd3.kills == kills1, "被暴龙吞掉不算玩家击杀")

io.write("S brakes: still, but never safe (1113)\n")
startFresh()
local y0 = P.y
steps(20, .05, { stop = true })
check(P.y == y0, "按住 S：前进冻结")
local dd4 = Game.debugGetDinos()
check(#dd4.enemies == 0, "刹车期间前方生成器不出龙（位置不动）")
T.brakeT = .01
step(.05, { stop = true })
check(#dd4.enemies >= 1, "刹车也会上门：干扰龙事件照常出现")
local ev = dd4.enemies[#dd4.enemies]
check(math.abs(ev.y - P.y) < 30, "刹车事件就近生成，跑不掉")

io.write("blocking obstacles are one-shot and do not stick\n")
startFresh()
local hpG = P.hp
local stuckRock = Game.debugSpawnObstacle("rock", P.x, P.y + .5)
step(.05)
check(P.hp == hpG - 1 and P.stunned,
    "the rock deals one hit and stuns the player")
check(not stuckRock.dead and Host.entity.exists(stuckRock.id),
    "blocking rocks stay in place")
resumeSteps(24, { up = true })
check(P.invulnT > 0, "invulnerability prevents further damage from the same rock")

io.write("endless sideways + spawns follow the heading\n")
-- no air walls anywhere: the player may run arbitrarily far from x = 0,
-- and egg/obstacle rows anchor on the predicted path wherever they are.
-- (eggs only here: obstacle rows also follow the line, and a player who
-- never weaves would get pinned against one - not what we check here)
local function startEggField()
    startFresh()
    Game.debugEnableSpawning("eggs")
end
startEggField()
step(.05, { right = true }); step(.05, { right = true })   -- heading 右
resumeSteps(150, { right = true })
check(P.x > 25, "no air walls: holding 右 walks arbitrarily far out (x=" .. string.format("%.1f", P.x) .. ")")
-- rows must sit on the heading's path (lateral deviation vs the diagonal),
-- not merely "near x" - on a sustained 右 run the path itself is far out
local tanNow = math.tan(Config.heading.angleDeg[P.heading] * math.pi / 180)
local near = 0
for _, it in ipairs(T.items) do
    local dy = it.y - P.y
    if dy > 0 and dy < 30 and math.abs(it.x - (P.x + tanNow * dy)) < 8 then
        near = near + 1
    end
end
check(near > 0, "supplies follow you into the middle of nowhere: " .. near .. " items on-path ahead")
local eggsFar = P.eggs
resumeSteps(300, { right = true })
check(P.eggs - eggsFar >= 3, "still collecting eggs far off-center (" .. (P.eggs - eggsFar) .. ")")
startEggField()
local eggsCenter = P.eggs
resumeSteps(250)
check(P.eggs - eggsCenter >= 2, "straight run still feeds eggs along the middle (+" .. (P.eggs - eggsCenter) .. ")")
-- the prediction itself
startFresh()
check(math.abs(P:futureX(P.y + 10) - P.x) < .01, "futureX straight = current x")
step(.05, { right = true })
check(P:futureX(P.y + 10) > P.x + 2, "futureX leans right with the heading")

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
startLive()
math.randomseed(7)
local maxEnts, sawEnemy, sawMount, eggsTotal = 0, false, false, 0
for i = 1, 2400 do
    P.hp = 99   -- survive blocking hits so the sim keeps running
    -- gentle meander like a real player: lean one way, recenter, lean back
    if i % 200 == 0 then step(.05, { right = true }) end
    if i % 200 == 40 then step(.05, { up = true }) end
    if i % 200 == 100 then step(.05, { left = true }) end
    if i % 200 == 140 then step(.05, { up = true }) end
    if i % 200 == 0 then step(.05, { shoot = true }) end
    if Game.state ~= "playing" then eggsTotal = eggsTotal + P.eggs; startLive() end
    if P.stunned then step(.05, { up = true }) else step(.05) end
    if D.countEnemies() > 0 then sawEnemy = true end
    for _, it in ipairs(T.items) do
        if it.type == "mount" then sawMount = true; break end
    end
    local n = countEntities()
    if n > maxEnts then maxEnts = n end
end
eggsTotal = eggsTotal + P.eggs
check(maxEnts < 700, "entity count stays bounded with live spawning (" .. maxEnts .. ")")
check(P.y > 100, "the plain runs forever (y=" .. math.floor(P.y) .. ")")
check(sawEnemy, "the event director spawns nuisance dinos")
check(sawMount, "sleeping mount dinos appear on the road")
check(eggsTotal > 20, "a real run harvests eggs naturally (eggs=" .. eggsTotal .. ")")

io.write("terrain biomes: mostly grass, some fern, rare swamp\n")
local counts = { grass = 0, fern = 0, swamp = 0 }
local widths = {}
local heights = {}
for cy = -20, 20 do
    for cx = -20, 20 do
        local plan = W.debugTerrainPlan(cx, cy)
        if plan then
            counts[plan.kind] = (counts[plan.kind] or 0) + 1
            widths[#widths + 1] = plan.blobs[1].w
            heights[#heights + 1] = plan.blobs[1].h
        else
            counts.grass = counts.grass + 1
        end
    end
end
check(counts.grass > counts.fern + counts.swamp, "grass covers most of the map ("
    .. counts.grass .. "/" .. (counts.grass + counts.fern + counts.swamp) .. ")")
check(counts.fern > 0, "fern ground occurs")
check(counts.swamp > 0, "swamp occurs")
check(counts.fern > counts.swamp, "swamp is rarer than fern ground ("
    .. counts.swamp .. " vs " .. counts.fern .. ")")
table.sort(widths)
table.sort(heights)
check(#widths > 10 and widths[#widths] - widths[1] > 2,
    "patch widths vary randomly (" .. string.format("%.1f..%.1f", widths[1], widths[#widths]) .. ")")
check(heights[#heights] - heights[1] > 1.5, "patch heights vary randomly")
local planA = W.debugTerrainPlan(3, -7)
local planB = W.debugTerrainPlan(3, -7)
local samePlan = false
if planA == nil and planB == nil then
    samePlan = true
elseif planA and planB then
    samePlan = planA.kind == planB.kind
        and math.abs(planA.blobs[1].w - planB.blobs[1].w) < 1e-9
        and math.abs(planA.blobs[1].h - planB.blobs[1].h) < 1e-9
end
check(samePlan, "the same cell always rolls the same terrain")

startFresh()
local patches, patchKinds = 0, {}
for _, p in pairs(host._debug.terrain()) do
    patches = patches + 1
    patchKinds[p.kind] = true
end

check(patches > 0, "terrain patches are instantiated on the ground (" .. patches .. ")")
check(patchKinds.fern or patchKinds.swamp, "at least one non-grass biome is visible near the start")
check(patches == host.terrain.count(), "Host.terrain.count matches the instantiated patches")
W.clear()
local afterClear = 0
for _ in pairs(host._debug.terrain()) do afterClear = afterClear + 1 end
check(afterClear == 0, "clearing the world removes every terrain patch")

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
