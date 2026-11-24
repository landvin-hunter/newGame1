-- 绘制基础：调色板、字体、控件、程序化像素图标
-- 说明：图标在正式 Tabler PNG 到位前先用硬边图形占位（见 assets/MISSING.md）
local UI = {}

UI.fonts = {}
UI.fontSizes = { 8, 16, 24, 32 }
UI.font_source = "default"

local function tryLoadSystemFont()
    -- 正式像素字体缺失时，从系统字体临时取一套中文字形；不把系统字体放进仓库
    local candidates = {
        "C:/Windows/Fonts/simhei.ttf",
        "C:/Windows/Fonts/msyh.ttc",
        "C:/Windows/Fonts/Deng.ttf",
    }
    for _, path in ipairs(candidates) do
        local f = io.open(path, "rb")
        if f then
            local data = f:read("*a")
            f:close()
            if data and #data > 10000 then
                local ok = pcall(love.filesystem.write, "_font_cn.ttf", data)
                if ok then
                    return true
                end
            end
        end
    end
    return false
end

function UI.init()
    local fileData = nil
    if love.filesystem.getInfo("assets/font/font_cn.ttf") then
        fileData = love.filesystem.newFileData("assets/font/font_cn.ttf")
        UI.font_source = "assets/font/font_cn.ttf"
    elseif love.filesystem.getInfo("_font_cn.ttf") or tryLoadSystemFont() then
        fileData = love.filesystem.newFileData("_font_cn.ttf")
        UI.font_source = "system:simhei (临时)"
    end

    for _, size in ipairs(UI.fontSizes) do
        local font
        if fileData then
            local ok, f = pcall(love.graphics.newFont, fileData, size)
            if ok and f then
                font = f
            end
        end
        if not font then
            font = love.graphics.newFont(size)
        end
        font:setLineHeight(1.25)
        font:setFilter("nearest", "nearest")
        UI.fonts[size] = font
    end
    love.graphics.setFont(UI.fonts[16])
end

-- ---------------------------------------------------------------- 调色板

-- 低饱和 32 色，统一在这里取，不在状态里写零散颜色
UI.col = {
    void = { 0.055, 0.063, 0.086 },
    bg = { 0.078, 0.090, 0.122 },
    bg2 = { 0.098, 0.113, 0.153 },
    panel = { 0.129, 0.149, 0.196 },
    panel2 = { 0.165, 0.188, 0.243 },
    line = { 0.243, 0.275, 0.333 },
    line2 = { 0.314, 0.353, 0.420 },
    text = { 0.878, 0.898, 0.925 },
    dim = { 0.557, 0.588, 0.647 },
    dim2 = { 0.404, 0.435, 0.494 },
    white = { 0.988, 0.992, 1.0 },
    cyan = { 0.353, 0.851, 0.851 },
    blue = { 0.400, 0.553, 0.949 },
    deepblue = { 0.235, 0.325, 0.588 },
    yellow = { 0.949, 0.800, 0.353 },
    gold = { 1.0, 0.847, 0.388 },
    orange = { 0.949, 0.596, 0.310 },
    magenta = { 0.902, 0.451, 0.749 },
    red = { 0.902, 0.376, 0.376 },
    darkred = { 0.541, 0.216, 0.235 },
    green = { 0.541, 0.847, 0.557 },
    teal = { 0.290, 0.702, 0.647 },
    purple = { 0.647, 0.498, 0.902 },
}

function UI.setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

-- ---------------------------------------------------------------- 基础图形

function UI.rect(x, y, w, h, c, a)
    UI.setColor(c, a)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y), math.floor(w), math.floor(h))
end

function UI.frame(x, y, w, h, c, a)
    UI.setColor(c, a)
    love.graphics.rectangle("line", math.floor(x) + 0.5, math.floor(y) + 0.5, math.floor(w), math.floor(h))
end

function UI.text(str, x, y, size, c, align, width)
    local font = UI.fonts[size] or UI.fonts[16]
    love.graphics.setFont(font)
    UI.setColor(c or UI.col.text)
    -- 宽度为 0 时用“按文本宽度反推起点”，避免 printf(limit=0) 一个字都不画
    if align == "center" then
        if width and width > 0 then
            love.graphics.printf(str, x, y, width, "center")
        else
            love.graphics.print(str, math.floor(x - font:getWidth(str) / 2), math.floor(y))
        end
    elseif align == "right" then
        if width and width > 0 then
            love.graphics.printf(str, x, y, width, "right")
        else
            love.graphics.print(str, math.floor(x - font:getWidth(str)), math.floor(y))
        end
    else
        love.graphics.print(str, math.floor(x), math.floor(y))
    end
