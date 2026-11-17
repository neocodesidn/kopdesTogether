local API = ...

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
local jedaScan = 0.08
local sedangMemproses = false

-- ==========================================
-- DETEKSI BARANG PELANGGAN DI MEJA KASIR
-- ==========================================
local function dapatkanMejaKasir()
    for _, obj in ipairs(clickObject:GetChildren()) do
        if obj.Name:lower():find("kasir") then
            return obj
        end
    end
    return nil
end

local function cariBarangDiMejaKasir()
    local meja = dapatkanMejaKasir()
    if not meja then return {}, nil end

    local daftarItem = {}
    for _, desc in ipairs(meja:GetDescendants()) do
        -- Barang belanjaan pelanggan di meja biasanya memiliki ClickDetector atau Highlight hijau
        if desc:IsA("ClickDetector") then
            local parentObj = desc.Parent
            -- Abaikan ClickDetector utama milik meja kasir (untuk buka/tutup kasir)
            if parentObj and parentObj ~= meja and not parentObj.Name:lower():find("meja") and not parentObj.Name:lower():find("kursi") then
                table.insert(daftarItem, {
                    obj = parentObj,
                    cd = desc
                })
            end
        end
    end

    -- Urutkan berdasarkan nama / posisi agar scan berurutan dari barang ke-1
    table.sort(daftarItem, function(a, b)
        local numA = tonumber(a.obj.Name:match("%d+")) or 0
        local numB = tonumber(b.obj.Name:match("%d+")) or 0
        if numA ~= numB then return numA < numB end
        return a.obj.Name < b.obj.Name
    end)

    return daftarItem, meja
end

local function prosesScanMejaKasir()
    if sedangMemproses then return 0 end
    local daftarItem = cariBarangDiMejaKasir()
    if #daftarItem == 0 then return 0 end

    sedangMemproses = true
    local jumlahTerscan = 0

    pcall(function()
        for indeks, item in ipairs(daftarItem) do
            if not item.obj or not item.obj.Parent then continue end

            -- 1. Picu ClickDetector bawaan barang agar KasirClient memindahkan item ke paper bag
            if item.cd and fireclickdetector then
                pcall(fireclickdetector, item.cd)
            end

            -- 2. Kirim nomor urut valid sesuai indeks barang di meja ke KasirScan
            if KasirScanRemote then
                KasirScanRemote:FireServer(indeks)
            end

            jumlahTerscan = jumlahTerscan + 1
            task.wait(jedaScan)
        end
    end)

    sedangMemproses = false
    return jumlahTerscan
end

-- ==========================================
-- UI TAB: KASIR
-- ==========================================
local KasirTab = API.CreateTab("Kasir")

API.Section(KasirTab, "Status Meja Kasir (" .. PlotToko.Name .. ")")
local StatusKasirCard = API.Paragraph(
    KasirTab,
    "Memindai Meja Kasir...",
    "Pastikan karakter sudah klik 'Buka Kasir' (tombol Tutup Kasir muncul di layar)."
)

API.Section(KasirTab, "Kontrol Auto Scan Kasir")
API.Slider(KasirTab, "Jeda Antar Barang (Detik)", 0.03, 0.30, 0.01, " dtk", 0.08, function(val)
    jedaScan = tonumber(val) or 0.08
end)

API.Toggle(KasirTab, "Auto Scan Kasir (Otomatis)", false, function(val)
    autoKasirEnabled = val
    API.Notify(
        val and "Auto Kasir Aktif" or "Auto Kasir Mati",
        val and "Otomatis men-scan semua barang pelanggan di meja kasir." or "Auto kasir dihentikan.",
        3
    )
end)

API.Button(KasirTab, "Scan Barang di Meja Sekarang (1x)", function()
    task.spawn(function()
        local hasil = prosesScanMejaKasir()
        if hasil > 0 then
            API.Notify("Scan Selesai", "Berhasil men-scan " .. tostring(hasil) .. " barang di meja kasir.", 2)
        else
            API.Notify("Meja Kosong", "Tidak ada barang pelanggan terdeteksi di MejaKasir.", 3)
        end
    end)
end)

-- ==========================================
-- LOOP PEMANTAUAN MEJA KASIR
-- ==========================================
task.spawn(function()
    while true do
        local items = cariBarangDiMejaKasir()

        API.SetElementText(
            StatusKasirCard,
            "Barang di Meja Kasir: " .. tostring(#items) .. " item",
            autoKasirEnabled
                and (#items > 0 and "Status: Men-scan barang pelanggan..." or "Status: Siaga (Menunggu pelanggan)")
                or "Status: Nonaktif"
        )

        if autoKasirEnabled and #items > 0 then
            prosesScanMejaKasir()
        end

        task.wait(0.35)
    end
end)
