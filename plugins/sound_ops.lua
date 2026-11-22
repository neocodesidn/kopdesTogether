-- sound_ops.lua
-- Modul Kontrol Sound System (Kopdes Together)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SoundSystemRequest = Remotes:WaitForChild("SoundSystemRequest")

-- Ambil konfigurasi & daftar lagu resmi langsung dari modul game
local SoundSystemConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundSystemConfig"))

local SoundOps = {}
SoundOps.Songs = SoundSystemConfig.Songs or {} -- Berisi array { Title = "...", ID = 123456 }
SoundOps.IsBusy = false

-- Helper aman untuk memanggil RemoteFunction dengan timeout
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

-- Helper mengecek apakah asset audio bisa dimuat oleh client (sesuai logika game)
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

-- 1. Inisialisasi sesi Sound System (wajib dipanggil sebelum memutar jika belum dibuka)
function SoundOps.Open()
    local res = safeInvoke("Open", nil)
    return res ~= nil and res.ok == true, res
end

-- 2. Putar lagu dari Daftar Lagu Bawaan (Preset List) memakai ID atau Title
function SoundOps.PlayListed(idOrTitle)
    if SoundOps.IsBusy then
        return false, "Sistem sedang memproses permintaan lain"
    end

    local targetId = tonumber(idOrTitle)
    local targetTitle = nil

    -- Jika parameter berupa judul lagu (string), cari ID-nya di SoundSystemConfig.Songs
    if not targetId and type(idOrTitle) == "string" then
        local query = string.lower(idOrTitle)
        for _, song in ipairs(SoundOps.Songs) do
            if string.lower(song.Title) == query or string.find(string.lower(song.Title), query, 1, true) then
                targetId = song.ID
                targetTitle = song.Title
                break
            end
        end
    else
        for _, song in ipairs(SoundOps.Songs) do
            if song.ID == targetId then
                targetTitle = song.Title
                break
            end
        end
    end

    if not targetId then
        return false, "Lagu tidak ditemukan di daftar bawaan"
    end

    SoundOps.IsBusy = true
    SoundOps.Open() -- Pastikan sesi terbuka
    local res = safeInvoke("PlayListed", targetId)
    SoundOps.IsBusy = false

    if res and res.ok then
        return true, targetTitle or tostring(targetId)
    end
    return false, "Gagal memutar lagu dari daftar"
end

-- 3. Cek & Putar lagu Custom ID (otomatis melewati alur Open -> Check -> Preload -> Play)
function SoundOps.PlayCustomId(rawInput)
    if SoundOps.IsBusy then
        return false, "Sistem sedang memproses permintaan lain"
    end

    local parsedId = SoundSystemConfig.ParseId and SoundSystemConfig.ParseId(tostring(rawInput)) or tonumber(tostring(rawInput):match("%d+"))
    if not parsedId then
        return false, "Format ID lagu tidak valid"
    end

    SoundOps.IsBusy = true
    SoundOps.Open()

    -- Tahap 1: Check ID ke server untuk mendapatkan token & judul lagu
    local checkRes = safeInvoke("Check", parsedId)
    if not (checkRes and checkRes.ok and checkRes.token) then
        SoundOps.IsBusy = false
        return false, "ID lagu ditolak atau belum tersedia di server"
    end

    -- Tahap 2: Validasi preload di client agar tidak error saat diputar
    if not canPreloadAudio(parsedId) then
        SoundOps.IsBusy = false
        return false, "Audio gagal dimuat oleh client (mungkin kena moderasi/private)"
    end

    -- Tahap 3: Eksekusi Play menggunakan token dari server
    local playRes = safeInvoke("Play", checkRes.token)
    SoundOps.IsBusy = false

    if playRes and playRes.ok then
        return true, checkRes.title or ("ID: " .. tostring(parsedId))
    end

    return false, "Gagal memutar lagu setelah validasi token"
end

-- 4. Matikan lagu yang sedang diputar
function SoundOps.Stop()
    if SoundOps.IsBusy then
        return false, "Sistem sedang sibuk"
    end

    SoundOps.IsBusy = true
    local res = safeInvoke("Stop", nil)
    SoundOps.IsBusy = false

    if res and res.ok then
        return true, "Lagu berhasil dimatikan"
    end
    return false, "Gagal mematikan lagu"
end

-- 5. Atur Volume Global Sound System (0.0 sampai 1.0, atau 0 - 100 otomatis dikonversi)
function SoundOps.SetVolume(level)
    local vol = tonumber(level) or 1
    if vol > 1 then
        vol = vol / 100
    end
    vol = math.clamp(vol, 0, 1)

    local res = safeInvoke("SetVolume", vol)
    return res ~= nil and res.ok == true, vol
end

-- 6. Ambil daftar judul lagu siap pakai untuk Dropdown UI
function SoundOps.GetSongTitles()
    local list = {}
    for _, song in ipairs(SoundOps.Songs) do
        table.insert(list, song.Title)
    end
    return list
end

-- 7. Cek status pemutaran & volume saat ini dari atribut workspace
function SoundOps.GetStatus()
    return {
        Playing = workspace:GetAttribute("SoundSystemPlaying") == true,
        SongId = workspace:GetAttribute("SoundSystemSongId"),
        Volume = workspace:GetAttribute("SoundSystemVolume") or 1,
    }
end

return SoundOps
