-- 战斗：1~50 波、弹幕对轰、自动字符率、技能、随机事件（流程 §3~§5、§9~§10）
local api, UI, Save, Audio, Bullet, Typing, Talent
local Waves, Words, Enemies, Events

local Battle = {}

local P = nil -- 波次核心参数

local SLOT_COUNT = 16
local MAX_ENEMIES = 40

local RING = { cx = 640, cy = 400, rx = 520, ry = 250 }
local PLAYER = { x = 640, y = 556 }

local TIP_ID = "skill_delete"
local SKILL_ORDER = {
    "skill_delete", "skill_freeze", "skill_wash", "blocklist", "skill_report",
    "skill_ban", "skill_reverse", "skill_flip", "skill_riot", "shot_nuke",
    "skill_pause", "skill_pin", "skill_fold", "skill_ally",
}
local SKILL_NAME = {
    skill_delete = "删评",
    skill_freeze = "控评",
    skill_wash = "洗地",
    blocklist = "拉黑",
    skill_report = "举报",
    skill_ban = "封号",
    skill_reverse = "反向网暴",
    skill_flip = "舆论反转",
    skill_riot = "全网声讨",
    shot_nuke = "舆论核弹",
    skill_pause = "时间暂停",
    skill_pin = "置顶神评",
    skill_fold = "差评折叠",
    skill_ally = "热评置顶",
}
local SKILL_TIP = {
    skill_delete = "清屏，本波热度减半",
    skill_freeze = "冻结全屏弹幕 5s",
    skill_wash = "30s 无敌",
    blocklist = "3s 无敌",
    skill_report = "对账号/Boss 按最大生命造成伤害",
    skill_ban = "直接删掉一个账号",
    skill_reverse = "把屏幕上的字母全部喷回去",
    skill_flip = "20s 内弹幕触底反而伤账号",
    skill_riot = "全屏 5 发回怼",
    shot_nuke = "全屏 20 发回怼",
    skill_pause = "暂停 3s",
    skill_pin = "10s 内每字母热度 ×2",
    skill_fold = "折叠最近一条弹幕",
    skill_ally = "最近一条弹幕变成友军",
}

local B = {
    phase = "idle",
    phaseT = 0,
    wave = 1,
    waveData = nil,
    time = 0,
    hp = 100,
    hpMax = 100,
    heat = 0,
    enemies = {},
    slots = {},
    run = nil,
    eff = nil,
    confirmRetreat = false,
    tutorial = 0,
    hoverSkill = 0,
    mouse = { x = 0, y = 0 },
    keyGlow = 0,
    lastKey = "",
}

-- ---------------------------------------------------------------- 输入队列

local keyQueue = {}
local keyQueueN = 0

-- ---------------------------------------------------------------- 账号池

for i = 1, MAX_ENEMIES do
    B.enemies[i] = {
        active = false,
        def = nil,
        slot = 0,
        x = 0,
        y = 0,
        homeX = 0,
        homeY = 0,
        hp = 1,
        maxhp = 1,
        alive = false,
        fireT = 0,
        interval = 1,
        spawnT = 0,
        movePhase = 0,
        hitFlash = 0,
        shieldT = 0,
        bossT = 0,
        bossMode = 0,
        appendT = 0,
        markerB = nil,
        fade = 1,
        scale = 1,
        stack = 0,
        isBoss = false,
    }
end

local function makeSlots()
    B.slots = {}
    for i = 1, SLOT_COUNT do
        local a = math.pi + (i - 0.5) / SLOT_COUNT * math.pi
        local x = RING.cx + RING.rx * math.cos(a)
        local y = RING.cy + RING.ry * math.sin(a)
        -- 环位：1~5 左，6~11 上，12~16 右
        local tags = {}
        if i <= 5 then
            tags.left = true
        end
        if i >= 6 and i <= 11 then
            tags.top = true
        end
        if i >= 12 then
            tags.right = true
        end
        if i >= 7 and i <= 10 then
            tags.center = true
        end
        tags.any = true
        B.slots[i] = { x = x, y = y, tags = tags }
    end
end

-- ---------------------------------------------------------------- 平衡计算

local function computeCombat()
    local eff = B.eff
    local p = P
    local save = api.activeSave
    local influence = save.influence or 0

    B.hpMax = (p.hp_base + eff.hp_max) * eff.hp_mult
    B.hp = B.hpMax
    B.autoCps = (eff.auto_cps + eff.auto_flat) * eff.auto_mult
        * (1 + 0.1 * influence)
        * (1 + eff.auto_influence)
    B.autoTargets = math.max(1, 1 + math.floor(eff.auto_targets))
    B.dmgPerLetter = (p.char_damage + eff.char_dmg) * eff.dmg_mul
    B.shotFlat = eff.shot_dmg
    B.critChance = math.min(0.95, p.crit_base + eff.crit_add)
    B.critHeat = p.crit_heat
    B.critDmg = p.crit_damage + eff.crit_mult
    B.heatMul = eff.heat_mul * (1 + 0.1 * influence)
    B.bulletRate = eff.bullet_rate
    B.extraShots = math.floor(eff.extra_shot)
    B.extraLow = math.floor(eff.extra_low)
    B.spread = math.floor(eff.spread)
    B.pierce = math.floor(eff.pierce)
    B.threat = {
        comboWindow = p.combo_window,
        comboBonus = p.combo_bonus_base + eff.combo_bonus,
        comboCap = p.combo_cap_base + eff.combo_cap,
        comboStep = p.combo_step,
        predict = math.min(0.95, eff.predict),
        fuzzy = math.min(0.95, eff.fuzzy_match),
        dualHand = math.floor(eff.dual_hand),
        undoPerWave = math.floor(eff.undo),
    }
    B.skills = {}
    for _, key in ipairs(SKILL_ORDER) do
        local lv = math.floor(eff[key] or 0)
        if lv > 0 then
            B.skills[#B.skills + 1] = {
                key = key,
                name = SKILL_NAME[key] or key,
                left = lv,
                max = lv,
                tip = SKILL_TIP[key] or "",
            }
        end
    end
    B.banLetters = B.banLetters or {}
end

-- ---------------------------------------------------------------- 词库挑选

local cand = {}
local candW = {}
local candN = 0
local recentWords = {}
local recentN = 0

local function wordAllowed(w)
    local cfg = Save.config
    if cfg.filter_profanity and w.blocked then
        return false
    end
    if cfg.humor == "低" then
        if w.edge then
            return false
        end
        if w.tier ~= "T2" and w.tier ~= "T4" then
            return false
        end
    end
    if B.banLetters then
        for i = 1, #B.banLetters do
            if w.pinyin:find(B.banLetters[i], 1, true) then
                return false
            end
        end
    end
    for i = 1, recentN do
        if recentWords[i] == w.id then
            return false
        end
    end
    return true
end

local function rememberWord(id)
    if recentN >= 4 then
        table.remove(recentWords, 1)
        recentN = recentN - 1
    end
    recentN = recentN + 1
    recentWords[recentN] = id
end

local function addCand(w, avg)
    local d = math.abs(w.letters - avg)
    local weight = 1 / (1 + d * 0.28)
    if w.tier == "T1" then
        weight = weight * 1.2
    end
    candN = candN + 1
    cand[candN] = w
    candW[candN] = weight
end

local function buildCands(def, waveNum)
    candN = 0
    local avg = B.waveData.avg_letters
    local tiers = {}
    for _, t in ipairs(def.tiers) do
        tiers[t] = true
    end
    -- 波次词级也参与（46 波后 T7 进入池子，靠长度权重成为主力）
    for t in (B.waveData.tier or ""):gmatch("T%d") do
        tiers[t] = true
    end
    for _, w in ipairs(Words.list) do
        if w.first_wave <= waveNum and tiers[w.tier] and wordAllowed(w) then
            addCand(w, avg)
        end
    end
    if candN == 0 then
        for _, w in ipairs(Words.list) do
            if w.first_wave <= waveNum and wordAllowed(w) then
                addCand(w, avg)
            end
        end
    end
    if candN == 0 then
        -- 极端情况（字母被屏蔽光了）：退到教学词
        candN = 1
        cand[1] = Words.list[1]
        candW[1] = 1
    end
end

local function pickWord(def, waveNum)
    buildCands(def, waveNum)
    local total = 0
    for i = 1, candN do
        total = total + candW[i]
    end
    local roll = love.math.random() * total
    local acc = 0
    for i = 1, candN do
        acc = acc + candW[i]
        if roll <= acc then
            rememberWord(cand[i].id)
            return cand[i]
        end
    end
    rememberWord(cand[candN].id)
    return cand[candN]
end

-- ---------------------------------------------------------------- 波次准备

local function waveDataFor(n)
    local list = Waves.list
    if n < 1 then
        n = 1
    end
    if n > #list then
        n = #list
    end
    return list[n]
end

local function clearEnemies()
    for i = 1, MAX_ENEMIES do
        local e = B.enemies[i]
        e.active = false
        e.alive = false
        e.markerB = nil
    end
