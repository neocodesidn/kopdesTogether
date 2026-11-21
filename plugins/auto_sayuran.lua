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
-- DAFTAR PRODUK SAYURAN DARI ReplicatedStorage.Product.Sayuran (Default & Lisensi_X)
-- ==========================================
local daftarProdukSayuran = {}

local function muatDaftarSayuran()
    daftarProdukSayuran = {}
    local folderProduct = ReplicatedStorage:FindFirstChild("Product")
    local folderSayuran = folderProduct and folderProduct:FindFirstChild("Sayuran")
    if not folderSayuran then return end

    for _, lisensiFolder in ipairs(folderSayuran:GetChildren()) do
        local namaSub = lisensiFolder.Name:lower()
        if namaSub == "default" or namaSub:find("^lisensi") or namaSub:find("^license") then
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
local function dapatkanFolderItemSlot(rakPart)
    return rakPart:FindFirstChild("ClientItemInstances")
        or rakPart:FindFirstChild("InstacesItem")
        or rakPart:FindFirstChild("InstanceItem")
end

local function apakahSlotSayuranKosong(rakPart)
    if not rakPart or not rakPart:IsA("BasePart") then return false end

    if slotDitolakServer[rakPart] and tick() < slotDitolakServer[rakPart] then
        return false
    end

    local clientInstances = dapatkanFolderItemSlot(rakPart)
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
        for _, modelRak in ipairs(PlotToko:GetDescendants()) do
            if modelRak.Name:lower():find("rakpenyimpanan") then
                local inputRak = modelRak:FindFirstChild("InputRak")
                if inputRak then
                    for i = 1, 6 do
                        local slotGudang = inputRak:FindFirstChild("Rak" .. tostring(i))
                        if slotGudang and not slotGudang:FindFirstChild("Kardus") and not (slotDitolakServer[slotGudang] and tick() < slotDitolakServer[slotGudang]) then
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
-- UPDATE UI STATUS & EKSEKUSI REAL-TIME
-- ==========================================
local StatusSayuranCard
local lastSlotSayuran = -1
local lastKardusSayuran = -1
local lastToggleSayuran = nil

local function perbaruiStatusUI(slotOpsional, kardusOpsional)
    if not StatusSayuranCard then return end

    local slotKosong = slotOpsional or cariSemuaSlotSayuranKosong()
    local kardusSayuran = kardusOpsional or ambilDaftarKardusSayuran()

    local jmlSlot = #slotKosong
    local jmlKardus = #kardusSayuran

    if jmlSlot == lastSlotSayuran and jmlKardus == lastKardusSayuran and autoSayuranEnabled == lastToggleSayuran then
        return
    end

    lastSlotSayuran = jmlSlot
    lastKardusSayuran = jmlKardus
    lastToggleSayuran = autoSayuranEnabled

    API.SetElementText(
        StatusSayuranCard,
        "Slot Kosong: " .. tostring(jmlSlot) .. "  |  Kardus Sayuran: " .. tostring(jmlKardus),
        "Status: " .. (autoSayuranEnabled and "Aktif" or "Nonaktif")
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
                    perbaruiStatusUI()
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
        perbaruiStatusUI()

        if sekaliJalan then
            API.Notify("Selesai", "Berhasil mengisi " .. tostring(terisiCount) .. " slot Rak Sayuran.", 3)
        end
    end)
end

-- ==========================================
-- LISTENER REAL-TIME RAK SAYURAN + LANTAI
-- ==========================================
local rakSayuranListener = {}

