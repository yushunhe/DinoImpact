-- All HUD and menus are built from Lua through Host.ui.
-- Animation is driven by fx.lua (easing + tweens); keyboard navigation is
-- handled here so every screen can be driven without a mouse.
-- HUD follows the design doc's screen sketch (1.2.2 / 2): hearts + stats on
-- the left, mount portrait (as text) and arrows on the right.
local Config = require("dino_config")
local U = require("util")
local I = require("input")
local fx = require("fx")

local C = Config.colors
local R = Config.run
local A = Config.arrow
local UI = {
    onAction = nil,
    cache = {},
    hudNames = {},
    menuNames = {},
    pauseNames = {},
    resultsNames = {},
    screen = nil,
    index = 1,
    lastEggs = 0,
    lastKills = 0,
    lastMounts = 0,
    lastArrows = A.max,
    lastHp = R.hpMax,
    titleT = 0,
    fade = { a = 0, color = C.ink },
    toast = { y = .30, a = 1, s = 1 },
}

-- BUTTONS: which Lua action each button triggers, per screen.
local SCREENS = {
    menu = {
        { name = "menu_start", action = "start" },
    },
    pause = {
        { name = "pause_resume", action = "resume" },
        { name = "pause_restart", action = "restart" },
        { name = "pause_menu", action = "menu" },
    },
    results = {
        { name = "results_retry", action = "retry" },
        { name = "results_menu", action = "menu" },
    },
}

local function action(name)
    return function()
        fx.sound("click", .7)
        if UI.onAction then UI.onAction(name) end
    end
end

local function setText(name, text)
    if UI.cache[name] ~= text then
        UI.cache[name] = text
        Host.ui.setText(name, text)
    end
end

local function showAll(names, visible)
    for i = 1, #names do Host.ui.show(names[i], visible) end
end

local function styleButton(name)
    Host.ui.setButtonColors(name, C.button, C.white)
end

-- Scale pop: jump to `amount`, then ease back to 1.
local function popLabel(name, amount, dur)
    amount = amount or 1.3
    dur = dur or .12
    Host.ui.setScale(name, amount)
    fx.to(dur, { s = amount }, { s = 1 }, fx.ease.quad_out, nil, "pop_" .. name,
        function(t) Host.ui.setScale(name, t.s) end)
end

local function popIn(names, delay)
    for i = 1, #names do
        local n = names[i]
        Host.ui.setScale(n, .85)
        fx.after((delay or 0) + (i - 1) * .04, function()
            fx.to(.32, { s = .85 }, { s = 1 }, fx.ease.back_out, nil, "popin_" .. n,
                function(t) Host.ui.setScale(n, t.s) end)
        end, "popin_wait_" .. n)
    end
end

-- ------------------------------------------------------------------ fade / flash

local function applyFade()
    Host.ui.setFade(UI.fade.a, UI.fade.color)
end

function UI.fadeTo(a, dur, color, done)
    if color then UI.fade.color = color end
    fx.to(dur or .3, UI.fade, { a = a }, fx.ease.quad_in_out,
        function() applyFade(); if done then done() end end,
        "fade", function() applyFade() end)
end

function UI.flash(color, dur)
    UI.fade.color = color or "#FFFFFF"
    UI.fade.a = .8
    applyFade()
    fx.to(dur or .35, UI.fade, { a = 0 }, fx.ease.quad_out,
        function() UI.fade.color = C.ink; applyFade() end,
        "fade", function() applyFade() end)
end

function UI.transitionIn(dur)
    UI.fade.a = 1
    UI.fade.color = C.ink
    applyFade()
    UI.fadeTo(0, dur or .35)
end

-- ------------------------------------------------------------------ init

