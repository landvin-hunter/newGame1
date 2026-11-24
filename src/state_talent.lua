-- 天赋屋：可平移缩放的天赋树、洗点、出战、换马甲（流程 §6.3、§7、§11）
local Talent = require("src.talent")
local Layout = require("data.talents_layout")
local TalentState = {}

local api, UI, Save, Audio

local T = {
    zoom = 0.70,
    panX = 0,
    panY = 0,
    time = 0,
    mx = -1,
    my = -1,
    dragging = false,
    dragX = 0,
    dragY = 0,
    hoverId = nil,
    selectedId = nil,
    can = {},
    visible = {},
    confirmRebirth = false,
    hoverBtn = nil,
}

local VIEW = { x = 258, y = 76, w = 1004, h = 556 }
local BRANCH_COLOR = {
    ["输入"] = { 0.353, 0.851, 0.851 },
    ["自动"] = { 0.290, 0.702, 0.647 },
    ["辅助"] = { 0.400, 0.553, 0.949 },
    ["回怼"] = { 0.902, 0.451, 0.749 },
    ["战术"] = { 0.949, 0.800, 0.353 },
    ["防御"] = { 0.541, 0.847, 0.557 },
    ["全局"] = { 0.647, 0.498, 0.902 },
    ["局外"] = { 0.949, 0.596, 0.310 },
}

local function save()
    return api.activeSave
end

-- ---------------------------------------------------------------- 视图

local function fitView()
    local z = math.min(VIEW.w / Layout.world.w, VIEW.h / Layout.world.h) * 0.95
    T.zoom = math.max(0.32, math.min(1.2, z))
    T.panX = VIEW.x + (VIEW.w - Layout.world.w * T.zoom) / 2
    T.panY = VIEW.y + (VIEW.h - Layout.world.h * T.zoom) / 2
    T.viewMode = "fit"
end

local function centerView()
    -- 默认视野：把第一个系放在左面板右侧，玩家一进来就能看到起手节点
    T.zoom = 0.66
    T.panX = 300 - Layout.nodes["I01"].x * T.zoom
    T.panY = (VIEW.y + VIEW.h / 2) - 440 * T.zoom
    T.viewMode = "default"
end

local function toWorld(sx, sy)
    return (sx - T.panX) / T.zoom, (sy - T.panY) / T.zoom
end

local function inView(sx, sy)
    return sx >= VIEW.x and sx <= VIEW.x + VIEW.w and sy >= VIEW.y and sy <= VIEW.y + VIEW.h
end

local function nodeScreenRect(id)
    local n = Layout.nodes[id]
    if not n then
        return nil
    end
    local w = Layout.cell.w * T.zoom
    local h = Layout.cell.h * T.zoom
    return n.x * T.zoom + T.panX - w / 2, n.y * T.zoom + T.panY - h / 2, w, h
end

local function nodeAt(sx, sy)
    for _, node in ipairs(Talent.order) do
        if T.visible[node.id] then
            local x, y, w, h = nodeScreenRect(node.id)
            if x and UI.hit(sx, sy, x, y, w, h) then
                return node.id
            end
        end
    end
    return nil
end

local function refreshView()
    local s = save()
    T.can = {}
    T.visible = {}
    for _, n in ipairs(Talent.order) do
        T.visible[n.id] = Talent.isVisible(s, n.id)
        T.can[n.id] = Talent.check(s, n.id)
    end
end

-- ---------------------------------------------------------------- 生命周期

function TalentState.init(a)
    api = a
    UI = a.ui
    Save = a.save
    Audio = a.audio
    -- 节点名/前置文案只在启动时算一次，避免每帧截断字符串
    T.label = {}
    T.reqLabel = {}
    T.fullReq = {}
    for _, n in ipairs(Talent.order) do
        T.label[n.id] = UI.truncate(n.name, 16, Layout.cell.w - 26)
        T.fullReq[n.id] = Talent.reqText(n)
        T.reqLabel[n.id] = UI.truncate(T.fullReq[n.id], 16, 198)
    end
end

