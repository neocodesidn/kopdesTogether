local API = ...

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KardusRemotes = API.Remotes.Kardus or ReplicatedStorage:WaitForChild("KardusRemotes", 10)
local PickupKardusRemote = KardusRemotes and KardusRemotes:WaitForChild("PickupKardus", 5)
local PlaceOilRemote = KardusRemotes and KardusRemotes:WaitForChild("PlaceOil", 5)
local PlaceOilDoneRemote = KardusRemotes and KardusRemotes:WaitForChild("PlaceOilDone", 5)

-- ==========================================
-- DETEKSI OTOMATIS PLOT MILIK SENDIRI
-- ==========================================
local function dapatkanPlotToko()
    local lp = API.LocalPlayer
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name:match("^Plot%d+$") and obj:FindFirstChild("ClickObject") then
            local ownerAttr = obj:GetAttribute("Owner") or obj:GetAttribute("UserId")
            if ownerAttr == lp.Name or ownerAttr == lp.UserId then
                return obj
            end
            for _, val in ipairs(obj:GetDescendants()) do
                if (val:IsA("StringValue") and val.Value == lp.Name)
                    or (val:IsA("IntValue") and val.Value == lp.UserId)
                    or (val:IsA("ObjectValue") and val.Value == lp) then
                    return obj
                end
            end
        end
    end
    return API.Plot or Workspace:WaitForChild("Plot1")
end

local PlotToko = dapatkanPlotToko()
local clickObject = PlotToko:WaitForChild("ClickObject")

-- ==========================================
-- KONFIGURASI & PENGAMAN ANTI-KARDUS HILANG
-- ==========================================
local autoPlaceRakEnabled = false
local jedaAntarRak = 0.30
local sedangMengisiRak = false

-- Menyimpan papan rak yang ditolak server ("rak penuh/terisi") agar tidak diulang-ulang
local rakDitolakServer = {}

-- Menyimpan kardus yang sudah terlanjur diambil ke server agar tidak mengambil kardus baru sebelum ditaruh
local kardusTertahanDiServer = nil

-- Filter agar kardus berisi perabotan/kulkas tidak ikut diambil sebagai stok barang
local kataKunciFurnitur = { "rakkecil", "rakbelanja", "kasir", "meja", "kulkas", "freezer", "lampu", "pintu", "dinding", "etalase" }

local function apakahFurnitur(nama)
    local lower = tostring(nama):lower()
    for _, kata in ipairs(kataKunciFurnitur) do
        if lower:find(kata, 1, true) then
            return true
        end
    end
    return false
end

-- ==========================================
-- DETEKSI KARDUS VALID DI LANTAI TOKO
-- ==========================================
local function bacaDetailKardus(kardus)
    local namaDitemukan = nil
    local jumlahIsi = 12

    for _, attrName in ipairs({ "ItemName", "Product", "Nama", "Item", "Produk", "Barang" }) do
        local val = kardus:GetAttribute(attrName)
        if typeof(val) == "string" and val ~= "" then
            namaDitemukan = val
            break
        end
    end

    for _, attrQty in ipairs({ "Stock", "Jumlah", "Count", "Isi", "Amount", "Qty" }) do
        local q = kardus:GetAttribute(attrQty)
        if typeof(q) == "number" and q > 0 then
            jumlahIsi = q
            break
        end
    end

    for _, desc in ipairs(kardus:GetDescendants()) do
        if not namaDitemukan then
            if desc:IsA("StringValue") and desc.Value ~= "" and desc.Value:lower() ~= "kardus" then
                namaDitemukan = desc.Value
            elseif desc:IsA("TextLabel") and desc.Text ~= "" then
                local bersih = desc.Text:gsub("%s*%b()", ""):gsub("^%s+", ""):gsub("%s+$", "")
                if bersih ~= "" and bersih:lower() ~= "kardus" and not bersih:match("^[xX]?%d+[/]?%d*$") then
                    namaDitemukan = bersih
                end
            end
        end
    end

    if not namaDitemukan or namaDitemukan == "" or apakahFurnitur(namaDitemukan) then
        return nil
    end

    return {
        obj = kardus,
        nama = namaDitemukan,
        jumlah = math.clamp(jumlahIsi, 1, 12)
    }
