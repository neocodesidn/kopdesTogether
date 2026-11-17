local API = ...

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KardusRemotes = (API and API.Remotes and API.Remotes.Kardus) or ReplicatedStorage:WaitForChild("KardusRemotes", 10)
local PickupKardusRemote = KardusRemotes and KardusRemotes:FindFirstChild("PickupKardus")
local DropKardusRemote = KardusRemotes and KardusRemotes:FindFirstChild("DropKardus")
local DropObjectKardusRemote = KardusRemotes and KardusRemotes:FindFirstChild("DropObjectKardus")
local PlaceOilRemote = KardusRemotes and KardusRemotes:FindFirstChild("PlaceOil")
local PlaceOilDoneRemote = KardusRemotes and KardusRemotes:FindFirstChild("PlaceOilDone")

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
    return (API and API.Plot) or Workspace:WaitForChild("Plot1")
end

local PlotToko = dapatkanPlotToko()
local clickObject = PlotToko:WaitForChild("ClickObject")

-- ==========================================
-- FILTER KETAT: HANYA Product.Makanan (Default & Lisensi)
-- ==========================================
local ProductFolder = ReplicatedStorage:WaitForChild("Product", 10)
local MakananFolder = ProductFolder and ProductFolder:FindFirstChild("Makanan")

local whitelistMakanan = {}
local blacklistKategoriLain = {}
local totalItemMakanan = 0

local function normalisasiTeks(teks)
    return tostring(teks):lower():gsub("%s+", ""):gsub("[^%w]", "")
end

local function kumpulkanAliasObjek(obj)
    local hasil = {}
    if obj and obj.Name ~= "" then
        table.insert(hasil, obj.Name)
    end
    for _, attr in ipairs({ "DisplayName", "Nama", "Title", "ProductName", "ItemName", "Product", "Item", "Produk", "Barang" }) do
        local v = obj:GetAttribute(attr)
        if typeof(v) == "string" and v ~= "" then
            table.insert(hasil, v)
        end
    end
    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("StringValue") and child.Value ~= "" then
            table.insert(hasil, child.Value)
        end
    end
    return hasil
end

local function muatDatabaseProduct()
    whitelistMakanan = {}
    blacklistKategoriLain = {}
    totalItemMakanan = 0

    if not ProductFolder then return end

    -- 1. Daftarkan seluruh item di dalam ReplicatedStorage.Product.Makanan (Default & Lisensi)
    if MakananFolder then
        for _, subFolder in ipairs(MakananFolder:GetChildren()) do
            local subLower = subFolder.Name:lower()
            local isDefaultAtauLisensi = subLower == "default"
                or subLower:find("lisensi", 1, true)
                or subLower:find("license", 1, true)

            if (subFolder:IsA("Folder") or subFolder:IsA("Configuration")) and isDefaultAtauLisensi then
                for _, itemObj in ipairs(subFolder:GetChildren()) do
                    local entry = {
                        canonicalName = itemObj.Name,
                        folderSumber = subFolder.Name,
                        model = itemObj
                    }
                    local terhitung = false
                    for _, alias in ipairs(kumpulkanAliasObjek(itemObj)) do
                        local key = normalisasiTeks(alias)
                        if key ~= "" and not whitelistMakanan[key] then
                            whitelistMakanan[key] = entry
                            if not terhitung then
                                totalItemMakanan = totalItemMakanan + 1
                                terhitung = true
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Daftarkan semua item di kategori lain (Minuman, Daging, Sayuran, dll.) ke blacklist
    for _, kategoriLain in ipairs(ProductFolder:GetChildren()) do
        if kategoriLain ~= MakananFolder then
            local kKat = normalisasiTeks(kategoriLain.Name)
            if kKat ~= "" then
                blacklistKategoriLain[kKat] = true
            end

            for _, desc in ipairs(kategoriLain:GetDescendants()) do
                local namaLower = desc.Name:lower()
                local isNamaFolderUmum = namaLower == "default"
                    or namaLower:find("lisensi", 1, true)
                    or namaLower:find("license", 1, true)
                    or namaLower == "handle"
                    or namaLower == "part"
                    or namaLower == "meshpart"
                    or namaLower == "union"
                    or namaLower == "model"

                if not isNamaFolderUmum then
                    for _, alias in ipairs(kumpulkanAliasObjek(desc)) do
                        local key = normalisasiTeks(alias)
                        if key ~= "" and not whitelistMakanan[key] then
                            blacklistKategoriLain[key] = true
                        end
                    end
                end
            end
        end
    end
