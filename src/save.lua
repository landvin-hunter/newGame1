-- 存档读写：save/<槽位>/save.json（规范 §9、流程 §14）
-- 设计要点：
--   · 目录必须落在游戏目录下，所以用 io + Win32 API，而不是 love.filesystem（后者在 appdata）
--   · 先写 .tmp 再 rename，rename 前保留上一版 save.bak
--   · version 不匹配时备份旧档再新建，不静默丢数据
local Save = {}

local SAVE_VERSION = 1
local MAX_SLOTS = 6

-- ---------------------------------------------------------------- Win32 文件系统

local ffi = nil
pcall(function()
    ffi = require("ffi")
end)

local CreateDirectoryA = nil

if ffi then
    local ok = pcall(ffi.cdef, [[
        int CreateDirectoryA(const char* lpPathName, void* lpSecurityAttributes);
    ]])
    if ok then
        CreateDirectoryA = ffi.C.CreateDirectoryA
    end
end

local function mkdir(path)
    if CreateDirectoryA then
        return CreateDirectoryA(path, nil) ~= 0
    end
    os.execute('cmd /c mkdir "' .. path .. '" >nul 2>nul')
    return true
end

local function mkdirs(path)
    local prefix = ""
    for seg in path:gmatch("([^/\\]+)") do
        prefix = prefix .. seg .. "/"
        mkdir(prefix)
    end
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    local data = f:read("*a")
    f:close()
    return data
end

local function fileExists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

-- ---------------------------------------------------------------- JSON

local escape_map = {
    ['"'] = '\\"',
    ["\\"] = "\\\\",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
}

local function escapeStr(s)
    return (
        '"'
        .. s:gsub('[%z\1-\31\\"]', function(c)
            return escape_map[c] or string.format("\\u%04x", c:byte())
        end)
        .. '"'
    )
end

local function numStr(n)
    if n ~= n then
        return "0"
    end
    if n == math.huge or n == -math.huge then
        return "0"
    end
    if n == math.floor(n) and math.abs(n) < 2147483647 then
        return string.format("%d", n)
    end
    return string.format("%.14g", n)
end

