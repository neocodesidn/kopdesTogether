local API = ...

local GetQuestsRemote = API.Remotes.Quest:WaitForChild("GetQuests")
local ClaimQuestRemote = API.Remotes.Quest:WaitForChild("ClaimQuest")
local QuestRemotes = API.Remotes and API.Remotes.Quest
local QuestUpdatedEvent = QuestRemotes and QuestRemotes:FindFirstChild("QuestUpdated")

local autoClaimQuestEnabled = false
local sedangProsesQuest = false
local waktuCekQuestTerakhir = 0

local function apakahQuestSiapClaim(q)
    if typeof(q) ~= "table" or q.claimed == true then return false end
    if q.completed == true or q.done == true or q.canClaim == true or q.ready == true then
        return true
    end

    local target = (typeof(q.def) == "table" and tonumber(q.def.target)) or tonumber(q.target)
    local progres = tonumber(q.progress or q.current or q.count or q.value or q.amount)
    return (target and progres and progres >= target) or false
end

local function cekDanClaimQuests(isManual)
    if sedangProsesQuest then return end
    if not isManual and (os.clock() - waktuCekQuestTerakhir) < 2 then return end

    sedangProsesQuest = true
    waktuCekQuestTerakhir = os.clock()
    local berhasilClaim = 0

    pcall(function()
        local hasil = GetQuestsRemote:InvokeServer()
        if typeof(hasil) ~= "table" then return end

        local daftarQuest = hasil.quests or hasil
        if typeof(daftarQuest) ~= "table" then return end

        for _, q in pairs(daftarQuest) do
            if apakahQuestSiapClaim(q) and typeof(q.uid) == "string" then
                local okClaim, resClaim = pcall(function()
                    if ClaimQuestRemote:IsA("RemoteFunction") then
                        return ClaimQuestRemote:InvokeServer(q.uid)
                    else
                        ClaimQuestRemote:FireServer(q.uid)
                        return true
                    end
                end)

                if okClaim and (resClaim == nil or resClaim == true or (typeof(resClaim) == "table" and resClaim.ok ~= false)) then
                    berhasilClaim = berhasilClaim + 1
                end
                task.wait(0.3)
            end
        end
    end)

    if berhasilClaim > 0 then
        API.Notify("Misi Selesai Diambil!", "Mengambil hadiah dari " .. berhasilClaim .. " tugas selesai.", 4)
    elseif isManual then
        API.Notify("Info Quest", "Belum ada misi tambahan yang siap diambil.", 3)
    end

    sedangProsesQuest = false
end

if QuestUpdatedEvent and QuestUpdatedEvent:IsA("RemoteEvent") then
    QuestUpdatedEvent.OnClientEvent:Connect(function()
        if autoClaimQuestEnabled then
            task.spawn(cekDanClaimQuests, false)
        end
    end)
end

-- UI Tab Quest
local QuestTab = API.CreateTab("Quest")
API.Section(QuestTab, "Misi Otomatis")

API.Toggle(QuestTab, "Auto Klaim Misi yang Sudah Selesai", false, function(val)
    autoClaimQuestEnabled = val
    if val then task.spawn(cekDanClaimQuests, false) end
    API.Notify(
        val and "Misi Otomatis Aktif" or "Misi Otomatis Dimatikan",
        val and "Misi yang sudah selesai otomatis diambil." or "Mekanisme auto misi dimatikan.",
        3
    )
end)

API.Button(QuestTab, "Cek & Ambil Semua Misi Sekarang", function()
    task.spawn(cekDanClaimQuests, true)
end)

task.spawn(function()
    while true do
        if autoClaimQuestEnabled then
            cekDanClaimQuests(false)
        end
        task.wait(8)
    end
end)
