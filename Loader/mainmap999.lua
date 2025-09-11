-- mainmap926.lua
-- Versi: full UI preserved + multiple routers via GitHub raw JSON
-- Fitur utama:
--  - records default dihapus
--  - PathLinks: daftar raw JSON (name + url)
--  - Start = mulai dari checkpoint terdekat terhadap posisi player
--  - Start to End = play semua router berurutan (dari current router)
--  - Stop = hentikan segera
--  - Next / Prev untuk pindah router dan langsung play
--  - UI ada tombol Discord (buka link), list router, dan kontrol

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer

-- tunggu character & hrp
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

-- ===========================
-- CONFIG: edit manual PathLinks
-- masukkan link raw github JSON kalian di sini
-- contoh format file JSON: [{"pos":[x,y,z],"rot":[rx,ry,rz]}, ...]
local PathLinks = {
    { name = "Router 1 - Ravika", url = "https://raw.githubusercontent.com/WataXScript/WataXMountRavika/Loader/ravika.json" },
    -- contoh tambahan:
    -- { name = "Router 2 - test", url = "https://raw.githubusercontent.com/username/Loader/branch/replay2.json" },
    -- { name = "Router 3 - etc", url = "https://raw.githubusercontent.com/username/Loader/branch/replay3.json" },
}
-- ===========================

-- internal state
local records = {}            -- akan diisi tiap load dari github
local isPlaying = false       -- true saat sedang memutar frame dalam satu router
local isAutoPlaying = false   -- true saat Play All (Start to End) berjalan
local currentRouterIndex = 1  -- router yang aktif (index di PathLinks)

-- util: safe http load and json decode
local function LoadFromGitHub(url)
    if not url or url == "" then
        warn("[Replay] LoadFromGitHub: url kosong")
        return {}
    end
    local ok, res = pcall(function()
        -- HttpGet bisa error jika tidak diizinkan
        local response = game:HttpGet(url)
        -- decode
        local decoded = HttpService:JSONDecode(response)
        return decoded
    end)
    if not ok then
        warn("[Replay] Gagal ambil/parse JSON:", res)
        return {}
    end
    if type(res) ~= "table" then
        warn("[Replay] JSON bukan array/table.")
        return {}
    end
    return res
end

-- util: convert pos array [x,y,z] ke Vector3 (aman)
local function toVector3(posArr)
    if not posArr or type(posArr) ~= "table" then return nil end
    local x = tonumber(posArr[1]) or tonumber(posArr.x) or 0
    local y = tonumber(posArr[2]) or tonumber(posArr.y) or 0
    local z = tonumber(posArr[3]) or tonumber(posArr.z) or 0
    return Vector3.new(x, y, z)
end

-- cari index checkpoint terdekat di dalam `tbl` terhadap posisi `v3`
local function findNearestIndex(tbl, v3)
    if not tbl or #tbl == 0 then return 1 end
    local bestIdx = 1
    local bestDist = math.huge
    for i, step in ipairs(tbl) do
        local p = toVector3(step.pos)
        if p then
            local d = (p - v3).Magnitude
            if d < bestDist then
                bestDist = d
                bestIdx = i
            end
        end
    end
    return bestIdx
end

-- play records from given start index (synchronous)
local function playRecordsFrom(tbl, startIndex)
    if not tbl or #tbl == 0 then return end
    isPlaying = true
    for i = startIndex, #tbl do
        if not isPlaying then break end
        local step = tbl[i]
        if step and step.pos then
            local p = toVector3(step.pos)
            if p then
                if step.rot and type(step.rot) == "table" then
                    -- rot likely in radians? JSON from earlier looked like radians; use as-is
                    local rx = tonumber(step.rot[1]) or tonumber(step.rot.x) or 0
                    local ry = tonumber(step.rot[2]) or tonumber(step.rot.y) or 0
                    local rz = tonumber(step.rot[3]) or tonumber(step.rot.z) or 0
                    -- set CFrame: position + rotation
                    -- using CFrame.Angles expects radians, assuming JSON uses radian (as file suggests)
                    hrp.CFrame = CFrame.new(p) * CFrame.Angles(rx, ry, rz)
                else
                    hrp.CFrame = CFrame.new(p)
                end
            end
        end
        -- delay per-step: samakan ke FPS yang dipakai di logic lama
        task.wait(1/30)
    end
    isPlaying = false
end