function TalentState.enter()
    if not api.activeSave then
        api.switch("menu")
        return
    end
    T.time = 0
    T.confirmRebirth = false
    T.selectedId = nil
    centerView()
    refreshView()
    Audio.playMusic("talent")
    UI.clearToasts()
    local s = save()
    if (s.fail_streak or 0) >= 3 then
        UI.toast("同一波连输 3 轮：去点防御系 / 自动系看看", UI.col.yellow, 4)
    end
end

function TalentState.leave() end

function TalentState.update(dt)
    T.time = T.time + dt
end

-- ---------------------------------------------------------------- 绘制

local function drawConnections()
    love.graphics.setLineWidth(2)
    local h = Layout.cell.h
    for _, n in ipairs(Talent.order) do
        if T.visible[n.id] then
            local pos = Layout.nodes[n.id]
            if pos and pos.parent and T.visible[pos.parent] then
                local p = Layout.nodes[pos.parent]
                local x1, y1 = p.x, p.y + h / 2
                local x2, y2 = pos.x, pos.y - h / 2
                local lv = Talent.level(save().talents, n.id)
                if lv > 0 then
                    UI.setColor(BRANCH_COLOR[n.branch] or UI.col.line2, 0.8)
                else
                    UI.setColor(UI.col.line, 0.7)
                end
                love.graphics.line(x1, y1, x1, (y1 + y2) / 2, x2, (y1 + y2) / 2, x2, y2)
            end
        end
    end
    love.graphics.setLineWidth(1)
end

local function drawTierGuides()
    for _, y in pairs(Layout.tier_y) do
        UI.rect(0, y - 1, Layout.world.w, 1, UI.col.line, 0.22)
    end
end

local function drawBranchHeaders()
    for _, branch in ipairs(Talent.branches) do
        local x = Layout.branch_x[branch] * T.zoom + T.panX
        if x > VIEW.x - 80 and x < VIEW.x + VIEW.w + 80 then
            local col = BRANCH_COLOR[branch] or UI.col.line2
            local pts = Talent.branchPoints(save().talents, branch)
            -- 表头固定在树区顶部，树本身可上下平移
            UI.text(branch .. "  " .. pts, x, VIEW.y, 24, col, "center", 0)
        end
    end
end

local function drawNode(id)
    local n = Talent.nodes[id]
    local pos = Layout.nodes[id]
    if not pos then
        return
    end
    local sx, sy, sw, sh = nodeScreenRect(id)
    if sx + sw < VIEW.x or sx > VIEW.x + VIEW.w or sy + sh < VIEW.y or sy > VIEW.y + VIEW.h then
        return
    end
    local w, h = Layout.cell.w, Layout.cell.h
    local x, y = pos.x - w / 2, pos.y - h / 2
    local lv = Talent.level(save().talents, id)
    local canBuy = T.can[id]
    local col = BRANCH_COLOR[n.branch] or UI.col.line2
    local hover = T.hoverId == id
    local selected = T.selectedId == id

    local bg
    local fg = UI.col.text
    local border
    if lv > 0 then
        bg = { col[1] * 0.24, col[2] * 0.24, col[3] * 0.26 }
        border = col
    elseif canBuy then
        bg = { 0.12, 0.20, 0.28 }
        border = UI.col.cyan
    else
        bg = UI.col.bg2
        border = UI.col.line
        fg = UI.col.dim2
    end
    if hover then
        bg = { bg[1] + 0.06, bg[2] + 0.07, bg[3] + 0.08 }
    end
    UI.rect(x, y, w, h, bg)
    UI.frame(x, y, w, h, border)
    if selected or hover then
        UI.frame(x - 2, y - 2, w + 4, h + 4, hover and UI.col.white or col, 0.6)
    end
    UI.rect(x, y, 3, h, lv > 0 and col or (canBuy and UI.col.cyan or UI.col.line))

    -- 卡片窄，只放名字 + 等级条 + 状态灯；详情看左侧面板
    local show = T.label[id] or n.name
    UI.text(show, x + 9, y + 3, 16, fg)
    local barW = w - 20
    UI.rect(x + 9, y + h - 10, barW, 4, UI.col.void)
    if lv > 0 then
        UI.rect(x + 9, y + h - 10, barW * math.min(1, lv / n.max), 4, col)
    end
    if lv >= n.max then
        UI.rect(x + w - 12, y + 5, 6, 6, UI.col.gold)
    elseif canBuy then
        UI.rect(x + w - 12, y + 5, 6, 6, UI.col.cyan)
    end
