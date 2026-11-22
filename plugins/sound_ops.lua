local API = ...

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SoundSystemRequest = Remotes:WaitForChild("SoundSystemRequest")
local SoundSystemConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundSystemConfig"))

local DaftarLagu = SoundSystemConfig.Songs or {}
local isBusy = false
local selectedSongIndex = 1

local StatusSoundCard

-- ==========================================
-- HELPER CARI & TRIGGER SPEAKER DI PLOT (UNIVERSAL)
-- ==========================================
local function cariSpeakerPlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then
        return Workspace:FindFirstChild("SoundSystem", true)
    end

    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:GetAttribute("Owner") or plot:GetAttribute("OwnerId") or plot:GetAttribute("UserId")
        local ownerVal = plot:FindFirstChild("Owner") or plot:FindFirstChild("OwnerId")
        local ownerMatch = (owner == LocalPlayer.Name or owner == LocalPlayer.UserId)
            or (ownerVal and (ownerVal.Value == LocalPlayer.Name or ownerVal.Value == LocalPlayer.UserId or ownerVal.Value == LocalPlayer))

        if ownerMatch then
            local spk = plot:FindFirstChild("SoundSystem", true)
            if spk then return spk end
        end
    end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local nearestSpk = nil
    local shortestDist = math.huge

    for _, desc in ipairs(plots:GetDescendants()) do
        if desc.Name == "SoundSystem" then
            local part = desc:IsA("BasePart") and desc or desc:FindFirstChildWhichIsA("BasePart", true)
            if part and hrp then
                local dist = (part.Position - hrp.Position).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    nearestSpk = desc
                end
            elseif not nearestSpk then
                nearestSpk = desc
            end
        end
    end

    return nearestSpk
end

local function triggerSpeakerFisik(sembunyikanUIBawaan)
    local speaker = cariSpeakerPlot()
    if not speaker then
        return false, "Speaker SoundSystem tidak ditemukan di plot!"
    end

    local prompt = speaker:FindFirstChildWhichIsA("ProximityPrompt", true)
    local clickDet = speaker:FindFirstChildWhichIsA("ClickDetector", true)
    local targetPart = speaker:IsA("BasePart") and speaker or speaker:FindFirstChildWhichIsA("BasePart", true)

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local posisiAwal = hrp and hrp.CFrame

    -- Dekatkan karakter ke speaker sementara agar lolos validasi jarak server
    local butuhGeser = false
    if hrp and targetPart then
        local maxDist = (prompt and prompt.MaxActivationDistance) or (clickDet and clickDet.MaxActivationDistance) or 12
        if (hrp.Position - targetPart.Position).Magnitude > (maxDist - 2) then
            butuhGeser = true
            hrp.CFrame = targetPart.CFrame * CFrame.new(0, 2, 2.5)
            task.wait(0.15)
        end
    end

    local triggered = false

    -- Metode 1: ProximityPrompt bawaan Roblox (tanpa perlu exploit function)
    if prompt then
        pcall(function()
            prompt:InputHoldBegin()
            task.wait((prompt.HoldDuration or 0) + 0.08)
            prompt:InputHoldEnd()
        end)
        triggered = true
    end

    -- Metode 2: ClickDetector via getconnections / simulasi tap di posisi speaker
    if not triggered and clickDet then
        if getconnections then
            for _, conn in ipairs(getconnections(clickDet.MouseClick)) do
                pcall(function() conn:Fire(LocalPlayer) end)
                triggered = true
            end
        end

        if not triggered and targetPart and Workspace.CurrentCamera then
            local screenPos, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 1)
                    task.wait(0.05)
                    VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 1)
                end)
                triggered = true
            end
        end
    end

    -- Metode 3: Jika speaker memakai SurfaceGui / BillboardGui tombol
    if not triggered then
        local guiBtn = speaker:FindFirstChildWhichIsA("GuiButton", true)
        if guiBtn and getconnections then
            for _, conn in ipairs(getconnections(guiBtn.Activated)) do
                pcall(function() conn:Fire() end)
                triggered = true
            end
            for _, conn in ipairs(getconnections(guiBtn.MouseButton1Click)) do
                pcall(function() conn:Fire() end)
                triggered = true
            end
        end
    end

    task.wait(0.25)

    if butuhGeser and hrp and posisiAwal then
        hrp.CFrame = posisiAwal
    end

    if sembunyikanUIBawaan then
        task.defer(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            local sc = pg and pg:FindFirstChild("SoundChoice")
            local mf = sc and sc:FindFirstChild("MainFrame")
            if mf then
                mf.Visible = false
            end
        end)
    end

    return triggered, triggered and "OK" or "Komponen interaksi speaker tidak ditemukan (bukan Prompt/ClickDetector)."
