local API = ...

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KardusRemotes = (API and API.Remotes and API.Remotes.Kardus) or ReplicatedStorage:WaitForChild("KardusRemotes", 10)
local PickupKardusRemote = KardusRemotes and KardusRemotes:FindFirstChild("PickupKardus")
local PlaceOilRemote = KardusRemotes and KardusRemotes:FindFirstChild("PlaceOil")
local PlaceOilDoneRemote = KardusRemotes and KardusRemotes:FindFirstChild("PlaceOilDone")

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
-- DAFTAR PRODUK MINUMAN DARI ReplicatedStorage.Product.Minuman (Lisensi_X)
-- ==========================================
local daftarProdukMinuman = {}

local function muatDaftarMinuman()
    daftarProdukMinuman = {}
    local folderProduct = ReplicatedStorage:FindFirstChild("Product")
    local folderMinuman = folderProduct and folderProduct:FindFirstChild("Minuman")
    if not folderMinuman then return end

    for _, lisensiFolder in ipairs(folderMinuman:GetChildren()) do
        if lisensiFolder.Name:lower():find("^lisensi") then
            for _, item in ipairs(lisensiFolder:GetChildren()) do
                daftarProdukMinuman[item.Name:lower()] = item.Name
            end
        end
    end
end

muatDaftarMinuman()

-- ==========================================
-- KONFIGURASI AUTO KULKAS (8 SLOT: Rak1 - Rak8)
-- ==========================================
local MAX_SLOT_KULKAS = 8
local ITEMS_PER_SLOT = 12
local autoKulkasEnabled = false
local jedaAntarSlot = 0.30
local sedangMengisiKulkas = false
local slotDitolakServer = {}
local kardusDitolakSementara = {}
local slotTerakhirDitembak = nil

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
            if pLower:find("sudah terisi") or pLower:find("penuh") or pLower:find("tidak sesuai") or pLower:find("hanya minuman") then
                slotDitolakServer[slotTerakhirDitembak] = tick() + 60
            end
        end
    end)
end

-- ==========================================
-- DETEKSI NAMA PRODUK & FILTER MINUMAN
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

local function apakahProdukMinuman(namaProduk)
    if not namaProduk or namaProduk == "" then return false, nil end
    if next(daftarProdukMinuman) == nil then
        muatDaftarMinuman()
    end

    local kunci = namaProduk:lower():gsub("%s+", "")
    if daftarProdukMinuman[namaProduk:lower()] then
        return true, daftarProdukMinuman[namaProduk:lower()]
    end

    for k, namaAsli in pairs(daftarProdukMinuman) do
        if k:gsub("%s+", "") == kunci then
            return true, namaAsli
        end
    end

    return false, nil
end

local function ambilDaftarKardusMinuman()
    local daftar = {}
    for _, v in ipairs(clickObject:GetChildren()) do
        if v.Name == "Kardus" then
            local skip = kardusDitolakSementara[v] and tick() < kardusDitolakSementara[v]
            if not skip then
                local namaTerdeteksi = deteksiNamaProdukKardus(v)
                local validMinuman, namaResmi = apakahProdukMinuman(namaTerdeteksi)
                if validMinuman and namaResmi then
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
-- PEMINDAIAN SLOT KULKAS KOSONG (Kulkas1, Kulkas2, dst. -> Rak1..Rak8)
-- ==========================================
local function apakahSlotKulkasKosong(rakPart)
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

local function cariSemuaSlotKulkasKosong()
    local daftarSlotKosong = {}
    local daftarKulkas = {}

    for _, model in ipairs(clickObject:GetChildren()) do
        -- Wajib persis "Kulkas" diikuti angka (Kulkas1, Kulkas2, dst.)
        -- KulkasDaging1 otomatis dilewati
        if model.Name:lower():match("^kulkas%d+$") and model:FindFirstChild("InputRak") then
            table.insert(daftarKulkas, model)
        end
    end

    table.sort(daftarKulkas, function(a, b)
        local numA = tonumber(a.Name:match("%d+")) or 9999
        local numB = tonumber(b.Name:match("%d+")) or 9999
        if numA ~= numB then return numA < numB end
        return a.Name < b.Name
    end)

    for _, modelKulkas in ipairs(daftarKulkas) do
        local inputRak = modelKulkas:FindFirstChild("InputRak")
        if inputRak then
            for i = 1, MAX_SLOT_KULKAS do
                local slotPart = inputRak:FindFirstChild("Rak" .. tostring(i))
                if slotPart and apakahSlotKulkasKosong(slotPart) then
                    table.insert(daftarSlotKosong, slotPart)
                end
            end
        end
    end

    return daftarSlotKosong, #daftarKulkas
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
-- AMBIL KARDUS JARAK JAUH (TANPA TELEPORT)
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