-- Play single router by index.
-- if startNearest==true -> start from nearest checkpoint to player
local function PlayRouterByIndex(idx, startNearest)
    if not PathLinks[idx] then
        warn("[Replay] Router index tidak ada:", idx)
        return
    end
    local url = PathLinks[idx].url
    local name = PathLinks[idx].name or ("Router "..tostring(idx))
    -- load
    local data = LoadFromGitHub(url)
    if not data or #data == 0 then
        warn("[Replay] Data kosong untuk router:", name)
        return
    end
    records = data
    -- compute start index
    local startIndex = 1
    if startNearest then
        local posPlayer = hrp and hrp.Position or (player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart.Position) or Vector3.new(0,0,0)
        startIndex = findNearestIndex(records, posPlayer)
    end
    -- play synchronously
    playRecordsFrom(records, startIndex)
end

-- Play all sequential starting at startIdx (non-blocking)
local function PlayAllSequential(startIdx)
    if isAutoPlaying then return end
    isAutoPlaying = true
    task.spawn(function()
        for i = startIdx or 1, #PathLinks do
            if not isAutoPlaying then break end
            currentRouterIndex = i
            -- for the very first router in the sequence, startNearest = true
            local startNearest = (i == startIdx)
            PlayRouterByIndex(i, startNearest)
            -- small pause between routers if continuing
            if isAutoPlaying then
                task.wait(0.15)
            end
        end
        isAutoPlaying = false
    end)
end

-- Stop everything immediately
local function StopAll()
    isAutoPlaying = false
    isPlaying = false
end

-- =========================
-- UI: preserve UI features (panel, discord, controls, list)
-- Layout meniru UI sebelumnya (sesuaikan ukuran/posisi jika mau)
-- =========================
local guiName = "MainMap926_ReplayGui"
-- remove existing if any (prevent duplicates)
if player:FindFirstChild("PlayerGui") then
    local pg = player:FindFirstChild("PlayerGui")
    local old = pg:FindFirstChild(guiName)
    if old then old:Destroy() end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = guiName
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 420, 0, 300)
mainFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(28,28,28)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
local frameCorner = Instance.new("UICorner", mainFrame); frameCorner.CornerRadius = UDim.new(0,10)

-- Title
local title = Instance.new("TextLabel", mainFrame)
title.Name = "Title"
title.Size = UDim2.new(1, -20, 0, 30)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Text = "MainMap Replay v2"
title.TextColor3 = Color3.fromRGB(235,235,235)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18

-- Discord button (preserved)
local discordBtn = Instance.new("TextButton", mainFrame)
discordBtn.Name = "DiscordBtn"
discordBtn.Size = UDim2.new(0, 28, 0, 28)
discordBtn.Position = UDim2.new(1, -38, 0, 8)
discordBtn.Text = "D"
discordBtn.Font = Enum.Font.SourceSansBold
discordBtn.TextSize = 16
discordBtn.BackgroundColor3 = Color3.fromRGB(72, 101, 199)
local discordCorner = Instance.new("UICorner", discordBtn); discordCorner.CornerRadius = UDim.new(0,6)
-- contoh discord link (ganti sesuai kebutuhan)
local DiscordURL = "https://discord.gg/yourserver"

discordBtn.MouseButton1Click:Connect(function()
    -- membuka link di browser (hanya efektif jika environment mengizinkan)
    pcall(function()
        GuiService:OpenBrowserWindow(DiscordURL)
    end)
end)

-- Router list (scrolling)
local listFrame = Instance.new("Frame", mainFrame)
listFrame.Name = "ListFrame"
listFrame.Size = UDim2.new(0, 220, 0, 220)
listFrame.Position = UDim2.new(0, 10, 0, 46)
listFrame.BackgroundColor3 = Color3.fromRGB(22,22,22)
local listCorner = Instance.new("UICorner", listFrame); listCorner.CornerRadius = UDim.new(0,8)

local listTitle = Instance.new("TextLabel", listFrame)
listTitle.Size = UDim2.new(1, 0, 0, 26)
listTitle.Position = UDim2.new(0, 0, 0, 0)
listTitle.BackgroundTransparency = 1
listTitle.Text = "Routers"
listTitle.TextColor3 = Color3.fromRGB(220,220,220)
listTitle.Font = Enum.Font.SourceSansBold
listTitle.TextSize = 14

