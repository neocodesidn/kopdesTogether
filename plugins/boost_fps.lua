local API = ...

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local fpsBoostEnabled = false
local koneksiWorkspace = nil
local koneksiLighting = nil
local koneksiPlayerAdded = nil
local koneksiCharAdded = {}

local StatusFpsCard

local function perbaruiStatusUI()
    if not StatusFpsCard then return end
    API.SetElementText(
        StatusFpsCard,
        "Ultra FPS Boost: " .. (fpsBoostEnabled and "AKTIF (Maximal Reduce)" or "Nonaktif"),
        fpsBoostEnabled
            and "Map polos tanpa bayangan/tekstur & seluruh karakter menjadi kotak polos."
            or "Klik toggle di bawah untuk memangkas grafik map dan karakter secara maksimal."
    )
end

-- ==========================================
-- 1. REDUCE KARAKTER JADI KOTAK POLOS (HAPUS AKSESORIS, BAJU, MESH)
-- ==========================================
local function jadikanKarakterKotak(char)
    if not char then return end

    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("Accessory")
            or desc:IsA("Hat")
            or desc:IsA("Shirt")
            or desc:IsA("Pants")
            or desc:IsA("ShirtGraphic")
            or desc:IsA("CharacterMesh")
            or desc:IsA("BodyColors")
            or desc:IsA("SurfaceAppearance")
            or desc:IsA("WrapLayer")
            or desc:IsA("WrapTarget") then
            pcall(function() desc:Destroy() end)
        elseif desc:IsA("SpecialMesh") then
            -- Ubah kepala/bagian tubuh bulat menjadi kotak polos
            pcall(function()
                desc.MeshType = Enum.MeshType.Brick
                desc.TextureId = ""
            end)
        elseif desc:IsA("MeshPart") then
            pcall(function()
                desc.TextureID = ""
                desc.Material = Enum.Material.SmoothPlastic
                desc.CastShadow = false
            end)
        elseif desc:IsA("Decal") or desc:IsA("Texture") then
            pcall(function() desc:Destroy() end)
        elseif desc:IsA("BasePart") then
            pcall(function()
                desc.Material = Enum.Material.SmoothPlastic
                desc.CastShadow = false
                desc.Reflectance = 0
                desc.Color = Color3.fromRGB(190, 190, 190)
            end)
        end
    end
end

local function bersihkanSemuaKarakter()
    -- Bersihkan seluruh player di server
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            jadikanKarakterKotak(plr.Character)
        end
        if not koneksiCharAdded[plr] then
            koneksiCharAdded[plr] = plr.CharacterAdded:Connect(function(newChar)
                if fpsBoostEnabled then
                    task.wait(0.15)
                    jadikanKarakterKotak(newChar)
                end
            end)
        end
    end

    -- Bersihkan juga seluruh model ber-Humanoid di Workspace (NPC kasir, pembeli, pencuri, dll)
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("Humanoid") and desc.Parent and desc.Parent:IsA("Model") then
            jadikanKarakterKotak(desc.Parent)
        end
    end
end

-- ==========================================
-- 2. MAXIMAL REDUCE MAP & LIGHTING
-- ==========================================
local function reduksiObjekMap(obj)
    if not obj or not obj.Parent then return end

    if obj:IsA("Accessory")
        or obj:IsA("Hat")
        or obj:IsA("Shirt")
        or obj:IsA("Pants")
        or obj:IsA("ShirtGraphic")
        or obj:IsA("CharacterMesh")
        or obj:IsA("SurfaceAppearance") then
        pcall(function() obj:Destroy() end)
    elseif obj:IsA("MeshPart") then
        obj.TextureID = ""
        obj.Material = Enum.Material.SmoothPlastic
        obj.CastShadow = false
        obj.Reflectance = 0
    elseif obj:IsA("BasePart") then
        obj.Material = Enum.Material.SmoothPlastic
        obj.CastShadow = false
        obj.Reflectance = 0
    elseif obj:IsA("SpecialMesh") then
        obj.TextureId = ""
        if obj.Parent and obj.Parent.Parent and obj.Parent.Parent:FindFirstChildOfClass("Humanoid") then
            obj.MeshType = Enum.MeshType.Brick
        end
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        -- Pertahankan tulisan/harga di papan GUI supaya masih terbaca
        if not obj:FindFirstAncestorWhichIsA("SurfaceGui") and not obj:FindFirstAncestorWhichIsA("BillboardGui") then
            pcall(function() obj:Destroy() end)
        end
    elseif obj:IsA("ParticleEmitter")
        or obj:IsA("Trail")
        or obj:IsA("Smoke")
        or obj:IsA("Fire")
        or obj:IsA("Sparkles")
        or obj:IsA("Beam") then
        obj.Enabled = false
    elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
        obj.Enabled = false
    end
