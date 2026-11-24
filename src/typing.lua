-- 打字判定：选中优先级、连击、失误，以及自动补全类效果（流程 §4.2~4.4）
local Bullet = require("src.bullet")

local Typing = {}

local params = {
    window = 1.2,
    bonus = 0.05,
    cap = 0.5,
    step = 10,
    predict = 0,
    fuzzy = 0,
    dualHand = 0,
    undoPerWave = 0,
}

Typing.combo = 0
Typing.comboTimer = 0
Typing.missStreak = 0
Typing.undoLeft = 0
Typing.maxCombo = 0

-- 复用结果表，按键处理不产生垃圾
Typing.result = {
    kind = "empty",
    bullet = nil,
    letters = 0,
    extra = nil,
    extraKind = nil,
    extraLetters = 0,
    fuzzy = false,
}

function Typing.reset(opts)
    params.window = opts.window or 1.2
    params.bonus = opts.bonus or 0.05
    params.cap = opts.cap or 0.5
    params.step = opts.step or 10
    params.predict = opts.predict or 0
    params.fuzzy = opts.fuzzy or 0
    params.dualHand = opts.dualHand or 0
    params.undoPerWave = opts.undoPerWave or 0
    Typing.combo = 0
    Typing.comboTimer = 0
    Typing.missStreak = 0
    Typing.undoLeft = opts.undoPerWave or 0
    Typing.maxCombo = 0
end

-- 每波开局刷新「撤回」次数
function Typing.refreshWave()
    Typing.undoLeft = params.undoPerWave
end

function Typing.update(dt)
    if Typing.combo > 0 then
        Typing.comboTimer = Typing.comboTimer + dt
        if Typing.comboTimer > params.window then
            Typing.combo = 0
            Typing.comboTimer = 0
        end
    end
end

function Typing.comboMul()
    if Typing.combo < params.step then
        return 1
    end
    local tiers = math.floor(Typing.combo / params.step)
    return 1 + math.min(tiers * params.bonus, params.cap)
end

function Typing.window()
    return params.window
end

-- ---------------------------------------------------------------- 邻键（模糊匹配用）

local ADJ = {}
do
    local rows = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }
    local offset = { 0, 0.35, 0.9 }
    for r, row in ipairs(rows) do
        for i = 1, #row do
            local ch = row:sub(i, i)
            ADJ[ch] = ADJ[ch] or {}
            if i > 1 then
                ADJ[ch][row:sub(i - 1, i - 1)] = true
            end
            if i < #row then
                ADJ[ch][row:sub(i + 1, i + 1)] = true
            end
            local upper = rows[r - 1]
            local lower = rows[r + 1]
            for _, other in ipairs({ upper, lower }) do
                if other then
                    local center = math.floor(i + (offset[r] or 0))
                    for k = center - 1, center + 1 do
                        local c = other:sub(k, k)
                        if c ~= "" then
                            ADJ[ch][c] = true
                        end
                    end
                end
            end
        end
    end
end

local function isAdjacent(a, b)
    return ADJ[a] ~= nil and ADJ[a][b] == true
end

-- ---------------------------------------------------------------- 选中

local function nextChar(b)
    if b.typed >= b.len then
        return nil
    end
    return b.letters:sub(b.typed + 1, b.typed + 1)
end

local function dist2(b, px, py)
    local dx = b.x - px
    local dy = b.y - py
    return dx * dx + dy * dy
end

-- 返回：目标弹幕（可空）、是否用了模糊匹配
local function findTarget(ch, px, py)
    local best, bestD = nil, nil
    -- ① 续字优先：已经敲了一部分的气泡
    for i = 1, Bullet.MAX do
        local b = Bullet.list[i]
        if b.active and not b.arrived and b.typed > 0 and nextChar(b) == ch then
            local d = dist2(b, px, py)
            if not bestD or d < bestD then
                best, bestD = b, d
            end
        end
    end
    if best then
        return best, false
    end
    -- ② 屏幕上离角色最近、且剩余字母里含该字母的气泡
    for i = 1, Bullet.MAX do
        local b = Bullet.list[i]
        if b.active and not b.arrived and b.typed < b.len then
            if b.letters:find(ch, b.typed + 1, true) then
                local d = dist2(b, px, py)
                if not bestD or d < bestD then
                    best, bestD = b, d
                end
            end
        end
    end
    return best, false