local function ambilSatuKardusMinuman(detailKardus)
    local existing = cariKardusPickedDiKarakter()
    if existing then
        local namaTangan = deteksiNamaProdukKardus(existing)
        local valid, namaResmi = apakahProdukMinuman(namaTangan)
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
        kardusDitolakSementara[kardusObj] = tick() + 4
        return nil, nil
    end

    local namaFinal = detailKardus.nama
    if PickupKardusRemote then
        pcall(function() PickupKardusRemote:FireServer(picked, namaFinal) end)
        task.wait(0.08)
        return picked, namaFinal
    end

    return nil, nil
end

-- ==========================================
-- EKSEKUSI UTAMA (3 TAHAP: Pickup -> PlaceOil -> PlaceOilDone)
-- ==========================================
local StatusKulkasCard

local function perbaruiStatusUI(teksStatus)
    if not StatusKulkasCard then return end
    local slotKosong, totalKulkas = cariSemuaSlotKulkasKosong()
    local kardusMinuman = ambilDaftarKardusMinuman()

    API.SetElementText(
        StatusKulkasCard,
        "Kulkas Minuman: " .. tostring(totalKulkas) .. " (" .. tostring(#slotKosong) .. " Slot Kosong)  |  Kardus Minuman: " .. tostring(#kardusMinuman),
        "Status: " .. teksStatus
    )
end

local function jalankanSiklusIsiKulkas(sekaliJalan)
    if sedangMengisiKulkas then return end
    if not PickupKardusRemote or not PlaceOilRemote or not PlaceOilDoneRemote then return end

    sedangMengisiKulkas = true
    local slotTerisiCount = 0

    task.spawn(function()
        local ok, err = pcall(function()
            while sekaliJalan or autoKulkasEnabled do
                local daftarSlotKosong = cariSemuaSlotKulkasKosong()
                if #daftarSlotKosong == 0 then
                    perbaruiStatusUI(autoKulkasEnabled and "Siaga (Semua slot kulkas penuh)" or "Nonaktif")
                    break
                end

                local targetSlot = daftarSlotKosong[1]
                if not targetSlot or not targetSlot.Parent then break end

                local picked = cariKardusPickedDiKarakter()
                local namaProduk = nil

                if picked then
                    local namaTangan = deteksiNamaProdukKardus(picked)
                    local valid, namaResmi = apakahProdukMinuman(namaTangan)
                    if not valid then
                        perbaruiStatusUI("Menunggu (Kardus di tangan bukan minuman)")
                        break
                    end
                    namaProduk = namaResmi
                    pcall(function() PickupKardusRemote:FireServer(picked, namaProduk) end)
                    task.wait(0.06)
                else
                    local daftarKardus = ambilDaftarKardusMinuman()
                    if #daftarKardus == 0 then
                        perbaruiStatusUI(autoKulkasEnabled and "Siaga (Menunggu kardus minuman...)" or "Nonaktif")
                        break
                    end
                    picked, namaProduk = ambilSatuKardusMinuman(daftarKardus[1])
                end

                if not picked or not namaProduk then break end

                perbaruiStatusUI("Mengisi " .. namaProduk .. " ke " .. targetSlot.Parent.Parent.Name .. "." .. targetSlot.Name)

                -- Tahap 2: PlaceOil ke KulkasX.InputRak.Rak1..Rak8
                slotTerakhirDitembak = targetSlot
                PlaceOilRemote:FireServer(targetSlot)
                task.wait(0.12)

                -- Tahap 3: PlaceOilDone(targetSlot, tableCFrame, namaProduk)
                local susunanCF = buatSusunanCFrameKulkas(targetSlot)
                PlaceOilDoneRemote:FireServer(targetSlot, susunanCF, namaProduk)

                local terkonfirmasi = false
                for _ = 1, 14 do
                    task.wait(0.10)
                    if not cariKardusPickedDiKarakter() or not apakahSlotKulkasKosong(targetSlot) then
                        terkonfirmasi = true
                        break
                    end
                end

                if terkonfirmasi then
                    slotTerisiCount = slotTerisiCount + 1
                    perbaruiStatusUI("Berhasil mengisi " .. namaProduk)
                    task.wait(jedaAntarSlot)
                else
                    slotDitolakServer[targetSlot] = tick() + 45
                end
            end
        end)

        if not ok and err then
            warn("[AutoKulkas Error]:", err)
        end

        sedangMengisiKulkas = false
        if sekaliJalan then
            API.Notify("Selesai", "Berhasil mengisi " .. tostring(slotTerisiCount) .. " slot kulkas.", 3)
            perbaruiStatusUI(autoKulkasEnabled and "Siaga" or "Nonaktif")
        end
    end)
end

-- ==========================================
-- TRIGGER EVENT-DRIVEN (ANTI-LAG TANPA LOOPING)
-- ==========================================
clickObject.ChildAdded:Connect(function(child)
    if child.Name == "Kardus" then
        task.wait(0.25)
        perbaruiStatusUI(autoKulkasEnabled and "Kardus baru terdeteksi..." or "Nonaktif")
        if autoKulkasEnabled then
            jalankanSiklusIsiKulkas(false)
        end
    end
end)

clickObject.ChildRemoved:Connect(function(child)
    if child.Name == "Kardus" and not sedangMengisiKulkas then
        perbaruiStatusUI(autoKulkasEnabled and "Siaga (Menunggu kardus minuman...)" or "Nonaktif")
    end
end)

-- ==========================================
-- UI TAB: KULKAS
-- ==========================================
local KulkasTab = API.CreateTab("Kulkas")

API.Section(KulkasTab, "Status Kulkas (" .. PlotToko.Name .. ")")
StatusKulkasCard = API.Paragraph(
    KulkasTab,
    "Kulkas Minuman: -  |  Kardus Minuman: -",
    "Status: Nonaktif"
)

API.Section(KulkasTab, "Kontrol Auto Kulkas")
API.Slider(KulkasTab, "Jeda Antar Slot (Detik)", 0.20, 1.50, 0.05, " dtk", 0.30, function(val)
    jedaAntarSlot = tonumber(val) or 0.30
end)

API.Toggle(KulkasTab, "Auto Isi Kulkas (Minuman)", false, function(val)
    autoKulkasEnabled = val
    if val then
        API.Notify("Auto Kulkas Aktif", "Memindai kardus Minuman (Lisensi_X) & mengisi Kulkas1..KulkasX.", 2)
        jalankanSiklusIsiKulkas(false)
    else
        API.Notify("Auto Kulkas Mati", "Auto isi kulkas dihentikan.", 2)
        perbaruiStatusUI("Nonaktif")
    end
end)

API.Paragraph(
    KulkasTab,
    "Cara Kerja Auto Kulkas",
    "Mengambil kardus yang terdaftar di ReplicatedStorage.Product.Minuman (Lisensi_X) dan menatanya ke slot kosong Rak1 - Rak8 khusus pada Kulkas1..KulkasX (melewati KulkasDagingX)."
)

API.Button(KulkasTab, "Isi Semua Kulkas Sekarang (1x)", function()
    jalankanSiklusIsiKulkas(true)
end)

API.Button(KulkasTab, "Reset Cache & Refresh Lisensi Minuman", function()
    slotDitolakServer = {}
    kardusDitolakSementara = {}
    muatDaftarMinuman()
    perbaruiStatusUI(autoKulkasEnabled and "Siaga" or "Nonaktif")
    API.Notify("Direset", "Daftar Minuman (Lisensi_X) & cache slot kulkas diperbarui.", 2)
end)

perbaruiStatusUI("Nonaktif")
