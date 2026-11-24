# 键盘侠 / KEYBOARD HERO

像素风增量游戏 + 打字弹幕对轰 + 天赋树成长。Love2D 11.5，设计基准 1280×720，纯键盘。

> 你被一堆账号围在中间，它们朝你扔带拼音字母的恶评；你把字母敲回去，打得多就挣技能点，
> 点天赋，下一轮撑得更久。自动字符率从 0 长到能接管 97% 的输入，手动从"打工"变成"补刀"。

## 运行

```
D:\Tools\LOVE2D\love.exe E:\MyGame\newGame1
```

只看报错就在命令行跑：

```
D:\Tools\LOVE2D\lovec.exe E:\MyGame\newGame1
```

打包（后期）：工程目录压成 zip 改后缀 `.love`，再与 `love.exe` 合并。

## 操作

| 场景 | 按键 |
|------|------|
| 战斗 | `A`~`Z` 敲字母；`Enter` 跳过波次准备/引导；`Esc` 撤退（二次确认）；鼠标点右下技能按钮 |
| 天赋屋 | 鼠标点击节点；拖拽平移；滚轮缩放；`Z` 全览/复位；方向键或 `WASD` 平移；`Enter` 出战；`Esc` 回菜单 |
| 菜单/列表 | `↑↓` 选择、`Enter` 确认、`Delete` 删档、`Esc` 返回/退出 |
| 全局 | `F11` 全屏；`F3` 调试面板（FPS / update / draw 耗时） |

不绑定中文输入法：战斗内只读 `love.keypressed` 的 a~z，不做 `love.textinput`。

## 目录

```
main.lua                 入口：状态机、缩放、资源初始化
conf.lua                 窗口 1280×720、标题、vsync
src/
  state_menu.lua         主菜单 / 存档列表 / 新建存档
  state_battle.lua       战斗 1~50 波：账号环、弹幕、自动字符率、技能、随机事件、Boss
  state_result.lua       本轮结算
  state_talent.lua       天赋屋（树 + SP + 洗点 + 出战 + 换马甲）
  state_settings.lua     设置
  typing.lua             按键判定 / 选中优先级 / 连击 / 失误
  bullet.lua             弹幕与回怼对象池（160 / 128）
  talent.lua             天赋前置判定、点数统计、效果聚合
  audio.lua              BGM 分层 cross-fade、音效池
  save.lua               存档读写（JSON、原子写、备份、版本迁移）
  ui.lua                 调色板、字体、控件、程序化图标（新增的公共绘制层）
data/                    纯数据，见下
tools/                   数据/占位资源生成脚本（开发用）
assets/                  字体、图、音效、音乐、占位（见 assets/MISSING.md）
save/                    运行时生成：save/<槽位>/save.json
```

## 数据驱动

所有数值来自 `data/`，代码里不写死内容数值：

| 文件 | 内容 |
|------|------|
| `data/talents.lua` | 79 个天赋节点：系、层级、效果键、每级数值、点数、上限、前置、首现波次、图标 |
| `data/talents_layout.lua` | 树的世界坐标、连线父节点、8 系 × 6 层 |
| `data/enemies.lua` | 24 种账号：环位、喷弹间隔系数、词级、血量系数、移动、特殊行为、SP、首现波次 |
| `data/events.lua` | 18 个随机事件：性质、持续、权重、效果 |
| `data/words.lua` | 70 条词库：文案 → 拼音串、词级、首现波次、回怼文案、反讽梗/脏话缩写标记 |
| `data/waves.lua` | 1~50 波：账号数、间隔、字母数、同屏上限、飞行时间、每字母热度、波末热度、SP、血量倍率、弹幕层数、词级 |

`data/*.lua` 由 `tools/gen_data.py` 从 `E:\MyGame\newGame1-doc\4.内容设计.xlsx` 直接转写，
保证文档与实现不出现两套数值。改数值请先改 xlsx，再跑：

```
python tools/gen_data.py
```

`tools/gen_assets.py` 生成占位音频与图片（不是正式资源，见 `assets/MISSING.md`）。

## 单轮流程

1. 主菜单 → 开始游戏/继续游戏 → 存档列表 → 新建存档（昵称 + 平台皮肤）或进入天赋屋
2. 出战：从第 1 波连续推进，波间不停顿、不结算、不消费资源
3. 心态归零或 `Esc` 撤退 → 本轮结算 → 天赋屋
4. 天赋屋点天赋 → 再出战；累计热度 + 波次达标可以换马甲拿影响力

技能点：每波 `2 + 波次÷5 + 账号数`（数据表 `sp` 列），击破账号另加账号自带的 SP；
首次到达新纪录波次 +2；失败保底 +3（主动撤退没有保底）。

## 存档

- 路径：`save/<槽位>/save.json`（最多 6 个槽位），配置文件 `save/config.json` 与存档分开
- 写盘：先写 `save.tmp`，再保留上一版为 `save.bak`，最后 rename，避免强行退出损坏
- 字段：`version / slot / nick / platform / best_wave / heat / total_heat / influence / sp / talents /
  unlocked / chapters / stats / last_run / last_save_at / last_exit_at`
- `version` 不匹配：把旧档备份成 `save.old.<时间>.json` 后新建，不静默丢数据
- 写盘时机：每轮结算、每次点天赋、洗点、换马甲、设置改动、退出、切后台

## 验收自测（对应流程 §8）

- 首轮可过第 3 波：波 1~4 的输入负载 0.3~2.5 字母/秒，纯手动可无伤；波 1 一个账号 6 血
- 每轮结束至少能点 2 个节点：首轮通关 3 波约 15~20 SP，T1 节点 1~2 SP/级
- 手动参与度：波 5 起负载 4~5 字母/秒，纯手动开始掉血；自动系点出来后接管
- 波 20~30 实际负载 78~135 字母/秒，同屏 40、飞行 6.5s，难度转向血量倍率与弹幕层数

## 打包

```
python tools/pack_exe.py
```

产物在 `E:\MyGame\newGame1-build\`：

- `键盘侠\`：`键盘侠.exe` + LÖVE 运行库（love.dll / SDL2.dll / OpenAL32.dll 等）+ `玩法说明.txt`
- `keyboard_hero.love`：纯游戏包，可直接 `love.exe keyboard_hero.love` 运行
- `键盘侠_v0.5_win64.zip`：发布包（解压即玩）

融合 exe 仍然是“exe + 同目录 DLL”，不是真正的单文件；存档写在 exe 同级的 `save\`，
中文路径也能正常读写（文件 API 走 UTF-16，不依赖系统代码页）。
exe 未做数字签名，首次运行 Windows 可能弹 SmartScreen 提示，选“仍要运行”即可。

## 已知取舍 / 待补

- `5.音乐设计.txt` 的分层切换细节尚未逐条实现：当前按波次 1~9 / 10~29 / 30+ 切 L1/L2/L3，
  正式音乐到位后再对齐交叉淡入的小节点。
- 天赋树 8 系 × 6 层是世界坐标（2080×1040），默认 66% 视野只显示到「全局」，「局外」需要平移；
  `Z` 可全览。
- 14 类「每波 1 次/级」技能做成右下角按钮（最多同时显示 6 个），鼠标点击释放；键盘只处理 a~z 与 Esc/Enter。
- 数值平衡只做了纸面推演（见 `data/waves.lua` 的负载列），实机手感需要回填。
