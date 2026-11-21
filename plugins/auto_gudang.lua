local API = ...

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KardusRemotes = (API and API.Remotes and API.Remotes.Kardus) or ReplicatedStorage:WaitForChild("KardusRemotes", 10)
local PickupKardusRemote = KardusRemotes and KardusRemotes:FindFirstChild("PickupKardus")
local PlaceOilRemote = KardusRemotes and KardusRemotes:FindFirstChild("PlaceOil")
local DropKardusRemote = KardusRemotes and (KardusRemotes:FindFirstChild("DropKardus") or KardusRemotes:FindFirstChild("ThrowKardus"))

local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
local NotifikasiRemote = RemotesFolder and RemotesFolder:FindFirstChild("Notifikasi")

-- ==========================================
-- LANGSUNG KE Workspace.Plot1
-- ==========================================
local PlotToko = Workspace:WaitForChild("Plot1")
local clickObject = PlotToko:WaitForChild("ClickObject")

-- ==========================================
-- KONFIGURASI & STATE DATA SYNC GUDANG
-- ==========================================
local autoGudangEnabled = false
local jedaAntarSlot = 0.25
local sedangMenyimpan = false

local cacheSlotKosong = {}
local totalRakTerdeteksi = 0
local dataSudahSync = false

local slotDitolakServer = {}
local kardusDitolakSementara = {}
local slotTerakhirDitembak = nil
local percobaanGagalTangan = 0

local kataGenerik = {
    kardus = true, karduspicked = true, box = true, handle = true, part = true,
    meshpart = true, union = true, unionoperation = true, lid = true, tutup = true,
    model = true, clickdetector = true, proximityprompt = true, surfacegui = true,
    billboardgui = true, weld = true, motor6d = true, attachment = true, decal = true, texture = true
}

if NotifikasiRemote and NotifikasiRemote:IsA("RemoteEvent") then
    NotifikasiRemote.OnClientEvent:Connect(function(pesan)
        if typeof(pesan) == "string" and slotTerakhirDitembak then
            local pLower = pesan:lower()
            if pLower:find("sudah terisi") or pLower:find("penuh") or pLower:find("tidak sesuai") or pLower:find("ada kardus") then
                slotDitolakServer[slotTerakhirDitembak] = tick() + 120
            end
        end
    end)
end

