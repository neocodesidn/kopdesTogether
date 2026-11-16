local API = ...

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local clickObject = API.Plot:WaitForChild("ClickObject")

-- ==========================================
-- STATE & KONFIGURASI OPERASIONAL TOKO
-- ==========================================
local autoKasirEnabled = false
local turboDoubleExec = false
local kasirDelay = 0.15

local antiPencuriEnabled = false
local walkSpeedValue = 16

-- Cache Remote agar tidak berat memindai GetDescendants() terus-menerus
local remoteCache = {}
local function getRemoteCached(remoteName)
    local cached = remoteCache[remoteName]
    if cached and cached.Parent then
        return cached
    end

    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == remoteName then
            remoteCache[remoteName] = obj
            return obj
        end
    end
    return nil
end

-- ==========================================
-- UI TAB: OPERASIONAL (KASIR & KEAMANAN)
-- ==========================================
local OpsTab = API.CreateTab("Operasional")

API.Section(OpsTab, "Auto Kasir & Boost Level Toko")

API.Slider(OpsTab, "Jeda Loop Kasir (Detik)", 0.05, 2.0, 0.05, " dtk", 0.15, function(val)
    kasirDelay = tonumber(val) or 0.15
end)

API.Toggle(OpsTab, "Auto Kasir / Boost Level", false, function(val)
    autoKasirEnabled = val
    API.Notify(
        val and "Auto Kasir Aktif" or "Auto Kasir Mati",
        val and "Memproses transaksi kasir & EXP toko otomatis." or "Auto kasir dihentikan.",
        3
    )
end)

API.Toggle(OpsTab, "Turbo 2x Eksekusi (Dupe Boost)", false, function(val)
    turboDoubleExec = val
end)

API.Section(OpsTab, "Keamanan Toko (Anti-Pencuri)")

API.Toggle(OpsTab, "Auto Pukul Pencuri (Plot1)", false, function(val)
    antiPencuriEnabled = val
    API.Notify(
        val and "Anti-Pencuri Aktif" or "Anti-Pencuri Mati",
        val and "Otomatis memukul pencuri yang masuk ke Plot1." or "Auto pukul pencuri dimatikan.",
        3
    )
end)

API.Section(OpsTab, "Utilitas Pemain")

API.Slider(OpsTab, "Kecepatan Jalan (Angkut Kardus)", 16, 120, 2, " Speed", 16, function(val)
    walkSpeedValue = tonumber(val) or 16
    local char = API.LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = walkSpeedValue
    end
end)

API.LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum and walkSpeedValue ~= 16 then
        task.wait(0.3)
        hum.WalkSpeed = walkSpeedValue
    end
end)

-- ==========================================
-- LOOP 1: AUTO KASIR & BOOST LEVEL
-- ==========================================
task.spawn(function()
    while true do
        if autoKasirEnabled then
            local mejaRemote = getRemoteCached("MejaKasirKlik")
            local kasirRemote = getRemoteCached("KasirSelesai")

            if mejaRemote and kasirRemote then
                pcall(function()
                    mejaRemote:FireServer()
                    kasirRemote:FireServer(0)
                end)

                if turboDoubleExec then
                    pcall(function()
                        mejaRemote:FireServer()
                        kasirRemote:FireServer(0)
                    end)
                end
            end
            task.wait(math.max(0.05, kasirDelay))
        else
            task.wait(0.5)
        end
    end
end)

-- ==========================================
-- LOOP 2: AUTO PUKUL SEMUA PENCURI DI PLOT1
-- ==========================================
task.spawn(function()
    while true do
        if antiPencuriEnabled then
            local pukulRemote = getRemoteCached("PukulPencuri")
            if pukulRemote then
                for _, obj in ipairs(clickObject:GetChildren()) do
                    if obj.Name == "Pencuri" then
                        pcall(function()
                            pukulRemote:FireServer(obj)
                        end)
                    end
                end
            end
            task.wait(0.8)
        else
            task.wait(1)
        end
    end
end)
