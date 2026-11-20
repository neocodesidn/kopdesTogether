local API = ...

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KardusRemotes = (API and API.Remotes and API.Remotes.Kardus) or ReplicatedStorage:WaitForChild("KardusRemotes", 10)
local PickupKardusRemote = KardusRemotes and KardusRemotes:FindFirstChild("PickupKardus")
local PlaceOilRemote = KardusRemotes and KardusRemotes:FindFirstChild("PlaceOil")

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
-- KONFIGURASI AUTO GUDANG
-- ==========================================
local autoGudangEnabled = false
local jedaAntarAksi = 0.25
local sedangBerjalan = false
local slotPenuhCache = {}
local slotTerakhirDitembak = nil
local adaTolakanTerakhir = false

-- Dengarkan balasan penolakan dari server ("❌ Slot rak sudah terisi!")
if NotifikasiRemote and NotifikasiRemote:IsA("RemoteEvent") then
    NotifikasiRemote.OnClientEvent:Connect(function(pesan)
        if typeof(pesan) == "string" and pesan:lower():find("sudah terisi") then
            adaTolakanTerakhir = true
            if slotTerakhirDitembak then
                slotPenuhCache[slotTerakhirDitembak] = tick() + 120
            end
        end
    end)
end

-- ==========================================
-- KUMPULKAN SEMUA SLOT RakPenyimpananX.InputRak.Rak1..Rak6
-- ==========================================
local function dapatkanDaftarSlotGudang(acak)
    local daftarSlot = {}
    for _, modelRak in ipairs(clickObject:GetChildren()) do
        if modelRak.Name:lower():find("^rakpenyimpanan") then
            local inputRak = modelRak:FindFirstChild("InputRak")
            if inputRak then
                for i = 1, 6 do
                    local slot = inputRak:FindFirstChild("Rak" .. tostring(i))
                    if slot and not (slotPenuhCache[slot] and tick() < slotPenuhCache[slot]) then
                        table.insert(daftarSlot, slot)
                    end
                end
            end
        end
    end

    if acak and #daftarSlot > 1 then
        for i = #daftarSlot, 2, -1 do
            local j = math.random(1, i)
            daftarSlot[i], daftarSlot[j] = daftarSlot[j], daftarSlot[i]
        end
    end

    return daftarSlot
end

-- ==========================================
-- AMBIL KARDUS APA SAJA DI LANTAI (RANDOM)
-- ==========================================
local function cariKardusDiTangan()
    local char = API.LocalPlayer.Character
    if not char then return nil end
    local upperTorso = char:FindFirstChild("UpperTorso")
    if upperTorso then
        local p = upperTorso:FindFirstChild("KardusPicked")
        if p then return p end
    end
    return char:FindFirstChild("KardusPicked", true)
end

