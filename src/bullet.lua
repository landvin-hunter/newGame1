-- 弹幕与回怼对象池（规范 §5.19：每帧不新建 table）
-- 一个弹幕 = 1 条拼音串；敲完 → 回怼弹幕飞回来源账号
local UI = require("src.ui")

local Bullet = {}

local MAX = 160
local RETORT_MAX = 128
local CELL_W = 15
local CELL_H = 26
local COLS = 10

Bullet.MAX = MAX
Bullet.RETORT_MAX = RETORT_MAX
Bullet.list = {}
Bullet.retorts = {}
Bullet.count = 0
Bullet.retortCount = 0
Bullet.frozen = false

local function newBullet()
    return {
        active = false,
        x = 0,
        y = 0,
        sx = 0,
        sy = 0,
        tx = 0,
        ty = 0,
        t = 0,
        dur = 10,
        letters = "",
        len = 0,
        typed = 0,
        word = nil,
        dmg = 5,
        layer = 1,
        layers = 1,
        armor = 0,
        src = 0,
        boss = false,
        tag = false,
        marker = false,
        immune = false,
        split = false,
        splitDone = false,
        shuffle = false,
        shuffleT = 0,
        selected = false,
        flash = 0,
        sway = 0,
        arrived = false,
        pass = 0,
        color = { 1, 1, 1 },
        autoMark = 0,
        holdT = 0,
    }
end

local function newRetort()
    return {
        active = false,
        x = 0,
        y = 0,
        sx = 0,
        sy = 0,
        tx = 0,
        ty = 0,
        t = 0,
        dur = 0.2,
        dmg = 0,
        target = 0,
        text = "",
        arrived = false,
        crit = false,
        kind = "normal",
        pierce = 0,
        done = false,
    }
end

for i = 1, MAX do
    Bullet.list[i] = newBullet()
end

for i = 1, RETORT_MAX do
    Bullet.retorts[i] = newRetort()
end

function Bullet.reset()
    for i = 1, MAX do
        Bullet.list[i].active = false
        Bullet.list[i].arrived = false
    end
    for i = 1, RETORT_MAX do
        Bullet.retorts[i].active = false
    end
    Bullet.count = 0
    Bullet.retortCount = 0
    Bullet.frozen = false
end

local function colorFor(b)
    if b.boss then
        return UI.col.red
    end
    local n = b.len
    if n <= 2 then
        return UI.col.white
    elseif n <= 5 then
        return UI.col.cyan
    elseif n <= 9 then
        return UI.col.yellow
    end
    return UI.col.magenta
end

-- opts: letters, word, x, y, tx, ty, dur, layers, armor, src, boss, tag,
--       marker, immune, split, shuffle, dmg
function Bullet.spawn(opts)
    for i = 1, MAX do
        local b = Bullet.list[i]
        if not b.active then
            b.active = true
            b.arrived = false
            b.x = opts.x
            b.y = opts.y
            b.sx = opts.x
            b.sy = opts.y
            b.tx = opts.tx
            b.ty = opts.ty
            b.t = 0
            b.dur = opts.dur or 10
            b.letters = opts.letters
            b.len = #opts.letters
            b.typed = 0
            b.word = opts.word
            b.dmg = opts.dmg or 5
            b.layer = 1
            b.layers = opts.layers or 1
            b.armor = opts.armor or 0
            b.src = opts.src or false
            b.boss = opts.boss or false
            b.tag = opts.tag or false
            b.marker = opts.marker or false
            b.immune = opts.immune or false
            b.split = opts.split or false
            b.splitDone = false
            b.shuffle = opts.shuffle or false
            b.shuffleT = 0
            b.selected = false
            b.flash = 0
            b.pass = 0
            b.autoMark = 0
            b.holdT = 0
            b.sway = love.math.random() * 6.28
            b.color = colorFor(b)
            Bullet.count = Bullet.count + 1
            return b
        end
    end
    return nil
end

function Bullet.remove(b)
    if b and b.active then
        b.active = false
        b.arrived = false
        b.selected = false
        Bullet.count = math.max(0, Bullet.count - 1)
    end
end

