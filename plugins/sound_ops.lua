local API = ...

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SoundSystemRequest = Remotes:WaitForChild("SoundSystemRequest")
local SoundSystemConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundSystemConfig"))

local DaftarLagu = SoundSystemConfig.Songs or {}
local isBusy = false
local selectedSongIndex = 1
local customIdInput = ""

local StatusSoundCard

-- ==========================================
-- HELPER REMOTE & PRELOAD AUDIO
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

local function canPreloadAudio(assetId)
    local tempSound = Instance.new("Sound")
    tempSound.SoundId = "rbxassetid://" .. tostring(assetId)
    tempSound.Volume = 0
    tempSound.Parent = SoundService

    local loaded = false
    local finished = false

    local thread = task.spawn(function()
        pcall(function()
            ContentProvider:PreloadAsync({ tempSound }, function(_, status)
                if status == Enum.AssetFetchStatus.Success then
                    loaded = true
                end
            end)
        end)
        loaded = loaded or tempSound.IsLoaded
        finished = true
    end)

    local timeout = os.clock() + (SoundSystemConfig.CheckTimeout or 8)
    while not finished and os.clock() < timeout do
        task.wait(0.05)
    end

    if not finished then
        pcall(task.cancel, thread)
        loaded = false
    end

    tempSound:Destroy()
    return loaded
end

local function cariJudulDariId(songId)
    if not songId then return "-" end
    for _, song in ipairs(DaftarLagu) do
        if song.ID == songId then
            return song.Title
        end
    end
    return "Custom ID (" .. tostring(songId) .. ")"
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
        "Volume: " .. tostring(currentVol) .. "% | Pilihan Preset (#" .. tostring(selectedSongIndex) .. "): " .. namaPilihan
    )
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
    safeInvoke("Open", nil)
    local res = safeInvoke("PlayListed", song.ID)
    isBusy = false

    if res and res.ok then
        API.Notify("Memutar Lagu", song.Title, 3)
    else
        API.Notify("Gagal Memutar", "Lagu belum tersedia di server.", 3)
    end
    perbaruiStatusUI()
end

local function putarCustomId(rawText)
    if isBusy then
        API.Notify("Tunggu", "Sedang memproses pengecekan lagu...", 2)
        return
    end

    local parsedId = (SoundSystemConfig.ParseId and SoundSystemConfig.ParseId(tostring(rawText)))
        or tonumber(tostring(rawText):match("%d+"))

    if not parsedId then
        API.Notify("ID Tidak Valid", "Masukkan angka Asset ID lagu yang benar.", 3)
        return
    end

    isBusy = true
    API.Notify("Mengecek Lagu", "Memvalidasi ID " .. tostring(parsedId) .. "...", 2)

    safeInvoke("Open", nil)
    local checkRes = safeInvoke("Check", parsedId)

    if not (checkRes and checkRes.ok and checkRes.token) then
        isBusy = false
        API.Notify("Ditolak Server", "Lagu belum tersedia atau tidak diizinkan.", 3)
        return
    end

    if not canPreloadAudio(parsedId) then
        isBusy = false
        API.Notify("Gagal Preload", "Audio gagal dimuat oleh client.", 3)
        return
    end

    local playRes = safeInvoke("Play", checkRes.token)
    isBusy = false

    if playRes and playRes.ok then
        API.Notify("Memutar Custom ID", checkRes.title or ("ID: " .. tostring(parsedId)), 3)
    else
        API.Notify("Gagal Memutar", "Token ditolak saat memutar lagu.", 3)
    end
    perbaruiStatusUI()
end

local function matikanLagu()
    if isBusy then return end
    isBusy = true
    local res = safeInvoke("Stop", nil)
    isBusy = false

    if res and res.ok then
        API.Notify("Sound System", "Lagu berhasil dimatikan.", 2)
    else
        API.Notify("Gagal", "Tidak dapat mematikan lagu.", 2)
    end
    perbaruiStatusUI()
end

local function aturVolume(persen)
    local vol = math.clamp((tonumber(persen) or 100) / 100, 0, 1)
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

-- Susun daftar judul untuk Dropdown jika tersedia di CustomUI
local judulOptions = {}
for i, song in ipairs(DaftarLagu) do
    table.insert(judulOptions, tostring(i) .. ". " .. song.Title)
end

if API.Dropdown then
    API.Dropdown(SoundTab, "Pilih Lagu Bawaan", judulOptions, judulOptions[1], function(val)
        local idx = tonumber(tostring(val):match("^(%d+)%."))
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

API.Section(SoundTab, "Custom Asset ID & Kontrol")

if API.Input or API.TextBox then
    local inputFn = API.Input or API.TextBox
    inputFn(SoundTab, "Masukkan ID Lagu (Angka)", "Contoh: 112447571198662", function(text)
        customIdInput = text
    end)
end

API.Button(SoundTab, "Cek & Putar Custom ID", function()
    putarCustomId(customIdInput)
end)

API.Button(SoundTab, "Matikan Lagu (Stop)", function()
    matikanLagu()
end)

API.Button(SoundTab, "Buka UI SoundChoice Bawaan Game", function()
    if _G.OpenSoundChoice then
        _G.OpenSoundChoice()
    else
        safeInvoke("Open", nil)
        API.Notify("Info", "Remote Open dipanggil.", 2)
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

-- Listener sinkronisasi real-time jika ada pemain lain mengganti lagu/volume
Workspace:GetAttributeChangedSignal("SoundSystemPlaying"):Connect(perbaruiStatusUI)
Workspace:GetAttributeChangedSignal("SoundSystemSongId"):Connect(perbaruiStatusUI)
Workspace:GetAttributeChangedSignal("SoundSystemVolume"):Connect(perbaruiStatusUI)

perbaruiStatusUI()
