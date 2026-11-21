local API = ...

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KardusRemotes = (API and API.Remotes and API.Remotes.Kardus) or ReplicatedStorage:WaitForChild("KardusRemotes", 10)
local BeliProductRemote = KardusRemotes and KardusRemotes:WaitForChild("BeliProduct")
local PickupKardusRemote = KardusRemotes and KardusRemotes:FindFirstChild("PickupKardus")
local PlaceOilRemote = KardusRemotes and KardusRemotes:FindFirstChild("PlaceOil")
local PlaceOilDoneRemote = KardusRemotes and KardusRemotes:FindFirstChild("PlaceOilDone")
local DropKardusRemote = KardusRemotes and (KardusRemotes:FindFirstChild("DropKardus") or KardusRemotes:FindFirstChild("ThrowKardus"))
local DropObjectKardusRemote = KardusRemotes and KardusRemotes:FindFirstChild("DropObjectKardus")

local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
local NotifikasiRemote = RemotesFolder and RemotesFolder:FindFirstChild("Notifikasi")

-- ==========================================
-- DETEKSI PLOT MILIK SENDIRI
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
-- DATABASE TERPADU: MAKANAN, MINUMAN, DAGING, SAYURAN
-- ==========================================
local ProductFolder = ReplicatedStorage:WaitForChild("Product", 10)
local KATEGORI_LIST = { "Makanan", "Minuman", "Daging", "Sayuran" }

local LABEL_KATEGORI = {
    Makanan = "Makanan (Rak Belanja / Kecil)",
    Minuman = "Minuman (Kulkas)",
    Daging = "Daging (Kulkas Daging)",
    Sayuran = "Sayuran (Rak Sayuran)"
}

local databaseProduk = {}
local daftarOpsiDropdown = {
    Makanan = {},
    Minuman = {},
    Daging = {},
    Sayuran = {}
}

local function normalisasiTeks(teks)
    return tostring(teks):lower():gsub("%s+", ""):gsub("[^%w]", "")
end

local function bacaHargaObjek(obj)
    for _, attr in ipairs({ "Price", "Harga", "BuyPrice", "SellPrice", "Cost", "Value", "Nilai" }) do
        local v = obj:GetAttribute(attr)
        if typeof(v) == "number" and v > 0 then
            return v
        end
    end
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("NumberValue") or child:IsA("IntValue") then
            local nLower = child.Name:lower()
            if nLower:find("price") or nLower:find("harga") or nLower:find("cost") or nLower:find("sell") then
                if child.Value > 0 then
                    return child.Value
                end
            end
        end
    end
    return 0
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

local function muatSemuaDatabaseProduk()
    databaseProduk = {}
    for _, kat in ipairs(KATEGORI_LIST) do
        daftarOpsiDropdown[kat] = {}
    end

    if not ProductFolder then return end

    for _, namaKat in ipairs(KATEGORI_LIST) do
        local folderKat = ProductFolder:FindFirstChild(namaKat)
        local tempList = {}
        local sudahAdaItem = {}

        if folderKat then
            for _, subFolder in ipairs(folderKat:GetChildren()) do
                local subLower = subFolder.Name:lower()
                if (subFolder:IsA("Folder") or subFolder:IsA("Configuration"))
                    and (subLower == "default" or subLower:find("^lisensi") or subLower:find("^license")) then
                    for _, itemObj in ipairs(subFolder:GetChildren()) do
                        local namaAsli = itemObj.Name
                        local keyUtama = normalisasiTeks(namaAsli)
                        local hargaItem = bacaHargaObjek(itemObj)

                        local entry = {
                            canonicalName = namaAsli,
                            kategori = namaKat,
                            model = itemObj,
                            harga = hargaItem
                        }

                        if keyUtama ~= "" and not sudahAdaItem[keyUtama] then
                            sudahAdaItem[keyUtama] = true
                            table.insert(tempList, entry)
                        end

                        for _, alias in ipairs(kumpulkanAliasObjek(itemObj)) do
                            local key = normalisasiTeks(alias)
                            if key ~= "" and not databaseProduk[key] then
                                databaseProduk[key] = entry
                            end
                        end
                    end
                end
            end
        end

        table.sort(tempList, function(a, b)
            if a.harga ~= b.harga then
                return a.harga > b.harga
            end
            return a.canonicalName < b.canonicalName
        end)

        for _, item in ipairs(tempList) do
            table.insert(daftarOpsiDropdown[namaKat], item.canonicalName)
        end

        if #daftarOpsiDropdown[namaKat] == 0 then
            table.insert(daftarOpsiDropdown[namaKat], "Tidak Ada Produk")
        end
    end
