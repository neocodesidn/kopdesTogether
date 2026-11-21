local API = ...

local BeliProductRemote = API.Remotes.Kardus:WaitForChild("BeliProduct")
local clickObject = API.Plot:WaitForChild("ClickObject")

local autoRestokEnabled = false
local namaItem = "Bebelove"
local jumlahBeli = 10
local sudahBeli = false
local waktuBeliTerakhir = 0

-- Cache area gudang (dihitung 1x di awal saja agar loop real-time tidak ngeframe)
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
    -- 1. Cek cepat parent (tanpa loop berat)
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

    -- 2. Cek atribut
    if kardus:GetAttribute("InGudang") == true
        or kardus:GetAttribute("Stored") == true
        or kardus:GetAttribute("IsStored") == true then
        return true
    end

    -- 3. Cek jarak koordinat sederhana ke cache rak gudang (super ringan)
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
-- UI TAB: [AUTO BUY] KARDUS
-- ==========================================
local ShopTab = API.CreateTab("Auto Beli Kardus")

local StatusBeliCard = API.Paragraph(
    ShopTab,
    "Kardus di Lantai: 0  |  Target: Bebelove (10x)",
    "Status: Nonaktif"
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

API.Section(ShopTab, "Pengaturan Produk")

API.Input(ShopTab, "Nama Produk", "Bebelove", function(text)
    local bersih = tostring(text or ""):match("^%s*(.-)%s*$")
    if bersih ~= "" then
        namaItem = bersih
        lastSisa = -1
        API.Notify("Produk Diatur", "Target belanja: " .. namaItem, 2)
    end
end)

API.Paragraph(
    ShopTab,
    "Cara Mengisi Nama Produk",
    "Ketik nama produk sesuai nama di dalam game (contoh: Bebelove, SusuSapi, Paprika), lalu tekan Enter untuk menyimpan."
)

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

API.Paragraph(
    ShopTab,
    "Cara Kerja Auto Beli",
    "Membeli maksimal 10 kardus secara otomatis begitu semua kardus di area toko habis (stok yang tersimpan di rak gudang tidak ikut dihitung)."
)

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