end

-- ==========================================
-- HELPER REMOTE & STATUS
-- ==========================================
local function safeInvoke(action, arg)
    local done = false
    local result = nil

    local thread = task.spawn(function()
        local ok, res = pcall(function()
            return SoundSystemRequest:InvokeServer(action, arg)
        end)
        if ok then
            result = res
        end
        done = true
    end)

    local timeout = os.clock() + (SoundSystemConfig.CheckTimeout or 10) + 3
    while not done and os.clock() < timeout do
        task.wait(0.05)
    end

    if not done then
        pcall(task.cancel, thread)
        return nil
    end

    return result
end

local function cariJudulDariId(songId)
    if not songId then return "-" end
    for _, song in ipairs(DaftarLagu) do
        if song.ID == songId then
            return song.Title
        end
    end
    return "ID (" .. tostring(songId) .. ")"
end

local function perbaruiStatusUI()
    if not StatusSoundCard then return end

    local isPlaying = Workspace:GetAttribute("SoundSystemPlaying") == true
    local currentId = Workspace:GetAttribute("SoundSystemSongId")
    local currentVol = math.floor(((Workspace:GetAttribute("SoundSystemVolume") or 1) * 100) + 0.5)
    local laguTerpilih = DaftarLagu[selectedSongIndex]
    local namaPilihan = laguTerpilih and laguTerpilih.Title or "Tidak ada"

    API.SetElementText(
        StatusSoundCard,
        "Sound System: " .. (isPlaying and ("MEMUTAR - " .. cariJudulDariId(currentId)) or "Berhenti"),
        "Volume: " .. tostring(currentVol) .. "% | Pilihan (#" .. tostring(selectedSongIndex) .. "): " .. namaPilihan
    )
end

local function pastikanSesiTerbuka()
    local res = safeInvoke("Open", nil)
    if res and res.ok then
        return true, res
    end

    local okTrigger, triggerMsg = triggerSpeakerFisik(true)
    if okTrigger then
        task.wait(0.15)
        local retryRes = safeInvoke("Open", nil)
        if retryRes and retryRes.ok then
            return true, retryRes
        end
    end

    local alasan = (type(res) == "table" and (res.message or res.msg or res.reason or res.error))
        or triggerMsg
        or "Gagal mengaktifkan sesi speaker."
    return false, alasan
end

-- ==========================================
-- AKSI UTAMA SOUND SYSTEM
-- ==========================================
local function putarLaguPreset(index)
    local song = DaftarLagu[index]
    if not song then
        API.Notify("Gagal", "Lagu tidak ditemukan di daftar.", 2)
        return
    end

    if isBusy then
        API.Notify("Tunggu", "Sedang memproses permintaan audio...", 2)
        return
    end

    isBusy = true
    local openOk, openErr = pastikanSesiTerbuka()
    if not openOk then
        isBusy = false
        API.Notify("Sesi Ditolak", tostring(openErr), 4)
        return
    end

    local res = safeInvoke("PlayListed", song.ID)
    isBusy = false

    if res and res.ok then
        API.Notify("Memutar Lagu", song.Title, 3)
    else
        local msg = (type(res) == "table" and (res.message or res.msg or res.reason or res.error))
            or "Lagu belum tersedia di server."
        API.Notify("Gagal Memutar", tostring(msg), 3)
    end
    perbaruiStatusUI()
end

