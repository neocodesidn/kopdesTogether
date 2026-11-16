local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ==========================================
-- KONFIGURASI REPOSITORY PLUGIN
-- ==========================================
local REPO_PLUGINS = "https://raw.githubusercontent.com/neocodesidn/kopdesTogether/main/plugins/"

local DaftarPlugin = {
    { id = "restok",        name = "Auto Restok (Gudang-Safe)",     file = "auto_restok.lua" },
    { id = "shop_ops",      name = "Auto Kasir & Anti-Pencuri",     file = "shop_ops.lua" },
    { id = "sound_system",  name = "Sound System (Remote Speaker)", file = "sound_system.lua" },
    { id = "payroll",       name = "Auto Payroll & Deposit",        file = "auto_payroll.lua" },
    { id = "smart_payroll", name = "Smart Payroll (Profit Share)",  file = "smart_payroll.lua" },
    { id = "sewa_pekerja",  name = "Sewa Pekerja (NPC Staff)",      file = "sewa_pekerja.lua" },
    { id = "quest",         name = "Auto Claim Quest",              file = "auto_quest.lua" },
    { id = "webhook",       name = "Discord Webhook V2",            file = "discord_log.lua" },
}

-- ==========================================
-- WINDOW UTAMA RAYFIELD VERSI BIASA (CLASSIC)
-- ==========================================
local Window = Rayfield:CreateWindow({
    Name = "Kopdes Together | v2.2",
    Icon = 0,
    LoadingTitle = "Kopdes Together Suite",
    LoadingSubtitle = "Cheese Dev • Modular Edition",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = false,
        FolderName = "KopdesTogether",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "cheesedev",
        RememberJoins = true
    },
    KeySystem = false
})

-- ==========================================
-- SHARED CORE API & EVENT BUS UNTUK PLUGIN
-- ==========================================
local EventListeners = {}
local LoadedPlugins = {}
local flagCounter = 0

local function nextFlag(prefix)
    flagCounter = flagCounter + 1
    return prefix .. "_" .. tostring(flagCounter)
end

local function formatRupiah(angka)
    local formatted = tostring(math.floor(tonumber(angka) or 0))
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1.%2")
        if k == 0 then break end
    end
    return formatted
end

local KopdesAPI = {
    Version = "2.2",
    Rayfield = Rayfield,
    Window = Window,
    Players = Players,
    LocalPlayer = LocalPlayer,
    PlayerGui = PlayerGui,
    HttpService = HttpService,
    Plot = workspace:WaitForChild("Plot1"),
    Remotes = {
        Kardus = ReplicatedStorage:WaitForChild("KardusRemotes"),
        Bank = ReplicatedStorage:WaitForChild("BankRemotes"),
        Quest = ReplicatedStorage:WaitForChild("QuestRemotes"),
    },
    FormatRupiah = formatRupiah,
}

function KopdesAPI.On(eventName, callback)
    if not EventListeners[eventName] then
        EventListeners[eventName] = {}
    end
    table.insert(EventListeners[eventName], callback)
end

function KopdesAPI.Emit(eventName, data)
    local list = EventListeners[eventName]
    if not list then return end
    for _, fn in ipairs(list) do
        task.spawn(pcall, fn, data)
    end
end

-- ==========================================
-- ADAPTER UI RAYFIELD CLASSIC (PASCALCASE)
-- ==========================================
function KopdesAPI.Notify(title, content, duration)
    pcall(function()
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3,
            Image = 4483362458,
        })
    end)
end

function KopdesAPI.CreateTab(name, iconId)
    return Window:CreateTab(name, iconId or 4483362458)
end

function KopdesAPI.Section(tab, title)
    return tab:CreateSection(title)
end

function KopdesAPI.Paragraph(tab, title, content)
    local ok, obj = pcall(function()
        return tab:CreateParagraph({
            Title = title,
            Content = content
        })
    end)
    return ok and obj or nil
end

function KopdesAPI.Button(tab, name, callback)
    return tab:CreateButton({
        Name = name,
        Callback = callback,
    })
end

function KopdesAPI.Toggle(tab, name, defaultVal, callback)
    return tab:CreateToggle({
        Name = name,
        CurrentValue = defaultVal or false,
        Flag = nextFlag("Toggle"),
        Callback = callback,
    })
end

function KopdesAPI.Slider(tab, name, minVal, maxVal, inc, suffix, defaultVal, callback)
    return tab:CreateSlider({
        Name = name,
        Range = { minVal, maxVal },
        Increment = inc or 1,
        Suffix = suffix or "",
        CurrentValue = defaultVal or minVal,
        Flag = nextFlag("Slider"),
        Callback = callback,
    })
end

function KopdesAPI.Dropdown(tab, name, options, defaultOpt, callback)
    local awal = defaultOpt or options[1]
    return tab:CreateDropdown({
        Name = name,
        Options = options,
        CurrentOption = awal and { awal } or {},
        MultipleOptions = false,
        Flag = nextFlag("Dropdown"),
        Callback = function(selected)
            local val = (typeof(selected) == "table" and selected[1]) or selected
            if callback then callback(val) end
        end,
    })
end

