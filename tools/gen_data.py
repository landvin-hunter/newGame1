# -*- coding: utf-8 -*-
"""从 4.内容设计.xlsx 生成 E:/MyGame/newGame1/data/*.lua。

文档（xlsx）是实现数据的唯一来源；本脚本只做转写，不引入新的数值。
用法：python gen_data.py
"""
import math
import os
import re

import openpyxl

SRC = r"E:\MyGame\newGame1-doc\4.内容设计.xlsx"
OUT = r"E:\MyGame\newGame1\data"

BRANCHES = ["输入", "自动", "辅助", "回怼", "战术", "防御", "全局", "局外"]
TIERS = ["T1", "T2", "T3", "T4", "T5", "T6"]

wb = openpyxl.load_workbook(SRC, data_only=True)


def s(v):
    """Lua 字符串字面量。"""
    if v is None:
        return '""'
    t = str(v).replace("\\", "\\\\").replace('"', '\\"')
    t = t.replace("\r", " ").replace("\n", "\\n")
    return '"' + t + '"'


def num(v):
    """Lua 数字字面量：整数不带小数点，浮点保留最短表示。"""
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        if v == int(v):
            return str(int(v))
        return repr(v)
    return str(v)


def cell(ws, r, c):
    return ws.cell(row=r, column=c).value


# ---------------------------------------------------------------- 天赋树


def parse_req(text, by_name):
    req = {"nodes": [], "branch_points": 0, "wave": 0, "rebirth": 0}
    if text is None:
        return req
    text = str(text).strip()
    m = re.search(r"第\s*(\d+)\s*波", text)
    if m:
        req["wave"] = int(m.group(1))
    if "已换马甲" in text:
        req["rebirth"] = 1
    m = re.search(r"(输入|自动|辅助|回怼|战术|防御|全局|局外)系累计\s*(\d+)\s*点", text)
    if m:
        req["branch_points"] = int(m.group(2))
    # 节点等级前置，形如「机械键帽 Lv5」「自动打字机 II Lv5」
    for name, lv in re.findall(r"([\u4e00-\u9fa5A-Za-z0-9·]+(?: [IVX]+)?)\s*Lv\s*(\d+)", text):
        nid = None
        if name in by_name:
            nid = by_name[name]
        else:
            for full, full_id in by_name.items():
                if full.startswith(name) or name.startswith(full):
                    nid = full_id
                    break
        if nid is None:
            raise SystemExit("无法解析前置节点: %r (来自 %r)" % (name, text))
        req["nodes"].append((nid, int(lv)))
    return req