end

local function drawTree()
    UI.rect(VIEW.x, VIEW.y, VIEW.w, VIEW.h, UI.col.bg)
    -- 树本体在世界坐标里画，缩放/平移统一交给变换矩阵
    love.graphics.push()
    love.graphics.translate(T.panX, T.panY)
    love.graphics.scale(T.zoom)
    drawTierGuides()
    drawConnections()
    for _, n in ipairs(Talent.order) do
        if T.visible[n.id] then
            drawNode(n.id)
        end
    end
    love.graphics.pop()
    drawBranchHeaders()
end

local function drawLeftPanel()
    local s = save()
    UI.panel(16, 76, 230, 556, { shadow = false })
    UI.text("天赋屋", 32, 88, 24, UI.col.text)
    UI.rect(32, 120, 198, 1, UI.col.line)

    UI.text("技能点", 32, 132, 16, UI.col.dim)
    UI.text(UI.comma(s.sp or 0), 32, 152, 32, UI.col.gold)

    UI.text("已投入 " .. Talent.totalSpent(s.talents), 32, 196, 16, UI.col.dim)
    UI.text("节点 " .. Talent.countVisible(s) .. " 可见", 32, 218, 16, UI.col.dim)

    local nextId = Talent.nextTarget(s)
    local nextY = 248
    if nextId then
        local n = Talent.nodes[nextId]
        UI.text("下一目标", 32, nextY, 16, UI.col.cyan)
        UI.text(n.name, 32, nextY + 20, 16, UI.col.text)
        UI.text(n.tier .. " · " .. n.cost .. " SP", 32, nextY + 42, 16, UI.col.dim)
    end

    -- 洗点
    local respecCost = Talent.respecCost(s)
    local canRespec = respecCost > 0 and (s.influence or 0) >= respecCost
    local hover = UI.hit(T.mx, T.my, 32, 320, 198, 34)
    UI.button(32, 320, 198, 34, "洗点（" .. respecCost .. " 影响力）", {
        hover = hover,
        disabled = not canRespec,
    })
    if not canRespec and respecCost > 0 then
        UI.text("影响力不足", 32, 358, 16, UI.col.dim2)
    end

    -- 选中/悬停节点详情
    local showId = T.hoverId or T.selectedId
    UI.rect(32, 384, 198, 1, UI.col.line)
    if showId then
        local n = Talent.nodes[showId]
        local lv = Talent.level(s.talents, showId)
        UI.text(n.name, 32, 396, 16, UI.col.text)
        UI.icon(n.icon, 206, 394, 20, BRANCH_COLOR[n.branch] or UI.col.cyan)
        UI.text(n.branch .. " · " .. n.tier .. " · Lv" .. lv .. "/" .. n.max, 32, 418, 16, UI.col.dim)
        UI.text(n.desc, 32, 440, 16, UI.col.cyan)
        UI.text("每级 " .. n.cost .. " SP", 32, 486, 16, UI.col.dim)
        local ok, reason = Talent.check(s, showId)
        if lv >= n.max then
            UI.text("已点满", 32, 508, 16, UI.col.gold)
        elseif ok then
            UI.text("点击节点点亮", 32, 508, 16, UI.col.green)
        else
            UI.text(reason, 32, 508, 16, UI.col.red)
        end
        -- 前置条件一行显示，放不下就截断（完整原因见上方检查结果）
        UI.text(T.reqLabel[showId] or T.fullReq[showId] or "", 32, 530, 16, UI.col.dim2)
    else
        UI.text("鼠标悬停节点查看详情", 32, 396, 16, UI.col.dim2)
        UI.text("拖拽平移 · 滚轮缩放 · Z 全览", 32, 424, 16, UI.col.dim2)
    end

    local backHover = UI.hit(T.mx, T.my, 32, 592, 96, 30)
    UI.button(32, 592, 96, 30, "返回菜单", { hover = backHover })
    local fitHover = UI.hit(T.mx, T.my, 134, 592, 98, 30)
    UI.button(134, 592, 98, 30, "全览 Z", { hover = fitHover })
