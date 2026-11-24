-- 窗口与模块配置（规范 §3 基准 1280×720；F11 全屏在 main.lua 处理）
function love.conf(t)
    t.identity = "newgame1"
    t.version = "11.5"
    t.console = false

    t.window.title = "键盘侠"
    t.window.width = 1280
    t.window.height = 720
    t.window.minwidth = 640
    t.window.minheight = 360
    t.window.resizable = true
    t.window.vsync = 1
    t.window.msaa = 0
    t.window.highdpi = false

    -- 只保留用到的模块，减少启动开销
    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = true
    t.modules.system = true
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true
    t.modules.thread = false
    t.modules.joystick = false
end
