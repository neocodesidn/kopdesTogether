local API = ...

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KardusRemotes = (API and API.Remotes and API.Remotes.Kardus) or ReplicatedStorage:WaitForChild("KardusRemotes", 10)
local PickupKardusRemote = KardusRemotes and KardusRemotes:FindFirstChild("PickupKardus")
local PlaceOilRemote = KardusRemotes and KardusRemotes:FindFirstChild("PlaceOil")

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
-- KONFIGURASI AUTO GUDANG (RakPenyimpananX: Rak1 - Rak6)
-- ==========================================
local MAX_SLOT_GUDANG = 6
local autoGudangEnabled = false
local jedaAntarSlot = 0.25
local sedangMengisiGudang = false
local slotDitolakServer = {}
local kardusDitolakSementara = {}

local kataGenerik = {
    kardus = true, karduspicked = true, box = true, handle = true, part = true,
    meshpart = true, union = true, unionoperation = true, lid = true, tutup = true,
    model = true, clickdetector = true, proximityprompt = true, surfacegui = true,
    billboardgui = true, weld = true, motor6d = true, attachment = true, decal = true, texture = true
}

-- ==========================================
-- DETEKSI NAMA PRODUK KARDUS (SEMUA KATEGORI DITERIMA)
-- ==========================================
local function deteksiNamaProdukKardus(objKardus)
    if not objKardus then return "Produk" end

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

    return "Produk"
end

local function ambilSemuaKardusDiLantai()
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
-- PEMINDAIAN SLOT KOSONG DI RakPenyimpananX (InputRak.Rak1..Rak6)
-- Struktur terisi: RakX -> KardusX -> Kardus (Model)
-- ==========================================
local function apakahSlotGudangKosong(rakPart, slotIndex)
    if not rakPart or not rakPart:IsA("BasePart") then return false end

    if slotDitolakServer[rakPart] and tick() < slotDitolakServer[rakPart] then
        return false
    end

    -- Cek model KardusX (misal Rak4 -> Kardus4)
    local kardusContainer = rakPart:FindFirstChild("Kardus" .. tostring(slotIndex))
        or rakPart:FindFirstChildWhichIsA("Model")

    if kardusContainer then
        -- Jika di dalam KardusX sudah ada Model "Kardus", berarti slot TERISI
        local isiKardus = kardusContainer:FindFirstChild("Kardus")
        if isiKardus then
            return false
        end
    end

    -- Jika ada child langsung bernama "Kardus" di dalam RakX, berarti slot TERISI
    if rakPart:FindFirstChild("Kardus") then
        return false
    end

    return true
end

local function cariSemuaSlotGudangKosong()
    local daftarSlotKosong = {}
    local daftarRakGudang = {}

    for _, modelRak in ipairs(clickObject:GetChildren()) do
        if modelRak.Name:lower():find("^rakpenyimpanan") and modelRak:FindFirstChild("InputRak") then
            table.insert(daftarRakGudang, modelRak)
        end
    end

    -- Urutkan RakPenyimpanan1, RakPenyimpanan2, dst.
    table.sort(daftarRakGudang, function(a, b)
        local numA = tonumber(a.Name:match("%d+")) or 9999
        local numB = tonumber(b.Name:match("%d+")) or 9999
        if numA ~= numB then return numA < numB end
        return a.Name < b.Name
    end)

    for _, modelRak in ipairs(daftarRakGudang) do
        local inputRak = modelRak:FindFirstChild("InputRak")
        if inputRak then
            for i = 1, MAX_SLOT_GUDANG do
                local slotPart = inputRak:FindFirstChild("Rak" .. tostring(i))
                if slotPart and apakahSlotGudangKosong(slotPart, i) then
                    table.insert(daftarSlotKosong, {
                        part = slotPart,
                        index = i
                    })
                end
            end
        end
    end

    return daftarSlotKosong
end

-- ==========================================
-- PENGAMBILAN KARDUS JARAK JAUH (TANPA TELEPORT)
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

local function ambilSatuKardusGudang(detailKardus)
    local existing = cariKardusPickedDiKarakter()
    if existing then
        local namaTangan = deteksiNamaProdukKardus(existing)
        if PickupKardusRemote then
            pcall(function() PickupKardusRemote:FireServer(existing, namaTangan) end)
        end
        return existing, namaTangan
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

    local namaFinal = deteksiNamaProdukKardus(picked)
    if namaFinal == "Produk" and detailKardus.nama ~= "Produk" then
        namaFinal = detailKardus.nama
    end

    if PickupKardusRemote then
        pcall(function() PickupKardusRemote:FireServer(picked, namaFinal) end)
        task.wait(0.08)
        return picked, namaFinal
    end

    return nil, nil
end

