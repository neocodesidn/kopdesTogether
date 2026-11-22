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
local sesiAktif = false
local selectedSongIndex = 1

local StatusSoundCard

-- ==========================================
-- HELPER CARI SPEAKER MILIK PLAYER DI PLOT
-- ==========================================
local function cekMilikPlayer(instance)
    if not instance then return false end

    for _, val in pairs(instance:GetAttributes()) do
        if val == LocalPlayer.Name or val == LocalPlayer.UserId or tostring(val) == tostring(LocalPlayer.UserId) then
            return true
        end
    end

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

    for _, plot in ipairs(plots:GetChildren()) do
        if cekMilikPlayer(plot) then
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

-- ==========================================
-- HELPER INVOKE & STATUS UI
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
    local labelSesi = sesiAktif and "AKTIF" or "BELUM AKTIF (Wajib Tahap 1)"

    API.SetElementText(
        StatusSoundCard,
        "Sesi: " .. labelSesi .. " | " .. (isPlaying and ("MEMUTAR - " .. cariJudulDariId(currentId)) or "Berhenti"),
        "Volume: " .. tostring(currentVol) .. "% | Pilihan (#" .. tostring(selectedSongIndex) .. "): " .. namaPilihan
    )
end

-- ==========================================
-- TAHAP 1: AKTIVASI SPEAKER DI DEKAT BARANG
-- ==========================================
local function aktivasiSpeaker(autoBalik)
    -- Cek apakah sesi sudah aktif tanpa perlu pindah posisi
    local cekLangsung = invokeDirect("Open", nil)
    if cekLangsung and cekLangsung.ok then
        sesiAktif = true
        perbaruiStatusUI()
        return true, "Sesi speaker sudah aktif!"
    end

    local speaker = cariSpeakerPlot()
    if not speaker then
        return false, "Speaker SoundSystem tidak ditemukan di plot!"
    end

    local targetPart = speaker:IsA("BasePart") and speaker or speaker:FindFirstChildWhichIsA("BasePart", true)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if not (hrp and targetPart) then
        return false, "Karakter atau objek speaker tidak ditemukan."
    end

    local posisiAwal = hrp.CFrame

    -- Dekatkan karakter tepat di depan speaker agar validasi jarak server lolos
    hrp.CFrame = targetPart.CFrame * CFrame.new(0, 2, 2.5)
    task.wait(0.35)

    local res = invokeDirect("Open", nil)

    if autoBalik and hrp and hrp.Parent then
        hrp.CFrame = posisiAwal
    end

    if res and res.ok then
        sesiAktif = true
        perbaruiStatusUI()
        return true, "Speaker berhasil diaktivasi!"
    end

    sesiAktif = false
    perbaruiStatusUI()
    local alasan = (type(res) == "table" and (res.message or res.msg or res.reason or res.error))
        or "Gagal aktivasi. Coba berdiri tepat di samping speaker lalu tekan Tahap 1."
    return false, alasan
end

-- ==========================================
-- TAHAP 2: PUTAR / STOP / VOLUME
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

    -- Pastikan Tahap 1 sudah aktif sebelum Tahap 2 dijalankan
    if not sesiAktif then
        local okAktif, errAktif = aktivasiSpeaker(true)
        if not okAktif then
            isBusy = false
            API.Notify("Wajib Tahap 1 Dulu", tostring(errAktif), 4)
            return
        end
    end

    local res = invokeDirect("PlayListed", song.ID)

    -- Jika sesi sempat reset oleh server, ulangi Tahap 1 sekali lagi
    if not (res and res.ok) then
        sesiAktif = false
        local okRetry, errRetry = aktivasiSpeaker(true)
        if okRetry then
            res = invokeDirect("PlayListed", song.ID)
        else
            isBusy = false
            API.Notify("Sesi Reset", tostring(errRetry), 4)
            return
        end
    end

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

    if not sesiAktif then
        aktivasiSpeaker(true)
    end

    local res = invokeDirect("Stop", nil)
    isBusy = false

    if res and res.ok then
        API.Notify("Sound System", "Lagu berhasil dimatikan.", 2)
    else
        API.Notify("Gagal", "Tidak dapat mematikan lagu (jalankan Tahap 1 dulu).", 3)
    end
    perbaruiStatusUI()
end

local function aturVolume(persen)
    local vol = math.clamp((tonumber(persen) or 100) / 100, 0, 1)
    if not sesiAktif then
        aktivasiSpeaker(true)
    end

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
    "Sesi: BELUM AKTIF | Memuat status...",
    "Jalankan Tahap 1 (Aktivasi) terlebih dahulu sebelum memutar lagu."
)

API.Section(SoundTab, "Tahap 1: Aktivasi Speaker (Wajib Pertama Kali)")

API.Button(SoundTab, "1. Teleport ke Speaker & Aktivasi (Stay)", function()
    if isBusy then return end
    isBusy = true
    local ok, msg = aktivasiSpeaker(false)
    isBusy = false
    API.Notify(ok and "Tahap 1 Berhasil" or "Tahap 1 Gagal", tostring(msg), 3)
end)

API.Button(SoundTab, "2. Aktivasi Cepat (Dekati Speaker & Balik)", function()
    if isBusy then return end
    isBusy = true
    local ok, msg = aktivasiSpeaker(true)
    isBusy = false
    API.Notify(ok and "Tahap 1 Berhasil" or "Tahap 1 Gagal", tostring(msg), 3)
end)

API.Section(SoundTab, "Tahap 2: Daftar Lagu Bawaan (" .. tostring(#DaftarLagu) .. " Lagu)")

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

API.Section(SoundTab, "Kontrol & Volume")

API.Button(SoundTab, "Matikan Lagu (Stop)", function()
    matikanLagu()
end)

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

-- Reset status sesi jika karakter respawn
LocalPlayer.CharacterAdded:Connect(function()
    sesiAktif = false
    perbaruiStatusUI()
end)

Workspace:GetAttributeChangedSignal("SoundSystemPlaying"):Connect(perbaruiStatusUI)
Workspace:GetAttributeChangedSignal("SoundSystemSongId"):Connect(perbaruiStatusUI)
Workspace:GetAttributeChangedSignal("SoundSystemVolume"):Connect(perbaruiStatusUI)

perbaruiStatusUI()