local scrolling = Instance.new("ScrollingFrame", listFrame)
scrolling.Name = "RouterScrolling"
scrolling.Size = UDim2.new(1, -12, 1, -36)
scrolling.Position = UDim2.new(0, 6, 0, 30)
scrolling.BackgroundTransparency = 1
scrolling.BorderSizePixel = 0
scrolling.CanvasSize = UDim2.new(0,0,0,0)
scrolling.ScrollBarThickness = 6

-- controls frame (right side)
local ctrlFrame = Instance.new("Frame", mainFrame)
ctrlFrame.Name = "ControlFrame"
ctrlFrame.Size = UDim2.new(0, 170, 0, 220)
ctrlFrame.Position = UDim2.new(0, 240, 0, 46)
ctrlFrame.BackgroundTransparency = 1

-- Buttons: Start, Start to End, Stop, Next, Prev
local btnStart = Instance.new("TextButton", ctrlFrame)
btnStart.Name = "BtnStart"
btnStart.Size = UDim2.new(1, 0, 0, 38)
btnStart.Position = UDim2.new(0, 0, 0, 0)
btnStart.Text = "▶ Start (nearest)"
btnStart.Font = Enum.Font.SourceSansBold
btnStart.TextSize = 16
btnStart.BackgroundColor3 = Color3.fromRGB(50,150,50)
local btnStartCorner = Instance.new("UICorner", btnStart); btnStartCorner.CornerRadius = UDim.new(0,6)

local btnStartAll = Instance.new("TextButton", ctrlFrame)
btnStartAll.Name = "BtnStartAll"
btnStartAll.Size = UDim2.new(1, 0, 0, 36)
btnStartAll.Position = UDim2.new(0, 0, 0, 46)
btnStartAll.Text = "⏵ Start to End"
btnStartAll.Font = Enum.Font.SourceSansBold
btnStartAll.TextSize = 15
btnStartAll.BackgroundColor3 = Color3.fromRGB(70,120,200)
local btnStartAllCorner = Instance.new("UICorner", btnStartAll); btnStartAllCorner.CornerRadius = UDim.new(0,6)

local btnPrev = Instance.new("TextButton", ctrlFrame)
btnPrev.Name = "BtnPrev"
btnPrev.Size = UDim2.new(0.48, -6, 0, 34)
btnPrev.Position = UDim2.new(0, 0, 0, 92)
btnPrev.Text = "⟸ Prev"
btnPrev.Font = Enum.Font.SourceSans
btnPrev.TextSize = 14
btnPrev.BackgroundColor3 = Color3.fromRGB(200,180,60)
local prevCorner = Instance.new("UICorner", btnPrev); prevCorner.CornerRadius = UDim.new(0,6)

local btnNext = Instance.new("TextButton", ctrlFrame)
btnNext.Name = "BtnNext"
btnNext.Size = UDim2.new(0.48, -6, 0, 34)
btnNext.Position = UDim2.new(0.52, 0, 0, 92)
btnNext.Text = "Next ⟹"
btnNext.Font = Enum.Font.SourceSans
btnNext.TextSize = 14
btnNext.BackgroundColor3 = Color3.fromRGB(200,180,60)
local nextCorner = Instance.new("UICorner", btnNext); nextCorner.CornerRadius = UDim.new(0,6)

local btnStop = Instance.new("TextButton", ctrlFrame)
btnStop.Name = "BtnStop"
btnStop.Size = UDim2.new(1, 0, 0, 34)
btnStop.Position = UDim2.new(0, 0, 0, 136)
btnStop.Text = "■ Stop"
btnStop.Font = Enum.Font.SourceSansBold
btnStop.TextSize = 15
btnStop.BackgroundColor3 = Color3.fromRGB(190,60,60)
local stopCorner = Instance.new("UICorner", btnStop); stopCorner.CornerRadius = UDim.new(0,6)

-- label info selected router
local infoLabel = Instance.new("TextLabel", ctrlFrame)
infoLabel.Name = "InfoLabel"
infoLabel.Size = UDim2.new(1, 0, 0, 44)
infoLabel.Position = UDim2.new(0, 0, 0, 176)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.fromRGB(230,230,230)
infoLabel.Font = Enum.Font.SourceSans
infoLabel.TextSize = 14
infoLabel.TextWrapped = true
infoLabel.Text = ""

