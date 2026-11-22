local API = ...

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SoundSystemRequest = Remotes:WaitForChild("SoundSystemRequest")
local SoundSystemConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundSystemConfig"))

local DaftarLagu = SoundSystemConfig.Songs or {}
local isBusy = false
local selectedSongIndex = 1

local StatusSoundCard

-- ==========================================
-- HELPER CARI SPEAKER MILIK PLAYER DI PLOT
-- ==========================================
local function cekMilikPlayer(instance)
    if not instance then return false end

    -- Cek semua attributes pada plot
    for _, val in pairs(instance:GetAttributes()) do
        if val == LocalPlayer.Name or val == LocalPlayer.UserId or tostring(val) == tostring(LocalPlayer.UserId) then
            return true
        end
    end

    -- Cek child ValueBase (StringValue, IntValue, NumberValue, ObjectValue) di level atas plot
    for _, child in ipairs(instance:GetChildren()) do
        if child:IsA("ValueBase") then
            local v = child.Value
            if v == LocalPlayer or v == LocalPlayer.Name or v == LocalPlayer.UserId or tostring(v) == tostring(LocalPlayer.UserId) then
                return true
            end
        end
    end

    return false
end

local function cariSpeakerPlot()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then
        return Workspace:FindFirstChild("SoundSystem", true)
    end

    -- 1. Cari di dalam plot yang teridentifikasi milik LocalPlayer
    for _, plot in ipairs(plots:GetChildren()) do
        if cekMilikPlayer(plot) then
            local spk = plot:FindFirstChild("SoundSystem", true)
            if spk then return spk end
        end
    end

    -- 2. Fallback: ambil SoundSystem terdekat dari posisi karakter saat ini
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

-- ==========================================
-- HELPER INVOKE REMOTE DENGAN SYNC JARAK
-- ==========================================
local function invokeDirect(action, arg)
    local ok, res = pcall(function()
        return SoundSystemRequest:InvokeServer(action, arg)
    end)
    if ok then
        return res
    end
    return nil
end

local function pastikanSesiTerbuka()
    -- Percobaan 1: langsung tembak Open (berhasil jika karakter sudah dekat atau sesi masih aktif)
    local res = invokeDirect("Open", nil)
    if res and res.ok then
        return true, res
    end

    -- Percobaan 2: dekatkan karakter sebentar ke speaker plot agar lolos cek jarak server
    local speaker = cariSpeakerPlot()
    if not speaker then
        return false, "Speaker SoundSystem tidak ditemukan di plot!"
    end

    local targetPart = speaker:IsA("BasePart") and speaker or speaker:FindFirstChildWhichIsA("BasePart", true)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not (hrp and targetPart) then
        return false, "Karakter atau part speaker tidak ditemukan."
    end

    local posisiAwal = hrp.CFrame
    hrp.CFrame = targetPart.CFrame * CFrame.new(0, 2, 2.5)
    task.wait(0.25) -- Beri waktu replikasi posisi karakter ke server

    local retryRes = invokeDirect("Open", nil)

    -- Kembalikan posisi karakter ke tempat semula
    if hrp and hrp.Parent then
        hrp.CFrame = posisiAwal
    end

    if retryRes and retryRes.ok then
        return true, retryRes
    end

    local alasan = (type(retryRes) == "table" and (retryRes.message or retryRes.msg or retryRes.reason or retryRes.error))
        or "Server tetap menolak Open (pastikan speaker berada di plot milikmu)."
    return false, alasan
end

-- ==========================================
-- STATUS & KONTROL LAGU
-- ==========================================
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

    local res = invokeDirect("PlayListed", song.ID)
    isBusy = false

    if res and res.ok then
        API.Notify("Memutar Lagu", song.Title, 3)
    else
        local msg = (type(res) == "table" and (res.message or res.msg or res.reason or res.error))
            or "Lagu gagal diputar oleh server."
        API.Notify("Gagal Memutar", tostring(msg), 3)
    end
    perbaruiStatusUI()
end

local function matikanLagu()
    if isBusy then return end
    isBusy = true
    local openOk, openErr = pastikanSesiTerbuka()
    if not openOk then
        isBusy = false
        API.Notify("Sesi Ditolak", tostring(openErr), 3)
        return
    end

    local res = invokeDirect("Stop", nil)
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
    local openOk = pastikanSesiTerbuka()
    if not openOk then return end

    local res = invokeDirect("SetVolume", vol)
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

API.Button(SoundTab, "Lagu Berikutnya", function()
    if #DaftarLagu == 0 then return end
    selectedSongIndex = (selectedSongIndex % #DaftarLagu) + 1
    putarLaguPreset(selectedSongIndex)
end)

API.Button(SoundTab, "Lagu Sebelumnya", function()
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

API.Button(SoundTab, "Matikan Lagu", function()
    matikanLagu()
end)

API.Button(SoundTab, "Buka UI Music", function()
    local speaker = cariSpeakerPlot()
    if _G.OpenSoundChoice then
        local openOk, openErr = pastikanSesiTerbuka()
        if openOk then
            _G.OpenSoundChoice(speaker)
        else
            API.Notify("Sesi Ditolak", tostring(openErr), 3)
        end
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
