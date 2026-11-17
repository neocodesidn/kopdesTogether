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
-- WHITELIST PRODUK DARI ReplicatedStorage.Product.Makanan
-- ==========================================
local ProductFolder = ReplicatedStorage:WaitForChild("Product", 10)
local MakananFolder = ProductFolder and ProductFolder:WaitForChild("Makanan", 10)

local daftarProdukMakanan = {}
local totalProdukTerdaftar = 0

local function normalisasiNamaProduk(nama)
    return tostring(nama):lower():gsub("%s+", ""):gsub("[^%w]", "")
end

local function muatWhitelistMakanan()
    daftarProdukMakanan = {}
    totalProdukTerdaftar = 0
    if not MakananFolder then return end

    local function daftarkanObjekProduk(obj)
        if not obj or obj.Name == "" then return end
        local key = normalisasiNamaProduk(obj.Name)
        if key ~= "" and not daftarProdukMakanan[key] then
            daftarProdukMakanan[key] = {
                canonicalName = obj.Name,
                model = obj
            }
            totalProdukTerdaftar = totalProdukTerdaftar + 1
        end
    end

    for _, kategori in ipairs(MakananFolder:GetChildren()) do
        if kategori:IsA("Folder") or kategori:IsA("Configuration") then
            for _, item in ipairs(kategori:GetChildren()) do
                daftarkanObjekProduk(item)
            end
        else
            daftarkanObjekProduk(kategori)
        end
    end
end

muatWhitelistMakanan()

local function ambilDataProdukMakanan(nama)
    if not nama or nama == "" then return nil end
    local key = normalisasiNamaProduk(nama)
    if daftarProdukMakanan[key] then
        return daftarProdukMakanan[key]
    end
    muatWhitelistMakanan()
    return daftarProdukMakanan[key]
end

-- ==========================================
-- KONFIGURASI AUTO INPUT (MODE SLOT KOSONG 0/12)
-- ==========================================
local KAPASITAS_MAKS_PAPAN = 12
local autoPlaceRakEnabled = false
local jedaAntarRak = 0.25
local sedangMengisiRak = false
local rakDitolakServer = {}

-- ==========================================
-- DETEKSI KARDUS KATEGORI MAKANAN DI LANTAI
-- ==========================================
local function bacaDetailKardus(kardus)
    local namaDitemukan = nil
    local dariDisplayText = false
    local jumlahIsi = KAPASITAS_MAKS_PAPAN

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
                    dariDisplayText = true
                end
            end
        end

        if desc:IsA("IntValue") or desc:IsA("NumberValue") then
            if desc.Value > 0 and desc.Value <= KAPASITAS_MAKS_PAPAN then
                jumlahIsi = desc.Value
            end
        elseif desc:IsA("TextLabel") then
            local angkaSisa = desc.Text:match("^[xX]?(%d+)")
            if angkaSisa then
                local n = tonumber(angkaSisa)
                if n and n > 0 and n <= KAPASITAS_MAKS_PAPAN then
                    jumlahIsi = n
                end
            end
        end
    end

    local infoMakanan = ambilDataProdukMakanan(namaDitemukan)
    if not infoMakanan then
        return nil
    end

    local namaFinal = dariDisplayText and infoMakanan.canonicalName or namaDitemukan

    return {
        obj = kardus,
        nama = namaFinal,
        jumlah = math.clamp(jumlahIsi, 1, KAPASITAS_MAKS_PAPAN)
    }
end

local function ambilSemuaKardusMakanan()
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
-- PEMINDAIAN SLOT KOSONG MURNI (0/12) DI Rak1 - Rak8
-- ==========================================
local function dapatkanFolderItemPapan(rakPart)
    return rakPart:FindFirstChild("ClientItemInstances")
        or rakPart:FindFirstChild("InstacesItem")
        or rakPart:FindFirstChild("InstanceItem")
end

