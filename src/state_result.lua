-- 本轮结算：技能点构成、战绩、进入天赋屋（流程 §6.2）
local Result = {}

local api, UI, Save, Audio

local R = {
    time = 0,
    run = nil,
    retreat = false,
    victory = false,
    hover = false,
    lineT = 0,
}

function Result.init(a)
    api = a
    UI = a.ui
    Save = a.save
    Audio = a.audio
end

function Result.enter(opts)
    opts = opts or {}
    R.run = opts.run or {}
    R.retreat = opts.retreat or false
    R.victory = opts.victory or false
    R.time = 0
    R.lineT = 0
    if R.victory then
        Audio.playMusic("battle3")
    else
        Audio.playMusic("fail")
    end
    UI.clearToasts()
end

function Result.leave() end

function Result.update(dt)
    R.time = R.time + dt
end

local function title()
    if R.victory then
        return "通关 50 波"
    elseif R.retreat then
        return "主动撤退"
    end
    return "心态归零"
end

local function titleColor()
    if R.victory then
        return UI.col.gold
    elseif R.retreat then
        return UI.col.blue
    end
    return UI.col.red
end

function Result.draw()
    UI.background(R.time, titleColor())
    local run = R.run
    UI.text("本轮结算", 640, 60, 24, UI.col.dim, "center", 0)
    UI.text(title(), 640, 96, 32, titleColor(), "center", 0)

    -- 左侧：战绩
    UI.panel(120, 170, 500, 380, { title = "战绩", shadow = false })
    local lines = {
        { "通过波次", tostring(run.waves or 0) .. " / 50" },
        { "击破账号", tostring(run.kills or 0) },
        { "完整回怼", tostring(run.words or 0) .. " 句" },
        { "敲击字母", tostring(run.chars or 0) },
        { "最高连击", tostring(run.maxCombo or 0) },
        { "本波失误", tostring(run.misses or 0) },
        { "本波热度", UI.commaNum(run.heat or 0) },
    }
    local y = 214
    for _, line in ipairs(lines) do
        UI.text(line[1], 150, y, 16, UI.col.dim)
        UI.text(line[2], 440, y, 16, UI.col.text, "right", 0)
        y = y + 44
    end

    -- 右侧：技能点构成
    UI.panel(660, 170, 500, 380, { title = "技能点", shadow = false })
    local spWave = run.spWave or 0
    local spKill = run.spKill or 0
    local total = run.sp or 0
    local extra = total - spWave - spKill
    local rows = {
        { "波次结算", "+" .. spWave },
        { "击破账号", "+" .. spKill },
        { R.retreat and "撤退（无保底）" or "保底 / 首通 / 加成", (extra >= 0 and "+" or "") .. extra },
    }
    y = 214
    for _, row in ipairs(rows) do
        UI.text(row[1], 690, y, 16, UI.col.dim)
        UI.text(row[2], 1130, y, 16, UI.col.text, "right", 0)
        y = y + 44
    end
    UI.rect(690, 350, 440, 1, UI.col.line)
    UI.text("本轮获得", 690, 366, 16, UI.col.dim)
    UI.text("+" .. total .. " SP", 1130, 360, 32, UI.col.gold, "right", 0)

    local save = api.activeSave
    if save then
        UI.text("当前技能点 " .. UI.comma(save.sp or 0), 690, 410, 16, UI.col.cyan)
        UI.text("最高波次 " .. tostring(save.best_wave or 0), 690, 438, 16, UI.col.dim)
        UI.text("累计热度 " .. UI.commaNum(save.total_heat or 0), 690, 466, 16, UI.col.gold)
        UI.text("影响力 " .. UI.comma(save.influence or 0), 690, 494, 16, UI.col.purple)
    end

    -- 底部提示与按钮
    local hint = "失败只损失本轮剩余时间：技能点照结算，天赋不丢（流程 §9）"
    if R.retreat then
        hint = "主动撤退照常结算，但拿不到失败保底 +3"
    elseif R.victory then
        hint = "三阶段全部通过。换马甲条件达成后可以去点局外系。"
    end
    UI.text(hint, 640, 578, 16, UI.col.dim2, "center", 0)

    R.hover = UI.hit(R.mx or -1, R.my or -1, 540, 612, 200, 52)
    UI.button(540, 612, 200, 52, "进入天赋屋", { hover = R.hover, primary = true, size = 24 })
    UI.text("Enter 继续", 640, 676, 16, UI.col.dim2, "center", 0)
end

function Result.mousemoved(x, y)
    R.mx = x
    R.my = y
end

function Result.keypressed(key)
    if key == "return" or key == "kpenter" or key == "space" or key == "escape" then
        Audio.playMusic("talent")
        api.switch("talent")
    end
end

function Result.mousepressed(x, y, button)
    if button == 1 and UI.hit(x, y, 540, 612, 200, 52) then
        Audio.playMusic("talent")
        api.switch("talent")
    end
end

return Result
