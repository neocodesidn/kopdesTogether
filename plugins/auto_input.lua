local API = ...

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KardusRemotes = API.Remotes.Kardus or ReplicatedStorage:WaitForChild("KardusRemotes", 10)
local PickupKardusRemote = KardusRemotes and KardusRemotes:WaitForChild("PickupKardus", 5)
local PlaceOilRemote = KardusRemotes and KardusRemotes:WaitForChild("PlaceOil", 5)
local PlaceOilDoneRemote = KardusRemotes and KardusRemotes:WaitForChild("PlaceOilDone", 5)

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
    return API.Plot or Workspace:WaitForChild("Plot1")
end

local PlotToko = dapatkanPlotToko()
local clickObject = PlotToko:WaitForChild("ClickObject")

-- ==========================================
-- KONFIGURASI AUTO INPUT RAK (UNIVERSAL)
-- ==========================================
local autoPlaceRakEnabled = false
local jedaAntarRak = 0.30
local sedangMengisiRak = false

-- Daftar kata kunci furnitur agar tidak ikut dimasukkan ke rak display
local kataKunciFurnitur = { "rak", "kasir", "meja", "kulkas", "freezer", "lampu", "pintu", "dinding" }

local function apakahFurnitur(nama)
    local lower = tostring(nama):lower()
    for _, kata in ipairs(kataKunciFurnitur) do
        if lower:find(kata, 1, true) then
            return true
        end
    end
    return false
end

-- ==========================================
-- DETEKSI SEMUA KARDUS PRODUK DI AREA TOKO
-- ==========================================
local function bacaDetailKardus(kardus)
    local namaDitemukan = nil
    local jumlahIsi = 12

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
            if desc.Value > 0 and desc.Value <= 24 then
                jumlahIsi = desc.Value
            end
        elseif desc:IsA("TextLabel") then
            local angkaSisa = desc.Text:match("^[xX]?(%d+)")
            if angkaSisa then
                local n = tonumber(angkaSisa)
                if n and n > 0 and n <= 24 then
                    jumlahIsi = n
                end
            end
        end
    end

    return {
        obj = kardus,
        nama = namaDitemukan,
        jumlah = math.clamp(jumlahIsi, 1, 12)
    }
end

local function ambilSemuaKardusTersedia()
    local daftar = {}
    for _, v in ipairs(clickObject:GetChildren()) do
        if v.Name == "Kardus" then
            local detail = bacaDetailKardus(v)
            if detail.nama and detail.nama ~= "" and not apakahFurnitur(detail.nama) then
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
-- KALKULASI GRID CFRAME & SCALE (4x3 / 4x2)
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
    local rakW = rakPart.Size.X
    local rakH = rakPart.Size.Y
    local rakD = rakPart.Size.Z

    -- RakBelanja punya kedalaman lebih besar (4 kolom x 3 baris = 12 item)
    -- RakKecil punya kedalaman lebih sempit (4 kolom x 2 baris = 6-8 item)
    local cols = 4
    local rows = (rakD >= 1.5) and 3 or 2
    local kapasitasMaks = cols * rows
    local totalPlace = math.clamp(jumlahItem or kapasitasMaks, 1, kapasitasMaks)

    local slotW = (rakW * 0.90) / cols
    local slotD = (rakD * 0.85) / rows

    local modelSize = cariUkuranModelProduk(itemName)
    local scale = (rakD >= 1.5) and 0.65325327 or 0.48711754
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
        local worldCF = rakPart.CFrame * CFrame.new(offX, offsetY, offZ)

        table.insert(daftarPenempatan, {
            cf = worldCF,
            scale = scale
        })
    end

    return daftarPenempatan
end

-- ==========================================
-- EKSEKUSI 3 TAHAP: PICKUP -> PLACEOIL -> PLACEOILDONE
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

local function pastikanKardusPickedLokal(kardusObj, itemName)
    local char = API.LocalPlayer.Character
    local upperTorso = char and char:FindFirstChild("UpperTorso")
    if not upperTorso then return nil end

    local existing = upperTorso:FindFirstChild("KardusPicked")
    if existing then
        return existing
    end

    -- Jika objek kardus masih ada di ClickObject, gunakan langsung atau pindahkan ke UpperTorso
    if kardusObj and kardusObj.Parent then
        kardusObj.Name = "KardusPicked"
        kardusObj:SetAttribute("ItemName", itemName)
        kardusObj.Parent = upperTorso
        return kardusObj
    end

    -- Fallback: buat instance KardusPicked lokal jika kardus sudah di-unparent
    local dummy = Instance.new("Model")
    dummy.Name = "KardusPicked"
    dummy:SetAttribute("ItemName", itemName)
    dummy.Parent = upperTorso
    return dummy
end

local function pilihPasanganRakDanKardus(daftarRak, daftarKardus, itemDiTangan)
    if itemDiTangan then
        for _, rak in ipairs(daftarRak) do
            if not rak.lockedItem or rak.lockedItem:lower() == itemDiTangan:lower() then
                return rak, { nama = itemDiTangan, jumlah = 12 }
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
    if sedangMengisiRak then return 0 end

    if not PickupKardusRemote or not PlaceOilRemote or not PlaceOilDoneRemote then
        API.Notify("Remote Tidak Lengkap", "Pastikan PickupKardus, PlaceOil, dan PlaceOilDone tersedia.", 4)
        return 0
    end

    sedangMengisiRak = true
    local terisiCount = 0

    local ok, err = xpcall(function()
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

            -- TAHAP 1: PickupKardus
            local objekPicked = sedangPegang or pastikanKardusPickedLokal(targetKardus.obj, itemAktif)
            if objekPicked then
                PickupKardusRemote:FireServer(objekPicked, itemAktif)
                task.wait(0.10)
            end

            -- TAHAP 2: PlaceOil (Inisialisasi slot rak di server)
            if targetRak.part and targetRak.part.Parent then
                PlaceOilRemote:FireServer(targetRak.part)
                task.wait(0.08)

                -- TAHAP 3: PlaceOilDone (Kirim susunan CFrame & scale)
                local batchData = buatBatchPenempatanRak(targetRak.part, itemAktif, targetKardus.jumlah or 12)
                PlaceOilDoneRemote:FireServer(targetRak.part, batchData, itemAktif)

                -- Bersihkan KardusPicked lokal agar siap mengambil kardus berikutnya
                if objekPicked and objekPicked.Parent == upperTorso then
                    objekPicked:Destroy()
                end

                terisiCount = terisiCount + 1
                task.wait(jedaAntarRak)
            else
                break
            end
        end
    end, debug.traceback)

    if not ok then
        API.Notify("Error Auto Input", tostring(err):sub(1, 140), 5)
    end

    sedangMengisiRak = false
    return terisiCount
end

-- ==========================================
-- UI TAB: INPUT
-- ==========================================
local InputTab = API.CreateTab("Input")

API.Section(InputTab, "Status Rak & Kardus (" .. PlotToko.Name .. ")")
local StatusInputCard = API.Paragraph(
    InputTab,
    "Memindai Rak...",
    "Mengecek slot rak kosong dan ketersediaan kardus..."
)

API.Section(InputTab, "Kontrol Auto Place (Semua Jenis Kardus)")
API.Slider(InputTab, "Jeda Antar Slot Rak (Detik)", 0.15, 1.50, 0.05, " dtk", 0.30, function(val)
    jedaAntarRak = tonumber(val) or 0.30
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
            API.Notify("Semua Rak Penuh", "Tidak ada slot rak kosong di " .. PlotToko.Name .. ".", 3)
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
