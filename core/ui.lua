-- core/ui.lua — Neo-Brutalism Responsive UI Engine (PC & Mobile)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")

local CustomUI = {}

-- ==========================================
-- TEMA NEO-BRUTALISM
-- ==========================================
local Theme = {
    BgMain       = Color3.fromRGB(246, 241, 230),
    BgSidebar    = Color3.fromRGB(255, 255, 255),
    BgCard       = Color3.fromRGB(255, 255, 255),
    BgCardHover  = Color3.fromRGB(255, 244, 189),
    BgInput      = Color3.fromRGB(255, 253, 247),
    Border       = Color3.fromRGB(17, 17, 17),
    BorderActive = Color3.fromRGB(17, 17, 17),
    Accent       = Color3.fromRGB(255, 210, 63),
    AccentSoft   = Color3.fromRGB(255, 240, 179),
    TextPrimary  = Color3.fromRGB(17, 17, 17),
    TextMuted    = Color3.fromRGB(91, 85, 96),
    Success      = Color3.fromRGB(6, 214, 160),
    OffTrack     = Color3.fromRGB(227, 222, 211),
    Ink          = Color3.fromRGB(17, 17, 17),
    Paper        = Color3.fromRGB(255, 255, 255),
    Pink         = Color3.fromRGB(255, 107, 157),
    Blue         = Color3.fromRGB(77, 150, 255),
    Green        = Color3.fromRGB(6, 214, 160),
    Orange       = Color3.fromRGB(255, 159, 28),
    Radius       = 2,
}

local Fonts = {
    Black  = Enum.Font.GothamBlack,
    Bold   = Enum.Font.GothamBold,
    Medium = Enum.Font.GothamMedium,
    Body   = Enum.Font.Gotham,
}

local SHADOW_OFFSET = 4
local BORDER_WIDTH = 2

-- ==========================================
-- IKON VEKTOR
-- ==========================================
local Icons = {
    Brand        = "rbxassetid://6031280882",
    Dashboard    = "rbxassetid://6026568198",
    Shop         = "rbxassetid://6034973115",
    Operasional  = "rbxassetid://6031094678",
    Musik        = "rbxassetid://6034328955",
    Bank         = "rbxassetid://6034684930",
    SmartPayroll = "rbxassetid://6034287594",
    SewaPekerja  = "rbxassetid://6031265976",
    Quest        = "rbxassetid://6031075938",
    Webhook      = "rbxassetid://6034509993",
    ChevronDown  = "rbxassetid://6034818372",
    Minimize     = "rbxassetid://6035067836",
    Bell         = "rbxassetid://6022668888",
}

-- Bersihkan teks heading: trim whitespace & collapse spasi ganda, biarkan casing asli agar rapi.
local function formatSectionTitle(value)
    local text = tostring(value)
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    text = text:gsub("%s+", " ")
    return text
end

local function humanizeText(value)
    local text = tostring(value)
    text = text:gsub("_", " ")
    text = text:gsub("(%l)(%u)", "%1 %2")
    text = text:gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

-- Versi multi-baris: rapikan tiap baris TANPA menggabungkan baris.
-- Dipakai untuk konten Paragraph agar "Cara Pemakaian" tetap per baris & tidak jadi satu blok padat.
local function humanizeMultiline(value)
    local text = tostring(value or "")
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}
    local lastBlank = true -- anggap blank di awal agar baris kosong pertama bukan separator
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local cleaned = humanizeText(line)
        if cleaned ~= "" then
            table.insert(lines, cleaned)
            lastBlank = false
        elseif not lastBlank then
            table.insert(lines, "")
            lastBlank = true
        end
    end
    while lines[#lines] == "" do
        table.remove(lines)
    end
    return table.concat(lines, "\n")
end

local function resolveTabIcon(tabName, customIconId)
    if typeof(customIconId) == "number" and customIconId > 0 and customIconId ~= 4483362458 then
        return "rbxassetid://" .. tostring(customIconId)
    end
    local lower = tostring(tabName):lower()
    if lower:find("dash") or lower:find("home") then return Icons.Dashboard end
    if lower:find("shop") or lower:find("restok") or lower:find("kardus") or lower:find("kulkas") or lower:find("sayuran") or lower:find("makanan") or lower:find("belanja") or lower:find("beli") or lower:find("restock") then return Icons.Shop end
    if lower:find("operasional") or lower:find("ops") or lower:find("kasir") or lower:find("anti") or lower:find("pukul") or lower:find("store") then return Icons.Operasional end
    if lower:find("musik") or lower:find("sound") or lower:find("audio") or lower:find("speaker") then return Icons.Musik end
    if lower:find("smart") or lower:find("payroll") or lower:find("profit") or lower:find("gaji") then return Icons.SmartPayroll end
    if lower:find("bank") or lower:find("transfer") or lower:find("deposit") or lower:find("dana") or lower:find("kredit") then return Icons.Bank end
    if lower:find("sewa") or lower:find("pekerja") or lower:find("staff") or lower:find("kontrak") then return Icons.SewaPekerja end
    if lower:find("quest") or lower:find("task") or lower:find("questv2") or lower:find("sidequest") then return Icons.Quest end
    if lower:find("webhook") or lower:find("discord") or lower:find("notif") or lower:find("log") or lower:find("integrasi") then return Icons.Webhook end
    if lower:find("boost") or lower:find("fps") or lower:find("performance") or lower:find("perf") then return Icons.Brand end
    return Icons.Brand
end

-- ==========================================
-- HELPER KOMPONEN, SHADOW & ANIMASI
-- ==========================================
local function tween(obj, props, dur)
    TweenService:Create(
        obj,
        TweenInfo.new(dur or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        props
    ):Play()
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or Theme.Radius)
    c.Parent = parent
    return c
end

local function addStroke(parent, thickness, color)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness or BORDER_WIDTH
    s.Color = color or Theme.Ink
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.LineJoinMode = Enum.LineJoinMode.Miter
    s.Parent = parent
    return s
end

local function addPadding(parent, top, right, bottom, left)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, top or 8)
    p.PaddingRight = UDim.new(0, right or 8)
    p.PaddingBottom = UDim.new(0, bottom or 8)
    p.PaddingLeft = UDim.new(0, left or 8)
    p.Parent = parent
    return p
end

local function getTopSafeInset()
    local ok, topLeft = pcall(function()
        return GuiService:GetGuiInset()
    end)
    local insetY = (ok and typeof(topLeft) == "Vector2") and topLeft.Y or 36
    return math.max(insetY + 8, 44)
end

