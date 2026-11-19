-- RUM_With_SimpleSpy.lua
-- Unified launcher for RUM Gameplay Scanner and SimpleSpy.
-- Both tools remain separate GUIs; this file only guards and loads their pinned sources.

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

local function fetch(url)
    local ok, source = pcall(game.HttpGet, game, url)
    if not ok then
        return nil, source
    end
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
    execute("RUM", rumSource)
else
    warn("[RUM + SimpleSpy] RUM download failed: " .. tostring(rumErr))
end

local simpleSpySource, simpleSpyErr = fetch(SOURCES.simpleSpy)
if simpleSpySource then
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
    getgenv().RUMSimpleSpyIntegrated = nil
end
