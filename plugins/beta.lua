local API = ...

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BeliProductRemote = API.Remotes.Kardus:WaitForChild("BeliProduct")
local clickObject = API.Plot:WaitForChild("ClickObject")

local autoRestokEnabled = false
local namaItem = "Bebelove"
local jumlahBeli = 10
local sudahBeli = false
local waktuBeliTerakhir = 0

-- ==========================================
-- AMBIL DATABASE PRODUK DARI REPLICATEDSTORAGE.PRODUCT
-- ==========================================
local ProductFolder = ReplicatedStorage:FindFirstChild("Product")
local KATEGORI_LIST = { "Makanan", "Minuman", "Daging", "Sayuran" }
local daftarSemuaProduk = {} -- { { nama = "Bebelove", kategori = "Makanan" }, ... }

local function normalisasiTeks(teks)
    return tostring(teks or ""):lower():gsub("%s+", ""):gsub("[^%w]", "")
end

local function muatDatabaseProduk()
    daftarSemuaProduk = {}
    local sudahAda = {}

    if not ProductFolder then return end

    for _, kat in ipairs(KATEGORI_LIST) do
        local folderKat = ProductFolder:FindFirstChild(kat)
        if folderKat then
            for _, obj in ipairs(folderKat:GetDescendants()) do
                if not obj:IsA("Folder") and not obj:IsA("Configuration") then
                    local parentName = obj.Parent and obj.Parent.Name:lower() or ""
                    local validItem = (obj.Parent == folderKat)
                        or parentName == "default"
                        or parentName:find("^lisensi")
                        or parentName:find("^license")

                    if validItem then
                        local key = normalisasiTeks(obj.Name)
                        if key ~= "" and not sudahAda[key] then
                            sudahAda[key] = true
                            table.insert(daftarSemuaProduk, {
                                nama = obj.Name,
                                kategori = kat
                            })
                        end
                    end
                end
            end
        end
    end

    table.sort(daftarSemuaProduk, function(a, b)
        return a.nama < b.nama
    end)
end

muatDatabaseProduk()

-- ==========================================
-- SEARCH ENGINE PRODUK (MIRIP & EXACT MATCH)
-- ==========================================
local hasilPencarianSaatIni = {}
local indeksKandidat = 1

