local API = ...

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PickupKardusRemote = API.Remotes.Kardus:FindFirstChild("PickupKardus")
local PlaceOilDoneRemote = API.Remotes.Kardus:FindFirstChild("PlaceOilDone")
local clickObject = API.Plot:WaitForChild("ClickObject")

-- ==========================================
-- KONFIGURASI AUTO INPUT RAK (UNIVERSAL)
-- ==========================================
local autoPlaceRakEnabled = false
local jedaAntarRak = 0.25
local sedangMengisiRak = false

-- ==========================================
-- DETEKSI SEMUA KARDUS DI AREA TOKO
-- ==========================================
local function bacaDetailKardus(kardus)
    local namaDitemukan = nil
    local jumlahIsi = 6

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
                end
            end
        end

        if desc:IsA("IntValue") or desc:IsA("NumberValue") then
            if desc.Value > 0 and desc.Value <= 20 then
                jumlahIsi = desc.Value
            end
        elseif desc:IsA("TextLabel") then
            local angkaSisa = desc.Text:match("^[xX]?(%d+)")
            if angkaSisa then
                local n = tonumber(angkaSisa)
                if n and n > 0 and n <= 20 then
                    jumlahIsi = n
                end
            end
        end
    end

    return {
        obj = kardus,
        nama = namaDitemukan,
        jumlah = math.clamp(jumlahIsi, 1, 8)
    }
end

local function ambilSemuaKardusTersedia()
    local daftar = {}
    for _, v in ipairs(clickObject:GetChildren()) do
        if v.Name == "Kardus" then
            local detail = bacaDetailKardus(v)
            if detail.nama and detail.nama ~= "" then
                table.insert(daftar, detail)
            end
        end
    end
    return daftar
end

-- ==========================================
-- DETEKSI SLOT RAK KOSONG & LABEL INFO
-- ==========================================
local function bacaKunciProdukRak(rakPart)
    local infoObj = rakPart:FindFirstChild("Info")
    if not infoObj then return nil end

    for _, attrName in ipairs({ "ItemName", "Product", "Nama", "Item", "Produk", "Barang" }) do
        local val = infoObj:GetAttribute(attrName)
        if typeof(val) == "string" and val ~= "" and val:lower() ~= "none" and val:lower() ~= "kosong" then
            return val
        end
    end

    for _, desc in ipairs(infoObj:GetDescendants()) do
        if desc:IsA("StringValue") and desc.Value ~= "" and desc.Value:lower() ~= "none" then
            return desc.Value
        elseif desc:IsA("TextLabel") and desc.Text ~= "" then
            local txt = desc.Text:gsub("^%s+", ""):gsub("%s+$", "")
            if txt ~= "" and not txt:match("^Rp") and not txt:match("^[%d%.,]+$") and txt:lower() ~= "kosong" then
                return txt
            end
        end
    end

    return nil
end

local function apakahSlotRakKosong(rakPart)
    if not rakPart or not rakPart:IsA("BasePart") then return false end
    local clientItems = rakPart:FindFirstChild("ClientItemInstances")
    if clientItems then
        return #clientItems:GetChildren() == 0
    end
    return true
end

local function cariSemuaRakKosong()
    local rakKosong = {}
    for _, modelRak in ipairs(clickObject:GetChildren()) do
        local inputRak = modelRak:FindFirstChild("InputRak")
        if inputRak then
            local slots = inputRak:GetChildren()
            table.sort(slots, function(a, b)
                local numA = tonumber(a.Name:match("%d+")) or 0
                local numB = tonumber(b.Name:match("%d+")) or 0
                if numA ~= numB then return numA < numB end
                return a.Name < b.Name
            end)

            for _, slotPart in ipairs(slots) do
                if slotPart:IsA("BasePart") and apakahSlotRakKosong(slotPart) then
                    table.insert(rakKosong, {
                        part = slotPart,
                        lockedItem = bacaKunciProdukRak(slotPart)
                    })
                end
            end
        end
    end
    return rakKosong
end

