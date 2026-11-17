local API = ...

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local KasirScanRemote = Remotes and Remotes:FindFirstChild("KasirScan")

local PlotToko = API.Plot or Workspace:WaitForChild("Plot1")
local clickObject = PlotToko:WaitForChild("ClickObject")

-- ==========================================
-- KONFIGURASI AUTO KASIR
-- ==========================================
local autoKasirEnabled = false
local autoAmbilUangEnabled = true
local jedaScan = 0.10
local sedangMemproses = false

local abaikanNama = {
    "rakbelanja", "rakkecil", "mejaskasir", "mejakasir", "edcmachine",
    "monitor", "tempatpembayaran", "kulkas", "freezer", "gatebutton",
    "computer", "kasir", "point1", "point2", "point3", "kamera"
}

local function apakahObjekFurnitur(nama)
    local lower = tostring(nama):lower()
    for _, kata in ipairs(abaikanNama) do
        if lower:find(kata, 1, true) then
            return true
        end
    end
    return false
end

-- ==========================================
-- DETEKSI AREA KASIR & BARANG BELANJAAN
-- ==========================================
local function dapatkanPosisiMejaKasir()
    local meja = clickObject:FindFirstChild("MejaKasir")
    if meja then
        local ok, cf = pcall(function() return meja:GetPivot() end)
        if ok and cf then return cf.Position, meja end
    end

    local folderKasir = PlotToko:FindFirstChild("Kasir")
    local p2 = folderKasir and folderKasir:FindFirstChild("Point2")
    if p2 and p2:IsA("BasePart") then
        return p2.Position, folderKasir
    end

    return nil, nil
end

local function cariBarangDiAreaKasir()
    local posKasir = dapatkanPosisiMejaKasir()
    if not posKasir then return {} end

    local daftarItem = {}
    local sudahMasuk = {}

    -- Pindai seluruh Plot1 dan Workspace dalam radius 12 stud dari meja kasir
    local sumberPencarian = { PlotToko, Workspace }
    for _, root in ipairs(sumberPencarian) do
        for _, desc in ipairs(root:GetDescendants()) do
            if desc:IsA("ClickDetector") or desc:IsA("ProximityPrompt") then
                local targetObj = desc.Parent
                if targetObj and not sudahMasuk[targetObj] and not apakahObjekFurnitur(targetObj.Name) then
                    local itemPos
                    if targetObj:IsA("BasePart") then
                        itemPos = targetObj.Position
                    elseif targetObj:IsA("Model") then
                        local ok, cf = pcall(function() return targetObj:GetPivot() end)
                        if ok and cf then itemPos = cf.Position end
                    end

                    -- Pastikan objek berada tepat di atas meja kasir (jarak <= 12 stud)
                    if itemPos and (itemPos - posKasir).Magnitude <= 12 then
                        -- Jangan masukkan tumpukan uang pembayaran sebagai barang scan
                        local isUang = targetObj.Name:lower():find("uang")
                            or targetObj.Name:lower():find("cash")
                            or targetObj.Name:lower():find("money")
                            or (desc:IsA("ProximityPrompt") and tostring(desc.ActionText):lower():find("ambil"))

                        if not isUang then
                            sudahMasuk[targetObj] = true
                            table.insert(daftarItem, {
                                obj = targetObj,
                                interaksi = desc
                            })
                        end
                    end
                end
            end
        end
    end

    table.sort(daftarItem, function(a, b)
        local numA = tonumber(a.obj.Name:match("%d+")) or 0
        local numB = tonumber(b.obj.Name:match("%d+")) or 0
        if numA ~= numB then return numA < numB end
        return a.obj.Name < b.obj.Name
    end)

    return daftarItem
end