local function isArray(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" then
            return false
        end
        n = n + 1
    end
    if n == 0 then
        return false
    end
    for i = 1, n do
        if t[i] == nil then
            return false
        end
    end
    return true
end

local encodeValue

local function encodeTable(t, depth)
    local pad = string.rep("  ", depth)
    local pad2 = string.rep("  ", depth + 1)
    local parts = {}
    if isArray(t) then
        for i = 1, #t do
            parts[#parts + 1] = pad2 .. encodeValue(t[i], depth + 1)
        end
        if #parts == 0 then
            return "[]"
        end
        return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
    end
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = tostring(k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = t[k]
        if v ~= nil then
            parts[#parts + 1] = pad2 .. escapeStr(k) .. ": " .. encodeValue(v, depth + 1)
        end
    end
    if #parts == 0 then
        return "{}"
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
end

encodeValue = function(v, depth)
    local tv = type(v)
    if tv == "table" then
        return encodeTable(v, depth)
    elseif tv == "string" then
        return escapeStr(v)
    elseif tv == "number" then
        return numStr(v)
    elseif tv == "boolean" then
        return v and "true" or "false"
    end
    return "null"
end

local function encode(v)
    return encodeValue(v, 0)
end

local function utf8char(cp)
    if cp < 0x80 then
        return string.char(cp)
    elseif cp < 0x800 then
        return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
    elseif cp < 0x10000 then
        return string.char(
            0xE0 + math.floor(cp / 0x1000),
            0x80 + math.floor(cp / 0x40) % 0x40,
            0x80 + cp % 0x40
        )
    end
    return string.char(
        0xF0 + math.floor(cp / 0x40000),
        0x80 + math.floor(cp / 0x1000) % 0x40,
        0x80 + math.floor(cp / 0x40) % 0x40,
        0x80 + cp % 0x40
    )
end

local function decode(str)
    local pos = 1
    local len = #str

    local function skip()
        while pos <= len do
            local c = str:sub(pos, pos)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then
                pos = pos + 1
            else
                break
            end
        end
    end

    local parseValue

    local function parseString()
        pos = pos + 1
        local buf = {}
        while true do
            local c = str:sub(pos, pos)
            if c == "" then
                error("json: unterminated string")
            end
            if c == '"' then
                pos = pos + 1
                break
            elseif c == "\\" then
                local e = str:sub(pos + 1, pos + 1)
                pos = pos + 2
                if e == "n" then
                    buf[#buf + 1] = "\n"
                elseif e == "r" then
                    buf[#buf + 1] = "\r"
                elseif e == "t" then
                    buf[#buf + 1] = "\t"
                elseif e == "b" then
                    buf[#buf + 1] = "\b"
                elseif e == "f" then
                    buf[#buf + 1] = "\f"
                elseif e == "u" then
                    local hex = str:sub(pos, pos + 3)
                    pos = pos + 4
                    local cp = tonumber(hex, 16) or 63
                    if cp >= 0xD800 and cp <= 0xDBFF then
                        -- 代理对
                        local hex2 = str:sub(pos + 2, pos + 5)
                        local lo = tonumber(hex2, 16)
                        if str:sub(pos, pos + 1) == "\\u" and lo and lo >= 0xDC00 and lo <= 0xDFFF then
                            pos = pos + 6
                            cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00)
                        end
                    end
                    buf[#buf + 1] = utf8char(cp)
                else
                    buf[#buf + 1] = e
                end
            else
                buf[#buf + 1] = c
                pos = pos + 1
            end
        end
        return table.concat(buf)
    end

    local function parseNumber()
        local startPos = pos
        while pos <= len do
            local c = str:sub(pos, pos)
            if c:match("[%d%.eE%+%-]") then
                pos = pos + 1
            else
                break
            end
        end
        return tonumber(str:sub(startPos, pos - 1)) or 0
    end

    local function parseArray()
        pos = pos + 1
        local out = {}
        skip()
        if str:sub(pos, pos) == "]" then
            pos = pos + 1
            return out
        end
        while true do
            out[#out + 1] = parseValue()
            skip()
            local c = str:sub(pos, pos)
            if c == "," then
                pos = pos + 1
                skip()
            elseif c == "]" then
                pos = pos + 1
                break
            else
                error("json: expected , or ] at " .. pos)
            end
        end
        return out
    end

    local function parseObject()
        pos = pos + 1
        local out = {}
        skip()
        if str:sub(pos, pos) == "}" then
            pos = pos + 1
            return out
        end
        while true do
            skip()
            if str:sub(pos, pos) ~= '"' then
                error("json: expected key at " .. pos)
            end
            local key = parseString()
            skip()
            if str:sub(pos, pos) ~= ":" then
                error("json: expected : at " .. pos)
            end
            pos = pos + 1
            out[key] = parseValue()
            skip()
            local c = str:sub(pos, pos)
            if c == "," then
                pos = pos + 1
            elseif c == "}" then
                pos = pos + 1
                break
            else
                error("json: expected , or } at " .. pos)
            end
        end
        return out
    end

    parseValue = function()
        skip()
        local c = str:sub(pos, pos)
        if c == "{" then
            return parseObject()
        elseif c == "[" then
            return parseArray()
        elseif c == '"' then
            return parseString()
        elseif c == "t" then
            pos = pos + 4
            return true
        elseif c == "f" then
            pos = pos + 5
            return false
        elseif c == "n" then
            pos = pos + 4
            return nil
        elseif c == "" then
            error("json: unexpected end")
        end
        return parseNumber()
    end

    return parseValue()
end

-- ---------------------------------------------------------------- 路径

local function sourceDir()
    local src = love.filesystem.getSource()
    if love.filesystem.isFused and love.filesystem.isFused() then
        local base = love.filesystem.getSourceBaseDirectory()
        if base then
            src = base
        end
    end
    src = src:gsub("\\", "/")
    -- 直接运行 .love 压缩包时，存档落在压缩包同级的 save/
    if src:match("%.love$") then
        src = src:gsub("/[^/]*$", "")
    end
    return src
end

local function defaultSave(slot, nick, platform)
    local now = os.time()
    return {
        version = SAVE_VERSION,
        slot = slot or "slot1",
        nick = nick or "键盘侠",
        platform = platform or 1,
        best_wave = 0,
        heat = 0,
        total_heat = 0,
        influence = 0,
        sp = 0,
        talents = {},
        unlocked = {},
        chapters = 0,
        tutorial_done = false,
        fail_streak_wave = 0,
        fail_streak = 0,
        last_run = nil,
        stats = {
            chars_typed = 0,
            words_done = 0,
            max_combo = 0,
            miss_count = 0,
            runs = 0,
            play_time = 0,
            kills = 0,
            waves_cleared = 0,
            best_wave = 0,
            sentences = 0,
        },
        last_save_at = now,
        last_exit_at = now,
        offline_seconds = 0,
    }
end

local function sanitize(t)
    if type(t) ~= "table" then
        return nil
    end
    if type(t.talents) ~= "table" then
        t.talents = {}
    end
    if type(t.unlocked) ~= "table" then
        t.unlocked = {}
    end
    if type(t.stats) ~= "table" then
        t.stats = {}
    end
    local defaults = defaultSave(t.slot, t.nick, t.platform)
    for k, v in pairs(defaults) do
        if t[k] == nil then
            t[k] = v
        end
    end
    for k, v in pairs(defaults.stats) do
        if t.stats[k] == nil then
            t.stats[k] = v
        end
    end
    t.last_run = t.last_run or nil
    return t
end

-- ---------------------------------------------------------------- 对外接口

Save.config = {
    version = 1,
    bgm = 0.7,
    sfx = 1.0,
    filter_profanity = true,
    humor = "中",
    window = "1280x720",
    last_slot = nil,
    tutorial_seen = false,
}

Save.base = nil
Save.using_fallback = false

function Save.init()
    Save.base = sourceDir() .. "/save"
    mkdirs(Save.base)
    -- 目录不可写的兜底：改用 love.filesystem 的存档目录，至少不崩
    local probe = Save.base .. "/.probe"
    local f = io.open(probe, "wb")
    if f then
        f:close()
        os.remove(probe)
    else
        Save.using_fallback = true
        print("[save] 游戏目录不可写，存档回退到 love.filesystem 存档目录")
    end
end

local function slotDir(slot)
    if Save.using_fallback then
        return slot
    end
    return Save.base .. "/" .. slot
end

local function slotPath(slot, name)
    if Save.using_fallback then
        return slot .. "/" .. name
    end
    return slotDir(slot) .. "/" .. name
end

local function writeRaw(path, text)
    local f = io.open(path, "wb")
    if not f then
        return false
    end
    f:write(text)
    f:flush()
    f:close()
    return true
end

local function readRaw(path)
    if Save.using_fallback then
        local ok, data = pcall(love.filesystem.read, path)
        if ok then
            return data
        end
        return nil
    end
    return readFile(path)
end

function Save.default(slot, nick, platform)
    return defaultSave(slot, nick, platform)
end

function Save.configPath()
    if Save.using_fallback then
        return "config.json"
    end
    return Save.base .. "/config.json"
end

function Save.loadConfig()
    local text = readRaw(Save.configPath())
    if text and text ~= "" then
        local ok, data = pcall(decode, text)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do
                Save.config[k] = v
            end
        end
    end
    Save.config.bgm = math.max(0, math.min(1, tonumber(Save.config.bgm) or 0.7))
    Save.config.sfx = math.max(0, math.min(1, tonumber(Save.config.sfx) or 1))
    return Save.config
end

function Save.saveConfig()
    local text = encode(Save.config)
    local path = Save.configPath()
    if not writeRaw(path, text) then
        pcall(love.filesystem.write, path, text)
    end
end

function Save.slots()
    if Save.using_fallback then
        return { "slot1" }
    end
    local text = readRaw(Save.base .. "/slots.json")
    local out = {}
    if text then
        local ok, data = pcall(decode, text)
        if ok and type(data) == "table" and type(data.slots) == "table" then
            for _, s in ipairs(data.slots) do
                out[#out + 1] = s
            end
        end
    end
    if #out == 0 then
        for i = 1, MAX_SLOTS do
            local s = "slot" .. i
            if fileExists(Save.base .. "/" .. s .. "/save.json") then
                out[#out + 1] = s
            end
        end
    end
    return out
end

local function writeSlots(list)
    if Save.using_fallback then
        return
    end
    writeRaw(Save.base .. "/slots.json", encode({ slots = list }))
end

function Save.addSlot(slot)
    local list = Save.slots()
    for _, s in ipairs(list) do
        if s == slot then
            return
        end
    end
    list[#list + 1] = slot
    writeSlots(list)
end

function Save.createSlot(nick, platform)
    local list = Save.slots()
    local used = {}
    for _, s in ipairs(list) do
        used[s] = true
    end
    local slot
    for i = 1, MAX_SLOTS do
        if not used["slot" .. i] then
            slot = "slot" .. i
            break
        end
    end
    if not slot then
        return nil, "存档槽已满"
    end
    if not Save.using_fallback then
        mkdirs(slotDir(slot))
    else
        pcall(love.filesystem.createDirectory, slot)
    end
    local data = defaultSave(slot, nick, platform)
    Save.write(data)
    Save.addSlot(slot)
    return slot
end

function Save.load(slot)
    local text = readRaw(slotPath(slot, "save.json"))
    if not text or text == "" then
        return nil
    end
    local ok, data = pcall(decode, text)
    if not ok or type(data) ~= "table" then
        -- 读不出来也先备份，绝不直接覆盖玩家数据
        Save.backupBroken(slot, text)
        return nil
    end
    if data.version ~= SAVE_VERSION then
        Save.backupBroken(slot, text)
        local fresh = defaultSave(slot, data.nick, data.platform)
        Save.write(fresh)
        return fresh
    end
    data = sanitize(data)
    local elapsed = os.time() - (tonumber(data.last_exit_at) or os.time())
    data.offline_seconds = math.max(0, elapsed)
    return data
end

function Save.backupBroken(slot, text)
    local stamp = os.date("%Y%m%d_%H%M%S")
    local name = "save.old." .. stamp .. ".json"
    writeRaw(slotPath(slot, name), text or "")
end

function Save.write(data)
    if not data then
        return false
    end
    data.version = SAVE_VERSION
    data.last_save_at = os.time()
    data.last_exit_at = os.time()
    local text = encode(data)
    local final = slotPath(data.slot, "save.json")
    local tmp = slotPath(data.slot, "save.tmp")
    local bak = slotPath(data.slot, "save.bak")

    if Save.using_fallback then
        pcall(love.filesystem.createDirectory, data.slot)
    end

    if not writeRaw(tmp, text) then
        -- 主目录写不了就退回 love.filesystem
        Save.using_fallback = true
        local dir = slotPath(data.slot, "save.json")
        pcall(love.filesystem.createDirectory, data.slot)
        local ok = pcall(love.filesystem.write, dir, text)
        return ok
    end

    -- 保留上一版
    local old = readRaw(final)
    if old then
        writeRaw(bak, old)
    end
    os.remove(final)
    local ok, err = os.rename(tmp, final)
    if not ok then
        -- 极端情况：写不回去时至少留下 tmp 与 bak
        print("[save] rename 失败: " .. tostring(err))
        return false
    end
    return true
end

function Save.deleteSlot(slot)
    if Save.using_fallback then
        pcall(love.filesystem.remove, slot .. "/save.json")
    else
        for _, name in ipairs({ "save.json", "save.bak", "save.tmp" }) do
            os.remove(slotPath(slot, name))
        end
    end
    local list = Save.slots()
    local out = {}
    for _, s in ipairs(list) do
        if s ~= slot then
            out[#out + 1] = s
        end
    end
    writeSlots(out)
end

function Save.meta(slot)
    local data = Save.load(slot)
    if not data then
        return nil
    end
    return {
        slot = slot,
        nick = data.nick,
        platform = data.platform,
        best_wave = data.best_wave,
        sp = data.sp,
        influence = data.influence,
        chapters = data.chapters,
        talent_count = (function()
            local n = 0
            for _ in pairs(data.talents) do
                n = n + 1
            end
            return n
        end)(),
        play_time = data.stats.play_time or 0,
        last_save_at = data.last_save_at,
    }
end

-- 测试与调试用：把内部函数暴露出来，方便做一致性校验
Save._encode = encode
Save._decode = decode
Save.SAVE_VERSION = SAVE_VERSION
Save.MAX_SLOTS = MAX_SLOTS

return Save