local function pasangListenerRakSayuran(modelRak)
    if rakSayuranListener[modelRak] then return end
    if not modelRak.Name:lower():match("^raksayuran%d+$") then return end

    local inputRak = modelRak:FindFirstChild("InputRak")
    if not inputRak then return end

    rakSayuranListener[modelRak] = true

    for i = 1, MAX_SLOT_SAYURAN do
        local slotPart = inputRak:FindFirstChild("Rak" .. tostring(i))
        if slotPart then
            local folderItem = dapatkanFolderItemSlot(slotPart)
            if folderItem then
                folderItem.ChildRemoved:Connect(function()
                    if #folderItem:GetChildren() == 0 then
                        perbaruiStatusUI()
                        if autoSayuranEnabled and not sedangMengisi then
                            jalankanSiklusSayuran(false)
                        end
                    end
                end)
                folderItem.ChildAdded:Connect(function()
                    if not sedangMengisi then
                        perbaruiStatusUI()
                    end
                end)
            end
        end
    end
end

for _, model in ipairs(clickObject:GetChildren()) do
    pasangListenerRakSayuran(model)
end

clickObject.ChildAdded:Connect(function(child)
    if child.Name == "Kardus" then
        task.wait(0.25)
        perbaruiStatusUI()
        if autoSayuranEnabled then
            jalankanSiklusSayuran(false)
        end
    elseif child.Name:lower():match("^raksayuran%d+$") then
        task.wait(0.25)
        pasangListenerRakSayuran(child)
        perbaruiStatusUI()
    end
end)

clickObject.ChildRemoved:Connect(function(child)
    if child.Name == "Kardus" and not sedangMengisi then
        perbaruiStatusUI()
    end
end)

-- ==========================================
-- UI TAB: [RESTOCK] SAYURAN (RAPI & TO THE POINT)
-- ==========================================
local SayuranTab = API.CreateTab("[RESTOCK] Sayuran")

-- 1. ATAS: DATA SLOT KOSONG & KARDUS SAYURAN TERSEDIA
StatusSayuranCard = API.Paragraph(
    SayuranTab,
    "Slot Kosong: 0  |  Kardus Sayuran: 0",
    "Status: Nonaktif"
)

-- 2. TENGAH: PENJELASAN CARA PEMAKAIAN
API.Paragraph(
    SayuranTab,
    "Cara Pemakaian",
    "Aktifkan toggle di bawah agar kardus kategori Sayuran otomatis diambil dan ditata ke rak sayuran yang kosong."
)

-- 3. BAWAH: FITUR & KONTROL
API.Section(SayuranTab, "Kontrol")

API.Toggle(SayuranTab, "Auto Isi Rak Sayuran", false, function(val)
    autoSayuranEnabled = val
    lastToggleSayuran = nil
    perbaruiStatusUI()
    if val then
        jalankanSiklusSayuran(false)
    end
end)

API.Slider(SayuranTab, "Jeda Antar Slot", 0.20, 1.50, 0.05, " dtk", 0.30, function(val)
    jedaAntarSlot = tonumber(val) or 0.30
end)

API.Button(SayuranTab, "Isi Sekarang (1x)", function()
    jalankanSiklusSayuran(true)
end)

API.Button(SayuranTab, "Refresh Data", function()
    slotDitolakServer = {}
    kardusDitolakSementara = {}
    percobaanGagalTangan = 0
    lastSlotSayuran = -1
    muatDaftarSayuran()
    for _, model in ipairs(clickObject:GetChildren()) do
        pasangListenerRakSayuran(model)
    end
    perbaruiStatusUI()
    API.Notify("Diperbarui", "Data slot dan kardus sayuran diperbarui.", 2)
end)

-- Sinkronisasi ringan setiap 0.6 detik tanpa GetDescendants (0% lag)
task.spawn(function()
    while true do
        task.wait(0.6)
        local slotKosong = cariSemuaSlotSayuranKosong()
        local kardusSayuran = ambilDaftarKardusSayuran()
        perbaruiStatusUI(slotKosong, kardusSayuran)
        if autoSayuranEnabled and not sedangMengisi and #slotKosong > 0 and #kardusSayuran > 0 then
            jalankanSiklusSayuran(false)
        end
    end
end)

perbaruiStatusUI()
