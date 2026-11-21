local API = ...

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = API.LocalPlayer

local QuestRemotes = ReplicatedStorage:WaitForChild("QuestRemotes", 10)
local GetQuestsRemote = QuestRemotes and QuestRemotes:FindFirstChild("GetQuests")
local ClaimQuestRemote = QuestRemotes and QuestRemotes:FindFirstChild("ClaimQuest")

local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
local NotifikasiRemote = RemotesFolder and RemotesFolder:FindFirstChild("Notifikasi")

-- ==========================================
-- KONFIGURASI AUTO CLAIM QUEST (REAL-TIME RINGAN)
-- ==========================================
local autoQuestEnabled = false
local sedangCekQuest = false
local timerDebounceAktif = false
local totalBerhasilClaim = 0
local waktuCekTerakhir = 0

local StatusQuestCard
local lastJudulUI = ""
local lastSubUI = ""

local function perbaruiStatusUI(teksJudul, teksSub)
    if not StatusQuestCard then return end
    if teksJudul == lastJudulUI and teksSub == lastSubUI then return end
    lastJudulUI = teksJudul
    lastSubUI = teksSub
    API.SetElementText(StatusQuestCard, teksJudul, teksSub)
end

-- ==========================================
-- FUNGSI CEK & CLAIM QUEST
-- ==========================================
local function cekDanClaimQuest(dariTombolManual)
    if sedangCekQuest then return 0 end
    if not GetQuestsRemote or not ClaimQuestRemote then
        perbaruiStatusUI("Error: QuestRemotes tidak ditemukan", "Pastikan remote tersedia di ReplicatedStorage.")
        return 0
    end

    sedangCekQuest = true
    waktuCekTerakhir = tick()

    local jumlahClaimBaru = 0
    local jumlahAktif = 0

    local ok, dataQuest = pcall(function()
        return GetQuestsRemote:InvokeServer()
    end)

    if ok and typeof(dataQuest) == "table" and typeof(dataQuest.quests) == "table" then
        for _, q in ipairs(dataQuest.quests) do
            if not q.claimed then
                jumlahAktif = jumlahAktif + 1
            end

            local siapClaim = (q.claimable == true)
                or (q.def and typeof(q.def.target) == "number" and typeof(q.progress) == "number" and q.progress >= q.def.target)

            if siapClaim and not q.claimed and typeof(q.uid) == "string" then
                local okClaim, resClaim = pcall(function()
                    return ClaimQuestRemote:InvokeServer(q.uid)
                end)

                if okClaim and typeof(resClaim) == "table" and resClaim.ok == true then
                    jumlahClaimBaru = jumlahClaimBaru + 1
                    totalBerhasilClaim = totalBerhasilClaim + 1

                    local jenisHadiah = (q.def and q.def.reward and q.def.reward.kind) or "Hadiah"
                    local nominalHadiah = (q.def and q.def.reward and tostring(q.def.reward.amount)) or ""
                    API.Notify(
                        "Misi Selesai Diambil!",
                        "Berhasil mengambil hadiah " .. nominalHadiah .. " " .. jenisHadiah .. ".",
                        2
                    )
                    task.wait(0.15)
                end
            end
        end
    end

    local statusTeks = autoQuestEnabled
        and "Status: Otomatis Aktif"
        or "Status: Nonaktif"

    perbaruiStatusUI(
        "Quest Aktif: " .. tostring(jumlahAktif) .. "  |  Total Diklaim: " .. tostring(totalBerhasilClaim),
        statusTeks
    )

    if dariTombolManual and jumlahClaimBaru == 0 then
        API.Notify("Info Quest", "Belum ada quest yang siap diklaim (" .. tostring(jumlahAktif) .. " quest berjalan).", 2)
    end

    sedangCekQuest = false
    return jumlahClaimBaru
end

-- ==========================================
-- TRIGGER CEPAT SAAT ADA TRANSAKSI / NOTIFIKASI
-- ==========================================
local function jadwalkanPengecekanCepat()
    if not autoQuestEnabled or timerDebounceAktif or sedangCekQuest then
        return
    end
    if (tick() - waktuCekTerakhir) < 1.2 then
        return
    end

    timerDebounceAktif = true
    task.delay(0.8, function()
        timerDebounceAktif = false
        if autoQuestEnabled then
            cekDanClaimQuest(false)
        end
    end)
end

if NotifikasiRemote and NotifikasiRemote:IsA("RemoteEvent") then
    NotifikasiRemote.OnClientEvent:Connect(function(pesan)
        if not autoQuestEnabled then return end
        if typeof(pesan) == "string" then
            local pLower = pesan:lower()
            if pLower:find("quest") or pLower:find("misi") or pLower:find("selesai") or pLower:find("klaim") or pLower:find("claim") then
                jadwalkanPengecekanCepat()
            end
        end
    end)
end

local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
if leaderstats then
    for _, stat in ipairs(leaderstats:GetChildren()) do
        if stat:IsA("ValueBase") then
            stat.Changed:Connect(function()
                if autoQuestEnabled then
                    jadwalkanPengecekanCepat()
                end
            end)
        end
    end
end

-- ==========================================
-- LOOP SINKRONISASI REAL-TIME RINGAN (3 DETIK, 0% LAG)
-- ==========================================
task.spawn(function()
    while true do
        task.wait(3)
        if autoQuestEnabled and not sedangCekQuest and (tick() - waktuCekTerakhir) >= 2.8 then
            cekDanClaimQuest(false)
        end
    end
end)

-- ==========================================
-- UI TAB: QUEST
-- ==========================================
local QuestTab = API.CreateTab("Quest")

API.Section(QuestTab, "Auto Klaim Misi")
StatusQuestCard = API.Paragraph(
    QuestTab,
    "Quest Aktif: -  |  Total Diklaim: 0",
    "Status: Nonaktif"
)

API.Toggle(QuestTab, "Auto Klaim Misi Otomatis", false, function(val)
    autoQuestEnabled = val
    if val then
        API.Notify("Misi Otomatis Aktif", "Mengecek misi yang siap diambil & memantau secara real-time.", 2)
        task.spawn(function()
            cekDanClaimQuest(false)
        end)
    else
        API.Notify("Misi Otomatis Dinonaktif", "Auto klaim misi dimatikan.", 2)
        perbaruiStatusUI(
            "Quest Aktif: -  |  Total Diklaim: " .. tostring(totalBerhasilClaim),
            "Status: Nonaktif"
        )
    end
end)

API.Button(QuestTab, "Cek & Ambil Misi Sekarang (1x)", function()
    task.spawn(function()
        cekDanClaimQuest(true)
    end)
end)