-- populate list function
local function refreshRouterList()
    -- clear previous items
    for _, v in ipairs(scrolling:GetChildren()) do
        if v:IsA("TextButton") or v:IsA("TextLabel") then
            v:Destroy()
        end
    end
    local y = 0
    for i, p in ipairs(PathLinks) do
        local btn = Instance.new("TextButton", scrolling)
        btn.Name = "RouterBtn_"..i
        btn.Size = UDim2.new(1, -6, 0, 32)
        btn.Position = UDim2.new(0, 3, 0, y)
        btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
        btn.TextColor3 = Color3.fromRGB(230,230,230)
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 14
        btn.AutoButtonColor = true
        btn.Text = tostring(i)..". "..(p.name or ("Router "..i))
        btn.MouseButton1Click:Connect(function()
            currentRouterIndex = i
            -- highlight handled by update loop below
        end)
        y = y + 36
    end
    scrolling.CanvasSize = UDim2.new(0,0,0,y)
end

refreshRouterList()

-- update highlight coroutine
task.spawn(function()
    while true do
        for i, child in ipairs(scrolling:GetChildren()) do
            if child:IsA("TextButton") then
                local idx = tonumber(child.Name:match("RouterBtn_(%d+)")) or 0
                if idx == currentRouterIndex then
                    child.BackgroundColor3 = Color3.fromRGB(70,70,70)
                    child.Text = "▶ "..tostring(idx)..". "..(PathLinks[idx].name or ("Router "..idx))
                else
                    child.BackgroundColor3 = Color3.fromRGB(40,40,40)
                    child.Text = tostring(idx)..". "..(PathLinks[idx].name or ("Router "..idx))
                end
            end
        end
        -- update info label
        local cur = PathLinks[currentRouterIndex]
        if cur then
            infoLabel.Text = ("Selected: %s\nURL: %s"):format(cur.name or ("Router "..currentRouterIndex), tostring(cur.url or ""))
        else
            infoLabel.Text = "No router selected"
        end
        task.wait(0.12)
    end
end)

-- BUTTON BEHAVIOR

-- Start: play selected router starting from nearest checkpoint
btnStart.MouseButton1Click:Connect(function()
    if isPlaying then
        -- jika sedang play, maka tombol berfungsi sebagai stop toggle
        StopAll()
        return
    end
    local idx = currentRouterIndex
    task.spawn(function()
        PlayRouterByIndex(idx, true)
    end)
end)

-- Start to End (Play All sequential from currentRouterIndex)
btnStartAll.MouseButton1Click:Connect(function()
    if isAutoPlaying then
        StopAll()
        return
    end
    PlayAllSequential(currentRouterIndex)
end)

-- Prev: pindah router ke prev & play from nearest
btnPrev.MouseButton1Click:Connect(function()
    if #PathLinks == 0 then return end
    local prev = currentRouterIndex - 1
    if prev < 1 then prev = #PathLinks end
    currentRouterIndex = prev
    -- langsung play selected from nearest
    task.spawn(function() PlayRouterByIndex(currentRouterIndex, true) end)
end)

-- Next: pindah router ke next & play from nearest
btnNext.MouseButton1Click:Connect(function()
    if #PathLinks == 0 then return end
    local nxt = currentRouterIndex + 1
    if nxt > #PathLinks then nxt = 1 end
    currentRouterIndex = nxt
    task.spawn(function() PlayRouterByIndex(currentRouterIndex, true) end)
end)

-- Stop: hentikan apapun
btnStop.MouseButton1Click:Connect(function()
    StopAll()
end)

-- expose simple debug API (opsional)
_G.MainMap926_Replay = _G.MainMap926_Replay or {}
_G.MainMap926_Replay.PathLinks = PathLinks
_G.MainMap926_Replay.PlaySelectedNearest = function() task.spawn(function() PlayRouterByIndex(currentRouterIndex, true) end) end
_G.MainMap926_Replay.PlayAll = function() PlayAllSequential(1) end
_G.MainMap926_Replay.Stop = StopAll

-- Final note: jika mau tambahkan link baru cukup edit PathLinks table
-- atau gunakan _G.MainMap926_Replay.PathLinks = {...} di runtime lalu refresh list:
local function RefreshFromGlobal()
    if _G.MainMap926_Replay and type(_G.MainMap926_Replay.PathLinks) == "table" then
        PathLinks = _G.MainMap926_Replay.PathLinks
        refreshRouterList()
    end
end

-- support: listen untuk perubahan PathLinks via _G (opsional)
task.spawn(function()
    while true do
        RefreshFromGlobal()
        task.wait(1.0)
    end
end)


print("[MainMap926] Replay GUI ready. Routers:", #PathLinks)
