-- RUM V11.1 QA FIX 1 | Test distribution, NOT runtime-certified
-- For authorized testing only. LZW/Base64 is reversible, not encryption.
-- Stable V10.9 remains at RUM-Scanner/Loader.lua.
local OWNER, REPO, REF = "RUMxScript", "RUMxScript", "main"
local DIR = "RUM-Scanner/V11.1-QA"
local root = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. REF .. "/" .. DIR .. "/"
assert(type(loadstring) == "function", "RUM V11.1 QA: loadstring unavailable")
local function download(path)
    local ok, src = pcall(function() return game:HttpGet(root .. path, true) end)
    assert(ok and type(src) == "string" and #src > 0 and not src:find("404: Not Found", 1, true), "RUM: fetch failed " .. path)
    return src
end
local m = game:GetService("HttpService"):JSONDecode(download("manifest.json"))
assert(type(m) == "table" and m.format == "RUM_PACKED_RELEASE_PARTED_V2" and m.version == "11.1-qa-fix1", "RUM: invalid manifest")
assert(type(m.parts) == "table" and #m.parts == 12 and m.dictionaryLimit == 8192, "RUM: invalid manifest parts")
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local values = {}
for i = 1, #alphabet do values[alphabet:byte(i)] = i-1 end
local function decode64(s)
    assert(#s % 4 == 0, "RUM: invalid base64 length")
    local out = {}
    for i = 1, #s, 4 do
        local a, b, c, d = values[s:byte(i)], values[s:byte(i+1)], values[s:byte(i+2)], values[s:byte(i+3)]
        assert(a ~= nil and b ~= nil, "RUM: invalid base64")
        local v = a*262144 + b*4096 + (c or 0)*64 + (d or 0)
        out[#out+1] = string.char(math.floor(v / 65536) % 256)
        if c ~= nil then out[#out+1] = string.char(math.floor(v / 256) % 256) end
        if d ~= nil then out[#out+1] = string.char(v % 256) end
    end
    return table.concat(out)
end
local function unpackLZW(raw)
    assert(#raw > 0 and #raw % 2 == 0, "RUM: invalid compressed data")
    local dict = {}
    for i = 0, 255 do dict[i] = string.char(i) end
    local nextCode = 256
    local function codeAt(i) return raw:byte(i)*256 + raw:byte(i+1) end
    local prev = dict[codeAt(1)]
    assert(prev, "RUM: invalid initial code")
    local output = {prev}
    for i = 3, #raw, 2 do
        local code = codeAt(i)
        local entry = dict[code]
        if entry == nil then
            assert(code == nextCode, "RUM: invalid LZW code")
            entry = prev .. prev:sub(1, 1)
        end
        output[#output+1] = entry
        if nextCode < 8192 then
            dict[nextCode] = prev .. entry:sub(1, 1)
            nextCode = nextCode + 1
        end
        prev = entry
    end
    return table.concat(output)
end
local segments, encodedTotal = {}, 0
for i, part in ipairs(m.parts) do
    assert(type(part.file) == "string" and part.file:match("^%d%d%.txt$"), "RUM: invalid fragment name")
    local encoded = download("parts/" .. part.file)
    assert(#encoded == part.bytes, "RUM: fragment size mismatch " .. part.file)
    encodedTotal = encodedTotal + #encoded
    local decoded = unpackLZW(decode64(encoded))
    assert(#decoded == part.sourceBytes, "RUM: decoded fragment size mismatch " .. part.file)
    segments[i] = decoded
end
assert(encodedTotal == m.encodedBytes, "RUM: encoded total mismatch")
local source = table.concat(segments, "\n")
assert(#source == m.expectedSourceBytes, "RUM: source length mismatch")
local entry, err = loadstring(source)
assert(entry, "RUM: compile failed " .. tostring(err))
local ok, value = pcall(entry)
assert(ok, "RUM: startup failed " .. tostring(value))
return value
