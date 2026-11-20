local API = ...

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 15)
local SewaGamepassRemote = RemotesFolder and RemotesFolder:WaitForChild("SewaGamepass", 15)

-- ==========================================
-- KONFIGURASI SEWA PEKERJA
-- ==========================================
local DAFTAR_ROLE = { "Pengangkut", "Keamanan", "Pembersih" }

local roleDipilih = "Pengangkut"
local durasiHari = 1
local autoPerpanjangAktif = false
local perpanjangSemuaRole = false

-- State Konfirmasi 2x Tap (Anti-Kepencet)
local konfirmasiSingle = false
local tokenSingle = 0
local konfirmasiSemua = false
local tokenSemua = 0

-- State Pelacak Siklus Hari untuk Auto Perpanjang
local sisaHariKontrak = 0
local hariTerakhirDiproses = nil

-- ==========================================
-- FUNGSI EKSEKUSI REMOTE SEWAGAMEPASS
-- ==========================================
local function eksekusiSewa(roleName, jumlahHari)
    if not SewaGamepassRemote then
        API.Notify("Remote Tidak Ditemukan", "Sewa Gamepass tidak ditemukan.", 4)
        return false
    end

    local hariValid = math.max(1, math.floor(tonumber(jumlahHari) or 1))
    local ok, err = pcall(function()
        SewaGamepassRemote:FireServer(roleName, hariValid)
    end)

    if not ok then
        API.Notify("Gagal Sewa " .. roleName, tostring(err), 4)
        return false
    end

    return true
end

local function sewaSemuaRole(jumlahHari)
    local berhasil = 0
    for _, role in ipairs(DAFTAR_ROLE) do
        if eksekusiSewa(role, jumlahHari) then
            berhasil = berhasil + 1
        end
        task.wait(0.35)
    end
    return berhasil
end

-- ==========================================
-- UI TAB: SEWA PEKERJA
-- ==========================================
local SewaTab = API.CreateTab("Sewa Pekerja")

API.Section(SewaTab, "Pengaturan Role & Durasi Hari")

local SingleSewaButton
local AllSewaButton

local function perbaruiLabelTombol()
    API.SetElementText(SingleSewaButton, "Sewa " .. roleDipilih .. " (" .. durasiHari .. " Hari)")
    API.SetElementText(AllSewaButton, "Sewa Semua Role (" .. durasiHari .. " Hari)")
end

API.Dropdown(SewaTab, "Pilih Role Pekerja", DAFTAR_ROLE, "Pengangkut", function(opt)
    roleDipilih = tostring(opt)
    konfirmasiSingle = false
    tokenSingle = tokenSingle + 1
    perbaruiLabelTombol()
end)

API.Slider(SewaTab, "Durasi Sewa (dalam Hari)", 1, 30, 1, " Hari", 1, function(val)
    durasiHari = math.max(1, math.floor(tonumber(val) or 1))
    konfirmasiSingle = false
    konfirmasiSemua = false
    tokenSingle = tokenSingle + 1
    tokenSemua = tokenSemua + 1
    perbaruiLabelTombol()
end)

API.Input(SewaTab, "Custom Angka Hari Bebas (Tekan Enter)", "Contoh: 7 atau 30", function(txt)
    local angka = tonumber(tostring(txt):match("%d+"))
    if angka and angka >= 1 then
        durasiHari = math.floor(angka)
        konfirmasiSingle = false
        konfirmasiSemua = false
        tokenSingle = tokenSingle + 1
        tokenSemua = tokenSemua + 1
        perbaruiLabelTombol()
        API.Notify("Durasi Diatur", "Durasi sewa diatur ke " .. durasiHari .. " hari.", 2)
    elseif txt ~= "" then
        API.Notify("Angka Tidak Valid", "Masukkan angka hari minimal 1.", 3)
    end
end)

API.Section(SewaTab, "Eksekusi Sewa (Konfirmasi 2x Klik)")