def gen_talents():
    ws = wb["天赋树"]
    rows = []
    for r in range(4, 83):
        rows.append(
            {
                "id": cell(ws, r, 1),
                "branch": cell(ws, r, 2),
                "tier": cell(ws, r, 3),
                "name": cell(ws, r, 4),
                "desc": cell(ws, r, 5),
                "key": cell(ws, r, 6),
                "value": cell(ws, r, 7),
                "mode": cell(ws, r, 8),
                "cost": cell(ws, r, 9),
                "max": cell(ws, r, 10),
                "req_text": cell(ws, r, 11),
                "first_wave": cell(ws, r, 12),
                "icon": cell(ws, r, 13),
            }
        )
    by_name = {r["name"]: r["id"] for r in rows}
    for r in rows:
        r["req"] = parse_req(r["req_text"], by_name)

    # 系内累计门槛：xlsx「天赋树总览」H 列
    ws2 = wb["天赋树总览"]
    gates = {}
    for r in range(4, 12):
        branch = cell(ws2, r, 1)
        text = str(cell(ws2, r, 8) or "")
        g = {}
        for tier, pts in re.findall(r"T(\d)\s*需\s*(\d+)", text):
            g["T" + tier] = int(pts)
        gates[branch] = g

    out = []
    out.append("-- 天赋树：79 个节点（来源 4.内容设计.xlsx → 天赋树）")
    out.append("-- 数值改动请先改 xlsx，再跑 tools/gen_data.py 重新生成，避免文档与实现两套逻辑")
    out.append("return {")
    out.append("    branches = { %s }," % ", ".join(s(b) for b in BRANCHES))
    out.append("    -- 层级门槛：系内累计投入点数")
    out.append("    gates = {")
    for b in BRANCHES:
        parts = ", ".join('%s = %d' % (t.upper(), v) for t, v in sorted(gates.get(b, {}).items()))
        out.append("        [%s] = { %s }," % (s(b), parts))
    out.append("    },")
    out.append("    nodes = {")
    for r in rows:
        req = r["req"]
        rp = []
        if req["nodes"]:
            ns = ", ".join("{ id = %s, level = %d }" % (s(i), lv) for i, lv in req["nodes"])
            rp.append("nodes = { %s }" % ns)
        if req["branch_points"]:
            rp.append("branch_points = %d" % req["branch_points"])
        if req["wave"]:
            rp.append("wave = %d" % req["wave"])
        if req["rebirth"]:
            rp.append("rebirth = %d" % req["rebirth"])
        reqstr = "{ " + ", ".join(rp) + " }"
        out.append("        {")
        out.append(
            "            id = %s, branch = %s, tier = %s, name = %s,"
            % (s(r["id"]), s(r["branch"]), s(r["tier"]), s(r["name"]))
        )
        out.append(
            "            desc = %s, key = %s, value = %s, mode = %s,"
            % (s(r["desc"]), s(r["key"]), num(r["value"]), s(r["mode"]))
        )
        out.append(
            "            cost = %s, max = %s, first_wave = %s, icon = %s,"
            % (num(r["cost"]), num(r["max"]), num(r["first_wave"]), s(r["icon"]))
        )
        out.append("            req = %s," % reqstr)
        out.append("        },")
    out.append("    },")
    out.append("}")
    write("talents.lua", out)
    return rows


# ---------------------------------------------------------------- 天赋树布局


def gen_layout(talents):
    col_w, row_h = 250, 150
    origin_x, origin_y = 170, 90
    tiers = {t: i for i, t in enumerate(TIERS)}
    # 同一层最多 3 个节点：两个并排，第三个下移，避免列宽超出
    offsets = {
        1: [(0, 0)],
        2: [(-62, 0), (62, 0)],
        3: [(-62, 0), (62, 0), (0, 46)],
    }
    pos = {}
    by_bt = {}
    for n in talents:
        by_bt.setdefault((n["branch"], n["tier"]), []).append(n)

    for bi, branch in enumerate(BRANCHES):
        for tier in TIERS:
            group = sorted(by_bt.get((branch, tier), []), key=lambda x: x["id"])
            cnt = len(group)
            for i, n in enumerate(group):
                off = offsets.get(cnt, offsets[3])[i]
                pos[n["id"]] = {
                    "x": int(round(origin_x + bi * col_w + off[0])),
                    "y": origin_y + tiers[tier] * row_h + off[1],
                    "branch": branch,
                    "tier": tier,
                }

    # 父节点：优先显式节点前置，否则连到同系更低层最近的节点
    parent = {}
    for n in talents:
        nid = n["id"]
        req_nodes = n["req"]["nodes"]
        p = None
        if req_nodes:
            p = req_nodes[0][0]
        else:
            best = None
            for m in talents:
                if m["branch"] != n["branch"]:
                    continue
                if tiers[m["tier"]] >= tiers[n["tier"]]:
                    continue
                d = abs(pos[m["id"]]["x"] - pos[nid]["x"]) + (tiers[n["tier"]] - tiers[m["tier"]]) * 8
                if best is None or d < best[0]:
                    best = (d, m["id"])
            if best:
                p = best[1]
        parent[nid] = p

    out = []
    out.append("-- 天赋树坐标（世界坐标，天赋屋内部按 zoom/pan 显示）")
    out.append("-- 每个节点 8 系 × 6 层；parent 为连线父节点")
    out.append("return {")
    out.append("    world = { w = %d, h = %d }," % (origin_x + 7 * col_w + 160, origin_y + 5 * row_h + 200))
    out.append("    cell = { w = 118, h = 38 },")
    out.append("    branch_x = {")
    for bi, b in enumerate(BRANCHES):
        out.append("        [%s] = %d," % (s(b), origin_x + bi * col_w))
    out.append("    },")
    out.append("    tier_y = {")
    for i, t in enumerate(TIERS):
        out.append("        [%s] = %d," % (s(t), origin_y + i * row_h))
    out.append("    },")
    out.append("    nodes = {")
    for n in talents:
        p = parent[n["id"]]
        out.append(
            "        [%s] = { x = %d, y = %d, parent = %s },"
            % (s(n["id"]), pos[n["id"]]["x"], pos[n["id"]]["y"], s(p) if p else "nil")
        )
    out.append("    },")
    out.append("}")
    write("talents_layout.lua", out)