end

muatSemuaDatabaseProduk()

-- ==========================================
-- STATE KONFIGURASI UNIFIED
-- ==========================================
local KAPASITAS_MAKS_SLOT = 12
local MAX_KARDUS_PER_PRODUK = 10
local MAX_TOTAL_KARDUS_LANTAI = 20

local autoRestockEnabled = false
local autoBeliEnabled = false
local jedaAntarSlot = 0.25
local jumlahBeliPerProduk = 10
local sedangMengisi = false

local waktuBeliTerakhir = { Makanan = 0, Minuman = 0, Daging = 0, Sayuran = 0 }

local kategoriAktif = {
    Makanan = true,
    Minuman = true,
    Daging = true,
    Sayuran = true
}

local produkTerpilih = {
    Makanan = daftarOpsiDropdown.Makanan[1],
    Minuman = daftarOpsiDropdown.Minuman[1],
    Daging = daftarOpsiDropdown.Daging[1],
    Sayuran = daftarOpsiDropdown.Sayuran[1]
}

local slotDitolakServer = {}
local kardusDitolakSementara = {}
local slotTerakhirDitembak = nil
local percobaanGagalTangan = 0

local kataGenerikObjek = {
    kardus = true, karduspicked = true, box = true, handle = true, part = true,
    meshpart = true, union = true, unionoperation = true, lid = true, tutup = true,
    model = true, clickdetector = true, proximityprompt = true, surfacegui = true,
    billboardgui = true, weld = true, motor6d = true, attachment = true, decal = true, texture = true
}

if NotifikasiRemote and NotifikasiRemote:IsA("RemoteEvent") then
    NotifikasiRemote.OnClientEvent:Connect(function(pesan)
        if typeof(pesan) == "string" and slotTerakhirDitembak then
            local pLower = pesan:lower()
            if pLower:find("sudah terisi") or pLower:find("penuh") or pLower:find("tidak sesuai") then
                slotDitolakServer[slotTerakhirDitembak] = tick() + 60
            end
        end
    end)
end

-- ==========================================
-- CACHE AREA GUDANG (ANTI-LAG)
-- ==========================================
local cacheAreaGudang = {}

local function muatUlangCacheGudang()
    local daftar = {}
    for _, obj in ipairs(PlotToko:GetDescendants()) do
        local namaLower = obj.Name:lower()
        if (obj:IsA("Model") or obj:IsA("BasePart")) and (namaLower:find("rakpenyimpanan") or namaLower:find("gudang")) then
            local cf, size
            if obj:IsA("Model") then
                local ok, boxCF, boxSize = pcall(function() return obj:GetBoundingBox() end)
                if ok then cf, size = boxCF, boxSize end
            else
                cf, size = obj.CFrame, obj.Size
            end
            if cf and size then
                table.insert(daftar, {
                    pos = cf.Position,
                    rx = (size.X / 2) + 1.5,
                    ry = (size.Y / 2) + 1.5,
                    rz = (size.Z / 2) + 1.5
                })
            end
        end
    end
    cacheAreaGudang = daftar
end

local function apakahKardusDiRakGudang(kardus)
    local p1 = kardus.Parent
    if p1 and p1 ~= clickObject then
        local n1 = p1.Name:lower()
        if n1:find("rak") or n1:find("gudang") then return true end
        local p2 = p1.Parent
        if p2 and (p2.Name:lower():find("rak") or p2.Name:lower():find("gudang")) then return true end
    end

    if kardus:GetAttribute("InGudang") == true
        or kardus:GetAttribute("Stored") == true
        or kardus:GetAttribute("IsStored") == true then
        return true
    end

    if #cacheAreaGudang > 0 then
        local part = kardus:IsA("BasePart") and kardus or (kardus.PrimaryPart or kardus:FindFirstChildWhichIsA("BasePart"))
        if part then
            local pos = part.Position
            for i = 1, #cacheAreaGudang do
                local area = cacheAreaGudang[i]
                if math.abs(pos.X - area.pos.X) <= area.rx
                    and math.abs(pos.Y - area.pos.Y) <= area.ry
                    and math.abs(pos.Z - area.pos.Z) <= area.rz then
                    return true
                end
            end
        end
    end

    return false
