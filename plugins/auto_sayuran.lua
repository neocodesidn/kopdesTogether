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
-- DAFTAR PRODUK SAYURAN DARI ReplicatedStorage.Product.Sayuran (Lisensi_X)
-- ==========================================
local daftarProdukSayuran = {}

local function muatDaftarSayuran()
    daftarProdukSayuran = {}
    local folderProduct = ReplicatedStorage:FindFirstChild("Product")
    local folderSayuran = folderProduct and folderProduct:FindFirstChild("Sayuran")
    if not folderSayuran then return end

    for _, lisensiFolder in ipairs(folderSayuran:GetChildren()) do
        if lisensiFolder.Name:lower():find("^lisensi") then
            for _, item in ipairs(lisensiFolder:GetChildren()) do
                daftarProdukSayuran[item.Name:lower()] = item.Name
            end
        end
    end
end

muatDaftarSayuran()

-- ==========================================
-- KONFIGURASI AUTO SAYURAN (6 SLOT: Rak1 - Rak6)
-- ==========================================
local MAX_SLOT_SAYURAN = 6
local ITEMS_PER_SLOT = 12

local autoSayuranEnabled = false
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
-- DETEKSI NAMA PRODUK & FILTER SAYURAN
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

local function apakahProdukSayuran(namaProduk)
    if not namaProduk or namaProduk == "" then return false, nil end
    if next(daftarProdukSayuran) == nil then
        muatDaftarSayuran()
    end

    local kunci = namaProduk:lower():gsub("%s+", "")
    if daftarProdukSayuran[namaProduk:lower()] then
        return true, daftarProdukSayuran[namaProduk:lower()]
    end

    for k, namaAsli in pairs(daftarProdukSayuran) do
        if k:gsub("%s+", "") == kunci then
            return true, namaAsli
        end
    end

    return false, nil
end

local function ambilDaftarKardusSayuran()
    local daftar = {}
    for _, v in ipairs(clickObject:GetChildren()) do
        if v.Name == "Kardus" then
            local skip = kardusDitolakSementara[v] and tick() < kardusDitolakSementara[v]
            if not skip then
                local namaTerdeteksi = deteksiNamaProdukKardus(v)
                local valid, namaResmi = apakahProdukSayuran(namaTerdeteksi)
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
-- PEMINDAIAN SLOT RAK SAYURAN KOSONG (RakSayuran1..X -> Rak1..Rak6)
-- ==========================================
local function apakahSlotSayuranKosong(rakPart)
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

local function cariSemuaSlotSayuranKosong()
    local daftarSlotKosong = {}
    local daftarRak = {}

    for _, model in ipairs(clickObject:GetChildren()) do
        if model.Name:lower():match("^raksayuran%d+$") and model:FindFirstChild("InputRak") then
            table.insert(daftarRak, model)
        end
    end

    table.sort(daftarRak, function(a, b)
        local numA = tonumber(a.Name:match("%d+")) or 9999
        local numB = tonumber(b.Name:match("%d+")) or 9999
        if numA ~= numB then return numA < numB end
        return a.Name < b.Name
    end)

    for _, modelRak in ipairs(daftarRak) do
        local inputRak = modelRak:FindFirstChild("InputRak")
        if inputRak then
            for i = 1, MAX_SLOT_SAYURAN do
                local slotPart = inputRak:FindFirstChild("Rak" .. tostring(i))
                if slotPart and apakahSlotSayuranKosong(slotPart) then
                    table.insert(daftarSlotKosong, slotPart)
                end
            end
        end
    end

    return daftarSlotKosong, #daftarRak
end

-- ==========================================
-- GENERATE CFRAME SUSUNAN ITEM DI DALAM SLOT RAK SAYURAN
-- ==========================================
local function buatSusunanCFrameSayuran(rakPart)
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

    if DropKardusRemote then
        pcall(function() DropKardusRemote:FireServer() end)
        pcall(function() DropKardusRemote:FireServer(picked) end)
        task.wait(0.15)
    end

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

local function ambilSatuKardusSayuran(detailKardus)
    local existing = cariKardusPickedDiKarakter()
    if existing then
        local namaTangan = deteksiNamaProdukKardus(existing)
        local valid, namaResmi = apakahProdukSayuran(namaTangan)
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
-- UPDATE UI STATUS & EKSEKUSI UTAMA
-- ==========================================
local StatusSayuranCard

