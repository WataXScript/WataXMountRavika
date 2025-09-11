-- WataX Replay (JSON loader + preserve original UI)
-- Full version: UI from mainmap926.lua left intact, but routes are loaded from JSON (GitHub raw).

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local hrp = nil

local function refreshHRP(char)
    if not char then
        char = player.Character or player.CharacterAdded:Wait()
    end
    hrp = char:WaitForChild("HumanoidRootPart")
end
if player.Character then refreshHRP(player.Character) end
player.CharacterAdded:Connect(refreshHRP)

local frameTime = 1/30
local playbackRate = 1.0
local isRunning = false
local routes = {}

-- ==================== CONFIG: ganti URL di bawah sesuai repo kamu ====================
-- Format: ["Label"] = "https://raw.githubusercontent.com/username/repo/branch/filename.json"
-- Contoh: ["CP0 → CP1"] = "https://raw.githubusercontent.com/me/replays/main/cp0to1.json"
local routeLinks = {
    -- contohnya satu route: bisa diganti
    ["CP0 → CP1"] = "https://raw.githubusercontent.com/WataXScript/WataXMountRavika/main/Loader/ravika.json",
    -- tambahin baris lain kalau mau banyak route
    -- ["CP1 → CP2"] = "https://raw.githubusercontent.com/username/repo/branch/cp1to2.json",
}
-- ====================================================================================

-- Helper: fetch & decode JSON safely
local function fetchJson(url)
    if not url or url == "" then return nil, "no url" end
    local ok, res = pcall(function()
        -- use :HttpGet (executor) or HttpService:GetAsync (Studio with Http enabled)
        if game.HttpGet then
            return game:HttpGet(url)
        else
            return HttpService:GetAsync(url)
        end
    end)
    if not ok then return nil, res end
    local ok2, data = pcall(function() return HttpService:JSONDecode(res) end)
    if not ok2 then return nil, data end
    return data
end

-- Convert an array of frame-objects (with pos & rot) to CFrame table
local function convertFrameArrayToCFrames(arr)
    local out = {}
    if type(arr) ~= "table" then return out end
    for _, f in ipairs(arr) do
        if type(f) == "table" then
            local pos = f.pos or f.position or f.Pos or f.Position
            local rot = f.rot or f.rotation or f.Rot or f.Rotation or {0,0,0}
            if pos and #pos >= 3 then
                local x,y,z = pos[1], pos[2], pos[3]
                local rx,ry,rz = 0,0,0
                if type(rot) == "table" and #rot >= 3 then rx,ry,rz = rot[1],rot[2],rot[3] end
                table.insert(out, CFrame.new(x,y,z) * CFrame.Angles(rx,ry,rz))
            end
        end
    end
    return out
end

-- Try to insert routes from decoded JSON. Supports two JSON styles:
-- 1) A single array of frames (then we add it under the provided label)
-- 2) An object with keys = route names, values = arrays of frames (we add each)
local function tryInsertRoutesFromData(decoded, fallbackLabel)
    if not decoded then return false end
    -- case 1: array of frames
    if type(decoded) == "table" and #decoded > 0 then
        local frames = convertFrameArrayToCFrames(decoded)
        if #frames > 0 then
            table.insert(routes, { tostring(fallbackLabel or "Route"), frames })
            return true
        end
    end
    -- case 2: object with multiple routes
    if type(decoded) == "table" then
        local inserted = false
        for k,v in pairs(decoded) do
            if type(v) == "table" and #v > 0 then
                local frames = convertFrameArrayToCFrames(v)
                if #frames > 0 then
                    table.insert(routes, { tostring(k), frames })
                    inserted = true
                end
            end
        end
        return inserted
    end
    return false
end

-- Load all routes configured in routeLinks
for label, url in pairs(routeLinks) do
    local data, err = fetchJson(url)
    if data then
        local ok = tryInsertRoutesFromData(data, label)
        if ok then
            print("[WataX] Loaded route:", label, "(from", url, ")")
        else
            warn("[WataX] No frames found in:", url, "(label:", label, ")")
        end
    else
        warn("[WataX] Failed to fetch:", url, "error:", err)
    end
