local GET_KEY_URL = "https://PASTE-LINK-LAY-KEY-THAT-VAO-DAY.example.com"

local KEYCHECK_BASE = "https://rumscript.com/k.php"

local MAP = {
}
local DEFAULT_ENTRY = { s = "5v6uc9", name = "RUM Script" }

local CACHE_FILE = "RUMScript_Bridge_Key.json"
local CACHE_MAX_AGE = 2 * 24 * 60 * 60

local capability = {
    save = type(writefile) == "function" and type(readfile) == "function",
    delete = type(delfile) == "function",
    clipboard = type(setclipboard) == "function",
}

local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local player = game:GetService("Players").LocalPlayer

local function readCache()
    if not capability.save then return nil end
    local ok, raw = pcall(readfile, CACHE_FILE)
    if not ok or type(raw) ~= "string" or raw == "" then return nil end
    local okJson, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not okJson or type(data) ~= "table" then return nil end
    return data
end

local function writeCache(key)
    if not capability.save then return end
    pcall(function()
        writefile(CACHE_FILE, HttpService:JSONEncode({ key = key, savedAt = os.time() }))
    end)
end

local function clearCache()
    if capability.delete then pcall(delfile, CACHE_FILE) end
end

local function checkKey(entry, key)
    if type(key) ~= "string" or key:match("^%s*$") then
        return false, "Vui lòng nhập key"
    end
    local url = KEYCHECK_BASE .. "?s=" .. HttpService:UrlEncode(entry.s) .. "&k=" .. HttpService:UrlEncode(key)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok then
        return false, "Không gọi được server (mạng/HTTP bị chặn): " .. tostring(body)
    end
    if type(body) ~= "string" or #body < 16 then
        return false, "Key sai hoặc đã hết hạn"
    end
    local fn, compileErr = loadstring(body)
    if not fn then
        return false, "Key sai hoặc đã hết hạn"
    end
    return true, body
end

local function runScript(code)
    local fn, err = loadstring(code)
    if not fn then
        warn("[RUM Script Bridge] Compile that bai: " .. tostring(err))
        return false
    end
    local ok, runErr = pcall(fn)
    if not ok then
        warn("[RUM Script Bridge] Loi khi chay: " .. tostring(runErr))
        return false
    end
    return true
end