function KopdesAPI.Input(tab, name, placeholder, callback)
    return tab:CreateInput({
        Name = name,
        CurrentValue = "",
        PlaceholderText = placeholder or "",
        RemoveTextAfterFocusLost = false,
        Flag = nextFlag("Input"),
        Callback = callback,
    })
end

function KopdesAPI.SetElementText(elem, newText, newContent)
    if not elem then return end
    pcall(function()
        if elem.Set then
            if newContent ~= nil then
                elem:Set({ Title = newText, Content = newContent })
            else
                elem:Set(newText)
            end
        end
    end)
end

-- ==========================================
-- ANTI-AFK GLOBAL
-- ==========================================
local antiAfkEnabled = true
LocalPlayer.Idled:Connect(function()
    if antiAfkEnabled then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- ==========================================
-- TAB 1: DASHBOARD & PLUGIN MANAGER
-- ==========================================
local HomeTab = KopdesAPI.CreateTab("Dashboard", 4483362458)

KopdesAPI.Section(HomeTab, "Live Status Koperasi")
local StatusCard = KopdesAPI.Paragraph(
    HomeTab,
    "Memuat Data Koperasi...",
    "Menghubungkan ke server Bank & Plot1..."
)

KopdesAPI.Section(HomeTab, "Sistem & Keamanan AFK")
KopdesAPI.Toggle(HomeTab, "Anti-AFK (Cegah Kick 20 Menit)", true, function(val)
    antiAfkEnabled = val
end)

KopdesAPI.Button(HomeTab, "Salin Link Discord Cheese Dev", function()
    if setclipboard then
        setclipboard("https://cheesedev.biz.id")
        KopdesAPI.Notify("Tersalin!", "https://cheesedev.biz.id disalin ke clipboard.", 3)
    end
end)

-- ==========================================
-- FUNGSI PEMUAT PLUGIN
-- ==========================================
local function muatPluginDariUrl(pluginName, url)
    local okGet, source = pcall(function()
        return game:HttpGet(url .. "?t=" .. tostring(os.time()))
    end)
    if not okGet or not source or source == "" or source:find("404: Not Found") then
        return false, "File tidak ditemukan (404)"
    end

    local fn, errCompile = loadstring(source)
    if not fn then
        return false, "Syntax Error: " .. tostring(errCompile)
    end

    local okRun, errRun = pcall(fn, KopdesAPI)
    if not okRun then
        return false, "Runtime Error: " .. tostring(errRun)
    end

    return true, "Aktif"
end

local ringkasanPlugin = {}
for _, info in ipairs(DaftarPlugin) do
    local ok, status = muatPluginDariUrl(info.name, REPO_PLUGINS .. info.file)
    LoadedPlugins[info.id] = { name = info.name, ok = ok, status = status }
    table.insert(ringkasanPlugin, (ok and "[ON] " or "[ERR] ") .. info.name .. " (" .. status .. ")")
end

KopdesAPI.Section(HomeTab, "Plugin Manager")
KopdesAPI.Paragraph(
    HomeTab,
    "Modul Terpasang (" .. #DaftarPlugin .. " Plugin)",
    table.concat(ringkasanPlugin, "\n")
)

local customPluginUrl = ""
KopdesAPI.Input(HomeTab, "Load Custom Plugin via URL (.lua)", "https://raw.githubusercontent.com/...", function(txt)
    customPluginUrl = txt
end)

KopdesAPI.Button(HomeTab, "Jalankan Custom Plugin", function()
    if customPluginUrl == "" or not customPluginUrl:find("^https?://") then
        KopdesAPI.Notify("URL Tidak Valid", "Masukkan link raw GitHub .lua yang valid.", 3)
        return
    end
    local ok, status = muatPluginDariUrl("Custom Plugin", customPluginUrl)
    KopdesAPI.Notify(ok and "Plugin Dimuat!" or "Gagal Memuat Plugin", status, 4)
end)

-- ==========================================
-- LOOP LIVE DASHBOARD (UPDATE TIAP 4 DETIK)
-- ==========================================
local GetStateRemote = KopdesAPI.Remotes.Bank:WaitForChild("GetState")
local clickObject = KopdesAPI.Plot:WaitForChild("ClickObject")

task.spawn(function()
    while true do
        local saldoTokoText, saldoUserText = "-", "-"
        local okState, state = pcall(function()
            return GetStateRemote:InvokeServer()
        end)
        if okState and typeof(state) == "table" then
            if typeof(state.shopBalance) == "number" then
                saldoTokoText = "Rp " .. formatRupiah(state.shopBalance)
            end
            if typeof(state.userBalance) == "number" then
                saldoUserText = "Rp " .. formatRupiah(state.userBalance)
            end
        end

        local hariText = "Memantau..."
        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Text:match("^Hari%s*%d+") then
                hariText = obj.Text
                break
            end
        end

        local totalKardus = 0
        for _, v in ipairs(clickObject:GetChildren()) do
            if v.Name == "Kardus" then
                totalKardus = totalKardus + 1
            end
        end

        KopdesAPI.SetElementText(
            StatusCard,
            hariText .. "  •  Kardus Area: " .. totalKardus,
            "Kas Toko: " .. saldoTokoText .. "\nSaldo Pribadi: " .. saldoUserText
        )

        task.wait(4)
    end
end)