function UI.init()
    -- HUD -------------------------------------------------------------------
    -- hearts (design doc 1.2.2) - placeholder art: text hearts, replaceable
    Host.ui.label("hud_hearts", "", .035, .062, 30, C.heart, "left")
    Host.ui.label("hud_distance", "0 m", .035, .115, 24, C.white, "left")
    Host.ui.label("hud_eggs", "EGGS 0", .035, .162, 20, C.accent, "left")
    Host.ui.label("hud_kills", "KILLS 0", .035, .205, 20, C.accent2, "left")
    Host.ui.label("hud_mounts", "MOUNTS 0", .035, .248, 20, C.gold, "left")
    -- right side: arrows + current mount (portrait placeholder = its name)
    Host.ui.label("hud_arrows", "", .965, .062, 26, C.white, "right")
    Host.ui.label("hud_mount", "", .965, .115, 22, C.accent2, "right")
    Host.ui.label("hud_uses", "", .965, .158, 22, C.accent, "right")
    -- centre-top: mount prompt (1.2.7)
    Host.ui.label("hud_prompt", "", .5, .06, 26, C.buttonHi, "center")
    Host.ui.label("hud_hint", "A/D STEER   W CENTER   S STOP   J SHOOT   K MOUNT   SPACE SKILL", .5, .955, 16, C.muted, "center")
    Host.ui.label("hud_toast", "", .5, .30, 40, C.accent, "center")
    UI.hudNames = {
        "hud_hearts", "hud_distance", "hud_eggs", "hud_kills", "hud_mounts",
        "hud_arrows", "hud_mount", "hud_uses", "hud_prompt", "hud_hint",
    }

    -- Title -----------------------------------------------------------------
    Host.ui.panel("menu_bg", .5, .5, 1920, 1080, C.ink)
    Host.ui.label("menu_title", Config.title, .5, .175, 108, C.accent, "center")
    Host.ui.label("menu_sub", Config.subtitle .. "  -  LUA-POWERED", .5, .255, 25, C.accent2, "center")
    Host.ui.label("menu_best", "BEST  0", .5, .325, 24, C.gold, "center")
    Host.ui.button("menu_start", "START RUN", .5, .44, 380, 74, action("start"))
    Host.ui.label("menu_controls", "A / D   STEP HEADING     W   SNAP TO CENTER", .5, .55, 23, C.white, "center")
    Host.ui.label("menu_controls2", "S   STOP FORWARD      J   SHOOT ARROW      K   MOUNT      SPACE   SKILL", .5, .60, 21, C.accent2, "center")
    Host.ui.label("menu_goal", "You ride automatically. Dodge or shoot. Collect eggs. Swap dinos.", .5, .675, 23, C.white, "center")
    Host.ui.label("menu_footer", "ENTER START      ARROWS / WASD TO MOVE", .5, .93, 16, C.muted, "center")
    UI.menuNames = {
        "menu_bg", "menu_title", "menu_sub", "menu_best", "menu_start",
        "menu_controls", "menu_controls2", "menu_goal", "menu_footer",
    }
    styleButton("menu_start")

    -- Pause -----------------------------------------------------------------
    Host.ui.panel("pause_bg", .5, .5, 1920, 1080, C.ink)
    Host.ui.label("pause_title", "PAUSED", .5, .26, 78, C.accent, "center")
    Host.ui.button("pause_resume", "RESUME", .5, .46, 380, 70, action("resume"))
    Host.ui.button("pause_restart", "RESTART", .5, .57, 380, 70, action("restart"))
    Host.ui.button("pause_menu", "MAIN MENU", .5, .68, 380, 70, action("menu"))
    styleButton("pause_resume"); styleButton("pause_restart"); styleButton("pause_menu")
    UI.pauseNames = { "pause_bg", "pause_title", "pause_resume", "pause_restart", "pause_menu" }

    -- Results ---------------------------------------------------------------
    Host.ui.panel("results_bg", .5, .5, 1920, 1080, C.ink)
    Host.ui.label("results_title", "GAME OVER", .5, .18, 76, C.red, "center")
    Host.ui.label("results_reason", "", .5, .265, 24, C.muted, "center")
    Host.ui.label("results_score", "SCORE 0", .5, .36, 52, C.accent, "center")
    Host.ui.label("results_d1", "", .5, .45, 24, C.white, "center")
    Host.ui.label("results_d2", "", .5, .505, 24, C.white, "center")
    Host.ui.label("results_best", "", .5, .585, 24, C.gold, "center")
    Host.ui.button("results_retry", "RUN AGAIN", .5, .69, 380, 70, action("retry"))
    Host.ui.button("results_menu", "MAIN MENU", .5, .79, 380, 70, action("menu"))
    styleButton("results_retry"); styleButton("results_menu")
    UI.resultsNames = {
        "results_bg", "results_title", "results_reason", "results_score",
        "results_d1", "results_d2", "results_best", "results_retry", "results_menu",
    }

    UI.showHud(false)
    UI.showPause(false)
    UI.showResults(false)
    UI.showMenu(true)
    Host.ui.show("hud_toast", false)
    Host.ui.show("hud_prompt", false)
    UI.fade.a = 0
    applyFade()
    Host.ui.setVignette(false)
