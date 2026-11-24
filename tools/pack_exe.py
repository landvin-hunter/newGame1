# -*- coding: utf-8 -*-
r"""把 E:\MyGame\newGame1 打包成可运行的 Windows 目录 + 单文件 exe（融合式）。

规范 §6：工程目录压成 zip 改后缀 .love，再与 love.exe 合并出单文件 exe。
注意：融合 exe 仍需要同目录的 love.dll / SDL2.dll 等运行库，所以交付的是一个文件夹 + zip。
"""
import os
import shutil
import zipfile

SRC = r"E:\MyGame\newGame1"      # 游戏工程目录
LOVE = r"D:\Tools\LOVE2D"          # Love2D 安装目录（含 love.exe 与 DLL）
OUT = r"E:\MyGame\newGame1-build"  # 产物目录（不进版本库）
DIST = os.path.join(OUT, "键盘侠")
GAME_LOVE = os.path.join(OUT, "keyboard_hero.love")
EXE_NAME = "键盘侠.exe"

# 进 .love 的内容（不含 .git / save / tools / 版本管理文件）
INCLUDE = ["main.lua", "conf.lua", "src", "data", "assets", "README.md"]
SKIP_DIRS = {".git", "save", "tools", "__pycache__"}
SKIP_FILES = {".gitignore", ".gitattributes", "Thumbs.db"}


def iter_files(root, rel):
    full = os.path.join(root, rel)
    if os.path.isfile(full):
        yield rel
        return
    for name in sorted(os.listdir(full)):
        if name in SKIP_DIRS or name in SKIP_FILES:
            continue
        sub = rel + "/" + name
        if os.path.isdir(os.path.join(root, sub)):
            for f in iter_files(root, sub):
                yield f
        else:
            yield sub


def build_love():
    if os.path.exists(GAME_LOVE):
        os.remove(GAME_LOVE)
    entries = []
    for inc in INCLUDE:
        entries.extend(iter_files(SRC, inc))
    with zipfile.ZipFile(GAME_LOVE, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for rel in entries:
            z.write(os.path.join(SRC, rel), rel)
    print(f".love: {GAME_LOVE}  files={len(entries)}  size={os.path.getsize(GAME_LOVE)/1024:.0f}KB")
    return entries


def build_dist():
    if os.path.isdir(DIST):
        shutil.rmtree(DIST)
    os.makedirs(DIST, exist_ok=True)

    # 1) 复制运行库
    for name in os.listdir(LOVE):
        lower = name.lower()
        if lower.endswith(".dll") or lower in ("license.txt", "changes.txt"):
            shutil.copy2(os.path.join(LOVE, name), os.path.join(DIST, name))

    # 2) love.exe + .love 拼接成融合 exe
    exe_path = os.path.join(DIST, EXE_NAME)
    with open(os.path.join(LOVE, "love.exe"), "rb") as f:
        head = f.read()
    with open(GAME_LOVE, "rb") as f:
        body = f.read()
    with open(exe_path, "wb") as f:
        f.write(head)
        f.write(body)
    print(f"exe: {exe_path}  size={os.path.getsize(exe_path)/1024/1024:.2f}MB")

    # 3) 附带一份给玩家看的说明
    readme = """键盘侠 / KEYBOARD HERO  v0.5

【怎么玩】
  双击 键盘侠.exe 即可，无需安装。

【操作】
  战斗：A~Z 敲掉气泡上的拼音字母，整句敲完会回怼账号；Enter 跳过准备/引导；Esc 撤退
  天赋屋：鼠标点节点、拖拽平移、滚轮缩放、Z 全览、Enter 出战、Esc 回菜单
  菜单：↑↓ 选择、Enter 确认、Delete 删档、Esc 返回
  全局：F11 全屏、F3 调试面板

【存档】
  存档写在 键盘侠.exe 同级的 save\\<槽位>\\save.json，
  换电脑拷走整个文件夹即可带走进度；save.bak 是上一版备份。

【说明】
  这是可运行开发版：音乐音效为合成占位，美术为程序化像素图形，
  缺失资源清单见仓库 assets/MISSING.md。
"""
    with open(os.path.join(DIST, "玩法说明.txt"), "w", encoding="utf-8-sig", newline="\r\n") as f:
        f.write(readme)

    # 4) 发布压缩包
    zip_path = os.path.join(OUT, "键盘侠_v0.5_win64.zip")
    if os.path.exists(zip_path):
        os.remove(zip_path)
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in sorted(os.listdir(DIST)):
            z.write(os.path.join(DIST, name), name)
    print(f"zip: {zip_path}  size={os.path.getsize(zip_path)/1024/1024:.2f}MB")
    return zip_path


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    build_love()
    build_dist()
