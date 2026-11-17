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
-- KONFIGURASI KAPASITAS & STATE KARDUS DI TANGAN
-- ==========================================
local KAPASITAS_MAKS_PAPAN = 12 -- Maksimal 12 item di dalam ClientItemInstances per Rak1-Rak8
local autoPlaceRakEnabled = false
local jedaAntarRak = 0.25
local sedangMengisiRak = false
local rakDitolakServer = {}

-- State pelacakan sisa isi kardus yang sedang dipegang agar tidak hilang/tertimpa
local stokKardusDiTangan = 0
local namaItemDiTangan = nil

local kataKunciFurnitur = { "rakkecil", "rakbelanja", "kasir", "meja", "kulkas", "freezer", "lampu", "pintu", "dinding", "etalase" }

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
-- DETEKSI KARDUS VALID DI LANTAI TOKO
-- ==========================================
local function bacaDetailKardus(kardus)
    local namaDitemukan = nil
    local jumlahIsi = KAPASITAS_MAKS_PAPAN

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
            if desc.Value > 0 and desc.Value <= KAPASITAS_MAKS_PAPAN then
                jumlahIsi = desc.Value
            end
        elseif desc:IsA("TextLabel") then
            local angkaSisa = desc.Text:match("^[xX]?(%d+)")
            if angkaSisa then
                local n = tonumber(angkaSisa)
                if n and n > 0 and n <= KAPASITAS_MAKS_PAPAN then
                    jumlahIsi = n
                end
            end
        end
    end

    if not namaDitemukan or namaDitemukan == "" or apakahFurnitur(namaDitemukan) then
        return nil
    end

    return {
        obj = kardus,
        nama = namaDitemukan,
        jumlah = math.clamp(jumlahIsi, 1, KAPASITAS_MAKS_PAPAN)
    }
end

local function ambilSemuaKardusTersedia()
    local daftar = {}
    for _, v in ipairs(clickObject:GetChildren()) do
        if v.Name == "Kardus" then
            local detail = bacaDetailKardus(v)
            if detail then
                table.insert(daftar, detail)
            end
        end
    end
    return daftar
end

-- ==========================================
-- PEMINDAIAN Rak1 - Rak8 & ISI ClientItemInstances
-- ==========================================
local function dapatkanFolderItemPapan(rakPart)
    return rakPart:FindFirstChild("ClientItemInstances")
        or rakPart:FindFirstChild("InstacesItem")
        or rakPart:FindFirstChild("InstanceItem")
end

