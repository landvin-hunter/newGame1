-- 主菜单 / 存档列表 / 新建存档（游戏类型 §3、§4）
local Menu = {}

local api, UI, Save, Audio

local PLATFORMS = {
    { name = "私信", color = { 0.353, 0.851, 0.851 } },
    { name = "评论区", color = { 0.949, 0.800, 0.353 } },
    { name = "热搜榜", color = { 0.902, 0.451, 0.749 } },
}

local ITEMS = {
    { id = "start", label = "开始游戏" },
    { id = "continue", label = "继续游戏" },
    { id = "settings", label = "设置" },
    { id = "quit", label = "退出" },
}

local LINES = {
    "「你行你上」—— 行，我上。",
    "「就这？」—— 就这，也能敲。",
    "他们扔的是弹幕，你还回去的是标点。",
    "一个键盘，一群账号，谁也不服谁。",
}

Menu.mode = "logo"
Menu.logoT = 0
Menu.time = 0
Menu.sel = 1
Menu.slots = {}
Menu.slotSel = 1
Menu.confirmDelete = nil
Menu.nick = "键盘侠"
Menu.platform = 1
Menu.mouse = { x = 0, y = 0 }
Menu.line = 1
Menu.lineT = 0
Menu.error = nil

local function platformOf(idx)
    return PLATFORMS[idx] or PLATFORMS[1]
end

local function accent()
    return platformOf(Menu.platform).color
end