# ---------------------------------------------------------------- 账号原型

BEHAVIORS = {
    "E01": "none",
    "E02": "extra_letter",
    "E03": "triple",
    "E04": "armor",
    "E05": "split",
    "E06": "shuffle",
    "E07": "copy_last",
    "E08": "long_bullet",
    "E09": "fast",
    "E10": "boss1",
    "E11": "rush",
    "E12": "tag",
    "E13": "shared",
    "E14": "mirror",
    "E15": "double",
    "E16": "boss2",
    "E17": "shrink",
    "E18": "double_clear",
    "E19": "append_short",
    "E20": "friend",
    "E21": "repost",
    "E22": "infinite",
    "E23": "immune",
    "E24": "boss3",
}

MOVES = {
    "原地": "static",
    "沿环缓慢横移": "drift",
    "环绕移动": "orbit",
    "飘移": "wander",
    "极慢": "crawl",
    "缓慢列队": "queue",
    "镜像缓慢": "mirror",
    "蜂群绕圈": "swarm",
    "高速环绕": "orbit_fast",
    "缓慢": "slow",
    "环形": "ring",
    "高速旋转": "spin",
    "左右交替": "alternate",
    "无": "none",
}


def parse_tiers(text):
    text = str(text or "")
    found = sorted(set(re.findall(r"T(\d)", text)))
    return ["T" + t for t in found]


