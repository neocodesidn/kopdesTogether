local API = ...

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KardusRemotes = (API and API.Remotes and API.Remotes.Kardus) or ReplicatedStorage:WaitForChild("KardusRemotes", 10)
local PickupKardusRemote = KardusRemotes and KardusRemotes:FindFirstChild("PickupKardus")
local PlaceOilRemote = KardusRemotes and KardusRemotes:FindFirstChild("PlaceOil")
local PlaceOilDoneRemote = KardusRemotes and KardusRemotes:FindFirstChild("PlaceOilDone")
local DropKardusRemote = KardusRemotes and (KardusRemotes:FindFirstChild("DropKardus") or KardusRemotes:FindFirstChild("ThrowKardus"))

local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
local NotifikasiRemote = RemotesFolder and RemotesFolder:FindFirstChild("Notifikasi")

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
-- DAFTAR PRODUK MINUMAN & DAGING DARI ReplicatedStorage.Product
-- ==========================================
local daftarProdukMinuman = {}
local daftarProdukDaging = {}

local function muatDaftarLisensi(namaKategori, tabelTujuan)
    for k in pairs(tabelTujuan) do
        tabelTujuan[k] = nil
    end

    local folderProduct = ReplicatedStorage:FindFirstChild("Product")
    local folderKategori = folderProduct and folderProduct:FindFirstChild(namaKategori)
    if not folderKategori then return end

    for _, lisensiFolder in ipairs(folderKategori:GetChildren()) do
        if lisensiFolder.Name:lower():find("^lisensi") then
            for _, item in ipairs(lisensiFolder:GetChildren()) do
                tabelTujuan[item.Name:lower()] = item.Name
            end
        end
    end
end

local function muatSemuaDaftarProduk()
    muatDaftarLisensi("Minuman", daftarProdukMinuman)
    muatDaftarLisensi("Daging", daftarProdukDaging)
end

muatSemuaDaftarProduk()

-- ==========================================
-- KONFIGURASI ANTREAN PRIORITAS & ANTI-STUCK
-- ==========================================
local MAX_SLOT_MINUMAN = 8 -- Kulkas1..KulkasX (Rak1 - Rak8)
local MAX_SLOT_DAGING = 4  -- KulkasDaging1..KulkasDagingX (Rak1 - Rak4)
local ITEMS_PER_SLOT = 12

local autoMinumanEnabled = false
local autoDagingEnabled = false
local urutanPrioritas = {} -- Menyimpan urutan kategori yang dinyalakan duluan

local jedaAntarSlot = 0.30
local sedangMengisi = false

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

local function aturPrioritasKategori(kategori, aktif)
    for i = #urutanPrioritas, 1, -1 do
        if urutanPrioritas[i] == kategori then
            table.remove(urutanPrioritas, i)
        end
    end
    if aktif then
        table.insert(urutanPrioritas, kategori)
    end
end

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
-- DETEKSI NAMA PRODUK & FILTER KATEGORI
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

local function cekCocokKategori(namaProduk, kategori)
    if not namaProduk or namaProduk == "" then return false, nil end

    local tabelRef = (kategori == "Minuman") and daftarProdukMinuman or daftarProdukDaging
    if next(tabelRef) == nil then
        muatSemuaDaftarProduk()
    end

    local kunci = namaProduk:lower():gsub("%s+", "")
    if tabelRef[namaProduk:lower()] then
        return true, tabelRef[namaProduk:lower()]
    end

    for k, namaAsli in pairs(tabelRef) do
        if k:gsub("%s+", "") == kunci then
            return true, namaAsli
        end
    end

    return false, nil
end

local function ambilDaftarKardusKategori(kategori)
    local daftar = {}
    for _, v in ipairs(clickObject:GetChildren()) do
        if v.Name == "Kardus" then
            local skip = kardusDitolakSementara[v] and tick() < kardusDitolakSementara[v]
            if not skip then
                local namaTerdeteksi = deteksiNamaProdukKardus(v)
                local valid, namaResmi = cekCocokKategori(namaTerdeteksi, kategori)
                if valid and namaResmi then
                    table.insert(daftar, {
                        obj = v,
                        nama = namaResmi
                    })
                end
            end
        end
    end
    return daftar
