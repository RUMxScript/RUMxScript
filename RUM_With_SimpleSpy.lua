-- RUM_With_SimpleSpy.lua
-- Unified loader + remote-log bridge for RUM and SimpleSpy.

if getgenv().RUMSimpleSpyIntegrated then
    warn("[RUM + SimpleSpy] Already loaded.")
    return
end
getgenv().RUMSimpleSpyIntegrated = true

local COMMITS = {
    rum = "786e8d4af3693ef82cdc2eb7828a258e85fa59eb",
    simpleSpy = "786e8d4af3693ef82cdc2eb7828a258e85fa59eb",
}

local SOURCES = {
    rum = ("https://raw.githubusercontent.com/RUMxScript/RUMxScript/%s/RUM_GameplayScanner_v6_1_DebugPatch.lua"):format(COMMITS.rum),
    simpleSpy = ("https://raw.githubusercontent.com/RUMxScript/RUMxScript/%s/SimpleSpySource.lua"):format(COMMITS.simpleSpy),
}

local Bridge = {
    events = {},
    dropped = 0,
    maxEvents = 3000,
}

local function safeFullName(inst)
    if typeof(inst) == "Instance" then
        local ok, path = pcall(function() return inst:GetFullName() end)
        if ok then return path end
        local okName, name = pcall(function() return inst.Name end)
        if okName then return tostring(name) end
    end
    return nil
end

local function encodeValue(value, depth)
    depth = depth or 0
    if depth > 4 then return "<depth limit>" end

    local valueType = typeof(value)
    if valueType == "nil" then return nil end
    if valueType == "boolean" then return value end
    if valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return tostring(value)
        end
        return value
    end
    if valueType == "string" then return value end

    if valueType == "Instance" then
        return {
            type = "Instance",
            name = value.Name,
            className = value.ClassName,
            path = safeFullName(value),
        }
    end

    if valueType == "Vector3" then return {type="Vector3", x=value.X, y=value.Y, z=value.Z} end
    if valueType == "Vector2" then return {type="Vector2", x=value.X, y=value.Y} end
    if valueType == "CFrame" then
        local components = {value:GetComponents()}
        return {type="CFrame", components=components}
    end
    if valueType == "Color3" then return {type="Color3", r=value.R, g=value.G, b=value.B} end
    if valueType == "UDim2" then
        return {type="UDim2", xScale=value.X.Scale, xOffset=value.X.Offset, yScale=value.Y.Scale, yOffset=value.Y.Offset}
    end
    if valueType == "EnumItem" then return tostring(value) end

    if type(value) == "table" then
        local output = {}
        local count = 0
        for key, item in pairs(value) do
            count = count + 1
            if count > 200 then
                output["<truncated>"] = true
                break
            end
            local encodedKey
            if type(key) == "string" or type(key) == "number" or type(key) == "boolean" then
                encodedKey = tostring(key)
            else
                encodedKey = "[" .. tostring(typeof(key)) .. "]"
            end
            output[encodedKey] = encodeValue(item, depth + 1)
        end
        return output
    end

    return tostring(value)
end

function RUMSimpleSpyRecord(data)
    if type(data) ~= "table" then return end

    if #Bridge.events >= Bridge.maxEvents then
        Bridge.dropped = Bridge.dropped + 1
        return
    end

    local remote = data.remote
    local method = tostring(data.method or "Unknown")
    local args = encodeValue(data.args, 0)

    Bridge.events[#Bridge.events + 1] = {
        t = os.clock(),
        method = method,
        metamethod = data.metamethod,
        blocked = data.blockcheck == true,
        remote = {
            name = tostring(remote and remote.Name or "<unknown>"),
            className = tostring(remote and remote.ClassName or "<unknown>"),
            path = safeFullName(remote),
            debugId = tostring(data.id or "<unknown>"),
        },
        args = args,
    }
end

Bridge.export = function()
    local output = {}
    for i, event in ipairs(Bridge.events) do
        output[i] = event
    end
    return {
        status = #output > 0 and "recorded" or "no_remote_calls",
        count = #output,
        dropped = Bridge.dropped,
        maxEvents = Bridge.maxEvents,
        events = output,
        note = "Remote payload summary from SimpleSpy; values are encoded safely for RUM export.",
    }
end

Bridge.clear = function()
    table.clear(Bridge.events)
    Bridge.dropped = 0
end

getgenv().RUMSimpleSpyBridge = Bridge

local function fetch(url)
    local ok, source = pcall(game.HttpGet, game, url)
    if not ok then return nil, source end
    return source
end

local function execute(name, source)
    local chunk, compileErr = loadstring(source)
    if not chunk then
        warn(("[RUM + SimpleSpy] %s compile error: %s"):format(name, tostring(compileErr)))
        return false, compileErr
    end
    local runOk, runErr = pcall(chunk)
    if not runOk then
        warn(("[RUM + SimpleSpy] %s runtime error: %s"):format(name, tostring(runErr)))
        return false, runErr
    end
    return true
end

local rumSource, rumErr = fetch(SOURCES.rum)
if rumSource then
    -- Add SimpleSpy remote data to RUM's normal export header.
    rumSource = rumSource:gsub(
        "header.reportQuality=buildQualityReport(snap)",
        "header.reportQuality=buildQualityReport(snap)\n    header.simpleSpyBridge=_G.RUMSimpleSpyBridge and _G.RUMSimpleSpyBridge.export() or {status=\"not_available\"}",
        1
    )
    execute("RUM", rumSource)
else
    warn("[RUM + SimpleSpy] RUM download failed: " .. tostring(rumErr))
end

local simpleSpySource, simpleSpyErr = fetch(SOURCES.simpleSpy)
if simpleSpySource then
    -- Record every scheduled remote event/function call for RUM export.
    simpleSpySource = simpleSpySource:gsub(
        "schedule(remoteHandler,data)",
        "schedule(remoteHandler,data)\n                    pcall(function() RUMSimpleSpyRecord(data) end)",
        2
    )
    execute("SimpleSpy", simpleSpySource)
else
    warn("[RUM + SimpleSpy] SimpleSpy download failed: " .. tostring(simpleSpyErr))
end

getgenv().RUMSimpleSpyClose = function()
    pcall(function()
        if type(getgenv().RUMScannerOneFileClose) == "function" then
            getgenv().RUMScannerOneFileClose()
        end
    end)
    pcall(function()
        if type(getgenv().SimpleSpyShutdown) == "function" then
            getgenv().SimpleSpyShutdown()
        end
    end)
    pcall(function() getgenv().RUMSimpleSpyBridge.clear() end)
    getgenv().RUMSimpleSpyBridge = nil
    getgenv().RUMSimpleSpyIntegrated = nil
end