def gen_enemies():
    ws = wb["随机列表"]
    rows = []
    for r in range(5, 29):
        eid = cell(ws, r, 1)
        if not eid:
            continue
        slot_text = str(cell(ws, r, 4) or "")
        tags = []
        for tag, kw in (("left", "左"), ("right", "右"), ("top", "顶"), ("center", "中央")):
            if kw in slot_text and tag not in tags:
                tags.append(tag)
        if "任意" in slot_text:
            tags.append("any")
        if "全屏" in slot_text:
            tags.append("event")
        if "上" in slot_text and "top" not in tags:
            tags.append("top")
        m = re.search(r"（\s*(\d+)\s*位）", slot_text)
        count = int(m.group(1)) if m else 1
        rows.append(
            {
                "id": eid,
                "name": cell(ws, r, 2),
                "type": cell(ws, r, 3),
                "slot_text": slot_text,
                "slots": tags,
                "slot_count": count,
                "interval": cell(ws, r, 5),
                "tiers": parse_tiers(cell(ws, r, 6)),
                "hp": cell(ws, r, 7),
                "move": MOVES.get(str(cell(ws, r, 8) or "").strip(), "static"),
                "behavior": BEHAVIORS.get(eid, "none"),
                "sp": cell(ws, r, 10),
                "first_wave": cell(ws, r, 11),
                "tip": cell(ws, r, 12),
            }
        )

    out = []
    out.append("-- 24 种账号（来源 4.内容设计.xlsx → 随机列表 A）")
    out.append("-- slots 为环位偏好：left/right/top/center/any；slot_count 为成群数量")
    out.append("return {")
    out.append("    -- 账号基础血量；实际血量 = base_hp × hp 系数 × 波次血量倍率 × 体力系数")
    out.append("    base_hp = 6,")
    out.append("    list = {")
    for e in rows:
        out.append("        {")
        out.append(
            "            id = %s, name = %s, type = %s, slots = { %s }, slot_count = %d,"
            % (s(e["id"]), s(e["name"]), s(e["type"]), ", ".join(s(t) for t in e["slots"]), e["slot_count"])
        )
        out.append(
            "            interval = %s, tiers = { %s }, hp = %s, move = %s, behavior = %s,"
            % (
                num(e["interval"]),
                ", ".join(s(t) for t in e["tiers"]),
                num(e["hp"]),
                s(e["move"]),
                s(e["behavior"]),
            )
        )
        out.append("            sp = %s, first_wave = %s," % (num(e["sp"]), num(e["first_wave"])))
        out.append("            tip = %s," % s(e["tip"]))
        out.append("            slot_text = %s," % s(e["slot_text"]))
        out.append("        },")
    out.append("    },")
    out.append("}")
    write("enemies.lua", out)


# ---------------------------------------------------------------- 随机事件

EVENT_EFFECTS = {
    "R01": 'input_delay = 0.15',
    "R02": 'dead_letters = 3',
    "R03": 'bullet_rate = 1.3, heat = 1.5',
    "R04": 'heat = 2, speed = 0.8',
    "R05": 'spawn_pause = 5',
    "R06": 'sp = 1.5',
    "R07": 'heat = 3, bullet_rate = 1.5',
    "R08": 'crit_add = 0.2',
    "R09": 'auto = 2',
    "R10": 'heat = 2, bullet_rate = 1.2',
    "R11": 'auto = 0.5',
    "R12": 'boss_hp = 1.5, sp = 2',
    "R13": 'spawn_delay = 3',
    "R14": 'auto = 0.7, heat = 0.8',
    "R15": 'accounts_add = 2, sp = 1.5',
    "R16": 'crit_add = 0.15, heat = 1.3',
    "R17": 'auto_zero = 1',
    "R18": 'sp = 3, hp = 1.3',
}


def gen_events():
    ws = wb["随机列表"]
    rows = []
    for r in range(32, 50):
        eid = cell(ws, r, 1)
        if not eid:
            continue
        dur = str(cell(ws, r, 5) or "")
        secs = 0
        m = re.search(r"(\d+)\s*s", dur)
        if m:
            secs = int(m.group(1))
        rows.append(
            {
                "id": eid,
                "name": cell(ws, r, 2),
                "kind": cell(ws, r, 3),
                "desc": cell(ws, r, 4),
                "duration_text": dur,
                "duration": secs,
                "weight": cell(ws, r, 6),
                "effects": EVENT_EFFECTS[eid],
            }
        )

    out = []
    out.append("-- 18 个随机事件（来源 4.内容设计.xlsx → 随机列表 B）")
    out.append("-- duration = 0 表示整波生效；effects 的键由 state_battle 解释")
    out.append("return {")
    out.append("    chance = 0.30,   -- 每波开始 30% 概率触发")
    out.append("    first_wave = 6,  -- 前 5 波不触发")
    out.append("    list = {")
    for e in rows:
        out.append("        {")
        out.append(
            "            id = %s, name = %s, kind = %s, weight = %s, duration = %d,"
            % (s(e["id"]), s(e["name"]), s(e["kind"]), num(e["weight"]), e["duration"])
        )
        out.append("            desc = %s, effects = { %s }," % (s(e["desc"]), e["effects"]))
        out.append("            duration_text = %s," % s(e["duration_text"]))
        out.append("        },")
    out.append("    },")
    out.append("}")
    write("events.lua", out)


