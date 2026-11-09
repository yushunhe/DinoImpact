-- SURF IMPACT - tunables. Edit freely; the game reloads Lua on play.
local C = {}

C.version = "1.0"
C.title = "SURF IMPACT"
C.subtitle = "LUA-POWERED ENDLESS SURF"

C.colors = {
    ink      = "#0A1822",
    panel    = "#07161FDD",
    button   = "#0E2634F0",
    buttonHi = "#FFC24BF5",
    accent   = "#FFC24B",
    accent2  = "#3FE0D0",
    white    = "#F2FBFF",
    muted    = "#9FC4D4",
    red      = "#FF5E5B",
    green    = "#5CFF7A",
    gold     = "#FFC24B",
    darkText = "#10222B",
    sand     = "#E9CF9C",
}

C.player = {
    baseSpeed = 15,
    minSpeed = 7,
    maxSpeed = 27,
    boostSpeed = 40,
    turnRate = 2.25,
    airTurnFactor = 0.55,
    gravity = 24,
    radius = 0.95,
    jumpBase = 8.5,
    jumpSpeedFactor = 0.13,
    boostDuration = 6,
    boostMax = 3,
    maxLives = 3,
    invulnTime = 2.2,
    airSpinRate = 520,
    trickThreshold = 260,
    trickPoints = 150,
    coinPoints = 25,
}

C.camera = {
    distance = 12.5,
    height = 6.8,
    lookAhead = 11,
    fov = 55,
    boostFov = 63,
    follow = 4.2,
    lookFollow = 6.5,
    menuRadius = 30,
    menuHeight = 10,
}

C.world = {
    dayLength = 170,
    startTimeOfDay = 0.06,
    cullDistance = 195,
    maxEntities = 270,
    cloudCount = 9,
    farIslandCount = 8,
}

C.spawn = {
    obstacleMin = 95,
    obstacleMax = 140,
    pickupMin = 55,
    pickupMax = 125,
    rampMin = 70,
    rampMax = 120,
    islandMin = 105,
    islandMax = 165,
    islandChance = 0.16,
    spreadDeg = 52,
}

C.modes = {
    classic = {
        key = "classic",
        name = "LET'S SURF",
        short = "CLASSIC",
        blurb = "Endless surf. Dodge the kraken.",
        obstacle = 0.95,
        island = 13,
        coin = 1.5,
        ramp = 10.5,
        bolt = 22,
        heart = 34,
        lives = 3,
    },
    timeTrial = {
        key = "timeTrial",
        name = "TIME TRIAL",
        short = "TIME TRIAL",
        blurb = "Hit every checkpoint before time runs out.",
        obstacle = 1.55,
        island = 22,
        coin = 1.25,
        ramp = 12,
        bolt = 30,
        heart = 46,
        lives = 3,
        timer = 38,
        gateGoal = 12,
        gateTime = 8,
        gateScore = 150,
    },
    zigzag = {
        key = "zigzag",
        name = "ZIGZAG",
        short = "ZIGZAG",
        blurb = "Thread the gates. Keep the streak alive.",
        obstacle = 1.7,
        island = 24,
        coin = 2.2,
        ramp = 13,
        bolt = 26,
        heart = 44,
        lives = 3,
        gateDistance = 90,
        gateOffset = 12.5,
    },
    collector = {
        key = "collector",
        name = "COLLECTOR",
        short = "COLLECTOR",
        blurb = "A sea of coins. Grab everything.",
        obstacle = 1.55,
        island = 22,
        coin = 0.55,
        ramp = 12,
        bolt = 24,
        heart = 34,
        lives = 3,
    },
}

C.modeOrder = { "classic", "timeTrial", "zigzag", "collector" }

return C
