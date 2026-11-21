local API = ...

local BeliProductRemote = API.Remotes.Kardus:WaitForChild("BeliProduct")
local clickObject = API.Plot:WaitForChild("ClickObject")

local autoRestokEnabled = false
local namaItem = "Bebelove"
local jumlahBeli = 10
local waktuBeliTerakhir = 0

-- Cache area rak gudang agar ringan (0% frame drop)
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
                table.insert(daftar, { cf = cf, size = size })
            end
        end
    end
    cacheAreaGudang = daftar
end

local function ambilPosisiObjek(obj)
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        local ok, cf = pcall(function() return obj:GetPivot() end)
        if ok and cf then return cf.Position end
        local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        if part then return part.Position end
    end
    return nil
end

local function apakahKardusDiRakGudang(kardus)
    local curr = kardus.Parent
    while curr and curr ~= workspace do
        local namaLower = curr.Name:lower()
        if namaLower:find("rakpenyimpanan") or namaLower:find("gudang") then
            return true
        end
        curr = curr.Parent
    end

    if kardus:GetAttribute("InGudang") == true
        or kardus:GetAttribute("Stored") == true
        or kardus:GetAttribute("IsStored") == true then
        return true
    end

    local posKardus = ambilPosisiObjek(kardus)
    if not posKardus then return false end

    for _, area in ipairs(cacheAreaGudang) do
        local rel = area.cf:PointToObjectSpace(posKardus)
        local tol = 1.5
        if math.abs(rel.X) <= (area.size.X / 2 + tol)
            and math.abs(rel.Y) <= (area.size.Y / 2 + tol)
            and math.abs(rel.Z) <= (area.size.Z / 2 + tol) then
            return true
        end
    end

    return false
end

local function hitungSisaKardus()
    local jumlah = 0
    for _, v in ipairs(clickObject:GetChildren()) do
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

local sisaTerakhirUI = -1
local statusTerakhirUI = nil

local function perbaruiUI(sisaOpsional)
    local sisa = sisaOpsional ~= nil and sisaOpsional or hitungSisaKardus()
    -- Hanya update UI jika angkanya benar-benar berubah (mencegah lag render UI)
    if sisa == sisaTerakhirUI and autoRestokEnabled == statusTerakhirUI then
        return
    end
    sisaTerakhirUI = sisa
    statusTerakhirUI = autoRestokEnabled

    API.SetElementText(
        StatusBeliCard,
        "Kardus di Lantai: " .. tostring(sisa) .. "  |  Target: " .. namaItem .. " (" .. tostring(jumlahBeli) .. "x)",
        "Status: " .. (autoRestokEnabled and "Aktif" or "Nonaktif")
    )
end

local function cekDanBeliOtomatis()
    local sisa = hitungSisaKardus()
    perbaruiUI(sisa)

    if not autoRestokEnabled then return end

    -- Jika sisa kardus di lantai 0 dan sudah lewat jeda aman 3.5 detik sejak pembelian terakhir
    if sisa == 0 and (tick() - waktuBeliTerakhir) >= 3.5 then
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

API.Section(ShopTab, "Pengaturan Produk")

API.Input(ShopTab, "Nama Produk", "Bebelove", function(text)
    local bersih = tostring(text or ""):match("^%s*(.-)%s*$")
    if bersih ~= "" then
        namaItem = bersih
        sisaTerakhirUI = -1
        perbaruiUI()
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
    sisaTerakhirUI = -1
    perbaruiUI()
end)

API.Section(ShopTab, "Auto Beli Kardus")

API.Toggle(ShopTab, "Aktifkan Auto Beli", false, function(val)
    autoRestokEnabled = val
    sisaTerakhirUI = -1
    if val then
        muatUlangCacheGudang()
        cekDanBeliOtomatis()
    else
        perbaruiUI()
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
-- 1. EVENT-DRIVEN (RESPONS INSTAN)
-- ==========================================
clickObject.ChildAdded:Connect(function(child)
    if child.Name == "Kardus" then
        task.wait(0.25)
        cekDanBeliOtomatis()
    elseif child.Name:lower():find("rakpenyimpanan") or child.Name:lower():find("gudang") then
        task.wait(0.25)
        muatUlangCacheGudang()
    end
end)

clickObject.ChildRemoved:Connect(function(child)
    if child.Name == "Kardus" then
        task.defer(cekDanBeliOtomatis)
    end
end)

-- ==========================================
-- 2. WATCHDOG RINGAN (ANTI-MACET JIKA PARENT TIDAK BERUBAH)
-- ==========================================
task.spawn(function()
    while true do
        task.wait(2.5)
        if autoRestokEnabled then
            cekDanBeliOtomatis()
        else
            perbaruiUI()
        end
    end
end)

muatUlangCacheGudang()
perbaruiUI()