end

local function rebirthInfo()
    local s = save()
    local idx = (s.chapters or 0) + 1
    local P = api.data.waves.params
    if idx > #P.rebirth_heat then
        return false, "已换马甲 3 次"
    end
    local needHeat = P.rebirth_heat[idx]
    local needWave = P.rebirth_wave[idx]
    if (s.total_heat or 0) < needHeat then
        return false, "累计热度 " .. UI.commaNum(s.total_heat or 0) .. " / " .. UI.commaNum(needHeat)
    end
    if (s.best_wave or 0) < needWave then
        return false, "需通过第 " .. needWave .. " 波"
    end
    return true
end

local function influenceGain()
    local s = save()
    local eff = Talent.effects(s.talents, s.influence)
    local mul = eff.inf_mul * eff.inf_mul_2 * (1 + eff.fan_econ)
    return math.floor(math.sqrt((s.total_heat or 0) / 20000) * mul)
end

local function drawBottomBar()
    local s = save()
    UI.rect(0, 640, 1280, 80, UI.col.bg2)
    UI.rect(0, 640, 1280, 1, UI.col.line)
    UI.text("本轮纪录 " .. tostring(s.best_wave or 0) .. " / 50", 24, 656, 16, UI.col.text)
    UI.text("历史最高 " .. tostring(s.peak_wave or s.best_wave or 0) .. " 波", 24, 680, 16, UI.col.dim)
    UI.text(
        "换马甲 " .. tostring(s.chapters or 0) .. " 次 · 影响力 " .. UI.comma(s.influence or 0),
        280,
        656,
        16,
        UI.col.purple
    )
    local ok, reason = rebirthInfo()
    if ok then
        UI.text("换马甲可得 " .. influenceGain() .. " 影响力", 280, 680, 16, UI.col.cyan)
    else
        UI.text(reason, 280, 680, 16, UI.col.dim2)
    end

    local rebirthHover = UI.hit(T.mx, T.my, 820, 656, 210, 44)
    UI.button(820, 656, 210, 44, "换马甲", { hover = rebirthHover, disabled = not ok })
    UI.text(string.format("缩放 %d%%", math.floor(T.zoom * 100 + 0.5)), 640, 680, 16, UI.col.dim2)
    local fightHover = UI.hit(T.mx, T.my, 1048, 650, 210, 52)
    UI.button(1048, 650, 210, 52, "出战", { hover = fightHover, primary = true, size = 24 })
end

local function drawRebirthConfirm()
    UI.dim(0.7)
    UI.panel(380, 250, 520, 230, { shadow = false })
    UI.text("注销旧号，注册新号？", 640, 278, 24, UI.col.text, "center", 0)
    UI.text("获得 " .. influenceGain() .. " 点影响力", 640, 320, 16, UI.col.cyan, "center", 0)
    UI.text("保留技能点与天赋；重置波次纪录与本轮热度", 640, 346, 16, UI.col.dim, "center", 0)
    UI.text("演出：注销扫描线 → 注册新号 → 随机开场白", 640, 370, 16, UI.col.dim2, "center", 0)
    local yHover = UI.hit(T.mx, T.my, 440, 410, 160, 44)
    UI.button(440, 410, 160, 44, "确认换号", { hover = yHover, primary = true })
    local nHover = UI.hit(T.mx, T.my, 680, 410, 160, 44)
    UI.button(680, 410, 160, 44, "再想想", { hover = nHover })
end

function TalentState.draw()
    local s = save()
    if not s then
        return
    end
    UI.background(T.time * 0.3)
    drawTree()
    drawLeftPanel()
    drawBottomBar()
    if T.confirmRebirth then
        drawRebirthConfirm()
    end
end

-- ---------------------------------------------------------------- 行为

local function buyNode(id)
    local s = save()
    local ok, reason = Talent.check(s, id)
    if ok then
        if Talent.buy(s, id) then
            api.saveNow()
            refreshView()
            Audio.playSfx("buy")
            local n = Talent.nodes[id]
            UI.toast(n.name .. " → Lv" .. Talent.level(s.talents, id), BRANCH_COLOR[n.branch] or UI.col.cyan, 2)
        end
    else
        Audio.playSfx("miss")
        UI.toast(reason or "不可点", UI.col.dim, 2)
    end
    T.selectedId = id
