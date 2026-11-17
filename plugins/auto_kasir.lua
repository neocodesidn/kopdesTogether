local API = ...

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local KasirScanRemote = Remotes and Remotes:FindFirstChild("KasirScan")

local PlotToko = API.Plot or Workspace:WaitForChild("Plot1")
local clickObject = PlotToko:WaitForChild("ClickObject")

-- ==========================================
-- KONFIGURASI AUTO KASIR
-- ==========================================
local autoKasirEnabled = false
local autoAmbilPembayaranEnabled = true
local jedaScan = 0.12
local sedangMemproses = false

-- Daftar objek sistem di Workspace yang bukan barang scan
local abaikanWorkspace = {
    camera = true,
    terrain = true,
    kotoranspawned = true,
    map = true,
    paperbag = true,
    kartudebit = true,
    ["pengangkut barang"] = true
}

local function apakahKarakterPemain(obj)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and (obj == plr.Character or obj:IsDescendantOf(plr.Character)) then
            return true
        end
    end
    return false
end

local function dapatkanPosisiMejaKasir()
    local meja = clickObject:FindFirstChild("MejaKasir")
    if meja then
        local ok, cf = pcall(function() return meja:GetPivot() end)
        if ok and cf then return cf.Position end
    end

    local folderKasir = PlotToko:FindFirstChild("Kasir")
    local p2 = folderKasir and folderKasir:FindFirstChild("Point2")
    if p2 and p2:IsA("BasePart") then
        return p2.Position
    end

    return nil
end

local function ambilPosisiObjek(obj)
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        local ok, cf = pcall(function() return obj:GetPivot() end)
        if ok and cf then return cf.Position end
    end
    return nil
end

-- ==========================================
-- DETEKSI BARANG PELANGGAN DI WORKSPACE & HIGHLIGHT
-- ==========================================
local function cariBarangDiMejaKasir()
    local posKasir = dapatkanPosisiMejaKasir()
    if not posKasir then return {} end

    local daftarItem = {}
    local sudahTerdata = {}

    local function tambahkanJikaValid(obj)
        if not obj or sudahTerdata[obj] then return end
        if not (obj:IsA("Model") or obj:IsA("BasePart")) then return end

        local lower = obj.Name:lower()
        if abaikanWorkspace[lower] or lower:match("^plot%d+$") or lower:find("npc") or lower:find("pembeli") then
            return
        end
        if apakahKarakterPemain(obj) then return end

        local pos = ambilPosisiObjek(obj)
        if pos and (pos - posKasir).Magnitude <= 12 then
            sudahTerdata[obj] = true
            table.insert(daftarItem, obj)
        end
    end

    -- 1. Cek objek yang sedang diberi Highlight hijau di Workspace
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Highlight") and child.Adornee then
            tambahkanJikaValid(child.Adornee)
        end
    end

    -- 2. Cek model/part barang belanjaan langsung di dalam Workspace sekitar meja kasir
    for _, child in ipairs(Workspace:GetChildren()) do
        tambahkanJikaValid(child)
    end

    return daftarItem
end

-- ==========================================
-- AUTO AMBIL UANG TUNAI & KARTU DEBIT DI WORKSPACE
-- ==========================================
local function cekDanAmbilPembayaran()
    if not autoAmbilPembayaranEnabled then return end
    local posKasir = dapatkanPosisiMejaKasir()
    if not posKasir then return end

    for _, child in ipairs(Workspace:GetChildren()) do
        local pos = ambilPosisiObjek(child)
        if pos and (pos - posKasir).Magnitude <= 12 then
            local lower = child.Name:lower()
            local isKartuAtauUang = lower:find("kartu") or lower:find("uang") or lower:find("cash") or lower:find("money")

            for _, desc in ipairs(child:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled then
                    local aksi = tostring(desc.ActionText):lower()
                    if isKartuAtauUang or aksi:find("ambil") then
                        if fireproximityprompt then
                            pcall(fireproximityprompt, desc)
                        end
                    end
                elseif desc:IsA("ClickDetector") and isKartuAtauUang then
                    if fireclickdetector then
                        pcall(fireclickdetector, desc)
                    end
                end
            end
        end
    end
end

-- ==========================================
-- EKSEKUSI SCAN BARANG
-- ==========================================
local function prosesScanKasir()
    if sedangMemproses or not KasirScanRemote then return 0 end
    local daftarItem = cariBarangDiMejaKasir()
    if #daftarItem == 0 then return 0 end

    sedangMemproses = true
    local totalItem = #daftarItem

    pcall(function()
        for indeks = 1, totalItem do
            if not autoKasirEnabled and indeks > 1 then break end
            KasirScanRemote:FireServer(indeks)
            task.wait(jedaScan)
        end
    end)

    sedangMemproses = false
    return totalItem
end

-- ==========================================
-- UI TAB: KASIR
-- ==========================================
local KasirTab = API.CreateTab("Kasir")

API.Section(KasirTab, "Status Meja Kasir (" .. PlotToko.Name .. ")")
local StatusKasirCard = API.Paragraph(
    KasirTab,
    "Memindai Workspace Kasir...",
    "Pastikan sudah klik 'Buka Kasir' (tombol Tutup Kasir aktif di layar)."
)

API.Section(KasirTab, "Kontrol Auto Scan & Pembayaran")
API.Slider(KasirTab, "Jeda Antar Scan (Detik)", 0.05, 0.40, 0.01, " dtk", 0.12, function(val)
    jedaScan = tonumber(val) or 0.12
end)

API.Toggle(KasirTab, "Auto Scan Kasir (Otomatis)", false, function(val)
    autoKasirEnabled = val
    API.Notify(
        val and "Auto Kasir Aktif" or "Auto Kasir Mati",
        val and "Otomatis mendeteksi barang di Workspace meja kasir dan men-scan." or "Auto kasir dihentikan.",
        3
    )
end)

API.Toggle(KasirTab, "Auto Ambil Uang & Kartu Debit", true, function(val)
    autoAmbilPembayaranEnabled = val
end)

API.Button(KasirTab, "Scan Barang Sekarang (1x)", function()
    task.spawn(function()
        local hasil = prosesScanKasir()
        if hasil > 0 then
            API.Notify("Scan Selesai", "Men-scan " .. tostring(hasil) .. " barang di meja kasir.", 2)
        else
            API.Notify("Meja Kosong", "Tidak ada barang pelanggan terdeteksi di sekitar MejaKasir.", 3)
        end
    end)
end)

-- ==========================================
-- LOOP PEMANTAUAN KASIR
-- ==========================================
task.spawn(function()
    while true do
        local items = cariBarangDiMejaKasir()

        API.SetElementText(
            StatusKasirCard,
            "Barang di Meja (Workspace): " .. tostring(#items) .. " item",
            autoKasirEnabled
                and (#items > 0 and "Status: Men-scan " .. tostring(#items) .. " barang..." or "Status: Siaga (Menunggu pelanggan)")
                or "Status: Nonaktif"
        )

        if autoKasirEnabled then
            if #items > 0 then
                prosesScanKasir()
            end
            cekDanAmbilPembayaran()
        end

        task.wait(0.30)
    end
end)