-- ==========================================
-- KALKULASI GRID CFRAME & SCALE DINAMIS
-- ==========================================
local modelSizeCache = {}
local function cariUkuranModelProduk(itemName)
    local key = itemName:lower()
    if modelSizeCache[key] then
        return modelSizeCache[key]
    end

    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc.Name:lower() == key then
            if desc:IsA("Model") then
                local sz = desc:GetExtentsSize()
                if sz.Magnitude > 0.05 then
                    modelSizeCache[key] = sz
                    return sz
                end
            elseif desc:IsA("BasePart") and desc.Size.Magnitude > 0.05 then
                modelSizeCache[key] = desc.Size
                return desc.Size
            end
        end
    end
    return nil
end

local function buatBatchPenempatanRak(rakPart, itemName, jumlahItem)
    jumlahItem = math.clamp(jumlahItem or 6, 1, 8)

    local cols = 4
    local rows = 2

    local rakW = rakPart.Size.X
    local rakH = rakPart.Size.Y
    local rakD = rakPart.Size.Z

    local slotW = (rakW * 0.90) / cols
    local slotD = (rakD * 0.85) / rows

    local modelSize = cariUkuranModelProduk(itemName)
    local scale = 0.48711754
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
    local startZ = ((rows - 1) * slotD) / 2

    local daftarPenempatan = {}
    for i = 0, jumlahItem - 1 do
        local col = i % cols
        local row = math.floor(i / cols)

        local offX = startX + (col * slotW)
        local offZ = startZ - (row * slotD)
        local worldCF = rakPart.CFrame * CFrame.new(offX, offsetY, offZ)

        table.insert(daftarPenempatan, {
            cf = worldCF,
            scale = scale
        })
    end

    return daftarPenempatan
end

-- ==========================================
-- EKSEKUSI PICKUP KARDUS -> PLACE KE RAK
-- ==========================================
local function bacaProdukDiTangan(upperTorso)
    local picked = upperTorso and upperTorso:FindFirstChild("KardusPicked")
    if not picked then return nil end

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

local function ambilKardusKeTangan(detailKardus)
    local char = API.LocalPlayer.Character
    local upperTorso = char and char:FindFirstChild("UpperTorso")
    if not upperTorso then return nil end

    local existing, namaDiTangan = bacaProdukDiTangan(upperTorso)
    if existing then
        return existing, (namaDiTangan or detailKardus.nama)
    end

    local kardusObj = detailKardus.obj
    if not kardusObj or not kardusObj.Parent then return nil end

    local cd = kardusObj:FindFirstChildWhichIsA("ClickDetector", true)
    if cd and fireclickdetector then
        pcall(fireclickdetector, cd)
    end

    local pp = kardusObj:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pp and fireproximityprompt then
        pcall(fireproximityprompt, pp)
    end

    local picked = upperTorso:WaitForChild("KardusPicked", 1.2)
    if picked and PickupKardusRemote then
        pcall(function()
            PickupKardusRemote:FireServer(picked, detailKardus.nama)
        end)
    end

    return upperTorso:FindFirstChild("KardusPicked"), detailKardus.nama
end

local function pilihPasanganRakDanKardus(daftarRak, daftarKardus, itemDiTangan)
    if itemDiTangan then
        for _, rak in ipairs(daftarRak) do
            if not rak.lockedItem or rak.lockedItem:lower() == itemDiTangan:lower() then
                return rak, { nama = itemDiTangan, jumlah = 6 }
            end
        end
    end

    for _, rak in ipairs(daftarRak) do
        if rak.lockedItem then
            for _, k in ipairs(daftarKardus) do
                if k.nama:lower() == rak.lockedItem:lower() then
                    return rak, k
                end
            end
        end
    end

    for _, rak in ipairs(daftarRak) do
        if not rak.lockedItem and #daftarKardus > 0 then
            return rak, daftarKardus[1]
        end
    end

    if #daftarRak > 0 and #daftarKardus > 0 then
        return daftarRak[1], daftarKardus[1]
    end

    return nil, nil
