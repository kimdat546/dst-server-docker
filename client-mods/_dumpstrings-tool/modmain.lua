-- Temporary server-side mod: harvest the (decrypted) CJK strings the Fairy Tales
-- mod adds to GLOBAL.STRINGS, and print them to the server log so we can build a
-- separate client translation mod. Reads only; mutates nothing.

local STRINGS   = GLOBAL.STRINGS
-- DST's mod sandbox does not expose these as bare globals — pull them from GLOBAL.
local pcall     = GLOBAL.pcall
local pairs     = GLOBAL.pairs
local type      = GLOBAL.type
local tostring  = GLOBAL.tostring
local print     = GLOBAL.print
local string    = GLOBAL.string

-- True if the string contains any CJK / fullwidth lead byte (UTF-8 E3..EF).
local function isCJK(s)
    for i = 1, #s do
        local b = string.byte(s, i)
        if b >= 0xE3 and b <= 0xEF then return true end
    end
    return false
end

-- Escape so each entry stays on one log line and field separators survive.
local function esc(s)
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "\\r")
    s = string.gsub(s, "\t", "\\t")
    return s
end

local function doDump()
    local out, seen = {}, {}
    -- Skip the heavy per-character speech tables and vanilla skin tables in the
    -- top-level walk; item descriptions are grabbed separately from GENERIC.DESCRIBE.
    local SKIP = {
        CHARACTERS = true,
        SKIN_NAMES = true, SKIN_QUOTES = true,
        SKIN_DESCRIPTIONS = true, SKIN_DLC_DESCRIPTIONS = true,
    }
    local function walk(t, path, topskip)
        if type(t) ~= "table" or seen[t] then return end
        seen[t] = true
        for k, v in pairs(t) do
            local kp = path .. "." .. tostring(k)
            local tv = type(v)
            if tv == "string" then
                if isCJK(v) then
                    out[#out + 1] = kp .. "\1" .. esc(v)
                end
            elseif tv == "table" then
                if not (topskip and SKIP[tostring(k)]) then
                    walk(v, kp, false)
                end
            end
        end
    end

    -- NAMES, RECIPE_DESC, UI, ACTIONS, and any mod-custom top-level tables.
    walk(STRINGS, "STRINGS", true)
    -- Item inspect descriptions (the bulk that players read).
    local gd = STRINGS.CHARACTERS and STRINGS.CHARACTERS.GENERIC and STRINGS.CHARACTERS.GENERIC.DESCRIBE
    if gd then walk(gd, "STRINGS.CHARACTERS.GENERIC.DESCRIBE", false) end

    print("@@FAIRYDUMP_BEGIN count=" .. tostring(#out))
    for i = 1, #out do
        print("@@FD\1" .. out[i])
    end
    print("@@FAIRYDUMP_END")
end

AddSimPostInit(function()
    local ok, err = pcall(doDump)
    if not ok then print("@@FAIRYDUMP_ERROR " .. tostring(err)) end
end)
