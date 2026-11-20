local API = ...

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local hideNpcEnabled = false
local fpsBoostEnabled = false
local hideOtherPlotsEnabled = false

local koneksiDescendantNPC = nil
local koneksiDescendantWorkspace = nil
local dataAsliObjek = setmetatable({}, { __mode = "k" })

-- ==========================================
-- DETEKSI PLOT MILIK SENDIRI (AMAN DARI HIDE)
-- ==========================================
local function dapatkanPlotMilikSendiri()
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
    return (API and API.Plot) or Workspace:FindFirstChild("Plot1")
end

local PlotSendiri = dapatkanPlotMilikSendiri()

-- ==========================================
-- UTILITAS SEMBUNYIKAN & PULIHKAN OBJEK VISUAL
-- ==========================================
local function sembunyikanVisual(obj)
    if obj:IsA("BasePart") then
        if not dataAsliObjek[obj] then
            dataAsliObjek[obj] = {
                Transparency = obj.Transparency,
                CastShadow = obj.CastShadow
            }
        end
        obj.Transparency = 1
        obj.CastShadow = false
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        if not dataAsliObjek[obj] then
            dataAsliObjek[obj] = {
                Transparency = obj.Transparency
            }
        end
        obj.Transparency = 1
    elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") or obj:IsA("Highlight") or obj:IsA("ParticleEmitter") then
        if not dataAsliObjek[obj] then
            dataAsliObjek[obj] = {
                Enabled = obj.Enabled
            }
        end
        obj.Enabled = false
    end
end

local function pulihkanVisual(obj)
    local asli = dataAsliObjek[obj]
    if not asli then return end

    if obj:IsA("BasePart") then
        obj.Transparency = asli.Transparency or 0
        obj.CastShadow = (asli.CastShadow ~= nil) and asli.CastShadow or true
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        obj.Transparency = asli.Transparency or 0
    elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") or obj:IsA("Highlight") or obj:IsA("ParticleEmitter") then
        obj.Enabled = (asli.Enabled ~= nil) and asli.Enabled or true
    end
end

-- ==========================================
-- 1. HIDE NPC PEMBELI (Workspace.NPC_Pembeli)
-- ==========================================
local function prosesSeluruhNPC(aktifkan)
    local folderNPC = Workspace:FindFirstChild("NPC_Pembeli")
    if not folderNPC then return 0 end

    local jumlah = #folderNPC:GetChildren()
    for _, desc in ipairs(folderNPC:GetDescendants()) do
        if aktifkan then
            sembunyikanVisual(desc)
        else
            pulihkanVisual(desc)
        end
    end

    if koneksiDescendantNPC then
        koneksiDescendantNPC:Disconnect()
        koneksiDescendantNPC = nil
    end

    if aktifkan then
        koneksiDescendantNPC = folderNPC.DescendantAdded:Connect(function(desc)
            if hideNpcEnabled then
                sembunyikanVisual(desc)
            end
        end)
    end

    return jumlah
end

-- ==========================================
-- 2. ULTRA FPS BOOST (POTATO GRAPHICS)
-- ==========================================
local function optimasiSatuPart(obj)
    if obj:IsA("BasePart") then
        obj.CastShadow = false
        obj.Material = Enum.Material.SmoothPlastic
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
        obj.Enabled = false
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        if not obj:FindFirstAncestorWhichIsA("SurfaceGui") then
            obj.Transparency = 1
        end
    end
end

local function aktifkanPotatoFpsBoost()
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 1

    for _, efek in ipairs(Lighting:GetChildren()) do
        if efek:IsA("PostEffect") or efek:IsA("BlurEffect") or efek:IsA("BloomEffect") or efek:IsA("SunRaysEffect") or efek:IsA("DepthOfFieldEffect") then
            efek.Enabled = false
        end
    end

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        terrain.WaterWaveSize = 0
        terrain.WaterWaveSpeed = 0
        terrain.WaterReflectance = 0
        terrain.WaterTransparency = 0
    end

    for _, desc in ipairs(Workspace:GetDescendants()) do
        optimasiSatuPart(desc)
    end

    if koneksiDescendantWorkspace then
        koneksiDescendantWorkspace:Disconnect()
        koneksiDescendantWorkspace = nil
    end

    koneksiDescendantWorkspace = Workspace.DescendantAdded:Connect(function(desc)
        if fpsBoostEnabled then
            optimasiSatuPart(desc)
        end
    end)