local function showKeyTab(entry, onSuccess)
    local root = Instance.new("ScreenGui")
    root.Name = "RUMScript_KeyTab"
    root.ResetOnSpawn = false
    root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    root.Parent = (gethui and gethui()) or game:GetService("CoreGui")

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.35
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 1
    overlay.Parent = root

    local card = Instance.new("Frame")
    card.Size = UDim2.fromOffset(420, 320)
    card.Position = UDim2.new(0.5, -210, 0.5, -160)
    card.BackgroundColor3 = Color3.fromRGB(11, 11, 11)
    card.BorderSizePixel = 0
    card.ZIndex = 2
    card.Parent = root
    local cardCorner = Instance.new("UICorner", card)
    cardCorner.CornerRadius = UDim.new(0, 14)
    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color = Color3.fromRGB(121, 255, 38)
    cardStroke.Thickness = 1.5
    cardStroke.Transparency = 0.25

    local logo = Instance.new("TextLabel")
    logo.Size = UDim2.new(1, -40, 0, 36)
    logo.Position = UDim2.fromOffset(20, 18)
    logo.BackgroundTransparency = 1
    logo.Text = "RUM"
    logo.Font = Enum.Font.GothamBlack
    logo.TextSize = 26
    logo.TextColor3 = Color3.fromRGB(121, 255, 38)
    logo.TextXAlignment = Enum.TextXAlignment.Left
    logo.ZIndex = 3
    logo.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 22)
    title.Position = UDim2.fromOffset(20, 54)
    title.BackgroundTransparency = 1
    title.Text = "RUM SCRIPT"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(250, 250, 250)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 3
    title.Parent = card

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -40, 0, 1)
    divider.Position = UDim2.fromOffset(20, 84)
    divider.BackgroundColor3 = Color3.fromRGB(49, 49, 49)
    divider.BorderSizePixel = 0
    divider.ZIndex = 3
    divider.Parent = card

    local keyLabel = Instance.new("TextLabel")
    keyLabel.Size = UDim2.new(1, -40, 0, 20)
    keyLabel.Position = UDim2.fromOffset(20, 98)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Text = "KEY :"
    keyLabel.Font = Enum.Font.Gotham
    keyLabel.TextSize = 14
    keyLabel.TextColor3 = Color3.fromRGB(204, 204, 204)
    keyLabel.TextXAlignment = Enum.TextXAlignment.Left
    keyLabel.ZIndex = 3
    keyLabel.Parent = card

    local inputBox = Instance.new("Frame")
    inputBox.Size = UDim2.new(1, -40, 0, 44)
    inputBox.Position = UDim2.fromOffset(20, 122)
    inputBox.BackgroundColor3 = Color3.fromRGB(21, 21, 21)
    inputBox.BorderSizePixel = 0
    inputBox.ZIndex = 3
    inputBox.Parent = card
    local inputCorner = Instance.new("UICorner", inputBox)
    inputCorner.CornerRadius = UDim.new(0, 10)

    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(1, -24, 1, 0)
    keyInput.Position = UDim2.fromOffset(12, 0)
    keyInput.BackgroundTransparency = 1
    keyInput.Text = ""
    keyInput.PlaceholderText = "Dán key vào đây..."
    keyInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    keyInput.TextColor3 = Color3.fromRGB(250, 250, 250)
    keyInput.Font = Enum.Font.Gotham
    keyInput.TextSize = 15
    keyInput.TextXAlignment = Enum.TextXAlignment.Left
    keyInput.ClearTextOnFocus = false
    keyInput.ZIndex = 4
    keyInput.Parent = inputBox

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -40, 0, 36)
    statusLabel.Position = UDim2.fromOffset(20, 172)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextWrapped = true
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 13
    statusLabel.TextColor3 = Color3.fromRGB(238, 124, 117)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.ZIndex = 3
    statusLabel.Parent = card

    local function makeButton(text, x, w, bg)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(w, 46)
        btn.Position = UDim2.fromOffset(x, 216)
        btn.BackgroundColor3 = bg
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 15
        btn.TextColor3 = Color3.fromRGB(10, 10, 10)
        btn.ZIndex = 3
        btn.Parent = card
        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0, 10)
        return btn
    end

    local getKeyBtn = makeButton("GET KEY", 20, 175, Color3.fromRGB(49, 49, 49))
    getKeyBtn.TextColor3 = Color3.fromRGB(121, 255, 38)
    local checkKeyBtn = makeButton("CHECK KEY", 205, 175, Color3.fromRGB(121, 255, 38))

    local footer = Instance.new("TextLabel")
    footer.Size = UDim2.new(1, -40, 0, 18)
    footer.Position = UDim2.fromOffset(20, 282)
    footer.BackgroundTransparency = 1
    footer.Text = "Key tự đổi mỗi 2 ngày. Hết hạn thì lấy key mới."
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 11
    footer.TextColor3 = Color3.fromRGB(120, 120, 120)
    footer.TextXAlignment = Enum.TextXAlignment.Left
    footer.ZIndex = 3
    footer.Parent = card

    getKeyBtn.MouseButton1Click:Connect(function()
        if capability.clipboard then
            pcall(setclipboard, GET_KEY_URL)
            statusLabel.TextColor3 = Color3.fromRGB(121, 255, 38)
            statusLabel.Text = "Đã copy link lấy key vào clipboard, dán ra trình duyệt."
        else
            statusLabel.TextColor3 = Color3.fromRGB(121, 255, 38)
            statusLabel.Text = "Copy link này ra trình duyệt: " .. GET_KEY_URL
        end
    end)

    local checking = false
    checkKeyBtn.MouseButton1Click:Connect(function()
        if checking then return end
        checking = true
        local prevText = checkKeyBtn.Text
        checkKeyBtn.Text = "ĐANG CHECK..."
        statusLabel.TextColor3 = Color3.fromRGB(204, 204, 204)
        statusLabel.Text = "Đang kiểm tra key..."

        local key = keyInput.Text:match("^%s*(.-)%s*$") or ""
        local ok, result = checkKey(entry, key)

        checking = false
        checkKeyBtn.Text = prevText

        if ok then
            writeCache(key)
            statusLabel.TextColor3 = Color3.fromRGB(121, 255, 38)
            statusLabel.Text = "Key hợp lệ! Đang mở script..."
            task.wait(0.3)
            pcall(function() root:Destroy() end)
            onSuccess(result)
        else
            statusLabel.TextColor3 = Color3.fromRGB(238, 124, 117)
            statusLabel.Text = tostring(result)
        end
    end)
end

local function resolveEntry()
    local gameId = tostring(game.GameId)
    local entries = MAP[gameId]
    if entries and entries[1] then return entries[1] end
    return DEFAULT_ENTRY
end

local function boot()
    local entry = resolveEntry()

    local cached = readCache()
    if cached and type(cached.key) == "string" and cached.savedAt
       and (os.time() - cached.savedAt) < CACHE_MAX_AGE then
        local ok, result = checkKey(entry, cached.key)
        if ok then
            runScript(result)
            return
        else
            clearCache()
        end
    end

    showKeyTab(entry, function(code)
        runScript(code)
    end)
end

boot()