end

local function doRebirth()
    local s = save()
    local eff = Talent.effects(s.talents, s.influence)
    local gain = influenceGain()
    s.influence = (s.influence or 0) + gain
    s.chapters = (s.chapters or 0) + 1
    s.total_heat = math.floor((s.total_heat or 0) * (eff.inherit or 0))
    s.best_wave = 0
    s.stats.best_wave = 0
    s.heat = 0
    s.fail_streak = 0
    s.fail_streak_wave = 0
    T.confirmRebirth = false
    api.saveNow()
    refreshView()
    Audio.playSfx("win")
    UI.toast("注销成功 +" .. gain .. " 影响力，新号已注册", UI.col.gold, 4)
end

function TalentState.keypressed(key)
    if T.confirmRebirth then
        if key == "return" or key == "kpenter" then
            doRebirth()
        elseif key == "escape" then
            T.confirmRebirth = false
        end
        return
    end
    if key == "escape" then
        api.saveNow()
        api.switch("menu")
    elseif key == "return" or key == "kpenter" then
        api.switch("battle")
    elseif key == "z" then
        if T.viewMode == "fit" then
            centerView()
        else
            fitView()
        end
    elseif key == "left" or key == "a" then
        T.panX = T.panX + 80
    elseif key == "right" or key == "d" then
        T.panX = T.panX - 80
    elseif key == "up" or key == "w" then
        T.panY = T.panY + 60
    elseif key == "down" or key == "s" then
        T.panY = T.panY - 60
    end
end

function TalentState.mousemoved(x, y, dx, dy)
    T.mx = x
    T.my = y
    if T.dragging then
        T.panX = T.panX + (dx or 0)
        T.panY = T.panY + (dy or 0)
    end
    if inView(x, y) then
        T.hoverId = nodeAt(x, y)
    else
        T.hoverId = nil
    end
end

function TalentState.mousepressed(x, y, button)
    T.mx = x
    T.my = y
    if button ~= 1 then
        return
    end
    if T.confirmRebirth then
        if UI.hit(x, y, 440, 410, 160, 44) then
            doRebirth()
        elseif UI.hit(x, y, 680, 410, 160, 44) then
            T.confirmRebirth = false
        end
        return
    end

    -- 面板按钮优先
    if UI.hit(x, y, 32, 592, 96, 30) then
        api.saveNow()
        api.switch("menu")
        return
    end
    if UI.hit(x, y, 134, 592, 98, 30) then
        if T.viewMode == "fit" then
            centerView()
        else
            fitView()
        end
        return
    end
    if UI.hit(x, y, 1048, 650, 210, 52) then
        api.switch("battle")
        return
    end
    if UI.hit(x, y, 820, 656, 210, 44) then
        local ok = rebirthInfo()
        if ok then
            T.confirmRebirth = true
        else
            Audio.playSfx("miss")
        end
        return
    end
    if UI.hit(x, y, 32, 320, 198, 34) then
        local s = save()
        local ok, err = Talent.respec(s)
        if ok then
            api.saveNow()
            refreshView()
            Audio.playSfx("buy")
            UI.toast("洗点完成，返还 " .. err .. " SP", UI.col.cyan, 3)
        else
            Audio.playSfx("miss")
            UI.toast(err or "洗点失败", UI.col.dim, 2)
        end
        return
    end

    if inView(x, y) then
        local id = nodeAt(x, y)
        if id then
            buyNode(id)
        else
            T.dragging = true
            T.dragX, T.dragY = x, y
        end
    end
end

function TalentState.mousereleased(x, y, button)
    T.dragging = false
end

function TalentState.wheelmoved(dx, dy)
    local mx, my = T.mx, T.my
    if not inView(mx, my) then
        return
    end
    local wx, wy = toWorld(mx, my)
    local factor = dy > 0 and 1.12 or 0.89
    T.zoom = math.max(0.32, math.min(1.3, T.zoom * factor))
    T.panX = mx - wx * T.zoom
    T.panY = my - wy * T.zoom
end

return TalentState
