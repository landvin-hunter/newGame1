-- 天赋：前置判定、点数统计、效果聚合（流程 §7）
-- 效果全部来自 data/talents.lua：mode = 加法 时累加，mode = 乘法 时按 value^等级 累乘
local Data = require("data.talents")
local Talent = {}

Talent.nodes = {}
Talent.order = Data.nodes
Talent.branches = Data.branches
Talent.gates = Data.gates

for _, n in ipairs(Data.nodes) do
    Talent.nodes[n.id] = n
end

local ADD_KEYS = {
    "char_value", "char_value_2", "combo_window", "char_dmg", "crit_chance",
    "combo_bonus", "combo_cap", "voice_input", "crit_mult", "dual_hand",
    "auto_cps", "idle_base", "offline_rate", "auto_flat", "auto_targets",
    "ai_auto", "farm", "auto_perfect", "undo", "bullet_slow", "auto_fill",
    "predict", "fuzzy_match", "keywords", "skill_freeze", "auto_complete",
    "grammar_skip", "skill_pause", "spread", "shot_dmg", "pierce", "extra_low",
    "lock_lowhp", "extra_shot", "shot_nuke", "skill_riot", "skill_delete",
    "skill_fold", "skill_pin", "skill_ally", "skill_report", "skill_reverse",
    "skill_ban", "skill_wash", "skill_flip", "hp_max", "miss_penalty",
    "block_rate", "ban_letters", "blocklist", "same_immune", "heal_wave",
    "auto_report", "like_mul", "traffic", "fan_filter", "platform_matrix",
    "recycle", "sp_bonus", "algo", "light_mul", "fan_econ", "inherit",
    "studio_sp", "max_hp_flat",
}

local MUL_KEYS = {
    "char_mul", "char_dmg_mul", "auto_mul", "auto_cps_mul", "global_mul",
    "auto_mul_2", "hp_mul", "hp_mul_2", "platform_mul", "sp_mul", "all_mul",
    "inf_mul", "inf_mul_2", "kb_god", "kb_god_2",
}

local function newEffects()
    local eff = {}
    for _, k in ipairs(ADD_KEYS) do
        eff[k] = 0
    end
    for _, k in ipairs(MUL_KEYS) do
        eff[k] = 1
    end
    eff.heat_mul = 1
    eff.dmg_mul = 1
    eff.auto_mult = 1
    eff.sp_mult = 1
    eff.hp_mult = 1
    eff.bullet_rate = 1
    eff.crit_add = 0
    eff.auto_influence = 0
    eff.per_letter_value = 0
    eff.levels = {}
    return eff
end

function Talent.level(talents, id)
    return (talents and talents[id]) or 0
end

function Talent.isVisible(save, id)
    local n = Talent.nodes[id]
    if not n then
        return false
    end
    -- 「起始可点」的节点在还没打过任何一波时也要可见
    return (save.best_wave or 0) >= (n.first_wave or 1) or (n.first_wave or 1) <= 1
end

function Talent.branchPoints(talents, branch)
    local pts = 0
    for id, lv in pairs(talents or {}) do
        local n = Talent.nodes[id]
        if n and n.branch == branch and lv > 0 then
            pts = pts + lv * n.cost
        end
    end
    return pts
end

function Talent.totalSpent(talents)
    local pts = 0
    for id, lv in pairs(talents or {}) do
        local n = Talent.nodes[id]
        if n and lv > 0 then
            pts = pts + lv * n.cost
        end
    end
    return pts
end

function Talent.spentByBranch(talents)
    local out = {}
    for _, b in ipairs(Talent.branches) do
        out[b] = Talent.branchPoints(talents, b)
    end
    return out
end

function Talent.maxLevel(id)
    return Talent.nodes[id].max
end