SingleSewaButton = API.Button(SewaTab, "Sewa Pengangkut (1 Hari)", function()
    if not konfirmasiSingle then
        konfirmasiSingle = true
        tokenSingle = tokenSingle + 1
        local currentToken = tokenSingle

        API.SetElementText(SingleSewaButton, "Tap Lagi untuk Konfirmasi Sewa " .. roleDipilih .. " (" .. durasiHari .. " Hari)")
        API.Notify("Konfirmasi Sewa", "Tap sekali lagi dalam 5 detik untuk menyewa " .. roleDipilih .. ".", 4)

        task.delay(5, function()
            if konfirmasiSingle and tokenSingle == currentToken then
                konfirmasiSingle = false
                perbaruiLabelTombol()
            end
        end)
    else
        konfirmasiSingle = false
        tokenSingle = tokenSingle + 1
        perbaruiLabelTombol()

        task.spawn(function()
            if eksekusiSewa(roleDipilih, durasiHari) then
                sisaHariKontrak = durasiHari
                API.Notify("Berhasil Sewa!", roleDipilih .. " disewa selama " .. durasiHari .. " hari.", 3)
            end
        end)
    end
end)

AllSewaButton = API.Button(SewaTab, "Sewa Semua Role (1 Hari)", function()
    if not konfirmasiSemua then
        konfirmasiSemua = true
        tokenSemua = tokenSemua + 1
        local currentToken = tokenSemua

        API.SetElementText(AllSewaButton, "Tap Lagi untuk Konfirmasi Semua Role (" .. durasiHari .. " Hari)")
        API.Notify("Konfirmasi Sewa Semua", "Tap sekali lagi dalam 5 detik untuk menyewa 3 role sekaligus.", 4)

        task.delay(5, function()
            if konfirmasiSemua and tokenSemua == currentToken then
                konfirmasiSemua = false
                perbaruiLabelTombol()
            end
        end)
    else
        konfirmasiSemua = false
        tokenSemua = tokenSemua + 1
        perbaruiLabelTombol()

        task.spawn(function()
            local total = sewaSemuaRole(durasiHari)
            if total > 0 then
                sisaHariKontrak = durasiHari
                API.Notify("Sewa Untuk Semua Role Berhasil!", total .. " role disewa selama " .. durasiHari .. " hari.", 4)
            end
        end)
    end
end)

API.Section(SewaTab, "Otomatisasi Idle (Perpanjang Otomatis)")

API.Toggle(SewaTab, "Perpanjang Semua Role (Kalau Tidak Aktif, Pakai Role Terpilih)", false, function(val)
    perpanjangSemuaRole = val
end)

API.Toggle(SewaTab, "Auto Perpanjang Saat Kontrak Habis", false, function(val)
    autoPerpanjangAktif = val
    if val then
        sisaHariKontrak = durasiHari
        API.Notify(
            "Auto Perpanjang Aktif",
            "Otomatis sewa ulang tiap " .. durasiHari .. " hari in-game berlalu.",
            3
        )
    else
        API.Notify("Auto Perpanjang Mati", "Perpanjangan otomatis dihentikan.", 2)
    end
end)

-- ==========================================
-- DETEKTOR PERGANTIAN HARI UNTUK AUTO PERPANJANG
-- ==========================================
task.spawn(function()
    local ShowDayRecap = RemotesFolder and RemotesFolder:WaitForChild("ShowDayRecap", 15)
    if ShowDayRecap and ShowDayRecap:IsA("RemoteEvent") then
        ShowDayRecap.OnClientEvent:Connect(function(data)
            if not autoPerpanjangAktif or typeof(data) ~= "table" then return end

            local dayId = data.day or os.time()
            if hariTerakhirDiproses == dayId then return end
            hariTerakhirDiproses = dayId

            sisaHariKontrak = sisaHariKontrak - 1
            if sisaHariKontrak <= 0 then
                sisaHariKontrak = durasiHari
                task.spawn(function()
                    if perpanjangSemuaRole then
                        local total = sewaSemuaRole(durasiHari)
                        if total > 0 then
                            API.Notify("Auto Perpanjang", "Kontrak " .. total .. " role diperpanjang (" .. durasiHari .. " hari).", 4)
                        end
                    else
                        if eksekusiSewa(roleDipilih, durasiHari) then
                            API.Notify("Auto Perpanjang", "Kontrak " .. roleDipilih .. " diperpanjang (" .. durasiHari .. " hari).", 4)
                        end
                    end
                end)
            end
        end)
    end
end)