local function perbaruiStatusUI(teksStatus)
    if not StatusSayuranCard then return end

    local slotKosong, totalRak = cariSemuaSlotSayuranKosong()
    local kardusSayuran = ambilDaftarKardusSayuran()

    API.SetElementText(
        StatusSayuranCard,
        "-" .. tostring(#slotKosong) .. " Kardus",
        tostring(#kardusSayuran) .. " Kardus Tersederah"
    )
end

local function jalankanSiklusSayuran(sekaliJalan)
    if sedangMengisi then return end
    if not PickupKardusRemote or not PlaceOilRemote or not PlaceOilDoneRemote then return end

    sedangMengisi = true

    task.spawn(function()
        local terisiCount = 0
        local ok, err = pcall(function()
            while sekaliJalan or autoSayuranEnabled do
                local daftarSlotKosong = cariSemuaSlotSayuranKosong()
                if #daftarSlotKosong == 0 then
                    local pickedSisa = cariKardusPickedDiKarakter()
                    if pickedSisa and apakahProdukSayuran(deteksiNamaProdukKardus(pickedSisa)) then
                        lepasKardusStuckDiTangan()
                    end
                    break
                end

                local targetSlot = daftarSlotKosong[1]
                if not targetSlot or not targetSlot.Parent then break end

                local picked = cariKardusPickedDiKarakter()
                local namaProduk = nil

                if picked then
                    local namaTangan = deteksiNamaProdukKardus(picked)
                    local valid, namaResmi = apakahProdukSayuran(namaTangan)
                    if not valid then
                        break
                    end
                    namaProduk = namaResmi
                    pcall(function() PickupKardusRemote:FireServer(picked, namaProduk) end)
                    task.wait(0.06)
                else
                    local daftarKardus = ambilDaftarKardusSayuran()
                    if #daftarKardus == 0 then break end
                    picked, namaProduk = ambilSatuKardusSayuran(daftarKardus[1])
                end

                if not picked or not namaProduk then break end

                perbaruiStatusUI("Mengisi " .. namaProduk .. " ke " .. targetSlot.Parent.Parent.Name .. "." .. targetSlot.Name)

                slotTerakhirDitembak = targetSlot
                PlaceOilRemote:FireServer(targetSlot)
                task.wait(0.12)

                local susunanCF = buatSusunanCFrameSayuran(targetSlot)
                PlaceOilDoneRemote:FireServer(targetSlot, susunanCF, namaProduk)

                local terkonfirmasi = false
                for _ = 1, 14 do
                    task.wait(0.10)
                    if not cariKardusPickedDiKarakter() or not apakahSlotSayuranKosong(targetSlot) then
                        terkonfirmasi = true
                        break
                    end
                end

                if terkonfirmasi then
                    terisiCount = terisiCount + 1
                    percobaanGagalTangan = 0
                    task.wait(jedaAntarSlot)
                else
                    slotDitolakServer[targetSlot] = tick() + 45
                    percobaanGagalTangan = percobaanGagalTangan + 1
                    if percobaanGagalTangan >= 2 then
                        lepasKardusStuckDiTangan()
                    end
                end
            end
        end)

        if not ok and err then
            warn("[AutoSayuran Error]:", err)
        end

        sedangMengisi = false
        perbaruiStatusUI(autoSayuranEnabled and "Siaga (Aktif)" or "Nonaktif")

        if sekaliJalan then
            API.Notify("Selesai", "Berhasil mengisi " .. tostring(terisiCount) .. " slot Rak Sayuran.", 3)
        end
    end)
end

-- ==========================================
-- TRIGGER EVENT-DRIVEN (ANTI-LAG TANPA LOOPING)
-- ==========================================
clickObject.ChildAdded:Connect(function(child)
    if child.Name == "Kardus" then
        task.wait(0.25)
        perbaruiStatusUI(autoSayuranEnabled and "Kardus baru terdeteksi..." or "Nonaktif")
        if autoSayuranEnabled then
            jalankanSiklusSayuran(false)
        end
    end
end)

clickObject.ChildRemoved:Connect(function(child)
    if child.Name == "Kardus" and not sedangMengisi then
        perbaruiStatusUI(autoSayuranEnabled and "Siaga (Aktif)" or "Nonaktif")
    end
end)

-- ==========================================
-- UI TAB: SAYURAN
-- ==========================================
local SayuranTab = API.CreateTab("Sayuran")

API.Section(SayuranTab, "Status Rak Sayuran (" .. PlotToko.Name .. ")")
StatusSayuranCard = API.Paragraph(
    SayuranTab,
    "Rak Sayuran: -  |  Kardus Sayuran: -",
    "Status: Nonaktif"
)

API.Section(SayuranTab, "Kontrol Auto Sayuran")
API.Slider(SayuranTab, "Jeda Antar Slot (Detik)", 0.20, 1.50, 0.05, " detik", 0.30, function(val)
    jedaAntarSlot = tonumber(val) or 0.30
end)

API.Toggle(SayuranTab, "Auto Isi Rak Sayuran", false, function(val)
    autoSayuranEnabled = val
    if val then
        API.Notify("Auto Sayuran Aktif", "Mengisi produk Sayuran ke rak penyimpanan.", 2)
        jalankanSiklusSayuran(false)
    else
        API.Notify("Auto Sayuran Mati", "Auto isi rak sayuran dihentikan.", 2)
        perbaruiStatusUI("Nonaktif")
    end
end)

API.Paragraph(
    SayuranTab,
    "Penjelasan Auto Sayuran",
    "Mengambil sayuran dari toko lalu menaruhnya ke rak penyimpanan kosong."
)

API.Section(SayuranTab, "Aksi Manual")
API.Button(SayuranTab, "Isi Semua Rak Sayuran Sekarang", function()
    jalankanSiklusSayuran(true)
end)

API.Button(SayuranTab, "Refresh Daftar & Atur Ulang", function()
    slotDitolakServer = {}
    kardusDitolakSementara = {}
    percobaanGagalTangan = 0
    muatDaftarSayuran()
    perbaruiStatusUI(autoSayuranEnabled and "Siaga (Aktif)" or "Nonaktif")
    API.Notify("Diperbarui", "Daftar produk Sayuran diperbarui.", 2)
end)

perbaruiStatusUI("Nonaktif")
