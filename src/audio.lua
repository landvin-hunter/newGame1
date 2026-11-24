-- 音频：BGM 分层 + 0.2s 插值 cross-fade，音效对象池（规范 §7）
-- 资源缺失时静默降级，不阻塞开发（占位见 assets/MISSING.md）
local Audio = {}

local BGM_VOLUME = 0.7
local SFX_VOLUME = 1.0
local FADE_TIME = 0.2
local MAX_SFX = 3

local MUSIC_FILES = {
    menu = { "assets/music/music_menu.ogg", "assets/music/music_menu.wav" },
    battle1 = { "assets/music/music_battle_L1.ogg", "assets/music/music_battle_L1.wav" },
    battle2 = { "assets/music/music_battle_L2.ogg", "assets/music/music_battle_L2.wav" },
    battle3 = { "assets/music/music_battle_L3.ogg", "assets/music/music_battle_L3.wav" },
    fail = { "assets/music/music_fail.ogg", "assets/music/music_fail.wav" },
    talent = { "assets/music/music_talent.ogg", "assets/music/music_talent.wav" },
}

local SFX_FILES = {
    type = { "assets/sfx/type.ogg", "assets/sfx/type.wav" },
    complete = { "assets/sfx/complete.ogg", "assets/sfx/complete.wav" },
    crit = { "assets/sfx/crit.ogg", "assets/sfx/crit.wav" },
    miss = { "assets/sfx/miss.ogg", "assets/sfx/miss.wav" },
    empty = { "assets/sfx/empty.ogg", "assets/sfx/empty.wav" },
    click = { "assets/sfx/click.ogg", "assets/sfx/click.wav" },
    buy = { "assets/sfx/buy.ogg", "assets/sfx/buy.wav" },
    hurt = { "assets/sfx/hurt.ogg", "assets/sfx/hurt.wav" },
    clear = { "assets/sfx/clear.ogg", "assets/sfx/clear.wav" },
    fail = { "assets/sfx/fail.ogg", "assets/sfx/fail.wav" },
    win = { "assets/sfx/win.ogg", "assets/sfx/win.wav" },
}

local music = {} -- name -> Source
local channels = {} -- 正在播放的 BGM 通道
local sfx = {} -- name -> { sources = {...}, index = 1 }
local currentBgm = nil

local function loadFirstSource(paths, kind)
    for _, path in ipairs(paths) do
        if love.filesystem.getInfo(path) then
            local ok, src = pcall(love.audio.newSource, path, kind)
            if ok and src then
                return src
            end
        end
    end
    return nil
end

function Audio.init(config)
    if config then
        BGM_VOLUME = config.bgm or BGM_VOLUME
        SFX_VOLUME = config.sfx or SFX_VOLUME
    end
    for name, paths in pairs(MUSIC_FILES) do
        music[name] = loadFirstSource(paths, "stream")
    end
    for name, paths in pairs(SFX_FILES) do
        local src = loadFirstSource(paths, "static")
        if src then
            local pool = { sources = {}, index = 1 }
            for i = 1, MAX_SFX do
                local ok, clone = pcall(function()
                    return src:clone()
                end)
                pool.sources[i] = ok and clone or src
            end
            sfx[name] = pool
        end
    end
end

function Audio.setVolumes(bgm, s)
    if bgm then
        BGM_VOLUME = math.max(0, math.min(1, bgm))
    end
    if s then
        SFX_VOLUME = math.max(0, math.min(1, s))
    end
end

local function fadeTo(channel, target)
    channel.target = target
    channel.rate = FADE_TIME
end

function Audio.playMusic(name, opts)
    if currentBgm == name and not (opts and opts.restart) then
        return
    end
    local src = music[name]
    if not src then
        currentBgm = name
        return
    end
    -- 旧通道淡出
    for _, ch in ipairs(channels) do
        if not ch.dying then
            fadeTo(ch, 0)
            ch.dying = true
        end
    end
    local ok, instance = pcall(function()
        return src:clone()
    end)
    local channelSource = ok and instance or src
    pcall(function()
        channelSource:setLooping(true)
        channelSource:setVolume(0)
        channelSource:play()
    end)
    channels[#channels + 1] = {
        source = channelSource,
        vol = 0,
        target = 1,
        dying = false,
        rate = FADE_TIME,
        name = name,
    }
    currentBgm = name
end

function Audio.stopMusic()
    for _, ch in ipairs(channels) do
        fadeTo(ch, 0)
        ch.dying = true
    end
    currentBgm = nil
end

function Audio.setBattleLayer(layer)
    if layer <= 1 then
        Audio.playMusic("battle1")
    elseif layer == 2 then
        Audio.playMusic("battle2")
    else
        Audio.playMusic("battle3")
    end
end

function Audio.playSfx(name)
    local pool = sfx[name]
    if not pool then
        return
    end
    local src = pool.sources[pool.index]
    pool.index = pool.index % #pool.sources + 1
    if src then
        pcall(function()
            src:stop()
            src:setVolume(SFX_VOLUME)
            src:play()
        end)
    end
end

function Audio.update(dt)
    local i = 1
    while i <= #channels do
        local ch = channels[i]
        local step = dt / FADE_TIME
        if ch.vol < ch.target then
            ch.vol = math.min(ch.target, ch.vol + step)
        elseif ch.vol > ch.target then
            ch.vol = math.max(ch.target, ch.vol - step)
        end
        pcall(function()
            ch.source:setVolume(math.max(0, math.min(1, ch.vol * BGM_VOLUME)))
        end)
        if ch.dying and ch.vol <= 0.01 then
            pcall(function()
                ch.source:stop()
            end)
            table.remove(channels, i)
        else
            i = i + 1
        end
    end
end

function Audio.setPaused(paused)
    for _, ch in ipairs(channels) do
        pcall(function()
            if paused then
                ch.source:pause()
            elseif ch.source:isPaused() then
                ch.source:play()
            end
        end)
    end
end

function Audio.current()
    return currentBgm
end

return Audio