end

-- ==========================================
-- IDENTIFIKASI PRODUK & KATEGORI DARI KARDUS
-- ==========================================
local function bacaInfoKardus(objKardus)
    if not objKardus then return nil, KAPASITAS_MAKS_SLOT end

    local jumlahIsi = KAPASITAS_MAKS_SLOT

    for _, desc in ipairs(objKardus:GetDescendants()) do
        if desc:IsA("ObjectValue") and desc.Value and ProductFolder and desc.Value:IsDescendantOf(ProductFolder) then
            local info = databaseProduk[normalisasiTeks(desc.Value.Name)]
            if info then
                return info, jumlahIsi
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
            table.insert(kandidatTeks, key)
        end
    end

    for _, attr in ipairs({ "ItemName", "Product", "Nama", "Item", "Produk", "Barang", "DisplayName" }) do
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
        for _, attr in ipairs({ "ItemName", "Product", "Nama", "Item", "Produk", "Barang", "DisplayName" }) do
            catatTeks(desc:GetAttribute(attr))
        end

        if desc:IsA("StringValue") then
            catatTeks(desc.Value)
        elseif desc:IsA("TextLabel") then
            catatTeks(desc.Text)
            local angka = desc.Text:match("^[xX]?(%d+)")
            if angka then
                local n = tonumber(angka)
                if n and n > 0 and n <= KAPASITAS_MAKS_SLOT then
                    jumlahIsi = n
                end
            end
        elseif desc:IsA("IntValue") or desc:IsA("NumberValue") then
            if desc.Value > 0 and desc.Value <= KAPASITAS_MAKS_SLOT then
                jumlahIsi = desc.Value
            end
        elseif desc:IsA("Model") or desc:IsA("BasePart") or desc:IsA("Tool") then
            catatTeks(desc.Name)
        end
    end

    for _, key in ipairs(kandidatTeks) do
        if databaseProduk[key] then
            return databaseProduk[key], math.clamp(jumlahIsi, 1, KAPASITAS_MAKS_SLOT)
        end
    end

    return nil, math.clamp(jumlahIsi, 1, KAPASITAS_MAKS_SLOT)
end

-- ==========================================
-- PENGECEKAN KETAT SLOT BENAR-BENAR KOSONG (ANTI-FALSE EMPTY)
-- ==========================================
local function dapatkanFolderItemSlot(rakPart)
    local f = rakPart:FindFirstChild("ClientItemInstances")
        or rakPart:FindFirstChild("InstacesItem")
        or rakPart:FindFirstChild("InstanceItem")
    if f then return f end

    for _, child in ipairs(rakPart:GetChildren()) do
        if child:IsA("Folder") then
            local nLower = child.Name:lower()
            if nLower:find("item") or nLower:find("instance") or nLower:find("product") or nLower:find("produk") then
                return child
            end
        end
    end
    return nil
end

local function apakahSlotKosong(rakPart)
    if not rakPart or not rakPart:IsA("BasePart") then return false end

    -- 1. Cek jika server baru saja menolak slot ini
    if slotDitolakServer[rakPart] and tick() < slotDitolakServer[rakPart] then
        return false
    end

    -- 2. Cek folder item di dalam slot
    local folderItem = dapatkanFolderItemSlot(rakPart)
    if folderItem and #folderItem:GetChildren() > 0 then
        return false
    end

    -- 3. Cek atribut stok/isi pada slot
    for _, attr in ipairs({ "Stock", "Jumlah", "Count", "Isi", "Amount", "Qty", "Occupied", "Terisi", "Full" }) do
        local v = rakPart:GetAttribute(attr)
        if typeof(v) == "number" and v > 0 then
            return false
        elseif typeof(v) == "boolean" and v == true then
            return false
        end
    end

    -- 4. Cek child langsung di dalam slot (selain ClickDetector / ProximityPrompt / GUI / Attachment / Weld)
    for _, child in ipairs(rakPart:GetChildren()) do
        if child:IsA("BasePart") or child:IsA("Model") or child:IsA("Tool") then
            return false
        elseif (child:IsA("IntValue") or child:IsA("NumberValue")) then
            local nLower = child.Name:lower()
            if (nLower:find("stock") or nLower:find("jumlah") or nLower:find("isi") or nLower:find("count")) and child.Value > 0 then
                return false
            end
        elseif child:IsA("StringValue") then
            local nLower = child.Name:lower()
            if (nLower:find("item") or nLower:find("product") or nLower:find("produk")) and child.Value ~= "" then
                return false
            end
        end
    end

    return true
