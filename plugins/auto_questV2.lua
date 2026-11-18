local API = ...

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = API.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local QuestRemotes = ReplicatedStorage:WaitForChild("QuestRemotes", 10)
local GetQuestsRemote = QuestRemotes and QuestRemotes:FindFirstChild("GetQuests")
local ClaimQuestRemote = QuestRemotes and QuestRemotes:FindFirstChild("ClaimQuest")

local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
local NotifikasiRemote = RemotesFolder and RemotesFolder:FindFirstChild("Notifikasi")

-- ==========================================
-- KONFIGURASI AUTO CLAIM QUEST (EVENT-DRIVEN)
-- ==========================================
local autoQuestEnabled = false
local sedangCekQuest = false
local timerDebounceAktif = false
local totalBerhasilClaim = 0

local StatusQuestCard

local function perbaruiStatusUI(teksJudul, teksSub)
    if StatusQuestCard then
        API.SetElementText(StatusQuestCard, teksJudul, teksSub)
    end
end

-- ==========================================
-- FUNGSI CEK & CLAIM QUEST (DIPANGGIL HANYA SAAT ADA TRIGGER)
-- ==========================================
local function cekDanClaimQuest(dariTombolManual)
    if sedangCekQuest then return 0 end
    if not GetQuestsRemote or not ClaimQuestRemote then
        perbaruiStatusUI("Error: QuestRemotes tidak ditemukan", "Pastikan remote tersedia di ReplicatedStorage.")
        return 0
    end

    sedangCekQuest = true
    local jumlahClaimBaru = 0
    local jumlahAktif = 0
    local jumlahSiapClaim = 0

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
                jumlahSiapClaim = jumlahSiapClaim + 1

                local okClaim, resClaim = pcall(function()
                    return ClaimQuestRemote:InvokeServer(q.uid)
                end)

                if okClaim and typeof(resClaim) == "table" and resClaim.ok == true then
                    jumlahClaimBaru = jumlahClaimBaru + 1
                    totalBerhasilClaim = totalBerhasilClaim + 1

                    local jenisHadiah = (q.def and q.def.reward and q.def.reward.kind) or "Hadiah"
                    local nominalHadiah = (q.def and q.def.reward and tostring(q.def.reward.amount)) or ""
                    API.Notify(
                        "Quest Diklaim!",
                        "Berhasil klaim " .. nominalHadiah .. " " .. jenisHadiah .. ".",
                        2
                    )
                    task.wait(0.15)
                end
            end
        end
    end

    local statusTeks = autoQuestEnabled
        and "Status: Event-Driven Aktif (0% CPU saat idle)"
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
-- DEBOUNCE TRIGGER (MENCEGAH SPAM SAAT BANYAK EVENT)
-- ==========================================
local function jadwalkanPengecekanQuest()
    if not autoQuestEnabled or timerDebounceAktif or sedangCekQuest then
        return
    end

    timerDebounceAktif = true
    task.delay(1.5, function()
        timerDebounceAktif = false
        if autoQuestEnabled then
            cekDanClaimQuest(false)
        end
    end)
end

-- ==========================================
-- LISTENER EVENT-DRIVEN (TANPA LOOPING)
-- ==========================================
-- 1. Trigger saat muncul teks "Claim" / "Klaim" / indikator selesai di GUI
PlayerGui.DescendantAdded:Connect(function(desc)
    if not autoQuestEnabled then return end
    if desc:IsA("TextLabel") or desc:IsA("TextButton") then
        local txt = desc.Text:lower()
        if txt:find("claim") or txt:find("klaim") or txt:find("selesai") or txt:find("complete") or txt:find("quest") then
            jadwalkanPengecekanQuest()
        end
    elseif desc.Name:lower():find("notif") or desc.Name:lower():find("badge") or desc.Name:lower():find("dot") or desc.Name:lower():find("quest") then
        jadwalkanPengecekanQuest()
    end
end)

-- 2. Trigger saat ada notifikasi dari server (misalnya quest selesai / progres tercapai)
if NotifikasiRemote and NotifikasiRemote:IsA("RemoteEvent") then
    NotifikasiRemote.OnClientEvent:Connect(function(pesan)
        if not autoQuestEnabled then return end
        if typeof(pesan) == "string" then
            local pLower = pesan:lower()
            if pLower:find("quest") or pLower:find("misi") or pLower:find("selesai") or pLower:find("klaim") or pLower:find("claim") then
                jadwalkanPengecekanQuest()
            end
        end
    end)
end

-- 3. Trigger saat uang / EXP player bertambah (indikator transaksi kasir / defeatThief / buyBox selesai)
local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
if leaderstats then
    for _, stat in ipairs(leaderstats:GetChildren()) do
        if stat:IsA("ValueBase") then
            stat.Changed:Connect(function()
                if autoQuestEnabled then
                    jadwalkanPengecekanQuest()
                end
            end)
        end
    end
end

-- ==========================================
-- UI TAB: QUEST
-- ==========================================
local QuestTab = API.CreateTab("Quest")

API.Section(QuestTab, "Auto Claim Quest (Event-Driven Anti-Lag)")
StatusQuestCard = API.Paragraph(
    QuestTab,
    "Quest Aktif: -  |  Total Diklaim: 0",
    "Status: Nonaktif (Hanya mengecek saat ada progres/notifikasi baru)"
)

API.Toggle(QuestTab, "Auto Claim Quest Otomatis", false, function(val)
    autoQuestEnabled = val
    if val then
        API.Notify("Auto Quest Aktif", "Mengecek quest siap klaim & memantau perubahan secara otomatis.", 2)
        task.spawn(function()
            cekDanClaimQuest(false)
        end)
    else
        API.Notify("Auto Quest Mati", "Auto claim quest dihentikan.", 2)
        perbaruiStatusUI(
            "Quest Aktif: -  |  Total Diklaim: " .. tostring(totalBerhasilClaim),
            "Status: Nonaktif"
        )
    end
end)

API.Button(QuestTab, "Cek & Claim Quest Sekarang (1x)", function()
    task.spawn(function()
        cekDanClaimQuest(true)
    end)
end)