end

local function ambilSemuaKardusTersedia()
    local daftar = {}
    for _, v in ipairs(clickObject:GetChildren()) do
        if v.Name == "Kardus" then
            local detail = bacaDetailKardus(v)
            if detail then
                table.insert(daftar, detail)
            end
        end
    end
    return daftar
end

-- ==========================================
-- DETEKSI RAK KOSONG (KHUSUS RakBelanjaX & RakBelanjaHitamX)
-- ==========================================
local function apakahRakKosong(rakPart)
    if not rakPart or not rakPart:IsA("BasePart") then return false end

    -- Lewati rak yang baru saja ditolak server ("Rak penuh/terisi")
    if rakDitolakServer[rakPart] and tick() < rakDitolakServer[rakPart] then
        return false
    end

    -- 1. Cek ClientItemInstances
    local clientItems = rakPart:FindFirstChild("ClientItemInstances")
    if clientItems and #clientItems:GetChildren() > 0 then
        return false
    end

    -- 2. Cek atribut stok tersembunyi di server (jika ada)
    for _, attr in ipairs({ "Stock", "Jumlah", "Count", "Isi", "Amount", "Qty" }) do
        local v = rakPart:GetAttribute(attr)
        if typeof(v) == "number" and v > 0 then
            return false
        end
    end

    local infoObj = rakPart:FindFirstChild("Info")
    if infoObj then
        for _, attr in ipairs({ "Stock", "Jumlah", "Count", "Isi", "Amount", "Qty" }) do
            local v = infoObj:GetAttribute(attr)
            if typeof(v) == "number" and v > 0 then
                return false
            end
        end
    end

    return true
end

local function cariSemuaRakKosong()
    local rakKosong = {}
    local daftarModelRak = {}

    for _, modelRak in ipairs(clickObject:GetChildren()) do
        local namaModel = modelRak.Name:lower()
        if namaModel:find("rakbelanja") and modelRak:FindFirstChild("InputRak") then
            table.insert(daftarModelRak, modelRak)
        end
    end

    -- Urutkan model rak dari nomor terkecil (RakBelanja1, RakBelanja2, dst.)
    table.sort(daftarModelRak, function(a, b)
        local numA = tonumber(a.Name:match("%d+")) or 9999
        local numB = tonumber(b.Name:match("%d+")) or 9999
        if numA ~= numB then return numA < numB end
        return a.Name < b.Name
    end)

    for _, modelRak in ipairs(daftarModelRak) do
        local inputRak = modelRak:FindFirstChild("InputRak")
        if inputRak then
            local slots = inputRak:GetChildren()
            -- Wajib diurutkan dari papan Rak1, Rak2, Rak3, dst.
            table.sort(slots, function(a, b)
                local numA = tonumber(a.Name:match("%d+")) or 9999
                local numB = tonumber(b.Name:match("%d+")) or 9999
                if numA ~= numB then return numA < numB end
                return a.Name < b.Name
            end)

            for _, slotPart in ipairs(slots) do
                if slotPart:IsA("BasePart") and apakahRakKosong(slotPart) then
                    table.insert(rakKosong, slotPart)
                end
            end
        end
    end

    return rakKosong
end

-- ==========================================
-- KALKULASI GRID CFRAME & SCALE
-- ==========================================
local modelSizeCache = {}
local function cariUkuranModelProduk(itemName)
    local key = itemName:lower()
    if modelSizeCache[key] then
        return modelSizeCache[key]
    end

    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc.Name:lower() == key then
            if desc:IsA("Model") then
                local sz = desc:GetExtentsSize()
                if sz.Magnitude > 0.05 then
                    modelSizeCache[key] = sz
                    return sz
                end
            elseif desc:IsA("BasePart") and desc.Size.Magnitude > 0.05 then
                modelSizeCache[key] = desc.Size
                return desc.Size
            end
        end
    end
    return nil
end