end

local function identifikasiModelRak(modelRak)
    local namaLower = modelRak.Name:lower()
    if namaLower:find("^rakkecil") then
        return "Makanan", 12
    elseif namaLower:find("^rakbelanja") then
        return "Makanan", 8
    elseif namaLower:match("^kulkas%d+$") then
        return "Minuman", 8
    elseif namaLower:match("^kulkasdaging%d+$") then
        return "Daging", 4
    elseif namaLower:match("^raksayuran%d+$") then
        return "Sayuran", 6
    end
    return nil, nil
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

local function pindaiSemuaDataToko()
    local rakAda = { Makanan = false, Minuman = false, Daging = false, Sayuran = false }
    local slotPerKategori = { Makanan = {}, Minuman = {}, Daging = {}, Sayuran = {} }
    local kardusLantaiPerKat = { Makanan = 0, Minuman = 0, Daging = 0, Sayuran = 0 }
    local daftarKandidatIsi = {}
    local totalSemuaKardusLantai = 0

    local daftarModel = {}
    for _, child in ipairs(clickObject:GetChildren()) do
        local kat, maxSlot = identifikasiModelRak(child)
        if kat and maxSlot and child:FindFirstChild("InputRak") then
            rakAda[kat] = true
            table.insert(daftarModel, { model = child, kategori = kat, maxSlot = maxSlot })
        end
    end

    table.sort(daftarModel, function(a, b)
        local numA = tonumber(a.model.Name:match("%d+")) or 9999
        local numB = tonumber(b.model.Name:match("%d+")) or 9999
        if numA ~= numB then return numA < numB end
        return a.model.Name < b.model.Name
    end)

    for _, info in ipairs(daftarModel) do
        local inputRak = info.model:FindFirstChild("InputRak")
        if inputRak then
            for i = 1, info.maxSlot do
                local slotPart = inputRak:FindFirstChild("Rak" .. tostring(i))
                if slotPart and apakahSlotKosong(slotPart) then
                    table.insert(slotPerKategori[info.kategori], slotPart)
                end
            end
        end
    end

    -- Hitung kardus di lantai
    for _, v in ipairs(clickObject:GetChildren()) do
        if v.Name == "Kardus" and not apakahKardusDiRakGudang(v) then
            totalSemuaKardusLantai = totalSemuaKardusLantai + 1
            local info, jumlah = bacaInfoKardus(v)
            if info and rakAda[info.kategori] then
                kardusLantaiPerKat[info.kategori] = kardusLantaiPerKat[info.kategori] + 1
                if kategoriAktif[info.kategori] then
                    local skip = kardusDitolakSementara[v] and tick() < kardusDitolakSementara[v]
                    -- HANYA masukkan ke antrian isi jika slot kosong kategori tsb BENAR-BENAR > 0
                    if not skip and #slotPerKategori[info.kategori] > 0 then
                        table.insert(daftarKandidatIsi, {
                            obj = v,
                            nama = info.canonicalName,
                            kategori = info.kategori,
                            jumlah = jumlah
                        })
                    end
                end
            end
        end
    end

    -- Ikut hitung kardus yang sedang dipegang di tangan supaya tidak double-buy saat transisi
    local pickedTangan = cariKardusPickedDiKarakter()
    if pickedTangan then
        local infoTangan = bacaInfoKardus(pickedTangan)
        if infoTangan and kardusLantaiPerKat[infoTangan.kategori] ~= nil then
            kardusLantaiPerKat[infoTangan.kategori] = kardusLantaiPerKat[infoTangan.kategori] + 1
        end
    end

    return rakAda, slotPerKategori, kardusLantaiPerKat, daftarKandidatIsi, totalSemuaKardusLantai
