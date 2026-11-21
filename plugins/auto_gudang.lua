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
-- KONFIGURASI AUTO GUDANG & ANTI-BENTROK
-- ==========================================
local autoGudangEnabled = false
local jedaAntarSlot = 0.25
local sedangMenyimpan = false

local slotDitolakServer = {}
local slotTerkunciLokal = {}
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
                slotDitolakServer[slotTerakhirDitembak] = tick() + 120
                slotTerkunciLokal[slotTerakhirDitembak] = true
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
-- PEMINDAIAN SLOT GUDANG KOSONG
-- RakPenyimpananX.InputRak.RakX (Kosong jika tidak ada child persis "Kardus")
-- ==========================================
local function apakahSlotGudangKosong(slotObj)
    if not slotObj or not slotObj.Parent then return false end

    -- 1. Kunci lokal (mencegah double-fire sebelum replikasi selesai)
    if slotTerkunciLokal[slotObj] then
        return false
    end

    -- 2. Cooldown penolakan server
    if slotDitolakServer[slotObj] and tick() < slotDitolakServer[slotObj] then
        return false
    end

    -- 3. Cek persis child bernama "Kardus" di dalam RakX (sesuai hierarki game)
    if slotObj:FindFirstChild("Kardus") then
        return false
    end

    return true
end

local function cariSemuaSlotGudangKosong()
    local daftarSlotKosong = {}
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
                    table.insert(daftarSlotKosong, slotObj)
                end
            end
        end
    end

    return daftarSlotKosong, #daftarRakGudang
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
-- UPDATE UI STATUS & EKSEKUSI 2 TAHAP (Pickup -> PlaceOil SAJA)
-- ==========================================
local StatusGudangCard

local function perbaruiStatusUI()
    if not StatusGudangCard then return end

    local slotKosong, totalRak = cariSemuaSlotGudangKosong()
    local kardusLantai = ambilDaftarKardusLantai()

    API.SetElementText(
        StatusGudangCard,
        "Slot Gudang Kosong: " .. tostring(#slotKosong) .. " (" .. tostring(totalRak) .. " Rak)  |  Kardus di Lantai: " .. tostring(#kardusLantai),
        "Status: " .. (autoGudangEnabled and "Aktif" or "Nonaktif")
    )
end

local function jalankanSiklusGudang(sekaliJalan)
    if sedangMenyimpan then return end
    if not PickupKardusRemote or not PlaceOilRemote then return end

    sedangMenyimpan = true

    task.spawn(function()
        local tersimpanCount = 0
        local ok, err = pcall(function()
            while sekaliJalan or autoGudangEnabled do
                local daftarSlotKosong = cariSemuaSlotGudangKosong()
                if #daftarSlotKosong == 0 then
                    break
                end

                local targetSlot = daftarSlotKosong[1]
                if not targetSlot or not targetSlot.Parent then break end

                local picked = cariKardusPickedDiKarakter()
                if not picked then
                    local daftarKardus = ambilDaftarKardusLantai()
                    if #daftarKardus == 0 then break end
                    picked = ambilSatuKardusKeTangan(daftarKardus[1])
                end

                if not picked then break end

                -- Kunci slot lokal seketika sebelum tembak remote agar tidak pernah bentrok
                slotTerkunciLokal[targetSlot] = true
                slotTerakhirDitembak = targetSlot

                -- TAHAP 2 SAJA: PlaceOil ke RakPenyimpananX.InputRak.RakX (TANPA PlaceOilDone)
                PlaceOilRemote:FireServer(targetSlot)

                local terkonfirmasi = false
                for _ = 1, 14 do
                    task.wait(0.10)
                    local masihDiTangan = cariKardusPickedDiKarakter()
                    local adaKardusDiSlot = targetSlot:FindFirstChild("Kardus") ~= nil
                    if not masihDiTangan or adaKardusDiSlot then
                        terkonfirmasi = true
                        break
                    end
                end

                if terkonfirmasi then
                    tersimpanCount = tersimpanCount + 1
                    percobaanGagalTangan = 0
                    perbaruiStatusUI()
                    task.wait(jedaAntarSlot)
                else
                    -- Jika gagal masuk, buka kunci lokal dan masukkan ke blacklist sementara 60 detik
                    slotTerkunciLokal[targetSlot] = nil
                    slotDitolakServer[targetSlot] = tick() + 60
                    percobaanGagalTangan = percobaanGagalTangan + 1
                    if percobaanGagalTangan >= 2 then
                        lepasKardusStuckDiTangan()
                    end
                end
            end
        end)

        if not ok and err then
            warn("[AutoGudang Error]:", err)
        end

        sedangMenyimpan = false
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
        perbaruiStatusUI()
        if autoGudangEnabled then
            jalankanSiklusGudang(false)
        end
    end
end)

clickObject.ChildRemoved:Connect(function(child)
    if child.Name == "Kardus" and not sedangMenyimpan then
        perbaruiStatusUI()
    end
end)

-- Jika kardus di dalam RakGudang diambil manual/NPC, buka kunci slotnya otomatis
PlotToko.DescendantRemoving:Connect(function(desc)
    if desc.Name == "Kardus" and desc.Parent and desc.Parent.Name:lower():match("^rak%d+$") then
        local slotObj = desc.Parent
        slotTerkunciLokal[slotObj] = nil
        slotDitolakServer[slotObj] = nil
        task.defer(perbaruiStatusUI)
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

-- 2. TENGAH: PENJELASAN CARA PEMAKAIAN
API.Paragraph(
    GudangTab,
    "Cara Pemakaian",
    "Aktifkan toggle di bawah untuk memindahkan kardus yang ada di lantai ke slot kosong Rak Penyimpanan (Gudang) secara otomatis."
)

-- 3. BAWAH: FITUR & KONTROL
API.Section(GudangTab, "Kontrol")

API.Toggle(GudangTab, "Auto Simpan ke Gudang", false, function(val)
    autoGudangEnabled = val
    perbaruiStatusUI()
    if val then
        jalankanSiklusGudang(false)
    end
end)

API.Slider(GudangTab, "Jeda Antar Kardus", 0.20, 1.50, 0.05, " dtk", 0.25, function(val)
    jedaAntarSlot = tonumber(val) or 0.25
end)

API.Button(GudangTab, "Simpan Semua Sekarang (1x)", function()
    jalankanSiklusGudang(true)
end)

API.Button(GudangTab, "Refresh Data", function()
    slotDitolakServer = {}
    slotTerkunciLokal = {}
    kardusDitolakSementara = {}
    percobaanGagalTangan = 0
    perbaruiStatusUI()
    API.Notify("Diperbarui", "Data slot gudang dan kardus diperbarui.", 2)
end)

perbaruiStatusUI()