local function buatBatchPenempatanRak(rakPart, itemName, jumlahItem)
    local rakW = rakPart.Size.X
    local rakH = rakPart.Size.Y
    local rakD = rakPart.Size.Z

    local cols = 4
    local rows = (rakD >= 1.5) and 3 or 2
    local kapasitasMaks = cols * rows
    local totalPlace = math.clamp(jumlahItem or kapasitasMaks, 1, kapasitasMaks)

    local slotW = (rakW * 0.90) / cols
    local slotD = (rakD * 0.85) / rows

    local modelSize = cariUkuranModelProduk(itemName)
    local scale = (rakD >= 1.5) and 0.65325327 or 0.48711754
    local itemHeight = 0.72

    if modelSize then
        local scaleX = slotW / math.max(modelSize.X, 0.1)
        local scaleZ = slotD / math.max(modelSize.Z, 0.1)
        scale = math.min(scaleX, scaleZ, 1.0)
        itemHeight = modelSize.Y * scale
    end

    local offsetY = (rakH > 0.6)
        and (-(rakH / 2) + (itemHeight / 2))
        or ((rakH / 2) + (itemHeight / 2))

    local startX = -((cols - 1) * slotW) / 2
    local startZ = -((rows - 1) * slotD) / 2

    local daftarPenempatan = {}
    for i = 0, totalPlace - 1 do
        local col = i % cols
        local row = math.floor(i / cols)

        local offX = startX + (col * slotW)
        local offZ = startZ + (row * slotD)
        local worldCF = rakPart.CFrame * CFrame.new(offX, offsetY, offZ)

        table.insert(daftarPenempatan, {
            cf = worldCF,
            scale = scale
        })
    end

    return daftarPenempatan
end