local function makeDraggable(dragHandle, targetFrame, onMove)
    local dragging = false
    local dragStart = nil
    local startAbs = nil

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startAbs = targetFrame.AbsolutePosition
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1024, 768)
        local size = targetFrame.AbsoluteSize
        local maxX = math.max(4, vp.X - size.X - 4)
        local maxY = math.max(4, vp.Y - size.Y - 4)
        local nx = math.clamp(startAbs.X + delta.X, 4, maxX)
        local ny = math.clamp(startAbs.Y + delta.Y, 4, maxY)

        targetFrame.Position = UDim2.fromOffset(math.floor(nx), math.floor(ny))
        if onMove then
            onMove(targetFrame.Position)
        end
    end)
end

-- Kartu neo-brutalism: border tebal + hard shadow hitam.
local function newShadowed(parent, className, height, bgColor, autoHeight, baseZ)
    local holder = Instance.new("Frame")
    holder.Name = "BrutalHolder"
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.ClipsDescendants = false
    holder.Size = UDim2.new(1, 0, 0, (height or 0) + SHADOW_OFFSET)
    holder.Parent = parent

    local shadow = Instance.new("Frame")
    shadow.Name = "HardShadow"
    shadow.BackgroundColor3 = Theme.Ink
    shadow.BorderSizePixel = 0
    shadow.Size = UDim2.new(1, -SHADOW_OFFSET, 0, height or 0)
    shadow.Position = UDim2.new(0, SHADOW_OFFSET, 0, SHADOW_OFFSET)
    shadow.ZIndex = baseZ or 1
    shadow.Parent = holder
    addCorner(shadow, Theme.Radius)

    local card = Instance.new(className or "Frame")
    card.Name = "Card"
    card.BackgroundColor3 = bgColor or Theme.Paper
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, -SHADOW_OFFSET, 0, height or 0)
    card.Position = UDim2.new(0, 0, 0, 0)
    card.ZIndex = (baseZ or 1) + 1
    card.ClipsDescendants = false
    card.Parent = holder

    if card:IsA("TextButton") then
        card.AutoButtonColor = false
        card.Text = ""
    end

    addCorner(card, Theme.Radius)
    addStroke(card, BORDER_WIDTH, Theme.Ink)

    local function syncSize(targetHeight)
        local h = targetHeight or card.AbsoluteSize.Y
        h = math.max(h or 0, 1)
        if not autoHeight then
            card.Size = UDim2.new(1, -SHADOW_OFFSET, 0, h)
        end
        shadow.Size = UDim2.new(1, -SHADOW_OFFSET, 0, h)
        holder.Size = UDim2.new(1, 0, 0, h + SHADOW_OFFSET)
    end

    if autoHeight then
        card.AutomaticSize = Enum.AutomaticSize.Y
        card:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            syncSize(card.AbsoluteSize.Y)
        end)
        task.defer(function()
            syncSize(card.AbsoluteSize.Y)
        end)
    end

    return holder, card, shadow, syncSize
end