local function hitungSkorMirip(queryNorm, targetNorm)
    if queryNorm == "" or targetNorm == "" then return 0 end
    if queryNorm == targetNorm then
        return 1000 -- Sama persis
    end
    if targetNorm:sub(1, #queryNorm) == queryNorm then
        return 800 - (#targetNorm - #queryNorm) -- Awalan sama persis
    end
    if targetNorm:find(queryNorm, 1, true) then
        return 600 - (#targetNorm - #queryNorm) -- Mengandung kata yang dicari
    end

    -- Fuzzy huruf berurutan (antisipasi typo ringan)
    local qIdx = 1
    local qLen = #queryNorm
    for i = 1, #targetNorm do
        if targetNorm:sub(i, i) == queryNorm:sub(qIdx, qIdx) then
            qIdx = qIdx + 1
            if qIdx > qLen then
                return math.floor(300 * (qLen / math.max(#targetNorm, 1)))
            end
        end
    end

    return 0
end

local function cariProduk(kataKunci)
    local queryNorm = normalisasiTeks(kataKunci)
    if queryNorm == "" then
        return {}
    end

    -- 1. Kalau sama persis (contoh: ketik "bebelove" -> langsung 1 hasil saja)
    for _, item in ipairs(daftarSemuaProduk) do
        if normalisasiTeks(item.nama) == queryNorm then
            return { item }
        end
    end

    -- 2. Cari semua yang namanya hampir sama
    local kandidat = {}
    for _, item in ipairs(daftarSemuaProduk) do
        local skor = hitungSkorMirip(queryNorm, normalisasiTeks(item.nama))
        if skor >= 120 then
            table.insert(kandidat, {
                nama = item.nama,
                kategori = item.kategori,
                skor = skor
            })
        end
    end

    table.sort(kandidat, function(a, b)
        if a.skor ~= b.skor then
            return a.skor > b.skor
        end
        return a.nama < b.nama
    end)

    return kandidat
end

-- ==========================================
-- CACHE AREA GUDANG (ANTI-LAG)
-- ==========================================
local cacheAreaGudang = {}

local function muatUlangCacheGudang()
    local daftar = {}
    for _, obj in ipairs(API.Plot:GetDescendants()) do
        local namaLower = obj.Name:lower()
        if (obj:IsA("Model") or obj:IsA("BasePart")) and (namaLower:find("rakpenyimpanan") or namaLower:find("gudang")) then
            local cf, size
            if obj:IsA("Model") then
                local ok, boxCF, boxSize = pcall(function() return obj:GetBoundingBox() end)
                if ok then cf, size = boxCF, boxSize end
            else
                cf, size = obj.CFrame, obj.Size
            end
            if cf and size then
                table.insert(daftar, {
                    pos = cf.Position,
                    rx = (size.X / 2) + 1.5,
                    ry = (size.Y / 2) + 1.5,
                    rz = (size.Z / 2) + 1.5
                })
            end
        end
    end
    cacheAreaGudang = daftar
end

local function ambilPosisiCepat(obj)
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        if part then return part.Position end
    end
    return nil
end

local function apakahKardusDiRakGudang(kardus)
    local p1 = kardus.Parent
    if p1 and p1 ~= clickObject then
        local n1 = p1.Name:lower()
        if n1:find("rak") or n1:find("gudang") then
            return true
        end
        local p2 = p1.Parent
        if p2 and (p2.Name:lower():find("rak") or p2.Name:lower():find("gudang")) then
            return true
        end
    end

    if kardus:GetAttribute("InGudang") == true
        or kardus:GetAttribute("Stored") == true
        or kardus:GetAttribute("IsStored") == true then
        return true
    end

    if #cacheAreaGudang > 0 then
        local pos = ambilPosisiCepat(kardus)
        if pos then
            for i = 1, #cacheAreaGudang do
                local area = cacheAreaGudang[i]
                if math.abs(pos.X - area.pos.X) <= area.rx
                    and math.abs(pos.Y - area.pos.Y) <= area.ry
                    and math.abs(pos.Z - area.pos.Z) <= area.rz then
                    return true
                end
            end
        end
    end

    return false
end

local function hitungSisaKardus()
    local jumlah = 0
    local anak = clickObject:GetChildren()
    for i = 1, #anak do
        local v = anak[i]
        if v.Name == "Kardus" and not apakahKardusDiRakGudang(v) then
            jumlah = jumlah + 1
        end
    end
    return jumlah
end

-- ==========================================
-- UI TAB: AUTO BELI KARDUS + SEARCH PRODUK
-- ==========================================
local ShopTab = API.CreateTab("Auto Beli Kardus")

local StatusBeliCard = API.Paragraph(
    ShopTab,
    "Kardus di Lantai: 0  |  Target: Bebelove (10x)",
    "Status: Nonaktif"
)

local HasilSearchCard = API.Paragraph(
    ShopTab,
    "Terpilih: Bebelove",
    "Ketik potongan nama produk di bawah untuk mencari otomatis."
)

local lastSisa = -1
local lastStatus = nil

local function perbaruiUI(sisa)
    if sisa == lastSisa and autoRestokEnabled == lastStatus then
        return
    end
    lastSisa = sisa
    lastStatus = autoRestokEnabled

    API.SetElementText(
        StatusBeliCard,
        "Kardus di Lantai: " .. tostring(sisa) .. "  |  Target: " .. namaItem .. " (" .. tostring(jumlahBeli) .. "x)",
        "Status: " .. (autoRestokEnabled and "Aktif" or "Nonaktif")
    )
end

local function perbaruiCardSearch(kataKunci)
    if #hasilPencarianSaatIni == 0 then
        API.SetElementText(
            HasilSearchCard,
            "Terpilih: " .. namaItem,
            "Tidak ada produk mirip \"" .. tostring(kataKunci) .. "\" di Product."
        )
        return
    end

    local terpilih = hasilPencarianSaatIni[indeksKandidat]
    namaItem = terpilih.nama
    lastSisa = -1

    if #hasilPencarianSaatIni == 1 then
        -- Sama persis / cuma 1 hasil cocok
        API.SetElementText(
            HasilSearchCard,
            "Terpilih (1 Cocok): " .. terpilih.nama .. " [" .. terpilih.kategori .. "]",
            "Nama produk terkunci otomatis (anti-typo)."
        )
    else
        -- Beberapa produk mirip muncul
        local daftarTeks = {}
        local batas = math.min(#hasilPencarianSaatIni, 6)
        for i = 1, batas do
            local item = hasilPencarianSaatIni[i]
            table.insert(daftarTeks, item.nama .. " (" .. item.kategori .. ")")
        end
        local sisaLain = #hasilPencarianSaatIni - batas
        local keterangan = "Mirip (" .. tostring(#hasilPencarianSaatIni) .. "): " .. table.concat(daftarTeks, ", ")
        if sisaLain > 0 then
            keterangan = keterangan .. " (+" .. tostring(sisaLain) .. " lainnya)"
        end

        API.SetElementText(
            HasilSearchCard,
            string.format("Terpilih (%d/%d): %s [%s]", indeksKandidat, #hasilPencarianSaatIni, terpilih.nama, terpilih.kategori),
            keterangan
        )
    end
end

API.Section(ShopTab, "Pencarian & Pengaturan Produk")

API.Input(ShopTab, "Cari Nama Produk", "Bebelove", function(text)
    local bersih = tostring(text or ""):match("^%s*(.-)%s*$")
    if bersih == "" then return end

    hasilPencarianSaatIni = cariProduk(bersih)
    indeksKandidat = 1
    perbaruiCardSearch(bersih)

    if #hasilPencarianSaatIni > 0 then
        API.Notify("Produk Ditemukan", "Target belanja: " .. namaItem, 2)
    else
        API.Notify("Tidak Ditemukan", "Produk \"" .. bersih .. "\" tidak ada di database.", 2)
    end
end)

API.Button(ShopTab, "Pilih Hasil Mirip Berikutnya", function()
    if #hasilPencarianSaatIni <= 1 then
        API.Notify("Info Pencarian", "Hanya ada 1 produk cocok: " .. namaItem, 2)
        return
    end

    indeksKandidat = (indeksKandidat % #hasilPencarianSaatIni) + 1
    perbaruiCardSearch("")
    API.Notify("Produk Diganti", "Target belanja: " .. namaItem, 2)
end)

API.Slider(ShopTab, "Jumlah Sekali Beli (Max 10)", 1, 10, 1, " Kardus", 10, function(val)
    jumlahBeli = math.clamp(math.floor(tonumber(val) or 10), 1, 10)
    lastSisa = -1
end)

API.Section(ShopTab, "Auto Beli Kardus")

API.Toggle(ShopTab, "Aktifkan Auto Beli", false, function(val)
    autoRestokEnabled = val
    lastSisa = -1
    if val then
        sudahBeli = false
        muatUlangCacheGudang()
    end
    API.Notify(
        val and "Auto Beli Aktif" or "Auto Beli Mati",
        val and ("Siap membeli maksimal " .. jumlahBeli .. " kardus " .. namaItem .. " saat stok di lantai habis.") or "Auto beli kardus dihentikan.",
        2
    )
end)

-- ==========================================
-- LOOP REAL-TIME SUPER RINGAN (0.35 DETIK, 0% LAG)
-- ==========================================
muatUlangCacheGudang()

task.spawn(function()
    while true do
        local sisa = hitungSisaKardus()
        perbaruiUI(sisa)

        if autoRestokEnabled then
            if sisa > 0 then
                sudahBeli = false
            elseif sisa == 0 and not sudahBeli and (tick() - waktuBeliTerakhir) >= 3 then
                sudahBeli = true
                waktuBeliTerakhir = tick()

                local jumlahKirim = math.clamp(jumlahBeli, 1, 10)
                BeliProductRemote:FireServer({
                    {
                        jumlahKardus = jumlahKirim,
                        itemName = namaItem
                    }
                })
                API.Notify("Belanja Berhasil", "Membeli " .. jumlahKirim .. " kardus " .. namaItem .. ".", 3)
            end
        end

        task.wait(0.35)
    end
end)