-- ==========================================
-- EKSEKUSI AMAN (1 KARDUS PER SIKLUS + VERIFIKASI HASIL)
-- ==========================================
local function jalankanSiklusIsiRak(abaikanToggle)
    if sedangMengisiRak then return 0 end

    if not PickupKardusRemote or not PlaceOilRemote or not PlaceOilDoneRemote then
        return 0
    end

    sedangMengisiRak = true
    local terisiCount = 0

    pcall(function()
        while abaikanToggle or autoPlaceRakEnabled do
            local daftarRakKosong = cariSemuaRakKosong()
            if #daftarRakKosong == 0 then
                break
            end

            local targetRak = daftarRakKosong[1]
            if not targetRak or not targetRak.Parent then
                break
            end

            -- Gunakan kardus yang sudah tertahan di server jika gagal di rak sebelumnya,
            -- JANGAN ambil kardus baru dari lantai sebelum kardus ini masuk ke rak!
            local kardusAktif = kardusTertahanDiServer
            local baruDiambilDariLantai = false

            if not kardusAktif then
                local daftarKardus = ambilSemuaKardusTersedia()
                if #daftarKardus == 0 then
                    break
                end
                kardusAktif = daftarKardus[1]
                baruDiambilDariLantai = true
            end

            local itemAktif = kardusAktif.nama
            if not itemAktif or apakahFurnitur(itemAktif) then
                break
            end

            -- Tahap 1: Ambil kardus HANYA jika belum ada kardus yang tertahan di tangan/server
            if baruDiambilDariLantai and kardusAktif.obj and kardusAktif.obj.Parent then
                PickupKardusRemote:FireServer(kardusAktif.obj, itemAktif)
                kardusTertahanDiServer = {
                    nama = itemAktif,
                    jumlah = kardusAktif.jumlah or 12
                }
                task.wait(0.15)
            end

            -- Tahap 2 & 3: Coba tempatkan ke targetRak
            PlaceOilRemote:FireServer(targetRak)
            task.wait(0.10)

            local batchData = buatBatchPenempatanRak(targetRak, itemAktif, kardusAktif.jumlah or 12)
            PlaceOilDoneRemote:FireServer(targetRak, batchData, itemAktif)

            -- Tunggu server merespons apakah item benar-benar masuk ke rak
            task.wait(math.max(jedaAntarRak, 0.30))

            local clientItems = targetRak:FindFirstChild("ClientItemInstances")
            local berhasilMasuk = clientItems and (#clientItems:GetChildren() > 0)

            if berhasilMasuk then
                -- BERHASIL: Lepas kunci kardus tertahan agar siklus berikutnya boleh ambil kardus baru
                kardusTertahanDiServer = nil
                local char = API.LocalPlayer.Character
                local upperTorso = char and char:FindFirstChild("UpperTorso")
                local p = upperTorso and upperTorso:FindFirstChild("KardusPicked")
                if p then p:Destroy() end

                terisiCount = terisiCount + 1
            else
                -- GAGAL (Server menganggap rak penuh/terisi):
                -- 1. Tandai rak ini agar dilewati selama 60 detik (jangan dipaksa lagi)
                rakDitolakServer[targetRak] = tick() + 60
                -- 2. Tetap simpan kardusTertahanDiServer agar dipakai di rak berikutnya tanpa menghanguskan kardus lain di lantai!
            end
        end
    end)

    sedangMengisiRak = false
    return terisiCount
end

-- ==========================================
-- UI TAB: INPUT
-- ==========================================
local InputTab = API.CreateTab("Input")

API.Section(InputTab, "Informasi Sistem Auto Input (" .. PlotToko.Name .. ")")
local StatusInputCard = API.Paragraph(
    InputTab,
    "Modul Aktif: Khusus RakBelanjaX & RakBelanjaHitamX",
    "Mengisi berurutan dari Rak 1 dengan proteksi anti-kardus hilang (otomatis melewati rak yang penuh di server)."
)

API.Section(InputTab, "Kontrol Auto Input Rak")
API.Slider(InputTab, "Jeda Antar Slot Rak (Detik)", 0.25, 1.50, 0.05, " dtk", 0.30, function(val)
    jedaAntarRak = tonumber(val) or 0.30
end)

API.Toggle(InputTab, "Auto Isi Rak Kosong (Otomatis)", false, function(val)
    autoPlaceRakEnabled = val
    API.Notify(
        val and "Auto Input Aktif" or "Auto Input Mati",
        val and "Mengisi RakBelanja dari nomor 1 dengan proteksi anti-hangus kardus." or "Auto input dihentikan.",
        3
    )
end)

API.Button(InputTab, "Isi Semua Rak Kosong Sekarang (1x)", function()
    task.spawn(function()
        local rakKosong = cariSemuaRakKosong()
        if #rakKosong == 0 then
            API.Notify("Semua Rak Penuh", "Tidak ada slot rak belanja kosong di " .. PlotToko.Name .. ".", 3)
            return
        end
        local hasil = jalankanSiklusIsiRak(true)
        API.Notify("Selesai", "Berhasil mengisi " .. tostring(hasil) .. " slot rak kosong.", 3)
    end)
end)

API.Button(InputTab, "Reset Cache Rak Penuh (Pindai Ulang)", function()
    rakDitolakServer = {}
    kardusTertahanDiServer = nil
    API.Notify("Cache Direset", "Semua papan rak akan dipindai ulang dari nomor 1.", 2)
end)

-- ==========================================
-- LOOP PEMANTAUAN OTOMATIS
-- ==========================================
task.spawn(function()
    while true do
        local rakKosong = cariSemuaRakKosong()
        local kardusAda = ambilSemuaKardusTersedia()

        API.SetElementText(
            StatusInputCard,
            "Rak Kosong: " .. tostring(#rakKosong) .. " papan  |  Kardus Tersedia: " .. tostring(#kardusAda),
            autoPlaceRakEnabled
                and (#rakKosong > 0 and "Status: Mengisi RakBelanja dari nomor 1..." or "Status: Siaga (Semua rak terisi)")
                or "Status: Nonaktif (Menunggu diaktifkan)"
        )

        if autoPlaceRakEnabled and #rakKosong > 0 and (#kardusAda > 0 or kardusTertahanDiServer ~= nil) then
            jalankanSiklusIsiRak(false)
        end

        task.wait(0.8)
    end
end)