local function reqText(n)
    local parts = {}
    -- 「无（需通过第 5 波）」这类：有 wave 就展示
    if n.req and n.req.wave and n.req.wave > 0 then
        parts[#parts + 1] = "通过第 " .. n.req.wave .. " 波"
    end
    if n.req and n.req.rebirth and n.req.rebirth > 0 then
        parts[#parts + 1] = "已换马甲"
    end
    if n.req and n.req.nodes then
        for _, r in ipairs(n.req.nodes) do
            local pn = Talent.nodes[r.id]
            if pn then
                parts[#parts + 1] = pn.name .. " Lv" .. r.level
            end
        end
    end
    if n.req and n.req.branch_points and n.req.branch_points > 0 then
        parts[#parts + 1] = n.branch .. "系累计 " .. n.req.branch_points .. " 点"
    end
    local gate = Talent.gates[n.branch] and Talent.gates[n.branch][n.tier]
    if gate then
        parts[#parts + 1] = n.branch .. "系累计 " .. gate .. " 点（" .. n.tier .. " 门槛）"
    end
    if #parts == 0 then
        return "无前置"
    end
    return table.concat(parts, " / ")
end

Talent.reqText = reqText

-- 返回 可点 / 不可点原因（用于节点提示）
function Talent.check(save, id)
    local n = Talent.nodes[id]
    if not n then
        return false, "未知节点"
    end
    local lv = Talent.level(save.talents, id)
    if lv >= n.max then
        return false, "已满级"
    end
    if not Talent.isVisible(save, id) then
        return false, "通过第 " .. (n.first_wave or 1) .. " 波后出现"
    end
    if (save.sp or 0) < n.cost then
        return false, "技能点不足（需 " .. n.cost .. "）"
    end
    if n.req then
        if n.req.wave and n.req.wave > 0 and (save.best_wave or 0) < n.req.wave then
            return false, "需通过第 " .. n.req.wave .. " 波"
        end
        if n.req.rebirth and n.req.rebirth > 0 and (save.chapters or 0) < n.req.rebirth then
            return false, "需先换马甲"
        end
        if n.req.nodes then
            for _, r in ipairs(n.req.nodes) do
                if Talent.level(save.talents, r.id) < r.level then
                    local pn = Talent.nodes[r.id]
                    return false, (pn and pn.name or r.id) .. " 需 Lv" .. r.level
                end
            end
        end
        if n.req.branch_points and n.req.branch_points > 0 then
            local pts = Talent.branchPoints(save.talents, n.branch)
            if pts < n.req.branch_points then
                return false, n.branch .. "系累计 " .. n.req.branch_points .. " 点（当前 " .. pts .. "）"
            end
        end
    end
    local gate = Talent.gates[n.branch] and Talent.gates[n.branch][n.tier]
    if gate then
        local pts = Talent.branchPoints(save.talents, n.branch)
        if pts < gate then
            return false, n.branch .. "系累计 " .. gate .. " 点（当前 " .. pts .. "）"
        end
    end
    return true
end

function Talent.buy(save, id)
    local ok = Talent.check(save, id)
    if not ok then
        return false
    end
    local n = Talent.nodes[id]
    save.sp = save.sp - n.cost
    save.talents[id] = Talent.level(save.talents, id) + 1
    save.unlocked[id] = true
    save.spent_by_branch = Talent.spentByBranch(save.talents)
    return true
end

function Talent.respecCost(save)
    local spent = Talent.totalSpent(save.talents)
    if spent <= 0 then
        return 0
    end
    return math.max(1, math.floor(spent / 10))
end

function Talent.respec(save)
    local cost = Talent.respecCost(save)
    if cost <= 0 then
        return false, "没有可洗的点数"
    end
    if (save.influence or 0) < cost then
        return false, "影响力不足（需 " .. cost .. "）"
    end
    local refund = Talent.totalSpent(save.talents)
    save.influence = save.influence - cost
    save.sp = save.sp + refund
    save.talents = {}
    save.spent_by_branch = {}
    return true, refund
end

-- 效果聚合：一次战斗/一次存档节点算一次，不在每帧调用
local cacheKey = nil
local cacheEff = nil

function Talent.effects(talents, influence)
    local keyParts = {}
    for id, lv in pairs(talents or {}) do
        if lv > 0 then
            keyParts[#keyParts + 1] = id .. ":" .. lv
        end
    end
    table.sort(keyParts)
    local key = table.concat(keyParts, ",") .. "|" .. tostring(influence or 0)
    if cacheKey == key and cacheEff then
        return cacheEff
    end

    local eff = newEffects()
    for id, lv in pairs(talents or {}) do
        local n = Talent.nodes[id]
        if n and lv > 0 then
            eff.levels[id] = lv
            local v = n.value * lv
            if n.mode == "乘法" then
                eff[n.key] = (eff[n.key] or 1) * (n.value ^ lv)
            else
                eff[n.key] = (eff[n.key] or 0) + v
            end
        end
    end

    -- 复合效果节点（xlsx 里一行写了两条效果的）
    local trafficLv = eff.levels["G02"] or 0
    local algoLv = eff.levels["G05"] or 0
    local fanLv = eff.levels["G07"] or 0
    local platformLv = eff.levels["G03"] or 0

    eff.crit_add = eff.crit_chance + fanLv * 0.02
    eff.per_letter_value = eff.char_value + eff.char_value_2

    -- 热度倍率：大V认证、热搜体质、粉丝滤镜、热搜算法、平台矩阵
    eff.heat_mul = (1 + eff.like_mul)
        * (1 + 0.10 * trafficLv)
        * (1 + 0.15 * fanLv)
        * (1 + 0.40 * algoLv)
        * (1 + 0.25 * platformLv)

    -- 伤害倍率：输入系 × 自动系 × 全局系 × 一把性的「键盘之神 / 换平台」
    eff.dmg_mul = eff.char_mul
        * eff.char_dmg_mul
        * eff.kb_god
        * eff.kb_god_2
        * eff.global_mul
        * eff.platform_mul
        * eff.all_mul

    -- 自动字符率倍率：复制粘贴机 × 自动打字机 II × 算力农场 × 全自动人生效率
    eff.auto_mult = eff.auto_mul
        * eff.auto_cps_mul
        * eff.auto_mul_2
        * (1 + 0.10 * eff.auto_perfect)
        * eff.all_mul

    -- 键盘之光：每点影响力 +10% 自动字符率（每级）
    eff.auto_influence = (eff.light_mul > 0 and (0.10 * (influence or 0) * (eff.levels["P01"] or 0)) or 0)

    eff.sp_mult = eff.sp_mul * eff.all_mul
    eff.hp_mult = eff.hp_mul * eff.hp_mul_2

    -- 弹幕数量：热搜体质 +10%、热搜算法 +15%
    eff.bullet_rate = (1 + 0.10 * trafficLv) * (1 + 0.15 * algoLv)

    cacheKey = key
    cacheEff = eff
    return eff
end

-- 下一目标：优先当前可点的最便宜节点，给天赋屋左侧提示
function Talent.nextTarget(save)
    local bestId, bestCost = nil, nil
    for _, n in ipairs(Talent.order) do
        local ok = Talent.check(save, n.id)
        if ok then
            if not bestCost or n.cost < bestCost then
                bestId, bestCost = n.id, n.cost
            end
        end
    end
    return bestId
end

function Talent.countVisible(save)
    local count = 0
    for _, n in ipairs(Talent.order) do
        if Talent.isVisible(save, n.id) then
            count = count + 1
        end
    end
    return count
end

return Talent