# ---------------------------------------------------------------- 词库

# 反讽梗：搞笑梗强度「低」时剔除（文档 3 §4.7）
EDGE_IDS = {"W063", "W064", "W065", "W028"}
BLOCKED_IDS = {"W069", "W070"}
TIER_DMG = {"T1": 5, "T2": 5, "T3": 8, "T4": 10, "T5": 12, "T6": 15, "T7": 15}


def gen_words():
    ws = wb["词库"]
    rows = []
    for r in range(4, 74):
        wid = cell(ws, r, 1)
        if not wid:
            continue
        pinyin = str(cell(ws, r, 5) or "")
        rows.append(
            {
                "id": wid,
                "tier": cell(ws, r, 2),
                "tier_name": cell(ws, r, 3),
                "text": cell(ws, r, 4),
                "pinyin": pinyin,
                "letters": len(pinyin),
                "first_wave": cell(ws, r, 7),
                "retort": cell(ws, r, 8),
                "note": cell(ws, r, 9),
            }
        )
    out = []
    out.append("-- 70 条词库（来源 4.内容设计.xlsx → 词库）")
    out.append("-- 字母数 = 拼音串长度，由生成脚本算出，不在运行时拼拼音")
    out.append("-- edge：反讽梗，搞笑梗强度「低」时剔除；blocked：脏话缩写，默认屏蔽")
    out.append("return {")
    out.append("    tier_names = {")
    out.append('        T1 = "单键", T2 = "单字/缩写", T3 = "双字词",')
    out.append('        T4 = "短句", T5 = "Boss 长句", T6 = "狂暴长句", T7 = "超长文段",')
    out.append("    },")
    out.append("    -- 未打完的气泡触底按词级扣心态（文档 3 §9）")
    out.append("    tier_damage = { T1 = 5, T2 = 5, T3 = 8, T4 = 10, T5 = 12, T6 = 15, T7 = 15 },")
    out.append("    list = {")
    for w in rows:
        out.append("        {")
        out.append(
            "            id = %s, tier = %s, tier_name = %s, letters = %d, first_wave = %s,"
            % (s(w["id"]), s(w["tier"]), s(w["tier_name"]), w["letters"], num(w["first_wave"]))
        )
        out.append(
            "            text = %s, pinyin = %s, retort = %s,"
            % (s(w["text"]), s(w["pinyin"]), s(w["retort"]))
        )
        out.append(
            "            edge = %s, blocked = %s, dmg = %d, note = %s,"
            % (
                "true" if w["id"] in EDGE_IDS else "false",
                "true" if w["id"] in BLOCKED_IDS else "false",
                TIER_DMG.get(w["tier"], 10),
                s(w["note"]),
            )
        )
        out.append("        },")
    out.append("    },")
    out.append("}")
    write("words.lua", out)


# ---------------------------------------------------------------- 波次与核心参数