end

local function jalankanSiklusIsiRak(abaikanToggle)
    if sedangMengisiRak or not PlaceOilDoneRemote then return 0 end
    sedangMengisiRak = true
    local terisiCount = 0

    pcall(function()
        while abaikanToggle or autoPlaceRakEnabled do
            local daftarRakKosong = cariSemuaRakKosong()
            if #daftarRakKosong == 0 then break end

            local char = API.LocalPlayer.Character
            local upperTorso = char and char:FindFirstChild("UpperTorso")
            local sedangPegang, namaDiTangan = bacaProdukDiTangan(upperTorso)

            local daftarKardus = ambilSemuaKardusTersedia()
            if not sedangPegang and #daftarKardus == 0 then break end

            local targetRak, targetKardus = pilihPasanganRakDanKardus(
                daftarRakKosong,
                daftarKardus,
                sedangPegang and namaDiTangan or nil
            )
            if not targetRak or not targetKardus then break end

            local itemAktif = targetKardus.nama
            if not sedangPegang then
                sedangPegang, itemAktif = ambilKardusKeTangan(targetKardus)
                task.wait(0.15)
            end

            if targetRak.part and targetRak.part.Parent and itemAktif then
                local batchData = buatBatchPenempatanRak(targetRak.part, itemAktif, targetKardus.jumlah or 6)
                PlaceOilDoneRemote:FireServer(targetRak.part, batchData, itemAktif)
                terisiCount = terisiCount + 1
                task.wait(jedaAntarRak)
            else
                break
            end
        end
    end)

    sedangMengisiRak = false
    return terisiCount
end

-- ==========================================
-- UI TAB: INPUT
-- ==========================================
local InputTab = API.CreateTab("Input")

API.Section(InputTab, "Status Rak & Kardus Area Toko")
local StatusInputCard = API.Paragraph(
    InputTab,
    "Memindai Rak...",
    "Mengecek slot rak kosong dan ketersediaan kardus..."
)

API.Section(InputTab, "Kontrol Auto Place (Semua Jenis Kardus)")
API.Slider(InputTab, "Jeda Antar Slot Rak (Detik)", 0.15, 1.50, 0.05, " dtk", 0.25, function(val)
    jedaAntarRak = tonumber(val) or 0.25
end)

API.Toggle(InputTab, "Auto Isi Rak Kosong (Otomatis)", false, function(val)
    autoPlaceRakEnabled = val
    API.Notify(
        val and "Auto Input Aktif" or "Auto Input Mati",
        val and "Otomatis menaruh semua jenis kardus ke slot rak yang kosong." or "Auto input dihentikan.",
        3
    )
end)

API.Button(InputTab, "Isi Semua Rak Kosong Sekarang (1x)", function()
    task.spawn(function()
        local rakKosong = cariSemuaRakKosong()
        if #rakKosong == 0 then
            API.Notify("Semua Rak Penuh", "Tidak ada slot rak kosong di Plot1.", 3)
            return
        end
        local hasil = jalankanSiklusIsiRak(true)
        API.Notify("Selesai", "Berhasil mengisi " .. tostring(hasil) .. " slot rak kosong.", 3)
    end)
end)

-- ==========================================
-- LOOP PEMANTAUAN RAK KOSONG
-- ==========================================
task.spawn(function()
    while true do
        local rakKosong = cariSemuaRakKosong()
        local kardusAda = ambilSemuaKardusTersedia()

        API.SetElementText(
            StatusInputCard,
            "Slot Rak Kosong: " .. tostring(#rakKosong) .. "  |  Kardus Tersedia: " .. tostring(#kardusAda),
            autoPlaceRakEnabled
                and (#rakKosong > 0 and "Status: Mengisi rak kosong..." or "Status: Stanby (Semua rak terisi)")
                or "Status: Nonaktif"
        )

        if autoPlaceRakEnabled and #rakKosong > 0 and #kardusAda > 0 then
            jalankanSiklusIsiRak(false)
        end

        task.wait(0.8)
    end
end)