end

-- ==========================================
-- KALKULASI CFRAME GRID 4x3 (12 ITEM)
-- ==========================================
local modelSizeCache = {}
local function cariUkuranModelProduk(itemName)
    local key = normalisasiTeks(itemName)
    if modelSizeCache[key] then
        return modelSizeCache[key]
    end

    local info = databaseProduk[key]
    local sumberObj = info and info.model

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

local function buatBatchPenempatanRak(rakPart, itemName, kategori, jumlahItem)
    local cols = 4
    local rows = 3
    local totalPlace = math.clamp(jumlahItem or KAPASITAS_MAKS_SLOT, 1, KAPASITAS_MAKS_SLOT)

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

    local offsetY
    if kategori == "Minuman" or kategori == "Daging" or kategori == "Sayuran" then
        offsetY = (rakH * 0.5) + 0.35
    else
        offsetY = (rakH > 0.6)
            and (-(rakH / 2) + (itemHeight / 2))
            or ((rakH / 2) + (itemHeight / 2))
    end

    local startX = -((cols - 1) * slotW) / 2
    local startZ = -((rows - 1) * slotD) / 2

    local daftarPenempatan = {}
    for i = 0, totalPlace - 1 do
        local col = i % cols
        local row = math.floor(i / cols)
        local offX = startX + (col * slotW)
        local offZ = startZ + (row * slotD)
        local cfSlot = rakPart.CFrame * CFrame.new(offX, offsetY, offZ)

        if kategori == "Makanan" then
            table.insert(daftarPenempatan, { cf = cfSlot, scale = scale })
        else
            table.insert(daftarPenempatan, cfSlot)
        end
    end

    return daftarPenempatan
end

-- ==========================================
-- PENGAMBILAN JARAK JAUH & ANTI-STUCK TANGAN
-- ==========================================
local function lepasKardusDiTangan()
    local picked = cariKardusPickedDiKarakter()
    if not picked then
        percobaanGagalTangan = 0
        return
    end
    if DropKardusRemote then
        pcall(function() DropKardusRemote:FireServer() end)
        pcall(function() DropKardusRemote:FireServer(picked) end)
    end
    if DropObjectKardusRemote then
        pcall(function() DropObjectKardusRemote:FireServer(picked) end)
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

local function ambilSatuKardus(detailKardus)
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
            pcall(function() PickupKardusRemote:FireServer(kardusObj, detailKardus.nama) end)
        end
    end

    if not picked then
        kardusDitolakSementara[kardusObj] = tick() + 5
        return nil
    end

    percobaanGagalTangan = 0
    if PickupKardusRemote then
        pcall(function() PickupKardusRemote:FireServer(picked, detailKardus.nama) end)
        task.wait(0.08)
    end

    return picked
end