end

muatDatabaseProduct()

local function cekProdukMakanan(nama)
    if not nama or nama == "" then return nil end
    local key = normalisasiTeks(nama)
    if key == "" or blacklistKategoriLain[key] then
        return nil
    end
    return whitelistMakanan[key]
end

-- ==========================================
-- KONFIGURASI AUTO INPUT & PELACAK INSTANCE
-- ==========================================
local KAPASITAS_MAKS_PAPAN = 12
local autoPlaceRakEnabled = false
local jedaAntarRak = 0.25
local sedangMengisiRak = false
local rakDitolakServer = {}
local kardusDitolakSementara = {}

local instancePickedTerverifikasi = nil
local namaPickedTerverifikasi = nil

local kataGenerikObjek = {
    kardus = true, karduspicked = true, box = true, handle = true, part = true,
    meshpart = true, union = true, unionoperation = true, lid = true, tutup = true,
    model = true, clickdetector = true, proximityprompt = true, surfacegui = true,
    billboardgui = true, weld = true, motor6d = true, attachment = true, decal = true, texture = true
}

-- ==========================================
-- ANALISIS KETAT ISI KARDUS
-- ==========================================
local function bacaInfoKardusMakanan(objKardus)
    if not objKardus then return nil, 12 end

    local jumlahIsi = KAPASITAS_MAKS_PAPAN
    local hasilWhitelist = nil

    for _, desc in ipairs(objKardus:GetDescendants()) do
        if desc:IsA("ObjectValue") and desc.Value then
            if MakananFolder and desc.Value:IsDescendantOf(MakananFolder) then
                local info = cekProdukMakanan(desc.Value.Name)
                if info then return info, jumlahIsi end
                return nil, jumlahIsi
            elseif ProductFolder and desc.Value:IsDescendantOf(ProductFolder) then
                return nil, jumlahIsi
            end
        end
    end

    local kandidatTeks = {}
    local function catatTeks(raw)
        if typeof(raw) ~= "string" or raw == "" then return end
        local bersih = raw:gsub("%s*%b()", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if bersih == "" or bersih:match("^[xX]?%d+[/]?%d*$") then return end
        local key = normalisasiTeks(bersih)
        if key ~= "" and not kataGenerikObjek[key] then
            table.insert(kandidatTeks, bersih)
        end
    end

    for _, attr in ipairs({ "ItemName", "Product", "Nama", "Item", "Produk", "Barang", "DisplayName", "Category", "Kategori" }) do
        catatTeks(objKardus:GetAttribute(attr))
    end

    for _, attrQty in ipairs({ "Stock", "Jumlah", "Count", "Isi", "Amount", "Qty" }) do
        local q = objKardus:GetAttribute(attrQty)
        if typeof(q) == "number" and q > 0 then
            jumlahIsi = q
            break
        end
    end

    for _, desc in ipairs(objKardus:GetDescendants()) do
        for _, attr in ipairs({ "ItemName", "Product", "Nama", "Item", "Produk", "Barang", "DisplayName", "Category", "Kategori" }) do
            catatTeks(desc:GetAttribute(attr))
        end

        if desc:IsA("StringValue") then
            catatTeks(desc.Value)
        elseif desc:IsA("TextLabel") then
            catatTeks(desc.Text)
            local angka = desc.Text:match("^[xX]?(%d+)")
            if angka then
                local n = tonumber(angka)
                if n and n > 0 and n <= KAPASITAS_MAKS_PAPAN then
                    jumlahIsi = n
                end
            end
        elseif desc:IsA("IntValue") or desc:IsA("NumberValue") then
            if desc.Value > 0 and desc.Value <= KAPASITAS_MAKS_PAPAN then
                jumlahIsi = desc.Value
            end
        elseif desc:IsA("Model") or desc:IsA("BasePart") or desc:IsA("Tool") then
            catatTeks(desc.Name)
        end
    end

    for _, teks in ipairs(kandidatTeks) do
        local key = normalisasiTeks(teks)
        if blacklistKategoriLain[key] then
            return nil, jumlahIsi
        end
        if not hasilWhitelist and whitelistMakanan[key] then
            hasilWhitelist = whitelistMakanan[key]
        end
    end

    return hasilWhitelist, math.clamp(jumlahIsi, 1, KAPASITAS_MAKS_PAPAN)
end

local function apakahKardusMengandungNonMakanan(objKardus)
    if not objKardus then return false end

    for _, desc in ipairs(objKardus:GetDescendants()) do
        if desc:IsA("ObjectValue") and desc.Value and ProductFolder and desc.Value:IsDescendantOf(ProductFolder) then
            if not (MakananFolder and desc.Value:IsDescendantOf(MakananFolder)) then
                return true
            end
        elseif desc:IsA("StringValue") and blacklistKategoriLain[normalisasiTeks(desc.Value)] then
            return true
        elseif desc:IsA("TextLabel") then
            local bersih = desc.Text:gsub("%s*%b()", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if blacklistKategoriLain[normalisasiTeks(bersih)] then
                return true
            end
        elseif (desc:IsA("Model") or desc:IsA("BasePart") or desc:IsA("Tool")) and blacklistKategoriLain[normalisasiTeks(desc.Name)] then
            return true
        end
    end

    for _, attrVal in pairs(objKardus:GetAttributes()) do
        if typeof(attrVal) == "string" and blacklistKategoriLain[normalisasiTeks(attrVal)] then
            return true
        end
    end

    return false
end

local function ambilSemuaKardusMakanan()
    local daftar = {}
    for _, v in ipairs(clickObject:GetChildren()) do
        if v.Name == "Kardus" then
            local skip = kardusDitolakSementara[v] and tick() < kardusDitolakSementara[v]
            if not skip and not apakahKardusMengandungNonMakanan(v) then
                local infoMakanan, jumlah = bacaInfoKardusMakanan(v)
                if infoMakanan then
                    table.insert(daftar, {
                        obj = v,
                        nama = infoMakanan.canonicalName,
                        jumlah = jumlah
                    })
                end
            end
        end
    end
    return daftar
end

-- ==========================================
-- PEMINDAIAN SLOT KOSONG MURNI (0/12)
-- RakBelanjaX / RakBelanjaHitamX (Rak1-Rak8) & RakKecilX (Rak1-Rak12)
-- ==========================================
local function dapatkanFolderItemPapan(rakPart)
    return rakPart:FindFirstChild("ClientItemInstances")
        or rakPart:FindFirstChild("InstacesItem")
        or rakPart:FindFirstChild("InstanceItem")
end

local function apakahSlotMurniKosong(rakPart)
    if not rakPart or not rakPart:IsA("BasePart") then return false end

    if rakDitolakServer[rakPart] and tick() < rakDitolakServer[rakPart] then
        return false
    end

    local folderItem = dapatkanFolderItemPapan(rakPart)
    if folderItem and #folderItem:GetChildren() > 0 then
        return false
    end

    return true
end

local function dapatkanJumlahSlotModelRak(modelRak)
    local namaLower = modelRak.Name:lower()
    if namaLower:find("^rakkecil") then
        return 12
    elseif namaLower:find("^rakbelanja") then
        return 8
    end
    return nil
end

local function cariSemuaSlotKosong()
    local daftarSlotKosong = {}
    local daftarModelRak = {}

    for _, modelRak in ipairs(clickObject:GetChildren()) do
        local jumlahSlot = dapatkanJumlahSlotModelRak(modelRak)
        if jumlahSlot and modelRak:FindFirstChild("InputRak") then
            table.insert(daftarModelRak, {
                model = modelRak,
                maxSlot = jumlahSlot
            })
        end
    end

    table.sort(daftarModelRak, function(a, b)
        local numA = tonumber(a.model.Name:match("%d+")) or 9999
        local numB = tonumber(b.model.Name:match("%d+")) or 9999
        if numA ~= numB then return numA < numB end
        return a.model.Name < b.model.Name
    end)

    for _, infoRak in ipairs(daftarModelRak) do
        local inputRak = infoRak.model:FindFirstChild("InputRak")
        if inputRak then
            for i = 1, infoRak.maxSlot do
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
    local key = normalisasiTeks(itemName)
    if modelSizeCache[key] then
        return modelSizeCache[key]
    end

    local infoMakanan = cekProdukMakanan(itemName)
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
-- PENGAMBILAN JARAK JAUH (TANPA TELEPORT) & VALIDASI TANGAN
-- ==========================================
local function jatuhkanKardusSalah(picked)
    if instancePickedTerverifikasi == picked then
        instancePickedTerverifikasi = nil
        namaPickedTerverifikasi = nil
    end
    if DropKardusRemote then
        pcall(function() DropKardusRemote:FireServer(picked) end)
    end
    if DropObjectKardusRemote then
        pcall(function() DropObjectKardusRemote:FireServer(picked) end)
    end
end

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

local function cekKardusMakananDiTangan()
    local picked = cariKardusPickedDiKarakter()

    if not picked then
        instancePickedTerverifikasi = nil
        namaPickedTerverifikasi = nil
        return nil, nil, false
    end

    if apakahKardusMengandungNonMakanan(picked) then
        return nil, nil, true
    end

    local infoMakanan = bacaInfoKardusMakanan(picked)
    if infoMakanan then
        instancePickedTerverifikasi = picked
        namaPickedTerverifikasi = infoMakanan.canonicalName
        return picked, infoMakanan.canonicalName, false
    end

    if picked == instancePickedTerverifikasi and namaPickedTerverifikasi and cekProdukMakanan(namaPickedTerverifikasi) then
        return picked, namaPickedTerverifikasi, false
    end

    return nil, nil, true
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

local function ambilSatuKardusAman(detailKardus)
    local existing, existingNama, pegangBarangLain = cekKardusMakananDiTangan()
    if pegangBarangLain then
        return nil, nil
    end
    if existing and existingNama then
        return existing, existingNama
    end

    local kardusObj = detailKardus.obj
    if not kardusObj or not kardusObj.Parent then return nil, nil end

    if apakahKardusMengandungNonMakanan(kardusObj) or not cekProdukMakanan(detailKardus.nama) then
        kardusDitolakSementara[kardusObj] = tick() + 30
        return nil, nil
    end

    picuInteraksiKardusJarakJauh(kardusObj)

    local picked = nil
    for step = 1, 24 do
        task.wait(0.05)
        picked = cariKardusPickedDiKarakter()
        if picked then break end

        if step == 8 and PickupKardusRemote and kardusObj.Parent then
            pcall(function() PickupKardusRemote:FireServer(kardusObj) end)
            pcall(function() PickupKardusRemote:FireServer(kardusObj, detailKardus.nama) end)
        end
    end

    if not picked then
        kardusDitolakSementara[kardusObj] = tick() + 4
        return nil, nil
    end

    if apakahKardusMengandungNonMakanan(picked) then
        jatuhkanKardusSalah(picked)
        kardusDitolakSementara[kardusObj] = tick() + 10
        return nil, nil
    end

    local infoMakananTangan = bacaInfoKardusMakanan(picked)
    local namaFinal = infoMakananTangan and infoMakananTangan.canonicalName or detailKardus.nama

    if not cekProdukMakanan(namaFinal) then
        jatuhkanKardusSalah(picked)
        return nil, nil
    end

    instancePickedTerverifikasi = picked
    namaPickedTerverifikasi = namaFinal

    if PickupKardusRemote then
        pcall(function() PickupKardusRemote:FireServer(picked, namaFinal) end)
        task.wait(0.10)
        return picked, namaFinal
    end

    return nil, nil
end

-- ==========================================
-- EKSEKUSI UTAMA (HANYA MAKANAN -> SLOT KOSONG 0/12)
-- ==========================================
local function jalankanSiklusIsiRak(abaikanToggle)
    if sedangMengisiRak then return 0 end
    if not PickupKardusRemote or not PlaceOilRemote or not PlaceOilDoneRemote then
        return 0
    end

    sedangMengisiRak = true
    local slotTerisiCount = 0
    local jumlahItemTerakhir = KAPASITAS_MAKS_PAPAN

    local ok, err = pcall(function()
        while abaikanToggle or autoPlaceRakEnabled do
            local daftarSlotKosong = cariSemuaSlotKosong()
            if #daftarSlotKosong == 0 then break end

            local targetRak = daftarSlotKosong[1]
            if not targetRak or not targetRak.Parent then break end

            local picked, itemAktif, pegangBarangLain = cekKardusMakananDiTangan()
            if pegangBarangLain then
                break
            end

            local jumlahKirim = jumlahItemTerakhir

            if not picked or not itemAktif then
                local daftarKardus = ambilSemuaKardusMakanan()
                if #daftarKardus == 0 then break end

                local kardusPilihan = daftarKardus[1]
                picked, itemAktif = ambilSatuKardusAman(kardusPilihan)
                jumlahItemTerakhir = kardusPilihan.jumlah or KAPASITAS_MAKS_PAPAN
                jumlahKirim = jumlahItemTerakhir
            end

            if not picked or not itemAktif or not cekProdukMakanan(itemAktif) then
                break
            end

            PlaceOilRemote:FireServer(targetRak)
            task.wait(0.08)

            local batchData = buatBatchPenempatanRak(targetRak, itemAktif, jumlahKirim)
            PlaceOilDoneRemote:FireServer(targetRak, batchData, itemAktif)

            local terkonfirmasi = false
            for _ = 1, 12 do
                task.wait(0.10)
                local folderItem = dapatkanFolderItemPapan(targetRak)
                local masihDiTangan = cekKardusMakananDiTangan()
                if (folderItem and #folderItem:GetChildren() > 0) or not masihDiTangan then
                    terkonfirmasi = true
                    break
                end
            end

            if terkonfirmasi then
                instancePickedTerverifikasi = nil
                namaPickedTerverifikasi = nil
                jumlahItemTerakhir = KAPASITAS_MAKS_PAPAN
                slotTerisiCount = slotTerisiCount + 1
                task.wait(jedaAntarRak)
            else
                rakDitolakServer[targetRak] = tick() + 60
            end
        end
    end)

    if not ok and err then
        warn("[AutoInput Error]:", err)
    end

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
    "Whitelist Ketat: Product.Makanan (" .. tostring(totalItemMakanan) .. " item)",
    "Mengangkut kardus Product.Makanan ke slot kosong (0/12) RakBelanjaX, RakBelanjaHitamX (8 slot), & RakKecilX (12 slot)."
)

API.Section(InputTab, "Kontrol Auto Input Rak")
API.Slider(InputTab, "Jeda Antar Slot Rak (Detik)", 0.20, 1.50, 0.05, " dtk", 0.25, function(val)
    jedaAntarRak = tonumber(val) or 0.25
end)

API.Toggle(InputTab, "Auto Isi Slot Kosong Makanan (Otomatis)", false, function(val)
    autoPlaceRakEnabled = val
    API.Notify(
        val and "Auto Input Aktif" or "Auto Input Mati",
        val and "Mengangkut khusus produk Makanan ke RakBelanja, RakBelanjaHitam, & RakKecil." or "Auto input dihentikan.",
        3
    )
end)

API.Button(InputTab, "Isi Semua Slot Kosong Makanan Sekarang (1x)", function()
    task.spawn(function()
        local _, _, pegangBarangLain = cekKardusMakananDiTangan()
        if pegangBarangLain then
            API.Notify("Tangan Memegang Barang Lain", "Lepaskan kardus non-Makanan di tangan terlebih dahulu!", 3)
            return
        end

        local daftar = cariSemuaSlotKosong()
        if #daftar == 0 then
            API.Notify("Tidak Ada Slot Kosong", "Semua papan RakBelanja & RakKecil sudah terisi.", 3)
            return
        end
        local hasil = jalankanSiklusIsiRak(true)
        API.Notify("Selesai", "Berhasil mengisi " .. tostring(hasil) .. " slot kosong dengan produk Makanan.", 3)
    end)
end)

API.Button(InputTab, "Reset Cache & Refresh Daftar Makanan", function()
    rakDitolakServer = {}
    kardusDitolakSementara = {}
    instancePickedTerverifikasi = nil
    namaPickedTerverifikasi = nil
    muatDatabaseProduct()
    API.Notify("Diperbarui", "Whitelist Default & Lisensi (" .. tostring(totalItemMakanan) .. " produk) & blacklist kulkas diperbarui.", 2)
end)

-- ==========================================
-- LOOP PEMANTAUAN OTOMATIS
-- ==========================================
task.spawn(function()
    while true do
        local slotKosong = cariSemuaSlotKosong()
        local kardusMakanan = ambilSemuaKardusMakanan()
        local picked, _, pegangBarangLain = cekKardusMakananDiTangan()

        local teksStatus = "Status: Nonaktif (Filter: Product.Makanan)"
        if pegangBarangLain then
            teksStatus = "Status: Tertahan (Tangan memegang barang non-Makanan)"
        elseif autoPlaceRakEnabled then
            teksStatus = (#slotKosong > 0 and "Status: Mengisi produk Makanan ke slot kosong..." or "Status: Siaga (Tidak ada slot 0/12)")
        end

        API.SetElementText(
            StatusInputCard,
            "Slot Kosong (0/12): " .. tostring(#slotKosong) .. "  |  Kardus Makanan: " .. tostring(#kardusMakanan),
            teksStatus
        )

        if autoPlaceRakEnabled and not pegangBarangLain and #slotKosong > 0 and (#kardusMakanan > 0 or picked ~= nil) then
            jalankanSiklusIsiRak(false)
        end

        task.wait(0.8)
    end
end)
