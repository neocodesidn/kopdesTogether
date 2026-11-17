local API = ...

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local KasirScanRemote = Remotes and Remotes:FindFirstChild("KasirScan")

-- ==========================================
-- KONFIGURASI AUTO KASIR & BOOST SCAN
-- ==========================================
local autoKasirEnabled = false
local kecepatanScan = 0.05 -- Semakin kecil semakin ngebut (turbo scan)
local sedangScan = false

local function scanSemuaBarangAktif()
    if not KasirScanRemote then return end
    
    -- Cari apakah ada objek item di meja kasir / area scanner yang butuh diskan
    local plot = API.Plot or workspace:FindFirstChild("Plot1")
    local clickObject = plot and plot:FindFirstChild("ClickObject")
    if not clickObject then return end

    -- Kita bisa mengirim rentang ID atau memicu scan otomatis secara berurutan
    pcall(function()
        for idBarang = 1, 50 do
            if not autoKasirEnabled then break end
            KasirScanRemote:FireServer(idBarang)
            task.wait(kecepatanScan)
        end
    end)
end

-- ==========================================
-- UI TAB: KASIR
-- ==========================================
local KasirTab = API.CreateTab("Kasir")

API.Section(KasirTab, "Informasi Auto Kasir")
local StatusKasirCard = API.Paragraph(
    KasirTab,
    "Modul Aktif: Turbo Kasir Scan",
    "Otomatis menembak remote KasirScan untuk mempercepat proses scan barang pembeli."
)

API.Section(KasirTab, "Kontrol Kecepatan & Auto Scan")
API.Slider(KasirTab, "Kecepatan Scan (Detik)", 0.01, 0.20, 0.01, " dtk", 0.05, function(val)
    kecepatanScan = tonumber(val) or 0.05
end)

API.Toggle(KasirTab, "Auto Kasir (Scan Otomatis)", false, function(val)
    autoKasirEnabled = val
    API.Notify(
        val and "Auto Kasir Aktif" or "Auto Kasir Mati",
        val and "Sistem otomatis men-scan barang di kasir dengan kecepatan tinggi." or "Auto kasir dihentikan.",
        3
    )
end)

API.Button(KasirTab, "Scan Cepat Sekarang (1x Burst)", function()
    task.spawn(function()
        if not KasirScanRemote then
            API.Notify("Error", "Remote KasirScan tidak ditemukan!", 3)
            return
        end
        
        -- Kirim rentang ID 1 sampai 20 seketika untuk melibas antrean kasir
        for i = 1, 20 do
            KasirScanRemote:FireServer(i)
            task.wait(0.02)
        end
        API.Notify("Selesai", "Burst scan kasir berhasil dieksekusi.", 2)
    end)
end)

-- ==========================================
-- LOOP PEMANTAUAN OTOMATIS KASIR
-- ==========================================
task.spawn(function()
    while true do
        if autoKasirEnabled then
            scanSemuaBarangAktif()
        end
        task.wait(0.5)
    end
end)