end

local slotPick = {}

local function slotAccepts(slot, tags)
    local st = slot.tags
    if tags.any then
        return true
    end
    if tags.left and st.left then
        return true
    end
    if tags.right and st.right then
        return true
    end
    if tags.top and st.top then
        return true
    end
    if tags.center and st.center then
        return true
    end
    return false
end

local function slotLoad(i)
    local count = 0
    for j = 1, MAX_ENEMIES do
        local e = B.enemies[j]
        if e.active and e.slot == i then
            count = count + 1
        end
    end
    return count
end

local function pickFreeSlot(tags)
    local n = 0
    local best, bestCount = nil, 99
    for i = 1, SLOT_COUNT do
        if slotAccepts(B.slots[i], tags) then
            local count = slotLoad(i)
            if count == 0 then
                n = n + 1
                slotPick[n] = i
            elseif count < bestCount then
                best, bestCount = i, count
            end
        end
    end
    if n > 0 then
        return slotPick[love.math.random(n)], 0
    end
    if best then
        -- 区域满了：叠加到该区域负载最低的环位
        return best, bestCount
    end
    -- 没有任何匹配环位，退到任意空位
    n = 0
    for i = 1, SLOT_COUNT do
        if slotLoad(i) == 0 then
            n = n + 1
            slotPick[n] = i
        end
    end
    if n > 0 then
        return slotPick[love.math.random(n)], 0
    end
    return 6, 0
end

local function addEnemy(def, tags, isBoss)
    for i = 1, MAX_ENEMIES do
        local e = B.enemies[i]
        if not e.active then
            e.active = true
            e.alive = true
            e.def = def
            e.hp = 0
            local slot, stack = pickFreeSlot(tags or { any = true })
            e.slot = slot
            e.stack = stack
            local s = B.slots[slot]
            e.homeX = s.x
            e.homeY = s.y - stack * 30
            e.x = e.homeX
            e.y = e.homeY
            e.movePhase = love.math.random() * 6.28
            e.hitFlash = 0
            e.shieldT = 0
            e.bossT = 0
            e.bossMode = 0
            e.appendT = 0
            e.markerB = nil
            e.fade = 0
            e.scale = (1 - stack * 0.12) * (isBoss and 1.6 or 1)
            e.isBoss = isBoss or false
            e.spawnT = 0
            e.fireT = B.waveData.interval * 0.5
            e.interval = B.waveData.interval * (def.interval or 1)
            local hp = Enemies.base_hp * (def.hp or 1) * B.waveData.hp_mul
            if B.eventFx and B.eventFx.boss_hp and e.isBoss then
                hp = hp * B.eventFx.boss_hp
            end
            e.maxhp = math.max(1, hp)
            e.hp = e.maxhp
            return e
        end
    end
    return nil
end

local poolDefs = {}