local function bacaStatusIsiPapan(rakPart)
    local folderItem = dapatkanFolderItemPapan(rakPart)
    if not folderItem then
        return 0, nil
    end
    local children = folderItem:GetChildren()
    local namaProdukAda = (#children > 0) and children[1].Name or nil
    return #children, namaProdukAda
end

local function cariSemuaPapanBelumPenuh()
    local daftarTarget = {}
    local daftarModelRak = {}

    for _, modelRak in ipairs(clickObject:GetChildren()) do
        local namaLower = modelRak.Name:lower()
        if namaLower:find("rakbelanja") and modelRak:FindFirstChild("InputRak") then
            table.insert(daftarModelRak, modelRak)
        end
    end

    -- Urutkan model rak dari nomor terkecil (RakBelanja1, RakBelanja2, dst.)
    table.sort(daftarModelRak, function(a, b)
        local numA = tonumber(a.Name:match("%d+")) or 9999
        local numB = tonumber(b.Name:match("%d+")) or 9999
        if numA ~= numB then return numA < numB end
        return a.Name < b.Name
    end)

    -- Wajib periksa berurutan dari Rak1 sampai Rak8 per RakBelanja
    for _, modelRak in ipairs(daftarModelRak) do
        local inputRak = modelRak:FindFirstChild("InputRak")
        if inputRak then
            for i = 1, 8 do
                local slotPart = inputRak:FindFirstChild("Rak" .. tostring(i))
                if slotPart and slotPart:IsA("BasePart") then
                    local skip = rakDitolakServer[slotPart] and tick() < rakDitolakServer[slotPart]
                    if not skip then
                        local terisi, namaProdukAda = bacaStatusIsiPapan(slotPart)
                        if terisi < KAPASITAS_MAKS_PAPAN then
                            table.insert(daftarTarget, {
                                part = slotPart,
                                terisi = terisi,
                                sisaSlot = KAPASITAS_MAKS_PAPAN - terisi,
                                namaProdukAda = namaProdukAda
                            })
                        end
                    end
                end
            end
        end
    end

    return daftarTarget
end

-- ==========================================
-- KALKULASI TITIK GRID CFRAME (ISI SLOT KOSONG SAJA)
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

local function ambilPosisiItemEksisting(rakPart)
    local posisiList = {}
    local folderItem = dapatkanFolderItemPapan(rakPart)
    if not folderItem then return posisiList end

    for _, item in ipairs(folderItem:GetChildren()) do
        if item:IsA("BasePart") then
            table.insert(posisiList, item.Position)
        elseif item:IsA("Model") then
            local ok, cf = pcall(function() return item:GetPivot() end)
            if ok and cf then
                table.insert(posisiList, cf.Position)
            end
        end
    end
    return posisiList
end

local function buatBatchPenempatanRak(rakPart, itemName, jumlahKirim)
    local cols = 4
    local rows = 3
    local targetJumlah = math.clamp(jumlahKirim, 1, KAPASITAS_MAKS_PAPAN)

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

    local offsetY = (rakH > 0.6)
        and (-(rakH / 2) + (itemHeight / 2))
        or ((rakH / 2) + (itemHeight / 2))

    local startX = -((cols - 1) * slotW) / 2
    local startZ = -((rows - 1) * slotD) / 2

    local semuaTitik = {}
    for i = 0, KAPASITAS_MAKS_PAPAN - 1 do
        local col = i % cols
        local row = math.floor(i / cols)
        local offX = startX + (col * slotW)
        local offZ = startZ + (row * slotD)
        table.insert(semuaTitik, rakPart.CFrame * CFrame.new(offX, offsetY, offZ))
    end

    -- Lewati titik koordinat yang sudah ditempati item di papan
    local posisiTerisi = ambilPosisiItemEksisting(rakPart)
    local titikKosong = {}
    local titikTerpakai = {}

    for _, cf in ipairs(semuaTitik) do
        local sudahAda = false
        for _, posAda in ipairs(posisiTerisi) do
            if (cf.Position - posAda).Magnitude < 0.35 then
                sudahAda = true
                break
            end
        end
        if sudahAda then
            table.insert(titikTerpakai, cf)
        else
            table.insert(titikKosong, cf)
        end
    end

    local daftarPenempatan = {}
    for _, cf in ipairs(titikKosong) do
        if #daftarPenempatan >= targetJumlah then break end
        table.insert(daftarPenempatan, { cf = cf, scale = scale })
    end
    for _, cf in ipairs(titikTerpakai) do
        if #daftarPenempatan >= targetJumlah then break end
        table.insert(daftarPenempatan, { cf = cf, scale = scale })
    end

    return daftarPenempatan
end

-- ==========================================
-- PENGAMBILAN & PELACAKAN SISA KARDUS DI TANGAN
-- ==========================================
local function sinkronkanKardusDiTangan()
    local char = API.LocalPlayer.Character
    local upperTorso = char and char:FindFirstChild("UpperTorso")
    local picked = upperTorso and upperTorso:FindFirstChild("KardusPicked")

    if not picked then
        stokKardusDiTangan = 0
        namaItemDiTangan = nil
        return nil, nil, 0
    end

    local namaAttr = nil
    for _, attrName in ipairs({ "ItemName", "Product", "Nama", "Item", "Produk", "Barang" }) do
        local val = picked:GetAttribute(attrName)
        if typeof(val) == "string" and val ~= "" then
            namaAttr = val
            break
        end
    end
    if not namaAttr then
        for _, desc in ipairs(picked:GetDescendants()) do
            if desc:IsA("StringValue") and desc.Value ~= "" then
                namaAttr = desc.Value
                break
            end
        end
    end

    local stokAttr = nil
    for _, attrQty in ipairs({ "Stock", "Jumlah", "Count", "Isi", "Amount", "Qty" }) do
        local q = picked:GetAttribute(attrQty)
        if typeof(q) == "number" and q > 0 then
            stokAttr = q
            break
        end
    end

    if namaAttr then namaItemDiTangan = namaAttr end
    if stokAttr then
        stokKardusDiTangan = math.clamp(stokAttr, 1, KAPASITAS_MAKS_PAPAN)
    elseif stokKardusDiTangan <= 0 then
        stokKardusDiTangan = KAPASITAS_MAKS_PAPAN
    end

    return picked, namaItemDiTangan, stokKardusDiTangan
end

local function picuInteraksiKardus(kardusObj)
    local cd = kardusObj:FindFirstChildWhichIsA("ClickDetector", true)
    if cd and fireclickdetector then
        pcall(fireclickdetector, cd)
    end
    local pp = kardusObj:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pp and fireproximityprompt then
        pcall(fireproximityprompt, pp)
    end
end

local function ambilSatuKardusAman(detailKardus)
    local char = API.LocalPlayer.Character
    local upperTorso = char and char:FindFirstChild("UpperTorso")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not upperTorso then return nil, nil, 0 end

    -- Jangan ambil kardus baru jika masih ada sisa di KardusPicked
    local existing, existingNama, existingStok = sinkronkanKardusDiTangan()
    if existing and existingStok > 0 then
        return existing, (existingNama or detailKardus.nama), existingStok
    end

    local kardusObj = detailKardus.obj
    if not kardusObj or not kardusObj.Parent then return nil, nil, 0 end

    picuInteraksiKardus(kardusObj)
    local picked = upperTorso:WaitForChild("KardusPicked", 0.30)

    if not picked and hrp then
        local kardusPos
        if kardusObj:IsA("BasePart") then
            kardusPos = kardusObj.Position
        elseif kardusObj:IsA("Model") then
            local ok, cf = pcall(function() return kardusObj:GetPivot() end)
            if ok and cf then kardusPos = cf.Position end
        end

        if kardusPos then
            local posisiAwal = hrp.CFrame
            hrp.CFrame = CFrame.new(kardusPos + Vector3.new(0, 2.5, 0))
            task.wait(0.08)
            picuInteraksiKardus(kardusObj)
            picked = upperTorso:WaitForChild("KardusPicked", 0.90)
            hrp.CFrame = posisiAwal
        end
    end

    if picked and PickupKardusRemote then
        PickupKardusRemote:FireServer(picked, detailKardus.nama)
        namaItemDiTangan = detailKardus.nama
        stokKardusDiTangan = detailKardus.jumlah or KAPASITAS_MAKS_PAPAN
        task.wait(0.10)
        return picked, namaItemDiTangan, stokKardusDiTangan
    end

    return nil, nil, 0
end

-- ==========================================
-- PEMILIHAN TARGET RAK BERURUTAN (Rak1 - Rak8) & OPER SISA
-- ==========================================
local function cariPapanCocokUntukItem(daftarTarget, namaItem)
    -- Pindai urut dari Rak1 ke Rak8: pilih papan pertama yang masih butuh item
    -- (baik terisi sebagian dengan produk yang sama maupun papan kosong 0/12)
    for _, t in ipairs(daftarTarget) do
        if not t.namaProdukAda or t.namaProdukAda:lower() == namaItem:lower() then
            return t
        end
    end
    return nil
end

local function pilihKardusSesuaiUrutanRak(daftarTarget, daftarKardus)
    -- Prioritaskan melengkapi papan pertama yang sudah berisi sebagian (misal Rak2 isi 8/12)
    for _, t in ipairs(daftarTarget) do
        if t.namaProdukAda then
            for _, k in ipairs(daftarKardus) do
                if k.nama:lower() == t.namaProdukAda:lower() then
                    return k
                end
            end
        end
    end

    -- Jika papan terdepan kosong (0/12), ambil kardus pertama yang punya target papan cocok
    for _, k in ipairs(daftarKardus) do
        if cariPapanCocokUntukItem(daftarTarget, k.nama) then
            return k
        end
    end

    return nil
end

-- ==========================================
-- EKSEKUSI UTAMA (TOP-UP + OPER SISA KE RAK BERIKUTNYA)
-- ==========================================
local function jalankanSiklusIsiRak(abaikanToggle)
    if sedangMengisiRak then return 0 end
    if not PickupKardusRemote or not PlaceOilRemote or not PlaceOilDoneRemote then
        return 0
    end

    sedangMengisiRak = true
    local totalItemMasuk = 0

    pcall(function()
        while abaikanToggle or autoPlaceRakEnabled do
            local daftarTarget = cariSemuaPapanBelumPenuh()
            if #daftarTarget == 0 then break end

            local picked, itemAktif, sisaDiTangan = sinkronkanKardusDiTangan()

            -- Hanya ambil kardus baru dari lantai jika kardus sebelumnya sudah habis (0)
            if not picked or sisaDiTangan <= 0 then
                local daftarKardus = ambilSemuaKardusTersedia()
                if #daftarKardus == 0 then break end

                local kardusPilihan = pilihKardusSesuaiUrutanRak(daftarTarget, daftarKardus)
                if not kardusPilihan then break end

                picked, itemAktif, sisaDiTangan = ambilSatuKardusAman(kardusPilihan)
            end

            if not picked or not itemAktif or sisaDiTangan <= 0 or apakahFurnitur(itemAktif) then
                break
            end

            -- Cari papan Rak1-Rak8 pertama yang cocok untuk menampung sisaDiTangan
            local targetInfo = cariPapanCocokUntukItem(daftarTarget, itemAktif)
            if not targetInfo then
                -- Tidak ada papan yang cocok untuk item di tangan; berhenti aman tanpa membuang kardus
                break
            end

            local targetRak = targetInfo.part
            local isiSebelum = bacaStatusIsiPapan(targetRak)
            local jumlahKirim = math.min(targetInfo.sisaSlot, sisaDiTangan)

            -- Tahap 2: PlaceOil
            PlaceOilRemote:FireServer(targetRak)
            task.wait(0.08)

            -- Tahap 3: PlaceOilDone (kirim sejumlah kekurangan slot atau sisa kardus di tangan)
            local batchData = buatBatchPenempatanRak(targetRak, itemAktif, jumlahKirim)
            PlaceOilDoneRemote:FireServer(targetRak, batchData, itemAktif)

            -- Tunggu konfirmasi pertambahan item di ClientItemInstances
            local isiSesudah = isiSebelum
            local terkonfirmasi = false
            for _ = 1, 12 do
                task.wait(0.10)
                isiSesudah = bacaStatusIsiPapan(targetRak)
                local masihAdaDiTangan = sinkronkanKardusDiTangan()
                if isiSesudah > isiSebelum or not masihAdaDiTangan then
                    terkonfirmasi = true
                    break
                end
            end

            if terkonfirmasi then
                local masukAktual = (isiSesudah > isiSebelum) and (isiSesudah - isiSebelum) or jumlahKirim
                totalItemMasuk = totalItemMasuk + masukAktual

                -- Kurangi sisa stok di tangan; jika masih bersisa (misal 12 - 4 = 8),
                -- iterasi berikutnya langsung mengoper sisa 8 tersebut ke Rak selanjutnya!
                stokKardusDiTangan = math.max(0, sisaDiTangan - masukAktual)
                if stokKardusDiTangan == 0 then
                    namaItemDiTangan = nil
                end

                task.wait(jedaAntarRak)
            else
                -- Papan ditolak server: lewati papan ini 60 detik, oper kardus di tangan ke papan berikutnya
                rakDitolakServer[targetRak] = tick() + 60
            end
        end
    end)

    sedangMengisiRak = false
    return totalItemMasuk
end

-- ==========================================
-- UI TAB: INPUT
-- ==========================================
local InputTab = API.CreateTab("Input")

API.Section(InputTab, "Informasi Sistem Auto Input (" .. PlotToko.Name .. ")")
local StatusInputCard = API.Paragraph(
    InputTab,
    "Mode Oper Sisa Stok (Rak1 - Rak8 | Maks 12/Papan)",
    "Mengisi papan kurang dari 12 item hingga penuh lalu mengoper sisa isi kardus ke rak berikutnya tanpa membuang kardus."
)

API.Section(InputTab, "Kontrol Auto Input Rak")
API.Slider(InputTab, "Jeda Antar Pengisian (Detik)", 0.20, 1.50, 0.05, " dtk", 0.25, function(val)
    jedaAntarRak = tonumber(val) or 0.25
end)

API.Toggle(InputTab, "Auto Isi Rak (Oper Sisa Otomatis)", false, function(val)
    autoPlaceRakEnabled = val
    API.Notify(
        val and "Auto Input Aktif" or "Auto Input Mati",
        val and "Melengkapi Rak1 - Rak8 hingga 12/12 dan mengoper sisa stok kardus secara otomatis." or "Auto input dihentikan.",
        3
    )
end)

API.Button(InputTab, "Isi & Lengkapi Semua Rak Sekarang (1x)", function()
    task.spawn(function()
        local daftar = cariSemuaPapanBelumPenuh()
        if #daftar == 0 then
            API.Notify("Semua Rak Penuh", "Seluruh papan Rak1 - Rak8 sudah terisi 12/12.", 3)
            return
        end
        local hasil = jalankanSiklusIsiRak(true)
        API.Notify("Selesai", "Berhasil memasukkan " .. tostring(hasil) .. " item ke rak belanja.", 3)
    end)
end)

API.Button(InputTab, "Reset Cache Rak Penuh (Pindai Ulang)", function()
    rakDitolakServer = {}
    API.Notify("Cache Direset", "Papan Rak1 - Rak8 dipindai ulang dari nomor 1.", 2)
end)

-- ==========================================
-- LOOP PEMANTAUAN OTOMATIS
-- ==========================================
task.spawn(function()
    while true do
        local papanBelumPenuh = cariSemuaPapanBelumPenuh()
        local kardusAda = ambilSemuaKardusTersedia()
        local picked, itemTangan, sisaTangan = sinkronkanKardusDiTangan()

        local infoTangan = (picked and sisaTangan > 0)
            and ("  |  Sisa Tangan: " .. tostring(sisaTangan) .. " (" .. tostring(itemTangan or "?") .. ")")
            or ""

        API.SetElementText(
            StatusInputCard,
            "Papan <12: " .. tostring(#papanBelumPenuh) .. "  |  Kardus Lantai: " .. tostring(#kardusAda) .. infoTangan,
            autoPlaceRakEnabled
                and (#papanBelumPenuh > 0 and "Status: Mengisi & mengoper sisa ke Rak1-Rak8..." or "Status: Siaga (Semua papan 12/12)")
                or "Status: Nonaktif (Menunggu diaktifkan)"
        )

        if autoPlaceRakEnabled and #papanBelumPenuh > 0 and (#kardusAda > 0 or (picked and sisaTangan > 0)) then
            jalankanSiklusIsiRak(false)
        end

        task.wait(0.8)
    end
end)