end

-- ==========================================
-- PEMINDAIAN SLOT KULKAS KOSONG
-- ==========================================
local function apakahSlotKosong(rakPart)
    if not rakPart or not rakPart:IsA("BasePart") then return false end

    if slotDitolakServer[rakPart] and tick() < slotDitolakServer[rakPart] then
        return false
    end

    local clientInstances = rakPart:FindFirstChild("ClientItemInstances")
    if clientInstances and #clientInstances:GetChildren() > 0 then
        return false
    end

    return true
end

local function cariSlotKosongKategori(kategori)
    local daftarSlotKosong = {}
    local daftarModel = {}

    local polaNama = (kategori == "Minuman") and "^kulkas%d+$" or "^kulkasdaging%d+$"
    local maxSlot = (kategori == "Minuman") and MAX_SLOT_MINUMAN or MAX_SLOT_DAGING

    for _, model in ipairs(clickObject:GetChildren()) do
        if model.Name:lower():match(polaNama) and model:FindFirstChild("InputRak") then
            table.insert(daftarModel, model)
        end
    end

    table.sort(daftarModel, function(a, b)
        local numA = tonumber(a.Name:match("%d+")) or 9999
        local numB = tonumber(b.Name:match("%d+")) or 9999
        if numA ~= numB then return numA < numB end
        return a.Name < b.Name
    end)

    for _, modelKulkas in ipairs(daftarModel) do
        local inputRak = modelKulkas:FindFirstChild("InputRak")
        if inputRak then
            for i = 1, maxSlot do
                local slotPart = inputRak:FindFirstChild("Rak" .. tostring(i))
                if slotPart and apakahSlotKosong(slotPart) then
                    table.insert(daftarSlotKosong, slotPart)
                end
            end
        end
    end

    return daftarSlotKosong, #daftarModel
end

-- ==========================================
-- GENERATE CFRAME SUSUNAN ITEM DI DALAM SLOT KULKAS
-- ==========================================
local function buatSusunanCFrameKulkas(rakPart)
    local daftarCFrame = {}
    local cfBase = rakPart.CFrame
    local sz = rakPart.Size

    local cols = 4
    local rows = 3
    local tinggiY = (sz.Y * 0.5) + 0.35

    for r = 1, rows do
        for c = 1, cols do
            if #daftarCFrame < ITEMS_PER_SLOT then
                local offsetX = ((c - (cols + 1) / 2) / cols) * (sz.X * 0.78)
                local offsetZ = ((r - (rows + 1) / 2) / rows) * (sz.Z * 0.78)
                table.insert(daftarCFrame, cfBase * CFrame.new(offsetX, tinggiY, offsetZ))
            end
        end
    end

    return daftarCFrame
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

    -- 1. Coba drop lewat remote jika tersedia
    if DropKardusRemote then
        pcall(function() DropKardusRemote:FireServer() end)
        pcall(function() DropKardusRemote:FireServer(picked) end)
        task.wait(0.15)
    end

    -- 2. Jika masih menempel di karakter, coba taruh ke RakPenyimpanan kosong (gudang) agar tangan bebas
    if cariKardusPickedDiKarakter() then
        for _, modelRak in ipairs(clickObject:GetChildren()) do
            if modelRak.Name:lower():find("^rakpenyimpanan") then
                local inputRak = modelRak:FindFirstChild("InputRak")
                if inputRak then
                    for i = 1, 6 do
                        local slotGudang = inputRak:FindFirstChild("Rak" .. tostring(i))
                        if slotGudang and not (slotDitolakServer[slotGudang] and tick() < slotDitolakServer[slotGudang]) then
                            local kc = slotGudang:FindFirstChild("Kardus" .. tostring(i))
                            if not kc or not kc:FindFirstChild("Kardus") then
                                slotTerakhirDitembak = slotGudang
                                PlaceOilRemote:FireServer(slotGudang)
                                task.wait(0.15)
                                if not cariKardusPickedDiKarakter() then
                                    percobaanGagalTangan = 0
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end
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

