local lib = {}

lib.null = {}

local encode

local escapeCharMap = {
    ["\\"] = "\\",
    ["\""] = "\"",
    ["\b"] = "b",
    ["\f"] = "f",
    ["\n"] = "n",
    ["\r"] = "r",
    ["\t"] = "t"
}

local escapeCharMapInv = { ["/"] = "/" }

for k, v in pairs(escapeCharMap) do
    escapeCharMapInv[v] = k
end

local function escapeChar(c)
    return "\\" .. (escapeCharMap[c] or string.format("u%04x", c:byte()))
end

local function encodeNil()
    return "null"
end

local function encodeString(v)
    return '"' .. v:gsub('[%z\1-\31\\"]', escapeChar) .. '"'
end

local function encodeNumber(v)
    if v ~= v or v <= -math.huge or v >= math.huge then
        error("invalid number")
    end
    return string.format("%.14g", v)
end

local function encodeTable(val, stack)
    local res = {}
    stack = stack or {}

    if stack[val] then
        error("circular reference")
    end

    stack[val] = true

    local isArray = rawget(val, 1) ~= nil or next(val) == nil

    if isArray then
        local n = 0

        for k in pairs(val) do
            if type(k) ~= "number" then
                error("invalid table key")
            end
            n += 1
        end

        if n ~= #val then
            error("sparse array")
        end

        for i = 1, #val do
            res[i] = encode(val[i], stack)
        end

        stack[val] = nil
        return "[" .. table.concat(res, ",") .. "]"
    end

    for k, v in pairs(val) do
        if type(k) ~= "string" then
            error("invalid table key")
        end
        res[#res + 1] = encode(k, stack) .. ":" .. encode(v, stack)
    end

    stack[val] = nil
    return "{" .. table.concat(res, ",") .. "}"
end

local typeMap = {
    ["nil"] = encodeNil,
    ["table"] = function(v, stack)
        if v == lib.null then
            return "null"
        end
        return encodeTable(v, stack)
    end,
    ["string"] = encodeString,
    ["number"] = encodeNumber,
    ["boolean"] = tostring
}

encode = function(v, stack)
    local f = typeMap[type(v)]
    if not f then
        error("invalid type")
    end
    return f(v, stack)
end

function lib.encode(v)
    return encode(v)
end

local function set(...)
    local r = {}
    for i = 1, select("#", ...) do
        r[select(i, ...)] = true
    end
    return r
end

local space = set(" ", "\t", "\r", "\n")
local delim = set(" ", "\t", "\r", "\n", "]", "}", ",")
local literals = set("true", "false", "null")

local literalMap = {
    ["true"] = true,
    ["false"] = false,
    ["null"] = lib.null
}

local function nextChar(str, i, set, neg)
    for j = i, #str do
        if set[str:sub(j, j)] ~= neg then
            return j
        end
    end
    return #str + 1
end

local function errorAt(str, i, msg)
    local line, col = 1, 1

    for j = 1, i - 1 do
        col += 1
        if str:sub(j, j) == "\n" then
            line += 1
            col = 1
        end
    end

    error(msg .. " at " .. line .. ":" .. col)
end

local function utf8(n)
    local f = math.floor

    if n <= 0x7f then
        return string.char(n)
    elseif n <= 0x7ff then
        return string.char(f(n / 64) + 192, n % 64 + 128)
    elseif n <= 0xffff then
        return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
    end

    return string.char(
        f(n / 262144) + 240,
        f(n % 262144 / 4096) + 128,
        f(n % 4096 / 64) + 128,
        n % 64 + 128
    )
end

local function parseString(str, i)
    local res = {}
    local j = i + 1
    local start = j

    while j <= #str do
        local c = str:byte(j)

        if c < 32 then
            errorAt(str, j, "control char")
        elseif c == 92 then
            res[#res + 1] = str:sub(start, j - 1)
            j += 1

            local esc = str:sub(j, j)

            if esc == "u" then
                local hex = str:match("^%x%x%x%x", j + 1)
                res[#res + 1] = utf8(tonumber(hex, 16))
                j += #hex
            else
                res[#res + 1] = escapeCharMapInv[esc]
            end

            start = j + 1
        elseif c == 34 then
            res[#res + 1] = str:sub(start, j - 1)
            return table.concat(res), j + 1
        end

        j += 1
    end

    errorAt(str, i, "unclosed string")
end

local function parseNumber(str, i)
    local j = nextChar(str, i, delim)
    local n = tonumber(str:sub(i, j - 1))

    if not n then
        errorAt(str, i, "invalid number")
    end

    return n, j
end

local function parseLiteral(str, i)
    local j = nextChar(str, i, delim)
    local w = str:sub(i, j - 1)

    if not literals[w] then
        errorAt(str, i, "invalid literal")
    end

    return literalMap[w], j
end

local parse

local function parseArray(str, i)
    local res = {}
    local n = 1
    i += 1

    while true do
        i = nextChar(str, i, space, true)

        if str:sub(i, i) == "]" then
            return res, i + 1
        end

        res[n], i = parse(str, i)
        n += 1

        i = nextChar(str, i, space, true)

        local c = str:sub(i, i)
        i += 1

        if c == "]" then break end
        if c ~= "," then errorAt(str, i, "expected ] or ,") end
    end

    return res, i
end

local function parseObject(str, i)
    local res = {}
    i += 1

    while true do
        i = nextChar(str, i, space, true)

        if str:sub(i, i) == "}" then
            return res, i + 1
        end

        local key
        key, i = parse(str, i)

        i = nextChar(str, i, space, true)
        i += 1

        local val
        val, i = parse(str, i)

        res[key] = val

        i = nextChar(str, i, space, true)

        local c = str:sub(i, i)
        i += 1

        if c == "}" then break end
        if c ~= "," then errorAt(str, i, "expected } or ,") end
    end

    return res, i
end

local parsers = {
    ['"'] = parseString,
    ['0'] = parseNumber, ['1'] = parseNumber, ['2'] = parseNumber,
    ['3'] = parseNumber, ['4'] = parseNumber, ['5'] = parseNumber,
    ['6'] = parseNumber, ['7'] = parseNumber, ['8'] = parseNumber,
    ['9'] = parseNumber, ['-'] = parseNumber,
    t = parseLiteral,
    f = parseLiteral,
    n = parseLiteral,
    ["["] = parseArray,
    ["{"] = parseObject
}

parse = function(str, i)
    local f = parsers[str:sub(i, i)]
    if not f then
        errorAt(str, i, "invalid char")
    end
    return f(str, i)
end

function lib.decode(str)
    local res, i = parse(str, nextChar(str, 1, space, true))
    i = nextChar(str, i, space, true)

    if i <= #str then
        errorAt(str, i, "trailing data")
    end

    return res
end

return lib