local function cekDanAmbilUangPembayaran()
    if not autoAmbilUangEnabled then return end
    local posKasir = dapatkanPosisiMejaKasir()
    if not posKasir then return end

    for _, desc in ipairs(PlotToko:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled then
            local aksi = tostring(desc.ActionText):lower()
            local objek = tostring(desc.ObjectText):lower()
            if aksi:find("ambil") or objek:find("uang") or objek:find("rp") then
                if fireproximityprompt then
                    pcall(fireproximityprompt, desc)
                end
            end
        elseif desc:IsA("ClickDetector") and desc.Parent then
            local nama = desc.Parent.Name:lower()
            if nama:find("uang") or nama:find("cash") or nama:find("money") then
                if fireclickdetector then
                    pcall(fireclickdetector, desc)
                end
            end
        end
    end
end

local function prosesScanKasir()
    if sedangMemproses then return 0 end
    local daftarItem = cariBarangDiAreaKasir()
    if #daftarItem == 0 then return 0 end

    sedangMemproses = true
    local jumlahTerscan = 0

    pcall(function()
        for indeks, item in ipairs(daftarItem) do
            if not item.obj or not item.obj.Parent then continue end

            if item.interaksi:IsA("ClickDetector") and fireclickdetector then
                pcall(fireclickdetector, item.interaksi)
            elseif item.interaksi:IsA("ProximityPrompt") and fireproximityprompt then
                pcall(fireproximityprompt, item.interaksi)
            end

            if KasirScanRemote then
                KasirScanRemote:FireServer(indeks)
            end

            jumlahTerscan = jumlahTerscan + 1
            task.wait(jedaScan)
        end
    end)

    sedangMemproses = false
    return jumlahTerscan
end

-- ==========================================
-- UI TAB: KASIR
-- ==========================================
local KasirTab = API.CreateTab("Kasir")

API.Section(KasirTab, "Status Meja Kasir (" .. PlotToko.Name .. ")")
local StatusKasirCard = API.Paragraph(
    KasirTab,
    "Memindai Area Kasir...",
    "Mendeteksi barang pelanggan dalam radius MejaKasir & Point1-Point3."
)

API.Section(KasirTab, "Kontrol Auto Scan & Pembayaran")
API.Slider(KasirTab, "Jeda Antar Barang (Detik)", 0.03, 0.30, 0.01, " dtk", 0.10, function(val)
    jedaScan = tonumber(val) or 0.10
end)

API.Toggle(KasirTab, "Auto Scan Kasir (Otomatis)", false, function(val)
    autoKasirEnabled = val
    API.Notify(
        val and "Auto Kasir Aktif" or "Auto Kasir Mati",
        val and "Otomatis men-scan barang pelanggan di area kasir." or "Auto kasir dihentikan.",
        3
    )
end)

API.Toggle(KasirTab, "Auto Ambil Uang Pembayaran", true, function(val)
    autoAmbilUangEnabled = val
end)

API.Button(KasirTab, "Scan Barang Sekarang (1x)", function()
    task.spawn(function()
        local hasil = prosesScanKasir()
        if hasil > 0 then
            API.Notify("Scan Selesai", "Berhasil memproses " .. tostring(hasil) .. " barang di kasir.", 2)
        else
            API.Notify("Tidak Terdeteksi", "0 barang terdeteksi. Coba klik 'Cek Path Barang' saat ada barang di meja.", 3)
        end
    end)
end)

API.Button(KasirTab, "Cek Path Barang di Kasir (Console)", function()
    local posKasir = dapatkanPosisiMejaKasir()
    print("=== DEBUG BARANG DI AREA KASIR ===")
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and posKasir and (obj.Position - posKasir).Magnitude <= 8 then
            if not obj:IsDescendantOf(API.LocalPlayer.Character or Workspace) then
                print(" -", obj:GetFullName(), "[" .. obj.ClassName .. "]")
            end
        end
    end
    API.Notify("Debug Tercetak", "Buka /console untuk melihat jalur folder barang di meja kasir.", 3)
end)

-- ==========================================
-- LOOP PEMANTAUAN KASIR
-- ==========================================
task.spawn(function()
    while true do
        local items = cariBarangDiAreaKasir()

        API.SetElementText(
            StatusKasirCard,
            "Barang Terdeteksi: " .. tostring(#items) .. " item",
            autoKasirEnabled
                and (#items > 0 and "Status: Men-scan barang pelanggan..." or "Status: Siaga (Menunggu pelanggan)")
                or "Status: Nonaktif"
        )

        if autoKasirEnabled then
            if #items > 0 then
                prosesScanKasir()
            end
            cekDanAmbilUangPembayaran()
        end

        task.wait(0.30)
    end
end)
