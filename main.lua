-- 入口：只做 love.load / update / draw 分发与全局状态机（规范 §2、§17）
local Save = require("src.save")
local Audio = require("src.audio")
local UI = require("src.ui")
local Talent = require("src.talent")

local Waves = require("data.waves")
local Words = require("data.words")
local Enemies = require("data.enemies")
local Events = require("data.events")

local Game = {
    scale = 1,
    ox = 0,
    oy = 0,
    time = 0,
    debug = false,
    updMs = 0,
    drawMs = 0,
    W = 1280,
    H = 720,
}

local stateModules = {
    menu = require("src.state_menu"),
    battle = require("src.state_battle"),
    result = require("src.state_result"),
    talent = require("src.state_talent"),
    settings = require("src.state_settings"),
}

local currentName = nil
local current = nil
local pendingName = nil
local pendingOpts = nil
local activeSave = nil

local api = {
    game = Game,
    save = Save,
    audio = Audio,
    ui = UI,
    talent = Talent,
    data = {
        waves = Waves,
        words = Words,
        enemies = Enemies,
        events = Events,
    },
}

function api.switch(name, opts)
    pendingName = name
    pendingOpts = opts
end

function api.setActiveSave(s)
    activeSave = s
    api.activeSave = s
end

function api.saveNow()
    if activeSave then
        activeSave.spent_by_branch = Talent.spentByBranch(activeSave.talents)
        Save.write(activeSave)
    end
end

function api.quit()
    api.saveNow()
    Save.saveConfig()
    love.event.quit()
end

function api.applyWindowMode(mode)
    Save.config.window = mode
    if mode == "fullscreen" then
        love.window.setFullscreen(true, "desktop")
    else
        love.window.setFullscreen(false)
        local w, h = mode:match("(%d+)x(%d+)")
        if w then
            love.window.setMode(tonumber(w), tonumber(h), {
                resizable = true,
                vsync = 1,
                msaa = 0,
            })
        end
    end
    updateScale()
end

-- 离线收益：上限 8h，按挂机脚本 / 值班小助手结算（流程 §14）
function api.applyOffline(save)
    if not save then
        return 0
    end
    local eff = Talent.effects(save.talents, save.influence)
    local cap = Waves.params.offline_cap_hours * 3600
    local seconds = math.min(save.offline_seconds or 0, cap)
    if seconds < 60 or eff.idle_base <= 0 then
        save.offline_seconds = 0
        return 0
    end
    local letters = eff.idle_base * (1 + eff.offline_rate) * seconds
    local heat = math.floor(letters * (1 + 0.1 * (save.influence or 0)))
    save.total_heat = (save.total_heat or 0) + heat
    save.offline_seconds = 0
    return heat
end

-- ---------------------------------------------------------------- 缩放

function updateScale()
    local w, h = love.graphics.getDimensions()
    local s = math.min(w / Game.W, h / Game.H)
    if s <= 0 then
        s = 1
    end
    Game.scale = s
    Game.ox = (w - Game.W * s) / 2
    Game.oy = (h - Game.H * s) / 2
end

function api.updateScale()
    updateScale()
end

local function toDesign(x, y)
    return (x - Game.ox) / Game.scale, (y - Game.oy) / Game.scale
end

-- ---------------------------------------------------------------- 生命周期

function love.load()
    math.randomseed(os.time())
    love.math.setRandomSeed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setBackgroundColor(UI.col.void)

    Save.init()
    Save.loadConfig()
    UI.init()
    Audio.init(Save.config)

    for _, mod in pairs(stateModules) do
        if mod.init then
            mod.init(api)
        end
    end

    updateScale()
    if Save.config.window and Save.config.window ~= "1280x720" then
        api.applyWindowMode(Save.config.window)
    end

    api.switch("menu")
    pendingName = "menu"
    pendingOpts = nil
end

local function setState(name, opts)
    if current and current.leave then
        current.leave()
    end
    currentName = name
    api.stateName = name
    current = stateModules[name]
    if current.enter then
        current.enter(opts)
    end
end

function love.update(dt)
    dt = math.min(dt, 0.05)
    Game.time = Game.time + dt

    local t0 = love.timer.getTime()
    UI.update(dt)
    Audio.update(dt)
    if current and current.update then
        current.update(dt)
    end
    if activeSave then
        activeSave.stats.play_time = (activeSave.stats.play_time or 0) + dt
    end
    Game.updMs = (love.timer.getTime() - t0) * 1000

    -- 状态切换放在 update 末尾，避免在遍历中打断
    if pendingName and (pendingName ~= currentName or pendingOpts) then
        local name, opts = pendingName, pendingOpts
        pendingName, pendingOpts = nil, nil
        setState(name, opts)
    end
end

function love.draw()
    local t0 = love.timer.getTime()
    love.graphics.clear(UI.col.void)
    love.graphics.push()
    love.graphics.translate(Game.ox, Game.oy)
    love.graphics.scale(Game.scale)
    if current and current.draw then
        current.draw()
    end
    UI.drawToasts()
    if Game.debug then
        love.graphics.setFont(UI.fonts[16])
        UI.rect(8, 138, 420, 16, UI.col.void, 0.7)
        UI.text(
            string.format(
                "FPS %d | update %.2fms | draw %.2fms | state %s",
                love.timer.getFPS(),
                Game.updMs,
                Game.drawMs,
                tostring(currentName)
            ),
            12,
            138,
            16,
            UI.col.green
        )
    end
    love.graphics.pop()
    Game.drawMs = (love.timer.getTime() - t0) * 1000
end

function love.keypressed(key)
    if key == "f11" then
        local full = love.window.getFullscreen()
        love.window.setFullscreen(not full, "desktop")
        updateScale()
        return
    end
    if key == "f3" then
        Game.debug = not Game.debug
        return
    end
    if current and current.keypressed then
        current.keypressed(key)
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    local dx, dy = toDesign(x, y)
    if current and current.mousepressed then
        current.mousepressed(dx, dy, button)
    end
end

function love.mousereleased(x, y, button)
    local dx, dy = toDesign(x, y)
    if current and current.mousereleased then
        current.mousereleased(dx, dy, button)
    end
end

function love.mousemoved(x, y, dx, dy)
    local mx, my = toDesign(x, y)
    if current and current.mousemoved then
        current.mousemoved(mx, my, dx / Game.scale, dy / Game.scale)
    end
end

function love.wheelmoved(x, y)
    if current and current.wheelmoved then
        current.wheelmoved(x, y)
    end
end

function love.resize(w, h)
    updateScale()
end

function love.focus(focused)
    if not focused then
        api.saveNow()
    end
end

function love.quit()
    api.saveNow()
    Save.saveConfig()
    return false
end