local function buildDefPool(waveNum)
    poolDefs = {}
    for _, def in ipairs(Enemies.list) do
        if def.type ~= "Boss" and def.type ~= "事件" and def.first_wave <= waveNum then
            poolDefs[#poolDefs + 1] = def
        end
    end
end

local function bossForWave(waveNum)
    if waveNum == 12 then
        return "E10"
    elseif waveNum == 27 then
        return "E16"
    elseif waveNum == 50 then
        return "E24"
    end
    return nil
end

local function defById(id)
    for _, def in ipairs(Enemies.list) do
        if def.id == id then
            return def
        end
    end
    return nil
end

-- 随机事件
local function rollEvent(waveNum)
    B.event = nil
    B.eventFx = nil
    if waveNum < Events.first_wave then
        return
    end
    if love.math.random() > Events.chance then
        return
    end
    local total = 0
    for _, ev in ipairs(Events.list) do
        total = total + ev.weight
    end
    local roll = love.math.random() * total
    local acc = 0
    local chosen = Events.list[1]
    for _, ev in ipairs(Events.list) do
        acc = acc + ev.weight
        if roll <= acc then
            chosen = ev
            break
        end
    end
    B.event = {
        def = chosen,
        t = chosen.duration > 0 and chosen.duration or -1,
        total = chosen.duration,
    }
    B.eventFx = {
        bullet_rate = chosen.effects.bullet_rate or 1,
        heat = chosen.effects.heat or 1,
        speed = chosen.effects.speed or 1,
        sp = chosen.effects.sp or 1,
        crit_add = chosen.effects.crit_add or 0,
        auto = chosen.effects.auto or 1,
        boss_hp = chosen.effects.boss_hp or 1,
        accounts_add = chosen.effects.accounts_add or 0,
        spawn_pause = chosen.effects.spawn_pause or 0,
        spawn_delay = chosen.effects.spawn_delay or 0,
        input_delay = chosen.effects.input_delay or 0,
        dead_letters = chosen.effects.dead_letters or 0,
        auto_zero = chosen.effects.auto_zero and 1 or 0,
        hp = chosen.effects.hp or 1,
    }
    if B.eventFx.dead_letters > 0 then
        B.deadLetters = {}
        local alphabet = "QWERTYUIOPASDFGHJKLZXCVBNM"
        for i = 1, B.eventFx.dead_letters do
            local idx = love.math.random(#alphabet)
            B.deadLetters[i] = alphabet:sub(idx, idx)
            alphabet = alphabet:sub(1, idx - 1) .. alphabet:sub(idx + 1)
        end
        B.deadCount = B.eventFx.dead_letters
    end
    UI.toast("随机事件：" .. chosen.name .. " · " .. chosen.kind, UI.col.gold, 3)
end

local function startWave(n)
    B.wave = n
    B.waveData = waveDataFor(n)
    B.phase = "prep"
    B.phaseT = 0
    B.waveHeat = 0
    B.waveSp = 0
    B.event = nil
    B.eventFx = nil
    B.deadLetters = {}
    B.deadCount = 0
    B.shrinkT = 0
    B.friendT = 0
    B.flipT = 0
    B.invulnT = 0
    B.pinT = 0
    B.freezeT = 0
    B.pauseT = 0
    B.heatHalf = false
    B.surgeT = 0
    B.lastHitWord = nil
    B.graceT = 0
    B.autoAcc = 0
    B.autoCycle = 1
    B.autoMarks = 0
    B.farmT = 0
    B.keywordT = 0
    B.aiT = 0
    B.blockT = 0
    B.reportT = 0
    B.friendHitT = 0
    B.pendingEventEnemy = nil
    B.spawnDelayT = 0
    keyQueueN = 0
    Bullet.clearAll()
    Bullet.clearRetorts()
    Bullet.frozen = false
    clearEnemies()
    Typing.refreshWave()

    rollEvent(n)
    local waveNum = n
    local count = B.waveData.accounts + ((B.eventFx and B.eventFx.accounts_add) or 0)
    local bossId = bossForWave(waveNum)
    local bossDef = bossId and defById(bossId)
    if bossDef then
        addEnemy(bossDef, { center = true }, true)
        count = count - 1
    end
    buildDefPool(waveNum)
    for i = 1, count do
        if #poolDefs > 0 then
            local def = poolDefs[love.math.random(#poolDefs)]
            local tags = {}
            for _, t in ipairs(def.slots) do
                tags[t] = true
            end
            addEnemy(def, tags, false)
        end
    end
    -- 事件型账号：到了首现波次就触发一次
    for _, def in ipairs(Enemies.list) do
        if def.type == "事件" and def.first_wave == waveNum then
            B.pendingEventEnemy = def
        end
    end
    -- 音频分层：1~9 波 L1，10~29 L2，30+ L3
    if waveNum <= 9 then
        Audio.setBattleLayer(1)
    elseif waveNum <= 29 then
        Audio.setBattleLayer(2)
    else
        Audio.setBattleLayer(3)
    end
end

-- ---------------------------------------------------------------- 数值辅助

local function currentHeatPerLetter()
    return (B.waveData.heat_per_letter + (B.eff.per_letter_value or 0))
end

local function addHeat(amount, manual)
    if amount <= 0 then
        return
    end
    local mult = B.heatMul
    if B.heatHalf then
        mult = mult * 0.5
    end
    if manual then
        mult = mult * Typing.comboMul()
    end
    if B.pinT > 0 then
        mult = mult * 2
    end
    if B.eventFx and B.eventFx.heat then
        mult = mult * B.eventFx.heat
    end
    local gain = amount * mult
    B.heat = B.heat + gain
    B.waveHeat = B.waveHeat + gain
    B.run.heat = B.run.heat + gain
end

local function enemyAt(index)
    return B.enemies[index]
end

local function aliveEnemyCount()
    local n = 0
    for i = 1, MAX_ENEMIES do
        if B.enemies[i].active and B.enemies[i].alive then
            n = n + 1
        end
    end
    return n
end

local function nearestAliveEnemy(x, y)
    local best, bestD = nil, nil
    for i = 1, MAX_ENEMIES do
        local e = B.enemies[i]
        if e.active and e.alive then
            local dx, dy = e.x - x, e.y - y
            local d = dx * dx + dy * dy
            if not bestD or d < bestD then
                best, bestD = e, d
            end
        end
    end
    return best
end

local function lowestHpEnemy()
    local best, bestHp = nil, nil
    for i = 1, MAX_ENEMIES do
        local e = B.enemies[i]
        if e.active and e.alive then
            if not bestHp or e.hp < bestHp then
                best, bestHp = e, e.hp
            end
        end
    end
    return best
end

local function killEnemy(e)
    if not e.active or not e.alive then
        return
    end
    e.alive = false
    e.active = false
    B.run.kills = B.run.kills + 1
    api.activeSave.stats.kills = (api.activeSave.stats.kills or 0) + 1
    local sp = (e.def.sp or 1)
    B.run.sp = B.run.sp + sp
    B.run.spKill = (B.run.spKill or 0) + sp
    UI.toast("击退 " .. e.def.name .. "  +" .. sp .. " SP", UI.col.green, 1.6)
    if e.def.behavior == "friend" then
        B.friendT = 5
        UI.toast("反串黑变成友军，替你打 5s", UI.col.cyan, 2.5)
    end
    Audio.playSfx("clear")
end

local function damageEnemy(e, dmg)
    if not e or not e.active or not e.alive then
        return
    end
    if e.shieldT > 0 then
        dmg = dmg * 0.3
    end
    e.hp = e.hp - dmg
    e.hitFlash = 0.12
    if e.hp <= 0 then
        killEnemy(e)
    end
end

local function retortTargetFor(e, preferLow)
    if preferLow then
        local low = lowestHpEnemy()
        if low then
            return low
        end
    end
    return e
end

local function fireRetort(target, dmg, crit, text, opts)
    if not target then
        return
    end
    local r = Bullet.spawnRetort({
        x = PLAYER.x,
        y = PLAYER.y - 40,
        tx = target.x,
        ty = target.y,
        dur = 0.2,
        dmg = dmg,
        target = target,
        text = text or "反弹！",
        crit = crit,
        kind = (opts and opts.kind) or "normal",
    })
    if r then
        r.spread = (opts and opts.spread) or 0
        r.pierce = (opts and opts.pierce) or 0
        r.lockLow = (opts and opts.lockLow) or false
    end
end

-- ---------------------------------------------------------------- 完成一句

local function spawnBulletFrom(e)
    local def = e.def
    local wd = B.waveData
    local word = pickWord(def, B.wave)
    local letters = word.pinyin

    if def.behavior == "extra_letter" then
        local extra = ("QWERTYUIOPASDFGHJKLZXCVBNM"):sub(love.math.random(26), love.math.random(26))
        extra = extra:sub(1, 1)
        letters = letters .. extra
    elseif def.behavior == "repost" and B.lastClearedLetters and #B.lastClearedLetters > 1 then
        letters = B.lastClearedLetters
        local pos = love.math.random(#letters)
        local rep = ("QWERTYUIOPASDFGHJKLZXCVBNM"):sub(love.math.random(26), love.math.random(26))
        letters = letters:sub(1, pos - 1) .. rep .. letters:sub(pos + 1)
    elseif def.behavior == "mirror" and B.lastClearedLetters then
        letters = B.lastClearedLetters
        local chars = {}
        for i = 1, #letters do
            chars[i] = letters:sub(i, i)
        end
        for i = #chars, 2, -1 do
            local j = love.math.random(i)
            chars[i], chars[j] = chars[j], chars[i]
        end
        letters = table.concat(chars)
    elseif def.behavior == "copy_last" and B.lastClearedLetters then
        letters = B.lastClearedLetters
    end

    local speed = (B.eventFx and B.eventFx.speed) or 1
    if def.behavior == "fast" then
        speed = speed * 1.6
    end
    if B.surgeT > 0 then
        speed = speed * 1.5
    end
    local dur = (wd.flight / speed) * (1 + 0.1 * (B.eff.bullet_slow or 0))
    if B.eff.skill_flip and B.eff.skill_flip > 0 then
        -- 不影响飞行，只影响触底处理
    end
    local b = Bullet.spawn({
        letters = letters,
        word = word,
        x = e.x,
        y = e.y + 26,
        tx = PLAYER.x + love.math.random(-40, 40),
        ty = PLAYER.y - 40,
        dur = dur,
        layers = math.max(1, math.floor(wd.layers)),
        armor = (def.behavior == "armor" or def.behavior == "double_clear") and 1 or 0,
        src = e,
        boss = e.isBoss,
        tag = def.behavior == "tag",
        immune = def.behavior == "immune",
        split = def.behavior == "split",
        shuffle = def.behavior == "shuffle",
        dmg = word.dmg,
    })
    if b then
        if def.behavior == "infinite" and not e.markerB then
            b.marker = true
            e.markerB = b
        end
        -- 语法预测：长句自动跳过若干字母
        if B.eff.grammar_skip > 0 and b.len >= 12 then
            local skip = math.min(b.len - 1, math.floor(B.eff.grammar_skip))
            b.typed = skip
        end
    end
    return b
end

local function fireEnemy(e)
    if not e.active or not e.alive then
        return
    end
    local behavior = e.def.behavior
    local wd = B.waveData
    if Bullet.count >= wd.screen_cap then
        return
    end
    local fired = spawnBulletFrom(e)
    if behavior == "triple" then
        spawnBulletFrom(e)
        spawnBulletFrom(e)
    elseif behavior == "double" then
        spawnBulletFrom(e)
    end
    if fired then
        e.firePulse = 0.2
    end
end

local function fullyComplete(b)
    local letters = b.len
    local crit = love.math.random() < B.critChance
    if B.eventFx and B.eventFx.crit_add > 0 then
        crit = crit or love.math.random() < B.eventFx.crit_add
    end
    local dmg = letters * B.dmgPerLetter
    if crit then
        dmg = dmg * B.critDmg
    end
    dmg = dmg + B.shotFlat

    local e = b.src
    if type(e) ~= "table" then
        e = nil
    end
    local target = retortTargetFor(e, B.eff.lock_lowhp and B.eff.lock_lowhp > 0)
    local text = (b.word and b.word.retort) or "反弹！"
    local opts = {
        spread = B.spread,
        pierce = B.pierce,
        lockLow = B.eff.lock_lowhp and B.eff.lock_lowhp > 0,
    }
    if target and target.active then
        fireRetort(target, dmg, crit, text, opts)
    end
    for i = 1, B.extraShots do
        local t2 = nearestAliveEnemy(PLAYER.x, PLAYER.y)
        fireRetort(t2, dmg, crit, "反弹！", opts)
    end
    for i = 1, B.extraLow do
        local t2 = nearestAliveEnemy(PLAYER.x, PLAYER.y)
        fireRetort(t2, dmg * 0.7, false, "反弹！", opts)
    end

    -- 热度：整句完成额外加成 + 暴击
    local perLetter = currentHeatPerLetter()
    local bonus = letters * perLetter * P.sentence_bonus
    if crit then
        bonus = bonus * B.critHeat
    end
    addHeat(bonus, false)
    if crit then
        Audio.playSfx("crit")
    end

    -- 弹幕回收
    if B.eff.recycle > 0 then
        addHeat(letters * 0.5 * B.eff.recycle, false)
    end

    B.lastClearedLetters = b.letters
    B.run.words = B.run.words + 1
    api.activeSave.stats.words_done = (api.activeSave.stats.words_done or 0) + 1
    api.activeSave.stats.sentences = (api.activeSave.stats.sentences or 0) + 1
    api.activeSave.stats.max_combo = math.max(api.activeSave.stats.max_combo or 0, Typing.maxCombo)
    if b.marker then
        local src = b.src
        if src and src.active then
            killEnemy(src)
        end
    end
    Bullet.remove(b)
end

-- 敲掉一个字母之后的统一处理（手动与自动共用）
local function applyLetter(b, kind, manual)
    if kind == "done" then
        addHeat(1 * currentHeatPerLetter(), manual)
        fullyComplete(b)
    else
        addHeat(1 * currentHeatPerLetter(), manual)
        if kind == "pass" then
            Audio.playSfx("complete")
        end
        if b.split and not b.splitDone and b.typed >= math.floor(b.len / 2) then
            b.splitDone = true
            local src = b.src
            if src and src.active then
                spawnBulletFrom(src)
            end
        end
    end
end

-- ---------------------------------------------------------------- 自动系统

local function nearestIncompleteBullet(skipMarked)
    local best, bestD = nil, nil
    for i = 1, Bullet.MAX do
        local b = Bullet.list[i]
        if b.active and not b.arrived and b.typed < b.len then
            if not skipMarked or b.autoMark ~= B.autoCycle then
                local dx, dy = b.x - PLAYER.x, b.y - PLAYER.y
                local d = dx * dx + dy * dy
                if not bestD or d < bestD then
                    best, bestD = b, d
                end
            end
        end
    end
    return best
end

local function autoTypeLetter(b)
    b.autoMark = B.autoCycle
    B.autoMarks = B.autoMarks + 1
    if B.autoMarks >= B.autoTargets then
        B.autoCycle = B.autoCycle + 1
        B.autoMarks = 0
    end
    local kind = Bullet.typeLetter(b)
    applyLetter(b, kind, false)
end

local function autoTick(dt)
    local cps = B.autoCps
    if B.eventFx and B.eventFx.auto_zero == 1 then
        cps = 0
    elseif B.eventFx and B.eventFx.auto then
        cps = cps * B.eventFx.auto
    end
    if B.surgeT > 0 then
        cps = cps * 2
    end
    if cps <= 0 then
        return
    end
    B.autoAcc = B.autoAcc + cps * dt
    local guard = 0
    while B.autoAcc >= 1 and guard < 64 do
        guard = guard + 1
        B.autoAcc = B.autoAcc - 1
        local b = nearestIncompleteBullet(true)
        if not b then
            B.autoCycle = B.autoCycle + 1
            B.autoMarks = 0
            b = nearestIncompleteBullet(false)
        end
        if not b then
            break
        end
        autoTypeLetter(b)
    end
end

local function completeWholeBullet(b, dmgMul)
    if not b.active then
        return
    end
    -- 自动整条击破：不走逐字热度，直接给回怼
    local dmg = b.len * B.dmgPerLetter * (dmgMul or 1)
    local target = b.src
    if target and target.active then
        fireRetort(target, dmg, false, "反弹！", nil)
    end
    addHeat(b.len * currentHeatPerLetter() * 0.5, false)
    B.lastClearedLetters = b.letters
    B.run.words = B.run.words + 1
    Bullet.remove(b)
end

local function findLongestBullet()
    local best, bestLen = nil, 0
    for i = 1, Bullet.MAX do
        local b = Bullet.list[i]
        if b.active and not b.arrived and b.typed < b.len and b.len > bestLen then
            best, bestLen = b, b.len
        end
    end
    return best
end

-- ---------------------------------------------------------------- 输入

local function queueKey(ch)
    local delay = (B.eventFx and B.eventFx.input_delay) or 0
    if delay > 0 then
        keyQueueN = keyQueueN + 1
        keyQueue[keyQueueN] = { ch = ch, t = delay }
    else
        B.handleKey(ch)
    end
end

local function handleMiss()
    if B.graceT > 0 then
        return
    end
    if B.eff.voice_input > 0 then
        B.graceT = 5 * math.floor(B.eff.voice_input)
    end
    local penalty = Typing.miss()
    if penalty then
        B.hp = B.hp - P.miss_hp
    end
    api.activeSave.stats.miss_count = (api.activeSave.stats.miss_count or 0) + 1
    B.run.misses = B.run.misses + 1
    Audio.playSfx("miss")
    if B.hp <= 0 then
        B.hp = 0
        B.finishRun(false)
    end
end

local function tryManualKey(ch)
    -- 事件：键盘进水，死键
    if B.deadCount and B.deadCount > 0 then
        for i = 1, B.deadCount do
            if B.deadLetters[i] == ch then
                Audio.playSfx("miss")
                UI.toast("这个键进水了：" .. ch, UI.col.red, 1)
                return
            end
        end
    end
    local r = Typing.press(ch, PLAYER.x, PLAYER.y)
    if r.kind == "miss" then
        if r.bullet then
            Bullet.miss(r.bullet, 1.2 - 0.02 * math.floor(B.eff.miss_penalty or 0))
        end
        handleMiss()
        return
    end
    if r.kind == "empty" then
        Audio.playSfx("empty")
        return
    end
    if r.kind == "hit" or r.kind == "pass" or r.kind == "done" then
        if r.bullet then
            r.bullet.autoMark = B.autoCycle
        end
        applyLetter(r.bullet, r.kind, true)
        if r.extra and r.extraKind then
            applyLetter(r.extra, r.extraKind, true)
        end
        if r.kind == "hit" or r.kind == "done" then
            Audio.playSfx("type")
        end
        B.run.chars = B.run.chars + (r.letters or 1) + (r.extraLetters or 0)
        api.activeSave.stats.chars_typed = (api.activeSave.stats.chars_typed or 0) + (r.letters or 1)
        B.keyGlow = 0.12
        B.lastKey = ch
        if B.tutorialStep == 0 then
            B.tutorialStep = 1
        end
    end
end

B.handleKey = tryManualKey

-- ---------------------------------------------------------------- 触底与伤害

local function playerHit(dmg, word)
    if B.invulnT > 0 then
        dmg = 0
    end
    if B.eff.same_immune > 0 and B.lastHitWord and word and B.lastHitWord == word.id then
        dmg = dmg * math.max(0, 1 - 0.2 * math.floor(B.eff.same_immune))
    end
    if B.shrinkT > 0 then
        dmg = dmg * 1.2
    end
    if B.eventFx and B.eventFx.hp and B.eventFx.hp ~= 1 then
        dmg = dmg * B.eventFx.hp
    end
    B.lastHitWord = word and word.id or nil
    B.hp = B.hp - dmg
    B.run.hpLost = (B.run.hpLost or 0) + dmg
    B.hitFlash = 0.25
    Audio.playSfx("hurt")
    if B.hp <= 0 then
        B.hp = 0
        B.finishRun(false)
    end
end

-- ---------------------------------------------------------------- 技能

local function activateSkill(skill)
    if not skill or skill.left <= 0 then
        return
    end
    local eff = B.eff
    local key = skill.key
    skill.left = skill.left - 1
    Audio.playSfx("buy")

    if key == "skill_delete" then
        B.heatHalf = true
        for i = 1, Bullet.MAX do
            local b = Bullet.list[i]
            if b.active and not b.immune then
                Bullet.remove(b)
            end
        end
        UI.toast("删评：清屏，本波热度减半", UI.col.cyan)
    elseif key == "skill_freeze" then
        Bullet.frozen = true
        B.freezeT = 5
        UI.toast("控评：全屏冻结 5s", UI.col.cyan)
    elseif key == "skill_wash" then
        B.invulnT = math.max(B.invulnT, 30)
        UI.toast("全网洗地：30s 无敌", UI.col.green)
    elseif key == "blocklist" then
        B.invulnT = math.max(B.invulnT, 3)
        UI.toast("拉黑：3s 无敌", UI.col.green)
    elseif key == "skill_report" then
        local pct = 0.05 * skill.max
        for i = 1, MAX_ENEMIES do
            local e = B.enemies[i]
            if e.active and e.alive then
                damageEnemy(e, e.maxhp * pct)
            end
        end
        UI.toast("举报：按最大生命削 5%", UI.col.yellow)
    elseif key == "skill_ban" then
        local victim = nil
        for i = 1, MAX_ENEMIES do
            local e = B.enemies[i]
            if e.active and e.alive and not e.isBoss then
                victim = e
                break
            end
        end
        if victim then
            killEnemy(victim)
            UI.toast("封号：" .. victim.def.name .. " 已退场", UI.col.red)
        else
            for i = 1, MAX_ENEMIES do
                local e = B.enemies[i]
                if e.active and e.alive and e.isBoss then
                    damageEnemy(e, e.maxhp * 0.15)
                    UI.toast("封号：Boss 掉 15% 血", UI.col.red)
                end
            end
        end
    elseif key == "skill_reverse" then
        for i = 1, Bullet.MAX do
            local b = Bullet.list[i]
            if b.active and b.src and b.src.active then
                local remain = b.len - b.typed
                if remain > 0 then
                    fireRetort(b.src, remain * B.dmgPerLetter, false, "反弹！")
                end
                Bullet.remove(b)
            end
        end
        UI.toast("反向网暴：字母全部喷回去", UI.col.magenta)
    elseif key == "skill_flip" then
        B.flipT = 20 * skill.max
        UI.toast("舆论反转：弹幕触底反而伤账号 " .. B.flipT .. "s", UI.col.purple)
    elseif key == "skill_riot" then
        local target
        for _ = 1, 5 do
            target = nearestAliveEnemy(PLAYER.x, PLAYER.y)
            fireRetort(target, 8 * B.dmgPerLetter, false, "全网声讨")
        end
        UI.toast("全网声讨：全屏 5 发回怼", UI.col.magenta)
    elseif key == "shot_nuke" then
        local target
        for _ = 1, 20 do
            target = nearestAliveEnemy(PLAYER.x, PLAYER.y)
            fireRetort(target, 12 * B.dmgPerLetter, true, "舆论核弹")
        end
        UI.toast("舆论核弹：全屏 20 发回怼", UI.col.red)
    elseif key == "skill_pause" then
        B.pauseT = 3
        UI.toast("时间暂停：3s", UI.col.blue)
    elseif key == "skill_pin" then
        B.pinT = 10 + 2 * skill.max
        UI.toast("置顶神评：热度 ×2 " .. B.pinT .. "s", UI.col.gold)
    elseif key == "skill_fold" then
        local b = nearestIncompleteBullet(false)
        if b then
            b.holdT = 5
            UI.toast("差评折叠 5s", UI.col.blue)
        end
    elseif key == "skill_ally" then
        local b = nearestIncompleteBullet(false)
        if b then
            if b.src and b.src.active then
                damageEnemy(b.src, b.len * B.dmgPerLetter * 2)
            end
            Bullet.remove(b)
            UI.toast("热评置顶：这条帮你打了", UI.col.green)
        end
    end
end

-- ---------------------------------------------------------------- Boss

local function bossTick(e, dt)
    e.bossT = e.bossT + dt
    local interval = (e.def.id == "E24") and 6 or 8
    if e.bossT < interval then
        return
    end
    e.bossT = 0
    e.bossMode = (e.bossMode + 1) % 3
    local wd = B.waveData

    if e.def.id == "E10" then
        if e.bossMode == 0 then
            UI.toast("大V：召唤水军", UI.col.red, 1.6)
            for i = 1, 3 do
                local b = Bullet.spawn({
                    letters = "NMSL",
                    word = Words.list[72],
                    x = e.x,
                    y = e.y + 30,
                    tx = PLAYER.x + love.math.random(-120, 120),
                    ty = PLAYER.y - 40,
                    dur = wd.flight * 0.8,
                    layers = 1,
                    src = e,
                    boss = false,
                    dmg = 5,
                })
            end
        elseif e.bossMode == 1 then
            e.shieldT = 5
            UI.toast("大V：弹幕护盾 5s", UI.col.blue, 1.6)
        else
            UI.toast("大V：全屏长句", UI.col.red, 1.6)
            for i = 1, 2 do
                local b = Bullet.spawn({
                    letters = "JIANGDEZHENHAOXIACIBIEJIANGLE",
                    word = Words.list[47],
                    x = e.x,
                    y = e.y + 30,
                    tx = PLAYER.x,
                    ty = PLAYER.y - 40,
                    dur = wd.flight * 1.1,
                    layers = 1,
                    src = e,
                    boss = true,
                    dmg = 12,
                })
            end
        end
    elseif e.def.id == "E16" then
        if e.bossMode == 0 then
            UI.toast("超级大V：弹幕海", UI.col.red, 1.6)
            for i = 1, 6 do
                spawnBulletFrom(e)
            end
        elseif e.bossMode == 1 then
            B.surgeT = 5
            UI.toast("超级大V：字母狂暴 5s", UI.col.red, 1.6)
        else
            UI.toast("超级大V：召唤营销矩阵", UI.col.red, 1.6)
            local def = defById("E08")
            if def then
                addEnemy(def, { top = true }, false)
            end
            spawnBulletFrom(e)
        end
    elseif e.def.id == "E24" then
        local frac = e.hp / e.maxhp
        if frac > 0.66 then
            UI.toast("流量黑洞：吸走半屏弹幕", UI.col.purple, 1.6)
            local removed = 0
            for i = 1, Bullet.MAX do
                local b = Bullet.list[i]
                if b.active and not b.immune and removed < 20 then
                    Bullet.remove(b)
                    removed = removed + 1
                end
            end
            e.hp = math.min(e.maxhp, e.hp + e.maxhp * 0.05)
        elseif frac > 0.33 then
            UI.toast("流量黑洞：复制全场", UI.col.purple, 1.6)
            local copied = 0
            for i = 1, Bullet.MAX do
                local b = Bullet.list[i]
                if b.active and copied < 4 and not b.marker then
                    Bullet.spawn({
                        letters = b.letters,
                        word = b.word,
                        x = b.x,
                        y = b.y,
                        tx = b.tx,
                        ty = b.ty,
                        dur = b.dur,
                        layers = 1,
                        src = b.src,
                        boss = true,
                        dmg = b.dmg,
                    })
                    copied = copied + 1
                end
            end
        else
            B.surgeT = 6
            UI.toast("流量黑洞：字母狂暴", UI.col.purple, 1.6)
        end
    end
end

-- ---------------------------------------------------------------- 更新

local function updateBullets(dt)
    -- 冻结/暂停的开关统一在 updateEvents 里维护
    Bullet.update(dt)

    for i = 1, Bullet.MAX do
        local b = Bullet.list[i]
        if b.active and b.arrived then
            if B.flipT > 0 and b.src and b.src.active then
                fireRetort(b.src, b.len * B.dmgPerLetter, false, "反转！")
                Bullet.remove(b)
            else
                playerHit(b.dmg, b.word)
                Bullet.remove(b)
            end
        end
    end
    Bullet.updateRetorts(dt)
    for i = 1, Bullet.RETORT_MAX do
        local r = Bullet.retorts[i]
        if r and r.active and r.arrived then
            local e = r.target
            if type(e) == "table" and e.active and e.alive then
                damageEnemy(e, r.dmg)
                if r.spread and r.spread > 0 then
                    local n = 0
                    for j = 1, MAX_ENEMIES do
                        local other = B.enemies[j]
                        if other.active and other.alive and other ~= e and n < r.spread then
                            damageEnemy(other, r.dmg * 0.5)
                            n = n + 1
                        end
                    end
                end
                if r.pierce and r.pierce > 0 then
                    local n = 0
                    for j = 1, MAX_ENEMIES do
                        local other = B.enemies[j]
                        if other.active and other.alive and other ~= e and n < r.pierce then
                            damageEnemy(other, r.dmg * 0.6)
                            n = n + 1
                        end
                    end
                end
            end
            Bullet.removeRetort(r)
        end
    end
end

local function updateEnemies(dt)
    for i = 1, MAX_ENEMIES do
        local e = B.enemies[i]
        if e.active then
            if e.fade < 1 then
                e.fade = math.min(1, e.fade + dt / 0.3)
            end
            if e.hitFlash > 0 then
                e.hitFlash = math.max(0, e.hitFlash - dt)
            end
            if e.shieldT > 0 then
                e.shieldT = math.max(0, e.shieldT - dt)
            end
            if e.firePulse and e.firePulse > 0 then
                e.firePulse = math.max(0, e.firePulse - dt)
            end
            -- 移动方式
            local t = B.time + e.movePhase
            if e.def.move == "drift" then
                e.x = e.homeX + math.sin(t * 0.6) * 26
            elseif e.def.move == "orbit" then
                e.x = e.homeX + math.cos(t * 0.8) * 18
                e.y = e.homeY + math.sin(t * 0.8) * 10
            elseif e.def.move == "wander" then
                e.x = e.homeX + math.sin(t * 0.5) * 30
                e.y = e.homeY + math.cos(t * 0.7) * 14
            elseif e.def.move == "swarm" then
                e.x = e.homeX + math.sin(t * 2.0) * 22
                e.y = e.homeY + math.cos(t * 1.7) * 12
            elseif e.def.move == "orbit_fast" then
                e.x = e.homeX + math.cos(t * 1.6) * 30
                e.y = e.homeY + math.sin(t * 1.6) * 16
            elseif e.def.move == "spin" then
                e.x = e.homeX + math.cos(t * 2.4) * 40
                e.y = e.homeY + math.sin(t * 2.4) * 20
            elseif e.def.move == "alternate" then
                e.x = e.homeX + math.sin(t * 0.9) * 60
            elseif e.def.move == "mirror" then
                e.x = e.homeX + math.sin(t * 0.4) * 12
            end

            -- 入场期间不喷弹幕
            if e.fade >= 1 and B.phase == "fight" then
                local paused = (B.eventFx and B.eventFx.spawn_pause and B.eventFx.spawn_pause > 0 and B.event.t ~= nil and B.event.t > 0) or false
                if B.spawnDelayT and B.spawnDelayT > 0 then
                    paused = true
                end
                if not paused then
                    local interval = e.interval / (B.bulletRate * ((B.eventFx and B.eventFx.bullet_rate) or 1))
                    e.fireT = e.fireT + dt
                    if e.fireT >= interval then
                        if Bullet.count < B.waveData.screen_cap then
                            e.fireT = e.fireT - interval
                            fireEnemy(e)
                        else
                            -- 同屏到上限：把这一发留在队列里，腾出位置立刻喷
                            e.fireT = math.min(e.fireT, interval)
                        end
                    end
                    -- 数据女工：每 5s 追加 1 条短句
                    if e.def.behavior == "append_short" then
                        e.appendT = e.appendT + dt
                        if e.appendT >= 5 then
                            e.appendT = 0
                            spawnBulletFrom(e)
                        end
                    end
                end
                if e.isBoss then
                    bossTick(e, dt)
                end
            end
        end
    end
end

local function updateEvents(dt)
    if B.event and B.event.t and B.event.t > 0 then
        B.event.t = B.event.t - dt
        if B.event.t <= 0 then
            B.event = nil
            B.eventFx = nil
            B.deadLetters = {}
            B.deadCount = 0
        end
    end
    if B.spawnDelayT and B.spawnDelayT > 0 then
        B.spawnDelayT = B.spawnDelayT - dt
    end
    if B.freezeT > 0 then
        B.freezeT = B.freezeT - dt
        if B.freezeT <= 0 then
            Bullet.frozen = false
        end
    end
    if B.pauseT > 0 then
        B.pauseT = B.pauseT - dt
    end
    if B.surgeT > 0 then
        B.surgeT = B.surgeT - dt
    end
    if B.invulnT > 0 then
        B.invulnT = B.invulnT - dt
    end
    if B.pinT > 0 then
        B.pinT = B.pinT - dt
    end
    if B.flipT > 0 then
        B.flipT = B.flipT - dt
    end
    if B.shrinkT > 0 then
        B.shrinkT = B.shrinkT - dt
    end
    if B.friendT > 0 then
        B.friendT = B.friendT - dt
        B.friendHitT = (B.friendHitT or 0) + dt
        if B.friendHitT >= 0.4 then
            B.friendHitT = 0
            local b = nearestIncompleteBullet(false)
            if b then
                Bullet.remove(b)
                addHeat(2, false)
            end
        end
    end
    if B.graceT > 0 then
        B.graceT = B.graceT - dt
    end
    Bullet.frozen = (B.freezeT > 0) or (B.pauseT > 0)
end

local function updateAutoSystems(dt)
    autoTick(dt)
    local eff = B.eff
    if eff.farm > 0 then
        B.farmT = B.farmT + dt
        while B.farmT >= 1 do
            B.farmT = B.farmT - 1
            for i = 1, math.floor(eff.farm) do
                local b = nearestIncompleteBullet(false)
                if b then
                    completeWholeBullet(b, 1)
                end
            end
        end
    end
    if eff.keywords > 0 then
        B.keywordT = B.keywordT + dt
        if B.keywordT >= 20 then
            B.keywordT = 0
            for i = 1, math.floor(eff.keywords) do
                local b = nearestIncompleteBullet(false)
                if b then
                    completeWholeBullet(b, 1)
                end
            end
        end
    end
    if eff.ai_auto > 0 then
        B.aiT = B.aiT + dt
        if B.aiT >= 10 then
            B.aiT = 0
            for i = 1, math.floor(eff.ai_auto) do
                local b = findLongestBullet()
                if b then
                    completeWholeBullet(b, 1)
                end
            end
        end
    end
    if eff.block_rate > 0 then
        B.blockT = B.blockT + dt
        while B.blockT >= 1 do
            B.blockT = B.blockT - 1
            for i = 1, math.floor(eff.block_rate) do
                local b = nearestIncompleteBullet(false)
                if b and not b.immune then
                    Bullet.remove(b)
                end
            end
        end
    end
    if eff.auto_report > 0 then
        B.reportT = B.reportT + dt
        if B.reportT >= 10 then
            B.reportT = 0
            for i = 1, MAX_ENEMIES do
                local e = B.enemies[i]
                if e.active and e.alive and e.isBoss then
                    damageEnemy(e, e.maxhp * 0.05 * math.floor(eff.auto_report))
                end
            end
        end
    end
end

local function waveCleared()
    for i = 1, MAX_ENEMIES do
        local e = B.enemies[i]
        if e.active and e.alive then
            return false
        end
    end
    return true
end

local function finishWave()
    -- 剩余弹幕按半价热度碎掉
    local perLetter = currentHeatPerLetter()
    for i = 1, Bullet.MAX do
        local b = Bullet.list[i]
        if b.active then
            addHeat(b.len * perLetter * 0.5, false)
            Bullet.remove(b)
        end
    end
    Bullet.clearRetorts()
    B.run.waves = B.run.waves + 1
    api.activeSave.stats.waves_cleared = (api.activeSave.stats.waves_cleared or 0) + 1

    local p = P
    local sp = B.waveData.sp + math.floor(B.eff.sp_bonus)
    sp = sp * B.eff.sp_mult
    if B.eventFx and B.eventFx.sp then
        sp = sp * B.eventFx.sp
    end
    if B.wave > (api.activeSave.best_wave or 0) then
        sp = sp + 2
    end
    sp = math.max(1, math.floor(sp + 0.5))
    B.run.sp = B.run.sp + sp
    B.run.spWave = (B.run.spWave or 0) + sp
    B.waveSp = sp

    if B.wave > (api.activeSave.best_wave or 0) then
        api.activeSave.best_wave = B.wave
        api.activeSave.stats.best_wave = B.wave
    end

    -- 精神胜利：每波结束回血
    if B.eff.heal_wave > 0 then
        B.hp = math.min(B.hpMax, B.hp + B.hpMax * B.eff.heal_wave)
    end

    if B.wave >= #Waves.list then
        B.finishRun(true)
        return
    end
    B.phase = "clear"
    B.phaseT = 0
end

function B.finishRun(victory)
    if B.finished then
        return
    end
    B.finished = true
    local save = api.activeSave
    local run = B.run
    run.victory = victory
    run.waveReached = B.wave
    run.hpMax = B.hpMax
    run.maxCombo = Typing.maxCombo
    run.sp = math.floor(run.sp)
    -- 失败保底 +3；主动撤退拿不到保底（流程 §6.2）
    if not victory and not B.retreat then
        run.sp = run.sp + 3
    end
    run.sp = math.floor(run.sp)

    save.sp = (save.sp or 0) + run.sp
    save.total_heat = (save.total_heat or 0) + run.heat
    save.heat = run.heat
    save.best_wave = math.max(save.best_wave or 0, run.waves)
    save.stats.best_wave = save.best_wave
    save.stats.runs = (save.stats.runs or 0) + 1
    save.stats.max_combo = math.max(save.stats.max_combo or 0, Typing.maxCombo)
    save.tutorial_done = true
    save.last_run = {
        waves = run.waves,
        kills = run.kills,
        heat = math.floor(run.heat),
        sp = run.sp,
        victory = victory,
        retreat = B.retreat,
        timestamp = os.time(),
    }
    -- 同波连败统计：天赋屋给一句提示
    if (save.fail_streak_wave or 0) == B.wave then
        save.fail_streak = (save.fail_streak or 0) + 1
    else
        save.fail_streak_wave = B.wave
        save.fail_streak = 1
    end
    api.saveNow()
    Audio.playMusic(victory and "battle3" or "fail")
    B.phase = "over"
    api.switch("result", {
        run = run,
        retreat = B.retreat or false,
        victory = victory,
    })
end

local function updatePhase(dt)
    if B.phase == "prep" then
        if B.phaseT >= 3 then
            B.phase = "enter"
            B.phaseT = 0
            -- 事件型账号在入场时触发
            if B.pendingEventEnemy then
                local def = B.pendingEventEnemy
                B.pendingEventEnemy = nil
                if def.behavior == "rush" then
                    for i = 1, 24 do
                        local w = pickWord({ tiers = { "T2" } }, B.wave)
                        Bullet.spawn({
                            letters = w.pinyin,
                            word = w,
                            x = 100 + love.math.random(1080),
                            y = 120 + love.math.random(220),
                            tx = PLAYER.x + love.math.random(-30, 30),
                            ty = PLAYER.y - 40,
                            dur = B.waveData.flight * 0.9,
                            layers = 1,
                            src = nil,
                            dmg = w.dmg,
                        })
                    end
                    UI.toast("网暴风暴：24 条短弹幕同时涌入", UI.col.red, 3)
                elseif def.behavior == "shrink" then
                    B.shrinkT = B.waveData.duration
                    UI.toast("网暴巨兽：安全区收缩，伤害 +20%", UI.col.red, 3)
                end
            end
            if B.eventFx and B.eventFx.spawn_delay then
                B.spawnDelayT = B.eventFx.spawn_delay
            end
        end
    elseif B.phase == "enter" then
        if B.phaseT >= 0.3 * math.min(10, aliveEnemyCount() + 2) + 0.4 then
            B.phase = "fight"
            B.phaseT = 0
            -- 全局搜索：开局自动完成 2 条/级
            if B.eff.auto_complete > 0 then
                for i = 1, math.floor(B.eff.auto_complete) do
                    local b = nearestIncompleteBullet(false)
                    if b then
                        completeWholeBullet(b, 1)
                    end
                end
            end
            -- 大写锁定：补全 50%
            if B.eff.auto_fill > 0 then
                for i = 1, math.floor(B.eff.auto_fill) do
                    local b = nearestIncompleteBullet(false)
                    if b then
                        local target = math.floor(b.len * 0.5)
                        while b.active and b.typed < target do
                            local kind = Bullet.typeLetter(b)
                            addHeat(1 * currentHeatPerLetter(), false)
                            if kind == "done" then
                                fullyComplete(b)
                                break
                            end
                        end
                    end
                end
            end
        end
    elseif B.phase == "fight" then
        if waveCleared() then
            finishWave()
        end
    elseif B.phase == "clear" then
        if B.phaseT >= 0.9 then
            if B.wave + 1 > #Waves.list then
                B.finishRun(true)
            else
                startWave(B.wave + 1)
            end
        end
    end
end

function Battle.update(dt)
    if B.phase == "idle" or B.phase == "over" then
        return
    end
    B.time = B.time + dt
    B.phaseT = B.phaseT + dt

    if B.confirmRetreat then
        return
    end

    -- 延迟按键（事件：输入法卡顿）
    if keyQueueN > 0 then
        local i = 1
        while i <= keyQueueN do
            local item = keyQueue[i]
            item.t = item.t - dt
            if item.t <= 0 then
                B.handleKey(item.ch)
                table.remove(keyQueue, i)
                keyQueueN = keyQueueN - 1
            else
                i = i + 1
            end
        end
    end

    if B.hitFlash and B.hitFlash > 0 then
        B.hitFlash = math.max(0, B.hitFlash - dt)
    end
    if B.keyGlow > 0 then
        B.keyGlow = math.max(0, B.keyGlow - dt)
    end

    Typing.update(dt)

    -- 账号的淡入与移动在所有阶段都要推进，喷弹幕只在 fight 阶段
    if B.phase == "fight" or B.phase == "enter" or B.phase == "prep" then
        updateEnemies(dt)
    end
    if B.phase == "fight" then
        updateBullets(dt)
        updateAutoSystems(dt)
    end
    updateEvents(dt)
    updatePhase(dt)

    if B.tutorialStep == 1 and B.run.words > 0 then
        B.tutorialStep = 2
    end
    if B.tutorialStep == 2 and B.run.words >= 2 then
        B.tutorialStep = 3
    end
end

-- ---------------------------------------------------------------- 绘制

local TYPE_COLOR = {
    普通 = { 0.55, 0.58, 0.64 },
    群刷 = { 0.35, 0.75, 0.75 },
    精英 = { 0.40, 0.55, 0.90 },
    分裂 = { 0.85, 0.45, 0.75 },
    干扰 = { 0.65, 0.50, 0.90 },
    坦克 = { 0.55, 0.80, 0.55 },
    高速 = { 0.95, 0.65, 0.35 },
    特殊 = { 0.95, 0.80, 0.35 },
    事件 = { 0.90, 0.35, 0.35 },
    Boss = { 0.90, 0.30, 0.35 },
}

local function drawEnemy(e)
    local col = TYPE_COLOR[e.def.type] or TYPE_COLOR["普通"]
    local s = e.scale * (0.7 + 0.3 * e.fade)
    local w = 40 * s
    local h = 40 * s
    local x = e.x - w / 2
    local y = e.y - h / 2
    local alpha = 0.35 + 0.65 * e.fade
    if e.hitFlash > 0 then
        col = UI.col.white
    end
    UI.rect(x + 2, y + 2, w, h, UI.col.void, 0.5 * alpha)
    UI.rect(x, y, w, h, { col[1] * 0.55, col[2] * 0.55, col[3] * 0.55 }, alpha)
    UI.frame(x, y, w, h, col, alpha)
    -- 像素脸
    UI.rect(x + w * 0.22, y + h * 0.28, w * 0.18, h * 0.16, UI.col.void, alpha)
    UI.rect(x + w * 0.6, y + h * 0.28, w * 0.18, h * 0.16, UI.col.void, alpha)
    UI.rect(x + w * 0.25, y + h * 0.62, w * 0.5, h * 0.08, UI.col.void, alpha)
    if e.isBoss then
        UI.text("BOSS", e.x, y - 22, 16, UI.col.red, "center", 0)
    else
        UI.text(e.def.name, e.x, y + h + 2, 16, col, "center", 0)
    end
    -- 血条
    local bw = math.max(44, w)
    local ratio = math.max(0, e.hp / e.maxhp)
    UI.bar(e.x - bw / 2, y + h + 20, bw, 4, ratio, e.isBoss and UI.col.red or UI.col.green, UI.col.void)
    if e.shieldT > 0 then
        UI.frame(x - 3, y - 3, w + 6, h + 6, UI.col.blue)
    end
    if e.firePulse and e.firePulse > 0 then
        UI.setColor(col, e.firePulse * 3)
        love.graphics.rectangle("line", x - 5, y - 5, w + 10, h + 10)
    end
end

local function drawPlayer()
    local px, py = PLAYER.x, PLAYER.y
    -- 键盘
    local kx, ky, kw, kh = px - 110, py + 32, 220, 46
    UI.rect(kx, ky, kw, kh, UI.col.panel2)
    UI.frame(kx, ky, kw, kh, UI.col.line2)
    local rows = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }
    for r = 1, #rows do
        for i = 1, #rows[r] do
            local cw = 17
            local cx = kx + 8 + (i - 1) * (cw + 1) + (r - 1) * 8
            local cy = ky + 5 + (r - 1) * 12
            local ch = rows[r]:sub(i, i)
            local glow = (B.keyGlow > 0 and B.lastKey == ch)
            if glow then
                UI.rect(cx, cy, cw, 10, UI.col.cyan)
            else
                UI.rect(cx, cy, cw, 10, UI.col.bg2)
                UI.frame(cx, cy, cw, 10, UI.col.line, 0.6)
            end
        end
    end
    -- 角色
    local hx, hy = px - 22, py - 62
    UI.rect(hx + 4, hy + 40, 36, 26, UI.col.deepblue)
    UI.rect(hx, hy, 44, 42, UI.col.panel2)
    UI.frame(hx, hy, 44, 42, UI.col.line2)
    UI.rect(hx + 8, hy + 12, 8, 6, UI.col.cyan)
    UI.rect(hx + 28, hy + 12, 8, 6, UI.col.cyan)
    UI.rect(hx + 14, hy + 30, 16, 3, UI.col.cyan, 0.8)
    UI.text("键盘侠", px, hy - 22, 16, UI.col.cyan, "center", 0)
    -- 受击闪红
    if B.hitFlash and B.hitFlash > 0 then
        UI.rect(hx - 4, hy - 30, 52, 100, UI.col.red, B.hitFlash)
    end
end

local function drawHUD()
    local save = api.activeSave
    -- 心态条
    local hpRatio = math.max(0, B.hp / B.hpMax)
    UI.text("心态", 24, 22, 16, UI.col.dim)
    UI.bar(74, 22, 240, 16, hpRatio, hpRatio > 0.35 and UI.col.green or UI.col.red, UI.col.void)
    UI.text(string.format("%d / %d", math.floor(B.hp), math.floor(B.hpMax)), 86, 22, 16, UI.col.text)
    -- 热度
    UI.text("热度 " .. UI.commaNum(B.heat), 24, 48, 16, UI.col.gold)
    -- 连击
    if Typing.combo > 1 then
        local mul = Typing.comboMul()
        UI.text(
            string.format("连击 %d  ×%.2f", Typing.combo, mul),
            24,
            72,
            16,
            Typing.combo >= 30 and UI.col.magenta or (Typing.combo >= 10 and UI.col.yellow or UI.col.cyan)
        )
    end
    -- 顶中：波次
    UI.text(string.format("第 %d 波 / %d · %s", B.wave, #Waves.list, B.waveData.theme), 640, 16, 24, UI.col.text, "center", 0)
    local total = B.waveData.accounts
    local alive = aliveEnemyCount()
    local remaining = math.max(0, alive)
    local dotX = 640 - (total * 12) / 2
    for i = 1, total do
        local on = i <= remaining
        UI.rect(dotX + (i - 1) * 12, 48, 8, 8, on and UI.col.red or UI.col.line)
    end
    -- 右上：自动字符率
    UI.text(string.format("自动 %.1f 字母/秒", B.autoCps), 1256, 20, 16, UI.col.cyan, "right", 0)
    UI.text("同屏 " .. Bullet.count .. " / " .. B.waveData.screen_cap, 1256, 42, 16, UI.col.dim, "right", 0)
    if B.event then
        local txt = B.event.def.name .. " · " .. B.event.def.kind
        if B.event.t and B.event.t > 0 then
            txt = txt .. string.format(" %.1fs", B.event.t)
        end
        UI.text(txt, 640, 76, 16, UI.col.gold, "center", 0)
    end

    -- Boss 血条：放在左上，避开顶部环位的账号
    for i = 1, MAX_ENEMIES do
        local e = B.enemies[i]
        if e.active and e.alive and e.isBoss then
            UI.text(e.def.name .. "（Boss）", 24, 100, 16, UI.col.red)
            UI.bar(24, 120, 260, 10, e.hp / e.maxhp, UI.col.red, UI.col.void)
            break
        end
    end

    -- 技能按钮（右下，2 列）
    for i, skill in ipairs(B.skills) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local w, h = 120, 32
        local x = 1256 - (2 - col) * (w + 8) + 8
        local y = 720 - 60 - row * (h + 6)
        if y < 400 then
            break
        end
        local hover = UI.hit(B.mouse.x, B.mouse.y, x, y, w, h)
        local ok = skill.left > 0
        UI.rect(x, y, w, h, ok and (hover and { 0.22, 0.40, 0.42 } or UI.col.panel) or UI.col.bg2)
        UI.frame(x, y, w, h, ok and (hover and UI.col.cyan or UI.col.line2) or UI.col.line)
        UI.text(skill.name, x, y + 2, 16, ok and UI.col.text or UI.col.dim2, "center", w)
        UI.text("×" .. skill.left, x + w - 6, y + 14, 8, ok and UI.col.cyan or UI.col.dim2, "right", 0)
        if hover and skill.tip then
            UI.text(skill.tip, x + w, y - 4, 16, UI.col.dim, "right", 0)
        end
    end

    -- 底部输入提示
    local selected = nil
    for i = 1, Bullet.MAX do
        if Bullet.list[i].active and Bullet.list[i].selected then
            selected = Bullet.list[i]
            break
        end
    end
    if selected then
        local rest = selected.letters:sub(selected.typed + 1)
        UI.text("下一条：" .. rest, 24, 690, 16, UI.col.cyan)
    else
        UI.text("敲字母开始回怼 · Esc 撤退", 24, 690, 16, UI.col.dim2)
    end


end

local function drawTutorial()
    if B.tutorialStep > 2 then
        return
    end
    local texts = {
        [0] = "① 屏幕上飘下来的气泡带着拼音字母，直接敲键盘把它敲掉",
        [1] = "② 敲完一整句会变成回怼弹幕飞回账号，账号掉血退场",
        [2] = "③ 左边是你的心态值，气泡触底会掉；心态归零本轮结束",
    }
    local t = texts[B.tutorialStep] or ""
    local w = UI.textWidth(t, 16) + 40
    UI.rect(640 - w / 2, 646, w, 32, UI.col.void, 0.85)
    UI.frame(640 - w / 2, 646, w, 32, UI.col.cyan)
    UI.text(t, 640 - w / 2, 652, 16, UI.col.text, "center", w)
    UI.text("Enter 跳过引导", 640, 680, 16, UI.col.dim2, "center", 0)
end

local function drawRetreatConfirm()
    UI.dim(0.6)
    UI.panel(400, 260, 480, 200, { shadow = false })
    UI.text("确定撤退？", 640, 290, 24, UI.col.text, "center", 0)
    UI.text("本轮照常结算技能点，但拿不到失败保底 +3", 640, 330, 16, UI.col.dim, "center", 0)
    local yHover = UI.hit(B.mouse.x, B.mouse.y, 440, 380, 160, 44)
    UI.button(440, 380, 160, 44, "撤退", { hover = yHover, primary = true })
    local nHover = UI.hit(B.mouse.x, B.mouse.y, 680, 380, 160, 44)
    UI.button(680, 380, 160, 44, "继续打", { hover = nHover })
    UI.text("Esc 继续   Enter 确认撤退", 640, 436, 16, UI.col.dim2, "center", 0)
end

function Battle.draw()
    if not B.waveData then
        return
    end
    UI.background(B.time * 0.4)
    -- 环位参考点
    for i = 1, SLOT_COUNT do
        local s = B.slots[i]
        UI.rect(s.x - 2, s.y - 2, 4, 4, UI.col.line, 0.5)
    end
    for i = 1, MAX_ENEMIES do
        local e = B.enemies[i]
        if e.active and e.fade > 0 then
            drawEnemy(e)
        end
    end
    Bullet.draw()
    drawPlayer()
    Bullet.drawRetorts()

    if B.hp / B.hpMax < 0.3 then
        UI.frame(2, 2, 1276, 716, UI.col.red, 0.4)
    end
    if B.shrinkT > 0 then
        UI.frame(40, 40, 1200, 640, UI.col.red, 0.5)
        UI.text("安全区收缩", 640, 56, 16, UI.col.red, "center", 0)
    end
    if B.invulnT > 0 then
        UI.text(string.format("无敌 %.1fs", B.invulnT), 1256, 64, 16, UI.col.green, "right", 0)
    end

    if B.phase == "prep" then
        UI.dim(0.72)
        UI.text("第 " .. B.wave .. " 波", 640, 260, 32, UI.col.text, "center", 0)
        UI.text("主题：" .. B.waveData.theme, 640, 310, 24, UI.col.cyan, "center", 0)
        UI.text("账号 " .. B.waveData.accounts .. " 个 · 词级 " .. B.waveData.tier, 640, 344, 16, UI.col.dim, "center", 0)
        if B.event then
            UI.text("本波事件：" .. B.event.def.name, 640, 380, 16, UI.col.gold, "center", 0)
            UI.text(B.event.def.desc, 640, 404, 16, UI.col.dim, "center", 0)
        end
        UI.text("账号正在就位……  Enter 立即开始", 640, 460, 16, UI.col.dim2, "center", 0)
    elseif B.phase == "clear" then
        UI.text("清场！", 640, 300, 32, UI.col.green, "center", 0)
        UI.text("本波 +" .. (B.waveSp or 0) .. " SP", 640, 344, 24, UI.col.cyan, "center", 0)
    end

    drawHUD()
    drawTutorial()
    if B.confirmRetreat then
        drawRetreatConfirm()
    end
end

-- ---------------------------------------------------------------- 输入接口

function Battle.init(a)
    api = a
    UI = a.ui
    Save = a.save
    Audio = a.audio
    Bullet = require("src.bullet")
    Typing = require("src.typing")
    Talent = a.talent
    Waves = a.data.waves
    Words = a.data.words
    Enemies = a.data.enemies
    Events = a.data.events
    P = Waves.params
    makeSlots()
end

function Battle.enter(opts)
    local save = api.activeSave
    if not save then
        api.switch("menu")
        return
    end
    opts = opts or {}
    local eff = Talent.effects(save.talents, save.influence)
    B.eff = eff
    B.banLetters = {}
    B.banCount = 0
    if eff.ban_letters > 0 then
        local pool = "XZQKVJGBPYFU"
        local n = math.min(#pool, math.floor(eff.ban_letters))
        for i = 1, n do
            B.banLetters[i] = pool:sub(i, i)
        end
        B.banCount = n
    end
    computeCombat()
    B.time = 0
    B.finished = false
    B.retreat = false
    B.confirmRetreat = false
    B.run = {
        waves = 0,
        kills = 0,
        sp = 0,
        spWave = 0,
        spKill = 0,
        heat = 0,
        chars = 0,
        words = 0,
        misses = 0,
        hpLost = 0,
        startWave = 1,
    }
    B.tutorialStep = (save.tutorial_done and 4) or 0
    B.hp = B.hpMax
    B.heat = 0
    Typing.reset(B.threat)
    Bullet.reset()
    Bullet.frozen = false
    keyQueueN = 0
    Audio.playSfx("clear")
    startWave(1)
    -- 工作室：每轮开局送技能点
    if eff.studio_sp > 0 then
        B.run.sp = B.run.sp + math.floor(eff.studio_sp)
        UI.toast("工作室：开局 +" .. math.floor(eff.studio_sp) .. " SP", UI.col.cyan, 3)
    end
end

function Battle.leave()
    B.phase = "idle"
    Bullet.clearAll()
    Bullet.clearRetorts()
end

function Battle.keypressed(key)
    if B.confirmRetreat then
        if key == "escape" or key == "n" then
            B.confirmRetreat = false
        elseif key == "return" or key == "kpenter" or key == "y" then
            B.retreat = true
            B.finishRun(false)
        end
        return
    end
    if key == "escape" then
        B.confirmRetreat = true
        return
    end
    if key == "return" or key == "kpenter" then
        if B.phase == "prep" then
            B.phaseT = 3
        elseif B.tutorialStep < 3 then
            B.tutorialStep = 4
            api.activeSave.tutorial_done = true
        end
        return
    end
    if #key ~= 1 then
        return
    end
    local lower = key:lower()
    if lower < "a" or lower > "z" then
        return
    end
    if B.phase ~= "fight" then
        if B.phase == "prep" then
            B.phaseT = 3
        end
        return
    end
    local ch = lower:upper()
    queueKey(ch)
end

function Battle.mousemoved(x, y)
    B.mouse.x = x
    B.mouse.y = y
end

function Battle.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end
    B.mouse.x = x
    B.mouse.y = y
    if B.confirmRetreat then
        if UI.hit(x, y, 440, 380, 160, 44) then
            B.retreat = true
            B.finishRun(false)
        elseif UI.hit(x, y, 680, 380, 160, 44) then
            B.confirmRetreat = false
        end
        return
    end
    for i, skill in ipairs(B.skills) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local w, h = 120, 32
        local sx = 1256 - (2 - col) * (w + 8) + 8
        local sy = 720 - 60 - row * (h + 6)
        if sy < 400 then
            break
        end
        if UI.hit(x, y, sx, sy, w, h) then
            activateSkill(skill)
            return
        end
    end
end

return Battle
