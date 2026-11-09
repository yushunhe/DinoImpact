-- All menus and HUD are built from Lua at runtime through Host.ui.
local Config = require("config")
local U = require("util")

local UI = {
    menuIndex = 1,
    pauseIndex = 1,
    resultsIndex = 1,
    cache = {},
    toasts = {},
    toastActive = false,
    toastTimer = 0,
    bests = {},
    onAction = nil,
    fade = nil,
    vig = false,
    built = false,
}

local C = Config.colors

local function action(name)
    return function()
        if UI.onAction then UI.onAction(name) end
    end
end

local function hide(names)
    for i = 1, #names do Host.ui.show(names[i], false) end
end

local function show(names)
    for i = 1, #names do Host.ui.show(names[i], true) end
end

local function setTextC(name, text)
    if UI.cache[name] ~= text then
        UI.cache[name] = text
        Host.ui.setText(name, text)
    end
end

local function setColorC(name, color)
    local key = name .. "@c"
    if UI.cache[key] ~= color then
        UI.cache[key] = color
        Host.ui.setColor(name, color)
    end
end

local function bestText(v)
    if not v or v <= 0 then return "BEST  -" end
    return "BEST  " .. U.comma(v)
end

-- construction -------------------------------------------------------------

local function buildHud()
    Host.ui.label("hud_score", "0", .038, .055, 58, C.white, "left")
    Host.ui.label("hud_dist", "0 m", .042, .118, 22, C.muted, "left")
    Host.ui.label("hud_lives", "LIVES 3", .962, .055, 30, C.white, "right")
    Host.ui.label("hud_coins", "COINS 0", .962, .108, 23, C.accent, "right")
    Host.ui.label("hud_boost", "BOOST 0/3", .962, .152, 21, C.green, "right")
    Host.ui.label("hud_objective", "", .5, .055, 42, C.accent, "center")
    Host.ui.label("hud_objective2", "", .5, .12, 22, C.muted, "center")
    Host.ui.label("hud_warning", "", .5, .185, 27, C.red, "center")
    Host.ui.label("hud_speed", "SPEED 0", .5, .878, 18, C.muted, "center")
    Host.ui.bar("hud_speedbar", .5, .908, 420, 12, "#07161FCC", C.accent2)
    Host.ui.label("hud_hint", "STEER A/D   DASH W   BOOST F   PAUSE SPACE", .5, .968, 18, C.muted, "center")
    Host.ui.label("toast", "", .5, .40, 40, C.accent, "center")
    Host.ui.label("countdown", "", .5, .42, 150, C.accent, "center")
    Host.ui.show("toast", false)
    Host.ui.show("countdown", false)
end

