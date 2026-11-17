local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- KONFIGURASI REPOSITORY & ANTI-CACHE
-- ==========================================
local BASE_URL = "https://raw.githubusercontent.com/neocodesidn/roblox/refs/heads/main/kopdesTogether/"

local DaftarPlugin = {
    { id = "restok",        name = "Auto Restok (Gudang-Safe)",     file = "auto_restok.lua" },
    { id = "input",         name = "Auto Input (Universal Rak)",    file = "auto_input2.lua" },
    --{ id = "shop_ops",      name = "Auto Kasir & Anti-Pencuri",     file = "shop_ops.lua" },
    --{ id = "sound_system",  name = "Sound System (Remote Speaker)", file = "sound_system.lua" },
    { id = "payroll",       name = "Auto Payroll & Deposit",        file = "auto_payroll.lua" },
    { id = "smart_payroll", name = "Smart Payroll (Profit Share)",  file = "smart_payroll.lua" },
    { id = "auto_kasir",    name = "Auto Kasir (Turbo Scan)",       file = "auto_kasir.lua" },
    { id = "sewa_pekerja",  name = "Sewa Pekerja (NPC Staff)",      file = "sewa_pekerja.lua" },
    { id = "quest",         name = "Auto Claim Quest",              file = "auto_quest.lua" },
    { id = "webhook",       name = "Discord Webhook V2",            file = "discord_log.lua" },
}

local function ambilScript(relativePath)
    local url = BASE_URL .. relativePath .. "?t=" .. tostring(math.floor(tick()))
    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or not source or source == "" then
        warn("[Kopdes Loader] Gagal mengunduh:", relativePath)
        return nil
    end

    local fn, compileErr = loadstring(source, "@" .. relativePath)
    if not fn then
        warn("[Kopdes Loader] Syntax error di " .. relativePath .. ":", compileErr)
        return nil
    end
    return fn
end

-- ==========================================
-- INISIALISASI CORE UI (core/ui.lua)
-- ==========================================
local uiChunk = ambilScript("core/ui.lua")
if not uiChunk then
    warn("[Kopdes Loader] Core UI gagal dimuat, proses dihentikan.")
    return
end

local UI = uiChunk()

-- ==========================================
-- DETEKSI PLOT & REMOTES UNTUK API PLUGIN
-- ==========================================
local function cariPlotMilikSendiri()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name:match("^Plot%d+$") and obj:FindFirstChild("ClickObject") then
            local ownerAttr = obj:GetAttribute("Owner") or obj:GetAttribute("UserId")
            if ownerAttr == LocalPlayer.Name or ownerAttr == LocalPlayer.UserId then
                return obj
            end
            for _, val in ipairs(obj:GetDescendants()) do
                if (val:IsA("StringValue") and val.Value == LocalPlayer.Name)
                    or (val:IsA("IntValue") and val.Value == LocalPlayer.UserId)
                    or (val:IsA("ObjectValue") and val.Value == LocalPlayer) then
                    return obj
                end
            end
        end
    end
    return Workspace:FindFirstChild("Plot1")
end

local API = {
    LocalPlayer = LocalPlayer,
    Plot = cariPlotMilikSendiri(),
    Plugins = DaftarPlugin,
    Remotes = {
        Kardus = ReplicatedStorage:FindFirstChild("KardusRemotes"),
        Main = ReplicatedStorage:FindFirstChild("Remotes"),
        Quest = ReplicatedStorage:FindFirstChild("QuestRemotes")
    },

    -- Jembatan Komponen UI (Slider otomatis menjadi Input Nominal)
    CreateTab = UI.CreateTab,
    Section = UI.Section,
    Paragraph = UI.Paragraph,
    SetElementText = UI.SetElementText,
    Input = UI.Input,
    Slider = UI.Slider,
    Toggle = UI.Toggle,
    Button = UI.Button,
    Notify = UI.Notify
}

-- ==========================================
-- EKSEKUSI SEMUA PLUGIN AKTIF
-- ==========================================
for _, plugin in ipairs(DaftarPlugin) do
    local pluginPath = "plugins/" .. plugin.file
    local pluginFn = ambilScript(pluginPath)

    if pluginFn then
        task.spawn(function()
            local ok, runtimeErr = pcall(pluginFn, API)
            if not ok then
                warn("[Kopdes Loader] Runtime error di [" .. plugin.name .. "] (" .. plugin.file .. "):", runtimeErr)
                if API.Notify then
                    API.Notify("Error: " .. plugin.name, "Gagal menjalankan " .. plugin.file, 4)
                end
            end
        end)
    else
        if API.Notify then
            API.Notify("Gagal Unduh", plugin.name .. " (" .. plugin.file .. ") tidak ditemukan.", 4)
        end
    end
end