end

-- ------------------------------------------------------------------ screens

local function clearSelection()
    for _, screen in pairs(SCREENS) do
        for _, b in ipairs(screen) do
            Host.ui.setButtonColors(b.name, C.button, C.white)
        end
    end
end

local function refreshSelection()
    clearSelection()
    if not UI.screen then return end
    local list = SCREENS[UI.screen]
    if not list then return end
    for i, b in ipairs(list) do
        if i == UI.index then
            Host.ui.setButtonColors(b.name, C.buttonHi, C.darkText)
        end
    end
end

local function setActive(screen)
    UI.screen = screen
    if screen and SCREENS[screen] then
        if UI.index > #SCREENS[screen] then UI.index = 1 end
        if UI.index < 1 then UI.index = 1 end
    end
    refreshSelection()
end

function UI.showMenu(v)
    showAll(UI.menuNames, v)
    if v then setActive("menu") end
end

function UI.showHud(v)
    showAll(UI.hudNames, v)
    if v then setActive(nil) end
end

function UI.showPause(v)
    showAll(UI.pauseNames, v)
    if v then setActive("pause") end
end

function UI.showResults(v)
    showAll(UI.resultsNames, v)
    if v then setActive("results") end
end

-- ------------------------------------------------------------------ navigation

function UI.handleNav()
    if not UI.screen then return false end
    local list = SCREENS[UI.screen]
    if not list or #list < 2 then return false end
    local moved = 0
    if I.down() or I.right() then moved = 1
    elseif I.up() or I.left() then moved = -1 end
    if moved ~= 0 then
        UI.index = ((UI.index - 1 + moved) % #list) + 1
        refreshSelection()
        fx.sound("tick", .5)
        return true
    end
    return false
end

function UI.activateSelected()
    if not UI.screen then return false end
    local list = SCREENS[UI.screen]
    if not list then return false end
    local b = list[UI.index]
    if not b or not UI.onAction then return false end
    fx.sound("click", .7)
    UI.onAction(b.action)
    return true
end

-- ------------------------------------------------------------------ hud

function UI.setBest(best)
    UI.cache.menu_best = nil
    setText("menu_best", "BEST  " .. U.comma(best or 0))
end

function UI.resetRun()
    UI.cache = {}
    UI.lastEggs, UI.lastKills, UI.lastMounts = 0, 0, 0
    UI.lastArrows, UI.lastHp = A.max, R.hpMax
    UI.showMenu(false)
    UI.showPause(false)
    UI.showResults(false)
    UI.showHud(true)
    setActive(nil)
    Host.ui.show("hud_toast", false)
    Host.ui.show("hud_prompt", false)
    Host.ui.setVignette(false)
    UI.transitionIn(.35)
    fx.sound("gate", .8)
end

local function showToast(text)
    Host.ui.show("hud_toast", true)
    Host.ui.setText("hud_toast", text)
    Host.ui.setPos("hud_toast", .5, .30)
    Host.ui.setColor("hud_toast", fx.rgba(C.accent, 1))
    Host.ui.setScale("hud_toast", 1.15)
    UI.toast.y, UI.toast.a, UI.toast.s = .30, 1, 1.15
    fx.to(.75, UI.toast, { y = .235, a = 0, s = .95 }, fx.ease.quad_out,
        function() Host.ui.show("hud_toast", false) end, "toast",
        function(t)
            Host.ui.setPos("hud_toast", .5, t.y)
            Host.ui.setColor("hud_toast", fx.rgba(C.accent, t.a))
            Host.ui.setScale("hud_toast", t.s)
        end)
end

function UI.updateHud(P, Mount)
    local distance = math.floor(P.distance + .5)
    local score = distance + P.eggs * Config.spawn.eggValue

    setText("hud_distance", U.comma(distance) .. " m")
    setText("hud_eggs", "EGGS " .. tostring(P.eggs))
    setText("hud_kills", "KILLS " .. tostring(Mount and require("dino_dinos").kills or 0))

    -- hearts: full + lost (1.2.2)
    local hearts = ""
    for i = 1, R.hpMax do
        hearts = hearts .. (i <= P.hp and "♥ " or "♡ ")
    end
    setText("hud_hearts", hearts)
    if P.hp < UI.lastHp then
        UI.lastHp = P.hp
        popLabel("hud_hearts", 1.6, .3)
        UI.flash(C.red, .25)
    elseif P.hp > UI.lastHp then
        UI.lastHp = P.hp
        popLabel("hud_hearts", 1.3, .2)
    end

    -- arrow inventory (1.2.3)
    local arrows = ""
    for i = 1, A.max do
        arrows = arrows .. (i <= P.arrows and "➳ " or "- ")
    end
    setText("hud_arrows", arrows)
    if P.arrows < UI.lastArrows then
        popLabel("hud_arrows", 1.35, .12)
        UI.lastArrows = P.arrows
    elseif P.arrows > UI.lastArrows then
        UI.lastArrows = P.arrows
    end

    -- current mount: portrait is a name label until real art exists
    if Mount then
        local info = Mount.info()
        setText("hud_mount", info.label)
        setText("hud_uses", "x" .. tostring(info.uses))
        if Mount.mountCount > UI.lastMounts then
            UI.lastMounts = Mount.mountCount
            popLabel("hud_mounts", 1.4, .2)
        end
        setText("hud_mounts", "MOUNTS " .. tostring(Mount.mountCount))
        -- mount prompt (1.2.7)
        if Mount.prompt then
            setText("hud_prompt", "[K] MOUNT THE " .. info.label)
            Host.ui.show("hud_prompt", true)
        else
            Host.ui.show("hud_prompt", false)
        end
    end

    if P.eggs > UI.lastEggs then
        UI.lastEggs = P.eggs
        popLabel("hud_eggs", 1.4, .16)
        showToast("+" .. Config.spawn.eggValue)
    elseif P.eggs < UI.lastEggs then
        UI.lastEggs = P.eggs
    end
end

function UI.updateMenu(dt)
    UI.titleT = UI.titleT + dt
    local s = 1 + math.sin(UI.titleT * 2.2) * .015
    Host.ui.setScale("menu_title", s)
    local s2 = 1 + math.sin(UI.titleT * 1.7 + 1) * .01
    Host.ui.setScale("menu_sub", s2)
end

function UI.update(dt)
    applyFade()
end

-- ------------------------------------------------------------------ overlays

function UI.showPauseOverlay()
    UI.showHud(false)
    UI.showPause(true)
    popIn({ "pause_title", "pause_resume", "pause_restart", "pause_menu" })
end

function UI.showResultsPanel(data)
    UI.showHud(false)
    UI.showPause(false)
    UI.showResults(true)
    for _, n in ipairs({ "results_title", "results_reason", "results_d1",
                         "results_d2", "results_best", "results_score" }) do
        UI.cache[n] = nil
    end
    setText("results_title", data.title or "GAME OVER")
    setText("results_reason", data.reason or "You hit an obstacle.")
    -- the four stat lines from 1.2.2 / section 2
    setText("results_d1", string.format("DISTANCE  %s m      EGGS  %d",
        U.comma(math.floor((data.distance or 0) + .5)), data.eggs or 0))
    setText("results_d2", string.format("KILLS  %d      MOUNTS  %d",
        data.kills or 0, data.mounts or 0))
    if data.newBest then
        setText("results_best", "NEW BEST!")
    else
        setText("results_best", "BEST  " .. U.comma(data.best or 0))
    end

    local target = data.score or 0
    setText("results_score", "SCORE  0")
    fx.to(.75, { v = 0 }, { v = target }, fx.ease.cubic_out,
        function() setText("results_score", "SCORE  " .. U.comma(target)) end,
        "resultscore",
        function(t)
            Host.ui.setText("results_score", "SCORE  " .. U.comma(math.floor(t.v + .5)))
        end)

    popIn({ "results_title", "results_score", "results_d1", "results_d2",
            "results_best", "results_retry", "results_menu" })

    if data.newBest then
        UI.flash(C.gold, .4)
        fx.after(.25, function() popLabel("results_best", 1.5, .35) end, "bestpop")
    end
end

return UI