-- ==========================================
-- EKSEKUSI UTAMA (SIMPAN KARDUS KE RakPenyimpananX)
-- ==========================================
local function jalankanSiklusIsiGudang(abaikanToggle)
    if sedangMengisiGudang then return 0 end
    if not PickupKardusRemote or not PlaceOilRemote then
        return 0
    end

    sedangMengisiGudang = true
    local slotTerisiCount = 0

    local ok, err = pcall(function()
        while abaikanToggle or autoGudangEnabled do
            local daftarSlotKosong = cariSemuaSlotGudangKosong()
            if #daftarSlotKosong == 0 then break end

            local targetInfo = daftarSlotKosong[1]
            local targetSlot = targetInfo.part
            local slotIdx = targetInfo.index
            if not targetSlot or not targetSlot.Parent then break end

            local picked = cariKardusPickedDiKarakter()
            if not picked then
                local daftarKardus = ambilSemuaKardusDiLantai()
                if #daftarKardus == 0 then break end

                picked = ambilSatuKardusGudang(daftarKardus[1])
            else
                local namaTangan = deteksiNamaProdukKardus(picked)
                pcall(function() PickupKardusRemote:FireServer(picked, namaTangan) end)
                task.wait(0.06)
            end

            if not picked then break end

            -- Langsung taruh kardus ke RakPenyimpananX.InputRak.Rak1..Rak6
            PlaceOilRemote:FireServer(targetSlot)

            local terkonfirmasi = false
            for _ = 1, 12 do
                task.wait(0.10)
                if not cariKardusPickedDiKarakter() or not apakahSlotGudangKosong(targetSlot, slotIdx) then
                    terkonfirmasi = true
                    break
                end
            end

            if terkonfirmasi then
                slotTerisiCount = slotTerisiCount + 1
                task.wait(jedaAntarSlot)
            else
                slotDitolakServer[targetSlot] = tick() + 60
            end
        end
    end)

    if not ok and err then
        warn("[AutoGudang Error]:", err)
    end

    sedangMengisiGudang = false
    return slotTerisiCount
end

-- ==========================================
-- UI TAB: GUDANG
-- ==========================================
local GudangTab = API.CreateTab("Gudang")

API.Section(GudangTab, "Informasi Rak Penyimpanan (" .. PlotToko.Name .. ")")
local StatusGudangCard = API.Paragraph(
    GudangTab,
    "Target: RakPenyimpananX (6 Kardus / Rak)",
    "Mengangkut semua jenis kardus dari lantai ke slot kosong Rak1 - Rak6 tanpa membongkar isi produk."
)

API.Section(GudangTab, "Kontrol Auto Simpan Gudang")
API.Slider(GudangTab, "Jeda Antar Slot Gudang (Detik)", 0.20, 1.50, 0.05, " dtk", 0.25, function(val)
    jedaAntarSlot = tonumber(val) or 0.25
end)

API.Toggle(GudangTab, "Auto Simpan Kardus ke Gudang (Otomatis)", false, function(val)
    autoGudangEnabled = val
    API.Notify(
        val and "Auto Gudang Aktif" or "Auto Gudang Mati",
        val and "Menyimpan semua kardus ke slot kosong RakPenyimpananX." or "Auto simpan gudang dihentikan.",
        3
    )
end)

API.Button(GudangTab, "Isi Semua RakPenyimpanan Sekarang (1x)", function()
    task.spawn(function()
        local daftar = cariSemuaSlotGudangKosong()
        if #daftar == 0 then
            API.Notify("Gudang Penuh", "Semua slot Rak1 - Rak6 di RakPenyimpanan sudah terisi.", 3)
            return
        end
        local hasil = jalankanSiklusIsiGudang(true)
        API.Notify("Selesai", "Berhasil menyimpan " .. tostring(hasil) .. " kardus ke RakPenyimpanan.", 3)
    end)
end)

API.Button(GudangTab, "Reset Cache Slot Gudang", function()
    slotDitolakServer = {}
    kardusDitolakSementara = {}
    API.Notify("Direset", "Cache slot RakPenyimpanan & kardus diperbarui.", 2)
end)

-- ==========================================
-- LOOP PEMANTAUAN OTOMATIS
-- ==========================================
task.spawn(function()
    while true do
        local slotKosong = cariSemuaSlotGudangKosong()
        local kardusLantai = ambilSemuaKardusDiLantai()
        local picked = cariKardusPickedDiKarakter()

        local teksStatus = "Status: Nonaktif (Semua Kategori Produk)"
        if autoGudangEnabled then
            teksStatus = (#slotKosong > 0 and "Status: Menyimpan kardus ke RakPenyimpanan..." or "Status: Siaga (Semua slot gudang penuh)")
        end

        API.SetElementText(
            StatusGudangCard,
            "Slot Gudang Kosong: " .. tostring(#slotKosong) .. "  |  Kardus Tersedia: " .. tostring(#kardusLantai),
            teksStatus
        )

        if autoGudangEnabled and #slotKosong > 0 and (#kardusLantai > 0 or picked ~= nil) then
            jalankanSiklusIsiGudang(false)
        end

        task.wait(0.8)
    end
end)
