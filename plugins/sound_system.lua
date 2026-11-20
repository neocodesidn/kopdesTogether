local API = ...

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 15)
local SoundSystemRemote = RemotesFolder and RemotesFolder:WaitForChild("SoundSystemRequest", 15)

-- ==========================================
-- STATE & PLAYLIST TERSIMPAN
-- ==========================================
local inputAudioId = 136298946425465
local sedangMemproses = false
local autoLoopAktif = false
local lastPlayedId = nil
local lastPlayedTitle = "-"

-- Daftar lagu cepat (otomatis bertambah saat kamu memutar ID baru)
local savedTracks = {
    { id = 136298946425465, title = "CLOUD | KICAU MANIA" },
}

local function ambilOpsiPlaylist()
    local opsi = {}
    for _, track in ipairs(savedTracks) do
        table.insert(opsi, track.title .. " [" .. tostring(track.id) .. "]")
    end
    return opsi
end

local function simpanKePlaylist(audioId, title)
    for _, track in ipairs(savedTracks) do
        if track.id == audioId then
            track.title = title
            return
        end
    end
    table.insert(savedTracks, { id = audioId, title = title })
end

-- ==========================================
-- EKSEKUSI 3 TAHAP: OPEN -> CHECK -> PLAY
-- ==========================================
local StatusCard
local PlaylistDropdown

local function putarAudioRemote(audioId, silent)
    if sedangMemproses then return false end
    if not SoundSystemRemote then
        if not silent then
            API.Notify("Remote Tidak Ditemukan", "Sistem suara tidak ditemukan.", 4)
        end
        return false
    end

    local idAngka = tonumber(tostring(audioId):match("%d+"))
    if not idAngka or idAngka <= 0 then
        if not silent then
            API.Notify("ID Tidak Valid", "Masukkan angka Roblox Audio ID yang benar.", 3)
        end
        return false
    end

    sedangMemproses = true
    local berhasil = false

    pcall(function()
        -- Tahap 1: Inisialisasi sesi panel speaker dari jarak jauh
        local resOpen = SoundSystemRemote:InvokeServer("Open", nil)
        if typeof(resOpen) == "table" and resOpen.ok == false then
            if not silent then
                API.Notify("Akses Ditolak", tostring(resOpen.message or "Tidak memiliki akses ke speaker toko."), 4)
            end
            return
        end

        -- Tahap 2: Validasi ID & ambil token otorisasi dari server
        local resCheck = SoundSystemRemote:InvokeServer("Check", idAngka)
        if typeof(resCheck) ~= "table" or not resCheck.ok or not resCheck.token then
            local errMsg = (typeof(resCheck) == "table" and resCheck.message) or "Audio ID tidak valid atau terkena moderasi."
            if not silent then
                API.Notify("Gagal Cek Audio", tostring(errMsg), 4)
            end
            return
        end

        local judulLagu = tostring(resCheck.title or ("Audio #" .. tostring(idAngka)))
        local tokenLagu = tostring(resCheck.token)

        -- Tahap 3: Putar lagu menggunakan token hasil validasi
        local resPlay = SoundSystemRemote:InvokeServer("Play", tokenLagu)
        if typeof(resPlay) == "table" and resPlay.ok then
            berhasil = true
            lastPlayedId = idAngka
            lastPlayedTitle = judulLagu

            simpanKePlaylist(idAngka, judulLagu)
            if PlaylistDropdown and PlaylistDropdown.Refresh then
                pcall(function()
                    PlaylistDropdown:Refresh(ambilOpsiPlaylist())
                end)
            end

            API.SetElementText(
                StatusCard,
                "Sedang Diputar: " .. judulLagu,
                "Audio ID: " .. tostring(idAngka) .. " • Status: Aktif di Speaker Toko"
            )

            if not silent then
                API.Notify("Memutar Musik", judulLagu, 3)
            end
        else
            local playErr = (typeof(resPlay) == "table" and resPlay.message) or "Server gagal memutar audio."
            if not silent then
                API.Notify("Gagal Memutar", tostring(playErr), 4)
            end
        end
    end)

    sedangMemproses = false
    return berhasil
end

-- ==========================================
-- UI TAB: SPEAKER / MUSIK
-- ==========================================
local MusicTab = API.CreateTab("Musik")

API.Section(MusicTab, "Status Speaker Toko (Jarak Jauh)")
StatusCard = API.Paragraph(
    MusicTab,
    "Belum Ada Lagu Diputar",
    "Masukkan Audio ID di bawah atau pilih dari Playlist Cepat."
)

API.Section(MusicTab, "Putar Lagu dengan Audio ID")
API.Input(MusicTab, "Roblox Audio ID (Tekan Enter)", "136298946425465", function(txt)
    local angka = tonumber(tostring(txt):match("%d+"))
    if angka then
        inputAudioId = angka
        API.Notify("ID Disiapkan", "Audio ID: " .. tostring(angka), 2)
    elseif txt ~= "" then
        API.Notify("Format Salah", "Masukkan angka Audio ID Roblox.", 3)
    end
end)

API.Button(MusicTab, "Cek & Putar Audio ID Sekarang", function()
    task.spawn(putarAudioRemote, inputAudioId, false)
end)

API.Section(MusicTab, "Playlist Cepat & Main Ulang")
PlaylistDropdown = API.Dropdown(
    MusicTab,
    "Pilih Lagu Tersimpan",
    ambilOpsiPlaylist(),
    "CLOUD | KICAU MANIA [136298946425465]",
    function(opt)
        local idDariPilihan = tonumber(tostring(opt):match("%[(%d+)%]"))
        if idDariPilihan then
            inputAudioId = idDariPilihan
            task.spawn(putarAudioRemote, idDariPilihan, false)
        end
    end
)

API.Toggle(MusicTab, "Main Ulang Otomatis", false, function(val)
    autoLoopAktif = val
    API.Notify(
        val and "Main Ulang Aktif" or "Main Ulang Dinonaktif",
        val and "Lagu terakhir akan diputar ulang sendiri saat selesai." or "Fitur main ulang dimatikan.",
        3
    )
end)

-- ==========================================
-- LISTENER AUTO REPLAY (DETEKSI SOUND DI PLOT1)
-- ==========================================
local function pantauObjekSound(obj)
    if obj:IsA("Sound") then
        obj.Ended:Connect(function()
            if autoLoopAktif and lastPlayedId then
                task.wait(0.5)
                putarAudioRemote(lastPlayedId, true)
            end
        end)
    end
end

for _, desc in ipairs(API.Plot:GetDescendants()) do
    pantauObjekSound(desc)
end
API.Plot.DescendantAdded:Connect(pantauObjekSound)