end

local function reduksiLightingMaksimal()
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.FogStart = 9e9
    Lighting.Brightness = 1
    Lighting.EnvironmentDiffuseScale = 0
    Lighting.EnvironmentSpecularScale = 0

    for _, efek in ipairs(Lighting:GetChildren()) do
        if efek:IsA("PostEffect")
            or efek:IsA("BlurEffect")
            or efek:IsA("BloomEffect")
            or efek:IsA("SunRaysEffect")
            or efek:IsA("DepthOfFieldEffect")
            or efek:IsA("ColorCorrectionEffect")
            or efek:IsA("Atmosphere")
            or efek:IsA("Sky") then
            efek.Enabled = false
        end
    end

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        terrain.WaterWaveSize = 0
        terrain.WaterWaveSpeed = 0
        terrain.WaterReflectance = 0
        terrain.WaterTransparency = 0
        pcall(function() terrain.Decoration = false end)
    end
end

local function aktifkanMaxFpsBoost()
    reduksiLightingMaksimal()
    bersihkanSemuaKarakter()

    -- Sapu seluruh objek map secara bertahap per batch agar tidak freeze saat pertama diklik
    task.spawn(function()
        local semuaObjek = Workspace:GetDescendants()
        for i = 1, #semuaObjek do
            if not fpsBoostEnabled then break end
            reduksiObjekMap(semuaObjek[i])
            if i % 400 == 0 then
                task.wait()
            end
        end
    end)

    if koneksiWorkspace then koneksiWorkspace:Disconnect() end
    koneksiWorkspace = Workspace.DescendantAdded:Connect(function(desc)
        if not fpsBoostEnabled then return end
        if desc:IsA("Humanoid") and desc.Parent then
            task.defer(function()
                jadikanKarakterKotak(desc.Parent)
            end)
        else
            reduksiObjekMap(desc)
        end
    end)

    if koneksiLighting then koneksiLighting:Disconnect() end
    koneksiLighting = Lighting.ChildAdded:Connect(function(efek)
        if fpsBoostEnabled and (efek:IsA("PostEffect") or efek:IsA("Atmosphere") or efek:IsA("Sky")) then
            efek.Enabled = false
        end
    end)

    if koneksiPlayerAdded then koneksiPlayerAdded:Disconnect() end
    koneksiPlayerAdded = Players.PlayerAdded:Connect(function(plr)
        koneksiCharAdded[plr] = plr.CharacterAdded:Connect(function(newChar)
            if fpsBoostEnabled then
                task.wait(0.15)
                jadikanKarakterKotak(newChar)
            end
        end)
    end)
end

local function matikanListenerFpsBoost()
    if koneksiWorkspace then
        koneksiWorkspace:Disconnect()
        koneksiWorkspace = nil
    end
    if koneksiLighting then
        koneksiLighting:Disconnect()
        koneksiLighting = nil
    end
    if koneksiPlayerAdded then
        koneksiPlayerAdded:Disconnect()
        koneksiPlayerAdded = nil
    end
end

-- ==========================================
-- UI TAB: BOOST FPS (KHUSUS MAXIMAL FPS BOOST)
-- ==========================================
local FpsTab = API.CreateTab("Boost FPS")

StatusFpsCard = API.Paragraph(
    FpsTab,
    "Ultra FPS Boost: Nonaktif",
    "Klik toggle di bawah untuk memangkas grafik map dan karakter secara maksimal."
)

API.Section(FpsTab, "Kontrol FPS Boost")

API.Toggle(FpsTab, "Aktifkan Ultra FPS Boost", false, function(val)
    fpsBoostEnabled = val
    perbaruiStatusUI()
    if val then
        aktifkanMaxFpsBoost()
        API.Notify("Ultra FPS Boost Aktif", "Map & seluruh karakter dipangkas menjadi kotak polos.", 3)
    else
        matikanListenerFpsBoost()
        API.Notify("FPS Boost Nonaktif", "Pemangkasan objek baru dihentikan.", 2)
    end
end)

API.Button(FpsTab, "Paksa Bersihkan Map & Karakter Sekarang", function()
    reduksiLightingMaksimal()
    bersihkanSemuaKarakter()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        reduksiObjekMap(obj)
    end
    API.Notify("Selesai", "Seluruh map, aksesoris, dan karakter berhasil dipangkas ulang.", 2)
end)

API.Paragraph(
    FpsTab,
    "Cara Kerja Ultra FPS Boost",
    "Menghapus seluruh aksesoris, baju, celana, tekstur wajah, mesh karakter (menjadi kotak abu-abu polos), mematikan bayangan, lampu, efek cahaya, partikel, dan menyederhanakan material map menjadi SmoothPlastic."
)

perbaruiStatusUI()