end

local function findPartial(ch, px, py, exclude)
    local best, bestD = nil, nil
    for i = 1, Bullet.MAX do
        local b = Bullet.list[i]
        if b.active and not b.arrived and b ~= exclude and nextChar(b) == ch then
            local d = dist2(b, px, py)
            if not bestD or d < bestD then
                best, bestD = b, d
            end
        end
    end
    return best
end

-- 当前选中的气泡（给 UI 高亮）
function Typing.setSelected(b)
    for i = 1, Bullet.MAX do
        local x = Bullet.list[i]
        x.selected = x == b
    end
end

-- ---------------------------------------------------------------- 按键

-- 返回 Typing.result：
--   kind = "empty" | "hit" | "pass" | "done"
--   letters = 本次按键实际敲掉的字母数（模糊/联想可能 >1）
function Typing.press(ch, px, py)
    local r = Typing.result
    r.kind = "empty"
    r.bullet = nil
    r.letters = 0
    r.extra = nil
    r.extraKind = nil
    r.extraLetters = 0
    r.fuzzy = false

    local target = findTarget(ch, px, py)

    -- 模糊匹配：按错相邻键也判定正确
    if not target and params.fuzzy > 0 and Typing.combo > 0 then
        -- 找最近的有部分进度的气泡，判断它下一个字母是否与按下的键相邻
        local best, bestD = nil, nil
        for i = 1, Bullet.MAX do
            local b = Bullet.list[i]
            if b.active and not b.arrived and b.typed > 0 and b.typed < b.len then
                local nc = nextChar(b)
                if nc and isAdjacent(nc, ch) then
                    local d = dist2(b, px, py)
                    if not bestD or d < bestD then
                        best, bestD = b, d
                    end
                end
            end
        end
        if best and love.math.random() <= params.fuzzy then
            target = best
            r.fuzzy = true
        end
    end

    if not target then
        -- 有敲了一半的气泡却按错键 → 失误；否则空敲不惩罚
        local partial, partialD = nil, nil
        for i = 1, Bullet.MAX do
            local b = Bullet.list[i]
            if b.active and not b.arrived and b.typed > 0 and b.typed < b.len then
                local d = dist2(b, px, py)
                if not partialD or d < partialD then
                    partial, partialD = b, d
                end
            end
        end
        if partial then
            r.kind = "miss"
            r.bullet = partial
        else
            r.kind = "empty"
        end
        return r
    end

    Typing.setSelected(target)
    local kind = Bullet.typeLetter(target)
    r.bullet = target
    r.letters = 1
    r.kind = kind

    Typing.combo = Typing.combo + 1
    Typing.comboTimer = 0
    if Typing.combo > Typing.maxCombo then
        Typing.maxCombo = Typing.combo
    end

    -- 双手互搏：同一按键再喂给另一条气泡
    if params.dualHand > 0 and kind == "hit" then
        local extra = findPartial(ch, px, py, target)
        if extra then
            local ek = Bullet.typeLetter(extra)
            r.extra = extra
            r.extraKind = ek
            r.extraLetters = 1
        end
    end

    -- 输入法联想：概率直接补完一条
    if kind == "hit" and params.predict > 0 and love.math.random() < params.predict then
        local guard = 0
        local k = "hit"
        while k == "hit" and guard < 128 do
            k = Bullet.typeLetter(target)
            r.letters = r.letters + 1
            guard = guard + 1
        end
        r.kind = k
        r.extra = nil
        r.extraKind = nil
        r.extraLetters = 0
    end

    return r
end

-- 手动指定敲击（自动补全类技能用），返回 "hit"/"pass"/"done"
function Typing.strike(b)
    return Bullet.typeLetter(b)
end

function Typing.miss()
    if Typing.undoLeft > 0 then
        Typing.undoLeft = Typing.undoLeft - 1
        return false, true
    end
    Typing.combo = 0
    Typing.comboTimer = 0
    Typing.missStreak = Typing.missStreak + 1
    local penalty = Typing.missStreak % 3 == 0
    return penalty, false
end

function Typing.resetMiss()
    Typing.missStreak = 0
end

function Typing.params()
    return params
end

return Typing
