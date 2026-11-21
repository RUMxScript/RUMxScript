-- RUM V10.9 packed distribution | authorized client testing only
-- LZW/Base64 is reversible obfuscation; NEVER put API secrets here.
local OWNER = "RUMxScript"
local REPOSITORY = "RUMxScript"
local SUBDIR = "RUM-Scanner"
local REF = "main"
local root = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPOSITORY .. "/" .. REF .. "/" .. SUBDIR .. "/"
assert(type(loadstring)=="function", "RUM: this client cannot load Lua source")
local function download(path)
    local ok,src=pcall(function() return game:HttpGet(root..path,true) end)
    assert(ok and type(src)=="string" and #src>0 and not src:find("404: Not Found",1,true), "RUM: fetch failed "..path)
    return src
end
local json=game:GetService("HttpService")
local raw=download("manifest.json")
local m=json:JSONDecode(raw)
assert(type(m)=="table" and m.format=="RUM_PACKED_RELEASE_V1" and m.version=="10.9", "RUM: invalid manifest")
assert(type(m.parts)=="table" and #m.parts==12 and m.dictionaryLimit==8192, "RUM: invalid fragments")
local parts={}
for i,p in ipairs(m.parts) do
    assert(type(p.file)=="string" and p.file:match("^%d%d%.txt$"), "RUM: invalid name")
    local s=download("parts/"..p.file)
    assert(#s==p.bytes, "RUM: fragment size mismatch "..p.file)
    parts[i]=s
end
local b64=table.concat(parts)
assert(#b64==m.encodedBytes,"RUM: bundle size mismatch")
local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local values={}
for i=1,#alphabet do values[alphabet:byte(i)]=i-1 end
local function base64Decode(s)
    assert(#s%4==0,"RUM: invalid base64 length")
    local out={}
    for i=1,#s,4 do
        local a,b,c,d=values[s:byte(i)],values[s:byte(i+1)],values[s:byte(i+2)],values[s:byte(i+3)]
        assert(a and b,"RUM: invalid base64")
        local v=a*262144+b*4096+(c or 0)*64+(d or 0)
        out[#out+1]=string.char(math.floor(v/65536)%256)
        if c then out[#out+1]=string.char(math.floor(v/256)%256) end
        if d then out[#out+1]=string.char(v%256) end
    end
    return table.concat(out)
end
local function unpackLZW(raw)
    assert(#raw>0 and #raw%2==0,"RUM: invalid packed data")
    local dict={}
    for i=0,255 do dict[i]=string.char(i) end
    local nextCode=256
    local function codeAt(i)
        return raw:byte(i)*256+raw:byte(i+1)
    end
    local previous=dict[codeAt(1)]
    assert(previous,"RUM: invalid first code")
    local output={previous}
    for i=3,#raw,2 do
        local k=codeAt(i)
        local entry=dict[k]
        if entry==nil then
            assert(k==nextCode, "RUM: invalid LZW code")
            entry=previous..previous:sub(1,1)
        end
        output[#output+1]=entry
        if nextCode<8192 then
            dict[nextCode]=previous..entry:sub(1,1)
            nextCode=nextCode+1
        end
        previous=entry
    end
    return table.concat(output)
end
local source=unpackLZW(base64Decode(b64))
assert(#source==m.expectedSourceBytes,"RUM: decoded length mismatch")
local main,err=loadstring(source)
assert(main, "RUM: compile failed "..tostring(err))
local ok,result=pcall(main)
assert(ok,"RUM: initialization failed "..tostring(result))
return result
