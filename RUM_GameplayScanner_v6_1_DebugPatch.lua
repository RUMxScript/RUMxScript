local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("[RUM Scanner] Chi chay duoc tren Roblox client.")
    return
end
local playerGui = LocalPlayer:WaitForChild("PlayerGui", 15)
if not playerGui then
    warn("[RUM Scanner] Khong the truy cap PlayerGui.")
    return
end

local previousCleanup
pcall(function()
    if type(getgenv) == "function" then
        local env = getgenv()
        previousCleanup = env.RUMScannerOneFileClose
        if type(previousCleanup) == "function" then pcall(previousCleanup) end
        if type(env.RUMScannerV3Close) == "function" then pcall(env.RUMScannerV3Close) end
        if type(env.RUMScannerV2Close) == "function" then pcall(env.RUMScannerV2Close) end
    end
end)
for _, name in ipairs({"RUM_GameScanner_V2", "RUM_GameScanner_V3", "RUM_GameScanner_OneFile"}) do
    local old = playerGui:FindFirstChild(name)
    if old then pcall(function() old:Destroy() end) end
end

local PALETTE = {
    bg=Color3.fromRGB(13,17,20), panel=Color3.fromRGB(19,25,29),
    subpanel=Color3.fromRGB(24,32,36), green=Color3.fromRGB(91,235,163),
    greenDark=Color3.fromRGB(29,161,104), blue=Color3.fromRGB(35,47,55),
    purple=Color3.fromRGB(29,67,53), text=Color3.fromRGB(235,242,243),
    muted=Color3.fromRGB(152,172,181), border=Color3.fromRGB(43,56,62),
    red=Color3.fromRGB(255,116,116), amber=Color3.fromRGB(240,190,102),
}
local function create(className, parent, props)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function corner(obj, radius)
    create("UICorner", obj, {CornerRadius=UDim.new(0, radius or 7)})
end
local function textLabel(parent, content, pos, size, props)
    local defaults = {
        Text=content, Position=pos, Size=size, BackgroundTransparency=1,
        TextColor3=PALETTE.text, Font=Enum.Font.Gotham,
        TextSize=12, TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
        TextTruncate=Enum.TextTruncate.AtEnd,
    }
    for k,v in pairs(props or {}) do defaults[k]=v end
    return create("TextLabel", parent, defaults)
end
local function button(parent, content, pos, size, color)
    local b=create("TextButton", parent, {
        Text=content, Position=pos, Size=size, BorderSizePixel=0,
        BackgroundColor3=color, TextColor3=PALETTE.text,
        Font=Enum.Font.GothamBold, TextSize=12, AutoButtonColor=true,
    })
    corner(b,6)
    return b
end
local function safePath(inst)
    local ok,v=pcall(function() return inst:GetFullName() end)
    if ok and type(v)=="string" then return v end
    local okName,n=pcall(function() return inst.Name end)
    return okName and tostring(n) or "<unavailable>"
end
local function encodeValue(value)
    local t=typeof(value)
    if t=="nil" then return nil end
    if t=="string" or t=="boolean" then return value end
    if t=="number" then
        return (value==value and value~=math.huge and value~=-math.huge) and value or tostring(value)
    end
    if t=="Vector3" then return {x=value.X,y=value.Y,z=value.Z} end
    if t=="Vector2" then return {x=value.X,y=value.Y} end
    if t=="Color3" then return {r=value.R,g=value.G,b=value.B} end
    if t=="CFrame" then
        local components={value:GetComponents()}
        return {components=components}
    end
    if t=="UDim2" then
        return {xScale=value.X.Scale,xOffset=value.X.Offset,yScale=value.Y.Scale,yOffset=value.Y.Offset}
    end
    if t=="UDim" then return {scale=value.Scale,offset=value.Offset} end
    if t=="EnumItem" then return tostring(value) end
    if t=="Instance" then return {type="InstanceRef",path=safePath(value)} end
    if t=="BrickColor" then return tostring(value) end
    return tostring(value)