local function buildMenu()
    Host.ui.panel("menu_bg", .5, .5, 1920, 1080, "#04121ACC")
    Host.ui.label("menu_title", Config.title, .5, .155, 116, C.accent, "center")
    Host.ui.label("menu_sub", Config.subtitle, .5, .232, 25, C.accent2, "center")

    UI.menuNames = { "menu_bg", "menu_title", "menu_sub", "menu_blurb", "menu_footer" }
    local y = .365
    for i = 1, #Config.modeOrder do
        local key = Config.modeOrder[i]
        local m = Config.modes[key]
        local name = "menu_" .. key
        Host.ui.button(name, (i) .. "   " .. m.name, .45, y, 560, 72, action("mode:" .. key))
        Host.ui.label("menu_best_" .. key, "BEST  -", .755, y, 20, C.muted, "left")
        UI.menuNames[#UI.menuNames + 1] = name
        UI.menuNames[#UI.menuNames + 1] = "menu_best_" .. key
        y = y + .104
    end
    Host.ui.label("menu_blurb", "", .5, .79, 24, C.white, "center")
    Host.ui.label("menu_footer", "UP/DOWN SELECT   ENTER START   M MUTE   ESC BACK", .5, .945, 18, C.muted, "center")
end

local function buildPause()
    Host.ui.panel("pause_bg", .5, .5, 1920, 1080, "#04121AB8")
    Host.ui.label("pause_title", "PAUSED", .5, .255, 84, C.accent, "center")
    Host.ui.button("pause_resume", "RESUME", .5, .47, 420, 66, action("resume"))
    Host.ui.button("pause_restart", "RESTART", .5, .572, 420, 66, action("restart"))
    Host.ui.button("pause_menu", "MAIN MENU", .5, .674, 420, 66, action("menu"))
    Host.ui.label("pause_hint", "ESC RESUME   R RESTART   M MUTE", .5, .84, 18, C.muted, "center")
    UI.pauseNames = { "pause_bg", "pause_title", "pause_resume", "pause_restart", "pause_menu", "pause_hint" }
end

local function buildResults()
    Host.ui.panel("results_bg", .5, .5, 1920, 1080, "#04121AF0")
    Host.ui.label("results_title", "", .5, .22, 84, C.accent, "center")
    Host.ui.label("results_reason", "", .5, .295, 26, C.muted, "center")
    Host.ui.label("results_score", "", .5, .40, 56, C.white, "center")
    Host.ui.label("results_detail", "", .5, .475, 22, C.muted, "center")
    Host.ui.label("results_best", "", .5, .54, 26, C.accent, "center")
    Host.ui.button("results_retry", "RETRY", .5, .655, 360, 70, action("retry"))
    Host.ui.button("results_menu", "MAIN MENU", .5, .762, 360, 70, action("menu"))
    Host.ui.label("results_hint", "UP/DOWN SELECT   ENTER CONFIRM", .5, .87, 18, C.muted, "center")
    UI.resultsNames = {
        "results_bg", "results_title", "results_reason", "results_score",
        "results_detail", "results_best", "results_retry", "results_menu", "results_hint",
    }
end

function UI.init()
    Host.ui.clear()
    UI.cache = {}
    UI.built = true
    buildHud()
    buildMenu()
    buildPause()
    buildResults()

    UI.hudNames = {
        "hud_score", "hud_dist", "hud_lives", "hud_coins", "hud_boost",
        "hud_objective", "hud_objective2", "hud_warning", "hud_speed", "hud_speedbar", "hud_hint",
    }
    hide(UI.hudNames)
    hide(UI.menuNames)
    hide(UI.pauseNames)
    hide(UI.resultsNames)
    Host.ui.setFade(1, "#000000")
    UI.fade = nil
    UI.setMenuSelection(1)
end

-- visibility ---------------------------------------------------------------

function UI.setHudVisible(v)
    if v then show(UI.hudNames); UI.cache = {} else hide(UI.hudNames) end
    UI.hudShown = v
end

function UI.setMenuVisible(v)
    if v then show(UI.menuNames) else hide(UI.menuNames) end
end

function UI.setPauseVisible(v)
    if v then
        show(UI.pauseNames)
        UI.setPauseSelection(UI.pauseIndex)
    else
        hide(UI.pauseNames)
    end
end

function UI.setResultsVisible(v)
    if v then
        show(UI.resultsNames)
        UI.setResultsSelection(UI.resultsIndex)
    else
        hide(UI.resultsNames)
    end
end

-- menu ---------------------------------------------------------------------

function UI.setBests(bests)
    UI.bests = bests or {}
    for i = 1, #Config.modeOrder do
        local key = Config.modeOrder[i]
        Host.ui.setText("menu_best_" .. key, bestText(UI.bests[key]))
    end
end

function UI.setMenuSelection(i)
    local n = #Config.modeOrder
    if n == 0 then return end
    i = ((i - 1) % n) + 1
    UI.menuIndex = i
    for j = 1, n do
        local key = Config.modeOrder[j]
        Host.ui.setButtonSelected("menu_" .. key, j == i)
    end
    local key = Config.modeOrder[i]
    local m = Config.modes[key]
    Host.ui.setText("menu_blurb", m.short .. "  -  " .. m.blurb)
    UI.cache.menu_blurb = nil
end

function UI.getMenuSelection()
    return UI.menuIndex
end

function UI.setPauseSelection(i)
    i = U.clamp(i, 1, 3)
    UI.pauseIndex = i
    Host.ui.setButtonSelected("pause_resume", i == 1)
    Host.ui.setButtonSelected("pause_restart", i == 2)
    Host.ui.setButtonSelected("pause_menu", i == 3)
end

function UI.getPauseSelection()
    return UI.pauseIndex
end

function UI.setResultsSelection(i)
    i = U.clamp(i, 1, 2)
    UI.resultsIndex = i
    Host.ui.setButtonSelected("results_retry", i == 1)
    Host.ui.setButtonSelected("results_menu", i == 2)
end

function UI.getResultsSelection()
    return UI.resultsIndex
end

-- results ------------------------------------------------------------------

function UI.showResults(data)
    Host.ui.setText("results_title", data.title or "RUN OVER")
    Host.ui.setColor("results_title", data.win and C.accent or C.red)
    Host.ui.setText("results_reason", data.reason or "")
    Host.ui.setText("results_score", "SCORE  " .. U.comma(data.score or 0))
    Host.ui.setText("results_detail", data.detail or "")
    Host.ui.setText("results_best", data.newBest and "NEW BEST!" or bestText(data.best))
    Host.ui.setColor("results_best", data.newBest and C.green or C.accent)
    UI.resultsIndex = 1
    UI.setResultsVisible(true)
end

-- toasts / countdown / fade ------------------------------------------------

local function showNextToast()
    if #UI.toasts == 0 then
        UI.toastActive = false
        Host.ui.show("toast", false)
        return
    end
    local t = table.remove(UI.toasts, 1)
    Host.ui.setText("toast", t.text)
    Host.ui.setColor("toast", t.color or C.accent)
    Host.ui.show("toast", true)
    UI.toastActive = true
    UI.toastTimer = t.duration or 1.5
end

function UI.toast(text, color, duration)
    if not text or text == "" then return end
    if #UI.toasts > 4 then table.remove(UI.toasts, 1) end
    UI.toasts[#UI.toasts + 1] = { text = text, color = color or C.accent, duration = duration or 1.5 }
    if not UI.toastActive then showNextToast() end
end

function UI.clearToasts()
    UI.toasts = {}
    UI.toastActive = false
    Host.ui.show("toast", false)
end

function UI.showCountdown(text)
    Host.ui.setText("countdown", text)
    Host.ui.setSize("countdown", 150)
    Host.ui.show("countdown", true)
    UI.countdownVisible = true
    UI.countdownT = 0
end

function UI.hideCountdown()
    UI.countdownVisible = false
    Host.ui.show("countdown", false)
end

function UI.fadeTo(alpha, color, duration)
    UI.fade = {
        from = UI.fadeAlpha or 1,
        to = alpha,
        color = color or "#000000",
        t = 0,
        dur = duration or .5,
    }
    if UI.fade.dur <= 0 then
        UI.fadeAlpha = alpha
        Host.ui.setFade(alpha, UI.fade.color)
        UI.fade = nil
    end
end

-- per-frame ----------------------------------------------------------------

function UI.update(dt)
    if UI.fade then
        UI.fade.t = UI.fade.t + dt
        local k = U.clamp01(UI.fade.t / UI.fade.dur)
        local a = U.lerp(UI.fade.from, UI.fade.to, k)
        UI.fadeAlpha = a
        Host.ui.setFade(a, UI.fade.color)
        if k >= 1 then UI.fade = nil end
    end

    if UI.countdownVisible then
        UI.countdownT = (UI.countdownT or 0) + dt
        local size = math.floor(138 + math.sin(UI.countdownT * 7) * 12)
        Host.ui.setSize("countdown", size)
    end

    if UI.toastActive then
        UI.toastTimer = UI.toastTimer - dt
        if UI.toastTimer <= 0 then showNextToast() end
    end
end

function UI.updateHud(P, M, dt)
    if not UI.hudShown then return end
    UI.hudAcc = (UI.hudAcc or 0) + dt
    if UI.hudAcc < .055 then return end
    UI.hudAcc = 0

    setTextC("hud_score", U.comma(P.totalScore()))
    setTextC("hud_dist", U.formatDistance(P.distance))
    setTextC("hud_lives", "LIVES " .. P.lives)
    setColorC("hud_lives", P.lives <= 1 and C.red or C.white)
    setTextC("hud_coins", "COINS " .. U.comma(P.tokens))
    setTextC("hud_boost", "BOOST " .. P.boostCharges .. "/" .. Config.player.boostMax)
    setColorC("hud_boost", P.boostCharges > 0 and C.green or C.muted)
    setTextC("hud_speed", "SPEED " .. math.floor(P.speed + .5))
    Host.ui.setBar("hud_speedbar", U.clamp01(P.speed / Config.player.boostSpeed))

    local objective, objective2 = "", ""
    if M.mode == "timeTrial" then
        objective = U.formatTime(M.timeLeft)
        setColorC("hud_objective", M.timeLeft < 8 and C.red or C.accent)
        objective2 = "CHECKPOINT " .. M.gates .. " / " .. M.goal
    elseif M.mode == "zigzag" then
        objective = "STREAK x" .. M.streak
        setColorC("hud_objective", M.streak >= 5 and C.green or C.accent)
        objective2 = "BEST x" .. M.bestStreak
    elseif M.mode == "collector" then
        objective = "COINS " .. U.comma(P.tokens)
        setColorC("hud_objective", C.accent)
        objective2 = "COLLECT EVERYTHING"
    else
        setColorC("hud_objective", C.accent)
    end
    setTextC("hud_objective", objective)
    setTextC("hud_objective2", objective2)

    local warning = ""
    if M.mode == "classic" then
        if M.krakenWarning then
            warning = "THE KRAKEN IS COMING"
        elseif M.krakenActive then
            if M.krakenDistance < 34 then
                warning = "THE KRAKEN IS ON YOUR TAIL"
            elseif M.krakenDistance < 60 then
                warning = "THE KRAKEN IS CLOSE"
            end
        end
    end
    setTextC("hud_warning", warning)
    Host.ui.show("hud_warning", warning ~= "")

    local vig = (M.mode == "classic" and M.krakenActive and M.krakenDistance < 36)
        or P.boostTime > 0
        or (M.mode == "timeTrial" and M.timeLeft < 6)
    if vig ~= UI.vig then
        UI.vig = vig
        Host.ui.setVignette(vig)
    end
end

function UI.resetRun()
    UI.cache = {}
    UI.clearToasts()
    UI.hideCountdown()
    UI.setHudVisible(true)
    UI.setPauseVisible(false)
    UI.setResultsVisible(false)
    UI.setMenuVisible(false)
end

return UI