end

-- ==========================================
-- 3. HIDE PLOT PEMAIN LAIN
-- ==========================================
local function prosesPlotPemainLain(aktifkan)
    local jumlahPlot = 0
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name:match("^Plot%d+$") and obj ~= PlotSendiri then
            jumlahPlot = jumlahPlot + 1
            for _, desc in ipairs(obj:GetDescendants()) do
                if aktifkan then
                    sembunyikanVisual(desc)
                else
                    pulihkanVisual(desc)
                end
            end
        end
    end
    return jumlahPlot
end

-- ==========================================
-- UI TAB: OPTIMASI / BOOST FPS
-- ==========================================
local FpsTab = API.CreateTab("Boost FPS")

-- FITUR 1: HIDE NPC PEMBELI
API.Section(FpsTab, "Sembunyikan NPC Pembeli")
local StatusNpcCard = API.Paragraph(
    FpsTab,
    "Status NPC Pembeli: Nonaktif",
    "NPC Pembeli tampil normal di layar."
)

API.Toggle(FpsTab, "Sembunyikan NPC Pembeli", false, function(val)
    hideNpcEnabled = val
    local total = prosesSeluruhNPC(val)
    API.SetElementText(
        StatusNpcCard,
        val and ("Status NPC Pembeli: Aktif (" .. tostring(total) .. " NPC)") or "Status NPC Pembeli: Nonaktif",
        val and "Seluruh model & efek NPC baru otomatis disembunyikan." or "Tampilan NPC Pembeli dikembalikan seperti semula."
    )
end)

API.Paragraph(
    FpsTab,
    "Penjelasan Sembunyikan NPC Pembeli",
    "Menyembunyikan seluruh tubuh, aksesoris, bayangan, dan tanda di atas kepala NPC Pembeli di pihak pemain supaya transaksi kasir tidak terganggu dan game berjalan lebih ringan."
)

-- FITUR 2: ULTRA FPS BOOST
API.Section(FpsTab, "Ultra FPS Boost")
API.Toggle(FpsTab, "Aktifkan Ultra FPS Boost", false, function(val)
    fpsBoostEnabled = val
    if val then
        aktifkanPotatoFpsBoost()
        API.Notify("FPS Boost Aktif", "Bayangan, partikel, dan tekstur dekorasi dinonaktifkan.", 3)
    else
        if koneksiDescendantWorkspace then
            koneksiDescendantWorkspace:Disconnect()
            koneksiDescendantWorkspace = nil
        end
        API.Notify("FPS Boost Mati", "Optimasi objek baru dihentikan.", 2)
    end
end)

API.Paragraph(
    FpsTab,
    "Penjelasan Ultra FPS Boost",
    "Mematikan bayangan, efek cahaya, partikel koin/pengalaman, dan menyederhanakan permukaan objek supaya perangkat lebih ringan."
)

-- FITUR 3: HIDE PLOT PEMAIN LAIN
API.Section(FpsTab, "Sembunyikan Toko Pemain Lain")
API.Toggle(FpsTab, "Sembunyikan Toko Pemain Lain", false, function(val)
    hideOtherPlotsEnabled = val
    local totalPlot = prosesPlotPemainLain(val)
    API.Notify(
        val and "Toko Lain Disembunyikan" or "Toko Lain Ditampilkan",
        tostring(totalPlot) .. " plot pemain lain " .. (val and "disembunyikan." or "dikembalikan."),
        2
    )
end)

API.Paragraph(
    FpsTab,
    "Penjelasan Sembunyikan Toko Lain",
    "Menyembunyikan seluruh rak, kardus, dan dekorasi milik pemain lain supaya hanya toko kamu yang ditampilkan."
)