local function apakahSlotMurniKosong(rakPart)
    if not rakPart or not rakPart:IsA("BasePart") then return false end

    -- Skip slot yang baru saja ditolak server
    if rakDitolakServer[rakPart] and tick() < rakDitolakServer[rakPart] then
        return false
    end

    -- Jika sudah ada item (misal 6/12, 8/12, atau 12/12), WAJIB SKIP
    local folderItem = dapatkanFolderItemPapan(rakPart)
    if folderItem and #folderItem:GetChildren() > 0 then
        return false
    end

    return true
end

local function cariSemuaSlotKosong()
    local daftarSlotKosong = {}
    local daftarModelRak = {}

    for _, modelRak in ipairs(clickObject:GetChildren()) do
        local namaLower = modelRak.Name:lower()
        if namaLower:find("rakbelanja") and modelRak:FindFirstChild("InputRak") then
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

    -- Periksa berurutan dari Rak1 sampai Rak8; ambil HANYA yang kosong 0/12
    for _, modelRak in ipairs(daftarModelRak) do
        local inputRak = modelRak:FindFirstChild("InputRak")
        if inputRak then
            for i = 1, 8 do
                local slotPart = inputRak:FindFirstChild("Rak" .. tostring(i))
                if slotPart and apakahSlotMurniKosong(slotPart) then
                    table.insert(daftarSlotKosong, slotPart)
                end
            end
        end
    end

    return daftarSlotKosong
end

-- ==========================================
-- KALKULASI GRID CFRAME 4x3 (12 ITEM)
-- ==========================================
local modelSizeCache = {}
local function cariUkuranModelProduk(itemName)
    local key = normalisasiNamaProduk(itemName)
    if modelSizeCache[key] then
        return modelSizeCache[key]
    end

    local infoMakanan = ambilDataProdukMakanan(itemName)
    local sumberObj = infoMakanan and infoMakanan.model

    if sumberObj then
        if sumberObj:IsA("Model") then
            local sz = sumberObj:GetExtentsSize()
            if sz.Magnitude > 0.05 then
                modelSizeCache[key] = sz
                return sz
            end
        elseif sumberObj:IsA("BasePart") and sumberObj.Size.Magnitude > 0.05 then
            modelSizeCache[key] = sumberObj.Size
            return sumberObj.Size
        end
    end

    return nil
end

local function buatBatchPenempatanRak(rakPart, itemName, jumlahItem)
    local cols = 4
    local rows = 3
    local totalPlace = math.clamp(jumlahItem or KAPASITAS_MAKS_PAPAN, 1, KAPASITAS_MAKS_PAPAN)

    local rakW = rakPart.Size.X
    local rakH = rakPart.Size.Y
    local rakD = rakPart.Size.Z

    local slotW = (rakW * 0.90) / cols
    local slotD = (rakD * 0.85) / rows

    local modelSize = cariUkuranModelProduk(itemName)
    local scale = 0.65325327
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

        table.insert(daftarPenempatan, {
            cf = rakPart.CFrame * CFrame.new(offX, offsetY, offZ),
            scale = scale
        })
    end

    return daftarPenempatan
end

-- ==========================================
-- PENGAMBILAN & VALIDASI KardusPicked DI TANGAN
-- ==========================================
local function cekKardusDiTangan()
    local char = API.LocalPlayer.Character
    local upperTorso = char and char:FindFirstChild("UpperTorso")
    local picked = upperTorso and upperTorso:FindFirstChild("KardusPicked")
    if not picked then return nil, nil end

    for _, attrName in ipairs({ "ItemName", "Product", "Nama", "Item", "Produk", "Barang" }) do
        local val = picked:GetAttribute(attrName)
        if typeof(val) == "string" and val ~= "" then
            return picked, val
        end
    end
    for _, desc in ipairs(picked:GetDescendants()) do
        if desc:IsA("StringValue") and desc.Value ~= "" then
            return picked, desc.Value
        end
    end
    return picked, nil
end