-- ==========================================
-- DETEKSI NAMA PRODUK KARDUS & DAFTAR KARDUS LANTAI
-- ==========================================
local function deteksiNamaProdukKardus(objKardus)
    if not objKardus then return nil end

    for _, desc in ipairs(objKardus:GetDescendants()) do
        if desc:IsA("ObjectValue") and desc.Value and desc.Value.Name ~= "" then
            return desc.Value.Name
        end
    end

    for _, attr in ipairs({ "ItemName", "Product", "Nama", "Item", "Produk", "Barang", "DisplayName" }) do
        local v = objKardus:GetAttribute(attr)
        if typeof(v) == "string" and v ~= "" then
            return v
        end
    end

    for _, desc in ipairs(objKardus:GetDescendants()) do
        for _, attr in ipairs({ "ItemName", "Product", "Nama", "Item", "Produk", "Barang", "DisplayName" }) do
            local v = desc:GetAttribute(attr)
            if typeof(v) == "string" and v ~= "" then
                return v
            end
        end

        if desc:IsA("StringValue") and desc.Value ~= "" then
            local bersih = desc.Value:gsub("%s*%b()", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if bersih ~= "" and not kataGenerik[bersih:lower()] then
                return bersih
            end
        elseif desc:IsA("TextLabel") and desc.Text ~= "" then
            local bersih = desc.Text:gsub("%s*%b()", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if bersih ~= "" and not bersih:match("^[xX]?%d+[/]?%d*$") and not kataGenerik[bersih:lower()] then
                return bersih
            end
        end
    end

    return nil
end

local function ambilDaftarKardusLantai()
    local daftar = {}
    for _, v in ipairs(clickObject:GetChildren()) do
        if v.Name == "Kardus" then
            local skip = kardusDitolakSementara[v] and tick() < kardusDitolakSementara[v]
            if not skip then
                table.insert(daftar, {
                    obj = v,
                    nama = deteksiNamaProdukKardus(v)
                })
            end
        end
    end
    return daftar
end

-- ==========================================
-- TAHAP SCAN & SYNC DATA GUDANG (RakPenyimpananX.InputRak.RakX)
-- ==========================================
local function apakahSlotGudangKosong(slotObj)
    if not slotObj or not slotObj.Parent then return false end

    if slotDitolakServer[slotObj] and tick() < slotDitolakServer[slotObj] then
        return false
    end

    -- Kosong jika di dalam RakX tidak ada child .Kardus
    if slotObj:FindFirstChild("Kardus") then
        return false
    end

    return true
end

local function scanDanSyncDataGudang()
    local hasilSlotKosong = {}
    local daftarRakGudang = {}
    local sudahTercatat = {}

    for _, desc in ipairs(PlotToko:GetDescendants()) do
        if not sudahTercatat[desc] and desc.Name:lower():find("rakpenyimpanan") and desc:FindFirstChild("InputRak") then
            sudahTercatat[desc] = true
            table.insert(daftarRakGudang, desc)
        end
    end

    table.sort(daftarRakGudang, function(a, b)
        local numA = tonumber(a.Name:match("%d+")) or 9999
        local numB = tonumber(b.Name:match("%d+")) or 9999
        if numA ~= numB then return numA < numB end
        return a.Name < b.Name
    end)

    for _, modelGudang in ipairs(daftarRakGudang) do
        local inputRak = modelGudang:FindFirstChild("InputRak")
        if inputRak then
            local daftarSlotRak = {}
            for _, childSlot in ipairs(inputRak:GetChildren()) do
                if childSlot.Name:lower():match("^rak%d+$") then
                    table.insert(daftarSlotRak, childSlot)
                end
            end

            table.sort(daftarSlotRak, function(a, b)
                local numA = tonumber(a.Name:match("%d+")) or 9999
                local numB = tonumber(b.Name:match("%d+")) or 9999
                return numA < numB
            end)

            for _, slotObj in ipairs(daftarSlotRak) do
                if apakahSlotGudangKosong(slotObj) then
                    table.insert(hasilSlotKosong, slotObj)
                end
            end
        end
    end

    cacheSlotKosong = hasilSlotKosong
    totalRakTerdeteksi = #daftarRakGudang
    dataSudahSync = true

    return cacheSlotKosong, totalRakTerdeteksi
end

-- ==========================================
-- MANAJEMEN KARDUS DI TANGAN & ANTI-STUCK
-- ==========================================
local function cariKardusPickedDiKarakter()
    local char = API.LocalPlayer.Character
    if not char then return nil end
    local upperTorso = char:FindFirstChild("UpperTorso")
    if upperTorso then
        local p = upperTorso:FindFirstChild("KardusPicked")
        if p then return p end
    end
    return char:FindFirstChild("KardusPicked", true)
end

local function lepasKardusStuckDiTangan()
    local picked = cariKardusPickedDiKarakter()
    if not picked then
        percobaanGagalTangan = 0
        return
    end

    if DropKardusRemote then
        pcall(function() DropKardusRemote:FireServer() end)
        pcall(function() DropKardusRemote:FireServer(picked) end)
        task.wait(0.15)
    end

    percobaanGagalTangan = 0
end

local function picuInteraksiKardusJarakJauh(kardusObj)
    if not kardusObj or not kardusObj.Parent then return end

    for _, desc in ipairs(kardusObj:GetDescendants()) do
        if desc:IsA("ClickDetector") and fireclickdetector then
            local jarakAsli = desc.MaxActivationDistance
            pcall(function() desc.MaxActivationDistance = 99999 end)
            local ok = pcall(fireclickdetector, desc, 0)
            if not ok then
                pcall(fireclickdetector, desc)
            end
            pcall(function() desc.MaxActivationDistance = jarakAsli end)
        elseif desc:IsA("ProximityPrompt") and fireproximityprompt then
            local jarakAsli = desc.MaxActivationDistance
            local losAsli = desc.RequiresLineOfSight
            pcall(function()
                desc.MaxActivationDistance = 99999
                desc.RequiresLineOfSight = false
                fireproximityprompt(desc)
            end)
            pcall(function()
                desc.MaxActivationDistance = jarakAsli
                desc.RequiresLineOfSight = losAsli
            end)
        end
    end
end

local function ambilSatuKardusKeTangan(detailKardus)
    local existing = cariKardusPickedDiKarakter()
    if existing then
        local namaTangan = deteksiNamaProdukKardus(existing)
        if PickupKardusRemote and namaTangan then
            pcall(function() PickupKardusRemote:FireServer(existing, namaTangan) end)
        end
        return existing
    end

    local kardusObj = detailKardus.obj
    if not kardusObj or not kardusObj.Parent then return nil end

    picuInteraksiKardusJarakJauh(kardusObj)

    local picked = nil
    for step = 1, 24 do
        task.wait(0.05)
        picked = cariKardusPickedDiKarakter()
        if picked then break end

        if step == 8 and PickupKardusRemote and kardusObj.Parent then
            pcall(function() PickupKardusRemote:FireServer(kardusObj) end)
            if detailKardus.nama then
                pcall(function() PickupKardusRemote:FireServer(kardusObj, detailKardus.nama) end)
            end
        end
    end

    if not picked then
        kardusDitolakSementara[kardusObj] = tick() + 5
        return nil
    end

    percobaanGagalTangan = 0
    local namaFinal = deteksiNamaProdukKardus(picked) or detailKardus.nama
    if PickupKardusRemote then
        if namaFinal then
            pcall(function() PickupKardusRemote:FireServer(picked, namaFinal) end)
        else
            pcall(function() PickupKardusRemote:FireServer(picked) end)
        end
        task.wait(0.08)
    end

    return picked
end

-- ==========================================
-- UPDATE UI STATUS & ALUR: SCAN -> SYNC -> ISI -> SCAN
-- ==========================================
local StatusGudangCard

local function perbaruiStatusUI(faseTeks)
    if not StatusGudangCard then return end

    local kardusLantai = ambilDaftarKardusLantai()
    local statusDefault = autoGudangEnabled and "Aktif (Siaga)" or "Nonaktif"

    API.SetElementText(
        StatusGudangCard,
        "Slot Gudang Kosong: " .. tostring(#cacheSlotKosong) .. " (" .. tostring(totalRakTerdeteksi) .. " Rak)  |  Kardus di Lantai: " .. tostring(#kardusLantai),
        "Status: " .. (faseTeks or statusDefault)
    )
end

local function jalankanSiklusGudang(sekaliJalan)
    if sedangMenyimpan then return end
    if not PickupKardusRemote or not PlaceOilRemote then return end

    sedangMenyimpan = true

    task.spawn(function()
        local tersimpanCount = 0
        local ok, err = pcall(function()
            -- LANGKAH 1: SCAN & SYNC DATA AWAL SEBELUM MEMULAI PENGISIAN
            perbaruiStatusUI("Scanning & Sync Data Gudang...")
            task.wait(0.20)
            local daftarSlotKosong = scanDanSyncDataGudang()
            perbaruiStatusUI("Data Sync Selesai (" .. tostring(#daftarSlotKosong) .. " slot kosong)")

            if #daftarSlotKosong == 0 then
                return
            end

            local daftarKardusAwal = ambilDaftarKardusLantai()
            if #daftarKardusAwal == 0 and not cariKardusPickedDiKarakter() then
                return
            end

            API.Notify(
                "Sync Gudang Selesai",
                "Ditemukan " .. tostring(#daftarSlotKosong) .. " slot kosong. Pastikan NPC/player lain tidak mengisi gudang saat proses berjalan.",
                3
            )
            task.wait(0.25)

            -- LANGKAH 2: LOOP SIKLUS (ISI -> SCAN ULANG -> ISI -> SCAN ULANG)
            while sekaliJalan or autoGudangEnabled do
                -- Ambil kardus dulu ke tangan
                local picked = cariKardusPickedDiKarakter()
                if not picked then
                    local daftarKardus = ambilDaftarKardusLantai()
                    if #daftarKardus == 0 then break end
                    picked = ambilSatuKardusKeTangan(daftarKardus[1])
                end

                if not picked then break end

                -- SCAN ULANG TEPAT SEBELUM TEMBAK (memastikan tidak diisi NPC/player lain saat kardus diambil)
                perbaruiStatusUI("Scanning slot kosong...")
                local slotTersedia = scanDanSyncDataGudang()
                if #slotTersedia == 0 then
                    break
                end

                local targetSlot = slotTersedia[1]
                if not targetSlot or not targetSlot.Parent or targetSlot:FindFirstChild("Kardus") then
                    continue
                end

                -- ISI 1 SLOT (2 TAHAP: Pickup -> PlaceOil SAJA)
                perbaruiStatusUI("Mengisi ke " .. targetSlot.Parent.Parent.Name .. "." .. targetSlot.Name .. "...")
                slotTerakhirDitembak = targetSlot
                PlaceOilRemote:FireServer(targetSlot)

                -- Tunggu konfirmasi server sampai .Kardus muncul di dalam RakX
                local terkonfirmasi = false
                for _ = 1, 16 do
                    task.wait(0.10)
                    if targetSlot:FindFirstChild("Kardus") then
                        terkonfirmasi = true
                        break
                    end
                end

                -- SCAN ULANG SETELAH PENGISIAN UNTUK SYNC DATA TERBARU
                scanDanSyncDataGudang()
                perbaruiStatusUI()

                if terkonfirmasi then
                    tersimpanCount = tersimpanCount + 1
                    percobaanGagalTangan = 0
                    task.wait(jedaAntarSlot)
                else
                    slotDitolakServer[targetSlot] = tick() + 60
                    percobaanGagalTangan = percobaanGagalTangan + 1
                    if percobaanGagalTangan >= 2 then
                        lepasKardusStuckDiTangan()
                    end
                    task.wait(0.15)
                end
            end
        end)

        if not ok and err then
            warn("[AutoGudang Error]:", err)
        end

        sedangMenyimpan = false
        scanDanSyncDataGudang()
        perbaruiStatusUI()

        if sekaliJalan then
            API.Notify("Selesai", "Berhasil menyimpan " .. tostring(tersimpanCount) .. " kardus ke gudang.", 3)
        end
    end)
end

-- ==========================================
-- TRIGGER EVENT-DRIVEN (ANTI-LAG & REALTIME SYNC)
-- ==========================================
clickObject.ChildAdded:Connect(function(child)
    if child.Name == "Kardus" then
        task.wait(0.25)
        if not sedangMenyimpan then
            scanDanSyncDataGudang()
            perbaruiStatusUI()
            if autoGudangEnabled then
                jalankanSiklusGudang(false)
            end
        end
    end
end)

clickObject.ChildRemoved:Connect(function(child)
    if child.Name == "Kardus" and not sedangMenyimpan then
        perbaruiStatusUI()
    end
end)

-- ==========================================
-- UI TAB: [RESTOCK] GUDANG (RAPI & TO THE POINT)
-- ==========================================
local GudangTab = API.CreateTab("[RESTOCK] Gudang")

-- 1. ATAS: DATA SLOT GUDANG KOSONG & KARDUS LANTAI
StatusGudangCard = API.Paragraph(
    GudangTab,
    "Slot Gudang Kosong: 0 (0 Rak)  |  Kardus di Lantai: 0",
    "Status: Nonaktif"
)

-- 2. TENGAH: PENJELASAN CARA PEMAKAIAN & PERINGATAN
API.Paragraph(
    GudangTab,
    "Cara Pemakaian & Peringatan",
    "Sistem akan melakukan Scan & Sync slot kosong terlebih dahulu sebelum mengisi. Pastikan tidak ada player lain atau NPC gudang yang sedang mengisi rak bersamaan."
)

-- 3. BAWAH: FITUR & KONTROL
API.Section(GudangTab, "Kontrol")

API.Toggle(GudangTab, "Auto Simpan ke Gudang", false, function(val)
    autoGudangEnabled = val
    if val then
        jalankanSiklusGudang(false)
    else
        scanDanSyncDataGudang()
        perbaruiStatusUI("Nonaktif")
    end
end)

API.Slider(GudangTab, "Jeda Antar Kardus", 0.20, 1.50, 0.05, " dtk", 0.25, function(val)
    jedaAntarSlot = tonumber(val) or 0.25
end)

API.Button(GudangTab, "Simpan Semua Sekarang (1x)", function()
    jalankanSiklusGudang(true)
end)

API.Button(GudangTab, "Scan & Sync Ulang Data", function()
    slotDitolakServer = {}
    kardusDitolakSementara = {}
    percobaanGagalTangan = 0
    perbaruiStatusUI("Scanning & Sync Data Gudang...")
    task.wait(0.10)
    local slotKosong, totalRak = scanDanSyncDataGudang()
    perbaruiStatusUI()
    API.Notify("Sync Selesai", "Tersinkron: " .. tostring(#slotKosong) .. " slot kosong dari " .. tostring(totalRak) .. " rak.", 2)
end)

-- Scan awal saat plugin dimuat
scanDanSyncDataGudang()
perbaruiStatusUI()