local function ambilKardusRandom()
    local diTangan = cariKardusDiTangan()
    if diTangan then return diTangan end

    local daftarKardus = {}
    for _, obj in ipairs(clickObject:GetChildren()) do
        if obj.Name == "Kardus" then
            table.insert(daftarKardus, obj)
        end
    end

    if #daftarKardus == 0 then return nil end

    -- Pilih kardus secara acak
    local targetKardus = daftarKardus[math.random(1, #daftarKardus)]

    -- Picu interaksi jarak jauh (ClickDetector / ProximityPrompt)
    for _, desc in ipairs(targetKardus:GetDescendants()) do
        if desc:IsA("ClickDetector") and fireclickdetector then
            local dAsli = desc.MaxActivationDistance
            pcall(function() desc.MaxActivationDistance = 99999 end)
            pcall(fireclickdetector, desc, 0)
            pcall(function() desc.MaxActivationDistance = dAsli end)
        elseif desc:IsA("ProximityPrompt") and fireproximityprompt then
            local dAsli = desc.MaxActivationDistance
            local losAsli = desc.RequiresLineOfSight
            pcall(function()
                desc.MaxActivationDistance = 99999
                desc.RequiresLineOfSight = false
                fireproximityprompt(desc)
            end)
            pcall(function()
                desc.MaxActivationDistance = dAsli
                desc.RequiresLineOfSight = losAsli
            end)
        end
    end

    -- Tunggu kardus masuk ke tangan
    for step = 1, 20 do
        task.wait(0.05)
        local picked = cariKardusDiTangan()
        if picked then
            if PickupKardusRemote then
                pcall(function() PickupKardusRemote:FireServer(picked) end)
            end
            return picked
        end
        if step == 7 and PickupKardusRemote and targetKardus.Parent then
            pcall(function() PickupKardusRemote:FireServer(targetKardus) end)
        end
    end

    return nil
end

-- ==========================================
-- EKSEKUSI UTAMA (EVENT-DRIVEN / NON-SPAM)
-- ==========================================
local StatusGudangCard

local function updateTeksStatus(info)
    if StatusGudangCard then
        local jumlahKardus = 0
        for _, obj in ipairs(clickObject:GetChildren()) do
            if obj.Name == "Kardus" then
                jumlahKardus = jumlahKardus + 1
            end
        end
        API.SetElementText(
            StatusGudangCard,
            "Kardus di Lantai: " .. tostring(jumlahKardus),
            "Status: " .. info
        )
    end
end

local function prosesSimpanGudang(sekaliJalan)
    if sedangBerjalan then return end
    if not PickupKardusRemote or not PlaceOilRemote then return end

    sedangBerjalan = true
    local berhasilSimpan = 0

    task.spawn(function()
        while (sekaliJalan or autoGudangEnabled) do
            local daftarSlot = dapatkanDaftarSlotGudang(true)
            if #daftarSlot == 0 then
                updateTeksStatus("Semua slot sudah penuh (Refresh jika seharusnya kosong)")
                break
            end

            local picked = ambilKardusRandom()
            if not picked then
                updateTeksStatus(autoGudangEnabled and "Siaga (Menunggu kardus baru muncul...)" or "Nonaktif")
                break
            end

            updateTeksStatus("Menaruh kardus ke RakPenyimpanan...")

            -- Coba taruh ke slot acak sampai diterima server (tidak ditolak)
            local masuk = false
            local urutanSlot = 1
            while urutanSlot <= #daftarSlot do
                if not (sekaliJalan or autoGudangEnabled) then break end
                local targetSlot = daftarSlot[urutanSlot]
                urutanSlot = urutanSlot + 1
                if not cariKardusDiTangan() then
                    masuk = true
                    break
                end

                adaTolakanTerakhir = false
                slotTerakhirDitembak = targetSlot
                PlaceOilRemote:FireServer(targetSlot)

                task.wait(0.15)

                -- Jika ditolak server ("❌ Slot rak sudah terisi!"), lanjut ke slot berikutnya
                if not adaTolakanTerakhir then
                    -- Jika kardus sudah lepas dari tangan, berarti berhasil masuk
                    if not cariKardusDiTangan() then
                        masuk = true
                        berhasilSimpan = berhasilSimpan + 1
                        break
                    end
                end
            end

            if masuk then
                task.wait(jedaAntarAksi)
            else
                task.wait(0.3)
            end
        end

        sedangBerjalan = false
        if sekaliJalan then
            API.Notify("Selesai", "Berhasil menyimpan " .. tostring(berhasilSimpan) .. " kardus ke gudang.", 3)
            updateTeksStatus(autoGudangEnabled and "Siaga" or "Nonaktif")
        end
    end)
end

-- Trigger otomatis hanya saat ada objek "Kardus" baru muncul di lantai (Anti-Lag)
clickObject.ChildAdded:Connect(function(child)
    if child.Name == "Kardus" then
        updateTeksStatus(autoGudangEnabled and "Kardus baru terdeteksi..." or "Nonaktif")
        if autoGudangEnabled then
            task.wait(0.2)
            prosesSimpanGudang(false)
        end
    end
end)

clickObject.ChildRemoved:Connect(function(child)
    if child.Name == "Kardus" and not sedangBerjalan then
        updateTeksStatus(autoGudangEnabled and "Siaga (Menunggu kardus baru...)" or "Nonaktif")
    end
end)

-- ==========================================
-- UI TAB: GUDANG
-- ==========================================
local GudangTab = API.CreateTab("Gudang")

API.Section(GudangTab, "Auto Simpan Gudang (" .. PlotToko.Name .. ")")
StatusGudangCard = API.Paragraph(
    GudangTab,
    "Kardus di Lantai: 0",
    "Status: Nonaktif (Mode Acak & Otomatis)"
)

API.Slider(GudangTab, "Jeda Antar Kardus (Detik)", 0.15, 1.50, 0.05, " dtk", 0.25, function(val)
    jedaAntarAksi = tonumber(val) or 0.25
end)

API.Toggle(GudangTab, "Auto Simpan Kardus ke Gudang", false, function(val)
    autoGudangEnabled = val
    if val then
        API.Notify("Auto Gudang Aktif", "Mengambil kardus dari lantai & menaruhnya ke rak penyimpanan.", 2)
        prosesSimpanGudang(false)
    else
        API.Notify("Auto Gudang Mati", "Auto simpan gudang dihentikan.", 2)
        updateTeksStatus("Nonaktif")
    end
end)

API.Button(GudangTab, "Simpan Semua Kardus Sekarang (1x)", function()
    prosesSimpanGudang(true)
end)

API.Button(GudangTab, "Refresh Rak Gudang", function()
    slotPenuhCache = {}
    API.Notify("Refresh Rak Gudang", "Semua slot penyimpanan sudah bisa dipakai lagi.", 2)
    if autoGudangEnabled then
        prosesSimpanGudang(false)
    end
end)

updateTeksStatus("Nonaktif")