local function picuInteraksiKardus(kardusObj)
    local cd = kardusObj:FindFirstChildWhichIsA("ClickDetector", true)
    if cd and fireclickdetector then
        pcall(fireclickdetector, cd)
    end
    local pp = kardusObj:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pp and fireproximityprompt then
        pcall(fireproximityprompt, pp)
    end
end

local function ambilSatuKardusAman(detailKardus)
    local char = API.LocalPlayer.Character
    local upperTorso = char and char:FindFirstChild("UpperTorso")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not upperTorso then return nil, nil end

    local existing, existingNama = cekKardusDiTangan()
    if existing then
        return existing, (existingNama or detailKardus.nama)
    end

    local kardusObj = detailKardus.obj
    if not kardusObj or not kardusObj.Parent then return nil, nil end

    picuInteraksiKardus(kardusObj)
    local picked = upperTorso:WaitForChild("KardusPicked", 0.30)

    if not picked and hrp then
        local kardusPos
        if kardusObj:IsA("BasePart") then
            kardusPos = kardusObj.Position
        elseif kardusObj:IsA("Model") then
            local ok, cf = pcall(function() return kardusObj:GetPivot() end)
            if ok and cf then kardusPos = cf.Position end
        end

        if kardusPos then
            local posisiAwal = hrp.CFrame
            hrp.CFrame = CFrame.new(kardusPos + Vector3.new(0, 2.5, 0))
            task.wait(0.08)
            picuInteraksiKardus(kardusObj)
            picked = upperTorso:WaitForChild("KardusPicked", 0.90)
            hrp.CFrame = posisiAwal
        end
    end

    if picked and PickupKardusRemote then
        PickupKardusRemote:FireServer(picked, detailKardus.nama)
        task.wait(0.10)
        return picked, detailKardus.nama
    end

    return nil, nil
end