-- ==========================================
-- EKSEKUSI AUTO RESTOCK UNIFIED (BERHENTI TOTAL JIKA PENUH)
-- ==========================================
local function jalankanSiklusRestockAll(sekaliJalan)
    if sedangMengisi then return end
    if not PickupKardusRemote or not PlaceOilRemote or not PlaceOilDoneRemote then return end

    sedangMengisi = true

    task.spawn(function()
        local totalTerisi = 0
        local ok, err = pcall(function()
            while sekaliJalan or autoRestockEnabled do
                local rakAda, slotPerKat, _, daftarKandidat = pindaiSemuaDataToko()
                local picked = cariKardusPickedDiKarakter()

                local itemNama, kategoriAktifName, jumlahItem = nil, nil, KAPASITAS_MAKS_SLOT

                if picked then
                    local infoTangan, jmlTangan = bacaInfoKardus(picked)
                    -- Jika kategori dari kardus di tangan slotnya sudah 0 (PENUH), langsung jatuhkan dan berhenti mengambil
                    if not infoTangan
                        or not rakAda[infoTangan.kategori]
                        or not kategoriAktif[infoTangan.kategori]
                        or #slotPerKat[infoTangan.kategori] == 0 then
                        lepasKardusDiTangan()
                        task.wait(0.15)
                        if #daftarKandidat == 0 then break end
                        continue
                    end
                    itemNama = infoTangan.canonicalName
                    kategoriAktifName = infoTangan.kategori
                    jumlahItem = jmlTangan
                    pcall(function() PickupKardusRemote:FireServer(picked, itemNama) end)
                    task.wait(0.06)
                else
                    -- Jika tidak ada slot kosong untuk kategori yang punya kardus, berhenti total
                    if #daftarKandidat == 0 then
                        break
                    end

                    local pilihan = daftarKandidat[1]
                    -- Validasi ulang slot kosong tepat sebelum mengambil kardus
                    if #slotPerKat[pilihan.kategori] == 0 then
                        continue
                    end

                    picked = ambilSatuKardus(pilihan)
                    if not picked then
                        continue
                    end
                    itemNama = pilihan.nama
                    kategoriAktifName = pilihan.kategori
                    jumlahItem = pilihan.jumlah
                end

                local daftarSlotTarget = slotPerKat[kategoriAktifName]
                local targetSlot = daftarSlotTarget and daftarSlotTarget[1]
                if not targetSlot or not targetSlot.Parent or not apakahSlotKosong(targetSlot) then
                    continue
                end

                slotTerakhirDitembak = targetSlot
                PlaceOilRemote:FireServer(targetSlot)
                task.wait(0.10)

                local batchData = buatBatchPenempatanRak(targetSlot, itemNama, kategoriAktifName, jumlahItem)
                PlaceOilDoneRemote:FireServer(targetSlot, batchData, itemNama)

                local terkonfirmasi = false
                for _ = 1, 14 do
                    task.wait(0.10)
                    if not cariKardusPickedDiKarakter() or not apakahSlotKosong(targetSlot) then
                        terkonfirmasi = true
                        break
                    end
                end

                if terkonfirmasi then
                    totalTerisi = totalTerisi + 1
                    percobaanGagalTangan = 0
                    task.wait(jedaAntarSlot)
                else
                    slotDitolakServer[targetSlot] = tick() + 45
                    percobaanGagalTangan = percobaanGagalTangan + 1
                    if percobaanGagalTangan >= 2 then
                        lepasKardusDiTangan()
                    end
                end
            end
        end)

        if not ok and err then
            warn("[SmartRestock Error]:", err)
        end

        sedangMengisi = false

        if sekaliJalan then
            API.Notify("Selesai", "Berhasil mengisi " .. tostring(totalTerisi) .. " slot kosong.", 3)
        end
    end)
end

-- ==========================================
-- UI TUNGGAL TERPADU (SMART RESTOCK: BELI + ISI RAK)
-- ==========================================
local SmartTab = API.CreateTab("Smart Restock")

local StatusCard = API.Paragraph(
    SmartTab,
    "Memindai rak toko...",
    "Kardus Lantai: 0/20  |  Restock: Nonaktif  |  Beli: Nonaktif"
)

local lastStatusUI = ""