end

-- If no routes were loaded, warn user (UI tetap berfungsi but Start won't do anything)
if #routes == 0 then
    warn("[WataX] Warning: no routes loaded. Edit 'routeLinks' at the top of the script to point to your JSON files.")
end

-- -------------------- existing helper functions (kept intact) --------------------
local function getNearestRoute()
    local nearestIdx, dist = 1, math.huge
    if hrp then
        local pos = hrp.Position
        for i,data in ipairs(routes) do
            for _,cf in ipairs(data[2]) do
                local d = (cf.Position - pos).Magnitude
                if d < dist then
                    dist = d
                    nearestIdx = i
                end
            end
        end
    end
    return nearestIdx
end

local function getNearestFrameIndex(frames)
    local startIdx, dist = 1, math.huge
    if hrp then
        local pos = hrp.Position
        for i,cf in ipairs(frames) do
            local d = (cf.Position - pos).Magnitude
            if d < dist then
                dist = d
                startIdx = i
            end
        end
    end
    if startIdx >= #frames then
        startIdx = math.max(1, #frames - 1)
    end
    return startIdx
end

local function lerpCF(fromCF, toCF)
    local duration = frameTime / math.max(0.05, playbackRate)
    local t = 0
    while t < duration do
        if not isRunning then break end
        local dt = task.wait()
        t += dt
        local alpha = math.min(t / duration, 1)
        if hrp and hrp.Parent and hrp:IsDescendantOf(workspace) then
            hrp.CFrame = fromCF:Lerp(toCF, alpha)
        end
    end
end

local function runRouteOnce()
    if #routes == 0 then return end
    if not hrp then refreshHRP() end
    isRunning = true
    local idx = getNearestRoute()
    print("▶ Start CP:", routes[idx][1])
    local frames = routes[idx][2]
    if #frames < 2 then isRunning = false return end
    local startIdx = getNearestFrameIndex(frames)
    for i = startIdx, #frames - 1 do
        if not isRunning then break end
        lerpCF(frames[i], frames[i+1])
    end
    isRunning = false
end

local function runAllRoutes()
    if #routes == 0 then return end
    if not hrp then refreshHRP() end
    isRunning = true
    local idx = getNearestRoute()
    print("⏩ Start To End dari:", routes[idx][1])
    for r = idx, #routes do
        if not isRunning then break end
        local frames = routes[r][2]
        if #frames < 2 then continue end
        -- PATCH: always use nearest frame index, not just for the first route
        local startIdx = getNearestFrameIndex(frames)
        for i = startIdx, #frames - 1 do
            if not isRunning then break end
            lerpCF(frames[i], frames[i+1])
        end
    end
    isRunning = false
end

local function stopRoute()
    if isRunning then
        print("⏹ Stop ditekan")
    end
    isRunning = false
end
-- ---------------------------------------------------------------------------------

-- -------------------- UI (exactly as in original mainmap926.lua) -----------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WataXReplay"
screenGui.ResetOnSpawn = false
screenGui.Parent = game.CoreGui

local frame = Instance.new("Frame",screenGui)
frame.Size = UDim2.new(0,280,0,180)
frame.Position = UDim2.new(0.5,-140,0.5,-90)
frame.BackgroundColor3 = Color3.fromRGB(35,35,40)
frame.Active = true
frame.Draggable = true
frame.BackgroundTransparency = 0.05
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,12)

local title = Instance.new("TextLabel",frame)
title.Size = UDim2.new(1,0,0,32)
title.Text = "WataX Menu"
title.BackgroundColor3 = Color3.fromRGB(55,55,65)
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
Instance.new("UICorner", title).CornerRadius = UDim.new(0,12)

local startCP = Instance.new("TextButton",frame)
startCP.Size = UDim2.new(0.5,-7,0,42)
startCP.Position = UDim2.new(0,5,0,44)
startCP.Text = "Start CP"
startCP.BackgroundColor3 = Color3.fromRGB(60,200,80)
startCP.TextColor3 = Color3.fromRGB(255,255,255)
startCP.Font = Enum.Font.GothamBold
startCP.TextScaled = true
Instance.new("UICorner", startCP).CornerRadius = UDim.new(0,10)
startCP.MouseButton1Click:Connect(runRouteOnce)

local stopBtn = Instance.new("TextButton",frame)
stopBtn.Size = UDim2.new(0.5,-7,0,42)
stopBtn.Position = UDim2.new(0.5,2,0,44)
stopBtn.Text = "Stop"
stopBtn.BackgroundColor3 = Color3.fromRGB(220,70,70)
stopBtn.TextColor3 = Color3.fromRGB(255,255,255)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextScaled = true
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0,10)
stopBtn.MouseButton1Click:Connect(stopRoute)

