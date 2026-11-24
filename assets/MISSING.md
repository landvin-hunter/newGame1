# 缺失资源清单

最后更新：2026-11-24
规则（规范 §31~§32）：缺失资源先生成临时占位，不阻塞开发；正式资源到位后删除占位并更新本清单。
占位文件统一放在 `assets/_temp/`，或由代码程序化绘制（本清单会注明）。

| # | 资源 | 当前占位 | 正式规格 | 影响 |
|---|------|----------|----------|------|
| 1 | 中文像素字体 | 无字体文件。启动时从 `C:/Windows/Fonts/simhei.ttf` 读一份拷到存档目录 `_font_cn.ttf` 临时加载（`UI.font_source` 可查来源） | `assets/font/font_cn.ttf`：像素中文字体，8/16/24/32 整倍 | 换一台没装黑体的机器会退回 LÖVE 默认字体（中文变方块） |
| 2 | 英文像素字 | 与中文共用一套 | `assets/font/font_en.ttf`，等宽 | 弹幕字母不是等宽像素字，字模对齐靠固定格宽兜住 |
| 3 | Tabler 图标 PNG | 图标没有转 PNG；`src/ui.lua` 的 `UI.icon()` 用硬边矩形程序化绘制 | 取 `E:\MyGame\resourceBank\icons` 的 outline/filled → PNG → 2× 放大到 48×48 | 图标是近似图形，不是 Tabler 原图；天赋节点用图形 + 颜色区分 |
| 4 | 角色像素图 | `assets/sprite/hero_placeholder.png`（纯色块 + 白字，未接入绘制） | `assets/sprite/hero.png` | 角色由代码绘制成方块像素人 |
| 5 | 账号头像 | `assets/sprite/account_placeholder.png`（同上） | `assets/sprite/account_*.png` | 账号由代码绘制成方块脸 |
| 6 | 键盘像素图 | `assets/sprite/keyboard_placeholder.png`（同上） | `assets/sprite/keyboard.png` | 键盘由代码绘制键帽阵列 |
| 7 | 启动开发者 Logo | 无图片，主菜单启动时程序化绘制文字板 | `assets/sprite/logo_dev.png` | 目前是一块文字排版 |
| 8 | 通用图标占位 | `assets/_temp/icon_placeholder.png` | — | 备用，未接入 |
| 9 | BGM 6 首 | `assets/music/*.wav`，`tools/gen_assets.py` 合成的小样 | OGG Vorbis 44.1kHz：`music_menu` / `music_battle_L1~L3` / `music_fail` / `music_talent` | 音乐是合成小样，正式曲见 `5.音乐设计.txt` |
| 10 | 音效 11 个 | `assets/sfx/*.wav`，同样由脚本合成 | 正式音效（OGG/ WAV），static 加载 | 音效是合成小样 |

## 说明

- 代码加载资源时都做了兜底：字体缺失退回默认字体、音乐/音效缺失静默跳过，不会因为缺资源崩溃。
- 正式 BGM 换成 OGG 后，把 `assets/music/*.wav` 删掉即可；`src/audio.lua` 会优先找 `.ogg`。
- 图标正式 PNG 到位后，把 `UI.icon()` 里的程序化图形替换为图片绘制，节点 `icon` 字段已经按 Tabler 名称写好（如 `keyboard`、`crown`），可以直接对应。