-- ==========================================
-- INISIALISASI ENGINE KE KOPDESAPI
-- ==========================================
function CustomUI.AttachToAPI(KopdesAPI, config)
    config = config or {}

    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local guiParent = nil

    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then
            guiParent = hui
        end
    end
    if not guiParent then
        guiParent = PlayerGui
    end

    local function destroyOldGui(parent)
        if not parent then return end
        for _, guiName in ipairs({ "KopdesNeoBrutalSuite", "KopdesDarkBlueSuite" }) do
            local old = parent:FindFirstChild(guiName)
            if old then old:Destroy() end
        end
    end
    pcall(destroyOldGui, guiParent)
    if guiParent ~= PlayerGui then pcall(destroyOldGui, PlayerGui) end
    if guiParent ~= CoreGui then pcall(destroyOldGui, CoreGui) end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "KopdesNeoBrutalSuite"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.DisplayOrder = 999
    local okParent = pcall(function()
        ScreenGui.Parent = guiParent
    end)
    if not okParent then
        ScreenGui.Parent = PlayerGui
    end

    -- ==========================================
    -- WINDOW UTAMA + HARD SHADOW
    -- ==========================================
    local WindowShadow = Instance.new("Frame")
    WindowShadow.Name = "WindowShadow"
    WindowShadow.BackgroundColor3 = Theme.Ink
    WindowShadow.BorderSizePixel = 0
    WindowShadow.ZIndex = 9
    WindowShadow.Parent = ScreenGui
    addCorner(WindowShadow, Theme.Radius)

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainWindow"
    MainFrame.BackgroundColor3 = Theme.BgMain
    MainFrame.ClipsDescendants = true
    MainFrame.Size = UDim2.new(0, 620, 0, 460)
    MainFrame.Position = UDim2.new(0.5, -310, 0.5, -230)
    MainFrame.ZIndex = 10
    MainFrame.Parent = ScreenGui
    addCorner(MainFrame, Theme.Radius)
    addStroke(MainFrame, 3, Theme.Ink)

    -- ==========================================
    -- TOPBAR NEON YELLOW
    -- ==========================================
    local Topbar = Instance.new("Frame")
    Topbar.Name = "Topbar"
    Topbar.Size = UDim2.new(1, 0, 0, 54)
    Topbar.BackgroundColor3 = Theme.Accent
    Topbar.BorderSizePixel = 0
    Topbar.ZIndex = 3
    Topbar.Parent = MainFrame
    addCorner(Topbar, Theme.Radius)

    local TopLine = Instance.new("Frame")
    TopLine.Name = "TopBorder"
    TopLine.Size = UDim2.new(1, 0, 0, 3)
    TopLine.Position = UDim2.new(0, 0, 1, -3)
    TopLine.BackgroundColor3 = Theme.Ink
    TopLine.BorderSizePixel = 0
    TopLine.ZIndex = 4
    TopLine.Parent = Topbar

    local BrandBadge = Instance.new("Frame")
    BrandBadge.Name = "BrandBadge"
    BrandBadge.Size = UDim2.new(0, 32, 0, 32)
    BrandBadge.Position = UDim2.new(0, 14, 0.5, -16)
    BrandBadge.BackgroundColor3 = Theme.Paper
    BrandBadge.ZIndex = 5
    BrandBadge.Parent = Topbar
    addCorner(BrandBadge, Theme.Radius)
    addStroke(BrandBadge, BORDER_WIDTH, Theme.Ink)

    local BrandIcon = Instance.new("ImageLabel")
    BrandIcon.Size = UDim2.new(0, 17, 0, 17)
    BrandIcon.Position = UDim2.new(0.5, -8.5, 0.5, -8.5)
    BrandIcon.BackgroundTransparency = 1
    BrandIcon.Image = Icons.Brand
    BrandIcon.ImageColor3 = Theme.Ink
    BrandIcon.ZIndex = 6
    BrandIcon.Parent = BrandBadge

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -112, 0, 18)
    TitleLabel.Position = UDim2.new(0, 56, 0, 8)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = tostring(config.Title or "Kopdes Together")
    TitleLabel.TextColor3 = Theme.Ink
    TitleLabel.Font = Fonts.Black
    TitleLabel.TextSize = 14
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    TitleLabel.ZIndex = 5
    TitleLabel.Parent = Topbar

    local SubLabel = Instance.new("TextLabel")
    SubLabel.Size = UDim2.new(1, -112, 0, 14)
    SubLabel.Position = UDim2.new(0, 56, 0, 28)
    SubLabel.BackgroundTransparency = 1
    SubLabel.Text = tostring(config.Subtitle or "Cheese Dev Suite")
    SubLabel.TextColor3 = Theme.TextMuted
    SubLabel.Font = Fonts.Medium
    SubLabel.TextSize = 9
    SubLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubLabel.TextTruncate = Enum.TextTruncate.AtEnd
    SubLabel.ZIndex = 5
    SubLabel.Parent = Topbar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Name = "Minimize"
    MinBtn.Size = UDim2.new(0, 34, 0, 34)
    MinBtn.Position = UDim2.new(1, -48, 0.5, -17)
    MinBtn.BackgroundColor3 = Theme.Pink
    MinBtn.Text = ""
    MinBtn.AutoButtonColor = false
    MinBtn.ZIndex = 5
    MinBtn.Parent = Topbar
    addCorner(MinBtn, Theme.Radius)
    addStroke(MinBtn, BORDER_WIDTH, Theme.Ink)

    local MinIcon = Instance.new("ImageLabel")
    MinIcon.Size = UDim2.new(0, 15, 0, 15)
    MinIcon.Position = UDim2.new(0.5, -7.5, 0.5, -7.5)
    MinIcon.BackgroundTransparency = 1
    MinIcon.Image = Icons.Minimize
    MinIcon.ImageColor3 = Theme.Ink
    MinIcon.ZIndex = 6
    MinIcon.Parent = MinBtn

    -- ==========================================
    -- MOBILE TAB BAR (HORIZONTAL)
    -- ==========================================
    local MobileBar = Instance.new("ScrollingFrame")
    MobileBar.Name = "MobileTabs"
    MobileBar.BackgroundColor3 = Theme.Paper
    MobileBar.BorderSizePixel = 0
    MobileBar.ScrollBarThickness = 0
    MobileBar.ScrollingDirection = Enum.ScrollingDirection.X
    MobileBar.AutomaticCanvasSize = Enum.AutomaticSize.X
    MobileBar.CanvasSize = UDim2.new(0, 0, 0, 0)
    MobileBar.Visible = false
    MobileBar.ZIndex = 3
    MobileBar.Parent = MainFrame
    addPadding(MobileBar, 6, 8, 6, 8)

    local MobileLayout = Instance.new("UIListLayout")
    MobileLayout.FillDirection = Enum.FillDirection.Horizontal
    MobileLayout.Padding = UDim.new(0, 8)
    MobileLayout.SortOrder = Enum.SortOrder.LayoutOrder
    MobileLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    MobileLayout.Parent = MobileBar

    local MobileLine = Instance.new("Frame")
    MobileLine.Name = "MobileBottomBorder"
    MobileLine.BackgroundColor3 = Theme.Ink
    MobileLine.BorderSizePixel = 0
    MobileLine.Visible = false
    MobileLine.ZIndex = 4
    MobileLine.Parent = MainFrame

    -- ==========================================
    -- SIDEBAR (PC)
    -- ==========================================
    local Sidebar = Instance.new("ScrollingFrame")
    Sidebar.Name = "Sidebar"
    Sidebar.BackgroundColor3 = Theme.BgSidebar
    Sidebar.BorderSizePixel = 0
    Sidebar.ScrollBarThickness = 3
    Sidebar.ScrollBarImageColor3 = Theme.Ink
    Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    Sidebar.ZIndex = 2
    Sidebar.Parent = MainFrame
    addPadding(Sidebar, 10, 8, 10, 8)

    local SideLayout = Instance.new("UIListLayout")
    SideLayout.Padding = UDim.new(0, 8)
    SideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SideLayout.Parent = Sidebar

    local SideDivider = Instance.new("Frame")
    SideDivider.Name = "SidebarBorder"
    SideDivider.BackgroundColor3 = Theme.Ink
    SideDivider.BorderSizePixel = 0
    SideDivider.ZIndex = 3
    SideDivider.Parent = MainFrame

    local ContentHolder = Instance.new("Frame")
    ContentHolder.Name = "ContentHolder"
    ContentHolder.BackgroundTransparency = 1
    ContentHolder.ZIndex = 2
    ContentHolder.Parent = MainFrame

    -- ==========================================
    -- FLOATING RESTORE BUTTON
    -- ==========================================
    local FloatHolder = Instance.new("Frame")
    FloatHolder.Name = "FloatingRestore"
    FloatHolder.Size = UDim2.new(0, 150, 0, 46)
    FloatHolder.Position = UDim2.new(0, 16, 0, 64)
    FloatHolder.BackgroundTransparency = 1
    FloatHolder.Visible = false
    FloatHolder.ZIndex = 20
    FloatHolder.Parent = ScreenGui

    local FloatShadow = Instance.new("Frame")
    FloatShadow.Size = UDim2.new(0, 142, 0, 42)
    FloatShadow.Position = UDim2.new(0, SHADOW_OFFSET, 0, SHADOW_OFFSET)
    FloatShadow.BackgroundColor3 = Theme.Ink
    FloatShadow.BorderSizePixel = 0
    FloatShadow.ZIndex = 21
    FloatShadow.Parent = FloatHolder
    addCorner(FloatShadow, Theme.Radius)

    local FloatBtn = Instance.new("TextButton")
    FloatBtn.Size = UDim2.new(0, 142, 0, 42)
    FloatBtn.BackgroundColor3 = Theme.Accent
    FloatBtn.Text = ""
    FloatBtn.AutoButtonColor = false
    FloatBtn.ZIndex = 22
    FloatBtn.Parent = FloatHolder
    addCorner(FloatBtn, Theme.Radius)
    addStroke(FloatBtn, 3, Theme.Ink)

    local FloatBadge = Instance.new("Frame")
    FloatBadge.Size = UDim2.new(0, 24, 0, 24)
    FloatBadge.Position = UDim2.new(0, 8, 0.5, -12)
    FloatBadge.BackgroundColor3 = Theme.Pink
    FloatBadge.ZIndex = 23
    FloatBadge.Parent = FloatBtn
    addCorner(FloatBadge, Theme.Radius)
    addStroke(FloatBadge, BORDER_WIDTH, Theme.Ink)

    local FloatIcon = Instance.new("ImageLabel")
    FloatIcon.Size = UDim2.new(0, 14, 0, 14)
    FloatIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
    FloatIcon.BackgroundTransparency = 1
    FloatIcon.Image = Icons.Brand
    FloatIcon.ImageColor3 = Theme.Ink
    FloatIcon.ZIndex = 24
    FloatIcon.Parent = FloatBadge

    local FloatText = Instance.new("TextLabel")
    FloatText.Size = UDim2.new(1, -42, 1, 0)
    FloatText.Position = UDim2.new(0, 38, 0, 0)
    FloatText.BackgroundTransparency = 1
    FloatText.Text = "KOPDES UI"
    FloatText.TextColor3 = Theme.Ink
    FloatText.Font = Fonts.Black
    FloatText.TextSize = 11
    FloatText.TextXAlignment = Enum.TextXAlignment.Left
    FloatText.ZIndex = 23
    FloatText.Parent = FloatBtn

    -- ==========================================
    -- NOTIFIKASI TOAST
    -- ==========================================
    local NotifHolder = Instance.new("Frame")
    NotifHolder.Name = "NotifHolder"
    NotifHolder.BackgroundTransparency = 1
    NotifHolder.Size = UDim2.new(0, 300, 1, -20)
    NotifHolder.Position = UDim2.new(1, -312, 0, 10)
    NotifHolder.ZIndex = 100
    NotifHolder.Parent = ScreenGui

    local NotifLayout = Instance.new("UIListLayout")
    NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    NotifLayout.Padding = UDim.new(0, 10)
    NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
    NotifLayout.Parent = NotifHolder

    local notifCounter = 0
    local tabs = {}
    local tabCounter = 0
    local layoutCounters = setmetatable({}, { __mode = "k" })
    local isMobileLayout = false
    local firstTab = true

    local function nextLayoutOrder(parent)
        layoutCounters[parent] = (layoutCounters[parent] or 0) + 1
        return layoutCounters[parent]
    end

    -- ==========================================
    -- TAB VISUAL & RESPONSIVE LAYOUT
    -- ==========================================
    local function placeTab(item, mobile)
        item.btn.LayoutOrder = item.order
        if mobile then
            item.btn.Parent = MobileBar
            item.btn.Size = UDim2.new(0, math.clamp(56 + #tostring(item.name) * 7, 122, 200), 0, 34)
        else
            item.btn.Parent = Sidebar
            item.btn.Size = UDim2.new(1, 0, 0, 40)
        end
        item.bar.Visible = item.active == true and not mobile
    end

    local function refreshTabVisuals()
        for _, item in ipairs(tabs) do
            local active = item.active == true
            item.page.Visible = active
            item.bar.Visible = active and not isMobileLayout
            item.label.Font = active and Fonts.Black or Fonts.Medium

            tween(item.btn, {
                BackgroundColor3 = active and Theme.Accent or Theme.Paper,
                BackgroundTransparency = 0,
            }, 0.12)
            tween(item.stroke, { Transparency = 0 }, 0.12)
            tween(item.icon, {
                ImageColor3 = active and Theme.Ink or Theme.TextMuted,
            }, 0.12)
            tween(item.label, {
                TextColor3 = active and Theme.Ink or Theme.TextPrimary,
            }, 0.12)
        end
    end

    local function applyResponsiveLayout()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1024, 768)
        isMobileLayout = vp.X < 760

        local topbarH = 54
        local mobileBarH = 48
        local topSafe = getTopSafeInset()
        local availH = math.max(math.floor(vp.Y - topSafe), 240)
        local winW, winH, sideW

        if isMobileLayout then
            winW = math.clamp(math.floor(vp.X - 20), 320, 540)
            winH = math.clamp(availH - 20, 320, 780)
            sideW = 0
        else
            winW = math.clamp(math.floor(vp.X - 160), 560, 720)
            winH = math.clamp(availH - 100, 380, 560)
            sideW = 176
        end

        winW = math.min(winW, math.max(320, vp.X - 12))
        winH = math.min(winH, math.max(240, availH - 8))

        local posX = math.floor((vp.X - winW) / 2)
        local posY = topSafe + math.max(0, math.floor((availH - winH) / 2))

        MainFrame.Size = UDim2.new(0, winW, 0, winH)
        MainFrame.Position = UDim2.new(0, posX, 0, posY)
        WindowShadow.Size = MainFrame.Size
        WindowShadow.Position = UDim2.new(0, posX + 8, 0, posY + 8)
        WindowShadow.Visible = MainFrame.Visible

        Topbar.Size = UDim2.new(1, 0, 0, topbarH)

        Sidebar.Visible = not isMobileLayout
        SideDivider.Visible = not isMobileLayout
        MobileBar.Visible = isMobileLayout
        MobileLine.Visible = isMobileLayout

        Sidebar.Position = UDim2.new(0, 0, 0, topbarH)
        Sidebar.Size = UDim2.new(0, sideW, 1, -topbarH)
        SideDivider.Position = UDim2.new(0, sideW, 0, topbarH)
        SideDivider.Size = UDim2.new(0, 3, 1, -topbarH)

        MobileBar.Position = UDim2.new(0, 0, 0, topbarH)
        MobileBar.Size = UDim2.new(1, 0, 0, mobileBarH)
        MobileLine.Position = UDim2.new(0, 0, 0, topbarH + mobileBarH - 3)
        MobileLine.Size = UDim2.new(1, 0, 0, 3)

        if isMobileLayout then
            ContentHolder.Position = UDim2.new(0, 0, 0, topbarH + mobileBarH)
            ContentHolder.Size = UDim2.new(1, 0, 1, -(topbarH + mobileBarH))
        else
            ContentHolder.Position = UDim2.new(0, sideW + 3, 0, topbarH)
            ContentHolder.Size = UDim2.new(1, -(sideW + 3), 1, -topbarH)
        end

        local notifW = isMobileLayout and math.clamp(math.floor(vp.X - 32), 240, 340) or 300
        NotifHolder.Size = UDim2.new(0, notifW, 1, -20)
        NotifHolder.Position = UDim2.new(1, -(notifW + 12), 0, 10)

        for _, item in ipairs(tabs) do
            placeTab(item, isMobileLayout)
        end
        refreshTabVisuals()

        SubLabel.Visible = not (isMobileLayout and winW < 390)
        TitleLabel.TextSize = isMobileLayout and 13 or 14
    end

    applyResponsiveLayout()
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
    end

    -- ==========================================
    -- WINDOW CONTROLS
    -- ==========================================
    MinBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        WindowShadow.Visible = false
        FloatHolder.Visible = true
    end)

    FloatBtn.MouseButton1Click:Connect(function()
        FloatHolder.Visible = false
        MainFrame.Visible = true
        WindowShadow.Visible = true
    end)

    makeDraggable(FloatBtn, FloatHolder)
    makeDraggable(Topbar, MainFrame, function(pos)
        WindowShadow.Position = UDim2.new(pos.X.Scale, pos.X.Offset + 8, pos.Y.Scale, pos.Y.Offset + 8)
    end)

    -- ==========================================
    -- NOTIFIKASI
    -- ==========================================
    function KopdesAPI.Notify(title, content, duration)
        task.spawn(function()
            notifCounter = notifCounter + 1
            local holder, card = newShadowed(NotifHolder, "Frame", 56, Theme.Paper, true, 100)
            holder.LayoutOrder = notifCounter
            addPadding(card, 10, 12, 10, 12)

            local badge = Instance.new("Frame")
            badge.Size = UDim2.new(0, 22, 0, 22)
            badge.Position = UDim2.new(0, 0, 0, 0)
            badge.BackgroundColor3 = Theme.Accent
            badge.Parent = card
            addCorner(badge, Theme.Radius)
            addStroke(badge, BORDER_WIDTH, Theme.Ink)

            local icon = Instance.new("ImageLabel")
            icon.Size = UDim2.new(0, 13, 0, 13)
            icon.Position = UDim2.new(0.5, -6.5, 0.5, -6.5)
            icon.BackgroundTransparency = 1
            icon.Image = Icons.Bell
            icon.ImageColor3 = Theme.Ink
            icon.Parent = badge

            local tLbl = Instance.new("TextLabel")
            tLbl.Size = UDim2.new(1, -30, 0, 16)
            tLbl.Position = UDim2.new(0, 30, 0, 0)
            tLbl.BackgroundTransparency = 1
            tLbl.Text = humanizeText(title)
            tLbl.TextColor3 = Theme.Ink
            tLbl.Font = Fonts.Black
            tLbl.TextSize = 12
            tLbl.TextXAlignment = Enum.TextXAlignment.Left
            tLbl.TextTruncate = Enum.TextTruncate.AtEnd
            tLbl.Parent = card

            local cLbl = Instance.new("TextLabel")
            cLbl.Size = UDim2.new(1, -30, 0, 0)
            cLbl.Position = UDim2.new(0, 30, 0, 18)
            cLbl.AutomaticSize = Enum.AutomaticSize.Y
            cLbl.BackgroundTransparency = 1
            cLbl.Text = humanizeMultiline(content)
            cLbl.TextColor3 = Theme.TextMuted
            cLbl.Font = Fonts.Medium
            cLbl.TextSize = 11
            cLbl.TextWrapped = true
            cLbl.TextXAlignment = Enum.TextXAlignment.Left
            cLbl.Parent = card

            task.wait(duration or 3)
            if holder.Parent then
                holder:Destroy()
            end
        end)
    end

    -- ==========================================
    -- TAB CREATION
    -- ==========================================
    function KopdesAPI.CreateTab(name, iconId)
        local isInitial = firstTab
        firstTab = false
        tabCounter = tabCounter + 1

        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = "TabButton"
        tabBtn.Size = UDim2.new(1, 0, 0, 40)
        tabBtn.BackgroundColor3 = isInitial and Theme.Accent or Theme.Paper
        tabBtn.BackgroundTransparency = 0
        tabBtn.Text = ""
        tabBtn.AutoButtonColor = false
        tabBtn.ClipsDescendants = true
        tabBtn.ZIndex = 5
        tabBtn.Parent = Sidebar
        addCorner(tabBtn, Theme.Radius)
        local tabStroke = addStroke(tabBtn, BORDER_WIDTH, Theme.Ink)
        tabStroke.Transparency = 0

        local activeBar = Instance.new("Frame")
        activeBar.Size = UDim2.new(0, 4, 0, 18)
        activeBar.Position = UDim2.new(0, 0, 0.5, -9)
        activeBar.BackgroundColor3 = Theme.Ink
        activeBar.BorderSizePixel = 0
        activeBar.Visible = isInitial
        activeBar.ZIndex = 6
        activeBar.Parent = tabBtn
        addCorner(activeBar, 1)

        local tabIcon = Instance.new("ImageLabel")
        tabIcon.Size = UDim2.new(0, 15, 0, 15)
        tabIcon.Position = UDim2.new(0, 12, 0.5, -7.5)
        tabIcon.BackgroundTransparency = 1
        tabIcon.Image = resolveTabIcon(name, iconId)
        tabIcon.ImageColor3 = isInitial and Theme.Ink or Theme.TextMuted
        tabIcon.ZIndex = 6
        tabIcon.Parent = tabBtn

        local tabText = Instance.new("TextLabel")
        tabText.Size = UDim2.new(1, -40, 1, 0)
        tabText.Position = UDim2.new(0, 36, 0, 0)
        tabText.BackgroundTransparency = 1
        tabText.Text = tostring(name)
        tabText.TextColor3 = isInitial and Theme.Ink or Theme.TextPrimary
        tabText.Font = isInitial and Fonts.Black or Fonts.Medium
        tabText.TextSize = 10
        tabText.TextXAlignment = Enum.TextXAlignment.Left
        tabText.TextTruncate = Enum.TextTruncate.AtEnd
        tabText.ZIndex = 6
        tabText.Parent = tabBtn

        local page = Instance.new("ScrollingFrame")
        page.Name = "Page"
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = Theme.Ink
        page.ScrollingDirection = Enum.ScrollingDirection.Y
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.Visible = isInitial
        page.ZIndex = 2
        page.Parent = ContentHolder
        addPadding(page, 12, 16, 22, 12)

        local pageLayout = Instance.new("UIListLayout")
        pageLayout.Padding = UDim.new(0, 10)
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Parent = page

        local item = {
            btn = tabBtn,
            bar = activeBar,
            icon = tabIcon,
            label = tabText,
            stroke = tabStroke,
            page = page,
            name = tostring(name),
            order = tabCounter,
            active = isInitial,
        }
        table.insert(tabs, item)

        tabBtn.MouseButton1Click:Connect(function()
            for _, other in ipairs(tabs) do
                other.active = (other == item)
            end
            refreshTabVisuals()
        end)

        placeTab(item, isMobileLayout)
        refreshTabVisuals()
        return page
    end

    -- ==========================================
    -- SECTION
    -- ==========================================
    function KopdesAPI.Section(tab, title)
        local row = Instance.new("Frame")
        row.Name = "Section"
        row.Size = UDim2.new(1, 0, 0, 24)
        -- Tumbuh kalau judul membungkus ke 2 baris; spacer transparan menjaga minimal 24px.
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.BackgroundTransparency = 1
        row.LayoutOrder = nextLayoutOrder(tab)
        row.Parent = tab

        local minSpacer = Instance.new("Frame")
        minSpacer.Name = "MinHeight"
        minSpacer.Size = UDim2.new(0, 0, 0, 24)
        minSpacer.BackgroundTransparency = 1
        minSpacer.BorderSizePixel = 0
        minSpacer.Parent = row

        local block = Instance.new("Frame")
        block.Size = UDim2.new(0, 6, 0, 16)
        block.Position = UDim2.new(0, 0, 0, 4)
        block.BackgroundColor3 = Theme.Blue
        block.BorderSizePixel = 0
        block.Parent = row
        addCorner(block, 1)
        addStroke(block, BORDER_WIDTH, Theme.Ink)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -14, 0, 0)
        lbl.AutomaticSize = Enum.AutomaticSize.Y
        lbl.Position = UDim2.new(0, 14, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = formatSectionTitle(title)
        lbl.TextColor3 = Theme.Ink
        lbl.Font = Fonts.Black
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextYAlignment = Enum.TextYAlignment.Top
        -- Bungkus teks, jangan dipotong: judul section memuat hint pakai
        -- (mis. "Setor Saldo ke Toko (Konfirmasi 2x Klik)").
        lbl.TextWrapped = true
        lbl.Parent = row
        return lbl
    end

    -- ==========================================
    -- PARAGRAPH / STATUS CARD
    -- ==========================================
    function KopdesAPI.Paragraph(tab, title, content)
        local holder, card = newShadowed(tab, "Frame", 0, Theme.Paper, true, 1)
        holder.LayoutOrder = nextLayoutOrder(tab)
        addPadding(card, 10, 12, 10, 12)

        local marker = Instance.new("Frame")
        marker.Size = UDim2.new(0, 10, 0, 10)
        marker.Position = UDim2.new(0, 0, 0, 2)
        marker.BackgroundColor3 = Theme.Blue
        marker.BorderSizePixel = 0
        marker.Parent = card
        addCorner(marker, 1)
        addStroke(marker, BORDER_WIDTH, Theme.Ink)

        -- Kolom teks: judul & isi ditata vertikal lewat UIListLayout.
        -- Keduanya AutomaticSize.Y + TextWrapped, jadi panjang berapa pun tidak akan terpotong.
        local textCol = Instance.new("Frame")
        textCol.Name = "TextColumn"
        textCol.Size = UDim2.new(1, -18, 0, 0)
        textCol.Position = UDim2.new(0, 18, 0, 0)
        textCol.AutomaticSize = Enum.AutomaticSize.Y
        textCol.BackgroundTransparency = 1
        textCol.BorderSizePixel = 0
        textCol.Parent = card

        local textFlow = Instance.new("UIListLayout")
        textFlow.Name = "TextFlow"
        textFlow.FillDirection = Enum.FillDirection.Vertical
        textFlow.SortOrder = Enum.SortOrder.LayoutOrder
        textFlow.Padding = UDim.new(0, 4)
        textFlow.Parent = textCol

        local tLbl = Instance.new("TextLabel")
        tLbl.Name = "Title"
        tLbl.Size = UDim2.new(1, 0, 0, 0)
        tLbl.AutomaticSize = Enum.AutomaticSize.Y
        tLbl.LayoutOrder = 1
        tLbl.BackgroundTransparency = 1
        tLbl.Text = humanizeText(title)
        tLbl.TextColor3 = Theme.Ink
        tLbl.Font = Fonts.Black
        tLbl.TextSize = 12
        tLbl.TextWrapped = true
        tLbl.TextXAlignment = Enum.TextXAlignment.Left
        tLbl.TextYAlignment = Enum.TextYAlignment.Top
        tLbl.Parent = textCol

        local cLbl = Instance.new("TextLabel")
        cLbl.Name = "Content"
        cLbl.Size = UDim2.new(1, 0, 0, 0)
        cLbl.AutomaticSize = Enum.AutomaticSize.Y
        cLbl.LayoutOrder = 2
        cLbl.BackgroundTransparency = 1
        cLbl.Text = humanizeMultiline(content)
        cLbl.TextColor3 = Theme.TextMuted
        cLbl.Font = Fonts.Medium
        cLbl.TextSize = 11
        cLbl.TextWrapped = true
        cLbl.TextXAlignment = Enum.TextXAlignment.Left
        cLbl.TextYAlignment = Enum.TextYAlignment.Top
        cLbl.Parent = textCol

        return {
            _type = "Paragraph",
            Set = function(_, data)
                if typeof(data) == "table" then
                    if data.Title or data.title then tLbl.Text = humanizeText(tostring(data.Title or data.title)) end
                    if data.Content or data.content then cLbl.Text = humanizeMultiline(tostring(data.Content or data.content)) end
                end
            end,
        }
    end

    -- ==========================================
    -- BUTTON (PRESSABLE HARD SHADOW)
    -- ==========================================
    function KopdesAPI.Button(tab, name, callback)
        local holder, btn = newShadowed(tab, "TextButton", 42, Theme.Accent, false, 1)
        holder.LayoutOrder = nextLayoutOrder(tab)

        btn.Text = tostring(name)
        btn.TextColor3 = Theme.Ink
        btn.Font = Fonts.Black
        btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Center
        btn.TextYAlignment = Enum.TextYAlignment.Center
        -- Label tombol memuat langkah pakai (mis. "1. Teleport ke Speaker & Aktivasi (Stay)").
        -- Tinggi 42px muat 2 baris, jadi bungkus alih-alih potong dengan "…".
        btn.TextWrapped = true
        btn.AutoButtonColor = false
        addPadding(btn, 0, 12, 0, 12)

        local function press()
            tween(btn, { Position = UDim2.new(0, 2, 0, 2) }, 0.05)
        end
        local function release()
            tween(btn, { Position = UDim2.new(0, 0, 0, 0) }, 0.08)
        end

        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                press()
            end
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                release()
            end
        end)
        btn.MouseLeave:Connect(release)
        btn.MouseButton1Click:Connect(function()
            if callback then task.spawn(callback) end
        end)

        return {
            _type = "Button",
            Set = function(_, newText)
                btn.Text = tostring(newText)
            end,
        }
    end

    -- ==========================================
    -- TOGGLE NEO-BRUTALISM
    -- ==========================================
    function KopdesAPI.Toggle(tab, name, defaultVal, callback)
        local state = defaultVal == true
        local holder, row = newShadowed(tab, "TextButton", 46, Theme.Paper, false, 1)
        holder.LayoutOrder = nextLayoutOrder(tab)
        row.Text = ""
        row.AutoButtonColor = false

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -80, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = tostring(name)
        lbl.TextColor3 = Theme.Ink
        lbl.Font = Fonts.Bold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextYAlignment = Enum.TextYAlignment.Center
        -- Nama toggle memuat instruksi (mis. "Perpanjang Semua Role (Kalau Tidak Aktif,
        -- Pakai Role Terpilih)"). Tinggi baris 46px muat 2 baris, jadi bungkus.
        lbl.TextWrapped = true
        lbl.ZIndex = 4
        lbl.Parent = row

        local pill = Instance.new("Frame")
        pill.Size = UDim2.new(0, 48, 0, 26)
        pill.Position = UDim2.new(1, -60, 0.5, -13)
        pill.BackgroundColor3 = state and Theme.Green or Theme.OffTrack
        pill.ZIndex = 4
        pill.Parent = row
        addCorner(pill, Theme.Radius)
        addStroke(pill, BORDER_WIDTH, Theme.Ink)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 18, 0, 18)
        knob.Position = state and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 4, 0.5, -9)
        knob.BackgroundColor3 = Theme.Ink
        knob.ZIndex = 5
        knob.Parent = pill
        addCorner(knob, 1)

        local function applyState(newState, fireCb)
            state = newState == true
            tween(pill, { BackgroundColor3 = state and Theme.Green or Theme.OffTrack }, 0.12)
            tween(knob, {
                Position = state and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 4, 0.5, -9),
            }, 0.12)
            if fireCb and callback then
                task.spawn(callback, state)
            end
        end

        row.MouseButton1Click:Connect(function()
            applyState(not state, true)
        end)

        return {
            _type = "Toggle",
            Set = function(_, newState)
                applyState(newState == true, false)
            end,
        }
    end

    -- ==========================================
    -- SLIDER NEO-BRUTALISM
    -- ==========================================
    function KopdesAPI.Slider(tab, name, minVal, maxVal, inc, suffix, defaultVal, callback)
        inc = inc or 1
        suffix = suffix or ""
        local current = math.clamp(defaultVal or minVal, minVal, maxVal)
        local draggingSlider = false

        local holder, card = newShadowed(tab, "Frame", 74, Theme.Paper, false, 1)
        holder.LayoutOrder = nextLayoutOrder(tab)

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(1, -136, 0, 0)
        titleLbl.AutomaticSize = Enum.AutomaticSize.Y
        titleLbl.Position = UDim2.new(0, 12, 0, 9)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = tostring(name)
        titleLbl.TextColor3 = Theme.Ink
        titleLbl.Font = Fonts.Bold
        titleLbl.TextSize = 11
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.TextYAlignment = Enum.TextYAlignment.Top
        -- Judul slider boleh 2 baris (ruang y=9..42 masih tersedia sebelum track).
        titleLbl.TextWrapped = true
        titleLbl.Parent = card

        local valBadge = Instance.new("Frame")
        valBadge.Size = UDim2.new(0, 110, 0, 22)
        valBadge.Position = UDim2.new(1, -122, 0, 7)
        valBadge.BackgroundColor3 = Theme.Accent
        valBadge.Parent = card
        addCorner(valBadge, Theme.Radius)
        addStroke(valBadge, BORDER_WIDTH, Theme.Ink)

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(1, 0, 1, 0)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = tostring(current) .. suffix
        valLbl.TextColor3 = Theme.Ink
        valLbl.Font = Fonts.Black
        valLbl.TextSize = 10
        valLbl.TextXAlignment = Enum.TextXAlignment.Center
        valLbl.TextTruncate = Enum.TextTruncate.AtEnd
        valLbl.Parent = valBadge
        addPadding(valLbl, 0, 4, 0, 4)

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -24, 0, 14)
        track.Position = UDim2.new(0, 12, 0, 42)
        track.BackgroundColor3 = Theme.OffTrack
        track.Parent = card
        addCorner(track, Theme.Radius)
        addStroke(track, BORDER_WIDTH, Theme.Ink)

        local fill = Instance.new("Frame")
        local initAlpha = (current - minVal) / math.max(maxVal - minVal, 0.0001)
        fill.Size = UDim2.new(math.clamp(initAlpha, 0, 1), 0, 1, 0)
        fill.BackgroundColor3 = Theme.Blue
        fill.BorderSizePixel = 0
        fill.ZIndex = 2
        fill.Parent = track
        addCorner(fill, 1)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = UDim2.new(math.clamp(initAlpha, 0, 1), -8, 0.5, -8)
        knob.BackgroundColor3 = Theme.Ink
        knob.ZIndex = 3
        knob.Parent = track
        addCorner(knob, 2)
        addStroke(knob, 1.5, Theme.Paper)

        local hitbox = Instance.new("Frame")
        hitbox.Size = UDim2.new(1, 0, 0, 38)
        hitbox.Position = UDim2.new(0, 0, 0, 30)
        hitbox.BackgroundTransparency = 1
        hitbox.ZIndex = 5
        hitbox.Parent = card

        local function updateFromInput(inputPos)
            local relX = math.clamp(
                (inputPos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1),
                0,
                1
            )
            local raw = minVal + (maxVal - minVal) * relX
            local stepped = math.floor((raw / inc) + 0.5) * inc
            stepped = tonumber(string.format("%.4f", math.clamp(stepped, minVal, maxVal)))
            current = stepped

            local alpha = (current - minVal) / math.max(maxVal - minVal, 0.0001)
            fill.Size = UDim2.new(math.clamp(alpha, 0, 1), 0, 1, 0)
            knob.Position = UDim2.new(math.clamp(alpha, 0, 1), -8, 0.5, -8)
            valLbl.Text = tostring(current) .. suffix
            if callback then task.spawn(callback, current) end
        end

        local function beginDrag(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = true
                updateFromInput(input.Position)
            end
        end

        track.InputBegan:Connect(beginDrag)
        hitbox.InputBegan:Connect(beginDrag)

        UserInputService.InputChanged:Connect(function(input)
            if not draggingSlider then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                updateFromInput(input.Position)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = false
            end
        end)

        return card
    end

    -- ==========================================
    -- DROPDOWN NEO-BRUTALISM
    -- ==========================================
    function KopdesAPI.Dropdown(tab, name, options, defaultOpt, callback)
        options = options or {}
        local currentOpt = defaultOpt or options[1] or "-"
        local expanded = false

        local holder, card, _, syncSize = newShadowed(tab, "Frame", 44, Theme.Paper, false, 1)
        holder.LayoutOrder = nextLayoutOrder(tab)

        local header = Instance.new("TextButton")
        header.Size = UDim2.new(1, 0, 0, 44)
        header.BackgroundTransparency = 1
        header.Text = ""
        header.AutoButtonColor = false
        header.ZIndex = 3
        header.Parent = card

        local headerLbl = Instance.new("TextLabel")
        headerLbl.Size = UDim2.new(1, -46, 1, 0)
        headerLbl.Position = UDim2.new(0, 12, 0, 0)
        headerLbl.BackgroundTransparency = 1
        headerLbl.Text = tostring(name) .. ": " .. tostring(currentOpt)
        headerLbl.TextColor3 = Theme.Ink
        headerLbl.Font = Fonts.Bold
        headerLbl.TextSize = 11
        headerLbl.TextXAlignment = Enum.TextXAlignment.Left
        headerLbl.TextYAlignment = Enum.TextYAlignment.Center
        -- "Nama: Pilihan" sering panjang, header 44px muat 2 baris.
        headerLbl.TextWrapped = true
        headerLbl.ZIndex = 4
        headerLbl.Parent = header

        local chevron = Instance.new("ImageLabel")
        chevron.Size = UDim2.new(0, 15, 0, 15)
        chevron.Position = UDim2.new(1, -27, 0.5, -7.5)
        chevron.BackgroundTransparency = 1
        chevron.Image = Icons.ChevronDown
        chevron.ImageColor3 = Theme.Ink
        chevron.ZIndex = 4
        chevron.Parent = header

        local divider = Instance.new("Frame")
        divider.Size = UDim2.new(1, 0, 0, 3)
        divider.Position = UDim2.new(0, 0, 0, 41)
        divider.BackgroundColor3 = Theme.Ink
        divider.BorderSizePixel = 0
        divider.Visible = false
        divider.ZIndex = 4
        divider.Parent = card

        local listFrame = Instance.new("Frame")
        listFrame.Size = UDim2.new(1, 0, 0, 0)
        listFrame.Position = UDim2.new(0, 0, 0, 44)
        listFrame.AutomaticSize = Enum.AutomaticSize.Y
        listFrame.BackgroundTransparency = 1
        listFrame.Visible = false
        listFrame.ZIndex = 3
        listFrame.Parent = card
        addPadding(listFrame, 4, 10, 10, 10)

        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, 6)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = listFrame

        local function resizeCard()
            local h = 44
            if expanded then
                h = h + math.max(listFrame.AbsoluteSize.Y, 1)
            end
            syncSize(h)
        end

        local function buildOptions(opts)
            for _, child in ipairs(listFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end

            for _, opt in ipairs(opts or {}) do
                local optText = tostring(opt)
                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1, 0, 0, 32)
                optBtn.BackgroundColor3 = (optText == currentOpt) and Theme.AccentSoft or Theme.Paper
                optBtn.Text = optText
                optBtn.TextColor3 = Theme.Ink
                optBtn.Font = Fonts.Bold
                optBtn.TextSize = 11
                optBtn.TextXAlignment = Enum.TextXAlignment.Left
                optBtn.TextTruncate = Enum.TextTruncate.AtEnd
                optBtn.AutoButtonColor = false
                optBtn.ZIndex = 4
                optBtn.Parent = listFrame
                addCorner(optBtn, Theme.Radius)
                addStroke(optBtn, 1.5, Theme.Ink)
                addPadding(optBtn, 0, 8, 0, 8)

                optBtn.MouseButton1Click:Connect(function()
                    currentOpt = optText
                    headerLbl.Text = tostring(name) .. ": " .. currentOpt
                    expanded = false
                    listFrame.Visible = false
                    divider.Visible = false
                    tween(chevron, { Rotation = 0 }, 0.12)
                    for _, other in ipairs(listFrame:GetChildren()) do
                        if other:IsA("TextButton") then
                            other.BackgroundColor3 = (other.Text == currentOpt) and Theme.AccentSoft or Theme.Paper
                        end
                    end
                    resizeCard()
                    if callback then task.spawn(callback, currentOpt) end
                end)
            end

            task.defer(function()
                if expanded then resizeCard() end
            end)
        end

        header.MouseButton1Click:Connect(function()
            expanded = not expanded
            listFrame.Visible = expanded
            divider.Visible = expanded
            tween(chevron, { Rotation = expanded and 180 or 0 }, 0.12)
            resizeCard()
            task.defer(resizeCard)
        end)

        listFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            if expanded then resizeCard() end
        end)

        buildOptions(options)

        return {
            _type = "Dropdown",
            Refresh = function(_, newOptions)
                buildOptions(newOptions or {})
            end,
        }
    end

    -- ==========================================
    -- INPUT NEO-BRUTALISM
    -- ==========================================
    function KopdesAPI.Input(tab, name, placeholder, callback)
        local holder, card, _, syncSize = newShadowed(tab, "Frame", 78, Theme.Paper, false, 1)
        holder.LayoutOrder = nextLayoutOrder(tab)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -24, 0, 0)
        lbl.AutomaticSize = Enum.AutomaticSize.Y
        lbl.Position = UDim2.new(0, 12, 0, 9)
        lbl.BackgroundTransparency = 1
        lbl.Text = tostring(name)
        lbl.TextColor3 = Theme.Ink
        lbl.Font = Fonts.Bold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextYAlignment = Enum.TextYAlignment.Top
        -- Label memuat instruksi (mis. "Custom Angka Hari Bebas (Tekan Enter)").
        -- Bungkus, lalu dorot textbox ke bawah mengikuti tinggi label.
        lbl.TextWrapped = true
        lbl.Parent = card

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -24, 0, 32)
        box.Position = UDim2.new(0, 12, 0, 31)
        box.BackgroundColor3 = Theme.BgInput
        box.Text = ""
        box.PlaceholderText = tostring(placeholder or "")
        box.PlaceholderColor3 = Theme.TextMuted
        box.TextColor3 = Theme.Ink
        box.Font = Fonts.Medium
        box.TextSize = 11
        box.ClearTextOnFocus = false
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.ZIndex = 3
        box.Parent = card
        addCorner(box, Theme.Radius)
        local boxStroke = addStroke(box, BORDER_WIDTH, Theme.Ink)
        addPadding(box, 0, 10, 0, 10)

        -- Tata ulang: textbox selalu di bawah label, kartu ikut memanjang.
        local function relayout()
            local labelH = math.max(lbl.AbsoluteSize.Y, 14)
            local boxY = 9 + labelH + 8
            box.Position = UDim2.new(0, 12, 0, boxY)
            syncSize(boxY + 32 + 15)
        end
        lbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
        task.defer(relayout)

        box.Focused:Connect(function()
            tween(box, { BackgroundColor3 = Theme.AccentSoft }, 0.12)
            tween(boxStroke, { Color = Theme.Ink }, 0.12)
        end)

        box.FocusLost:Connect(function()
            tween(box, { BackgroundColor3 = Theme.BgInput }, 0.12)
            if callback then
                task.spawn(callback, box.Text)
            end
        end)

        return box
    end

    -- ==========================================
    -- UPDATE ELEMENT TEXT
    -- ==========================================
    function KopdesAPI.SetElementText(elem, newText, newContent)
        if not elem then return end
        pcall(function()
            if elem._type == "Paragraph" and elem.Set then
                elem:Set({ Title = newText, Content = newContent })
            elseif elem.Set then
                elem:Set(newText)
            end
        end)
    end
end

return CustomUI