local function ambilSatuKardus(detailKardus, kategori)
    local existing = cariKardusPickedDiKarakter()
    if existing then
        local namaTangan = deteksiNamaProdukKardus(existing)
        local valid, namaResmi = cekCocokKategori(namaTangan, kategori)
        if valid and namaResmi then
            if PickupKardusRemote then
                pcall(function() PickupKardusRemote:FireServer(existing, namaResmi) end)
            end
            return existing, namaResmi
        end
        return nil, nil
    end

    local kardusObj = detailKardus.obj
    if not kardusObj or not kardusObj.Parent then return nil, nil end

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
        kardusDitolakSementara[kardusObj] = tick() + 6
        return nil, nil
    end

    percobaanGagalTangan = 0
    local namaFinal = detailKardus.nama
    if PickupKardusRemote then
        pcall(function() PickupKardusRemote:FireServer(picked, namaFinal) end)
        task.wait(0.08)
        return picked, namaFinal
    end

    return nil, nil
end

-- ==========================================
-- UPDATE UI STATUS & EKSEKUSI ANTREAN PRIORITAS
-- ==========================================
local StatusKulkasCard

local function perbaruiStatusUI(teksStatus)
    if not StatusKulkasCard then return end

    local slotMinuman, totalMinuman = cariSlotKosongKategori("Minuman")
    local kardusMinuman = ambilDaftarKardusKategori("Minuman")

    local slotDaging, totalDaging = cariSlotKosongKategori("Daging")
    local kardusDaging = ambilDaftarKardusKategori("Daging")

    local teksAntrean = (#urutanPrioritas > 0) and table.concat(urutanPrioritas, " -> ") or "Tidak ada"

    API.SetElementText(
        StatusKulkasCard,
        "Minuman: " .. tostring(#slotMinuman) .. " slot (" .. tostring(#kardusMinuman) .. " kardus)  |  Daging: " .. tostring(#slotDaging) .. " slot (" .. tostring(#kardusDaging) .. " kardus)",
        "Prioritas: " .. teksAntrean .. "  |  Status: " .. teksStatus
    )
end

local function prosesSatuKategori(kategori, wajibAktif)
    local terisi = 0

    while (wajibAktif or (kategori == "Minuman" and autoMinumanEnabled) or (kategori == "Daging" and autoDagingEnabled)) do
        local daftarSlotKosong = cariSlotKosongKategori(kategori)
        if #daftarSlotKosong == 0 then
            -- Jika slot kategori ini sudah PENUH semua, bersihkan tangan jika sedang pegang kategori ini
            local pickedSisa = cariKardusPickedDiKarakter()
            if pickedSisa then
                local namaTangan = deteksiNamaProdukKardus(pickedSisa)
                local validSama = cekCocokKategori(namaTangan, kategori)
                if validSama then
                    lepasKardusStuckDiTangan()
                end
            end
            break
        end

        local targetSlot = daftarSlotKosong[1]
        if not targetSlot or not targetSlot.Parent then break end

        local picked = cariKardusPickedDiKarakter()
        local namaProduk = nil

        if picked then
            local namaTangan = deteksiNamaProdukKardus(picked)
            local valid, namaResmi = cekCocokKategori(namaTangan, kategori)
            if not valid then
                -- Kardus di tangan bukan kategori ini (misal sedang giliran Minuman tapi tangan pegang Daging)
                -- Cek apakah kategori lain sedang aktif & punya slot kosong; kalau tidak, lepas supaya tidak stuck!
                local kategoriLain = (kategori == "Minuman") and "Daging" or "Minuman"
                local validLain = cekCocokKategori(namaTangan, kategoriLain)
                local slotLain = cariSlotKosongKategori(kategoriLain)
                if not (validLain and (wajibAktif or (kategoriLain == "Minuman" and autoMinumanEnabled) or (kategoriLain == "Daging" and autoDagingEnabled)) and #slotLain > 0) then
                    lepasKardusStuckDiTangan()
                end
                break
            end
            namaProduk = namaResmi
            pcall(function() PickupKardusRemote:FireServer(picked, namaProduk) end)
            task.wait(0.06)
        else
            local daftarKardus = ambilDaftarKardusKategori(kategori)
            if #daftarKardus == 0 then break end
            picked, namaProduk = ambilSatuKardus(daftarKardus[1], kategori)
        end

        if not picked or not namaProduk then break end

        perbaruiStatusUI("Mengisi " .. namaProduk .. " ke " .. targetSlot.Parent.Parent.Name .. "." .. targetSlot.Name)

        slotTerakhirDitembak = targetSlot
        PlaceOilRemote:FireServer(targetSlot)
        task.wait(0.12)

        local susunanCF = buatSusunanCFrameKulkas(targetSlot)
        PlaceOilDoneRemote:FireServer(targetSlot, susunanCF, namaProduk)

        local terkonfirmasi = false
        for _ = 1, 14 do
            task.wait(0.10)
            if not cariKardusPickedDiKarakter() or not apakahSlotKosong(targetSlot) then
                terkonfirmasi = true
                break
            end
        end

        if terkonfirmasi then
            terisi = terisi + 1
            percobaanGagalTangan = 0
            task.wait(jedaAntarSlot)
        else
            slotDitolakServer[targetSlot] = tick() + 45
            percobaanGagalTangan = percobaanGagalTangan + 1

            -- Anti-Stuck: Jika kardus yang sama gagal masuk 2x berturut-turut, lepas kardusnya agar tidak nyangkut
            if percobaanGagalTangan >= 2 then
                lepasKardusStuckDiTangan()
            end
        end
    end

    return terisi
end

local function jalankanSiklusKulkas(sekaliJalan)
    if sedangMengisi then return end
    if not PickupKardusRemote or not PlaceOilRemote or not PlaceOilDoneRemote then return end

    sedangMengisi = true

    task.spawn(function()
        local totalTerisi = 0
        local ok, err = pcall(function()
            -- Jalankan berurutan sesuai urutan toggle pertama kali dinyalakan (selesaikan 1 sampai penuh/habis, baru ke 2)
            local daftarEksekusi = {}
            if sekaliJalan then
                daftarEksekusi = { "Minuman", "Daging" }
            else
                for _, kat in ipairs(urutanPrioritas) do
                    table.insert(daftarEksekusi, kat)
                end
            end

            for _, kat in ipairs(daftarEksekusi) do
                if sekaliJalan or (kat == "Minuman" and autoMinumanEnabled) or (kat == "Daging" and autoDagingEnabled) then
                    totalTerisi = totalTerisi + prosesSatuKategori(kat, sekaliJalan)
                end
            end
        end)

        if not ok and err then
            warn("[AutoKulkas Error]:", err)
        end

        sedangMengisi = false
        local adaYangAktif = autoMinumanEnabled or autoDagingEnabled
        perbaruiStatusUI(adaYangAktif and "Siaga (Aktif)" or "Nonaktif")

        if sekaliJalan then
            API.Notify("Selesai", "Berhasil mengisi " .. tostring(totalTerisi) .. " slot kulkas.", 3)
        end
    end)
end

-- ==========================================
-- TRIGGER EVENT-DRIVEN (ANTI-LAG TANPA LOOPING)
-- ==========================================
clickObject.ChildAdded:Connect(function(child)
    if child.Name == "Kardus" then
        task.wait(0.25)
        local adaYangAktif = autoMinumanEnabled or autoDagingEnabled
        perbaruiStatusUI(adaYangAktif and "Kardus baru terdeteksi..." or "Nonaktif")
        if adaYangAktif then
            jalankanSiklusKulkas(false)
        end
    end
end)

clickObject.ChildRemoved:Connect(function(child)
    if child.Name == "Kardus" and not sedangMengisi then
        local adaYangAktif = autoMinumanEnabled or autoDagingEnabled
        perbaruiStatusUI(adaYangAktif and "Siaga (Aktif)" or "Nonaktif")
    end
end)

-- ==========================================
-- UI TAB: KULKAS (MINUMAN & DAGING)
-- ==========================================
local KulkasTab = API.CreateTab("Kulkas")

API.Section(KulkasTab, "Status Kulkas (" .. PlotToko.Name .. ")")
StatusKulkasCard = API.Paragraph(
    KulkasTab,
    "Minuman: -  |  Daging: -",
    "Prioritas: Tidak ada  |  Status: Nonaktif"
)

API.Section(KulkasTab, "Pengaturan Umum")
API.Slider(KulkasTab, "Jeda Antar Slot (Detik)", 0.20, 1.50, 0.05, " detik", 0.30, function(val)
    jedaAntarSlot = tonumber(val) or 0.30
end)

-- FITUR 1: KULKAS MINUMAN
API.Section(KulkasTab, "Kulkas Minuman (8 Slot / Unit)")
API.Toggle(KulkasTab, "Auto Isi Kulkas Minuman", false, function(val)
    autoMinumanEnabled = val
    aturPrioritasKategori("Minuman", val)
    if val then
        API.Notify("Kulkas Minuman Aktif", "Antrean: " .. table.concat(urutanPrioritas, " -> "), 2)
        jalankanSiklusKulkas(false)
    else
        API.Notify("Kulkas Minuman Mati", "Auto isi kulkas minuman dihentikan.", 2)
        perbaruiStatusUI(autoDagingEnabled and "Siaga (Event-Driven Aktif)" or "Nonaktif")
    end
end)

API.Paragraph(
    KulkasTab,
    "Penjelasan Kulkas Minuman",
    "Mengambil makanan Minuman dari toko lalu menaruhnya ke slot kosong kulkas."
)

-- FITUR 2: KULKAS DAGING
API.Section(KulkasTab, "Kulkas Daging (4 Slot / Unit)")
API.Toggle(KulkasTab, "Auto Isi Kulkas Daging", false, function(val)
    autoDagingEnabled = val
    aturPrioritasKategori("Daging", val)
    if val then
        API.Notify("Kulkas Daging Aktif", "Antrean: " .. table.concat(urutanPrioritas, " -> "), 2)
        jalankanSiklusKulkas(false)
    else
        API.Notify("Kulkas Daging Mati", "Auto isi kulkas daging dihentikan.", 2)
        perbaruiStatusUI(autoMinumanEnabled and "Siaga (Event-Driven Aktif)" or "Nonaktif")
    end
end)

API.Paragraph(
    KulkasTab,
    "Penjelasan Kulkas Daging",
    "Mengambil daging dari toko lalu menaruhnya ke slot kosong kulkas."
)

-- AKSI MANUAL & RESET
API.Section(KulkasTab, "Aksi Manual")
API.Button(KulkasTab, "Isi Semua Kulkas Sekarang", function()
    jalankanSiklusKulkas(true)
end)

API.Button(KulkasTab, "Refresh Daftar & Atur Ulang", function()
    slotDitolakServer = {}
    kardusDitolakSementara = {}
    percobaanGagalTangan = 0
    muatSemuaDaftarProduk()
    local adaYangAktif = autoMinumanEnabled or autoDagingEnabled
    perbaruiStatusUI(adaYangAktif and "Siaga (Aktif)" or "Nonaktif")
    API.Notify("Diperbarui", "Daftar produk Minuman & Daging diperbarui.", 2)
end)

perbaruiStatusUI("Nonaktif")