-- ==========================================
-- EKSEKUSI UTAMA (HANYA ISI SLOT KOSONG 0/12)
-- ==========================================
local function jalankanSiklusIsiRak(abaikanToggle)
    if sedangMengisiRak then return 0 end
    if not PickupKardusRemote or not PlaceOilRemote or not PlaceOilDoneRemote then
        return 0
    end

    sedangMengisiRak = true
    local slotTerisiCount = 0
    local namaItemTerakhir = nil
    local jumlahItemTerakhir = KAPASITAS_MAKS_PAPAN

    pcall(function()
        while abaikanToggle or autoPlaceRakEnabled do
            local daftarSlotKosong = cariSemuaSlotKosong()
            if #daftarSlotKosong == 0 then break end

            local targetRak = daftarSlotKosong[1]
            if not targetRak or not targetRak.Parent then break end

            -- Cek apakah sudah memegang kardus; jika belum, ambil 1 kardus Makanan dari lantai
            local picked, itemAktif = cekKardusDiTangan()
            local jumlahKirim = jumlahItemTerakhir

            if picked then
                itemAktif = itemAktif or namaItemTerakhir
            else
                local daftarKardus = ambilSemuaKardusMakanan()
                if #daftarKardus == 0 then break end

                local kardusPilihan = daftarKardus[1]
                picked, itemAktif = ambilSatuKardusAman(kardusPilihan)
                namaItemTerakhir = itemAktif
                jumlahItemTerakhir = kardusPilihan.jumlah or KAPASITAS_MAKS_PAPAN
                jumlahKirim = jumlahItemTerakhir
            end

            if not picked or not itemAktif or not ambilDataProdukMakanan(itemAktif) then
                break
            end

            -- Tahap 2: PlaceOil ke slot kosong (0/12)
            PlaceOilRemote:FireServer(targetRak)
            task.wait(0.08)

            -- Tahap 3: PlaceOilDone
            local batchData = buatBatchPenempatanRak(targetRak, itemAktif, jumlahKirim)
            PlaceOilDoneRemote:FireServer(targetRak, batchData, itemAktif)

            -- Tunggu konfirmasi server sampai ClientItemInstances terisi atau KardusPicked habis
            local terkonfirmasi = false
            for _ = 1, 12 do
                task.wait(0.10)
                local folderItem = dapatkanFolderItemPapan(targetRak)
                local masihDiTangan = cekKardusDiTangan()
                if (folderItem and #folderItem:GetChildren() > 0) or not masihDiTangan then
                    terkonfirmasi = true
                    break
                end
            end

            if terkonfirmasi then
                namaItemTerakhir = nil
                jumlahItemTerakhir = KAPASITAS_MAKS_PAPAN
                slotTerisiCount = slotTerisiCount + 1
                task.wait(jedaAntarRak)
            else
                -- Slot ditolak server: skip 60 detik, kardus di tangan tetap dipakai ke slot kosong berikutnya
                rakDitolakServer[targetRak] = tick() + 60
            end
        end
    end)

    sedangMengisiRak = false
    return slotTerisiCount
end

-- ==========================================
-- UI TAB: INPUT
-- ==========================================
local InputTab = API.CreateTab("Input")

API.Section(InputTab, "Informasi Filter & Target Rak (" .. PlotToko.Name .. ")")
local StatusInputCard = API.Paragraph(
    InputTab,
    "Mode Slot Kosong 0/12 | Filter: Product.Makanan (" .. tostring(totalProdukTerdaftar) .. " item)",
    "Melewati slot yang masih ada isinya (1..11/12) dan hanya mengisi slot kosong (0/12) di RakBelanjaX & RakBelanjaHitamX."
)

API.Section(InputTab, "Kontrol Auto Input Rak")
API.Slider(InputTab, "Jeda Antar Slot Rak (Detik)", 0.20, 1.50, 0.05, " dtk", 0.25, function(val)
    jedaAntarRak = tonumber(val) or 0.25
end)

API.Toggle(InputTab, "Auto Isi Slot Kosong (Otomatis)", false, function(val)
    autoPlaceRakEnabled = val
    API.Notify(
        val and "Auto Input Aktif" or "Auto Input Mati",
        val and "Mengisi khusus slot kosong (0/12) dengan produk Makanan." or "Auto input dihentikan.",
        3
    )
end)

API.Button(InputTab, "Isi Semua Slot Kosong Sekarang (1x)", function()
    task.spawn(function()
        local daftar = cariSemuaSlotKosong()
        if #daftar == 0 then
            API.Notify("Tidak Ada Slot Kosong", "Semua papan Rak1 - Rak8 sudah terisi (tidak ada slot 0/12).", 3)
            return
        end
        local hasil = jalankanSiklusIsiRak(true)
        API.Notify("Selesai", "Berhasil mengisi " .. tostring(hasil) .. " slot kosong dengan produk Makanan.", 3)
    end)
end)

API.Button(InputTab, "Reset Cache & Refresh Daftar Makanan", function()
    rakDitolakServer = {}
    muatWhitelistMakanan()
    API.Notify("Diperbarui", "Whitelist Product.Makanan (" .. tostring(totalProdukTerdaftar) .. " produk) & cache rak direset.", 2)
end)

-- ==========================================
-- LOOP PEMANTAUAN OTOMATIS
-- ==========================================
task.spawn(function()
    while true do
        local slotKosong = cariSemuaSlotKosong()
        local kardusMakanan = ambilSemuaKardusMakanan()
        local picked = cekKardusDiTangan()

        API.SetElementText(
            StatusInputCard,
            "Slot Kosong (0/12): " .. tostring(#slotKosong) .. "  |  Kardus Makanan: " .. tostring(#kardusMakanan),
            autoPlaceRakEnabled
                and (#slotKosong > 0 and "Status: Mengisi slot kosong Rak1-Rak8..." or "Status: Siaga (Tidak ada slot 0/12)")
                or "Status: Nonaktif (Skip slot terisi sebagian)"
        )

        if autoPlaceRakEnabled and #slotKosong > 0 and (#kardusMakanan > 0 or picked ~= nil) then
            jalankanSiklusIsiRak(false)
        end

        task.wait(0.8)
    end
end)