local function refreshSlots()
    Menu.slots = {}
    local names = Save.slots()
    for _, slot in ipairs(names) do
        local meta = Save.meta(slot)
        if meta then
            Menu.slots[#Menu.slots + 1] = meta
        end
    end
    if #Menu.slots == 0 then
        Menu.slotSel = 1
    else
        Menu.slotSel = math.max(1, math.min(Menu.slotSel, #Menu.slots))
    end
end

local function mainItems()
    local out = {}
    for i, item in ipairs(ITEMS) do
        out[i] = item
        if item.id == "continue" then
            out[i].disabled = #Menu.slots == 0
        end
    end
    return out
end

local function openSlots()
    refreshSlots()
    Menu.mode = "slots"
    Menu.confirmDelete = nil
    Menu.error = nil
    -- 有存档时默认选中上次退出的槽位
    local last = Save.config.last_slot
    for i, s in ipairs(Menu.slots) do
        if s.slot == last then
            Menu.slotSel = i
        end
    end
    Audio.playSfx("click")
end

local function loadSlot(slot)
    local data = Save.load(slot)
    if not data then
        Menu.error = "存档读取失败"
        return
    end
    Save.config.last_slot = slot
    Save.saveConfig()
    api.setActiveSave(data)
    local gain = api.applyOffline(data)
    if gain > 0 then
        UI.toast("离线收益 +" .. UI.commaNum(gain) .. " 热度", UI.col.gold, 4)
    end
    Audio.playSfx("click")
    api.switch("talent")
end

local function createSlot()
    local nick = Menu.nick
    if nick == "" then
        nick = "键盘侠"
    end
    local slot = Save.createSlot(nick, Menu.platform)
    if not slot then
        Menu.error = "存档槽已满"
        return
    end
    Save.config.last_slot = slot
    Save.saveConfig()
    local data = Save.load(slot)
    api.setActiveSave(data)
    Audio.playSfx("click")
    -- 新档直接从第 1 波开始
    api.switch("battle", { fresh = true })
end

function Menu.init(a)
    api = a
    UI = a.ui
    Save = a.save
    Audio = a.audio
end

function Menu.enter()
    -- 开发者 Logo 只在启动时出现一次，回菜单不重复播放
    if not Menu.booted then
        Menu.mode = "logo"
        Menu.logoT = 0
        Menu.booted = true
    else
        Menu.mode = "main"
    end
    Menu.sel = 1
    Menu.error = nil
    Menu.confirmDelete = nil
    Menu.time = 0
    refreshSlots()
    if #Menu.slots > 0 then
        Menu.sel = 2
    end
    if api.activeSave and api.activeSave.platform then
        Menu.platform = api.activeSave.platform
    end
    Audio.playMusic("menu")
    UI.clearToasts()
end

function Menu.leave() end

function Menu.update(dt)
    Menu.time = Menu.time + dt
    if Menu.mode == "logo" then
        Menu.logoT = Menu.logoT + dt
        if Menu.logoT >= 0.6 then
            Menu.mode = "main"
        end
    end
    Menu.lineT = Menu.lineT + dt
    if Menu.lineT > 5 then
        Menu.lineT = 0
        Menu.line = Menu.line % #LINES + 1
    end
    if api.activeSave and api.activeSave.platform then
        Menu.platform = api.activeSave.platform
    end
end

-- ---------------------------------------------------------------- 绘制

local function drawLogo()
    UI.rect(0, 0, 1280, 720, UI.col.void)
    local a = math.min(1, Menu.logoT * 6)
    UI.setColor(UI.col.cyan, a)
    UI.rect(590, 320, 100, 8, UI.col.cyan, a)
    UI.text("像 素 工 坊", 640, 350, 24, UI.col.text, "center", 0)
    UI.text("PIXEL FORGE", 640, 382, 16, UI.col.dim, "center", 0)
    UI.text("键盘侠 / KEYBOARD HERO", 640, 420, 16, UI.col.dim2, "center", 0)
    if Menu.logoT > 0.25 then
        UI.text("按任意键跳过", 640, 640, 16, UI.col.dim2, "center", 0)
    end
end

local function drawTitle()
    local col = accent()
    UI.text("键 盘 侠", 640, 96, 32, UI.col.text, "center", 0)
    UI.rect(500, 140, 280, 2, col, 0.8)
    UI.text("KEYBOARD HERO  ·  把恶评敲回去", 640, 152, 16, UI.col.dim, "center", 0)
end

local function drawMain()
    drawTitle()
    local items = mainItems()
    local startY = 300
    for i, item in ipairs(items) do
        local y = startY + (i - 1) * 62
        local x, w, h = 480, 320, 48
        local hover = UI.hit(Menu.mouse.x, Menu.mouse.y, x, y, w, h) and not item.disabled
        local active = Menu.sel == i
        local bg = UI.col.panel
        local fg = UI.col.text
        if item.disabled then
            bg = UI.col.bg2
            fg = UI.col.dim2
        elseif hover or active then
            bg = { 0.19, 0.34, 0.36 }
        end
        UI.rect(x, y, w, h, bg)
        UI.frame(x, y, w, h, item.disabled and UI.col.line or (active and accent() or UI.col.line2))
        if active then
            UI.rect(x, y, 4, h, accent())
            UI.setColor(accent())
            love.graphics.polygon("fill", x + 16, y + 14, x + 16, y + 34, x + 29, y + 24)
        end
        UI.text(item.label, x, y + 11, 24, fg, "center", w)
    end

    -- 底部状态行
    UI.text(LINES[Menu.line], 640, 620, 16, UI.col.dim, "center", 0)
    UI.text("↑↓ 选择   Enter 确认   F11 全屏", 640, 660, 16, UI.col.dim2, "center", 0)
    UI.text("存档 " .. #Menu.slots .. " / " .. Save.MAX_SLOTS, 24, 688, 16, UI.col.dim2)
    UI.text("v0.5 · Love2D", 1256, 688, 16, UI.col.dim2, "right", 0)
end

local function slotRowRect(i)
    return 240, 150 + (i - 1) * 76, 800, 68
end

local function drawSlots()
    UI.dim(0.78)
    UI.panel(190, 60, 900, 610, { title = "存档列表", shadow = false })

    UI.text("选择存档进入天赋屋；新档直接从第 1 波开始", 210, 96, 16, UI.col.dim)

    if #Menu.slots == 0 then
        UI.text("还没有存档", 640, 300, 24, UI.col.dim2, "center", 0)
    end

    for i, s in ipairs(Menu.slots) do
        local x, y, w, h = slotRowRect(i)
        local hover = UI.hit(Menu.mouse.x, Menu.mouse.y, x, y, w, h)
        local selected = Menu.slotSel == i
        UI.rect(x, y, w, h, selected and { 0.19, 0.30, 0.32 } or (hover and UI.col.panel2 or UI.col.bg2))
        UI.frame(x, y, w, h, selected and accent() or UI.col.line)
        if selected then
            UI.rect(x, y, 4, h, accent())
        end
        local col = platformOf(s.platform).color
        UI.rect(x + 12, y + 12, 6, h - 24, col)
        UI.text(s.nick, x + 28, y + 8, 24, UI.col.text)
        UI.text("第 " .. tostring(s.best_wave or 0) .. " 波", x + 28, y + 38, 16, UI.col.dim)
        UI.text("SP " .. UI.comma(s.sp or 0), x + 180, y + 12, 16, UI.col.cyan)
        UI.text("影响力 " .. UI.comma(s.influence or 0), x + 180, y + 36, 16, UI.col.purple)
        UI.text("天赋 " .. tostring(s.talent_count or 0) .. " 个", x + 330, y + 12, 16, UI.col.dim)
        UI.text("时长 " .. UI.clock(s.play_time or 0), x + 330, y + 36, 16, UI.col.dim2)
        UI.text("换马甲 " .. tostring(s.chapters or 0) .. " 次", x + 470, y + 12, 16, UI.col.dim)
        if Save.config.last_slot == s.slot then
            UI.text("上次存档", x + 470, y + 36, 16, UI.col.gold)
        end

        -- 行内按钮
        local bx = x + w - 170
        local enterHover = UI.hit(Menu.mouse.x, Menu.mouse.y, bx, y + 16, 74, 36)
        UI.button(bx, y + 16, 74, 36, "进入", { hover = enterHover, primary = true })
        local delHover = UI.hit(Menu.mouse.x, Menu.mouse.y, bx + 84, y + 16, 74, 36)
        UI.button(bx + 84, y + 16, 74, 36, "删除", { hover = delHover })
    end

    local newHover = UI.hit(Menu.mouse.x, Menu.mouse.y, 240, 608, 160, 44)
    UI.button(240, 608, 160, 44, "＋ 新建存档", { hover = newHover, primary = true, disabled = #Menu.slots >= Save.MAX_SLOTS })
    local backHover = UI.hit(Menu.mouse.x, Menu.mouse.y, 940, 608, 130, 44)
    UI.button(940, 608, 130, 44, "返回", { hover = backHover })
    UI.text("Enter 进入   Delete 删除   Esc 返回", 640, 680, 16, UI.col.dim2, "center", 0)

    if Menu.confirmDelete then
        UI.dim(0.5)
        UI.panel(400, 280, 480, 170, { shadow = false })
        UI.text("删除存档「" .. Menu.confirmDelete.nick .. "」？", 640, 300, 16, UI.col.text, "center", 0)
        UI.text("删除后不可恢复（会二次确认）", 640, 326, 16, UI.col.red, "center", 0)
        local yHover = UI.hit(Menu.mouse.x, Menu.mouse.y, 440, 370, 160, 44)
        UI.button(440, 370, 160, 44, "确认删除", { hover = yHover, primary = true })
        local nHover = UI.hit(Menu.mouse.x, Menu.mouse.y, 680, 370, 160, 44)
        UI.button(680, 370, 160, 44, "取消", { hover = nHover })
    end
end

local function drawNewSlot()
    UI.dim(0.8)
    UI.panel(330, 140, 620, 440, { title = "新建存档", shadow = false })

    UI.text("昵称（只接受 A~Z，避免中文输入法）", 370, 190, 16, UI.col.dim)
    UI.rect(370, 214, 540, 44, UI.col.void)
    UI.frame(370, 214, 540, 44, UI.col.cyan)
    UI.text(Menu.nick .. "_", 386, 222, 24, UI.col.text)

    UI.text("初始平台皮肤", 370, 286, 16, UI.col.dim)
    for i, p in ipairs(PLATFORMS) do
        local x = 370 + (i - 1) * 180
        local hover = UI.hit(Menu.mouse.x, Menu.mouse.y, x, 310, 160, 54)
        local on = Menu.platform == i
        UI.rect(x, 310, 160, 54, on and { 0.19, 0.32, 0.34 } or UI.col.panel2)
        UI.frame(x, 310, 160, 54, on and p.color or UI.col.line)
        UI.rect(x + 10, 322, 6, 30, p.color)
        UI.text(p.name, x + 22, 322, 16, on and UI.col.text or UI.col.dim)
    end

    if Menu.error then
        UI.text(Menu.error, 640, 390, 16, UI.col.red, "center", 0)
    end

    local okHover = UI.hit(Menu.mouse.x, Menu.mouse.y, 370, 480, 240, 48)
    UI.button(370, 480, 240, 48, "创建并开打", { hover = okHover, primary = true })
    local cancelHover = UI.hit(Menu.mouse.x, Menu.mouse.y, 640, 480, 240, 48)
    UI.button(640, 480, 240, 48, "取消", { hover = cancelHover })
    UI.text("Enter 确认   Esc 返回    ← → 选皮肤", 640, 552, 16, UI.col.dim2, "center", 0)
end

function Menu.draw()
    if Menu.mode == "logo" then
        drawLogo()
        return
    end
    UI.background(Menu.time, accent())
    if Menu.mode == "main" then
        drawMain()
    elseif Menu.mode == "slots" then
        drawMain()
        drawSlots()
    elseif Menu.mode == "newslot" then
        drawMain()
        drawNewSlot()
    end
    if Menu.mode ~= "main" then
        -- 覆盖层下压暗主菜单
        UI.rect(0, 0, 1280, 720, UI.col.void, 0.2)
    end
end

-- ---------------------------------------------------------------- 输入

local function activate(id)
    if id == "start" or id == "continue" then
        openSlots()
    elseif id == "settings" then
        Audio.playSfx("click")
        api.switch("settings")
    elseif id == "quit" then
        api.quit()
    end
end

function Menu.keypressed(key)
    if Menu.mode == "logo" then
        Menu.mode = "main"
        return
    end

    if Menu.mode == "main" then
        local items = mainItems()
        if key == "up" or key == "w" then
            Menu.sel = Menu.sel > 1 and Menu.sel - 1 or #items
        elseif key == "down" or key == "s" then
            Menu.sel = Menu.sel < #items and Menu.sel + 1 or 1
        elseif key == "return" or key == "kpenter" or key == "space" then
            local item = items[Menu.sel]
            if item and not item.disabled then
                activate(item.id)
            end
        elseif key == "escape" then
            api.quit()
        end
        return
    end

    if Menu.mode == "slots" then
        if Menu.confirmDelete then
            if key == "return" or key == "kpenter" then
                Save.deleteSlot(Menu.confirmDelete.slot)
                Menu.confirmDelete = nil
                refreshSlots()
                Audio.playSfx("miss")
            elseif key == "escape" then
                Menu.confirmDelete = nil
            end
            return
        end
        if key == "escape" then
            Menu.mode = "main"
            Audio.playSfx("click")
        elseif key == "up" or key == "w" then
            Menu.slotSel = math.max(1, Menu.slotSel - 1)
        elseif key == "down" or key == "s" then
            Menu.slotSel = math.min(math.max(1, #Menu.slots), Menu.slotSel + 1)
        elseif key == "return" or key == "kpenter" then
            local s = Menu.slots[Menu.slotSel]
            if s then
                loadSlot(s.slot)
            end
        elseif key == "delete" then
            local s = Menu.slots[Menu.slotSel]
            if s then
                Menu.confirmDelete = s
            end
        elseif key == "n" then
            Menu.mode = "newslot"
            Menu.nick = "键盘侠"
            Menu.error = nil
        end
        return
    end

    if Menu.mode == "newslot" then
        if key == "escape" then
            Menu.mode = "slots"
        elseif key == "backspace" then
            if Menu.nick ~= "" then
                -- UTF-8 安全退格
                Menu.nick = UI.utf8sub(Menu.nick, 1, UI.utf8len(Menu.nick) - 1)
            end
        elseif key == "left" then
            Menu.platform = Menu.platform > 1 and Menu.platform - 1 or #PLATFORMS
        elseif key == "right" or key == "tab" then
            Menu.platform = Menu.platform < #PLATFORMS and Menu.platform + 1 or 1
        elseif key == "return" or key == "kpenter" then
            createSlot()
        elseif #key == 1 and key:match("[a-z]") then
            if #Menu.nick < 24 then
                Menu.nick = Menu.nick .. key:upper()
                Audio.playSfx("type")
            end
        elseif #key == 1 and key:match("[0-9]") then
            if #Menu.nick < 24 then
                Menu.nick = Menu.nick .. key
                Audio.playSfx("type")
            end
        end
    end
end

function Menu.mousemoved(x, y)
    Menu.mouse.x = x
    Menu.mouse.y = y
end

function Menu.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end
    Menu.mouse.x = x
    Menu.mouse.y = y

    if Menu.mode == "logo" then
        Menu.mode = "main"
        return
    end

    if Menu.mode == "main" then
        local items = mainItems()
        for i, item in ipairs(items) do
            local yy = 300 + (i - 1) * 62
            if UI.hit(x, y, 480, yy, 320, 48) and not item.disabled then
                Menu.sel = i
                activate(item.id)
                return
            end
        end
        return
    end

    if Menu.mode == "slots" then
        if Menu.confirmDelete then
            if UI.hit(x, y, 440, 370, 160, 44) then
                Save.deleteSlot(Menu.confirmDelete.slot)
                Menu.confirmDelete = nil
                refreshSlots()
                Audio.playSfx("miss")
            elseif UI.hit(x, y, 680, 370, 160, 44) then
                Menu.confirmDelete = nil
            end
            return
        end
        for i, s in ipairs(Menu.slots) do
            local rx, ry, rw, rh = slotRowRect(i)
            if UI.hit(x, y, rx, ry, rw, rh) then
                Menu.slotSel = i
                local bx = rx + rw - 170
                if UI.hit(x, y, bx, ry + 16, 74, 36) then
                    loadSlot(s.slot)
                    return
                elseif UI.hit(x, y, bx + 84, ry + 16, 74, 36) then
                    Menu.confirmDelete = s
                    return
                end
                return
            end
        end
        if UI.hit(x, y, 240, 608, 160, 44) then
            Menu.mode = "newslot"
            Menu.nick = "键盘侠"
            Menu.error = nil
        elseif UI.hit(x, y, 940, 608, 130, 44) then
            Menu.mode = "main"
        end
        return
    end

    if Menu.mode == "newslot" then
        for i = 1, #PLATFORMS do
            local px = 370 + (i - 1) * 180
            if UI.hit(x, y, px, 310, 160, 54) then
                Menu.platform = i
                return
            end
        end
        if UI.hit(x, y, 370, 480, 240, 48) then
            createSlot()
        elseif UI.hit(x, y, 640, 480, 240, 48) then
            Menu.mode = "slots"
        end
    end
end

return Menu