function Bullet.shuffleRest(b)
    local done = b.letters:sub(1, b.typed)
    local rest = b.letters:sub(b.typed + 1)
    local chars = {}
    for i = 1, #rest do
        chars[i] = rest:sub(i, i)
    end
    for i = #chars, 2, -1 do
        local j = love.math.random(i)
        chars[i], chars[j] = chars[j], chars[i]
    end
    b.letters = done .. table.concat(chars)
end

-- 敲一个字母；返回 "hit" | "pass" | "done"
-- pass = 这一遍敲完了但还有护甲/层数，需要再敲一遍
function Bullet.typeLetter(b)
    b.typed = b.typed + 1
    if b.typed >= b.len then
        if b.armor > 0 then
            b.armor = b.armor - 1
            b.typed = 0
            b.pass = b.pass + 1
            return "pass"
        elseif b.layer < b.layers then
            b.layer = b.layer + 1
            b.typed = 0
            b.pass = b.pass + 1
            return "pass"
        end
        return "done"
    end
    return "hit"
end

function Bullet.miss(b, speedMul)
    if not b or not b.active then
        return
    end
    b.flash = 0.3
    b.dur = math.max(1.2, b.dur / (speedMul or 1.2))
end

function Bullet.update(dt)
    if Bullet.frozen then
        dt = 0
    end
    for i = 1, MAX do
        local b = Bullet.list[i]
        if b.active then
            if b.flash > 0 then
                b.flash = math.max(0, b.flash - dt)
            end
            local bdt = dt
            if b.holdT > 0 then
                b.holdT = b.holdT - dt
                bdt = 0
            end
            if b.shuffle and bdt > 0 then
                b.shuffleT = b.shuffleT + bdt
                if b.shuffleT >= 1 then
                    b.shuffleT = b.shuffleT - 1
                    Bullet.shuffleRest(b)
                end
            end
            b.t = b.t + bdt / b.dur
            if b.t >= 1 then
                b.t = 1
                b.arrived = true
            else
                local t = b.t
                local px = b.sx + (b.tx - b.sx) * t
                local py = b.sy + (b.ty - b.sy) * t
                -- 轻微摆动，避免所有气泡走同一条直线
                local nx = -(b.ty - b.sy)
                local ny = b.tx - b.sx
                local nl = math.sqrt(nx * nx + ny * ny)
                if nl > 0.001 then
                    local amp = math.sin(t * 6.28 + b.sway) * 7
                    px = px + nx / nl * amp
                    py = py + ny / nl * amp
                end
                b.x = px
                b.y = py
            end
        end
    end
end

-- ---------------------------------------------------------------- 回怼

function Bullet.spawnRetort(opts)
    for i = 1, RETORT_MAX do
        local r = Bullet.retorts[i]
        if not r.active then
            r.active = true
            r.arrived = false
            r.x = opts.x
            r.y = opts.y
            r.sx = opts.x
            r.sy = opts.y
            r.tx = opts.tx
            r.ty = opts.ty
            r.t = 0
            r.dur = opts.dur or 0.2
            r.dmg = opts.dmg or 0
            r.target = opts.target or false
            r.text = opts.text or "反弹！"
            r.crit = opts.crit or false
            r.kind = opts.kind or "normal"
            r.pierce = opts.pierce or 0
            r.done = false
            Bullet.retortCount = Bullet.retortCount + 1
            return r
        end
    end
    return nil
end

function Bullet.updateRetorts(dt)
    if Bullet.frozen then
        dt = 0
    end
    for i = 1, RETORT_MAX do
        local r = Bullet.retorts[i]
        if r.active then
            r.t = r.t + dt / r.dur
            if r.t >= 1 then
                r.t = 1
                r.arrived = true
            else
                r.x = r.sx + (r.tx - r.sx) * r.t
                r.y = r.sy + (r.ty - r.sy) * r.t
            end
        end
    end
end

function Bullet.removeRetort(r)
    if r and r.active then
        r.active = false
        r.arrived = false
        Bullet.retortCount = math.max(0, Bullet.retortCount - 1)
    end
end

function Bullet.clearAll()
    for i = 1, MAX do
        Bullet.list[i].active = false
    end
    Bullet.count = 0
end

function Bullet.clearRetorts()
    for i = 1, RETORT_MAX do
        Bullet.retorts[i].active = false
    end
    Bullet.retortCount = 0