def gen_waves():
    ws = wb["波次与数值"]
    rows = []
    for r in range(5, 55):
        n = cell(ws, r, 1)
        if not n:
            continue
        rows.append(
            {
                "wave": int(n),
                "theme": cell(ws, r, 2),
                "duration": cell(ws, r, 3),
                "accounts": cell(ws, r, 4),
                "interval": cell(ws, r, 5),
                "avg_letters": cell(ws, r, 6),
                "load_theory": cell(ws, r, 7),
                "screen_cap": cell(ws, r, 8),
                "flight": cell(ws, r, 9),
                "load_real": cell(ws, r, 10),
                "heat_per_letter": cell(ws, r, 11),
                "heat_wave": cell(ws, r, 12),
                "sp": cell(ws, r, 13),
                "hp_mul": cell(ws, r, 14),
                "layers": cell(ws, r, 15),
                "tier": cell(ws, r, 16),
                "note": cell(ws, r, 17),
            }
        )
    out = []
    out.append("-- 1~50 波（来源 4.内容设计.xlsx → 波次与数值 A）")
    out.append("-- 负载两列只作展示/调试；实际节奏由账号数、间隔、同屏上限、飞行时间算出")
    out.append("return {")
    out.append("    -- 核心参数（同表 B 区）")
    out.append("    params = {")
    out.append("        player_cps = 4,          -- 玩家手速参考（字母/秒），不是硬上限")
    out.append("        combo_window = 1.2,      -- 连击判定窗口（秒）")
    out.append("        screen_cap_min = 12,     -- 同屏弹幕下限")
    out.append("        screen_cap_max = 40,     -- 同屏弹幕上限")
    out.append("        flight_max = 16,         -- 气泡飞行时间上限（秒）")
    out.append("        flight_min = 6.5,        -- 气泡飞行时间下限（秒）")
    out.append("        load_cap = 135,          -- 输入负载天花板（字母/秒）")
    out.append("        char_damage = 1,         -- 单字母基础伤害")
    out.append("        sentence_bonus = 0.5,    -- 整句完成额外热度")
    out.append("        crit_base = 0.05,        -- 暴击基础概率")
    out.append("        crit_heat = 3,           -- 暴击热度倍率")
    out.append("        crit_damage = 2,         -- 暴击回怼伤害倍率")
    out.append("        hp_base = 100,           -- 初始心态值")
    out.append("        miss_hp = 5,             -- 连续 3 次失误扣的心态")
    out.append("        miss_speed = 1.2,        -- 失误后气泡加速")
    out.append("        combo_step = 10,         -- 每 N 连击一档加成")
    out.append("        combo_bonus_base = 0.05, -- 每档加成")
    out.append("        combo_cap_base = 0.5,    -- 连击加成上限")
    out.append("        rebirth_heat = { 10000, 5000000, 200000000 },")
    out.append("        rebirth_wave = { 15, 30, 50 },")
    out.append("        offline_cap_hours = 8,")
    out.append("        respec_influence_per = 10,   -- 每 10 点已投入技能点花 1 影响力")
    out.append("        max_wave = 50,")
    out.append("    },")
    out.append("    list = {")
    for w in rows:
        out.append("        {")
        out.append(
            "            wave = %d, theme = %s, duration = %s, accounts = %s, interval = %s,"
            % (w["wave"], s(w["theme"]), num(w["duration"]), num(w["accounts"]), num(w["interval"]))
        )
        out.append(
            "            avg_letters = %s, load_theory = %s, screen_cap = %s, flight = %s, load_real = %s,"
            % (
                num(w["avg_letters"]),
                num(w["load_theory"]),
                num(w["screen_cap"]),
                num(w["flight"]),
                num(w["load_real"]),
            )
        )
        out.append(
            "            heat_per_letter = %s, heat_wave = %s, sp = %s, hp_mul = %s, layers = %s,"
            % (
                num(w["heat_per_letter"]),
                num(w["heat_wave"]),
                num(w["sp"]),
                num(w["hp_mul"]),
                num(w["layers"]),
            )
        )
        out.append("            tier = %s, note = %s," % (s(w["tier"]), s(w["note"])))
        out.append("        },")
    out.append("    },")
    out.append("}")
    write("waves.lua", out)


def write(name, lines):
    path = os.path.join(OUT, name)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote", path, len(lines), "lines")


def main():
    if not os.path.isdir(OUT):
        os.makedirs(OUT)
    talents = gen_talents()
    gen_layout(talents)
    gen_enemies()
    gen_events()
    gen_words()
    gen_waves()
    print("nodes:", len(talents))
    print("branches:", {b: sum(1 for n in talents if n["branch"] == b) for b in BRANCHES})


if __name__ == "__main__":
    main()