local function perbaruiStatusUI(rakAda, slotPerKat, kardusLantaiPerKat, totalSemuaKardusLantai)
    local bagianRak = {}
    local namaSingkat = { Makanan = "Makanan", Minuman = "Minuman", Daging = "Daging", Sayuran = "Sayur" }

    for _, kat in ipairs(KATEGORI_LIST) do
        if rakAda[kat] then
            local jmlSlot = #slotPerKat[kat]
            table.insert(bagianRak, string.format(
                "%s: %s (%d kardus)",
                namaSingkat[kat],
                jmlSlot > 0 and (tostring(jmlSlot) .. " kosong") or "PENUH",
                kardusLantaiPerKat[kat]
            ))
        end
    end

    local judul = (#bagianRak > 0)
        and table.concat(bagianRak, "  |  ")
        or "Belum ada rak produk terpasang di toko."

    local sub = string.format(
        "Kardus Lantai: %d/%d  |  Restock: %s  |  Beli: %s",
        totalSemuaKardusLantai or 0,
        MAX_TOTAL_KARDUS_LANTAI,
        autoRestockEnabled and "Aktif" or "Nonaktif",
        autoBeliEnabled and "Aktif" or "Nonaktif"
    )

    local gab = judul .. "|" .. sub
    if gab ~= lastStatusUI then
        lastStatusUI = gab
        API.SetElementText(StatusCard, judul, sub)
    end
end

API.Section(SmartTab, "Kontrol Utama (1 Paket Autopilot)")

API.Toggle(SmartTab, "Auto Isi Rak (Restock Otomatis)", false, function(val)
    autoRestockEnabled = val
    lastStatusUI = ""
    if val then
        jalankanSiklusRestockAll(false)
    end
end)

API.Toggle(SmartTab, "Auto Beli Kardus (Hanya Saat Ada Slot Kosong)", false, function(val)
    autoBeliEnabled = val
    lastStatusUI = ""
    if val then
        muatUlangCacheGudang()
    end
end)

API.Slider(SmartTab, "Jumlah Beli Per Produk (Max 10)", 1, 10, 1, " Kardus", 10, function(val)
    jumlahBeliPerProduk = math.clamp(math.floor(tonumber(val) or 10), 1, MAX_KARDUS_PER_PRODUK)
end)

API.Slider(SmartTab, "Jeda Antar Slot Restock", 0.20, 1.50, 0.05, " dtk", 0.25, function(val)
    jedaAntarSlot = tonumber(val) or 0.25
end)

-- ==========================================
-- RENDER DINAMIS KATEGORI (HIDDEN JIKA RAKNYA TIDAK ADA)
-- ==========================================
local kategoriSudahDirender = {
    Makanan = false,
    Minuman = false,
    Daging = false,
    Sayuran = false
}

local function renderKategoriJikaRakAda(rakAda)
    for _, kat in ipairs(KATEGORI_LIST) do
        if rakAda[kat] and not kategoriSudahDirender[kat] then
            kategoriSudahDirender[kat] = true

            API.Section(SmartTab, "Kategori: " .. LABEL_KATEGORI[kat])

            API.Toggle(SmartTab, "Aktifkan " .. kat .. " (Beli & Restock)", kategoriAktif[kat], function(val)
                kategoriAktif[kat] = val
                if val and autoRestockEnabled then
                    jalankanSiklusRestockAll(false)
                end
            end)

            API.Dropdown(SmartTab, "Pilih Produk " .. kat, daftarOpsiDropdown[kat], produkTerpilih[kat], function(selected)
                produkTerpilih[kat] = selected
                API.Notify(kat .. " Dipilih", "Produk " .. kat .. ": " .. tostring(selected), 2)
            end)
        end
    end
end

local rakAwal, slotAwal, kardusAwal, _, totalKardusAwal = pindaiSemuaDataToko()
renderKategoriJikaRakAda(rakAwal)
perbaruiStatusUI(rakAwal, slotAwal, kardusAwal, totalKardusAwal)

API.Section(SmartTab, "Aksi Manual")

API.Button(SmartTab, "Isi Semua Rak Sekarang (1x)", function()
    jalankanSiklusRestockAll(true)
end)

API.Button(SmartTab, "Refresh Rak & Lisensi Produk", function()
    slotDitolakServer = {}
    kardusDitolakSementara = {}
    percobaanGagalTangan = 0
    lastStatusUI = ""
    muatSemuaDatabaseProduk()
    muatUlangCacheGudang()
    local rakBaru, slotBaru, kardusBaru, _, totalKardusBaru = pindaiSemuaDataToko()
    renderKategoriJikaRakAda(rakBaru)
    perbaruiStatusUI(rakBaru, slotBaru, kardusBaru, totalKardusBaru)
    API.Notify("Diperbarui", "Data rak terpasang & lisensi produk berhasil diperbarui.", 2)
end)

-- ==========================================
-- LISTENER REAL-TIME RAK + LANTAI
-- ==========================================
local rakTerpasangListener = {}

local function pasangListenerRak(modelRak)
    if rakTerpasangListener[modelRak] then return end
    local kat, maxSlot = identifikasiModelRak(modelRak)
    if not kat or not maxSlot then return end

    local inputRak = modelRak:FindFirstChild("InputRak")
    if not inputRak then return end

    rakTerpasangListener[modelRak] = true

    for i = 1, maxSlot do
        local slotPart = inputRak:FindFirstChild("Rak" .. tostring(i))
        if slotPart then
            local folderItem = dapatkanFolderItemSlot(slotPart)
            if folderItem then
                folderItem.ChildRemoved:Connect(function()
                    if #folderItem:GetChildren() == 0 and autoRestockEnabled and not sedangMengisi then
                        jalankanSiklusRestockAll(false)
                    end
                end)
            end
        end
    end
end

for _, model in ipairs(clickObject:GetChildren()) do
    pasangListenerRak(model)
end

clickObject.ChildAdded:Connect(function(child)
    if child.Name == "Kardus" then
        task.wait(0.25)
        if autoRestockEnabled and not sedangMengisi then
            jalankanSiklusRestockAll(false)
        end
    elseif identifikasiModelRak(child) then
        task.wait(0.25)
        pasangListenerRak(child)
        local rakBaru = pindaiSemuaDataToko()
        renderKategoriJikaRakAda(rakBaru)
    end
end)

-- ==========================================
-- LOOP SINKRONISASI TERPADU (STOP TOTAL SAAT RAK PENUH)
-- ==========================================
muatUlangCacheGudang()

task.spawn(function()
    while true do
        local rakAda, slotPerKat, kardusLantaiPerKat, daftarKandidatIsi, totalSemuaKardusLantai = pindaiSemuaDataToko()
        renderKategoriJikaRakAda(rakAda)
        perbaruiStatusUI(rakAda, slotPerKat, kardusLantaiPerKat, totalSemuaKardusLantai)

        -- 1. Trigger Auto Restock (Hanya jalan jika ada slot kosong yang cocok dengan kardus di lantai)
        if autoRestockEnabled and not sedangMengisi and #daftarKandidatIsi > 0 then
            jalankanSiklusRestockAll(false)
        end

        -- 2. Trigger Auto Beli (Hanya beli jika kebutuhan bersih = slotKosong - kardusTersedia > 0)
        if autoBeliEnabled and BeliProductRemote then
            local sisaKuotaLantai = MAX_TOTAL_KARDUS_LANTAI - totalSemuaKardusLantai

            if sisaKuotaLantai > 0 then
                local batchBeli = {}
                local sudahDipakaiItem = {}
                local sekarang = tick()
                local targetPerProduk = math.clamp(jumlahBeliPerProduk, 1, MAX_KARDUS_PER_PRODUK)

                for _, kat in ipairs(KATEGORI_LIST) do
                    if sisaKuotaLantai <= 0 then break end

                    local namaTarget = produkTerpilih[kat]
                    local keyProduk = namaTarget and normalisasiTeks(namaTarget) or ""
                    local jumlahSlotKosong = #slotPerKat[kat]
                    local jumlahKardusAda = kardusLantaiPerKat[kat]

                    -- Kebutuhan bersih = slot yang benar-benar kosong dikurangi kardus yang sudah ada di lantai/tangan
                    local kebutuhanBersih = jumlahSlotKosong - jumlahKardusAda

                    if rakAda[kat]
                        and kategoriAktif[kat]
                        and namaTarget
                        and namaTarget ~= ""
                        and namaTarget ~= "Tidak Ada Produk"
                        and not sudahDipakaiItem[keyProduk]
                        and jumlahSlotKosong > 0
                        and kebutuhanBersih > 0
                        and (sekarang - waktuBeliTerakhir[kat]) >= 3.5 then

                        local jumlahKirim = math.min(targetPerProduk, MAX_KARDUS_PER_PRODUK, kebutuhanBersih, sisaKuotaLantai)

                        if jumlahKirim >= 1 then
                            sudahDipakaiItem[keyProduk] = true
                            waktuBeliTerakhir[kat] = sekarang
                            sisaKuotaLantai = sisaKuotaLantai - jumlahKirim

                            table.insert(batchBeli, {
                                jumlahKardus = jumlahKirim,
                                itemName = namaTarget
                            })
                        end
                    end
                end

                if #batchBeli > 0 then
                    BeliProductRemote:FireServer(batchBeli)
                    local daftarNama = {}
                    for _, b in ipairs(batchBeli) do
                        table.insert(daftarNama, b.itemName .. " (" .. b.jumlahKardus .. "x)")
                    end
                    API.Notify("Auto Beli Berhasil", "Membeli: " .. table.concat(daftarNama, ", "), 3)
                end
            end
        end

        task.wait(0.45)
    end
end)
