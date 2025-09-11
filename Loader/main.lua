-- Loader Key UI

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

local saveFile = "WataX_Key.txt"


local function saveKey(k)
    writefile(saveFile, k)
end


local function loadKey()
    if isfile(saveFile) then
        return readfile(saveFile)
    else
        return nil
    end
end


local function isKeyValid(k)
    local url = "https://raw.githubusercontent.com/WataXScript/WataXMountRavika/main/Loader/eldl/"..k
    local success, data = pcall(function()
        return game:HttpGet(url)
    end)
    return success and data ~= nil and data ~= ""
end


local gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
gui.Name = "WataXLoader"
gui.ResetOnSpawn = false


local mainFrame = Instance.new("Frame", gui)
mainFrame.Size = UDim2.new(0, 400, 0, 250)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -125)
mainFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
mainFrame.BorderSizePixel = 0
local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 15)


local gradient = Instance.new("UIGradient", mainFrame)
gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 130, 180)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(123, 104, 238))
}
gradient.Rotation = 45


local titleBar = Instance.new("Frame", mainFrame)
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundTransparency = 1

local title = Instance.new("TextLabel", titleBar)
title.Size = UDim2.new(1, 0, 1, 0)
title.Text = "WataX Key 🔑"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.BackgroundTransparency = 1

local titleStroke = Instance.new("UIStroke", title)
titleStroke.Thickness = 1.2
titleStroke.Color = Color3.fromRGB(0, 0, 0)


local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(0, 5, 0.5, -15)
closeBtn.Text = "✕"
closeBtn.TextSize = 18
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
local closeCorner = Instance.new("UICorner", closeBtn)
closeCorner.CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)


local minBtn = Instance.new("TextButton", titleBar)
minBtn.Size = UDim2.new(0, 30, 0, 30)
minBtn.Position = UDim2.new(1, -35, 0.5, -15)
minBtn.Text = "-"
minBtn.TextSize = 22
minBtn.Font = Enum.Font.GothamBold
minBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
minBtn.TextColor3 = Color3.fromRGB(255,255,255)
local minCorner = Instance.new("UICorner", minBtn)
minCorner.CornerRadius = UDim.new(0, 6)


local iconBtn = Instance.new("TextButton", gui)
iconBtn.Size = UDim2.new(0, 90, 0, 40)
iconBtn.Position = UDim2.new(1, -110, 1, -80)
iconBtn.BackgroundColor3 = Color3.fromRGB(123, 104, 238)
iconBtn.Text = "WataX"
iconBtn.TextSize = 18
iconBtn.TextColor3 = Color3.fromRGB(255,255,255)
iconBtn.Font = Enum.Font.GothamBold
iconBtn.Visible = false
local iconCorner = Instance.new("UICorner", iconBtn)
iconCorner.CornerRadius = UDim.new(0.5, 0)

local iconStroke = Instance.new("UIStroke", iconBtn)
iconStroke.Thickness = 1.5
iconStroke.Color = Color3.fromRGB(255, 255, 255)


local dragging = false
local dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    iconBtn.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end
iconBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = iconBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
iconBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)


minBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    iconBtn.Visible = true
end)
iconBtn.MouseButton1Click:Connect(function()
    iconBtn.Visible = false
    mainFrame.Visible = true
end)


local keyBox = Instance.new("TextBox", mainFrame)
keyBox.Size = UDim2.new(0.8, 0, 0, 40)
keyBox.Position = UDim2.new(0.1, 0, 0.35, 0)
keyBox.PlaceholderText = "Enter your key..."
keyBox.Text = ""
keyBox.TextSize = 18
keyBox.Font = Enum.Font.Gotham
keyBox.TextColor3 = Color3.fromRGB(0, 0, 0)
keyBox.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
local keyCorner = Instance.new("UICorner", keyBox)
keyCorner.CornerRadius = UDim.new(0, 8)


local submitBtn = Instance.new("TextButton", mainFrame)
submitBtn.Size = UDim2.new(0.5, 0, 0, 35)
submitBtn.Position = UDim2.new(0.25, 0, 0.55, 0)
submitBtn.Text = "Submit"
submitBtn.TextSize = 18
submitBtn.Font = Enum.Font.GothamBold
submitBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 100)
submitBtn.TextColor3 = Color3.fromRGB(255,255,255)
local submitCorner = Instance.new("UICorner", submitBtn)
submitCorner.CornerRadius = UDim.new(0, 10)


local buyKeyLabel = Instance.new("TextLabel", mainFrame)
buyKeyLabel.Size = UDim2.new(1, 0, 0, 30)
buyKeyLabel.Position = UDim2.new(0, 0, 0.75, 0)
buyKeyLabel.Text = "Beli Key di Discord 💻"
buyKeyLabel.TextSize = 16
buyKeyLabel.Font = Enum.Font.GothamBold
buyKeyLabel.TextColor3 = Color3.fromRGB(255,255,255)
buyKeyLabel.BackgroundTransparency = 1
local buyStroke = Instance.new("UIStroke", buyKeyLabel)
buyStroke.Thickness = 1
buyStroke.Color = Color3.fromRGB(0,0,0)


local discordBtn = Instance.new("TextButton", mainFrame)
discordBtn.Size = UDim2.new(0, 100, 0, 30)
discordBtn.Position = UDim2.new(0, 10, 1, -40)
discordBtn.Text = "Discord"
discordBtn.TextSize = 16
discordBtn.Font = Enum.Font.GothamBold
discordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
discordBtn.TextColor3 = Color3.fromRGB(255,255,255)
local discCorner = Instance.new("UICorner", discordBtn)
discCorner.CornerRadius = UDim.new(0, 8)
discordBtn.MouseButton1Click:Connect(function()
    setclipboard("https://discord.gg/tfNqRQsqHK")
end)

-- ==============================

-- ==============================


local lastKey = loadKey()
if lastKey and isKeyValid(lastKey) then
    print("Auto login berhasil, key valid:", lastKey)
    mainFrame.Visible = false
    loadstring(game:HttpGet("https://raw.githubusercontent.com/WataXScript/WataXMountRavika/main/Loader/WataX.lua"))()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/WataXScript/WataXMountRavika/main/Loader/mainmap449.lua"))()
end


submitBtn.MouseButton1Click:Connect(function()
    local inputKey = keyBox.Text
    if isKeyValid(inputKey) then
        saveKey(inputKey)
        print("Key benar:", inputKey)
        mainFrame.Visible = false
            loadstring(game:HttpGet("https://raw.githubusercontent.com/WataXScript/WataXMountRavika/main/Loader/WataX.lua"))()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/WataXScript/WataXMountRavika/main/Loader/mainmap449.lua"))()
    else
        print("Key salah:", inputKey)
    end
end)