end
local function readIssue(diag, kind, inst, field, reason)
    if not diag then return end
    diag[kind]=(diag[kind] or 0)+1
    if #diag.samples<12 then
        diag.samples[#diag.samples+1]={kind=kind,path=safePath(inst),field=field,message=tostring(reason):sub(1,300)}
    end
end
local function tryProperty(inst,key,diag)
    if diag then diag.propertyAttempts=(diag.propertyAttempts or 0)+1 end
    local ok,value=pcall(function() return inst[key] end)
    if not ok then readIssue(diag,"propertyErrors",inst,key,value);return nil end
    if value==nil then
        if diag then diag.propertyNil=(diag.propertyNil or 0)+1 end
        return nil
    end
    local ok2,output=pcall(encodeValue,value)
    if not ok2 then readIssue(diag,"conversionErrors",inst,key,output);return nil end
    if diag then diag.propertyEncoded=(diag.propertyEncoded or 0)+1 end
    return output
end
local function category(inst)
    local c=inst.ClassName
    if c=="RemoteEvent" or c=="RemoteFunction" or c=="UnreliableRemoteEvent" then return "Remote" end
    if c=="ModuleScript" then return "Module" end
    if inst:IsA("BaseScript") then return "Script" end
    if inst:IsA("GuiObject") or inst:IsA("LayerCollector") then return "GUI" end
    if inst:IsA("ValueBase") then return "Value" end
    if inst:IsA("Humanoid") or inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector") then return "Interaction" end
    return "Other"
end
local function propertyList(inst)
    if inst:IsA("ValueBase") then return {"Value"} end
    if inst:IsA("Humanoid") then
        return {"Health","MaxHealth","WalkSpeed","JumpPower","HipHeight","Sit","PlatformStand","MoveDirection","JumpHeight","AutoRotate","FloorMaterial"}
    end
    if inst:IsA("ProximityPrompt") then
        return {"Enabled","ActionText","ObjectText","HoldDuration","MaxActivationDistance","RequiresLineOfSight","KeyboardKeyCode"}
    end
    if inst:IsA("ClickDetector") then return {"MaxActivationDistance"} end
    if inst:IsA("SpawnLocation") then return {"Enabled","Neutral","Duration","Position","Size"} end
    -- Metadata only; does not retrieve asset contents.
    if inst:IsA("MeshPart") then
        return {"Position","Size","Anchored","CanCollide","CanTouch","CanQuery","Transparency","Material","Color","MeshId","TextureID"}
    end
    if inst:IsA("BasePart") then
        return {"Position","Size","Anchored","CanCollide","CanTouch","CanQuery","Transparency","Material","Color"}
    end
    if inst:IsA("SpecialMesh") then return {"MeshId","TextureId"} end
    if inst:IsA("Decal") then return {"Texture","Transparency"} end
    if inst:IsA("Texture") then return {"Texture","Transparency"} end
    if inst:IsA("Sound") then return {"SoundId"} end
    if inst:IsA("ParticleEmitter") then return {"Texture","Enabled"} end
    if inst:IsA("Model") then return {"PrimaryPart","WorldPivot"} end
    if inst:IsA("TextBox") then return {"Visible","Active","Position","Size","TextEditable"} end
    if inst:IsA("TextLabel") or inst:IsA("TextButton") then
        return {"Text","Visible","Active","Position","Size","AbsolutePosition","AbsoluteSize","ZIndex"}
    end
    if inst:IsA("GuiObject") then
        return {"Visible","Active","Position","Size"}
    end
    if inst:IsA("ScreenGui") then return {"Enabled","DisplayOrder","ResetOnSpawn"} end
    if inst:IsA("Tool") then return {"Enabled","RequiresHandle","ToolTip","Grip"} end
    -- Media inspection is limited to basic metadata.
    if inst:IsA("BaseScript") then return {"Enabled","RunContext"} end
    return nil
end
local function detailsFor(inst,diag)
    local p={}
    local fields=propertyList(inst)
    if fields then
        for _,key in ipairs(fields) do
            local val=tryProperty(inst,key,diag)
            if val~=nil then p[key]=val end
        end
    end
    local attrs, attrCount={},0
    local okAttrs,raw=pcall(function() return inst:GetAttributes() end)
    if okAttrs and type(raw)=="table" then
        for k,v in pairs(raw) do
            local ok,converted=pcall(encodeValue,v)
            if ok and converted~=nil then attrs[k]=converted;attrCount=attrCount+1
            elseif not ok then readIssue(diag,"conversionErrors",inst,k,converted) end
        end
    elseif not okAttrs then readIssue(diag,"attributeErrors",inst,"Attributes",raw) end
    local okTags,tags=pcall(function() return CollectionService:GetTags(inst) end)
    if not okTags then readIssue(diag,"tagErrors",inst,"Tags",tags) end
    return p, ((okAttrs and attrCount>0) and attrs or nil), attrCount,
        ((okTags and #tags>0) and tags or nil)
end

local screen=create("ScreenGui",playerGui,{
    Name="RUM_GameScanner_OneFile",ResetOnSpawn=false,
    IgnoreGuiInset=false,DisplayOrder=1000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
})
local cam=workspace.CurrentCamera
local main=create("Frame",screen,{
    Name="Main",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
    Size=UDim2.fromOffset(620,490),BackgroundColor3=PALETTE.bg,
    BorderSizePixel=0,Active=true,
})
corner(main,14)
create("UIStroke",main,{Color=PALETTE.border,Thickness=1})
local scale=create("UIScale",main,{Scale=1})
local function fitWindow()
    local view=(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(800,600)
    scale.Scale=math.max(0.2,math.min(1,(view.X-20)/620,(view.Y-64)/490))
end
fitWindow()
local header=create("Frame",main,{
    Name="Header",Size=UDim2.new(1,0,0,60),BackgroundTransparency=1,Active=true,
})
local brand=create("Frame",header,{Position=UDim2.fromOffset(16,15),Size=UDim2.fromOffset(33,33),BackgroundColor3=PALETTE.greenDark,BorderSizePixel=0})
corner(brand,9)
textLabel(brand,"R",UDim2.fromScale(0,0),UDim2.fromScale(1,1),{TextSize=20,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center})
textLabel(header,"RUM / Gameplay Scanner",UDim2.fromOffset(60,11),UDim2.new(1,-160,0,25),{Font=Enum.Font.GothamBold,TextSize=19})
textLabel(header,"GAMEPLAY  /  v6.1  /  Debug",UDim2.fromOffset(61,35),UDim2.new(1,-145,0,17),{TextSize=11,TextColor3=PALETTE.muted})
local closeBtn=button(header,"×",UDim2.new(1,-46,0,16),UDim2.fromOffset(30,30),PALETTE.subpanel)
closeBtn.TextSize=20
local scanPanel=create("Frame",main,{Position=UDim2.fromOffset(16,64),Size=UDim2.new(1,-32,0,64),BackgroundColor3=PALETTE.panel,BorderSizePixel=0})
corner(scanPanel,10)
create("UIStroke",scanPanel,{Color=PALETTE.border,Thickness=1})
local summary=textLabel(scanPanel,"Chưa có dữ liệu",UDim2.fromOffset(12,8),UDim2.new(1,-164,0,24),{TextSize=17,TextColor3=PALETTE.green,Font=Enum.Font.GothamBold})
local subtitle=textLabel(scanPanel,"Đang chuẩn bị phiên quét",UDim2.fromOffset(13,34),UDim2.new(1,-164,0,17),{TextSize=11,TextColor3=PALETTE.muted})
local scanBtn=button(scanPanel,"QUÉT GAME",UDim2.new(1,-144,0,12),UDim2.fromOffset(132,40),PALETTE.greenDark)
local historyTab=button(main,"Lịch sử quét",UDim2.fromOffset(16,140),UDim2.fromOffset(132,30),PALETTE.subpanel)
local debugTab=button(main,"Debug  ·  0",UDim2.fromOffset(155,140),UDim2.fromOffset(132,30),PALETTE.panel)
local historyTitle=textLabel(main,"Chọn lần quét để xuất",UDim2.fromOffset(297,140),UDim2.new(1,-313,0,30),{TextColor3=PALETTE.muted,TextXAlignment=Enum.TextXAlignment.Right,TextSize=11})
local function makeList(name)
    local f=create("ScrollingFrame",main,{Name=name,Position=UDim2.fromOffset(16,178),Size=UDim2.new(1,-32,1,-281),BackgroundColor3=PALETTE.panel,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=PALETTE.green,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.fromOffset(0,0),ScrollingDirection=Enum.ScrollingDirection.Y})
    corner(f,9)
    create("UIPadding",f,{PaddingTop=UDim.new(0,7),PaddingBottom=UDim.new(0,7),PaddingLeft=UDim.new(0,7),PaddingRight=UDim.new(0,9)})
    create("UIListLayout",f,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,7)})
    return f
end
local historyFrame=makeList("ScanHistory")
local debugFrame=makeList("DebugLog")
debugFrame.Visible=false
local txtBtn=button(main,"↓  XUẤT TXT",UDim2.new(0,16,1,-94),UDim2.new(.5,-20,0,40),PALETTE.blue)
local jsonBtn=button(main,"↓  XUẤT JSON",UDim2.new(.5,4,1,-94),UDim2.new(.5,-20,0,40),PALETTE.purple)
create("UIStroke",txtBtn,{Color=PALETTE.border,Thickness=1})
create("UIStroke",jsonBtn,{Color=PALETTE.greenDark,Thickness=1})
local status=textLabel(main,"Sẵn sàng",UDim2.new(0,16,1,-48),UDim2.new(1,-32,0,28),{TextColor3=PALETTE.muted,TextSize=11,TextWrapped=true,TextTruncate=Enum.TextTruncate.None})
local track=create("Frame",main,{Position=UDim2.new(0,16,1,-13),Size=UDim2.new(1,-32,0,3),BackgroundColor3=PALETTE.border,BorderSizePixel=0})
corner(track,3)
local progress=create("Frame",track,{Size=UDim2.fromScale(0,1),BackgroundColor3=PALETTE.green,BorderSizePixel=0})
corner(progress,3)
local function setProgress(done,total)
    progress.Size=UDim2.fromScale(total>0 and math.clamp(done/total,0,1) or 0,1)
end

-- Scan history belongs to this execution and retains up to 3 complete snapshots.
-- Keeping a bounded number prevents unlimited memory growth in large games.
local histories={}
local exportMode="full"
local selectedIndex=1
local sequence=0
local busy=false
local closed=false
local connections={}
local activeRecorder=nil
local lastSaved=""
local MAX_HISTORY=3
local HISTORY_RECORD_BUDGET=300000
local function on(signal,callback)
    local conn=signal:Connect(callback)
    connections[#connections+1]=conn
    return conn
end
local logs={}
local debugStarted=os.clock()
local issueCount=0
local debugOpen=false
local logSequence=0
local debugLabels={}
local debugPool={}
local debugScrollPending=false
local function renderDebug()
    if not debugOpen or closed then return end
    local firstIndex=math.max(1,#logs-99)
    local first=logs[firstIndex] and logs[firstIndex].id or logSequence+1
    for id,label in pairs(debugLabels) do
        if id<first then
            label.Visible=false
            debugLabels[id]=nil
            debugPool[#debugPool+1]=label
        end
    end
    for i=firstIndex,#logs do
        local entry=logs[i]
        if not debugLabels[entry.id] then
            local tint=entry.level=="ERROR" and PALETTE.red or entry.level=="WARN" and PALETTE.amber or PALETTE.green
            local label=table.remove(debugPool)
            if not label then
                label=textLabel(debugFrame,"",UDim2.fromOffset(0,0),UDim2.new(1,-5,0,24),{TextSize=12,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,AutomaticSize=Enum.AutomaticSize.Y})
            end
            label.Text=entry.time..("  +%.2fs"):format(entry.elapsed).."  ["..entry.level.."]  "..entry.message
            label.TextColor3=tint
            label.LayoutOrder=entry.id
            label.Visible=true
            debugLabels[entry.id]=label
        end
    end
    if not debugScrollPending then
        debugScrollPending=true
        task.defer(function()
            debugScrollPending=false
            if debugOpen and not closed then debugFrame.CanvasPosition=Vector2.new(0,math.max(0,debugFrame.AbsoluteCanvasSize.Y-debugFrame.AbsoluteWindowSize.Y)) end
        end)
    end
end
local function log(level,message)
    logSequence=logSequence+1
    logs[#logs+1]={id=logSequence,time=os.date("%H:%M:%S"),elapsed=os.clock()-debugStarted,level=level,message=tostring(message):sub(1,3000)}
    if #logs>500 then table.remove(logs,1) end
    if level=="ERROR" or level=="WARN" then issueCount=issueCount+1 end
    debugTab.Text="Debug  ·  "..issueCount
    debugTab.TextColor3=issueCount>0 and PALETTE.amber or PALETTE.text
    renderDebug()
end
local debugExportBtn=button(main,"XUẤT DEBUG",UDim2.fromOffset(449,140),UDim2.fromOffset(155,30),PALETTE.blue)
debugExportBtn.Visible=false
local function selectTab(debugMode)
    debugOpen=debugMode
    historyFrame.Visible=not debugMode
    debugFrame.Visible=debugMode
    historyTab.BackgroundColor3=debugMode and PALETTE.panel or PALETTE.subpanel
    debugTab.BackgroundColor3=debugMode and PALETTE.subpanel or PALETTE.panel
    debugExportBtn.Visible=debugMode
    historyTitle.Size=debugMode and UDim2.fromOffset(145,30) or UDim2.new(1,-313,0,30)
    historyTitle.Text=debugMode and "100 log gần nhất" or "Chọn lần quét để xuất"
    if debugMode then renderDebug() end
end
on(historyTab.MouseButton1Click,function() selectTab(false) end)
on(debugTab.MouseButton1Click,function() selectTab(true) end)
if cam then on(cam:GetPropertyChangedSignal("ViewportSize"),fitWindow) end
local function updateStatus(message,isError)
    if closed then return end
    status.Text=tostring(message)
    status.TextColor3=isError and PALETTE.red or PALETTE.muted
end
-- Scanner diagnostics only. No global game console, input capture or external tool inspection.
local function scannerTrace(err)
    local msg=tostring(err)
    if type(debug)=="table" and type(debug.traceback)=="function" then
        local ok,trace=pcall(debug.traceback,msg,2)
        if ok and type(trace)=="string" then return trace end
    end
    return msg
end
local function formatDebugReport()
    local lines={"RUM SCANNER DEBUG v6.1", "UTC: "..os.date("!%Y-%m-%dT%H:%M:%SZ"),
        ("Retained logs: %d / %d; trimmed: %d"):format(#logs,logSequence,math.max(0,logSequence-#logs)),
        ("State: busy=%s; scans=%d; export=%s; issues=%d"):format(tostring(busy),sequence,exportMode,issueCount),
        "External tools embedded: none; published diagnostic input only.",
        "Review error text for personal identifiers before sharing.",""}
    for _,entry in ipairs(logs) do
        lines[#lines+1]=("%05d %s +%.3fs [%s] %s"):format(entry.id,entry.time,entry.elapsed,entry.level,entry.message:gsub("[%z\1-\8\11-\12\14-\31]","?"))
    end
    lines[#lines+1]="END OF DEBUG"
    return table.concat(lines,"\n").."\n"
end
on(debugExportBtn.MouseButton1Click,function()
    if closed then return end
    if type(writefile)~="function" then log("ERROR","Debug export: file writing unavailable");return end
    local filename=("RUM_DEBUG_%s_%d.txt"):format(os.date("!%Y%m%d_%H%M%S"),math.floor(os.clock()*1000))
    local data=formatDebugReport()
    local ok,err=pcall(function()
        writefile(filename,data)
        if type(readfile)=="function" and readfile(filename)~=data then error("Debug readback mismatch") end
    end)
    if ok then
        log("INFO","Debug file saved: "..filename)
        updateStatus("Debug: "..filename)
    else
        log("ERROR","Debug export: "..tostring(err))
        updateStatus("Không xuất được Debug.",true)
    end
end)
local function cleanup()
    if closed then return end
    closed=true
    if activeRecorder then pcall(activeRecorder.stop) end
    for _,conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    pcall(function() screen:Destroy() end)
    histories={}
    pcall(function()
        if type(getgenv)=="function" and getgenv().RUMScannerOneFileClose==cleanup then
            getgenv().RUMScannerOneFileClose=nil
        end
    end)
end
pcall(function()
    if type(getgenv)=="function" then getgenv().RUMScannerOneFileClose=cleanup end
end)
on(closeBtn.MouseButton1Click,cleanup)

-- Drag via header on PC or phone.
local dragging=false
local dragStart,windowStart,dragInput
on(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true
        dragInput=input
        dragStart=input.Position
        windowStart=main.Position
    end
end)
on(UserInputService.InputChanged,function(input)
    if not dragging or not dragStart then return end
    if input.UserInputType==Enum.UserInputType.MouseMovement or input==dragInput then
        local shift=input.Position-dragStart
        main.Position=UDim2.new(windowStart.X.Scale,windowStart.X.Offset+shift.X,
            windowStart.Y.Scale,windowStart.Y.Offset+shift.Y)
    end
end)
on(UserInputService.InputEnded,function(input)
    if input==dragInput or input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)

local function renderHistory()
    if closed then return end
    for _,obj in ipairs(historyFrame:GetChildren()) do if obj:IsA("GuiObject") then obj:Destroy() end end
    if #histories==0 then
        textLabel(historyFrame,"Chưa có lịch sử. Bấm QUÉT GAME để bắt đầu.",UDim2.fromOffset(0,0),UDim2.new(1,-8,0,50),{TextColor3=PALETTE.muted,TextXAlignment=Enum.TextXAlignment.Center})
        return
    end
    for i,snap in ipairs(histories) do
        local active=i==selectedIndex
        if snap.basicDiagnostics then
            local d=snap.basicDiagnostics
            local item=button(historyFrame,"",UDim2.fromOffset(0,0),UDim2.new(1,-2,0,132),PALETTE.subpanel)
            item.LayoutOrder=i
            create("UIStroke",item,{Color=active and PALETTE.greenDark or PALETTE.border,Thickness=1})
            textLabel(item,(active and "●  " or "○  ")..("Chẩn đoán client #%03d"):format(snap.sequence),UDim2.fromOffset(12,7),UDim2.new(1,-24,0,23),{Font=Enum.Font.GothamBold,TextSize=14,TextColor3=PALETTE.green})
            textLabel(item,snap.timeString,UDim2.fromOffset(12,30),UDim2.new(1,-24,0,18),{TextColor3=PALETTE.muted})
            textLabel(item,("UI cục bộ: %d đối tượng · %d ScreenGui"):format(d.localGuiObjects,d.localScreenGuis),UDim2.fromOffset(12,50),UDim2.new(1,-24,0,20),{})
            textLabel(item,("Nhân vật cục bộ: %d đối tượng"):format(d.localCharacterObjects or 0),UDim2.fromOffset(12,76),UDim2.new(1,-24,0,20),{})
            textLabel(item,"Chế độ cơ bản · Không có bản ghi gameplay",UDim2.fromOffset(12,100),UDim2.new(1,-24,0,20),{TextColor3=PALETTE.muted})
            item.MouseButton1Click:Connect(function()
                if busy or closed then return end
                selectedIndex=i
                summary.Text="Chẩn đoán client"
                subtitle.Text="Không quét gameplay nâng cao"
                renderHistory()
                updateStatus("Đã chọn báo cáo chẩn đoán. Có thể xuất TXT hoặc JSON.")
            end)
        else
        local transitions=snap.observation.transitions or {}
        local expandedHeight=active and (65+math.max(1,#transitions)*23) or 0
        local item=button(historyFrame,"",UDim2.fromOffset(0,0),UDim2.new(1,-2,0,151+expandedHeight),PALETTE.subpanel)
        item.LayoutOrder=i
        create("UIStroke",item,{Color=active and PALETTE.greenDark or PALETTE.border,Thickness=1})
        textLabel(item,(active and "●  " or "○  ")..("Lần quét #%03d"):format(snap.sequence),UDim2.fromOffset(12,7),UDim2.new(.55,-12,0,23),{Font=Enum.Font.GothamBold,TextSize=14,TextColor3=active and PALETTE.green or PALETTE.text})
        textLabel(item,snap.timeString,UDim2.new(.55,0,0,7),UDim2.new(.45,-12,0,23),{TextXAlignment=Enum.TextXAlignment.Right,TextSize=11,TextColor3=PALETTE.muted})
        local d=snap.readDiagnostics or {}
        local warnings=(d.propertyErrors or 0)+(d.conversionErrors or 0)+(d.attributeErrors or 0)+(d.tagErrors or 0)
        textLabel(item,("%d đối tượng  •  %d game  •  %d hệ thống"):format(snap.total,snap.gameCount,snap.total-snap.gameCount),UDim2.fromOffset(12,30),UDim2.new(1,-24,0,20),{TextColor3=PALETTE.muted,TextSize=11})
        local cats=snap.categories
        local labels={{"Remote",cats.Remote},{"Script",cats.Script},{"Module",cats.Module},{"GUI",cats.GUI},{"Value",cats.Value},{"Tương tác",cats.Interaction}}
        for j,entry in ipairs(labels) do
            local chip=create("Frame",item,{Position=UDim2.new((j-1)/6,10-(j-1)*20/6,0,55),Size=UDim2.new(1/6,-8,0,40),BackgroundColor3=PALETTE.panel,BorderSizePixel=0})
            corner(chip,5)
            textLabel(chip,tostring(entry[2]),UDim2.fromOffset(7,2),UDim2.new(1,-10,0,20),{TextSize=14,Font=Enum.Font.GothamBold,TextColor3=PALETTE.text})
            textLabel(chip,entry[1],UDim2.fromOffset(7,21),UDim2.new(1,-10,0,15),{TextSize=10,TextColor3=PALETTE.muted})
        end
        local cls=snap.byClass
        local flag=(snap.errors>0 or warnings>0) and ("Lỗi bản ghi: %d / cảnh báo đọc: %d"):format(snap.errors,warnings) or "Không ghi nhận lỗi đọc"
        textLabel(item,("Model %d · Folder %d · %s"):format(cls.Model or 0,cls.Folder or 0,flag),UDim2.fromOffset(12,101),UDim2.new(1,-24,0,21),{TextSize=10,TextColor3=(snap.errors>0 or warnings>0) and PALETTE.amber or PALETTE.muted})
        local roots=snap.byRoot
        textLabel(item,("Quan sát: %d mẫu · %d thay đổi ghi nhận"):format(#snap.observation.samples,snap.observation.changedAcrossSamples),UDim2.fromOffset(12,122),UDim2.new(1,-24,0,20),{TextSize=10,TextColor3=PALETTE.muted})
        if active then
            local detail=create("Frame",item,{Position=UDim2.fromOffset(10,148),Size=UDim2.new(1,-20,0,expandedHeight-3),BackgroundColor3=PALETTE.panel,BorderSizePixel=0})
            corner(detail,6)
            textLabel(detail,"BIẾN ĐỘNG QUAN SÁT",UDim2.fromOffset(9,4),UDim2.new(1,-18,0,20),{Font=Enum.Font.GothamBold,TextColor3=PALETTE.green,TextSize=11})
            if #transitions==0 then
                textLabel(detail,"Chưa có dữ liệu so sánh",UDim2.fromOffset(9,28),UDim2.new(1,-18,0,20),{TextColor3=PALETTE.muted,TextSize=11})
            end
            for j,t in ipairs(transitions) do
                textLabel(detail,("Mẫu %d → %d   |   %d đổi   ·   %d mới   ·   %d không thấy"):format(t.fromSample,t.toSample,t.changed,t.appeared,t.notObserved),UDim2.fromOffset(9,24+(j-1)*23),UDim2.new(1,-18,0,22),{TextSize=11,TextColor3=PALETTE.text})
            end
            textLabel(detail,("Đối chiếu: %s · Bỏ UI %d · Lỗi %d"):format(snap.integrity.accountingBalanced and "khớp" or "lệch",snap.integrity.excludedScannerUI,snap.integrity.failedRecords),UDim2.fromOffset(9,expandedHeight-40),UDim2.new(1,-18,0,17),{TextSize=10,TextColor3=snap.integrity.accountingBalanced and PALETTE.green or PALETTE.amber})
            textLabel(detail,"Không thấy ≠ đã bị xóa",UDim2.fromOffset(9,expandedHeight-20),UDim2.new(1,-18,0,15),{TextSize=10,TextColor3=PALETTE.muted})
        end
        item.MouseButton1Click:Connect(function()
            if busy or closed then return end
            selectedIndex=i
            summary.Text=("%d đối tượng"):format(snap.total)
            subtitle.Text=("Đang chọn lần #%03d · %d lỗi bản ghi"):format(snap.sequence,snap.errors)
            renderHistory()
            updateStatus("Đã chọn lần #"..snap.sequence..". Xuất TXT hoặc JSON bên dưới.")
        end)
        end
    end
end


-- Ordinary game roots only. Do not survey Roblox internals or other player data.
local rootNames={"Workspace","ReplicatedStorage","ReplicatedFirst","StarterGui","StarterPack","StarterPlayer","Lighting","SoundService","Teams"}
local function collectGameInstances()
    local result,seen,rootErrors,rootStatus,sourceRoot={},{},{},{},{}
    local function add(v,label)
        if not seen[v] then
            seen[v]=true; result[#result+1]=v; sourceRoot[v]=label
        end
    end
    local function visit(root,label)
        add(root,label)
        local ok,items=pcall(function() return root:GetDescendants() end)
        if not ok then
            rootStatus[label]={status="enumeration_error"}
            rootErrors[#rootErrors+1]=safePath(root)..": "..tostring(items)
            return
        end
        rootStatus[label]={status="enumerated",enumeratedIncludingRoot=#items+1}
        for i,v in ipairs(items) do
            if closed then return end
            add(v,label)
            if i%2000==0 then task.wait() end
        end
    end
    for _,name in ipairs(rootNames) do
        local root=game:FindFirstChild(name)
        if root then visit(root,name)
        else rootStatus[name]={status="not_present"} end
    end
    add(Players,"Players")
    rootStatus.Players={status="root_only_except_local_player"}
    visit(LocalPlayer,"LocalPlayer")
    return result,rootErrors,rootStatus,sourceRoot
end

-- Passive local diagnostic sampling. No network capture, input synthesis,
-- remote calls, script source access, or automatic gameplay actions.
local SAMPLE_COUNT=5
local SAMPLE_INTERVAL=3
local QA_TAG="RUM_QA_Observe"
local function qaMode()
    if game:GetService("RunService"):IsStudio() then return "studio" end
    local ok,enabled=pcall(function()
        return game:GetService("ReplicatedStorage"):GetAttribute("RUM_QA_Enabled")
    end)
    return ok and enabled==true and "developer_opt_in" or "basic"
end
local function sameData(a,b)
    if a==b then return true end
    if type(a)~="table" or type(b)~="table" then return false end
    for k,v in pairs(a) do if not sameData(v,rawget(b,k)) then return false end end
    for k in pairs(b) do if rawget(a,k)==nil then return false end end
    return true
end
local function readOne(v,idFor,screenRef,extended,tagged,localRoot,diag)
    if v==screenRef or v:IsDescendantOf(screenRef) then return nil end
    local f,group={},nil
    local function fields(keys)
        for _,key in ipairs(keys) do
            local val=tryProperty(v,key,diag)
            if val~=nil then f[key]=val end
        end
    end
    if v:IsA("ValueBase") then
        local val=v.Value
        if typeof(val)=="number" or typeof(val)=="boolean" or (extended and tagged and typeof(val)=="string") then
            f.Value=encodeValue(val);group="Value"
        end
    elseif v:IsA("Humanoid") then
        fields({"Health","MaxHealth"});group="Humanoid"
        if extended then fields({"Sit","WalkSpeed","JumpPower"}) end
    elseif v:IsA("ScreenGui") then fields({"Enabled"});group="Screen"
    elseif v:IsA("GuiButton") then
        fields({"Visible","Active"});group="Button"
        if extended and tagged and v:IsA("TextButton") then fields({"Text"}) end
    elseif v:IsA("TextLabel") then
        fields({"Visible"});group="TextLabel"
        if extended and tagged then fields({"Text"}) end
    elseif extended and v:IsA("ProximityPrompt") then
        fields({"Enabled","HoldDuration","MaxActivationDistance"});group="Prompt"
        if tagged then fields({"ActionText","ObjectText"}) end
    elseif extended and v:IsA("Tool") then
        fields({"Enabled","RequiresHandle"});group="Tool"
    elseif extended and v:IsA("BasePart") and (tagged or v==localRoot) then
        fields({"Position"});group="Position"
    elseif extended and tagged and v:IsA("GuiObject") then
        fields({"Visible","Active"});group="GUI"
    end
    if extended and tagged and not v:IsA("TextBox") then
        local ok,attrs=pcall(function() return v:GetAttributes() end)
        if ok and type(attrs)=="table" then
            local converted={}
            for k,val in pairs(attrs) do
                local success,out=pcall(encodeValue,val)
                if success and out~=nil then converted[k]=out
                elseif not success then readIssue(diag,"conversionErrors",v,k,out) end
            end
            f.Attributes=converted
            group=group or "TaggedAttributes"
        elseif not ok then readIssue(diag,"attributeErrors",v,"Attributes",attrs) end
    end
    if group and next(f) then return {id=idFor(v),className=v.ClassName,path=safePath(v),state=f,group=group} end
end
local function observeLocal(idFor,mode)
    local extended=mode~="basic"
    local state,errors,skipped={},0,0
    local coverage={Value=0,Humanoid=0,Screen=0,Button=0,TextLabel=0}
    local diag={samples={}}
    local seen,tagged={},{}
    local character=LocalPlayer.Character
    local localRoot=character and character:FindFirstChild("HumanoidRootPart")
    local tagList={}
    if extended then
        local ok,items=pcall(function() return CollectionService:GetTagged(QA_TAG) end)
        if ok then
            for _,v in ipairs(items) do
                -- Only explicit opt-in objects in the local player's subtree or
                -- the developer's replicated shared objects; no other characters.
                local allowed=v:IsDescendantOf(LocalPlayer) or (character and v:IsDescendantOf(character))
                    or v:IsDescendantOf(game:GetService("ReplicatedStorage"))
                if not allowed and v:IsDescendantOf(workspace) then
                    allowed=true
                    local p=v
                    while p and p~=workspace do
                        if p:IsA("Model") then
                            local owner=Players:GetPlayerFromCharacter(p)
                            if owner and owner~=LocalPlayer then allowed=false;break end
                        end
                        p=p.Parent
                    end
                end
                if allowed then tagged[v]=true;tagList[#tagList+1]=v end
            end
        else errors=errors+1 end
    end
    local function read(v)
        if seen[v] then return end
        seen[v]=true
        local ok,entry=pcall(readOne,v,idFor,screen,extended,tagged[v]==true,localRoot,diag)
        if not ok then errors=errors+1;return end
        if not entry then return end
        coverage[entry.group]=(coverage[entry.group] or 0)+1
        state[entry.id]=entry
    end
    local buckets={}
    local stats=LocalPlayer:FindFirstChild("leaderstats")
    if stats then buckets[#buckets+1]=stats end
    if character then buckets[#buckets+1]=character end
    local gui=LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if gui then buckets[#buckets+1]=gui end
    if extended then
        local backpack=LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then buckets[#buckets+1]=backpack end
    end
    for _,root in ipairs(buckets) do
        local ok,items=pcall(function() return root:GetDescendants() end)
        if ok then
            if extended then read(root) end
            for i,v in ipairs(items) do
                if closed then break end
                read(v)
                if i%1000==0 then task.wait() end
            end
        else errors=errors+1 end
    end
    for i,v in ipairs(tagList) do
        if closed then break end
        read(v)
        if i%1000==0 then task.wait() end
    end
    local count=0
    for _ in pairs(state) do count=count+1 end
    return state,errors,skipped,coverage,count,diag,#tagList
end
local function compareState(previous,current)
    local changes,added,missing={},{},{}
    for id,r in pairs(current) do
        local old=previous[id]
        if not old then added[#added+1]=r
        elseif not sameData(old.state,r.state) or old.path~=r.path or old.group~=r.group then
            changes[#changes+1]={id=id,before=old.state,after=r.state,beforePath=old.path,afterPath=r.path,group=r.group}
        end
    end
    for id in pairs(previous) do if not current[id] then missing[#missing+1]=id end end
    return changes,added,missing
end

-- QA evidence index: summarizes existing developer-opted-in observations only.
-- Never infers functionality from names, generates game actions, or treats
-- simultaneous state changes as proof of causation.
local function buildEvidence(observation,pause)
    local out={status="not_enabled",mode=observation.mode,systems={},systemCount=0,
        declaredObjects=0,invalidDeclarations=0,unindexedDeclarations=0,
        conflictingDeclarations=0,observationReadErrors=observation.readErrors or 0,
        limits={maxSystems=64,maxReferencesPerSystem=24},
        scriptReadiness="not_established",rule="Roles are developer declarations, not proven game rules. Changes are observations, not causal evidence. Authorized QA specification and outcome tests are still required."}
    if observation.mode~="studio" and observation.mode~="developer_opt_in" then return out end
    out.status="no_declarations"
    local byId={}
    local validRoles={state=true,condition=true,outcome=true}
    local visited=0
    local function tick()
        visited=visited+1
        if pause and visited%1000==0 then pause() end
    end
    local function declaration(id,state)
        local a=state and state.Attributes
        if type(a)~="table" then return nil,nil end
        return a.RUM_QA_System,a.RUM_QA_Role
    end
    local function register(row,sample)
        tick()
        local key,role=declaration(row.id,row.state)
        if key==nil and role==nil then return end
        if type(key)~="string" or #key<1 or #key>80 or not key:match("^[%w_%-%.]+$") or type(role)~="string" or not validRoles[role] then
            out.invalidDeclarations=out.invalidDeclarations+1;return
        end
        if byId[row.id] then return end
        local group=out.systems[key]
        if not group then
            if out.systemCount>=out.limits.maxSystems then out.unindexedDeclarations=out.unindexedDeclarations+1;return end
            group={roles={state=0,condition=0,outcome=0},observedChanges=0,pathOnlyChanges=0,notObserved=0,
                objects=0,referenceIds={},omittedReferences=0,firstSample=sample,lastSample=sample}
            out.systems[key]=group;out.systemCount=out.systemCount+1
        end
        byId[row.id]={key=key,role=role}
        out.declaredObjects=out.declaredObjects+1
        group.objects=group.objects+1;group.roles[role]=group.roles[role]+1;group.lastSample=sample
        if #group.referenceIds<out.limits.maxReferencesPerSystem then
            group.referenceIds[#group.referenceIds+1]={id=row.id,role=role,sample=sample}
        else group.omittedReferences=group.omittedReferences+1 end
    end
    for _,sample in ipairs(observation.samples or {}) do
        for _,row in ipairs(sample.baseline or {}) do register(row,sample.sample) end
        for _,row in ipairs(sample.added or {}) do register(row,sample.sample) end
        for _,row in ipairs(sample.changes or {}) do
            tick()
            local ref=byId[row.id]
            if ref then
                local group=out.systems[ref.key]
                local key,role=declaration(row.id,row.after)
                if not ref.invalid and (key~=ref.key or role~=ref.role) then
                    out.conflictingDeclarations=out.conflictingDeclarations+1
                    -- Keep original reference but do not attribute later changes.
                    byId[row.id]={key=ref.key,role=ref.role,invalid=true}
                elseif not ref.invalid then
                    if not sameData(row.before,row.after) then group.observedChanges=group.observedChanges+1
                    elseif row.beforePath~=row.afterPath then group.pathOnlyChanges=group.pathOnlyChanges+1 end
                    group.lastSample=sample.sample
                end
            end
        end
        for _,id in ipairs(sample.notObserved or {}) do
            tick()
            local ref=byId[id]
            if ref and not ref.invalid then local g=out.systems[ref.key];g.notObserved=g.notObserved+1 end
        end
    end
    if out.systemCount>0 then out.status="declarations_indexed" end
    for _,g in pairs(out.systems) do
        g.missingRoles={}
        for _,role in ipairs({"state","condition","outcome"}) do
            if g.roles[role]==0 then g.missingRoles[#g.missingRoles+1]=role end
        end
        g.status=#g.missingRoles>0 and "missing_declared_roles" or "declared_roles_present_unverified"
        g.ruleEvidence="not_verified";g.outcomeValidation="not_verified"
    end
    return out
end

-- ANALYSIS (v3.1): structural summaries over data ALREADY collected by the scan
-- (snapshot records + local observation). Reads no new Instances, never requires
-- modules, never reads script source, never calls or hooks remotes.
-- Groupings by location/name are unverified labels, not proof of function.
local function topN(map,limit)
    local list={}
    for k,v in pairs(map) do list[#list+1]={name=k,count=v} end
    table.sort(list,function(a,b)
        if a.count~=b.count then return a.count>b.count end
        return tostring(a.name)<tostring(b.name)
    end)
    while #list>limit do list[#list]=nil end
    return list
end
local function bump(map,key,n)
    if key==nil then return end
    map[key]=(map[key] or 0)+(n or 1)
end
local TOKEN_STOP={the=true,["and"]=true,gui=true,frame=true,label=true,button=true,text=true,folder=true,model=true,part=true}
local function nameTokens(name)
    local out={}
    local spaced=tostring(name):gsub("(%l)(%u)","%1 %2"):gsub("[_%-%.]"," ")
    for w in spaced:gmatch("%a%a%a+") do
        local lw=w:lower()
        if not TOKEN_STOP[lw] then out[#out+1]=lw end
    end
    return out
end
local function keepTop(list,item,score,limit)
    if #list>=limit and score<=list[#list].score then return end
    local pos=#list+1
    while pos>1 and list[pos-1].score<score do pos=pos-1 end
    table.insert(list,pos,{item=item,score=score})
    if #list>limit then list[#list]=nil end
end

-- EVENT TIMELINE (v3.1): passive client-side signals in a bounded window.
-- Listens only to Instances the scan already observes (local player subtree,
-- local character, ReplicatedStorage, direct Workspace children). No remote
-- hooks, no network capture, no input synthesis, no script source.
local EVENT_WINDOW_SECONDS=30
local EVENT_MAX=3000
local EVENT_PER_INSTANCE=60
local EVENT_PER_CLASS=150
local WATCH_MAX=2500
local BUTTON_WATCH_MAX=800
local TOOL_WATCH_MAX=60
local INTERACTION_EXTRA=500
local INTERACTION_KINDS={promptTriggered=true,promptShown=true,buttonActivated=true,toolActivated=true,toolEquipped=true,toolUnequipped=true}
local CORRELATE_SECONDS=3
local UI_LINK_SECONDS=2
local CLUSTER_RADIUS=40
local SPATIAL_MAX_POINTS=6000

local function startEventRecorder(idFor,mode)
    local extended=mode~="basic"
    local startedAt=os.clock()
    local events,conns={}, {}
    local stopped=false
    local perInst,perClass,cappedCount,cappedInfo={}, {}, {}, {}
    local dropped={byTotalLimit=0,perInstanceLimit=0,perClassLimit=0,otherPlayerCharacters=0}
    local watch={property=0,attribute=0,humanoidState=0,containers=0,buttons=0,tools=0,prompts=0,skippedByWatchCap=0}
    local watchTotal=0
    local buttonWatch,toolWatch=0,0
    local initialGui={}
    local last=setmetatable({},{__mode="k"})
    local attached=setmetatable({},{__mode="k"})
    local api={startedAt=startedAt}
    local RS=game:GetService("ReplicatedStorage")

    local function connect(signal,fn)
        local ok,conn=pcall(function() return signal:Connect(fn) end)
        if ok and conn then conns[#conns+1]=conn;return true end
        return false
    end
    local function inScanner(inst) return inst==screen or inst:IsDescendantOf(screen) end
    local function stamp() return math.floor((os.clock()-startedAt)*1000+0.5)/1000 end
    local function safeEncode(v)
        local ok,out=pcall(encodeValue,v)
        if ok then return out end
        return nil
    end
    local function record(kind,inst,field,value,previous,scope)
        if stopped then return end
        pcall(function()
            if inScanner(inst) then return end
            local id=idFor(inst)
            local className=inst.ClassName
            if kind=="added" or kind=="removed" then
                local key=kind.."|"..className
                local c=(perClass[key] or 0)+1
                perClass[key]=c
                if c>EVENT_PER_CLASS then dropped.perClassLimit=dropped.perClassLimit+1;return end
            else
                local n=(perInst[id] or 0)+1
                perInst[id]=n
                if n>EVENT_PER_INSTANCE then
                    dropped.perInstanceLimit=dropped.perInstanceLimit+1
                    cappedCount[id]=(cappedCount[id] or 0)+1
                    if not cappedInfo[id] then cappedInfo[id]={path=safePath(inst),className=className,field=field} end
                    return
                end
            end
            local limit=INTERACTION_KINDS[kind] and (EVENT_MAX+INTERACTION_EXTRA) or EVENT_MAX
            if #events>=limit then dropped.byTotalLimit=dropped.byTotalLimit+1;return end
            events[#events+1]={t=stamp(),kind=kind,id=id,className=className,path=safePath(inst),
                field=field,value=value,previous=previous,scope=scope}
        end)
    end
    local function watchProperty(inst,prop,allowString)
        if watchTotal>=WATCH_MAX then watch.skippedByWatchCap=watch.skippedByWatchCap+1;return end
        local ok,initial=pcall(function() return inst[prop] end)
        if not ok then return end
        last[inst]=last[inst] or {}
        last[inst][prop]=initial
        if (prop=="Enabled" or prop=="Visible") and type(initial)=="boolean" and #initialGui<600
            and (inst:IsA("LayerCollector") or inst:IsA("GuiObject")) then
            initialGui[#initialGui+1]={t=stamp(),id=idFor(inst),path=safePath(inst),className=inst.ClassName,field=prop,value=initial}
        end
        local okSig,signal=pcall(function() return inst:GetPropertyChangedSignal(prop) end)
        if not okSig then return end
        local connected=connect(signal,function()
            if stopped then return end
            local okv,v=pcall(function() return inst[prop] end)
            if not okv then return end
            local prev
            if last[inst] then prev=last[inst][prop] end
            if last[inst] then last[inst][prop]=v end
            local val,pv
            if typeof(v)=="string" and not allowString then val="<string>" else val=safeEncode(v) end
            if typeof(prev)=="string" and not allowString then pv="<string>" else pv=safeEncode(prev) end
            record("property",inst,prop,val,pv)
        end)
        if connected then watchTotal=watchTotal+1;watch.property=watch.property+1 end
    end
    local function watchAttributes(inst,allowString)
        if watchTotal>=WATCH_MAX then watch.skippedByWatchCap=watch.skippedByWatchCap+1;return end
        local okSig,signal=pcall(function() return inst.AttributeChanged end)
        if not okSig or not signal then return end
        local function encodeAttr(v)
            if v==nil then return "<removed>" end
            local t=typeof(v)
            if t=="number" or t=="boolean" then return safeEncode(v) end
            if t=="string" and allowString then return v end
            return "<"..t..">"
        end
        local connected=connect(signal,function(name)
            if stopped then return end
            local okv,v=pcall(function() return inst:GetAttribute(name) end)
            if not okv then return end
            local key="@"..tostring(name)
            last[inst]=last[inst] or {}
            local prev=last[inst][key]
            last[inst][key]=v
            local encodedPrev
            if prev~=nil then encodedPrev=encodeAttr(prev) end
            record("attribute",inst,tostring(name),encodeAttr(v),encodedPrev)
        end)
        if connected then watchTotal=watchTotal+1;watch.attribute=watch.attribute+1 end
    end
    local function attach(inst,tagged)
        if attached[inst] then return end
        attached[inst]=true
        if inScanner(inst) then return end
        if inst:IsA("ValueBase") then
            local ok,val=pcall(function() return inst.Value end)
            local t=ok and typeof(val) or nil
            if t=="number" or t=="boolean" or (extended and tagged and t=="string") then
                watchProperty(inst,"Value",extended and tagged)
            end
        elseif inst:IsA("Humanoid") then
            watchProperty(inst,"Health");watchProperty(inst,"MaxHealth")
            if extended then
                watchProperty(inst,"WalkSpeed");watchProperty(inst,"JumpPower");watchProperty(inst,"Sit")
            end
            if watchTotal<WATCH_MAX then
                local okSig,signal=pcall(function() return inst.StateChanged end)
                if okSig and signal and connect(signal,function(old,new)
                    record("humanoidState",inst,"State",tostring(new),tostring(old))
                end) then watchTotal=watchTotal+1;watch.humanoidState=watch.humanoidState+1 end
            end
            if extended then watchAttributes(inst,false) end
        elseif inst:IsA("ScreenGui") then
            watchProperty(inst,"Enabled")
        elseif inst:IsA("GuiButton") then
            watchProperty(inst,"Visible")
            if buttonWatch<BUTTON_WATCH_MAX then
                local okSig,signal=pcall(function() return inst.Activated end)
                if okSig and signal and connect(signal,function()
                    local label=nil
                    if inst:IsA("TextButton") then
                        local okT,txt=pcall(function() return inst.Text end)
                        if okT and type(txt)=="string" and #txt>0 then label=txt:sub(1,60) end
                    end
                    record("buttonActivated",inst,nil,label)
                end) then buttonWatch=buttonWatch+1;watch.buttons=watch.buttons+1 end
            end
        elseif inst:IsA("Frame") or inst:IsA("ScrollingFrame") or inst:IsA("CanvasGroup") then
            watchProperty(inst,"Visible")
        elseif extended and inst:IsA("ProximityPrompt") then
            watchProperty(inst,"Enabled")
        elseif inst:IsA("Tool") then
            if toolWatch<TOOL_WATCH_MAX then
                local added=false
                for _,sigName in ipairs({"Activated","Equipped","Unequipped"}) do
                    local okSig,signal=pcall(function() return inst[sigName] end)
                    if okSig and signal then
                        local kind=sigName=="Activated" and "toolActivated" or (sigName=="Equipped" and "toolEquipped" or "toolUnequipped")
                        if connect(signal,function() record(kind,inst,nil,nil) end) then added=true end
                    end
                end
                if added then toolWatch=toolWatch+1;watch.tools=watch.tools+1 end
            end
        end
        if extended and tagged and not inst:IsA("Humanoid") then watchAttributes(inst,true) end
    end
    local function watchContainer(root,scope)
        if not root then return end
        if connect(root.DescendantAdded,function(inst)
            if stopped then return end
            record("added",inst,nil,nil,nil,scope)
            pcall(attach,inst,false)
        end) then watch.containers=watch.containers+1 end
        connect(root.DescendantRemoving,function(inst)
            if stopped then return end
            record("removed",inst,nil,nil,nil,scope)
        end)
    end
    local function workspaceChild(inst,kind)
        if stopped then return end
        if inst:IsA("Model") then
            local okO,owner=pcall(function() return Players:GetPlayerFromCharacter(inst) end)
            if okO and owner and owner~=LocalPlayer then
                dropped.otherPlayerCharacters=dropped.otherPlayerCharacters+1
                return
            end
        end
        record(kind,inst,nil,nil,nil,"workspaceChild")
    end
    local function attachCharacter(character,isNew)
        if not character then return end
        if isNew then record("characterAdded",character,nil,nil,nil,"localPlayer") end
        watchContainer(character,"character")
        if extended then watchAttributes(character,false) end
        task.spawn(function()
            local ok,items=pcall(function() return character:GetDescendants() end)
            if not ok then return end
            for i,v in ipairs(items) do
                if stopped then return end
                pcall(attach,v,false)
                if i%500==0 then task.wait() end
            end
        end)
    end
    local function taggedAllowed(v,character)
        if v:IsDescendantOf(LocalPlayer) or (character and v:IsDescendantOf(character)) or v:IsDescendantOf(RS) then
            return true
        end
        if v:IsDescendantOf(workspace) then
            local p=v
            while p and p~=workspace do
                if p:IsA("Model") then
                    local owner=Players:GetPlayerFromCharacter(p)
                    if owner and owner~=LocalPlayer then return false end
                end
                p=p.Parent
            end
            return true
        end
        return false
    end

    -- Listeners first, so nothing during the initial attach pass is missed.
    watchContainer(LocalPlayer,"localPlayer")
    watchContainer(RS,"replicatedStorage")
    if connect(workspace.ChildAdded,function(inst) workspaceChild(inst,"added") end) then watch.containers=watch.containers+1 end
    connect(workspace.ChildRemoved,function(inst) workspaceChild(inst,"removed") end)
    connect(LocalPlayer.CharacterAdded,function(character) attachCharacter(character,true) end)
    do
        local okPPS,pps=pcall(function() return game:GetService("ProximityPromptService") end)
        if okPPS and pps then
            local function promptLabel(prompt)
                local okP,info=pcall(function()
                    return {actionText=prompt.ActionText:sub(1,60),objectText=prompt.ObjectText:sub(1,60)}
                end)
                return okP and info or nil
            end
            if connect(pps.PromptTriggered,function(prompt,player)
                if player==nil or player==LocalPlayer then record("promptTriggered",prompt,nil,promptLabel(prompt)) end
            end) then watch.prompts=watch.prompts+1 end
            connect(pps.PromptShown,function(prompt) record("promptShown",prompt,nil,promptLabel(prompt)) end)
        end
    end
    if extended then watchAttributes(LocalPlayer,false) end
    attachCharacter(LocalPlayer.Character,false)

    task.spawn(function()
        local count=0
        local character=LocalPlayer.Character
        if extended then
            local ok,items=pcall(function() return CollectionService:GetTagged(QA_TAG) end)
            if ok then
                for _,v in ipairs(items) do
                    if stopped then return end
                    local okA,allowed=pcall(taggedAllowed,v,character)
                    if okA and allowed then pcall(attach,v,true) end
                end
            end
        end
        local roots={}
        local stats=LocalPlayer:FindFirstChild("leaderstats")
        if stats then roots[#roots+1]=stats end
        if character then roots[#roots+1]=character end
        local gui=LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if gui then roots[#roots+1]=gui end
        if extended then
            local backpack=LocalPlayer:FindFirstChildOfClass("Backpack")
            if backpack then roots[#roots+1]=backpack end
        end
        roots[#roots+1]=RS
        for _,root in ipairs(roots) do
            local ok,items=pcall(function() return root:GetDescendants() end)
            if ok then
                for _,v in ipairs(items) do
                    if stopped then return end
                    pcall(attach,v,false)
                    count=count+1
                    if count%500==0 then task.wait() end
                end
            end
        end
    end)

    function api.stop()
        if stopped then return end
        stopped=true
        for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns={}
        if activeRecorder==api then activeRecorder=nil end
    end
    function api.finish()
        local elapsed=os.clock()-startedAt
        api.stop()
        local high={}
        for id,count in pairs(cappedCount) do
            local info=cappedInfo[id] or {}
            high[#high+1]={id=id,path=info.path,className=info.className,field=info.field,eventsBeyondCap=count}
        end
        table.sort(high,function(a,b)
            if a.eventsBeyondCap~=b.eventsBeyondCap then return a.eventsBeyondCap>b.eventsBeyondCap end
            return tostring(a.path)<tostring(b.path)
        end)
        while #high>20 do high[#high]=nil end
        return {status="recorded",mode=mode,windowSeconds=EVENT_WINDOW_SECONDS,elapsedSeconds=elapsed,
            count=#events,events=events,initialGuiState=initialGui,dropped=dropped,watched=watch,highFrequencyObjects=high,
            limits={maxEvents=EVENT_MAX,perInstance=EVENT_PER_INSTANCE,perClassAddedRemoved=EVENT_PER_CLASS,maxWatchedConnections=WATCH_MAX},
            note="Local client signals only; capped, so later events can be dropped in busy games. Times are seconds since the window opened. Events close in time are not proof of cause and effect. Only UI captions (button text, prompt action/object text) are recorded for your own interactions; TextBox and label text are never recorded, and other string values appear as <string> unless an object is explicitly QA-tagged. Keyboard and mouse input are not recorded."}
    end
    activeRecorder=api
    return api
end

local function summarizeEvents(tl)
    if type(tl)~="table" or type(tl.events)~="table" then
        return {status=type(tl)=="table" and tl.status or "not_recorded"}
    end
    local byKind,perObj,series,toggles,attrs={}, {}, {}, {}, {}
    local spawned,addedBy,removedBy={}, {}, {}
    local transitions,buckets,maxBucket={}, {}, 0
    for _,e in ipairs(tl.events) do
        bump(byKind,e.kind)
        local b=math.floor((e.t or 0)/5)+1
        buckets[b]=(buckets[b] or 0)+1
        if b>maxBucket then maxBucket=b end
        local o=perObj[e.id]
        if not o then
            o={id=e.id,path=e.path,className=e.className,count=0,kinds={}}
            perObj[e.id]=o
        end
        o.count=o.count+1
        bump(o.kinds,e.kind)
        if e.kind=="property" then
            if type(e.value)=="number" then
                local key=tostring(e.id).."|"..tostring(e.field)
                local sr=series[key]
                if not sr then
                    sr={id=e.id,path=e.path,className=e.className,field=e.field,count=0,min=e.value,max=e.value,
                        first=type(e.previous)=="number" and e.previous or e.value,increases=0,decreases=0,firstT=e.t}
                    series[key]=sr
                end
                sr.count=sr.count+1
                if e.value<sr.min then sr.min=e.value end
                if e.value>sr.max then sr.max=e.value end
                if type(e.previous)=="number" then
                    if e.value>e.previous then sr.increases=sr.increases+1
                    elseif e.value<e.previous then sr.decreases=sr.decreases+1 end
                end
                sr.last=e.value;sr.lastT=e.t
            elseif type(e.value)=="boolean" and (e.field=="Enabled" or e.field=="Visible") then
                local key=tostring(e.id).."|"..e.field
                local tg=toggles[key]
                if not tg then
                    tg={path=e.path,className=e.className,field=e.field,transitions=0}
                    toggles[key]=tg
                end
                tg.transitions=tg.transitions+1
                tg.lastValue=e.value;tg.lastT=e.t
            end
        elseif e.kind=="attribute" then
            bump(attrs,tostring(e.field))
        elseif e.kind=="humanoidState" then
            if #transitions<60 then transitions[#transitions+1]={t=e.t,path=e.path,from=e.previous,to=e.value} end
        elseif e.kind=="added" then
            bump(addedBy,e.className)
            if e.scope=="workspaceChild" then bump(spawned,e.className) end
        elseif e.kind=="removed" then
            bump(removedBy,e.className)
        end
    end
    local function sortedValues(map,limit,cmp)
        local list={}
        for _,v in pairs(map) do list[#list+1]=v end
        table.sort(list,cmp)
        while #list>limit do list[#list]=nil end
        return list
    end
    local busiest=sortedValues(perObj,20,function(a,b)
        if a.count~=b.count then return a.count>b.count end
        return tostring(a.path)<tostring(b.path)
    end)
    local seriesList=sortedValues(series,25,function(a,b)
        if a.count~=b.count then return a.count>b.count end
        return tostring(a.path)<tostring(b.path)
    end)
    for _,sr in ipairs(seriesList) do
        sr.net=(sr.last or sr.first)-sr.first
        if sr.increases>0 and sr.decreases==0 then sr.trend="increasing"
        elseif sr.decreases>0 and sr.increases==0 then sr.trend="decreasing"
        elseif sr.increases>0 and sr.decreases>0 then sr.trend="mixed"
        else sr.trend="flat" end
    end
    local toggleList=sortedValues(toggles,30,function(a,b)
        if a.transitions~=b.transitions then return a.transitions>b.transitions end
        return tostring(a.path)<tostring(b.path)
    end)
    local activity={}
    for i=1,maxBucket do activity[i]=buckets[i] or 0 end
    return {status="summarized",eventCount=#tl.events,byKind=byKind,busiestObjects=busiest,numericSeries=seriesList,
        toggles=toggleList,humanoidStateTransitions=transitions,attributeChanges=topN(attrs,30),
        spawnedByClass=topN(spawned,20),addedByClass=topN(addedBy,20),removedByClass=topN(removedBy,20),
        activityPerFiveSeconds=activity,
        note="trend/net are observations of the recorded window only (property events, not game rules)."}
end

-- SCAN COMPARISON (v3.1): newest scan vs the previous scan of this session.
-- Instance IDs are per-scan, so records are matched by path + class + occurrence
-- order. Same-path duplicates can mismatch. Not-observed-now is NOT deletion
-- (streaming, filtering and read failures can all hide an object).
local COMPARE_LIST_CAP=500
local function compareSnapshots(prev,cur,pause)
    local steps=0
    local function tick()
        steps=steps+1
        if pause and steps%2000==0 then pause() end
    end
    local function recordKey(r,counter)
        local base=r.path.."|"..r.className
        local n=(counter[base] or 0)+1
        counter[base]=n
        return base.."#"..n
    end
    local function diffMap(prefix,a,b,fields)
        if type(b)=="table" then
            for k,v in pairs(b) do
                local before
                if type(a)=="table" then before=a[k] end
                if not sameData(before,v) then
                    fields[prefix.."."..tostring(k)]={before=before==nil and "<absent>" or before,after=v}
                end
            end
        end
        if type(a)=="table" then
            for k,v in pairs(a) do
                if type(b)~="table" or b[k]==nil then
                    fields[prefix.."."..tostring(k)]={before=v,after="<absent>"}
                end
            end
        end
    end
    local NOTABLE={Remote=true,Module=true,Script=true,Interaction=true}
    local oldMap={}
    do
        local counter={}
        for _,r in ipairs(prev.records) do oldMap[recordKey(r,counter)]=r;tick() end
    end
    local seen={}
    local added,changed,notableAdded={}, {}, {}
    local addedCount,changedCount,childCountChanged=0,0,0
    local addedByCategory,addedByRoot,changedByCategory,changedByRoot={}, {}, {}, {}
    local counter={}
    for _,r in ipairs(cur.records) do
        tick()
        local key=recordKey(r,counter)
        local old=oldMap[key]
        if not old then
            addedCount=addedCount+1
            bump(addedByCategory,r.category);bump(addedByRoot,r.root)
            local item={path=r.path,className=r.className,category=r.category,root=r.root}
            if #added<COMPARE_LIST_CAP then added[#added+1]=item end
            if NOTABLE[r.category] and #notableAdded<200 then notableAdded[#notableAdded+1]=item end
        else
            seen[key]=true
            local fields={}
            diffMap("properties",old.properties,r.properties,fields)
            diffMap("attributes",old.attributes,r.attributes,fields)
            if not sameData(old.tags,r.tags) then fields.tags={before=old.tags or "<absent>",after=r.tags or "<absent>"} end
            if next(fields) then
                changedCount=changedCount+1
                bump(changedByCategory,r.category);bump(changedByRoot,r.root)
                if #changed<COMPARE_LIST_CAP then
                    changed[#changed+1]={path=r.path,className=r.className,category=r.category,fields=fields}
                end
            end
            if old.childCount~=r.childCount then childCountChanged=childCountChanged+1 end
        end
    end
    local removedAll={}
    local removedCount=0
    local removedByCategory,removedByRoot={}, {}
    for key,old in pairs(oldMap) do
        tick()
        if not seen[key] then
            removedCount=removedCount+1
            bump(removedByCategory,old.category);bump(removedByRoot,old.root)
            removedAll[#removedAll+1]={path=old.path,className=old.className,category=old.category,root=old.root}
        end
    end
    table.sort(removedAll,function(a,b)
        if a.path~=b.path then return a.path<b.path end
        return a.className<b.className
    end)
    local notObserved,notableNotObserved={}, {}
    for _,item in ipairs(removedAll) do
        if #notObserved<COMPARE_LIST_CAP then notObserved[#notObserved+1]=item end
        if NOTABLE[item.category] and #notableNotObserved<200 then notableNotObserved[#notableNotObserved+1]=item end
    end
    oldMap=nil
    local categoriesDelta={}
    for name,after in pairs(cur.categories or {}) do
        categoriesDelta[name]={before=(prev.categories or {})[name] or 0,after=after,delta=after-((prev.categories or {})[name] or 0)}
    end
    local classDelta={}
    do
        local keys={}
        for name in pairs(cur.byClass or {}) do keys[name]=true end
        for name in pairs(prev.byClass or {}) do keys[name]=true end
        for name in pairs(keys) do
            local b,a=(prev.byClass or {})[name] or 0,(cur.byClass or {})[name] or 0
            if a~=b then classDelta[#classDelta+1]={name=name,before=b,after=a,delta=a-b} end
        end
        table.sort(classDelta,function(x,y)
            local ax,ay=math.abs(x.delta),math.abs(y.delta)
            if ax~=ay then return ax>ay end
            return x.name<y.name
        end)
        while #classDelta>25 do classDelta[#classDelta]=nil end
    end
    return {status="compared",
        comparedWith={sequence=prev.sequence,time=prev.timeString,timestamp=prev.stamp,total=prev.total},
        current={sequence=cur.sequence,time=cur.timeString,total=cur.total},
        streamingWarning=(cur.streamingEnabled==true or prev.streamingEnabled==true) and "StreamingEnabled: absence between scans can reflect distance/streaming, not removal." or nil,
        summary={added=addedCount,notObservedNow=removedCount,changed=changedCount,childCountChanged=childCountChanged,
            addedByCategory=addedByCategory,addedByRoot=addedByRoot,notObservedByCategory=removedByCategory,
            notObservedByRoot=removedByRoot,changedByCategory=changedByCategory,changedByRoot=changedByRoot},
        categoriesDelta=categoriesDelta,classDelta=classDelta,
        added=added,notObservedNow=notObserved,changed=changed,notableAdded=notableAdded,notableNotObserved=notableNotObserved,
        limits={listCap=COMPARE_LIST_CAP,notableCap=200},
        rule="Records are matched by path+class+occurrence order because IDs are per-scan. 'notObservedNow' does not mean deleted. Changed lists only allowlisted properties, attributes and tags; childCount changes are counted but not listed. A difference between two scans is an observation, not proof of what caused it."}
end

-- WORLD POSITIONS (v3.1): positions of interaction points only (prompts, click
-- detectors, spawn locations, NPC humanoids, dropped tools). Never recorded for
-- any player's character; NPC means a Humanoid that no Player owns.
local POSITION_CLASSES={ProximityPrompt=true,ClickDetector=true,SpawnLocation=true,Humanoid=true,Tool=true}
local function worldPositionOf(inst)
    local ok,pos=pcall(function()
        local cur=inst
        for _=1,8 do
            if not cur or cur==workspace then return nil end
            if cur:IsA("BasePart") then return cur.Position end
            if cur:IsA("Attachment") then return cur.WorldPosition end
            if cur:IsA("Model") then return cur:GetPivot().Position end
            if cur:IsA("Tool") then
                local handle=cur:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then return handle.Position end
            end
            cur=cur.Parent
        end
        return nil
    end)
    if ok and typeof(pos)=="Vector3" then return {x=pos.X,y=pos.Y,z=pos.Z} end
    return nil
end
local function roundTo(n,decimals)
    local m=10^(decimals or 0)
    return math.floor(n*m+0.5)/m
end
local function labelOf(v)
    if type(v)=="string" then return v end
    if type(v)=="table" then
        local a,o=v.actionText,v.objectText
        local hasA=type(a)=="string" and #a>0
        local hasO=type(o)=="string" and #o>0
        if hasA and hasO then return a.." / "..o end
        if hasA then return a end
        if hasO then return o end
    end
    return nil
end

-- UI FLOW: which panels toggled, what opened them, and how they stack.
-- Derived only from recorded Enabled/Visible toggles and recorded button/prompt
-- activations. Modal input-blocking is not observable; stacking is a timing hint.
local PANEL_CLASSES={ScreenGui=true,Frame=true,ScrollingFrame=true,CanvasGroup=true}
local INTERACTION_SOURCES={buttonActivated=true,promptTriggered=true}
local function buildUiFlow(tl)
    if type(tl)~="table" or type(tl.events)~="table" then
        return {status=type(tl)=="table" and tl.status or "not_recorded"}
    end
    local function isToggle(e)
        return e.kind=="property" and type(e.value)=="boolean" and (e.field=="Enabled" or e.field=="Visible") and PANEL_CLASSES[e.className]
    end
    local items,toggled,seq={}, {}, 0
    for _,e in ipairs(tl.events) do
        seq=seq+1
        items[#items+1]={e=e,t=e.t or 0,seq=seq,order=1}
        if isToggle(e) then toggled[e.path]=true end
    end
    if next(toggled)==nil then
        return {status="no_gui_toggles_recorded",note="No panel toggled during the window. Open and close menus while the scan records."}
    end
    for _,ini in ipairs(tl.initialGuiState or {}) do
        if PANEL_CLASSES[ini.className] and toggled[ini.path] then
            seq=seq+1
            items[#items+1]={e={kind="initialState",path=ini.path,value=ini.value,t=ini.t or 0},t=ini.t or 0,seq=seq,order=0}
        end
    end
    table.sort(items,function(a,b)
        if a.t~=b.t then return a.t<b.t end
        if a.order~=b.order then return a.order<b.order end
        return a.seq<b.seq
    end)
    local panels,open,openedAt={}, {}, {}
    local edges,transitions,pending={}, {}, {}
    local lastInteraction,lastOpen=nil,nil
    local interactionsTotal,interactionsLinked=0,0
    local function getPanel(e)
        local p=panels[e.path]
        if not p then
            p={path=e.path,className=e.className,field=e.field,opens=0,closes=0,standalone=0,stackedOnTop=0,
                replacedOther=0,durationSum=0,durationCount=0}
            panels[e.path]=p
        end
        return p
    end
    for _,it in ipairs(items) do
        local e=it.e
        if e.kind=="initialState" then
            open[e.path]=e.value
            if e.value then openedAt[e.path]=e.t end
        elseif INTERACTION_SOURCES[e.kind] then
            interactionsTotal=interactionsTotal+1
            lastInteraction={t=e.t or 0,kind=e.kind,path=e.path,label=labelOf(e.value),used=false}
        elseif isToggle(e) then
            local path=e.path
            if e.value==true and open[path]~=true then
                local panel=getPanel(e)
                panel.opens=panel.opens+1
                local others={}
                for other,isOpen in pairs(open) do
                    if isOpen and other~=path then others[#others+1]=other end
                end
                open[path]=true
                openedAt[path]=e.t
                local linked=lastInteraction and ((e.t or 0)-lastInteraction.t)<=UI_LINK_SECONDS
                local edgeKey,source
                if linked then
                    source={kind=lastInteraction.kind,path=lastInteraction.path,label=lastInteraction.label}
                    edgeKey=lastInteraction.kind.."|"..lastInteraction.path.."=>"..path
                    if not lastInteraction.used then
                        lastInteraction.used=true
                        interactionsLinked=interactionsLinked+1
                    end
                else
                    source={kind="none"}
                    edgeKey="none=>"..path
                end
                local edge=edges[edgeKey]
                if not edge then
                    edge={sourceKind=source.kind,sourcePath=source.path,sourceLabel=source.label,panel=path,count=0}
                    edges[edgeKey]=edge
                end
                edge.count=edge.count+1
                if lastOpen and lastOpen.path~=path and ((e.t or 0)-lastOpen.t)<=5 then
                    local key=lastOpen.path.."=>"..path
                    local tr=transitions[key]
                    if not tr then tr={from=lastOpen.path,to=path,count=0,gapSum=0};transitions[key]=tr end
                    tr.count=tr.count+1
                    tr.gapSum=tr.gapSum+((e.t or 0)-lastOpen.t)
                end
                lastOpen={path=path,t=e.t or 0}
                if #others==0 then panel.standalone=panel.standalone+1
                else pending[#pending+1]={panel=panel,others=others,t=e.t or 0,replaced=false} end
            elseif e.value==false and open[path]~=false then
                local panel=getPanel(e)
                panel.closes=panel.closes+1
                if openedAt[path] then
                    panel.durationSum=panel.durationSum+((e.t or 0)-openedAt[path])
                    panel.durationCount=panel.durationCount+1
                end
                open[path]=false
                openedAt[path]=nil
                for _,pd in ipairs(pending) do
                    if not pd.replaced and ((e.t or 0)-pd.t)<=1 then
                        for _,o in ipairs(pd.others) do
                            if o==path then pd.replaced=true;break end
                        end
                    end
                end
            end
        end
    end
    for _,pd in ipairs(pending) do
        if pd.replaced then pd.panel.replacedOther=pd.panel.replacedOther+1
        else pd.panel.stackedOnTop=pd.panel.stackedOnTop+1 end
    end
    local panelList={}
    for _,p in pairs(panels) do panelList[#panelList+1]=p end
    table.sort(panelList,function(a,b)
        if a.opens~=b.opens then return a.opens>b.opens end
        return a.path<b.path
    end)
    local panelCount=#panelList
    local out={}
    for i=1,math.min(40,panelCount) do
        local p=panelList[i]
        local behavior="unknown"
        if p.stackedOnTop>p.replacedOther then behavior="overlay_on_other_panel"
        elseif p.replacedOther>0 then behavior="replaces_other_panel"
        elseif p.standalone>0 then behavior="standalone" end
        local parentPanel
        if panelCount<=300 then
            for _,o in ipairs(panelList) do
                if o.path~=p.path and p.path:sub(1,#o.path+1)==o.path.."." and (not parentPanel or #o.path>#parentPanel) then
                    parentPanel=o.path
                end
            end
        end
        out[i]={path=p.path,className=p.className,field=p.field,opens=p.opens,closes=p.closes,
            avgOpenSeconds=p.durationCount>0 and roundTo(p.durationSum/p.durationCount,2) or nil,
            standalone=p.standalone,stackedOnTop=p.stackedOnTop,replacedOther=p.replacedOther,
            behavior=behavior,parentPanel=parentPanel}
    end
    local edgeList={}
    for _,e in pairs(edges) do edgeList[#edgeList+1]=e end
    table.sort(edgeList,function(a,b)
        if a.count~=b.count then return a.count>b.count end
        return a.panel<b.panel
    end)
    while #edgeList>40 do edgeList[#edgeList]=nil end
    local trList={}
    for _,t in pairs(transitions) do
        trList[#trList+1]={from=t.from,to=t.to,count=t.count,avgGapSeconds=roundTo(t.gapSum/t.count,2)}
    end
    table.sort(trList,function(a,b)
        if a.count~=b.count then return a.count>b.count end
        return a.from<b.from
    end)
    while #trList>30 do trList[#trList]=nil end
    return {status="mapped",linkWindowSeconds=UI_LINK_SECONDS,stackWindowSeconds=1,panelCount=panelCount,
        panels=out,edges=edgeList,transitions=trList,interactionCount=interactionsTotal,
        unlinkedInteractions=interactionsTotal-interactionsLinked,
        note="Observed in the recording window only; only panels that toggled appear. 'edges' pair an activation with a panel opening within the link window (timing, not proof). Stacking vs replacing is inferred from toggle timing; input-blocking modality is not observable."}
end

-- INTERACTION <-> STATE LINKS: own prompt triggers / button / tool activations
-- followed by state events within CORRELATE_SECONDS. Timing only, never proof.
local STATE_KINDS={property=true,attribute=true,added=true,removed=true,humanoidState=true}
local ACTION_KINDS={promptTriggered=true,buttonActivated=true,toolActivated=true}
local function buildInteractionAnalysis(tl)
    if type(tl)~="table" or type(tl.events)~="table" then
        return {status=type(tl)=="table" and tl.status or "not_recorded"}
    end
    local events=tl.events
    local n=#events
    local function keyOf(e) return e.kind.."|"..tostring(e.path).."|"..tostring(e.field) end
    local keyTotals,kindCounts={}, {}
    for _,e in ipairs(events) do
        if STATE_KINDS[e.kind] then bump(keyTotals,keyOf(e)) end
        if ACTION_KINDS[e.kind] or e.kind=="promptShown" then bump(kindCounts,e.kind) end
    end
    local sources,detail,interactionCount={}, {}, 0
    for i,e in ipairs(events) do
        if ACTION_KINDS[e.kind] then
            interactionCount=interactionCount+1
            local label=labelOf(e.value)
            local srcKey=e.kind.."|"..tostring(e.path)
            local src=sources[srcKey]
            if not src then
                src={kind=e.kind,path=e.path,label=label,activations=0,followers={}}
                sources[srcKey]=src
            end
            src.activations=src.activations+1
            if label and not src.label then src.label=label end
            local seen,follows={}, {}
            for j=i+1,n do
                local f=events[j]
                if ((f.t or 0)-(e.t or 0))>CORRELATE_SECONDS then break end
                if STATE_KINDS[f.kind] then
                    local fk=keyOf(f)
                    if not seen[fk] then
                        seen[fk]=true
                        local fl=src.followers[fk]
                        if not fl then
                            fl={kind=f.kind,path=f.path,field=f.field,followedInActivations=0,deltaSum=0,deltaCount=0}
                            src.followers[fk]=fl
                        end
                        fl.followedInActivations=fl.followedInActivations+1
                        if f.kind=="property" and type(f.value)=="number" and type(f.previous)=="number" then
                            fl.deltaSum=fl.deltaSum+(f.value-f.previous)
                            fl.deltaCount=fl.deltaCount+1
                        end
                    end
                    if #follows<8 then
                        follows[#follows+1]={dt=roundTo((f.t or 0)-(e.t or 0),3),kind=f.kind,path=f.path,field=f.field,value=f.value,previous=f.previous}
                    end
                end
            end
            if #detail<60 then detail[#detail+1]={t=e.t,kind=e.kind,path=e.path,label=label,followedBy=follows} end
        end
    end
    local sourceList={}
    for _,src in pairs(sources) do
        local list={}
        for fk,fl in pairs(src.followers) do
            fl.ofActivations=src.activations
            local total=keyTotals[fk] or fl.followedInActivations
            fl.keyTotalEvents=total
            fl.specificity=roundTo(math.min(1,fl.followedInActivations/math.max(1,total)),2)
            if fl.deltaCount>0 then fl.avgDelta=roundTo(fl.deltaSum/fl.deltaCount,3) end
            fl.deltaSum=nil;fl.deltaCount=nil
            list[#list+1]=fl
        end
        table.sort(list,function(a,b)
            if a.followedInActivations~=b.followedInActivations then return a.followedInActivations>b.followedInActivations end
            if a.specificity~=b.specificity then return a.specificity>b.specificity end
            return tostring(a.path)<tostring(b.path)
        end)
        while #list>6 do list[#list]=nil end
        src.followers=list
        sourceList[#sourceList+1]=src
    end
    table.sort(sourceList,function(a,b)
        if a.activations~=b.activations then return a.activations>b.activations end
        return tostring(a.path)<tostring(b.path)
    end)
    while #sourceList>30 do sourceList[#sourceList]=nil end
    return {status=interactionCount>0 and "linked" or "no_interactions_recorded",windowSeconds=CORRELATE_SECONDS,
        interactionCount=interactionCount,byKind=kindCounts,bySource=sourceList,interactions=detail,
        note="Interact with the game while the scan records. 'followers' are state events that happened within the window after an activation. specificity near 1 means that event rarely happened otherwise; near 0 means it is background activity. Timing only, not proof of cause."}
end

-- SPATIAL MAP: distance clusters of interaction points (3D, grid + union-find).
local function buildSpatial(records,tick)
    local points,byKind,truncated={}, {}, false
    for _,r in ipairs(records) do
        tick()
        local wp=r.worldPosition
        if wp then
            local c,kind=r.className,nil
            if c=="ProximityPrompt" then kind="prompt"
            elseif c=="ClickDetector" then kind="clickDetector"
            elseif c=="SpawnLocation" then kind="spawn"
            elseif c=="Humanoid" and r.npc then kind="npc"
            elseif c=="Tool" then kind="tool" end
            if kind then
                if #points>=SPATIAL_MAX_POINTS then truncated=true
                else
                    local props=r.properties or {}
                    points[#points+1]={kind=kind,path=r.path,x=wp.x,y=wp.y,z=wp.z,actionText=props.ActionText,objectText=props.ObjectText}
                    bump(byKind,kind)
                end
            end
        end
    end
    if #points==0 then
        return {status="no_positioned_objects",note="No prompts, click detectors, spawns, NPCs or dropped tools with a readable position were found (StreamingEnabled hides far objects)."}
    end
    local R=CLUSTER_RADIUS
    local parent={}
    for i=1,#points do parent[i]=i end
    local function find(i)
        while parent[i]~=i do parent[i]=parent[parent[i]];i=parent[i] end
        return i
    end
    local grid={}
    for i,p in ipairs(points) do
        p.cx,p.cy,p.cz=math.floor(p.x/R),math.floor(p.y/R),math.floor(p.z/R)
        local key=p.cx..","..p.cy..","..p.cz
        local list=grid[key]
        if not list then list={};grid[key]=list end
        list[#list+1]=i
    end
    local R2=R*R
    for i,p in ipairs(points) do
        tick()
        for dx=-1,1 do for dy=-1,1 do for dz=-1,1 do
            local list=grid[(p.cx+dx)..","..(p.cy+dy)..","..(p.cz+dz)]
            if list then
                for _,j in ipairs(list) do
                    if j>i then
                        local q=points[j]
                        local ex,ey,ez=p.x-q.x,p.y-q.y,p.z-q.z
                        if ex*ex+ey*ey+ez*ez<=R2 then
                            local a,b=find(i),find(j)
                            if a~=b then parent[b]=a end
                        end
                    end
                end
            end
        end end end
    end
    local groups={}
    for i=1,#points do
        local root=find(i)
        local g=groups[root]
        if not g then g={members={}};groups[root]=g end
        g.members[#g.members+1]=i
    end
    local clusters,isolated={}, 0
    for _,g in pairs(groups) do
        if #g.members==1 then isolated=isolated+1
        else
            local sx,sy,sz=0,0,0
            local kinds,samples,texts,seenText={}, {}, {}, {}
            for _,idx in ipairs(g.members) do
                local p=points[idx]
                sx=sx+p.x;sy=sy+p.y;sz=sz+p.z
                bump(kinds,p.kind)
                if #samples<4 then samples[#samples+1]=p.path end
                local text=labelOf({actionText=p.actionText,objectText=p.objectText})
                if text and not seenText[text] and #texts<6 then seenText[text]=true;texts[#texts+1]=text end
            end
            local count=#g.members
            local cx,cy,cz=sx/count,sy/count,sz/count
            local radius=0
            for _,idx in ipairs(g.members) do
                local p=points[idx]
                local d=math.sqrt((p.x-cx)^2+(p.y-cy)^2+(p.z-cz)^2)
                if d>radius then radius=d end
            end
            clusters[#clusters+1]={count=count,center={x=roundTo(cx,1),y=roundTo(cy,1),z=roundTo(cz,1)},
                radius=roundTo(radius,1),byKind=kinds,samples=samples,actionTexts=texts}
        end
    end
    table.sort(clusters,function(a,b)
        if a.count~=b.count then return a.count>b.count end
        if a.center.x~=b.center.x then return a.center.x<b.center.x end
        return a.center.z<b.center.z
    end)
    local clusterCount=#clusters
    while #clusters>30 do clusters[#clusters]=nil end
    for i,c in ipairs(clusters) do c.id="C"..i end
    local spawns,npcs={}, {}
    local minX,minY,minZ,maxX,maxY,maxZ=math.huge,math.huge,math.huge,-math.huge,-math.huge,-math.huge
    for _,p in ipairs(points) do
        if p.x<minX then minX=p.x end if p.x>maxX then maxX=p.x end
        if p.y<minY then minY=p.y end if p.y>maxY then maxY=p.y end
        if p.z<minZ then minZ=p.z end if p.z>maxZ then maxZ=p.z end
        if p.kind=="spawn" and #spawns<30 then spawns[#spawns+1]={path=p.path,x=roundTo(p.x,1),y=roundTo(p.y,1),z=roundTo(p.z,1)} end
        if p.kind=="npc" and #npcs<60 then npcs[#npcs+1]={path=p.path,x=roundTo(p.x,1),y=roundTo(p.y,1),z=roundTo(p.z,1)} end
    end
    return {status="clustered",radiusStuds=R,pointCount=#points,pointsTruncated=truncated,byKind=byKind,
        clusterCount=clusterCount,isolatedPoints=isolated,clusters=clusters,spawnLocations=spawns,npcs=npcs,
        bounds={min={x=roundTo(minX,1),y=roundTo(minY,1),z=roundTo(minZ,1)},max={x=roundTo(maxX,1),y=roundTo(maxY,1),z=roundTo(maxZ,1)}},
        note="Only client-visible objects with a readable position; with StreamingEnabled far areas are missing. No player positions are included. Clusters are distance groups, not designed zones."}
end

-- MULTI-SCAN STABILITY: merge up to the retained scans (newest first).
local function diffMapInto(prefix,a,b,fields)
    if type(b)=="table" then
        for k,v in pairs(b) do
            local before
                if type(a)=="table" then before=a[k] end
            if not sameData(before,v) then fields[prefix.."."..tostring(k)]={before=before==nil and "<absent>" or before,after=v} end
        end
    end
    if type(a)=="table" then
        for k,v in pairs(a) do
            if type(b)~="table" or b[k]==nil then fields[prefix.."."..tostring(k)]={before=v,after="<absent>"} end
        end
    end
end
local STABILITY_MAX_RECORDS=450000
local function computeStability(snapshots,pause)
    local ordered={}
    for i=#snapshots,1,-1 do ordered[#ordered+1]=snapshots[i] end
    local scans=#ordered
    local seqs={}
    local totalRecords=0
    for i,sn in ipairs(ordered) do seqs[i]=sn.sequence;totalRecords=totalRecords+sn.total end
    if scans<2 then
        return {status="needs_two_scans",scansUsed=seqs,note="Scan at least twice in one session to merge scans."}
    end
    if totalRecords>STABILITY_MAX_RECORDS then
        return {status="skipped_too_large",scansUsed=seqs,totalRecords=totalRecords,limit=STABILITY_MAX_RECORDS}
    end
    local steps=0
    local function tick()
        steps=steps+1
        if pause and steps%2000==0 then pause() end
    end
    local map,keyed={}, 0
    for si,sn in ipairs(ordered) do
        local counter={}
        for _,r in ipairs(sn.records) do
            tick()
            local base=r.path.."|"..r.className
            local n=(counter[base] or 0)+1
            counter[base]=n
            local key=base.."#"..n
            local e=map[key]
            if not e then
                e={path=r.path,className=r.className,category=r.category,count=0,mask=0,changeScans=0,fieldChanges={},first={},lastv={}}
                map[key]=e
                keyed=keyed+1
            end
            e.count=e.count+1
            e.mask=e.mask+2^(si-1)
            if e.last then
                local fields={}
                diffMapInto("properties",e.last.properties,r.properties,fields)
                diffMapInto("attributes",e.last.attributes,r.attributes,fields)
                if not sameData(e.last.tags,r.tags) then fields.tags={before=e.last.tags or "<absent>",after=r.tags or "<absent>"} end
                if next(fields) then
                    e.changeScans=e.changeScans+1
                    for name,change in pairs(fields) do
                        e.fieldChanges[name]=(e.fieldChanges[name] or 0)+1
                        if e.first[name]==nil then e.first[name]=change.before end
                        e.lastv[name]=change.after
                    end
                end
            end
            e.last=r
        end
    end
    local stable,transientCount,changedOnce,changedRepeatedly=0,0,0,0
    local kinds={appearedInLatest=0,notObservedInLatest=0,intermittent=0}
    local transientByCategory,changedByCategory={}, {}
    local transientList,changedList={}, {}
    local newestBit=2^(scans-1)
    for _,e in pairs(map) do
        tick()
        if e.count==scans then
            stable=stable+1
            if e.changeScans>0 then
                if e.changeScans==1 then changedOnce=changedOnce+1 else changedRepeatedly=changedRepeatedly+1 end
                bump(changedByCategory,e.category)
                changedList[#changedList+1]=e
            end
        else
            transientCount=transientCount+1
            bump(transientByCategory,e.category)
            local inNewest=(math.floor(e.mask/newestBit)%2)==1
            local inOldest=(e.mask%2)==1
            local kind
            if inNewest and not inOldest and e.count==1 then kind="appearedInLatest";kinds.appearedInLatest=kinds.appearedInLatest+1
            elseif inOldest and not inNewest and e.count==1 then kind="notObservedInLatest";kinds.notObservedInLatest=kinds.notObservedInLatest+1
            else kind="intermittent";kinds.intermittent=kinds.intermittent+1 end
            e.transientKind=kind
            transientList[#transientList+1]=e
        end
    end
    table.sort(transientList,function(a,b)
        if a.path~=b.path then return a.path<b.path end
        return a.className<b.className
    end)
    local transientOut={}
    for i=1,math.min(300,#transientList) do
        local e=transientList[i]
        local presentIn={}
        for si=1,scans do
            if (math.floor(e.mask/2^(si-1))%2)==1 then presentIn[#presentIn+1]=seqs[si] end
        end
        transientOut[i]={path=e.path,className=e.className,category=e.category,kind=e.transientKind,presentIn=presentIn}
    end
    table.sort(changedList,function(a,b)
        if a.changeScans~=b.changeScans then return a.changeScans>b.changeScans end
        return a.path<b.path
    end)
    local changedOut={}
    for i=1,math.min(100,#changedList) do
        local e=changedList[i]
        local fields,fc={}, 0
        for name,count in pairs(e.fieldChanges) do
            if fc<8 then fc=fc+1;fields[name]={changes=count,first=e.first[name],last=e.lastv[name]} end
        end
        changedOut[i]={path=e.path,className=e.className,category=e.category,changedInScans=e.changeScans,fields=fields}
    end
    map=nil
    return {status="computed",scansUsed=seqs,objectsKeyed=keyed,stableObjects=stable,transientCount=transientCount,
        transientKinds=kinds,changedOnce=changedOnce,changedRepeatedly=changedRepeatedly,
        transientByCategory=transientByCategory,changedByCategory=changedByCategory,
        transientObjects=transientOut,repeatedlyChanging=changedOut,
        limits={transientList=300,changingList=100,maxRecords=STABILITY_MAX_RECORDS},
        note="Objects are keyed by path+class+occurrence order, so same-path duplicates can mismatch. 'transient' = not present in every retained scan (streaming, distance, spawning or short life); not proof of removal. 'changedRepeatedly' = allowlisted properties/attributes/tags differed in two or more scan intervals; use it to separate live state from static structure."}
end

local function buildAnalysis(snap,pause)
    local records=snap.records
    local steps=0
    local function tick()
        steps=steps+1
        if pause and steps%2000==0 then pause() end
    end
    local byId={}
    for _,r in ipairs(records) do byId[r.instanceId]=r;tick() end
    local function parentPath(r)
        local p=byId[r.parentId]
        if p then return p.path end
        return r.parentId=="ROOT" and "game" or "<outside_snapshot>"
    end
    local function screenOf(r)
        local cur,guard=r,0
        while cur and guard<60 do
            if cur.className=="ScreenGui" then return cur end
            cur=byId[cur.parentId];guard=guard+1
        end
        return nil
    end

    -- Explorer + modules + gameplay inventory share one pass over the records.
    local rootInfo,largest,deepest,maxDepth={}, {}, {}, 0
    local containerStats={}
    local function cstat(r)
        local key=parentPath(r)
        local c=containerStats[key]
        if not c then
            c={path=key,modules=0,scripts=0,remotes=0,values=0,gui=0,interaction=0,total=0}
            containerStats[key]=c
        end
        return c
    end
    local mod={count=0,byRoot={},maxDepth=0,names={},tokens={},tokenSamples={},tagged={},nested={},nestedCount=0}
    local gp={remoteCount=0,remoteByClass={},remoteContainers={},remoteList={},
        promptCount=0,prompts={},clickDetectors=0,spawns=0,humanoidCount=0,toolCount=0,tools={},
        valueCount=0,valueByClass={},valueContainers={},leaderstatsValues=0,
        tags={},attrKeys={},screenInfo={},buttons={},
        tokens={Remote={},Value={},Tool={},Prompt={}}}
    for _,r in ipairs(records) do
        tick()
        local cls,cat,props=r.className,r.category,r.properties or {}
        local depth=r.depth or 0
        local kids=r.childCount or 0
        -- explorer
        local info=rootInfo[r.root]
        if not info then
            info={objects=0,maxDepth=0,containers=0,classCounts={}}
            rootInfo[r.root]=info
        end
        info.objects=info.objects+1
        if depth>info.maxDepth then info.maxDepth=depth end
        if depth>maxDepth then maxDepth=depth end
        if kids>0 then info.containers=info.containers+1 end
        bump(info.classCounts,cls)
        if kids>=20 then keepTop(largest,r,kids,15) end
        keepTop(deepest,r,depth,10)
        -- container tallies (direct children only)
        local cs=cstat(r)
        cs.total=cs.total+1
        if cat=="Module" then cs.modules=cs.modules+1
        elseif cat=="Script" then cs.scripts=cs.scripts+1
        elseif cat=="Remote" then cs.remotes=cs.remotes+1
        elseif cat=="Value" then cs.values=cs.values+1
        elseif cat=="GUI" then cs.gui=cs.gui+1
        elseif cat=="Interaction" then cs.interaction=cs.interaction+1 end
        -- tags / attribute keys (conventions)
        if r.tags then for _,t in ipairs(r.tags) do bump(gp.tags,t) end end
        if r.attributes then for k in pairs(r.attributes) do bump(gp.attrKeys,k) end end
        -- modules
        if cat=="Module" then
            mod.count=mod.count+1
            bump(mod.byRoot,r.root)
            if depth>mod.maxDepth then mod.maxDepth=depth end
            bump(mod.names,r.name)
            local tk=nameTokens(r.name)[1]
            if tk then
                bump(mod.tokens,tk)
                local s=mod.tokenSamples[tk]
                if not s then s={};mod.tokenSamples[tk]=s end
                if #s<3 then s[#s+1]=r.path end
            end
            local parentRec=byId[r.parentId]
            if parentRec and parentRec.className=="ModuleScript" then
                mod.nestedCount=mod.nestedCount+1
                if #mod.nested<20 then mod.nested[#mod.nested+1]={path=r.path,parentPath=parentRec.path} end
            end
            if (r.tags or r.attributes) and #mod.tagged<30 then
                local keys={}
                for k in pairs(r.attributes or {}) do keys[#keys+1]=k end
                table.sort(keys)
                mod.tagged[#mod.tagged+1]={path=r.path,tags=r.tags,attributeKeys=keys}
            end
        end
        -- gameplay inventory
        if cat=="Remote" then
            gp.remoteCount=gp.remoteCount+1
            bump(gp.remoteByClass,cls)
            local pp=parentPath(r)
            local c=gp.remoteContainers[pp]
            if not c then c={path=pp,count=0,classes={}};gp.remoteContainers[pp]=c end
            c.count=c.count+1;bump(c.classes,cls)
            if #gp.remoteList<300 then gp.remoteList[#gp.remoteList+1]={path=r.path,className=cls} end
            for _,tk in ipairs(nameTokens(r.name)) do bump(gp.tokens.Remote,tk) end
        elseif cls=="ProximityPrompt" then
            gp.promptCount=gp.promptCount+1
            if #gp.prompts<150 then
                gp.prompts[#gp.prompts+1]={path=r.path,enabled=props.Enabled,actionText=props.ActionText,
                    objectText=props.ObjectText,holdDuration=props.HoldDuration,maxDistance=props.MaxActivationDistance}
            end
            if type(props.ActionText)=="string" then for _,tk in ipairs(nameTokens(props.ActionText)) do bump(gp.tokens.Prompt,tk) end end
        elseif cls=="ClickDetector" then gp.clickDetectors=gp.clickDetectors+1
        elseif cls=="SpawnLocation" then gp.spawns=gp.spawns+1
        elseif cls=="Humanoid" then gp.humanoidCount=gp.humanoidCount+1
        elseif cls=="Tool" then
            gp.toolCount=gp.toolCount+1
            if #gp.tools<60 then gp.tools[#gp.tools+1]={path=r.path,toolTip=props.ToolTip,enabled=props.Enabled} end
            for _,tk in ipairs(nameTokens(r.name)) do bump(gp.tokens.Tool,tk) end
        elseif cat=="Value" then
            gp.valueCount=gp.valueCount+1
            bump(gp.valueByClass,cls)
            local pp=parentPath(r)
            local c=gp.valueContainers[pp]
            if not c then c={path=pp,count=0};gp.valueContainers[pp]=c end
            c.count=c.count+1
            if r.path:find("leaderstats",1,true) then gp.leaderstatsValues=gp.leaderstatsValues+1 end
            for _,tk in ipairs(nameTokens(r.name)) do bump(gp.tokens.Value,tk) end
        elseif cat=="GUI" then
            local sg=screenOf(r)
            if sg then
                local s=gp.screenInfo[sg.instanceId]
                if not s then
                    s={path=sg.path,enabled=(sg.properties or {}).Enabled,objects=0,buttons=0,labels=0,textBoxes=0}
                    gp.screenInfo[sg.instanceId]=s
                end
                s.objects=s.objects+1
                if cls=="TextButton" or cls=="ImageButton" then s.buttons=s.buttons+1
                elseif cls=="TextLabel" then s.labels=s.labels+1
                elseif cls=="TextBox" then s.textBoxes=s.textBoxes+1 end
            end
            -- Button captions only; labels and text boxes may hold player-entered text.
            if cls=="TextButton" and type(props.Text)=="string" and #props.Text>0 and #gp.buttons<150 then
                gp.buttons[#gp.buttons+1]={path=r.path,text=props.Text:sub(1,80),visible=props.Visible}
            end
        end
    end

    local A={schema="RUM_ANALYSIS_V1",status="complete",
        rule="Structural summaries of client-visible metadata. No script source, no require, no remote calls or hooks. Location/name groupings are unverified labels, not proven function or causation.",
        limits={largestContainers=15,deepestObjects=10,remotes=300,prompts=150,tools=60,buttons=150,moduleTagged=30}}

    -- 1. Explorer (Dex-style structure)
    local rootsOut={}
    for name,info in pairs(rootInfo) do
        rootsOut[name]={objects=info.objects,maxDepth=info.maxDepth,containers=info.containers,topClasses=topN(info.classCounts,8)}
    end
    local largestOut,deepestOut={}, {}
    for _,e in ipairs(largest) do largestOut[#largestOut+1]={path=e.item.path,className=e.item.className,root=e.item.root,childCount=e.score} end
    for _,e in ipairs(deepest) do deepestOut[#deepestOut+1]={path=e.item.path,className=e.item.className,depth=e.score} end
    A.explorer={maxDepth=maxDepth,roots=rootsOut,largestContainers=largestOut,deepestObjects=deepestOut,
        note="Per-record parentId, depth, childCount, allowlisted properties, attributes and tags are in the records array."}

    -- 2. Module analyzer
    local dupNames={}
    for name,count in pairs(mod.names) do if count>1 then dupNames[name]=count end end
    local nameGroups={}
    for _,e in ipairs(topN(mod.tokens,40)) do
        if e.count>=2 and #nameGroups<20 then
            nameGroups[#nameGroups+1]={name=e.name,count=e.count,samples=mod.tokenSamples[e.name]}
        end
    end
    local moduleContainers={}
    do
        local list={}
        for _,c in pairs(containerStats) do if c.modules>0 then list[#list+1]=c end end
        table.sort(list,function(a,b)
            if a.modules~=b.modules then return a.modules>b.modules end
            return a.path<b.path
        end)
        for i=1,math.min(25,#list) do
            local c=list[i]
            moduleContainers[i]={path=c.path,modules=c.modules,scripts=c.scripts,remotes=c.remotes,values=c.values}
        end
    end
    A.modules={count=mod.count,byRoot=mod.byRoot,maxDepth=mod.maxDepth,
        nestedUnderModuleCount=mod.nestedCount,nestedUnderModule=mod.nested,
        moduleContainers=moduleContainers,nameGroups=nameGroups,duplicateNames=topN(dupNames,20),
        taggedModules=mod.tagged,
        note="Layout only. Module contents, exports and require() relationships are not read; nameGroups use the first word of the name and are unverified."}

    -- 3. Runtime inspector (from the existing local observation)
    local obs=snap.observation or {}
    local sampleList=obs.samples or {}
    local meta,stats={}, {}
    local groupObserved,groupAppeared,groupChanged={}, {}, {}
    local leader,humanoids={}, {}
    local baselineObjects,appeared,notObservedEvents=0,0,0
    for _,sample in ipairs(sampleList) do
        for _,row in ipairs(sample.baseline or {}) do
            tick()
            baselineObjects=baselineObjects+1
            meta[row.id]={className=row.className,path=row.path,group=row.group}
            bump(groupObserved,row.group)
            local st=row.state or {}
            if row.group=="Value" and type(row.path)=="string" and row.path:find("leaderstats",1,true) and #leader<60 then
                leader[#leader+1]={path=row.path,className=row.className,value=st.Value}
            elseif row.group=="Humanoid" and #humanoids<10 then
                humanoids[#humanoids+1]={path=row.path,state=st}
            end
        end
        for _,row in ipairs(sample.added or {}) do
            tick()
            appeared=appeared+1
            meta[row.id]=meta[row.id] or {className=row.className,path=row.path,group=row.group}
            bump(groupAppeared,row.group)
        end
        notObservedEvents=notObservedEvents+#(sample.notObserved or {})
        for _,row in ipairs(sample.changes or {}) do
            tick()
            local s=stats[row.id]
            if not s then s={changes=0,fields={},first={},last={}};stats[row.id]=s end
            s.changes=s.changes+1
            s.group=row.group
            s.path=row.afterPath
            local before,after=row.before or {},row.after or {}
            local function mark(name,b,a)
                s.fields[name]=(s.fields[name] or 0)+1
                if s.first[name]==nil then s.first[name]=(b==nil) and "<absent>" or b end
                s.last[name]=(a==nil) and "<removed>" or a
            end
            for k,v in pairs(after) do
                if k=="Attributes" and type(v)=="table" then
                    local ba=type(before.Attributes)=="table" and before.Attributes or {}
                    local seen={}
                    for ak,av in pairs(v) do
                        seen[ak]=true
                        if not sameData(ba[ak],av) then mark("Attributes."..tostring(ak),ba[ak],av) end
                    end
                    for ak,bv in pairs(ba) do
                        if not seen[ak] then mark("Attributes."..tostring(ak),bv,nil) end
                    end
                elseif not sameData(before[k],v) then
                    mark(k,before[k],v)
                end
            end
        end
    end
    local changedObjects=0
    local volatileList={}
    for id,s in pairs(stats) do
        changedObjects=changedObjects+1
        bump(groupChanged,s.group)
        volatileList[#volatileList+1]={id=id,s=s}
    end
    table.sort(volatileList,function(a,b)
        if a.s.changes~=b.s.changes then return a.s.changes>b.s.changes end
        return tostring(a.s.path)<tostring(b.s.path)
    end)
    local volatileObjects={}
    for i=1,math.min(25,#volatileList) do
        local e=volatileList[i]
        local m=meta[e.id] or {}
        volatileObjects[i]={id=e.id,path=e.s.path or m.path,className=m.className,group=e.s.group,
            changeCount=e.s.changes,fields=e.s.fields,firstValues=e.s.first,lastValues=e.s.last}
    end
    local groupsOut={}
    for g,count in pairs(groupObserved) do
        groupsOut[g]={observedAtBaseline=count,changedObjects=groupChanged[g] or 0,appearedLater=groupAppeared[g] or 0}
    end
    A.runtime={mode=obs.mode,samples=#sampleList,baselineObjects=baselineObjects,changedObjects=changedObjects,
        appearedAfterBaseline=appeared,notObservedEvents=notObservedEvents,groups=groupsOut,
        volatileObjects=volatileObjects,leaderstats=leader,humanoids=humanoids,
        note="Sampled local state only (a few samples, a few seconds apart). Short events can be missed; changes are not attributed to any action."}
    A.runtime.events=summarizeEvents(snap.eventTimeline)
    A.runtime.uiFlow=buildUiFlow(snap.eventTimeline)
    A.runtime.interactions=buildInteractionAnalysis(snap.eventTimeline)

    -- 4. Gameplay analyzer (aggregation)
    local remoteContainers={}
    do
        local list={}
        for _,c in pairs(gp.remoteContainers) do list[#list+1]=c end
        table.sort(list,function(a,b)
            if a.count~=b.count then return a.count>b.count end
            return a.path<b.path
        end)
        for i=1,math.min(25,#list) do remoteContainers[i]={path=list[i].path,count=list[i].count,classes=list[i].classes} end
    end
    local valueContainers={}
    do
        local list={}
        for _,c in pairs(gp.valueContainers) do list[#list+1]=c end
        table.sort(list,function(a,b)
            if a.count~=b.count then return a.count>b.count end
            return a.path<b.path
        end)
        for i=1,math.min(20,#list) do valueContainers[i]={path=list[i].path,count=list[i].count} end
    end
    local screenList={}
    for _,s in pairs(gp.screenInfo) do screenList[#screenList+1]=s end
    table.sort(screenList,function(a,b)
        if a.objects~=b.objects then return a.objects>b.objects end
        return a.path<b.path
    end)
    while #screenList>40 do screenList[#screenList]=nil end
    local clusters={}
    do
        local list={}
        for _,c in pairs(containerStats) do
            local kinds=0
            for _,n in ipairs({c.modules,c.scripts,c.remotes,c.values,c.gui,c.interaction}) do if n>0 then kinds=kinds+1 end end
            if kinds>=3 then list[#list+1]=c end
        end
        table.sort(list,function(a,b)
            if a.total~=b.total then return a.total>b.total end
            return a.path<b.path
        end)
        for i=1,math.min(20,#list) do
            local c=list[i]
            clusters[i]={path=c.path,modules=c.modules,scripts=c.scripts,remotes=c.remotes,values=c.values,gui=c.gui,interaction=c.interaction,total=c.total}
        end
    end
    A.gameplay={
        remotes={total=gp.remoteCount,byClass=gp.remoteByClass,remoteContainers=remoteContainers,remotes=gp.remoteList,
            note="Inventory only: class and location. Arguments, call direction and server behavior are not collected."},
        interaction={promptCount=gp.promptCount,clickDetectorCount=gp.clickDetectors,spawnLocationCount=gp.spawns,
            humanoidCount=gp.humanoidCount,toolCount=gp.toolCount,prompts=gp.prompts,tools=gp.tools},
        gui={screenGuiCount=0,screenGuis=screenList,buttons=gp.buttons},
        state={valueCount=gp.valueCount,valueByClass=gp.valueByClass,leaderstatsValues=gp.leaderstatsValues,valueContainers=valueContainers},
        conventions={tags=topN(gp.tags,30),attributeKeys=topN(gp.attrKeys,40),
            remoteTokens=topN(gp.tokens.Remote,30),valueTokens=topN(gp.tokens.Value,30),
            toolTokens=topN(gp.tokens.Tool,20),promptTokens=topN(gp.tokens.Prompt,20)},
        featureClusters=clusters,
        note="featureClusters list containers holding three or more kinds of objects directly. This is co-location only, not proof of a functional relationship. Token lists come from names/text and are unverified.",
    }
    local screenCount=0
    for _ in pairs(gp.screenInfo) do screenCount=screenCount+1 end
    A.gameplay.gui.screenGuiCount=screenCount
    A.spatial=buildSpatial(records,tick)
    return A
end

-- Optional QA report import. This is DATA ONLY, never code or a loader.
-- Place a developer-authorized, non-sensitive QA summary in the local input file.
-- It is not a credential or proof of permission; it does not enable expanded scanning.
local function validateQAInput(doc,placeId,gameId)
    local function whole(n,min,max)
        return type(n)=="number" and n==n and n%1==0 and n>=min and n<=max
    end
    local function identifier(s)
        return type(s)=="string" and #s>=1 and #s<=80 and s:match("^[%w_.%-]+$")~=nil
    end
    local function arrayCount(t,limit)
        if type(t)~="table" then return nil end
        local count,max=0,0
        for k in pairs(t) do
            if not whole(k,1,limit) then return nil end
            count=count+1;max=math.max(max,k)
        end
        if max~=count then return nil end
        return count
    end
    local function onlyKeys(t,allowed)
        if type(t)~="table" then return false end
        for k in pairs(t) do if not allowed[k] then return false end end
        return true
    end
    local rootKeys={schema=true,placeId=true,gameId=true,capturedAt=true,sessionId=true,sources=true}
    local sourceKeys={id=true,kind=true,entries=true}
    local entryKeys={id=true,system=true,check=true,status=true,count=true,durationMs=true}
    local statuses={qa_test={pass=true,fail=true,blocked=true},
        communication_summary={observed=true,not_observed=true,unknown=true},
        source_summary={documented=true,unknown=true}}
    if not onlyKeys(doc,rootKeys) or doc.schema~="RUM_QA_IMPORT_V1" then return nil,"invalid_schema" end
    if doc.placeId~=placeId or doc.gameId~=gameId then return nil,"game_id_mismatch" end
    if not whole(doc.capturedAt,1,9007199254740991) or not identifier(doc.sessionId) then return nil,"invalid_provenance" end
    local n=arrayCount(doc.sources,24)
    if not n or n==0 then return nil,"invalid_sources" end
    local out={schema=doc.schema,placeId=placeId,gameId=gameId,capturedAt=doc.capturedAt,sessionId=doc.sessionId,sources={},entryCount=0,
        byKind={qa_test=0,communication_summary=0,source_summary=0},provenance="user_supplied_unverified"}
    local seenSources={}
    for i=1,n do
        local s=doc.sources[i]
        if not onlyKeys(s,sourceKeys) or not identifier(s.id) or type(s.kind)~="string" or not statuses[s.kind] then return nil,"invalid_source" end
        if seenSources[s.id] then return nil,"duplicate_source_id" end
        seenSources[s.id]=true
        local m=arrayCount(s.entries,500)
        if not m or m==0 or out.entryCount+m>2000 then return nil,"invalid_entry_count" end
        local clean={id=s.id,kind=s.kind,entries={}}
        local seenEntries={}
        for j=1,m do
            local e=s.entries[j]
            if not onlyKeys(e,entryKeys) or not identifier(e.id) or not identifier(e.system) or not identifier(e.check)
                or type(e.status)~="string" or not statuses[s.kind][e.status] then return nil,"invalid_entry" end
            if seenEntries[e.id] then return nil,"duplicate_entry_id" end
            seenEntries[e.id]=true
            if e.count~=nil and not whole(e.count,0,1000000000) then return nil,"invalid_count" end
            if e.durationMs~=nil and not whole(e.durationMs,0,86400000) then return nil,"invalid_duration" end
            clean.entries[j]={id=e.id,system=e.system,check=e.check,status=e.status,count=e.count,durationMs=e.durationMs}
        end
        out.sources[i]=clean
        out.entryCount=out.entryCount+m
        out.byKind[s.kind]=out.byKind[s.kind]+m
    end
    return out
end

local function buildUnifiedReport(snap,readInput,decode,placeId,gameId)
    local report={schema="RUM_UNIFIED_V1",status="scan_only",inputStatus="not_provided",importedSources=0,importedEntries=0,
        inputFilename="RUM_QA_Input_"..tostring(placeId)..".json",
        scanReference={placeId=placeId,gameId=gameId,sequence=snap.sequence,timestamp=snap.stamp},
        provenance="Scanner data and imported QA declarations remain separate; matching game IDs do not prove matching sessions, authorship, or accuracy.",
        scriptReadiness="not_established",limitations={"No third-party loaders, executable source, remote payloads or interception.","Imported claims are not verified by the scanner.","No automatic connection between imported test IDs and scanned Instance IDs."},
        inputLimits={maxBytes=512*1024,maxSources=24,maxEntriesPerSource=500,maxEntries=2000}}
    if not readInput then report.inputStatus="reader_unavailable";return report end
    local ok,raw=pcall(readInput,report.inputFilename)
    if not ok then report.inputStatus="read_error";return report end
    if raw==nil then return report end
    if type(raw)~="string" then report.inputStatus="invalid_input_type";return report end
    if #raw>report.inputLimits.maxBytes then report.inputStatus="input_too_large";return report end
    local parsed,doc=pcall(decode,raw)
    if not parsed then report.inputStatus="invalid_json";return report end
    local validated,data,reason=pcall(validateQAInput,doc,placeId,gameId)
    if not validated then report.inputStatus="validation_error";return report end
    if not data then report.inputStatus=reason;return report end
    report.status="scan_plus_qa_summaries"
    report.inputStatus="validated_schema_unverified_content"
    report.importedSources=#data.sources
    report.importedEntries=data.entryCount
    report.importedQA=data
    report.sessionMatch="not_established"
    return report
end

-- Additional developer-published diagnostics, data only. Not executor-tool hooks.
-- Read one bounded snapshot per channel at completion of an authorized scan.
local function buildPublishedDiagnostics(snap, authorized, readChannel, decode, placeId, gameId, now)
    local channels={{name="ExplorerSummary",kind="source_summary"},{name="RemoteSummary",kind="communication_summary"}}
    local report={schema="RUM_PUBLISHED_DIAGNOSTICS_V1",status="not_authorized",sources={},importedEntries=0,importedSources=0,
        observedAt=now,scanTimestamp=snap.stamp,sessionMatch="not_established",
        note="Developer-published aggregate summaries only. No interception, source code, invocation arguments or return data. Schema validation does not authenticate claims."}
    for _,channel in ipairs(channels) do
        local result={id=channel.name,kind=channel.kind,status="not_authorized"}
        report.sources[#report.sources+1]=result
        if authorized then
            local ok,raw=pcall(readChannel,channel.name)
            result.status="not_provided"
            if not ok then result.status="read_error"
            elseif raw~=nil then
                if type(raw)~="string" or #raw>512*1024 then result.status="invalid_size_or_type"
                else
                    local parsed,doc=pcall(decode,raw)
                    if not parsed then result.status="invalid_json"
                    else
                        local checked,data,reason=pcall(validateQAInput,doc,placeId,gameId)
                        if not checked then result.status="validation_error"
                        elseif not data then result.status=reason
                        elseif data.capturedAt<snap.stamp or data.capturedAt>now+5 then result.status="outside_scan_window"
                        elseif #data.sources~=1 or data.sources[1].kind~=channel.kind then result.status="wrong_source_kind"
                        else
                            result.status="validated_schema_unverified_content"
                            result.data=data
                            report.importedEntries=report.importedEntries+data.entryCount
                            report.importedSources=report.importedSources+1
                        end
                    end
                end
            end
        end
    end
    if authorized then
        report.status=report.importedSources==#channels and "both_summaries_present" or (report.importedSources>0 and "partial" or "no_valid_summaries")
    end
    return report
end

local function scanOnce()
    if closed or busy then return end
    busy=true
    scanBtn.Text="ĐANG QUÉT..."
    setProgress(0,1)
    log("INFO","Bắt đầu quét client.")
    updateStatus("Đang quét Instance client nhìn thấy...")
    task.spawn(function()
        local started=os.clock()
        local stage="enumeration"
        local outerOk,outerError=xpcall(function()
        log("INFO","Stage: enumeration")
        local ok, descendants, rootErrors, rootStatus, sourceRoot=pcall(collectGameInstances)
        if not ok then
            busy=false
            scanBtn.Text="QUÉT GAME"
            log("ERROR","GetDescendants: "..tostring(descendants))
            updateStatus("Không thể lấy danh sách Instance. Xem Debug.",true)
            return
        end
        log("INFO",("Stage: enumeration complete; count=%d; elapsed=%.2fs"):format(#descendants,os.clock()-started))
        stage="inventory"
        if #descendants>HISTORY_RECORD_BUDGET/2 and #histories>0 then
            local retained=#descendants
            for _,old in ipairs(histories) do retained=retained+old.total end
            while #histories>0 and retained>HISTORY_RECORD_BUDGET do
                local old=table.remove(histories)
                retained=retained-old.total
                log("WARN","Giai phong lich su #"..old.sequence.." truoc khi quet lon; file da xuat khong bi xoa.")
            end
            selectedIndex=1
            renderHistory()
        end
        local ids=setmetatable({}, {__mode="k"})
        local nextId=0
        local function idFor(inst)
            if not inst or inst==game then return "ROOT" end
            local v=ids[inst]
            if not v then
                nextId=nextId+1
                v="I"..tostring(nextId)
                ids[inst]=v
            end
            return v
        end
        local scanTime=os.time()
        local streamingAtScan=tryProperty(workspace,"StreamingEnabled")
        local streamingStatus=type(streamingAtScan)=="boolean" and "observed" or "unavailable"
        local records, byClass, byRoot={}, {}, {}
        local cats={Remote=0,Script=0,Module=0,GUI=0,Value=0,Interaction=0,Other=0}
        local diag={propertyAttempts=0,propertyNil=0,propertyEncoded=0,propertyErrors=0,conversionErrors=0,attributeErrors=0,tagErrors=0,recordErrors=0,samples={}}
        local failed,excludedUI,invalidClass,detached=0,0,0,0
        local gameCount=0
        local rootCounts={}
        local function rootCounter(label)
            if not rootCounts[label] then rootCounts[label]={visited=0,retained=0,excludedScannerUI=0,readFailed=0} end
            return rootCounts[label]
        end
        for i,inst in ipairs(descendants) do
            if closed then return end
            local origin=sourceRoot[inst] or "Unknown"
            local rc=rootCounter(origin)
            rc.visited=rc.visited+1
            local good,record=pcall(function()
                if inst==screen or inst:IsDescendantOf(screen) then return nil end
                local parent=inst.Parent
                local path=safePath(inst)
                local name=inst.Name
                local class=inst.ClassName
                if class=="" then invalidClass=invalidClass+1; readIssue(diag,"propertyErrors",inst,"ClassName","empty class") end
                if not parent then detached=detached+1 end
                local cat=category(inst)
                local props,attributes,attrCount,tags=detailsFor(inst,diag)
                local rootName=origin
                local platform=(rootName=="CorePackages" or rootName=="CoreGui" or
                    rootName=="CoreScriptService" or rootName=="RobloxReplicatedStorage" or
                    rootName=="PluginGuiService")
                local row={
                    instanceId=idFor(inst),parentId=idFor(parent),name=name,
                    className=class~="" and class or "Unknown",path=path,category=cat,root=rootName,
                    scope=platform and "RobloxCore" or "ClientGame",
                }
                local depth=0
                do
                    local p=parent
                    while p and p~=game and depth<200 do depth=depth+1;p=p.Parent end
                end
                row.depth=depth
                local okKids,kidCount=pcall(function() return #inst:GetChildren() end)
                if okKids then row.childCount=kidCount end
                if POSITION_CLASSES[class] and inst:IsDescendantOf(workspace) then
                    local skipPosition=false
                    if class=="Humanoid" then
                        local okOwner,owner=pcall(function() return parent and Players:GetPlayerFromCharacter(parent) end)
                        if okOwner and owner then skipPosition=true else row.npc=true end
                    end
                    if not skipPosition then
                        local wp=worldPositionOf(inst)
                        if wp then row.worldPosition=wp end
                    end
                end
                if next(props) then row.properties=props end
                if attributes then row.attributes=attributes end
                if attrCount>0 then row.attributeCount=attrCount end
                if tags then row.tags=tags end
                return row
            end)
            if good and record then
                rc.retained=rc.retained+1
                records[#records+1]=record
                byClass[record.className]=(byClass[record.className] or 0)+1
                byRoot[record.root]=(byRoot[record.root] or 0)+1
                cats[record.category]=cats[record.category]+1
                if record.scope=="ClientGame" then gameCount=gameCount+1 end
            elseif not good then
                rc.readFailed=rc.readFailed+1
                failed=failed+1
                readIssue(diag,"recordErrors",inst,"record",record)
            else
                rc.excludedScannerUI=rc.excludedScannerUI+1
                excludedUI=excludedUI+1
            end
            if i%350==0 then
                setProgress(i,#descendants)
                updateStatus(("Đang quét %d/%d..."):format(i,#descendants))
                task.wait()
            end
        end
        if closed then return end
        -- Release the enumeration array before collecting diagnostics.
        local enumeratedCount=#descendants
        descendants=nil
        sourceRoot=nil
        for label,counts in pairs(rootCounts) do
            rootStatus[label]=rootStatus[label] or {}
            rootStatus[label].accounting=counts
        end
        log("INFO",("Stage: inventory complete; records=%d; elapsed=%.2fs"):format(#records,os.clock()-started))
        stage="observation"
        local samples,transitions={},{}
        local previous={}
        local transitionTotal,observationErrors=0,0
        local mode=qaMode()
        log("INFO","QA observation mode: "..mode)
        log("INFO","Quan sat cuc bo: 5 mau, luu baseline va thay doi, khong gioi han 2.500.")
        scanBtn.Text="QUAN SÁT..."
        local recorder,eventTimeline
        do
            local okR,res=pcall(startEventRecorder,idFor,mode)
            if okR then
                recorder=res
                log("INFO",("Ghi su kien: cua so %d giay, toi da %d su kien."):format(EVENT_WINDOW_SECONDS,EVENT_MAX))
            else
                eventTimeline={status="failed",error=tostring(res):sub(1,300)}
                log("WARN","Event recorder: "..tostring(res))
            end
        end
        for n=1,SAMPLE_COUNT do
            if closed then return end
            updateStatus(("Đang quan sát trạng thái %d/%d"):format(n,SAMPLE_COUNT))
            local observedAt=os.time()
            local rr,ee,ss,coverage,count,observationDiag,tagCount=observeLocal(idFor,mode)
            observationErrors=observationErrors+ee
            local sample={sample=n,timestamp=observedAt,observed=count,byGroup=coverage,readErrors=ee,omittedByLimit=ss,propertyDiagnostics=observationDiag,taggedCandidates=tagCount}
            if n==1 then
                local baseline={}
                for _,r in pairs(rr) do baseline[#baseline+1]=r end
                sample.baseline=baseline
            else
                local changed,added,missing=compareState(previous,rr)
                sample.changes=changed;sample.added=added;sample.notObserved=missing
                transitions[#transitions+1]={fromSample=n-1,toSample=n,changed=#changed,appeared=#added,notObserved=#missing}
                transitionTotal=transitionTotal+#changed
            end
            samples[#samples+1]=sample
            previous=rr
            log(ee>0 and "WARN" or "INFO",("Mau %d: %d trang thai, %d loi doc; %d bo qua do gioi han"):format(n,count,ee,ss))
            setProgress(n,SAMPLE_COUNT)
            if n<SAMPLE_COUNT then task.wait(SAMPLE_INTERVAL) end
        end
        if recorder then
            local window=EVENT_WINDOW_SECONDS
            scanBtn.Text="GHI SỰ KIỆN..."
            while not closed do
                local elapsed=os.clock()-recorder.startedAt
                if elapsed>=window then break end
                updateStatus(("Dang ghi su kien client: con %d giay. Hay thao tac binh thuong trong game."):format(math.ceil(window-elapsed)))
                setProgress(elapsed,window)
                task.wait(math.min(1,window-elapsed))
            end
            if closed then return end
            eventTimeline=recorder.finish()
            log("INFO",("Su kien: %d ghi nhan; bo %d (gioi han tong), %d (gioi han doi tuong), %d (gioi han lop)."):format(
                eventTimeline.count,eventTimeline.dropped.byTotalLimit,eventTimeline.dropped.perInstanceLimit,eventTimeline.dropped.perClassLimit))
        end
        log("INFO",("Stage: observation complete; elapsed=%.2fs"):format(os.clock()-started))
        stage="integrity"
        local initialIds,missingParents={},0
        for _,r in ipairs(records) do initialIds[r.instanceId]=true end
        local duplicateIds,seenIds=0,{}
        local duplicatePaths,seenPaths=0,{}
        local withProperties,withAttributes,withTags=0,0,0
        local fieldCoverageByClass={}
        for _,r in ipairs(records) do
            if r.parentId~="ROOT" and not initialIds[r.parentId] then missingParents=missingParents+1 end
            if seenIds[r.instanceId] then duplicateIds=duplicateIds+1 end
            seenIds[r.instanceId]=true
            if seenPaths[r.path] then duplicatePaths=duplicatePaths+1 end
            seenPaths[r.path]=true
            local cov=fieldCoverageByClass[r.className]
            if not cov then
                cov={records=0,withProperties=0,withAttributes=0,withTags=0}
                fieldCoverageByClass[r.className]=cov
            end
            cov.records=cov.records+1
            if r.properties then withProperties=withProperties+1;cov.withProperties=cov.withProperties+1 end
            if r.attributes then withAttributes=withAttributes+1;cov.withAttributes=cov.withAttributes+1 end
            if r.tags then withTags=withTags+1;cov.withTags=cov.withTags+1 end
        end
        seenPaths=nil
        local balanced=enumeratedCount==#records+excludedUI+failed
        log(balanced and "INFO" or "ERROR",("Doi chieu: %d = %d luu + %d UI loai + %d loi"):format(enumeratedCount,#records,excludedUI,failed))
        if detached>0 then log("WARN",("%d ban ghi khong con Parent luc doc"):format(detached)) end
        if duplicateIds>0 then log("ERROR","Duplicate ID: "..duplicateIds) end
        if missingParents>0 then log("WARN",("%d tham chiếu cha không nằm trong ảnh chụp ban đầu"):format(missingParents)) end
        for _,err in ipairs(rootErrors) do log("WARN",err) end
        if streamingAtScan==true then
            log("WARN","StreamingEnabled: Workspace chi gom doi tuong da tai den client.")
        elseif streamingStatus~="observed" then
            log("WARN","Khong doc duoc StreamingEnabled; khong xac nhan duoc pham vi Workspace.")
        end
        log("INFO","Pham vi loai tru: server/source, nhanh Players khac, tham so Remote. Chi metadata media.")
        sequence=sequence+1
        local snap={
            sequence=sequence,stamp=scanTime,streamingEnabled=streamingAtScan,streamingStatus=streamingStatus,
            timeString=os.date("%d/%m/%Y  %H:%M:%S",scanTime),
            total=#records,gameCount=gameCount,errors=failed,
            records=records,byClass=byClass,byRoot=byRoot,categories=cats,
            readDiagnostics=diag,durationSeconds=os.clock()-started,rootStatus=rootStatus,
            observation={samples=samples,transitions=transitions,readErrors=observationErrors,changedAcrossSamples=transitionTotal,mode=mode,scope=mode=="basic" and "basic local visibility and scalar state" or "local state plus explicitly tagged developer QA objects; tagged display text and attributes",format="baseline_then_deltas",limitations="samples are not atomic; absence does not prove removal; IDs for new objects may not be present in initial inventory; no action attribution; no network interception; sampling may miss short events; text inputs not collected in observation; tagged data must be non-sensitive"},
            integrity={unresolvedParentReferences=missingParents,rootErrors=rootErrors,duplicateIds=duplicateIds,duplicatePathExtraRecords=duplicatePaths,enumerated=enumeratedCount,retained=#records,excludedScannerUI=excludedUI,failedRecords=failed,accountingBalanced=balanced,unknownClassRecords=invalidClass,detachedAtRead=detached,withProperties=withProperties,withAttributes=withAttributes,withTags=withTags,fieldCoverageByClass=fieldCoverageByClass},
        }
        stage="analysis"
        snap.eventTimeline=eventTimeline or {status="not_recorded"}
        updateStatus("Dang lap chi muc bang chung QA...")
        snap.qaEvidence=buildEvidence(snap.observation,function()
            if closed then error("Scan cancelled") end
            task.wait()
        end)
        log("INFO",("QA evidence: %s; %d systems; %d declarations; readiness not established."):format(snap.qaEvidence.status,snap.qaEvidence.systemCount,snap.qaEvidence.declaredObjects))
        updateStatus("Dang phan tich cau truc (explorer / module / runtime / gameplay)...")
        local okAnalysis,analysis=pcall(buildAnalysis,snap,function()
            if closed then error("Scan cancelled") end
            task.wait()
        end)
        if closed then return end
        if okAnalysis then
            snap.analysis=analysis
            log("INFO",("Phan tich: %d module, %d remote (inventory), %d prompt, %d GUI goc, %d doi tuong bien dong, %d cum chuc nang (co-location)."):format(
                analysis.modules.count,analysis.gameplay.remotes.total,analysis.gameplay.interaction.promptCount,
                analysis.gameplay.gui.screenGuiCount,analysis.runtime.changedObjects,#analysis.gameplay.featureClusters))
        else
            snap.analysis={schema="RUM_ANALYSIS_V1",status="failed",error=tostring(analysis):sub(1,300)}
            log("ERROR","Phan tich that bai: "..tostring(analysis))
        end
        stage="published diagnostics"
        updateStatus("Dang tong hop bao cao QA tuy chon...")
        local reader
        if type(readfile)=="function" then
            reader=function(filename)
                if type(isfile)=="function" and not isfile(filename) then return nil end
                return readfile(filename)
            end
        end
        snap.unifiedReport=buildUnifiedReport(snap,reader,function(raw)
            return game:GetService("HttpService"):JSONDecode(raw)
        end,game.PlaceId,game.GameId)
        log(snap.unifiedReport.status=="scan_plus_qa_summaries" and "INFO" or
            ((snap.unifiedReport.inputStatus=="not_provided" or snap.unifiedReport.inputStatus=="reader_unavailable") and "INFO" or "WARN"),
            ("Unified QA: %s; %d sources, %d entries; readiness not established."):format(
                snap.unifiedReport.inputStatus,snap.unifiedReport.importedSources,snap.unifiedReport.importedEntries))
        -- Do not read arbitrary UI, executor globals or tool files. Only the explicit
        -- developer-published data channel, and only with the existing QA opt-in.
        snap.publishedDiagnostics=buildPublishedDiagnostics(snap,mode~="basic" and qaMode()~="basic",function(name)
            local folder=game:GetService("ReplicatedStorage"):FindFirstChild("RUM_QA_Diagnostics")
            if not folder or not folder:IsA("Folder") then return nil end
            local value=folder:FindFirstChild(name)
            if not value or not value:IsA("StringValue") then return nil end
            return value.Value
        end,function(raw) return game:GetService("HttpService"):JSONDecode(raw) end,game.PlaceId,game.GameId,os.time())
        log("INFO",("Published QA diagnostics: %s; %d sources, %d entries."):format(
            snap.publishedDiagnostics.status,snap.publishedDiagnostics.importedSources,snap.publishedDiagnostics.importedEntries))
        for _,source in ipairs(snap.publishedDiagnostics.sources or {}) do
            log("INFO","Published channel: "..tostring(source.id).." | "..tostring(source.status))
        end
        stage="comparison and history"
        do
            local prevSnap=histories[1]
            if prevSnap then
                updateStatus("Dang so sanh voi lan quet #"..prevSnap.sequence.."...")
                local okC,cmp=pcall(compareSnapshots,prevSnap,snap,function()
                    if closed then error("Scan cancelled") end
                    task.wait()
                end)
                if closed then return end
                if okC then
                    snap.comparison=cmp
                    log("INFO",("So sanh voi #%d: +%d moi, %d khong thay, %d doi thuoc tinh."):format(
                        prevSnap.sequence,cmp.summary.added,cmp.summary.notObservedNow,cmp.summary.changed))
                else
                    snap.comparison={status="failed",error=tostring(cmp):sub(1,300)}
                    log("ERROR","So sanh that bai: "..tostring(cmp))
                end
            else
                snap.comparison={status="no_previous_scan",note="Quet it nhat hai lan trong mot phien de co so sanh."}
            end
        end
        do
            local snaps={snap}
            if histories[1] then snaps[#snaps+1]=histories[1] end
            if histories[2] then snaps[#snaps+1]=histories[2] end
            updateStatus("Dang gop "..#snaps.." lan quet (on dinh / thoang qua / doi lap lai)...")
            local okS,stab=pcall(computeStability,snaps,function()
                if closed then error("Scan cancelled") end
                task.wait()
            end)
            if closed then return end
            if okS then
                snap.stability=stab
                if stab.status=="computed" then
                    log("INFO",("Gop %d lan quet: %d on dinh, %d thoang qua, %d doi lap lai."):format(
                        #stab.scansUsed,stab.stableObjects,stab.transientCount,stab.changedRepeatedly))
                else
                    log("INFO","Gop lan quet: "..tostring(stab.status))
                end
            else
                snap.stability={status="failed",error=tostring(stab):sub(1,300)}
                log("ERROR","Gop lan quet that bai: "..tostring(stab))
            end
        end
        local uiFlow=snap.analysis and snap.analysis.runtime and snap.analysis.runtime.uiFlow
        local inter=snap.analysis and snap.analysis.runtime and snap.analysis.runtime.interactions
        local spatial=snap.analysis and snap.analysis.spatial
        log("INFO",("Luong UI: %s (%d panel). Tuong tac: %s (%d). Khong gian: %s (%d cum)."):format(
            tostring(uiFlow and uiFlow.status),uiFlow and uiFlow.panelCount or 0,
            tostring(inter and inter.status),inter and inter.interactionCount or 0,
            tostring(spatial and spatial.status),spatial and spatial.clusterCount or 0))
        if snap.total>HISTORY_RECORD_BUDGET then
            log("WARN",("Snapshot #%d: %d > %d ban ghi. Giu snapshot moi; gioi han lich su khong phai gioi han RAM."):format(snap.sequence,snap.total,HISTORY_RECORD_BUDGET))
        end
        table.insert(histories,1,snap)
        local retained=snap.total
        for i=2,#histories do retained=retained+histories[i].total end
        while #histories>1 and (#histories>MAX_HISTORY or retained>HISTORY_RECORD_BUDGET) do
            local old=table.remove(histories)
            retained=retained-old.total
            log("WARN","Giai phong lich su #"..old.sequence.." do gioi han lich su/bo nho; file da xuat khong bi xoa.")
        end
        selectedIndex=1
        busy=false
        scanBtn.Text="QUÉT LẠI"
        summary.Text=("%d đối tượng"):format(snap.total)
        subtitle.Text=("Lần #%03d · %.1f giây · %d lỗi bản ghi"):format(snap.sequence,snap.durationSeconds,failed)
        renderHistory()
        setProgress(1,1)
        log("INFO",("Lần #%d: %d bản ghi, %.1fs, %d Instance game, %d hệ thống."):format(snap.sequence,snap.total,snap.durationSeconds,gameCount,snap.total-gameCount))
        log("INFO",("Thuoc tinh: %d lan doc; %d ma hoa; %d nil; %d loi doc."):format(diag.propertyAttempts,diag.propertyEncoded,diag.propertyNil,diag.propertyErrors))
        local issues=diag.propertyErrors+diag.conversionErrors+diag.attributeErrors+diag.tagErrors+diag.recordErrors
        if issues>0 then
            log("WARN",("Lỗi bản ghi %d; thuộc tính %d; chuyển kiểu %d; attributes %d; tags %d."):format(diag.recordErrors,diag.propertyErrors,diag.conversionErrors,diag.attributeErrors,diag.tagErrors))
            for _,entry in ipairs(diag.samples) do log("DETAIL",entry.kind.." / "..entry.path.." / "..entry.field..": "..entry.message) end
        end
        updateStatus((issues>0 or observationErrors>0 or missingParents>0 or duplicateIds>0 or #rootErrors>0) and "Quét xong với cảnh báo. Mở Debug để xem chi tiết." or "Quét xong. Chọn TXT hoặc JSON để xuất một file.",failed>0)
        end,scannerTrace)
        if not outerOk and not closed then
            if activeRecorder then pcall(activeRecorder.stop) end
            busy=false
            scanBtn.Text="QUÉT LẠI"
            log("ERROR","Scan stage="..stage..": "..tostring(outerError))
            updateStatus("Quét thất bại. Xem Debug.",true)
        end
    end)
end
on(scanBtn.MouseButton1Click,scanOnce)

-- V4.5: compact export is a projection, not a new collection mechanism.
-- Keep every non-visual record and its ancestor chain. Never deduplicate paths.
local COMPACT_VISUAL_CLASSES={Pose=true,Keyframe=true,Beam=true,Trail=true,
    ParticleEmitter=true,UIStroke=true,UICorner=true,UIGradient=true}
local function compactProjection(records,pause)
    local byId,keep={},{}
    local summary={policy="visual_projection_v1",originalRecords=#records,exportedRecords=0,
        omittedRecords=0,omittedByClass={},omittedByRoot={},retainedVisualAncestors=0,
        note="Full snapshot retained in session. Listed visual classes are counted instead of exported individually unless needed as ancestors of retained records. Summary and timeline references may refer to omitted records. No path-based deduplication."}
    for i,r in ipairs(records) do
        byId[r.instanceId]=r
        if pause and i%2000==0 then pause() end
    end
    for i,r in ipairs(records) do
        if not COMPACT_VISUAL_CLASSES[r.className] then
            local row=r
            while row and not keep[row.instanceId] do
                keep[row.instanceId]=true
                row=byId[row.parentId]
            end
        end
        if pause and i%2000==0 then pause() end
    end
    local out={}
    for i,r in ipairs(records) do
        if keep[r.instanceId] then
            out[#out+1]=r
            if COMPACT_VISUAL_CLASSES[r.className] then summary.retainedVisualAncestors=summary.retainedVisualAncestors+1 end
        else
            summary.omittedRecords=summary.omittedRecords+1
            summary.omittedByClass[r.className]=(summary.omittedByClass[r.className] or 0)+1
            summary.omittedByRoot[r.root]=(summary.omittedByRoot[r.root] or 0)+1
        end
        if pause and i%2000==0 then pause() end
    end
    summary.exportedRecords=#out
    summary.accountingBalanced=summary.originalRecords==summary.exportedRecords+summary.omittedRecords
    return out,summary
end

-- Broad structural categories only; counts are not verified gameplay rules.
local function buildCoverageAudit(snap)
    local a=snap.analysis or {}
    local runtime=a.runtime or {}
    local observation=snap.observation or {}
    local timeline=snap.eventTimeline or {}
    local watch=timeline.watched or {}
    local dropped=timeline.dropped or {}
    local eventCount=timeline.count or 0
    local changed=observation.changedAcrossSamples or 0
    local interactions=runtime.interactions or {}
    local audit={schema="RUM_COVERAGE_V1",classification="structural_only",
        structuralCategories=snap.categories or {},
        evidence={timelineStatus=timeline.status or "not_recorded",eventCount=eventCount,
            observedInteractions=interactions.interactionCount or 0,changedAcrossSamples=changed,
            sampleCount=#(observation.samples or {}),watchAttemptsSkipped=watch.skippedByWatchCap or 0,
            watchCounters=watch,droppedCounters=dropped,elapsedSeconds=timeline.elapsedSeconds,
            streamingEnabled=snap.streamingEnabled},
        missing={source=true,serverRules=true,remoteArguments=true,causalProof=true},
        structuralReadiness="inventory_only",behaviorReadiness="not_established",
        note="Counted categories and events are observations, not action recipes or causal evidence. Zero events does not prove inactivity. No new data collection. Advanced QA continues to require developer opt-in."}
    return audit
end

-- Quality audit is derived only from existing summaries, not new collection.
local function buildQualityReport(snap)
    local a=snap.analysis or {}
    local rt=a.runtime or {}
    local ev=rt.events or {}
    local tl=snap.eventTimeline or {}
    local visual=0
    for _,rows in ipairs({ev.addedByClass or {},ev.removedByClass or {}}) do
        for _,r in ipairs(rows) do
            if COMPACT_VISUAL_CLASSES[r.name] then visual=visual+(r.count or 0) end
        end
    end
    local count=tl.count or 0
    local interaction=(rt.interactions or {}).interactionCount or 0
    local changed=(snap.observation or {}).changedAcrossSamples or 0
    local dropped=tl.dropped or {}
    local capDrops=(dropped.byTotalLimit or 0)+(dropped.perInstanceLimit or 0)+(dropped.perClassLimit or 0)
    local issues={}
    local function issue(code) issues[#issues+1]=code end
    if count==0 then issue("NO_RECORDED_EVENTS") end
    if interaction==0 then issue("NO_RECORDED_INTERACTIONS") end
    if changed==0 then issue("NO_SAMPLED_CHANGES") end
    if capDrops>0 then issue("EVENT_CAP_REACHED") end
    if ((tl.watched or {}).skippedByWatchCap or 0)>0 then issue("WATCH_CAP_REACHED") end
    if snap.streamingEnabled then issue("STREAMING_LIMITED_SCOPE") end
    if ((snap.integrity or {}).detachedAtRead or 0)>0 then issue("DETACHED_RECORDS") end
    if (snap.errors or 0)>0 then issue("READ_ERRORS") end
    if count>0 and visual/count>=0.5 then issue("VISUAL_EVENTS_DOMINATE") end
    return {schema="RUM_REPORT_QUALITY_V1",recordedEvents=count,
        identifiedVisualAddRemoveEvents=visual,visualShareLowerBound=count>0 and visual/count or 0,
        unclassifiedOrOtherEvents=math.max(0,count-visual),capDropCounterSum=capDrops,
        recordedInteractions=interaction,sampledChanges=changed,issues=issues,
        inventoryCategories=snap.categories or {},
        recordIdentity="instanceId within scan; duplicate paths are not deduplicated",
        note="Visual count is a lower bound from capped class summaries. Other events are not necessarily gameplay. No causal claims, source or server logic."}
end
local function filenameFor(snap,extension,mode)
    local stamp=os.date("%Y%m%d_%H%M%S",snap.stamp)
    if snap.basicDiagnostics then
        return ("RUM_ClientDiagnostics_%s_SCAN%03d.%s"):format(stamp,snap.sequence,extension)
    end
    return ("RUM_GameplayScanner_%s_%s_SCAN%03d_V61_%s.%s"):
        format(tostring(game.PlaceId),stamp,snap.sequence,mode:upper(),extension)
end
local function reportHeader(snap)
    if snap.basicDiagnostics then
        return {schema="RUM_CLIENT_DIAGNOSTICS_V2",captureMode="local_ui_character_aggregate_only",
            scan={number=snap.sequence,timestamp=snap.stamp,time=snap.timeString,total=0},
            diagnostics=snap.basicDiagnostics,integrity=snap.integrity,
            note="No gameplay records collected. Basic diagnostics do not require QA."}
    end
    return {
        schema="RUM_GAMEPLAY_SCAN_V6_0",
        scope="CLIENT_VISIBLE_ONLY",
        auditNotes={coverageDenominator="enumerated selected roots only, not entire client or game",rootAssignment="enumeration origin, not path text",observation="passive sampled state; read failures or streaming can cause absence; no causal attribution",sourceAnalysis="not collected (no Script.Source, no decompilation, no require)",analysis="structural summaries computed from collected metadata; groupings are unverified labels",communicationAnalysis="inventory only",fieldCoverage="counts records with any captured fields; not a measure of all available properties"},
        captureMode="passive_inventory_and_local_state_deltas",
        note="Selected ordinary game roots plus local player data; all enumerated records retained except scanner UI and read failures. Basic media identifiers only. No asset contents, server-only data or network interception.",
        captureBoundaries={
            roots=snap.rootStatus,
            serverOnly={status="not_collected",reason="Server-only instances are not replicated to clients."},
            scriptSource={status="not_collected",reason="Script and module source is outside this passive inventory."},
            workspaceStreaming={status=snap.streamingStatus,enabled=snap.streamingEnabled,reason="Only currently replicated Workspace objects are visible; unobserved regions cannot be inferred."},
            otherPlayers={status="excluded_player_subtrees",reason="Only local player data is enumerated under Players. Replicated characters may appear in Workspace."},
            media={status="basic_metadata_only",reason="Selected readable IDs and attributes; no asset downloads or reconstruction."},
            eventTimeline={status=snap.eventTimeline and snap.eventTimeline.status or "not_recorded",reason="Local client signals in a bounded window; capped. Own interactions (prompt triggers, button and tool activations) are recorded with UI captions only. No network interception, remote hooks, keyboard/mouse logging or text-box content."},
            remoteArguments={status="not_collected",reason="Remote inventory contains type and path, not calls, argument schemas or server behavior."},
        },
        warnings={
            "Remote names/paths do not reveal parameters or server behavior.",
            "Instance IDs are unique within ONE scan, not across sessions.",
            "Same path can refer to multiple different Instances; use instanceId.",
            "RobloxCore, unrelated services and other Players subtrees are excluded; Workspace remains client-visible.",
            "Script and ModuleScript source code is not included.",
        },
        game={placeId=game.PlaceId,gameId=game.GameId,streamingEnabled=snap.streamingEnabled,streamingReadStatus=snap.streamingStatus},
        scan={number=snap.sequence,timestamp=snap.stamp,time=snap.timeString,
            total=snap.total,gameObjects=snap.gameCount,readErrors=snap.errors,durationSeconds=snap.durationSeconds,readDiagnostics=snap.readDiagnostics},
        totals={byClass=snap.byClass,byRoot=snap.byRoot,byCategory=snap.categories},
        integrity=snap.integrity,
        qaEvidence=snap.qaEvidence,
        analysis=snap.analysis,
        unifiedReport=snap.unifiedReport,
        publishedDiagnostics=snap.publishedDiagnostics,
        observationSummary={mode=snap.observation.mode,format=snap.observation.format,transitions=snap.observation.transitions,changedAcrossSamples=snap.observation.changedAcrossSamples,scope=snap.observation.scope,limitations=snap.observation.limitations},
    }
end

-- JSON serializer: accepts only plain data produced by the scanner.
-- Invalid UTF-8 bytes are escaped individually (U+00xx); nonfinite numbers
-- become explicit strings. Counts are included in the export diagnostics.
local function makeJsonEncoder()
    local arrayKeys={records=true,samples=true,transitions=true,baseline=true,changes=true,added=true,notObserved=true,rootErrors=true,tags=true,referenceIds=true,missingRoles=true,
        largestContainers=true,deepestObjects=true,topClasses=true,moduleContainers=true,nameGroups=true,
        duplicateNames=true,taggedModules=true,nestedUnderModule=true,volatileObjects=true,leaderstats=true,
        humanoids=true,remoteContainers=true,remotes=true,prompts=true,tools=true,screenGuis=true,buttons=true,
        valueContainers=true,attributeKeys=true,remoteTokens=true,valueTokens=true,toolTokens=true,
        promptTokens=true,featureClusters=true,
        events=true,highFrequencyObjects=true,busiestObjects=true,numericSeries=true,toggles=true,
        humanoidStateTransitions=true,attributeChanges=true,spawnedByClass=true,addedByClass=true,
        removedByClass=true,activityPerFiveSeconds=true,notObservedNow=true,notableAdded=true,
        notableNotObserved=true,classDelta=true,
        initialGuiState=true,panels=true,edges=true,interactions=true,bySource=true,followers=true,followedBy=true,
        clusters=true,spawnLocations=true,npcs=true,actionTexts=true,transientObjects=true,repeatedlyChanging=true,
        presentIn=true,scansUsed=true,sources=true,entries=true,limitations=true,changed=true}
    local stats={invalidUtf8Bytes=0,nonFiniteNumbers=0,unsupportedValues=0}
    local escapes={['"']='\\"',['\\']='\\\\',['\b']='\\b',['\f']='\\f',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
    local function quote(s)
        local function escapeAscii(t)
            return (t:gsub('[%z\1-\31"\\]',function(c)
                return escapes[c] or string.format('\\u%04x',string.byte(c))
            end))
        end
        if utf8.len(s) then return '"'..escapeAscii(s)..'"' end
        local out={'"'}
        local i=1
        local function cont(b) return b and b>=128 and b<=191 end
        while i<=#s do
            local a,b,c,d=s:byte(i,i+3)
            local n=0
            if a<128 then n=1
            elseif a>=194 and a<=223 and cont(b) then n=2
            elseif a>=224 and a<=239 and cont(b) and cont(c)
                and (a~=224 or b>=160) and (a~=237 or b<=159) then n=3
            elseif a>=240 and a<=244 and cont(b) and cont(c) and cont(d)
                and (a~=240 or b>=144) and (a~=244 or b<=143) then n=4 end
            if n==0 then
                out[#out+1]=string.format('\\u%04x',a)
                stats.invalidUtf8Bytes=stats.invalidUtf8Bytes+1
                i=i+1
            else
                out[#out+1]=escapeAscii(s:sub(i,i+n-1))
                i=i+n
            end
        end
        out[#out+1]='"'
        return table.concat(out)
    end
    local seen={}
    local function encode(v,field)
        local kind=type(v)
        if kind=='nil' then return 'null' end
        if kind=='boolean' then return v and 'true' or 'false' end
        if kind=='string' then return quote(v) end
        if kind=='number' then
            if v~=v or v==math.huge or v==-math.huge then
                stats.nonFiniteNumbers=stats.nonFiniteNumbers+1
                return quote(v~=v and 'NaN' or (v>0 and 'Infinity' or '-Infinity'))
            end
            return string.format('%.17g',v)
        end
        if kind~='table' or seen[v] then
            stats.unsupportedValues=stats.unsupportedValues+1
            return 'null'
        end
        seen[v]=true
        local count,max,allNumeric=0,0,true
        for k in pairs(v) do
            count=count+1
            if type(k)=='number' and k>=1 and k%1==0 then max=math.max(max,k)
            else allNumeric=false end
        end
        local out={}
        local array=allNumeric and max==count and (count>0 or arrayKeys[field]==true)
        if array then
            for i=1,count do out[i]=encode(v[i]) end
        else
            for k,item in pairs(v) do out[#out+1]=quote(tostring(k))..':'..encode(item,k) end
        end
        seen[v]=nil
        return (array and '[' or '{')..table.concat(out,',')..(array and ']' or '}')
    end
    return encode,stats
end

-- Write the existing observation schema incrementally. No additional capture.
-- Keep only a bounded batch of encoded observation rows in memory.
local function emitObservation(observation,encode,emit,pause)
    local metadata={}
    for k,v in pairs(observation) do if k~="samples" then metadata[k]=v end end
    local prefix=encode(metadata)
    emit(prefix:sub(1,-2)..(next(metadata) and "," or "")..'"samples":[')
    local arrayFields={baseline=true,changes=true,added=true,notObserved=true}
    local arrayOrder={"baseline","changes","added","notObserved"}
    for i,sample in ipairs(observation.samples or {}) do
        local fields={}
        for k,v in pairs(sample) do if not arrayFields[k] then fields[k]=v end end
        local prefix=encode(fields)
        if prefix=="{}" then prefix="{" else prefix=prefix:sub(1,-2) end
        emit((i==1 and "" or ",")..prefix)
        local needsComma=next(fields)~=nil
        for _,key in ipairs(arrayOrder) do
            local rows=sample[key]
            if rows~=nil then
                emit((needsComma and "," or "")..encode(key)..":[")
                needsComma=true
                local batch,bytes={},0
                for j,row in ipairs(rows) do
                    local encoded=(j==1 and "" or ",")..encode(row)
                    batch[#batch+1]=encoded;bytes=bytes+#encoded
                    if #batch>=350 or bytes>=256*1024 then
                        emit(table.concat(batch));batch={};bytes=0
                        if pause then pause() end
                    end
                end
                if #batch>0 then emit(table.concat(batch)) end
                emit("]")
            end
        end
        emit("}")
        if pause then pause() end
    end
    emit("]}")
end

local function saveAsSingleFile(snap,ext,mode)
    mode=mode=="compact" and "compact" or "full"
    if type(writefile)~="function" then
        return false,"Delta/executor khong ho tro writefile; khong the tao file."
    end
    local filename=filenameFor(snap,ext,mode)
    if type(isfile)=="function" then
        local base=filename:sub(1,-(#ext+2))
        local suffix=1
        while isfile(filename) do
            filename=base..("_R%03d."):format(suffix)..ext
            suffix=suffix+1
        end
    end
    local canAppend=type(appendfile)=="function"
    local header=reportHeader(snap)
    updateStatus("Dang chuan bi xuat "..mode:upper().."...")
    local exportRecords=snap.records or {}
    local projection={policy="full_inventory_v1",originalRecords=#exportRecords,
        exportedRecords=#exportRecords,omittedRecords=0,accountingBalanced=true,
        note="All records in the collected snapshot, not all objects or logic in the game."}
    if mode=="compact" then
        exportRecords,projection=compactProjection(exportRecords,function()
            if closed then error("Export cancelled") end
            task.wait()
        end)
    end
    local exportTotal=#exportRecords
    header.exportProjection=projection
    header.coverageAudit=buildCoverageAudit(snap)
    header.reportQuality=buildQualityReport(snap)
    header.exportMode=mode
    header.note="Passive inventory; scan totals describe the full collected snapshot, exportedRecords describes the selected projection. No source, server-only data or network interception."
    local jsonEncode,diagnostics=makeJsonEncoder()
    local function makeTxtHeader()
        if snap.basicDiagnostics then
            return "RUM CLIENT DIAGNOSTICS | NO GAMEPLAY RECORDS\n"..jsonEncode(header).."\n"
        end
        local out={
            "RUM GAME SCANNER | "..mode:upper().." TXT FILE",
            "Report quality: "..jsonEncode(header.reportQuality),
            "Export projection: "..jsonEncode(projection),
            "Coverage audit: "..jsonEncode(header.coverageAudit),
            "Selected game roots and local passive observation; no server-only data or Luau source",
            "PlaceId: "..tostring(game.PlaceId),
            "GameId: "..tostring(game.GameId),
            "Scan: #"..tostring(snap.sequence).."  "..snap.timeString,
            "Total: "..snap.total.."  ClientGame: "..snap.gameCount.."  ReadErrors: "..snap.errors,
            ("Remote: %d | Script: %d | Module: %d | GUI: %d | Value: %d"):
                format(snap.categories.Remote,snap.categories.Script,snap.categories.Module,
                    snap.categories.GUI,snap.categories.Value),
            "Format: [InstanceID; ParentID] [ClassName] Path | scope | depth | children | properties | attributes | tags",
            "Duplicate paths are possible. InstanceID is the key within this scan.",
            "CaptureBoundaries: "..jsonEncode(header.captureBoundaries),
            "ReadDiagnostics: "..jsonEncode(snap.readDiagnostics or {}),
            "Integrity: "..jsonEncode(snap.integrity or {}),
            "Observation format: baseline_then_deltas",
            "Observation mode: "..tostring(snap.observation.mode),
            "QA Evidence: "..jsonEncode(snap.qaEvidence or {}),
            "Unified QA Report: "..jsonEncode(snap.unifiedReport or {}),
            "Published QA Diagnostics: "..jsonEncode(snap.publishedDiagnostics or {}),
            "Analysis (explorer/modules/runtime/gameplay): "..jsonEncode(snap.analysis or {}),
            "Property coverage measures attempted allowlisted reads, not all Roblox properties.",
            "StreamingEnabled: "..tostring(snap.streamingEnabled).." ("..tostring(snap.streamingStatus)..")",
            string.rep("=",65),
        }
        return table.concat(out,"\n").."\n"
    end
    local function txtLine(r)
        local function plainField(v)
            if not utf8.len(v) or v:find("[%z\1-\31]") then return jsonEncode(v) end
            return v
        end
        local parts={("[%s;%s] [%s] %s | scope=%s"):
            format(r.instanceId,r.parentId,plainField(r.className),plainField(r.path),r.scope)}
        parts[#parts+1]="depth="..tostring(r.depth or 0)
        if r.childCount then parts[#parts+1]="children="..tostring(r.childCount) end
        if r.worldPosition then parts[#parts+1]="worldPosition="..jsonEncode(r.worldPosition) end
        if r.npc then parts[#parts+1]="npc=true" end
        if r.properties then parts[#parts+1]="properties="..jsonEncode(r.properties) end
        if r.attributes then parts[#parts+1]="attributes="..jsonEncode(r.attributes) end
        if r.tags then parts[#parts+1]="tags="..jsonEncode(r.tags) end
        return table.concat(parts," | ").."\n"
    end
    local stage="prepare"
    local written,expectedBytes=0,0
    local verification="not_available"
    local maxVerifiedBytes=(mode=="full" and 96 or 32)*1024*1024
    local ok,err=pcall(function()
        local chunks={}
        local started=false
        local function emit(data)
            stage="write at record "..written
            expectedBytes=expectedBytes+#data
            if expectedBytes>maxVerifiedBytes then error(mode:upper().." report exceeds "..(maxVerifiedBytes/1024/1024).." MiB safety budget; no complete export claimed") end
            if canAppend then
                if not started then writefile(filename,data);started=true
                else appendfile(filename,data) end
            else
                chunks[#chunks+1]=data
            end
        end
        stage="encode header"
        if ext=="txt" then emit(makeTxtHeader())
        else
            local encoded=jsonEncode(header)
            emit(encoded:sub(1,-2)..',"records":[')
        end
        local batch={}
        for i,r in ipairs(exportRecords) do
            if closed then error("Export cancelled") end
            stage="encode record "..i
            if ext=="txt" then batch[#batch+1]=txtLine(r)
            else batch[#batch+1]=(i==1 and "" or ",")..jsonEncode(r) end
            if #batch>=350 or i==exportTotal then
                written=i
                emit(table.concat(batch))
                batch={}
                setProgress(i,exportTotal)
                updateStatus(("%s %d/%d..."):format(ext:upper(),i,exportTotal))
                task.wait()
            end
        end
        if written~=exportTotal then error("Record count mismatch") end
        updateStatus("Dang xuat du lieu quan sat...")
        local function pauseTimeline()
            if closed then error("Export cancelled") end
            task.wait()
        end
        if ext=="txt" then
            emit("\nOBSERVATION: ")
            emitObservation(snap.observation,jsonEncode,emit,pauseTimeline)
            emit("\nEVENT_TIMELINE: "..jsonEncode(snap.eventTimeline or {status="not_recorded"}))
            emit("\nCOMPARISON: "..jsonEncode(snap.comparison or {status="not_available"}))
            emit("\nSTABILITY: "..jsonEncode(snap.stability or {status="not_available"}))
            emit("\nINTEGRITY: "..jsonEncode(snap.integrity).."\nEXPORT_DIAGNOSTICS: "..jsonEncode(diagnostics).."\nEND OF REPORT\n")
        else
            emit('],"observation":')
            emitObservation(snap.observation,jsonEncode,emit,pauseTimeline)
            emit(',"eventTimeline":'..jsonEncode(snap.eventTimeline or {status="not_recorded"}))
            emit(',"comparison":'..jsonEncode(snap.comparison or {status="not_available"}))
            emit(',"stability":'..jsonEncode(snap.stability or {status="not_available"}))
            emit(',"exportDiagnostics":'..jsonEncode(diagnostics)..',"exportedRecords":'..written..'}')
        end
        if not canAppend then
            stage="write complete file"
            writefile(filename,table.concat(chunks))
        end
        stage="verify file"
        if type(isfile)=="function" and not isfile(filename) then error("File not found after writing") end
        -- Avoid rereading huge exports on a memory-constrained client.
        if type(readfile)=="function" then
            local data=readfile(filename)
            if type(data)~="string" or #data~=expectedBytes then error("Export byte count mismatch") end
            if ext=="json" then
                local footer='"exportedRecords":'..written..'}'
                if data:sub(-#footer)~=footer then error("Incomplete JSON footer") end
            elseif data:sub(-14)~="END OF REPORT\n" then error("Incomplete TXT footer") end
            verification="size_and_footer_checked"
        elseif type(isfile)=="function" then verification="existence_only" end
    end)
    if not ok then
        -- A failed append can leave an incomplete file. Remove it if supported.
        local removed=false
        if type(delfile)=="function" then
            local removedOk,result=pcall(delfile,filename)
            removed=removedOk and result~=false
            if removed and type(isfile)=="function" then
                local checked,exists=pcall(isfile,filename)
                removed=checked and not exists
            end
        end
        return false,"Loi xuat ("..stage.."): "..tostring(err)..(removed and "" or "; file co the chua hoan chinh: "..filename)
    end
    diagnostics.expectedBytes=expectedBytes
    diagnostics.verification=verification
    diagnostics.exportedRecords=exportTotal
    diagnostics.omittedRecords=projection.omittedRecords
    return true,filename,diagnostics
end
local function exportNow(ext)
    if busy or closed then return end
    local snap=histories[selectedIndex]
    if not snap then log("WARN","Chưa có lần quét nào để xuất.");updateStatus("Chưa có lần quét nào để xuất.",true);return end
    busy=true
    setProgress(0,1)
    log("INFO","Xuất "..ext:upper().." lần #"..snap.sequence.."; một file.")
    scanBtn.Text="ĐANG XUẤT..."
    updateStatus("Dang xuat "..ext:upper().." tu lan #"..snap.sequence.." thanh 1 file...")
    task.spawn(function()
        local exportStarted=os.clock()
        local callOk,ok,path,diagnostics=xpcall(function() return saveAsSingleFile(snap,ext,exportMode) end,scannerTrace)
        if not callOk then path=tostring(ok);ok=false end
        if closed then return end
        busy=false
        scanBtn.Text="QUÉT LẠI"
        log("INFO",("Export result: %s; elapsed=%.2fs"):format(tostring(ok),os.clock()-exportStarted))
        if ok then
            lastSaved=path
            setProgress(1,1)
            log("INFO","Đã ghi file: "..path)
            if diagnostics then log("INFO",("%s: %d records; %d visual records summarized."):format(exportMode:upper(),diagnostics.exportedRecords,diagnostics.omittedRecords)) end
            if diagnostics then
                log(diagnostics.verification=="size_and_footer_checked" and "INFO" or "WARN",("File: %d bytes; %s"):format(diagnostics.expectedBytes,diagnostics.verification))
            end
            if diagnostics then
                local n=diagnostics.invalidUtf8Bytes+diagnostics.nonFiniteNumbers+diagnostics.unsupportedValues
                log(n>0 and "WARN" or "INFO",("Mã hóa: UTF-8 lỗi %d; số đặc biệt %d; giá trị không hỗ trợ %d."):format(diagnostics.invalidUtf8Bytes,diagnostics.nonFiniteNumbers,diagnostics.unsupportedValues))
            end
            updateStatus((diagnostics and diagnostics.verification=="size_and_footer_checked" and "Đã xuất, kiểm tra kích thước/đuôi: " or "Đã ghi (chưa kiểm tra toàn file): ")..path)
        else
            log("ERROR",path)
            updateStatus("Xuất thất bại. Xem Debug.",true)
        end
    end)
end
do
    local modeBtn=button(header,"FULL",UDim2.new(1,-151,0,16),UDim2.fromOffset(94,30),PALETTE.purple)
    modeBtn.TextSize=12
    on(modeBtn.MouseButton1Click,function()
        if busy or closed then return end
        exportMode=exportMode=="full" and "compact" or "full"
        modeBtn.Text=exportMode:upper()
        updateStatus(exportMode=="full" and "FULL: Giu tat ca ban ghi da thu thap." or "COMPACT: Tuy chon tom tat lop do hoa.")
    end)
end
on(txtBtn.MouseButton1Click,function() exportNow("txt") end)
on(jsonBtn.MouseButton1Click,function() exportNow("json") end)

renderHistory()
log("INFO","Khởi tạo Gameplay v6.1 Debug-only patch. Full / Compact Diagnostics / QA Optional. writefile="..tostring(type(writefile)=="function").."; appendfile="..tostring(type(appendfile)=="function"))
scanOnce()