end

function UI.textWidth(str, size)
    local font = UI.fonts[size] or UI.fonts[16]
    return font:getWidth(str)
end

-- UTF-8 安全的按字符截取/计数：Lua 5.1 没有 utf8 库，按首字节判断长度
function UI.utf8len(s)
    local n = 0
    local pos = 1
    while pos <= #s do
        local b = s:byte(pos)
        local len = 1
        if b >= 240 then
            len = 4
        elseif b >= 224 then
            len = 3
        elseif b >= 192 then
            len = 2
        end
        n = n + 1
        pos = pos + len
    end
    return n
end

function UI.utf8sub(s, i, j)
    local n = 0
    local startByte, endByte = nil, nil
    local pos = 1
    while pos <= #s do
        local b = s:byte(pos)
        local len = 1
        if b >= 240 then
            len = 4
        elseif b >= 224 then
            len = 3
        elseif b >= 192 then
            len = 2
        end
        n = n + 1
        if n == i then
            startByte = pos
        end
        if n == j then
            endByte = pos + len - 1
            break
        end
        pos = pos + len
    end
    if not startByte then
        return ""
    end
    return s:sub(startByte, endByte or #s)
end

-- 按像素宽度截断，返回截断后的字符串与被截断的字符数
function UI.truncate(str, size, maxW)
    if UI.textWidth(str, size) <= maxW then
        return str, 0
    end
    local n = UI.utf8len(str)
    local cut = 0
    while n - cut > 0 and UI.textWidth(UI.utf8sub(str, 1, n - cut), size) > maxW - size do
        cut = cut + 1
    end
    return UI.utf8sub(str, 1, math.max(1, n - cut)) .. "…", cut
end

function UI.panel(x, y, w, h, opts)
    opts = opts or {}
    local bg = opts.bg or UI.col.panel
    local border = opts.border or UI.col.line
    UI.rect(x, y, w, h, bg)
    if opts.shadow ~= false then
        UI.rect(x + 3, y + 3, w, h, UI.col.void, 0.5)
        UI.rect(x, y, w, h, bg)
    end
    UI.frame(x, y, w, h, border)
    if opts.title then
        UI.text(opts.title, x + 12, y + 8, 16, opts.title_color or UI.col.cyan)
        UI.rect(x + 8, y + 30, w - 16, 1, UI.col.line)
    end
end

function UI.hit(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function UI.button(x, y, w, h, label, opts)
    opts = opts or {}
    local disabled = opts.disabled
    local hover = opts.hover and not disabled
    local bg = UI.col.panel2
    local fg = UI.col.text
    if disabled then
        bg = UI.col.panel
        fg = UI.col.dim2
    elseif opts.primary then
        bg = hover and { 0.30, 0.62, 0.62 } or { 0.22, 0.45, 0.47 }
        fg = UI.col.white
    elseif hover then
        bg = { 0.24, 0.28, 0.35 }
    end
    UI.rect(x, y, w, h, bg)
    UI.frame(x, y, w, h, disabled and UI.col.line or (hover and UI.col.cyan or UI.col.line2))
    if hover then
        UI.rect(x, y, 3, h, UI.col.cyan)
    elseif opts.primary then
        UI.rect(x, y, 3, h, UI.col.teal)
    end
    UI.text(label, x, y + (h - 24) / 2 + 1, opts.size or 16, fg, "center", w)
end

function UI.bar(x, y, w, h, ratio, fg, bg)
    ratio = math.max(0, math.min(1, ratio or 0))
    UI.rect(x, y, w, h, bg or UI.col.void)
    if ratio > 0 then
        UI.rect(x, y, math.max(1, w * ratio), h, fg or UI.col.red)
    end
    UI.frame(x, y, w, h, UI.col.line)
end

function UI.toggle(x, y, w, on, label)
    local h = 20
    UI.rect(x, y, w, h, UI.col.panel2)
    UI.frame(x, y, w, h, on and UI.col.teal or UI.col.line2)
    local knobX = on and (x + w - 36) or (x + 4)
    UI.rect(knobX, y + 4, 32, h - 8, on and UI.col.teal or UI.col.dim2)
    UI.text(on and "开" or "关", knobX, y + 2, 16, on and UI.col.void or UI.col.text, "center", 32)
    if label then
        UI.text(label, x - 8, y + 2, 16, UI.col.text, "right", 0)
    end
end

function UI.slider(x, y, w, value, label)
    local h = 8
    UI.rect(x, y, w, h, UI.col.void)
    UI.rect(x, y, math.max(2, w * value), h, UI.col.teal)
    UI.frame(x, y, w, h, UI.col.line)
    local knob = x + w * value
    UI.rect(knob - 4, y - 4, 8, h + 8, UI.col.text)
    if label then
        UI.text(label .. "  " .. string.format("%d%%", math.floor(value * 100 + 0.5)), x, y - 24, 16, UI.col.dim)
    end
end

-- ---------------------------------------------------------------- 图标（占位）

local iconShapes = {}

iconShapes.keyboard = function(c)
    UI.rect(2, 6, 20, 12, c, 0.9)
    UI.rect(4, 8, 2, 2, UI.col.void)
    UI.rect(8, 8, 2, 2, UI.col.void)
    UI.rect(12, 8, 2, 2, UI.col.void)
    UI.rect(16, 8, 2, 2, UI.col.void)
    UI.rect(7, 13, 10, 2, UI.col.void)
end

iconShapes.crown = function(c)
    UI.rect(3, 8, 18, 3, c)
    UI.rect(3, 11, 18, 7, c, 0.85)
    UI.rect(5, 3, 3, 6, c)
    UI.rect(11, 2, 3, 7, c)
    UI.rect(17, 3, 3, 6, c)
    UI.rect(6, 14, 2, 2, UI.col.void)
    UI.rect(11, 14, 2, 2, UI.col.void)
    UI.rect(16, 14, 2, 2, UI.col.void)
end

iconShapes.shield = function(c)
    UI.rect(6, 2, 12, 3, c)
    UI.rect(4, 5, 16, 8, c, 0.9)
    UI.rect(7, 13, 10, 3, c, 0.85)
    UI.rect(10, 16, 4, 3, c, 0.8)
    UI.rect(11, 7, 2, 6, UI.col.void)
    UI.rect(8, 9, 8, 2, UI.col.void)
end

iconShapes.chip = function(c)
    UI.rect(6, 6, 12, 12, c, 0.9)
    UI.rect(9, 9, 6, 6, UI.col.void)
    for i = 0, 2 do
        UI.rect(8 + i * 4, 2, 2, 3, c)
        UI.rect(8 + i * 4, 19, 2, 3, c)
        UI.rect(2, 8 + i * 4, 3, 2, c)
        UI.rect(19, 8 + i * 4, 3, 2, c)
    end
end

iconShapes.people = function(c)
    UI.rect(7, 3, 5, 5, c)
    UI.rect(3, 10, 13, 3, c, 0.9)
    UI.rect(5, 13, 9, 6, c, 0.7)
    UI.rect(15, 5, 4, 4, c, 0.7)
    UI.rect(14, 11, 7, 3, c, 0.6)
    UI.rect(15, 14, 5, 5, c, 0.5)
end

iconShapes.bolt = function(c)
    UI.rect(12, 2, 6, 8, c)
    UI.rect(8, 9, 8, 4, c)
    UI.rect(6, 12, 8, 4, c)
    UI.rect(6, 15, 5, 7, c)
end

iconShapes.star = function(c)
    UI.rect(10, 2, 4, 6, c)
    UI.rect(3, 7, 18, 4, c)
    UI.rect(6, 10, 12, 4, c)
    UI.rect(8, 14, 8, 5, c)
    UI.rect(4, 18, 4, 3, c, 0.7)
    UI.rect(16, 18, 4, 3, c, 0.7)
end

iconShapes.arrow = function(c)
    UI.rect(4, 11, 12, 3, c)
    UI.rect(14, 8, 3, 8, c)
    UI.rect(17, 6, 3, 5, c)
    UI.rect(17, 13, 3, 5, c)
end

iconShapes.box = function(c)
    UI.rect(4, 6, 16, 14, c, 0.85)
    UI.rect(4, 6, 16, 3, c)
    UI.rect(10, 12, 4, 2, UI.col.void)
end

iconShapes.flag = function(c)
    UI.rect(5, 2, 3, 20, c)
    UI.rect(8, 3, 11, 8, c, 0.8)
    UI.rect(8, 3, 2, 8, c)
end

iconShapes.clock = function(c)
    UI.rect(7, 2, 10, 2, c)
    UI.rect(4, 5, 3, 12, c)
    UI.rect(17, 5, 3, 12, c)
    UI.rect(7, 18, 10, 3, c)
    UI.rect(6, 7, 2, 8, c, 0.8)
    UI.rect(16, 7, 2, 8, c, 0.8)
    UI.rect(11, 7, 2, 6, c)
    UI.rect(11, 12, 5, 2, c)
end

local iconAlias = {
    keyboard = "keyboard",
    crown = "crown",
    shield = "shield",
    star = "star",
    sparkle = "star",
    mood = "star",
    heart = "star",
    bolt = "bolt",
    trending = "bolt",
    wave = "bolt",
    users = "people",
    user = "people",
    robot = "chip",
    cpu = "chip",
    server = "chip",
    cloud = "chip",
    copy = "chip",
    file = "chip",
    device = "chip",
    router = "chip",
    arrow = "arrow",
    hand = "arrow",
    target = "arrow",
    message = "arrow",
    search = "arrow",
    speaker = "arrow",
    megaphone = "arrow",
    clock = "clock",
    hourglass = "clock",
    time = "clock",
    building = "box",
    contract = "box",
    archive = "box",
    lock = "box",
    book = "box",
    pin = "box",
    trash = "box",
    fold = "box",
    filter = "box",
    letter = "box",
    text = "box",
    nuclear = "box",
    brain = "box",
    badge = "box",
    sunglasses = "box",
    flag = "flag",
    shield = "shield",
    crown = "crown",
}

function UI.icon(name, x, y, size, c)
    local key = (name or ""):lower()
    local shapeName = "box"
    for prefix, target in pairs(iconAlias) do
        if key:find(prefix, 1, true) then
            shapeName = target
            break
        end
    end
    local shape = iconShapes[shapeName]
    if not shape then
        shape = iconShapes.box
    end
    local s = (size or 24) / 24
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(s, s)
    shape(c or UI.col.cyan)
    love.graphics.pop()
end

-- ---------------------------------------------------------------- 数字/文本格式

function UI.comma(n)
    local s = string.format("%.0f", n or 0)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if out:sub(1, 1) == "," then
        out = out:sub(2)
    end
    return out
end

function UI.commaNum(n)
    n = n or 0
    if n < 10000 then
        return string.format("%.0f", n)
    end
    if n < 100000000 then
        return string.format("%.1f万", n / 10000)
    end
    return string.format("%.2f亿", n / 100000000)
end

function UI.clock(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%d:%02d", m, s)
end

-- ---------------------------------------------------------------- 提示条

UI.toasts = {}

function UI.toast(text, c, seconds)
    UI.toasts[#UI.toasts + 1] = {
        text = text,
        color = c or UI.col.text,
        t = seconds or 2.4,
        age = 0,
    }
end

function UI.update(dt)
    local i = 1
    while i <= #UI.toasts do
        local t = UI.toasts[i]
        t.t = t.t - dt
        t.age = t.age + dt
        if t.t <= 0 then
            table.remove(UI.toasts, i)
        else
            i = i + 1
        end
    end
end

function UI.drawToasts()
    local y = 96
    for _, t in ipairs(UI.toasts) do
        local alpha = math.min(1, t.t * 2, t.age * 5)
        local w = UI.textWidth(t.text, 16) + 24
        UI.rect(640 - w / 2, y, w, 28, UI.col.panel2, alpha)
        UI.frame(640 - w / 2, y, w, 28, t.color, alpha)
        UI.text(t.text, 640 - w / 2, y + 5, 16, t.color, "center", w)
        y = y + 34
    end
end

function UI.clearToasts()
    UI.toasts = {}
end

-- ---------------------------------------------------------------- 背景

function UI.background(t, accent)
    UI.rect(0, 0, 1280, 720, UI.col.bg)
    UI.setColor(UI.col.line, 0.14)
    for x = 0, 1280, 64 do
        love.graphics.line(x, 0, x, 720)
    end
    for y = 0, 720, 64 do
        love.graphics.line(0, y, 1280, y)
    end
    love.graphics.setFont(UI.fonts[24])
    for i = 1, 18 do
        local sp = (i % 4) + 1
        local x = ((i * 173 + t * 12 * sp) % 1440) - 80
        local y = ((i * 97 + t * 18 * (i % 3 + 1)) % 840) - 60
        local ch = string.char(65 + (i * 7) % 26)
        UI.setColor(accent or UI.col.line2, 0.08 + (i % 3) * 0.03)
        love.graphics.print(ch, x, y)
    end
    for i = 0, 7 do
        UI.rect(0, i * 12, 1280, 12, UI.col.void, 0.05 * (8 - i))
    end
end

function UI.dim(alpha)
    UI.rect(0, 0, 1280, 720, UI.col.void, alpha or 0.72)
end

return UI
