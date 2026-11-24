-- 18 个随机事件（来源 4.内容设计.xlsx → 随机列表 B）
-- duration = 0 表示整波生效；effects 的键由 state_battle 解释
return {
    chance = 0.30,   -- 每波开始 30% 概率触发
    first_wave = 6,  -- 前 5 波不触发
    list = {
        {
            id = "R01", name = "输入法卡顿", kind = "负面", weight = 2, duration = 8,
            desc = "按键判定延迟 0.15s（字母轻微抖动）", effects = { input_delay = 0.15 },
            duration_text = "8s",
        },
        {
            id = "R02", name = "键盘进水", kind = "负面", weight = 2, duration = 5,
            desc = "随机 3 个字母键失效，弹幕上该字母闪烁警告", effects = { dead_letters = 3 },
            duration_text = "5s",
        },
        {
            id = "R03", name = "热搜空降", kind = "正面", weight = 3, duration = 0,
            desc = "弹幕数量 +30%，每字母热度 +50%", effects = { bullet_rate = 1.3, heat = 1.5 },
            duration_text = "本波",
        },
        {
            id = "R04", name = "路人围观", kind = "正面", weight = 3, duration = 0,
            desc = "本波热度 ×2，弹幕速度 -20%", effects = { heat = 2, speed = 0.8 },
            duration_text = "本波",
        },
        {
            id = "R05", name = "系统维护", kind = "中性", weight = 2, duration = 5,
            desc = "暂停喷弹幕 5s，可趁机调整", effects = { spawn_pause = 5 },
            duration_text = "5s",
        },
        {
            id = "R06", name = "路人转粉", kind = "正面", weight = 2, duration = 0,
            desc = "本波技能点 +50%", effects = { sp = 1.5 },
            duration_text = "本波",
        },
        {
            id = "R07", name = "毒流量", kind = "风险", weight = 2, duration = 0,
            desc = "本波热度 ×3，输入负载 ×1.5", effects = { heat = 3, bullet_rate = 1.5 },
            duration_text = "本波",
        },
        {
            id = "R08", name = "三连暴击", kind = "正面", weight = 2, duration = 0,
            desc = "本波暴击率 +20%", effects = { crit_add = 0.2 },
            duration_text = "本波",
        },
        {
            id = "R09", name = "键盘升级通知", kind = "正面", weight = 2, duration = 0,
            desc = "本波自动字符率 ×2（免费试用）", effects = { auto = 2 },
            duration_text = "本波",
        },
        {
            id = "R10", name = "平台推流", kind = "正面", weight = 2, duration = 0,
            desc = "本波热度 ×2、弹幕数量 +20%", effects = { heat = 2, bullet_rate = 1.2 },
            duration_text = "本波",
        },
        {
            id = "R11", name = "服务器抽风", kind = "负面", weight = 2, duration = 10,
            desc = "自动字符率下降 50%，持续 10s", effects = { auto = 0.5 },
            duration_text = "10s",
        },
        {
            id = "R12", name = "黑粉反扑", kind = "风险", weight = 1, duration = 0,
            desc = "本波 Boss 血量 ×1.5、技能点 ×2", effects = { boss_hp = 1.5, sp = 2 },
            duration_text = "本波",
        },
        {
            id = "R13", name = "审核延迟", kind = "正面", weight = 2, duration = 0,
            desc = "本波弹幕生成延迟 3s，节奏变松", effects = { spawn_delay = 3 },
            duration_text = "本波",
        },
        {
            id = "R14", name = "限流", kind = "负面", weight = 2, duration = 0,
            desc = "自动字符率 -30%，热度 -20%", effects = { auto = 0.7, heat = 0.8 },
            duration_text = "本波",
        },
        {
            id = "R15", name = "水军增援", kind = "风险", weight = 2, duration = 0,
            desc = "本波账号 +2、技能点 ×1.5", effects = { accounts_add = 2, sp = 1.5 },
            duration_text = "本波",
        },
        {
            id = "R16", name = "键盘灯效", kind = "正面", weight = 2, duration = 0,
            desc = "本波暴击 +15%、热度 +30%", effects = { crit_add = 0.15, heat = 1.3 },
            duration_text = "本波",
        },
        {
            id = "R17", name = "停电", kind = "负面", weight = 1, duration = 6,
            desc = "自动字符率归零，持续 6s", effects = { auto_zero = 1 },
            duration_text = "6s",
        },
        {
            id = "R18", name = "大V翻牌", kind = "风险", weight = 1, duration = 0,
            desc = "本波技能点 ×3、账号血量 ×1.3", effects = { sp = 3, hp = 1.3 },
            duration_text = "本波",
        },
    },
}