local function matikanLagu()
    if isBusy then return end
    isBusy = true
    pastikanSesiTerbuka()
    local res = safeInvoke("Stop", nil)
    isBusy = false

    if res and res.ok then
        API.Notify("Sound System", "Lagu berhasil dimatikan.", 2)
    else
        API.Notify("Gagal", "Tidak dapat mematikan lagu.", 3)
    end
    perbaruiStatusUI()
end

local function aturVolume(persen)
    local vol = math.clamp((tonumber(persen) or 100) / 100, 0, 1)
    pastikanSesiTerbuka()
    local res = safeInvoke("SetVolume", vol)
    if res and res.ok then
        API.Notify("Volume Diubah", "Volume diatur ke " .. tostring(math.floor(vol * 100)) .. "%", 2)
    end
    perbaruiStatusUI()
end

-- ==========================================
-- UI TAB: SOUND SYSTEM
-- ==========================================
local SoundTab = API.CreateTab("Sound System")

StatusSoundCard = API.Paragraph(
    SoundTab,
    "Sound System: Memuat status...",
    "Menghubungkan ke SoundSystemRequest & SoundSystemConfig..."
)

API.Section(SoundTab, "Daftar Lagu Bawaan (" .. tostring(#DaftarLagu) .. " Lagu)")

local judulOptions = {}
for i, song in ipairs(DaftarLagu) do
    table.insert(judulOptions, tostring(i) .. ". " .. song.Title)
end

if API.Dropdown then
    API.Dropdown(SoundTab, "Pilih Lagu Bawaan", judulOptions, judulOptions[1], function(val, idxParam)
        local idx = tonumber(idxParam) or tonumber(val) or tonumber(tostring(val):match("^(%d+)%."))
        if idx and DaftarLagu[idx] then
            selectedSongIndex = idx
            perbaruiStatusUI()
        end
    end)
end

API.Button(SoundTab, "Putar Lagu Pilihan", function()
    putarLaguPreset(selectedSongIndex)
end)

API.Button(SoundTab, "Lagu Berikutnya (Next) >>", function()
    if #DaftarLagu == 0 then return end
    selectedSongIndex = (selectedSongIndex % #DaftarLagu) + 1
    putarLaguPreset(selectedSongIndex)
end)

API.Button(SoundTab, "<< Lagu Sebelumnya (Prev)", function()
    if #DaftarLagu == 0 then return end
    selectedSongIndex = ((selectedSongIndex - 2) % #DaftarLagu) + 1
    putarLaguPreset(selectedSongIndex)
end)

API.Button(SoundTab, "Putar Lagu Acak (Shuffle)", function()
    if #DaftarLagu == 0 then return end
    selectedSongIndex = math.random(1, #DaftarLagu)
    putarLaguPreset(selectedSongIndex)
end)

API.Section(SoundTab, "Kontrol Speaker")

API.Button(SoundTab, "Matikan Lagu (Stop)", function()
    matikanLagu()
end)

API.Button(SoundTab, "Aktivasi & Buka UI Speaker Bawaan", function()
    local ok, err = triggerSpeakerFisik(false)
    if ok then
        API.Notify("Berhasil", "Speaker di-trigger & UI bawaan dibuka.", 2)
    else
        API.Notify("Gagal", tostring(err), 3)
    end
end)

API.Section(SoundTab, "Pengaturan Volume")

if API.Slider then
    API.Slider(SoundTab, "Volume Sound System (%)", 0, 100, 100, function(val)
        aturVolume(val)
    end)
else
    API.Button(SoundTab, "Volume 100% (Maksimal)", function() aturVolume(100) end)
    API.Button(SoundTab, "Volume 50% (Sedang)", function() aturVolume(50) end)
    API.Button(SoundTab, "Volume 20% (Pelan)", function() aturVolume(20) end)
    API.Button(SoundTab, "Volume 0% (Mute)", function() aturVolume(0) end)
end

Workspace:GetAttributeChangedSignal("SoundSystemPlaying"):Connect(perbaruiStatusUI)
Workspace:GetAttributeChangedSignal("SoundSystemSongId"):Connect(perbaruiStatusUI)
Workspace:GetAttributeChangedSignal("SoundSystemVolume"):Connect(perbaruiStatusUI)

perbaruiStatusUI()
