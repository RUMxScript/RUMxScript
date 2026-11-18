local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Theme = {
    Bg = Color3.fromRGB(11, 11, 11),
    Panel = Color3.fromRGB(17, 17, 17),
    Row = Color3.fromRGB(21, 21, 21),
    Stroke = Color3.fromRGB(121, 255, 38),
    Text = Color3.fromRGB(250, 250, 250),
    SubText = Color3.fromRGB(160, 160, 160),
    Accent = Color3.fromRGB(121, 255, 38),
    AccentText = Color3.fromRGB(10, 10, 10),
    Off = Color3.fromRGB(49, 49, 49),
}

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function strokeOn(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.3
    s.Parent = parent
    return s
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function makeDraggable(handle, target)
    local dragging = false
    local dragStart, startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    conn:Disconnect()
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local UI = {}

function UI:CreateWindow(opts)
    opts = opts or {}
    local windowName = opts.Name or "RUM Script"

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RUMScript_UI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

    local root = Instance.new("Frame")
    root.Size = UDim2.fromOffset(460, 360)
    root.Position = UDim2.fromOffset(60, 60)
    root.BackgroundColor3 = Theme.Bg
    root.BorderSizePixel = 0
    root.Parent = screenGui
    corner(root, 14)
    strokeOn(root, Theme.Stroke, 1.5, 0.25)

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 42)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = root

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -48, 1, 0)
    titleLabel.Position = UDim2.fromOffset(16, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = windowName
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16
    titleLabel.TextColor3 = Theme.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(28, 28)
    closeBtn.Position = UDim2.new(1, -36, 0, 7)
    closeBtn.BackgroundColor3 = Theme.Off
    closeBtn.Text = "X"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.TextColor3 = Theme.Text
    closeBtn.Parent = titleBar
    corner(closeBtn, 8)
    closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -32, 0, 1)
    divider.Position = UDim2.fromOffset(16, 42)
    divider.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    divider.BorderSizePixel = 0
    divider.Parent = root

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -32, 0, 30)
    tabBar.Position = UDim2.fromOffset(16, 52)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = root

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 8)
    tabLayout.Parent = tabBar

    local pages = Instance.new("Frame")
    pages.Size = UDim2.new(1, -32, 1, -96)
    pages.Position = UDim2.fromOffset(16, 90)
    pages.BackgroundTransparency = 1
    pages.Parent = root

    makeDraggable(titleBar, root)

    local Window = {}
    Window._tabs = {}
    Window._hasFirstTab = false

    function Window:Destroy()
        screenGui:Destroy()
    end

    function Window:CreateTab(tabName)
        tabName = tabName or "Tab"

        local tabBtn = Instance.new("TextButton")
        tabBtn.Size = UDim2.fromOffset(math.max(60, #tabName * 8 + 24), 30)
        tabBtn.BackgroundColor3 = Theme.Off
        tabBtn.Text = tabName
        tabBtn.Font = Enum.Font.GothamBold
        tabBtn.TextSize = 13
        tabBtn.TextColor3 = Theme.SubText
        tabBtn.Parent = tabBar
        corner(tabBtn, 8)

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.fromScale(1, 1)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = Theme.Accent
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.Visible = false
        page.Parent = pages

        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, 8)
        listLayout.Parent = page
        listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            page.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
        end)

        local Tab = {}

        local function activate()
            for _, t in ipairs(Window._tabs) do
                t.page.Visible = false
                t.button.BackgroundColor3 = Theme.Off
                t.button.TextColor3 = Theme.SubText
            end
            page.Visible = true
            tabBtn.BackgroundColor3 = Theme.Accent
            tabBtn.TextColor3 = Theme.AccentText
        end
        tabBtn.MouseButton1Click:Connect(activate)
        table.insert(Window._tabs, { page = page, button = tabBtn })
        if not Window._hasFirstTab then
            Window._hasFirstTab = true
            activate()
        end

        function Tab:CreateParagraph(info)
            info = info or {}
            local box = Instance.new("Frame")
            box.Size = UDim2.new(1, 0, 0, 44)
            box.BackgroundColor3 = Theme.Row
            box.BorderSizePixel = 0
            box.Parent = page
            corner(box, 10)

            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, -24, 0, 18)
            title.Position = UDim2.fromOffset(12, 8)
            title.BackgroundTransparency = 1
            title.Text = info.Title or ""
            title.Font = Enum.Font.GothamBold
            title.TextSize = 13
            title.TextColor3 = Theme.Text
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.Parent = box

            local content = Instance.new("TextLabel")
            content.Size = UDim2.new(1, -24, 0, 0)
            content.AutomaticSize = Enum.AutomaticSize.Y
            content.Position = UDim2.fromOffset(12, 28)
            content.BackgroundTransparency = 1
            content.Text = info.Content or ""
            content.TextWrapped = true
            content.Font = Enum.Font.Gotham
            content.TextSize = 12
            content.TextColor3 = Theme.SubText
            content.TextXAlignment = Enum.TextXAlignment.Left
            content.Parent = box

            local function resize()
                box.Size = UDim2.new(1, 0, 0, 28 + content.AbsoluteSize.Y + 10)
            end
            content:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
            task.defer(resize)
            return box
        end

        function Tab:CreateButton(info)
            info = info or {}
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 40)
            btn.BackgroundColor3 = Theme.Row
            btn.Text = info.Name or "Button"
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 14
            btn.TextColor3 = Theme.Text
            btn.Parent = page
            corner(btn, 10)
            btn.MouseButton1Click:Connect(function()
                if info.Callback then pcall(info.Callback) end
            end)
            return btn
        end

        function Tab:CreateToggle(info)
            info = info or {}
            local state = info.Default == true

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 40)
            row.BackgroundColor3 = Theme.Row
            row.Parent = page
            corner(row, 10)

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -70, 1, 0)
            label.Position = UDim2.fromOffset(14, 0)
            label.BackgroundTransparency = 1
            label.Text = info.Name or "Toggle"
            label.Font = Enum.Font.Gotham
            label.TextSize = 14
            label.TextColor3 = Theme.Text
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = row

            local switch = Instance.new("TextButton")
            switch.Size = UDim2.fromOffset(46, 24)
            switch.Position = UDim2.new(1, -58, 0.5, -12)
            switch.BackgroundColor3 = state and Theme.Accent or Theme.Off
            switch.Text = ""
            switch.AutoButtonColor = false
            switch.Parent = row
            corner(switch, 12)

            local knob = Instance.new("Frame")
            knob.Size = UDim2.fromOffset(18, 18)
            knob.Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            knob.Parent = switch
            corner(knob, 9)

            local function apply(animated)
                local goalColor = state and Theme.Accent or Theme.Off
                local goalPos = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
                if animated then
                    TweenService:Create(switch, TweenInfo.new(0.15), { BackgroundColor3 = goalColor }):Play()
                    TweenService:Create(knob, TweenInfo.new(0.15), { Position = goalPos }):Play()
                else
                    switch.BackgroundColor3 = goalColor
                    knob.Position = goalPos
                end
            end

            local function set(value, fireCallback)
                state = value
                apply(true)
                if fireCallback ~= false and info.Callback then pcall(info.Callback, state) end
            end

            switch.MouseButton1Click:Connect(function() set(not state) end)
            if state and info.Callback then
                task.defer(function() pcall(info.Callback, state) end)
            end

            return { Set = set, Get = function() return state end }
        end

        function Tab:CreateSlider(info)
            info = info or {}
            local min = info.Min or 0
            local max = info.Max or 100
            local value = clamp(info.Default or min, min, max)

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 52)
            row.BackgroundColor3 = Theme.Row
            row.Parent = page
            corner(row, 10)

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -24, 0, 20)
            label.Position = UDim2.fromOffset(12, 6)
            label.BackgroundTransparency = 1
            label.Text = (info.Name or "Slider") .. ": " .. tostring(value)
            label.Font = Enum.Font.Gotham
            label.TextSize = 13
            label.TextColor3 = Theme.Text
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = row

            local track = Instance.new("Frame")
            track.Size = UDim2.new(1, -24, 0, 6)
            track.Position = UDim2.fromOffset(12, 34)
            track.BackgroundColor3 = Theme.Off
            track.Parent = row
            corner(track, 3)

            local fill = Instance.new("Frame")
            fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
            fill.BackgroundColor3 = Theme.Accent
            fill.Parent = track
            corner(fill, 3)

            local dragging = false
            local function setFromX(x, fireCallback)
                local rel = clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                value = math.floor(min + rel * (max - min) + 0.5)
                fill.Size = UDim2.new(rel, 0, 1, 0)
                label.Text = (info.Name or "Slider") .. ": " .. tostring(value)
                if fireCallback ~= false and info.Callback then pcall(info.Callback, value) end
            end

            track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    setFromX(input.Position.X)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    setFromX(input.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)

            return {
                Set = function(v)
                    local rel = (clamp(v, min, max) - min) / (max - min)
                    setFromX(track.AbsolutePosition.X + rel * track.AbsoluteSize.X)
                end,
                Get = function() return value end,
            }
        end

        function Tab:CreateDropdown(info)
            info = info or {}
            local options = info.Options or {}
            local selected = info.Default or options[1]
            local open = false

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 40)
            row.BackgroundColor3 = Theme.Row
            row.ClipsDescendants = false
            row.ZIndex = 2
            row.Parent = page
            corner(row, 10)

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(0.5, -14, 1, 0)
            label.Position = UDim2.fromOffset(14, 0)
            label.BackgroundTransparency = 1
            label.Text = info.Name or "Dropdown"
            label.Font = Enum.Font.Gotham
            label.TextSize = 14
            label.TextColor3 = Theme.Text
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = row

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0.5, -14, 0, 28)
            btn.Position = UDim2.new(0.5, 0, 0.5, -14)
            btn.BackgroundColor3 = Theme.Off
            btn.Text = tostring(selected or "")
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 13
            btn.TextColor3 = Theme.Text
            btn.ZIndex = 3
            btn.Parent = row
            corner(btn, 8)

            local list = Instance.new("Frame")
            list.Size = UDim2.new(0.5, -14, 0, #options * 28)
            list.Position = UDim2.new(0.5, 0, 1, 4)
            list.BackgroundColor3 = Theme.Panel
            list.Visible = false
            list.ZIndex = 10
            list.Parent = row
            corner(list, 8)
            strokeOn(list, Theme.Stroke, 1, 0.4)

            local listLayout2 = Instance.new("UIListLayout")
            listLayout2.Parent = list

            for _, opt in ipairs(options) do
                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1, 0, 0, 28)
                optBtn.BackgroundTransparency = 1
                optBtn.Text = tostring(opt)
                optBtn.Font = Enum.Font.Gotham
                optBtn.TextSize = 13
                optBtn.TextColor3 = Theme.Text
                optBtn.ZIndex = 10
                optBtn.Parent = list
                optBtn.MouseButton1Click:Connect(function()
                    selected = opt
                    btn.Text = tostring(opt)
                    list.Visible = false
                    open = false
                    if info.Callback then pcall(info.Callback, opt) end
                end)
            end

            btn.MouseButton1Click:Connect(function()
                open = not open
                list.Visible = open
            end)

            return { Get = function() return selected end }
        end

        return Tab
    end

    return Window
end

return UI
