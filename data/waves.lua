-- 1~50 波（来源 4.内容设计.xlsx → 波次与数值 A）
-- 负载两列只作展示/调试；实际节奏由账号数、间隔、同屏上限、飞行时间算出
return {
    -- 核心参数（同表 B 区）
    params = {
        player_cps = 4,          -- 玩家手速参考（字母/秒），不是硬上限
        combo_window = 1.2,      -- 连击判定窗口（秒）
        screen_cap_min = 12,     -- 同屏弹幕下限
        screen_cap_max = 40,     -- 同屏弹幕上限
        flight_max = 16,         -- 气泡飞行时间上限（秒）
        flight_min = 6.5,        -- 气泡飞行时间下限（秒）
        load_cap = 135,          -- 输入负载天花板（字母/秒）
        char_damage = 1,         -- 单字母基础伤害
        sentence_bonus = 0.5,    -- 整句完成额外热度
        crit_base = 0.05,        -- 暴击基础概率
        crit_heat = 3,           -- 暴击热度倍率
        crit_damage = 2,         -- 暴击回怼伤害倍率
        hp_base = 100,           -- 初始心态值
        miss_hp = 5,             -- 连续 3 次失误扣的心态
        miss_speed = 1.2,        -- 失误后气泡加速
        combo_step = 10,         -- 每 N 连击一档加成
        combo_bonus_base = 0.05, -- 每档加成
        combo_cap_base = 0.5,    -- 连击加成上限
        rebirth_heat = { 10000, 5000000, 200000000 },
        rebirth_wave = { 15, 30, 50 },
        offline_cap_hours = 8,
        respec_influence_per = 10,   -- 每 10 点已投入技能点花 1 影响力
        max_wave = 50,
    },
    list = {
        {
            wave = 1, theme = "私信", duration = 45, accounts = 1, interval = 3,
            avg_letters = 1, load_theory = 0.3, screen_cap = 12, flight = 16, load_real = 0.3,
            heat_per_letter = 1, heat_wave = 20, sp = 3, hp_mul = 1, layers = 1,
            tier = "T1", note = "1 个账号，单字母弹幕；教「敲字即回怼」",
        },
        {
            wave = 2, theme = "评论区开战", duration = 50, accounts = 1, interval = 2.6,
            avg_letters = 2, load_theory = 0.8, screen_cap = 12, flight = 15.5, load_real = 0.8,
            heat_per_letter = 1, heat_wave = 28, sp = 3, hp_mul = 1, layers = 1,
            tier = "T2", note = "天赋：心态护甲",
        },
        {
            wave = 3, theme = "评论区开战", duration = 55, accounts = 2, interval = 2.4,
            avg_letters = 3, load_theory = 2.5, screen_cap = 12, flight = 15, load_real = 2.4,
            heat_per_letter = 1, heat_wave = 39, sp = 4, hp_mul = 1, layers = 1,
            tier = "T2", note = "天赋：盲打训练",
        },
        {
            wave = 4, theme = "热门帖", duration = 60, accounts = 2, interval = 2.1,
            avg_letters = 3, load_theory = 2.9, screen_cap = 12, flight = 14.5, load_real = 2.5,
            heat_per_letter = 2, heat_wave = 55, sp = 4, hp_mul = 1, layers = 1,
            tier = "T2", note = "天赋：金句暴击 / 大V认证",
        },
        {
            wave = 5, theme = "热门帖", duration = 65, accounts = 2, interval = 1.9,
            avg_letters = 4, load_theory = 4.2, screen_cap = 20, flight = 14, load_real = 4.2,
            heat_per_letter = 2, heat_wave = 77, sp = 5, hp_mul = 1, layers = 1,
            tier = "T3", note = "天赋：自动打字机 / 弹幕减速（必须自动化）",
        },
        {
            wave = 6, theme = "热门帖", duration = 70, accounts = 3, interval = 1.7,
            avg_letters = 5, load_theory = 8.8, screen_cap = 20, flight = 13.5, load_real = 7.4,
            heat_per_letter = 2, heat_wave = 108, sp = 6, hp_mul = 1, layers = 1,
            tier = "T3", note = "天赋：复制粘贴机 / 输入法联想 / 满血键盘",
        },
        {
            wave = 7, theme = "热搜榜", duration = 75, accounts = 3, interval = 1.6,
            avg_letters = 6, load_theory = 11.2, screen_cap = 20, flight = 13, load_real = 9.2,
            heat_per_letter = 3, heat_wave = 151, sp = 6, hp_mul = 1, layers = 1,
            tier = "T3", note = "天赋：手速狂飙 / 屏蔽词库 / 散射回怼 / 差评折叠",
        },
        {
            wave = 8, theme = "热搜榜", duration = 80, accounts = 3, interval = 1.5,
            avg_letters = 7, load_theory = 14, screen_cap = 20, flight = 12.5, load_real = 11.2,
            heat_per_letter = 4, heat_wave = 211, sp = 6, hp_mul = 1, layers = 1,
            tier = "T3", note = "天赋：删评 / 热搜体质 / 嘴臭回击",
        },
        {
            wave = 9, theme = "热搜榜", duration = 85, accounts = 4, interval = 1.4,
            avg_letters = 8, load_theory = 22.9, screen_cap = 24, flight = 12, load_real = 16,
            heat_per_letter = 4, heat_wave = 295, sp = 7, hp_mul = 1.2, layers = 1,
            tier = "T3/T4", note = "天赋：多线程小号 / 关键字库 / 穿透回怼 / 大写锁定",
        },
        {
            wave = 10, theme = "热搜榜", duration = 90, accounts = 4, interval = 1.3,
            avg_letters = 9, load_theory = 27.7, screen_cap = 24, flight = 11.5, load_real = 18.8,
            heat_per_letter = 5, heat_wave = 413, sp = 8, hp_mul = 1.4, layers = 1,
            tier = "T4", note = "天赋：置顶神评",
        },
        {
            wave = 11, theme = "全网黑", duration = 90, accounts = 4, interval = 1.2,
            avg_letters = 10, load_theory = 33.3, screen_cap = 24, flight = 11, load_real = 21.8,
            heat_per_letter = 6, heat_wave = 579, sp = 8, hp_mul = 1.6, layers = 1,
            tier = "T4", note = "天赋：追踪回怼 / 精神胜利",
        },
        {
            wave = 12, theme = "全网黑", duration = 90, accounts = 5, interval = 1.1,
            avg_letters = 11, load_theory = 50, screen_cap = 24, flight = 10.5, load_real = 25.1,
            heat_per_letter = 7, heat_wave = 810, sp = 9, hp_mul = 1.8, layers = 1,
            tier = "T4", note = "Boss 首战：大V；天赋：举报 / 粉丝滤镜",
        },
        {
            wave = 13, theme = "全网黑", duration = 90, accounts = 5, interval = 1,
            avg_letters = 12, load_theory = 60, screen_cap = 28, flight = 10, load_real = 33.6,
            heat_per_letter = 9, heat_wave = 1134, sp = 9, hp_mul = 2, layers = 1,
            tier = "T4", note = "天赋：换平台 / 连环回怼",
        },
        {
            wave = 14, theme = "全网黑", duration = 90, accounts = 6, interval = 0.95,
            avg_letters = 12, load_theory = 75.8, screen_cap = 28, flight = 9.5, load_real = 35.4,
            heat_per_letter = 11, heat_wave = 1587, sp = 10, hp_mul = 2.2, layers = 1,
            tier = "T5", note = "网暴风暴首现；天赋：模糊匹配",
        },
        {
            wave = 15, theme = "全网黑", duration = 90, accounts = 6, interval = 0.9,
            avg_letters = 14, load_theory = 93.3, screen_cap = 28, flight = 9, load_real = 43.6,
            heat_per_letter = 13, heat_wave = 2222, sp = 11, hp_mul = 2.4, layers = 1,
            tier = "T5", note = "第一轮换马甲条件达成；天赋：键盘之光",
        },
        {
            wave = 16, theme = "增量区间", duration = 90, accounts = 7, interval = 0.85,
            avg_letters = 14, load_theory = 115.3, screen_cap = 32, flight = 8.5, load_real = 52.7,
            heat_per_letter = 15, heat_wave = 3111, sp = 12, hp_mul = 2.6, layers = 1,
            tier = "T4", note = "天赋：双拼输入 / 内容农场 / 热评置顶",
        },
        {
            wave = 17, theme = "增量区间", duration = 90, accounts = 7, interval = 0.82,
            avg_letters = 15, load_theory = 128, screen_cap = 32, flight = 8, load_real = 60,
            heat_per_letter = 18, heat_wave = 4356, sp = 12, hp_mul = 2.8, layers = 1,
            tier = "T5", note = "天赋：自动打字机 II（无限）",
        },
        {
            wave = 18, theme = "增量区间", duration = 90, accounts = 8, interval = 0.79,
            avg_letters = 15, load_theory = 151.9, screen_cap = 32, flight = 7.5, load_real = 64,
            heat_per_letter = 22, heat_wave = 6098, sp = 13, hp_mul = 3, layers = 1,
            tier = "T4", note = "天赋：控评 / 表情包反击；营销矩阵首现",
        },
        {
            wave = 19, theme = "平台战争", duration = 90, accounts = 8, interval = 0.76,
            avg_letters = 16, load_theory = 168.4, screen_cap = 32, flight = 7, load_real = 73.1,
            heat_per_letter = 27, heat_wave = 8538, sp = 13, hp_mul = 3.2, layers = 1.1,
            tier = "T4", note = "天赋：平台矩阵 / 云输入 / 语音转文字",
        },
        {
            wave = 20, theme = "平台战争", duration = 90, accounts = 9, interval = 0.73,
            avg_letters = 16, load_theory = 197.3, screen_cap = 32, flight = 6.5, load_real = 78.8,
            heat_per_letter = 32, heat_wave = 11953, sp = 15, hp_mul = 3.4, layers = 1.1,
            tier = "T5", note = "天赋：反向网暴 / 弹幕回收 / 核心算力 / 全局搜索",
        },
        {
            wave = 21, theme = "平台战争", duration = 90, accounts = 9, interval = 0.7,
            avg_letters = 17, load_theory = 218.6, screen_cap = 36, flight = 6.5, load_real = 94.2,
            heat_per_letter = 38, heat_wave = 16734, sp = 15, hp_mul = 3.6, layers = 1.1,
            tier = "T5", note = "天赋：粉丝经济 / 双手互搏；镜像号首现",
        },
        {
            wave = 22, theme = "平台战争", duration = 90, accounts = 10, interval = 0.67,
            avg_letters = 17, load_theory = 253.7, screen_cap = 36, flight = 6.5, load_real = 94.2,
            heat_per_letter = 46, heat_wave = 23427, sp = 16, hp_mul = 3.8, layers = 1.2,
            tier = "T5", note = "天赋：自动举报 / 极限盲打 / 杠精免疫",
        },
        {
            wave = 23, theme = "平台战争", duration = 90, accounts = 10, interval = 0.64,
            avg_letters = 18, load_theory = 281.2, screen_cap = 36, flight = 6.5, load_real = 99.7,
            heat_per_letter = 55, heat_wave = 32798, sp = 16, hp_mul = 4, layers = 1.2,
            tier = "T5", note = "天赋：全网洗地",
        },
        {
            wave = 24, theme = "舆论海啸", duration = 90, accounts = 11, interval = 0.61,
            avg_letters = 18, load_theory = 324.6, screen_cap = 36, flight = 6.5, load_real = 99.7,
            heat_per_letter = 66, heat_wave = 45917, sp = 17, hp_mul = 4.2, layers = 1.3,
            tier = "T5", note = "天赋：热搜算法 / 时间暂停；热搜蜜蜂首现",
        },
        {
            wave = 25, theme = "舆论海啸", duration = 90, accounts = 11, interval = 0.58,
            avg_letters = 19, load_theory = 360.3, screen_cap = 36, flight = 6.5, load_real = 105.2,
            heat_per_letter = 79, heat_wave = 64284, sp = 18, hp_mul = 4.4, layers = 1.3,
            tier = "T5", note = "天赋：钛合金键盘 / 算法推荐位",
        },
        {
            wave = 26, theme = "舆论海啸", duration = 90, accounts = 12, interval = 0.55,
            avg_letters = 19, load_theory = 414.5, screen_cap = 40, flight = 6.5, load_real = 116.9,
            heat_per_letter = 95, heat_wave = 89998, sp = 19, hp_mul = 4.6, layers = 1.4,
            tier = "T5", note = "天赋：换马甲继承 / 键盘之神 / AI 代打",
        },
        {
            wave = 27, theme = "舆论海啸", duration = 90, accounts = 12, interval = 0.52,
            avg_letters = 20, load_theory = 461.5, screen_cap = 40, flight = 6.5, load_real = 123.1,
            heat_per_letter = 114, heat_wave = 125997, sp = 19, hp_mul = 4.8, layers = 1.5,
            tier = "T5", note = "Boss 2：超级大V",
        },
        {
            wave = 28, theme = "舆论海啸", duration = 90, accounts = 13, interval = 0.49,
            avg_letters = 20, load_theory = 530.6, screen_cap = 40, flight = 6.5, load_real = 123.1,
            heat_per_letter = 137, heat_wave = 176395, sp = 20, hp_mul = 5, layers = 1.5,
            tier = "T6", note = "天赋：影响力加速 / 全网声讨",
        },
        {
            wave = 29, theme = "舆论海啸", duration = 90, accounts = 13, interval = 0.46,
            avg_letters = 21, load_theory = 593.5, screen_cap = 40, flight = 6.5, load_real = 129.2,
            heat_per_letter = 165, heat_wave = 246953, sp = 20, hp_mul = 5.2, layers = 1.6,
            tier = "T6", note = "网暴巨兽首现",
        },
        {
            wave = 30, theme = "舆论海啸", duration = 90, accounts = 14, interval = 0.43,
            avg_letters = 22, load_theory = 716.3, screen_cap = 40, flight = 6.5, load_real = 135.4,
            heat_per_letter = 198, heat_wave = 345735, sp = 22, hp_mul = 5.5, layers = 1.7,
            tier = "T6", note = "第二轮换马甲条件达成",
        },
        {
            wave = 31, theme = "全网追杀", duration = 90, accounts = 15, interval = 0.4,
            avg_letters = 23, load_theory = 862.5, screen_cap = 40, flight = 6.5, load_real = 141.5,
            heat_per_letter = 237, heat_wave = 484029, sp = 23, hp_mul = 6, layers = 1.8,
            tier = "T6", note = "公关团队首现；天赋：工作室",
        },
        {
            wave = 32, theme = "全网追杀", duration = 90, accounts = 15, interval = 0.38,
            avg_letters = 23, load_theory = 907.9, screen_cap = 40, flight = 6.5, load_real = 141.5,
            heat_per_letter = 285, heat_wave = 677640, sp = 23, hp_mul = 6.5, layers = 1.9,
            tier = "T6", note = "血量进入 ×6.5 段，输出不够就拖死",
        },
        {
            wave = 33, theme = "全网追杀", duration = 90, accounts = 16, interval = 0.36,
            avg_letters = 24, load_theory = 1066.7, screen_cap = 40, flight = 6.5, load_real = 147.7,
            heat_per_letter = 342, heat_wave = 948696, sp = 24, hp_mul = 7, layers = 2,
            tier = "T6", note = "数据女工首现；天赋：封号",
        },
        {
            wave = 34, theme = "全网追杀", duration = 90, accounts = 16, interval = 0.34,
            avg_letters = 24, load_theory = 1129.4, screen_cap = 40, flight = 6.5, load_real = 147.7,
            heat_per_letter = 410, heat_wave = 1328175, sp = 24, hp_mul = 7.5, layers = 2,
            tier = "T6", note = "天赋：公关团队",
        },
        {
            wave = 35, theme = "全网追杀", duration = 90, accounts = 17, interval = 0.32,
            avg_letters = 25, load_theory = 1328.1, screen_cap = 40, flight = 6.5, load_real = 153.8,
            heat_per_letter = 492, heat_wave = 1859444, sp = 26, hp_mul = 8, layers = 2.1,
            tier = "T6", note = "反串黑首现",
        },
        {
            wave = 36, theme = "资本入场", duration = 90, accounts = 18, interval = 0.34,
            avg_letters = 25, load_theory = 1323.5, screen_cap = 40, flight = 6.5, load_real = 153.8,
            heat_per_letter = 591, heat_wave = 2603222, sp = 27, hp_mul = 8.5, layers = 2.2,
            tier = "T6", note = "天赋：舆论核弹",
        },
        {
            wave = 37, theme = "资本入场", duration = 90, accounts = 18, interval = 0.33,
            avg_letters = 26, load_theory = 1418.2, screen_cap = 40, flight = 6.5, load_real = 160,
            heat_per_letter = 709, heat_wave = 3644511, sp = 27, hp_mul = 9, layers = 2.3,
            tier = "T6", note = "洗稿号首现",
        },
        {
            wave = 38, theme = "资本入场", duration = 90, accounts = 19, interval = 0.32,
            avg_letters = 26, load_theory = 1543.8, screen_cap = 40, flight = 6.5, load_real = 160,
            heat_per_letter = 851, heat_wave = 5102316, sp = 28, hp_mul = 9.5, layers = 2.4,
            tier = "T6", note = "天赋：算力农场",
        },
        {
            wave = 39, theme = "资本入场", duration = 90, accounts = 19, interval = 0.31,
            avg_letters = 26, load_theory = 1593.5, screen_cap = 40, flight = 6.5, load_real = 160,
            heat_per_letter = 1021, heat_wave = 7143242, sp = 28, hp_mul = 10, layers = 2.5,
            tier = "T6", note = "算法推荐首现",
        },
        {
            wave = 40, theme = "资本入场", duration = 90, accounts = 20, interval = 0.3,
            avg_letters = 26, load_theory = 1733.3, screen_cap = 40, flight = 6.5, load_real = 160,
            heat_per_letter = 1225, heat_wave = 10000539, sp = 30, hp_mul = 11, layers = 2.6,
            tier = "T6", note = "天赋：键盘之神·改",
        },
        {
            wave = 41, theme = "镜像深渊", duration = 90, accounts = 21, interval = 0.3,
            avg_letters = 27, load_theory = 1890, screen_cap = 40, flight = 6.5, load_real = 166.2,
            heat_per_letter = 1470, heat_wave = 14000754, sp = 31, hp_mul = 12, layers = 2.7,
            tier = "T6", note = "审核机器人首现；天赋：心理素质",
        },
        {
            wave = 42, theme = "镜像深渊", duration = 90, accounts = 22, interval = 0.3,
            avg_letters = 27, load_theory = 1980, screen_cap = 40, flight = 6.5, load_real = 166.2,
            heat_per_letter = 1764, heat_wave = 19601056, sp = 32, hp_mul = 13, layers = 2.8,
            tier = "T6", note = "天赋：MCN 合同",
        },
        {
            wave = 43, theme = "镜像深渊", duration = 90, accounts = 22, interval = 0.29,
            avg_letters = 28, load_theory = 2124.1, screen_cap = 40, flight = 6.5, load_real = 172.3,
            heat_per_letter = 2116, heat_wave = 27441478, sp = 32, hp_mul = 14, layers = 3,
            tier = "T6", note = "T7 词池预热，长文开始混入",
        },
        {
            wave = 44, theme = "镜像深渊", duration = 90, accounts = 23, interval = 0.28,
            avg_letters = 28, load_theory = 2300, screen_cap = 40, flight = 6.5, load_real = 172.3,
            heat_per_letter = 2540, heat_wave = 38418069, sp = 33, hp_mul = 15, layers = 3.1,
            tier = "T6", note = "天赋：舆论反转",
        },
        {
            wave = 45, theme = "镜像深渊", duration = 90, accounts = 24, interval = 0.28,
            avg_letters = 29, load_theory = 2485.7, screen_cap = 40, flight = 6.5, load_real = 178.5,
            heat_per_letter = 3048, heat_wave = 53785296, sp = 35, hp_mul = 16, layers = 3.2,
            tier = "T6", note = "天赋：全自动人生",
        },
        {
            wave = 46, theme = "无限刷屏", duration = 90, accounts = 24, interval = 0.27,
            avg_letters = 29, load_theory = 2577.8, screen_cap = 40, flight = 6.5, load_real = 178.5,
            heat_per_letter = 3657, heat_wave = 75299415, sp = 35, hp_mul = 18, layers = 3.4,
            tier = "T6", note = "T7 长文进入词池",
        },
        {
            wave = 47, theme = "无限刷屏", duration = 90, accounts = 25, interval = 0.26,
            avg_letters = 30, load_theory = 2884.6, screen_cap = 40, flight = 6.5, load_real = 184.6,
            heat_per_letter = 4389, heat_wave = 105419181, sp = 36, hp_mul = 20, layers = 3.6,
            tier = "T6", note = "天赋：流量黑洞",
        },
        {
            wave = 48, theme = "无限刷屏", duration = 90, accounts = 25, interval = 0.25,
            avg_letters = 30, load_theory = 3000, screen_cap = 40, flight = 6.5, load_real = 184.6,
            heat_per_letter = 5266, heat_wave = 147586853, sp = 36, hp_mul = 22, layers = 3.8,
            tier = "T6", note = "T7 成为主力词池，T6 退为辅助",
        },
        {
            wave = 49, theme = "无限刷屏", duration = 90, accounts = 26, interval = 0.24,
            avg_letters = 30, load_theory = 3250, screen_cap = 40, flight = 6.5, load_real = 184.6,
            heat_per_letter = 6320, heat_wave = 206621594, sp = 37, hp_mul = 24, layers = 4,
            tier = "T6", note = "Boss 3 前置波",
        },
        {
            wave = 50, theme = "无限刷屏", duration = 90, accounts = 26, interval = 0.23,
            avg_letters = 30, load_theory = 3391.3, screen_cap = 40, flight = 6.5, load_real = 184.6,
            heat_per_letter = 7584, heat_wave = 289270232, sp = 38, hp_mul = 28, layers = 4.2,
            tier = "T6", note = "Boss 3：流量黑洞；第三轮换马甲条件",
        },
    },
}
