-- 设置：窗口、音量、脏话缩写、搞笑梗强度（游戏类型 §5）
local Settings = {}

local api, UI, Save, Audio

local S = {
    time = 0,
    mx = -1,
    my = -1,
    dragging = nil,
}

local WINDOWS = {
    { mode = "1280x720", label = "1280×720" },
    { mode = "1600x900", label = "1600×900" },
    { mode = "1920x1080", label = "1920×1080" },
    { mode = "fullscreen", label = "全屏" },
}

local HUMORS = { "低", "中", "高" }

local function windowRect(i)
    return 60 + (i - 1) * 220, 176, 200, 44
end

local function humorRect(i)
    return 60 + (i - 1) * 150, 276, 130, 44
end

local function sliderRect(which)
    if which == "bgm" then
        return 200, 424, 400, 12
    end
    return 200, 484, 400, 12
end

function Settings.init(a)
    api = a
    UI = a.ui
    Save = a.save
    Audio = a.audio
end

function Settings.enter()
    S.time = 0
    S.dragging = nil
    Audio.playMusic("menu")
end

function Settings.leave() end

function Settings.update(dt)
    S.time = S.time + dt
end

local function cfg()
    return Save.config
end

local function saveSettings()
    Save.saveConfig()
end

local function setSlider(which, x)
    local sx, sy, sw, sh = sliderRect(which)
    local v = math.max(0, math.min(1, (x - sx) / sw))
    if which == "bgm" then
        cfg().bgm = v
        Audio.setVolumes(v, nil)
    else
        cfg().sfx = v
        Audio.setVolumes(nil, v)
    end
    saveSettings()
end

function Settings.draw()
    UI.background(S.time * 0.25)
    UI.text("设置", 640, 48, 32, UI.col.text, "center", 0)
    UI.rect(500, 92, 280, 2, UI.col.cyan, 0.8)

    -- 窗口
    UI.text("窗口大小", 60, 140, 16, UI.col.dim)
    for i, w in ipairs(WINDOWS) do
        local x, y, ww, hh = windowRect(i)
        local on = cfg().window == w.mode
        local hover = UI.hit(S.mx, S.my, x, y, ww, hh)
        UI.rect(x, y, ww, hh, on and { 0.19, 0.34, 0.36 } or (hover and UI.col.panel2 or UI.col.panel))
        UI.frame(x, y, ww, hh, on and UI.col.cyan or UI.col.line)
        UI.text(w.label, x, y + 11, 16, on and UI.col.text or UI.col.dim, "center", ww)
    end

    -- 搞笑梗强度
    UI.text("搞笑梗强度", 60, 244, 16, UI.col.dim)
    for i, h in ipairs(HUMORS) do
        local x, y, w, hh = humorRect(i)
        local onH = cfg().humor == h
        local hover = UI.hit(S.mx, S.my, x, y, w, hh)
        UI.rect(x, y, w, hh, onH and { 0.19, 0.34, 0.36 } or (hover and UI.col.panel2 or UI.col.panel))
        UI.frame(x, y, w, hh, onH and UI.col.cyan or UI.col.line)
        UI.text(h, x, y + 12, 16, onH and UI.col.text or UI.col.dim, "center", w)
    end
    local humorDesc = "中：全部词条，按波次分层抽取"
    if cfg().humor == "低" then
        humorDesc = "低：只留 T2/T4 中性词，去掉「孝」「绷」这类反讽梗"
    elseif cfg().humor == "高" then
        humorDesc = "高：全部词条，单字梗穿插更频繁"
    end
    UI.text(humorDesc, 60, 330, 16, UI.col.dim2)

    -- 音量
    UI.text("音量", 60, 380, 16, UI.col.dim)
    local bx, by = sliderRect("bgm")
    UI.text("BGM", 60, by - 6, 16, UI.col.dim)
    UI.slider(bx, by, 400, cfg().bgm, nil)
    UI.text(string.format("%d%%", math.floor(cfg().bgm * 100 + 0.5)), 620, by - 4, 16, UI.col.text)
    local sx, sy = sliderRect("sfx")
    UI.text("音效", 60, sy - 6, 16, UI.col.dim)
    UI.slider(sx, sy, 400, cfg().sfx, nil)
    UI.text(string.format("%d%%", math.floor(cfg().sfx * 100 + 0.5)), 620, sy - 4, 16, UI.col.text)
    UI.text("0.2s 插值；默认 BGM 70% / SFX 100%", 200, 512, 16, UI.col.dim2)

    -- 屏蔽脏话缩写
    UI.text("屏蔽脏话缩写", 60, 550, 16, UI.col.dim)
    local on = cfg().filter_profanity
    UI.toggle(200, 540, 56, on)
    UI.text(
        on and "开启：CNM / NMSL 不进词池" or "关闭：20 波后才出现，且不参与 Boss 长句",
        270,
        550,
        16,
        UI.col.dim2
    )

    local backHover = UI.hit(S.mx, S.my, 540, 616, 200, 48)
    UI.button(540, 616, 200, 48, "返回", { hover = backHover, primary = true })
    UI.text("Esc 返回   F11 全屏", 640, 680, 16, UI.col.dim2, "center", 0)
end

local function setWindow(mode)
    api.applyWindowMode(mode)
    saveSettings()
    Audio.playSfx("click")
end

local function setHumor(h)
    cfg().humor = h
    saveSettings()
    Audio.playSfx("click")
end

local function toggleProfanity()
    cfg().filter_profanity = not cfg().filter_profanity
    saveSettings()
    Audio.playSfx("click")
end

function Settings.keypressed(key)
    if key == "escape" or key == "return" or key == "kpenter" then
        api.switch("menu")
    end
end

function Settings.mousemoved(x, y, dx, dy)
    S.mx = x
    S.my = y
    if S.dragging then
        setSlider(S.dragging, x)
    end
end

function Settings.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end
    S.mx = x
    S.my = y
    for i, w in ipairs(WINDOWS) do
        local wx, wy, ww, hh = windowRect(i)
        if UI.hit(x, y, wx, wy, ww, hh) then
            setWindow(w.mode)
            return
        end
    end
    for i, h in ipairs(HUMORS) do
        local hx, hy, hw, hh = humorRect(i)
        if UI.hit(x, y, hx, hy, hw, hh) then
            setHumor(h)
            return
        end
    end
    local bx, by = sliderRect("bgm")
    if UI.hit(x, y, bx, by - 8, 400, 28) then
        S.dragging = "bgm"
        setSlider("bgm", x)
        return
    end
    local sx, sy = sliderRect("sfx")
    if UI.hit(x, y, sx, sy - 8, 400, 28) then
        S.dragging = "sfx"
        setSlider("sfx", x)
        return
    end
    if UI.hit(x, y, 200, 538, 76, 28) then
        toggleProfanity()
        return
    end
    if UI.hit(x, y, 540, 616, 200, 48) then
        api.switch("menu")
    end
end

function Settings.mousereleased()
    S.dragging = nil
end

return Settings