local startAll = Instance.new("TextButton",frame)
startAll.Size = UDim2.new(1,-10,0,42)
startAll.Position = UDim2.new(0,5,0,96)
startAll.Text = "Start To End"
startAll.BackgroundColor3 = Color3.fromRGB(70,120,220)
startAll.TextColor3 = Color3.fromRGB(255,255,255)
startAll.Font = Enum.Font.GothamBold
startAll.TextScaled = true
Instance.new("UICorner", startAll).CornerRadius = UDim.new(0,10)
startAll.MouseButton1Click:Connect(runAllRoutes)

-- Close button (top-left)
local closeBtn = Instance.new("TextButton", frame)
closeBtn.Size = UDim2.new(0,30,0,30)
closeBtn.Position = UDim2.new(0,0,0,0)
closeBtn.Text = "✖"
closeBtn.BackgroundColor3 = Color3.fromRGB(220,60,60)
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,8)
closeBtn.MouseButton1Click:Connect(function()
    if screenGui then screenGui:Destroy() end
end)

-- Minimize / Bubble
local miniBtn = Instance.new("TextButton", frame)
miniBtn.Size = UDim2.new(0,30,0,30)
miniBtn.Position = UDim2.new(1,-30,0,0)
miniBtn.Text = "—"
miniBtn.BackgroundColor3 = Color3.fromRGB(80,80,200)
miniBtn.TextColor3 = Color3.fromRGB(255,255,255)
miniBtn.Font = Enum.Font.GothamBold
miniBtn.TextScaled = true
Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(0,8)

local bubbleBtn = Instance.new("TextButton", screenGui)
bubbleBtn.Size = UDim2.new(0,80,0,46)
bubbleBtn.Position = UDim2.new(0,20,0.7,0)
bubbleBtn.Text = "WataX"
bubbleBtn.BackgroundColor3 = Color3.fromRGB(0,140,220)
bubbleBtn.TextColor3 = Color3.fromRGB(255,255,255)
bubbleBtn.Font = Enum.Font.GothamBold
bubbleBtn.TextScaled = true
bubbleBtn.Visible = false
bubbleBtn.Active = true
bubbleBtn.Draggable = true
Instance.new("UICorner", bubbleBtn).CornerRadius = UDim.new(0,14)

miniBtn.MouseButton1Click:Connect(function()
    frame.Visible = false
    bubbleBtn.Visible = true
end)
bubbleBtn.MouseButton1Click:Connect(function()
    frame.Visible = true
    bubbleBtn.Visible = false
end)

-- Discord button (bottom-left)
local discordBtn = Instance.new("TextButton", frame)
discordBtn.Size = UDim2.new(0,100,0,30)
discordBtn.AnchorPoint = Vector2.new(0,1)
discordBtn.Position = UDim2.new(0,5,1,-5)
discordBtn.Text = "Discord"
discordBtn.BackgroundColor3 = Color3.fromRGB(90,90,220)
discordBtn.TextColor3 = Color3.fromRGB(255,255,255)
discordBtn.Font = Enum.Font.GothamBold
discordBtn.TextScaled = true
Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0,8)
-- ---------------------------------------------------------------------------------

print("[WataX] UI ready. Routes loaded:")
for i,rt in ipairs(routes) do
    print(i, rt[1], "frames:", #rt[2])
end