end

-- ---------------------------------------------------------------- 绘制

-- 长句用更小的字模，避免 40 条弹幕时整个屏幕被气泡盖满
local function bubbleMetrics(b)
    local font, cw, ch, cols
    if b.len <= 12 then
        font, cw, ch, cols = 24, CELL_W, CELL_H, COLS
    elseif b.len <= 30 then
        font, cw, ch, cols = 16, 10, 18, 14
    else
        font, cw, ch, cols = 16, 10, 18, 18
    end
    local shown = math.min(b.len, cols)
    if shown < 1 then
        shown = 1
    end
    local rows = math.ceil(b.len / cols)
    local w = shown * cw + 18
    local h = rows * ch + 14
    return w, h, cols, rows, font, cw, ch
end

local function jitter(b)
    if b.flash > 0 then
        return love.math.random(-2, 2), love.math.random(-2, 2)
    end
    return 0, 0
end

function Bullet.draw()
    for i = 1, MAX do
        local b = Bullet.list[i]
        if b.active then
            local w, h, cols, rows, fontSize, cellW, cellH = bubbleMetrics(b)
            local jx, jy = jitter(b)
            local bx = b.x - w / 2 + jx
            local by = b.y - h / 2 + jy
            local col = b.flash > 0 and UI.col.red or b.color

            -- 气泡主体与朝向角色的尾巴
            UI.rect(bx + 2, by + 2, w, h, UI.col.void, 0.55)
            UI.rect(bx, by, w, h, UI.col.panel)
            UI.frame(bx, by, w, h, b.selected and UI.col.white or col, b.selected and 1 or 0.85)
            if b.selected then
                UI.frame(bx - 2, by - 2, w + 4, h + 4, UI.col.cyan, 0.5)
            end
            local tailX = bx + w / 2
            UI.rect(tailX - 5, by + h, 10, 4, UI.col.panel)
            UI.rect(tailX - 2, by + h, 4, 8, col, 0.7)

            -- 字母：已敲掉的变暗留空
            love.graphics.setFont(UI.fonts[fontSize])
            for idx = 0, b.len - 1 do
                local ch = b.letters:sub(idx + 1, idx + 1)
                local cx = bx + 9 + (idx % cols) * cellW
                local cy = by + 6 + math.floor(idx / cols) * cellH
                local done = idx < b.typed
                local alpha = done and 0.22 or 1
                UI.setColor(done and UI.col.dim2 or col, alpha)
                love.graphics.print(ch, cx + 1, cy - (fontSize == 24 and 2 or 0))
                if not done and idx == b.typed then
                    UI.rect(cx, cy + cellH - 5, cellW - 2, 2, UI.col.white, 0.9)
                end
            end

            -- 状态用细条表示，避免 40 条弹幕时全是文字角标
            if b.armor > 0 then
                UI.rect(bx, by - 4, w, 3, UI.col.cyan, 0.9)
            end
            if b.layers > 1 then
                UI.rect(bx, by + h + 1, w, 3, UI.col.void, 0.9)
                UI.rect(bx, by + h + 1, w * (b.layer / b.layers), 3, UI.col.yellow, 0.9)
            end
            if b.marker then
                UI.text("推荐位", bx, by - 20, 16, UI.col.gold)
            end
            if b.tag then
                UI.text("#", bx - 12, by + 2, 24, UI.col.cyan)
            end
        end
    end
end

function Bullet.drawRetorts()
    for i = 1, RETORT_MAX do
        local r = Bullet.retorts[i]
        if r.active then
            local col = r.crit and UI.col.gold or UI.col.cyan
            local tw = UI.textWidth(r.text, 16)
            local w = tw + 16
            local x = r.x - w / 2
            local y = r.y - 12
            UI.rect(x + 1, y + 1, w, 22, UI.col.void, 0.6)
            UI.rect(x, y, w, 22, col)
            UI.text(r.text, x, y + 2, 16, UI.col.void, "center", w)
            -- 拖尾
            UI.rect(x - 14, y + 8, 14, 4, col, 0.35)
            UI.rect(x - 24, y + 9, 10, 2, col, 0.18)
        end
    end
end

return Bullet
