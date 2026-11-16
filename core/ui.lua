-- core/ui.lua — Minimalist Dark Blue Responsive UI Engine (PC & Mobile)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local CustomUI = {}

-- ==========================================
-- PALET WARNA: MINIMALIST DARK BLUE
-- ==========================================
local Theme = {
    BgMain       = Color3.fromRGB(11, 17, 32),    -- #0B1120 Midnight Navy
    BgSidebar    = Color3.fromRGB(15, 23, 42),    -- #0F172A Deep Slate Navy
    BgCard       = Color3.fromRGB(23, 33, 56),    -- #172138 Elevated Card
    BgCardHover  = Color3.fromRGB(29, 42, 70),    -- #1D2A46 Hover State
    BgInput      = Color3.fromRGB(13, 20, 38),    -- #0D1426 Deep Input
    Border       = Color3.fromRGB(38, 53, 84),    -- #263554 Subtle Stroke
    BorderActive = Color3.fromRGB(59, 130, 246),  -- #3B82F6 Active Stroke
    Accent       = Color3.fromRGB(59, 130, 246),  -- #3B82F6 Electric Blue
    AccentSoft   = Color3.fromRGB(30, 58, 138),   -- #1E3A8A Soft Blue Tint
    TextPrimary  = Color3.fromRGB(241, 245, 249), -- #F1F5F9 Crisp White
    TextMuted    = Color3.fromRGB(148, 163, 184), -- #94A3B8 Slate Muted
    Success      = Color3.fromRGB(16, 185, 129),  -- #10B981 Emerald
    OffTrack     = Color3.fromRGB(51, 65, 85),    -- #334155 Switch Off
}

-- ==========================================
-- DAFTAR VECTOR ICON (ROBLOX ASSET ID)
-- ==========================================
local Icons = {
    Brand        = "rbxassetid://6031280882", -- Layers / Grid
    Dashboard    = "rbxassetid://6026568198", -- Home
    Shop         = "rbxassetid://6034973115", -- Cart / Store
    Operasional  = "rbxassetid://6031094678", -- Shield / Ops
    Musik        = "rbxassetid://6034328955", -- Audio / Music
    Bank         = "rbxassetid://6034684930", -- Wallet / Bank
    SmartPayroll = "rbxassetid://6034287594", -- Analytics / Tuning
    SewaPekerja  = "rbxassetid://6031265976", -- Users / Staff
    Quest        = "rbxassetid://6031075938", -- Check Circle
    Webhook      = "rbxassetid://6034509993", -- Send / Broadcast
    ChevronDown  = "rbxassetid://6034818372", -- Dropdown Arrow
    Minimize     = "rbxassetid://6035067836", -- Minus
    Bell         = "rbxassetid://6022668888", -- Notification Info
}

local function resolveTabIcon(tabName, customIconId)
    if typeof(customIconId) == "number" and customIconId > 0 and customIconId ~= 4483362458 then
        return "rbxassetid://" .. tostring(customIconId)
    end
    local lower = tostring(tabName):lower()
    if lower:find("dash") or lower:find("home") then return Icons.Dashboard end
    if lower:find("shop") or lower:find("restok") then return Icons.Shop end
    if lower:find("operasional") or lower:find("ops") then return Icons.Operasional end
    if lower:find("musik") or lower:find("sound") then return Icons.Musik end
    if lower:find("smart") then return Icons.SmartPayroll end
    if lower:find("bank") or lower:find("payroll") then return Icons.Bank end
    if lower:find("sewa") or lower:find("pekerja") then return Icons.SewaPekerja end
    if lower:find("quest") then return Icons.Quest end
    if lower:find("webhook") or lower:find("discord") then return Icons.Webhook end
    return Icons.Brand
end

-- ==========================================
-- HELPER KOMPONEN & ANIMASI
-- ==========================================
local function tween(obj, props, dur)
    TweenService:Create(obj, TweenInfo.new(dur or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function addStroke(parent, thickness, color)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness or 1
    s.Color = color or Theme.Border
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
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

local function makeDraggable(dragHandle, targetFrame)
    local dragging, dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            targetFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ==========================================
-- INISIALISASI ENGINE KE KOPDESAPI
-- ==========================================
function CustomUI.AttachToAPI(KopdesAPI, config)
    config = config or {}
    local guiParent = (gethui and gethui()) or CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")

    local old = guiParent:FindFirstChild("KopdesDarkBlueSuite")
    if old then old:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "KopdesDarkBlueSuite"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = guiParent

    -- ==========================================
    -- FLOATING PILL BUTTON (MINIMIZED MODE)
    -- ==========================================
    local FloatBtn = Instance.new("TextButton")
    FloatBtn.Name = "FloatingRestore"
    FloatBtn.Size = UDim2.new(0, 128, 0, 36)
    FloatBtn.Position = UDim2.new(0, 14, 0, 58)
    FloatBtn.BackgroundColor3 = Theme.BgSidebar
    FloatBtn.Text = ""
    FloatBtn.Visible = false
    FloatBtn.AutoButtonColor = false
    FloatBtn.Parent = ScreenGui
    addCorner(FloatBtn, 18)
    addStroke(FloatBtn, 1.2, Theme.Accent)
    makeDraggable(FloatBtn, FloatBtn)

    local FloatIcon = Instance.new("ImageLabel")
    FloatIcon.Size = UDim2.new(0, 16, 0, 16)
    FloatIcon.Position = UDim2.new(0, 12, 0.5, -8)
    FloatIcon.BackgroundTransparency = 1
    FloatIcon.Image = Icons.Brand
    FloatIcon.ImageColor3 = Theme.Accent
    FloatIcon.Parent = FloatBtn

    local FloatText = Instance.new("TextLabel")
    FloatText.Size = UDim2.new(1, -36, 1, 0)
    FloatText.Position = UDim2.new(0, 34, 0, 0)
    FloatText.BackgroundTransparency = 1
    FloatText.Text = "Kopdes UI"
    FloatText.TextColor3 = Theme.TextPrimary
    FloatText.Font = Enum.Font.GothamBold
    FloatText.TextSize = 12
    FloatText.TextXAlignment = Enum.TextXAlignment.Left
    FloatText.Parent = FloatBtn

    -- ==========================================
    -- WINDOW UTAMA (RESPONSIF PC & MOBILE)
    -- ==========================================
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainWindow"
    MainFrame.BackgroundColor3 = Theme.BgMain
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    addCorner(MainFrame, 10)
    addStroke(MainFrame, 1, Theme.Border)

    -- Topbar
    local Topbar = Instance.new("Frame")
    Topbar.Size = UDim2.new(1, 0, 0, 42)
    Topbar.BackgroundColor3 = Theme.BgSidebar
    Topbar.BorderSizePixel = 0
    Topbar.Parent = MainFrame
    makeDraggable(Topbar, MainFrame)

    local TopLine = Instance.new("Frame")
    TopLine.Size = UDim2.new(1, 0, 0, 1)
    TopLine.Position = UDim2.new(0, 0, 1, -1)
    TopLine.BackgroundColor3 = Theme.Border
    TopLine.BorderSizePixel = 0
    TopLine.Parent = Topbar

    local BrandBadge = Instance.new("Frame")
    BrandBadge.Size = UDim2.new(0, 26, 0, 26)
    BrandBadge.Position = UDim2.new(0, 12, 0.5, -13)
    BrandBadge.BackgroundColor3 = Theme.AccentSoft
    BrandBadge.Parent = Topbar
    addCorner(BrandBadge, 6)
    addStroke(BrandBadge, 1, Theme.Accent)

    local BrandIcon = Instance.new("ImageLabel")
    BrandIcon.Size = UDim2.new(0, 14, 0, 14)
    BrandIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
    BrandIcon.BackgroundTransparency = 1
    BrandIcon.Image = Icons.Brand
    BrandIcon.ImageColor3 = Theme.TextPrimary
    BrandIcon.Parent = BrandBadge

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -100, 0, 16)
    TitleLabel.Position = UDim2.new(0, 46, 0, 6)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = tostring(config.Title or "Kopdes Together")
    TitleLabel.TextColor3 = Theme.TextPrimary
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 13
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = Topbar

    local SubLabel = Instance.new("TextLabel")
    SubLabel.Size = UDim2.new(1, -100, 0, 14)
    SubLabel.Position = UDim2.new(0, 46, 0, 22)
    SubLabel.BackgroundTransparency = 1
    SubLabel.Text = tostring(config.Subtitle or "Cheese Dev Suite")
    SubLabel.TextColor3 = Theme.TextMuted
    SubLabel.Font = Enum.Font.Gotham
    SubLabel.TextSize = 10
    SubLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubLabel.Parent = Topbar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 28, 0, 28)
    MinBtn.Position = UDim2.new(1, -38, 0.5, -14)
    MinBtn.BackgroundColor3 = Theme.BgCard
    MinBtn.Text = ""
    MinBtn.AutoButtonColor = false
    MinBtn.Parent = Topbar
    addCorner(MinBtn, 6)
    addStroke(MinBtn, 1, Theme.Border)

    local MinIcon = Instance.new("ImageLabel")
    MinIcon.Size = UDim2.new(0, 14, 0, 14)
    MinIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
    MinIcon.BackgroundTransparency = 1
    MinIcon.Image = Icons.Minimize
    MinIcon.ImageColor3 = Theme.TextMuted
    MinIcon.Parent = MinBtn

    MinBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        FloatBtn.Visible = true
    end)

    FloatBtn.MouseButton1Click:Connect(function()
        FloatBtn.Visible = false
        MainFrame.Visible = true
    end)

    -- ==========================================
    -- SIDEBAR NAVIGASI & AREA KONTEN
    -- ==========================================
    local Sidebar = Instance.new("ScrollingFrame")
    Sidebar.BackgroundColor3 = Theme.BgSidebar
    Sidebar.BorderSizePixel = 0
    Sidebar.ScrollBarThickness = 2
    Sidebar.ScrollBarImageColor3 = Theme.BorderActive
    Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    Sidebar.Parent = MainFrame
    addPadding(Sidebar, 8, 8, 8, 8)

    local SideLayout = Instance.new("UIListLayout")
    SideLayout.Padding = UDim.new(0, 5)
    SideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SideLayout.Parent = Sidebar

    local SideDivider = Instance.new("Frame")
    SideDivider.BackgroundColor3 = Theme.Border
    SideDivider.BorderSizePixel = 0
    SideDivider.Parent = MainFrame

    local ContentHolder = Instance.new("Frame")
    ContentHolder.BackgroundTransparency = 1
    ContentHolder.Parent = MainFrame

    -- Fungsi Penyesuaian Responsif PC vs Ponsel
    local function applyResponsiveLayout()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1024, 768)
        local isMobile = vp.X < 760

        local winW = isMobile and math.clamp(vp.X - 32, 330, 480) or 560
        local winH = isMobile and math.clamp(vp.Y - 40, 240, 315) or 370
        local sideW = isMobile and 122 or 152

        MainFrame.Size = UDim2.new(0, winW, 0, winH)
        MainFrame.Position = UDim2.new(0.5, -math.floor(winW / 2), 0.5, -math.floor(winH / 2))

        Sidebar.Size = UDim2.new(0, sideW, 1, -42)
        Sidebar.Position = UDim2.new(0, 0, 0, 42)

        SideDivider.Size = UDim2.new(0, 1, 1, -42)
        SideDivider.Position = UDim2.new(0, sideW, 0, 42)

        ContentHolder.Size = UDim2.new(1, -(sideW + 1), 1, -42)
        ContentHolder.Position = UDim2.new(0, sideW + 1, 0, 42)
    end

    applyResponsiveLayout()
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
    end

    -- ==========================================
    -- NOTIFIKASI TOAST (DENGAN IKON VEKTOR)
    -- ==========================================
    local NotifHolder = Instance.new("Frame")
    NotifHolder.Size = UDim2.new(0, 260, 1, -20)
    NotifHolder.Position = UDim2.new(1, -272, 0, 10)
    NotifHolder.BackgroundTransparency = 1
    NotifHolder.Parent = ScreenGui

    local NotifLayout = Instance.new("UIListLayout")
    NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    NotifLayout.Padding = UDim.new(0, 8)
    NotifLayout.Parent = NotifHolder

    local tabs = {}
    local firstTab = true

    function KopdesAPI.Notify(title, content, duration)
        task.spawn(function()
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, 0, 0, 52)
            card.AutomaticSize = Enum.AutomaticSize.Y
            card.BackgroundColor3 = Theme.BgSidebar
            card.Parent = NotifHolder
            addCorner(card, 8)
            addStroke(card, 1, Theme.Accent)
            addPadding(card, 8, 10, 8, 10)

            local icon = Instance.new("ImageLabel")
            icon.Size = UDim2.new(0, 15, 0, 15)
            icon.Position = UDim2.new(0, 0, 0, 1)
            icon.BackgroundTransparency = 1
            icon.Image = Icons.Bell
            icon.ImageColor3 = Theme.Accent
            icon.Parent = card

            local tLbl = Instance.new("TextLabel")
            tLbl.Size = UDim2.new(1, -22, 0, 16)
            tLbl.Position = UDim2.new(0, 22, 0, 0)
            tLbl.BackgroundTransparency = 1
            tLbl.Text = tostring(title)
            tLbl.TextColor3 = Theme.TextPrimary
            tLbl.Font = Enum.Font.GothamBold
            tLbl.TextSize = 12
            tLbl.TextXAlignment = Enum.TextXAlignment.Left
            tLbl.Parent = card

            local cLbl = Instance.new("TextLabel")
            cLbl.Size = UDim2.new(1, -22, 0, 0)
            cLbl.Position = UDim2.new(0, 22, 0, 18)
            cLbl.AutomaticSize = Enum.AutomaticSize.Y
            cLbl.BackgroundTransparency = 1
            cLbl.Text = tostring(content)
            cLbl.TextColor3 = Theme.TextMuted
            cLbl.Font = Enum.Font.Gotham
            cLbl.TextSize = 11
            cLbl.TextWrapped = true
            cLbl.TextXAlignment = Enum.TextXAlignment.Left
            cLbl.Parent = card

            task.wait(duration or 3)
            if card and card.Parent then
                card:Destroy()
            end
        end)
    end

    -- ==========================================
    -- TAB & IKON SIDEBAR
    -- ==========================================
    function KopdesAPI.CreateTab(name, iconId)
        local isInitial = firstTab
        firstTab = false

        local tabBtn = Instance.new("TextButton")
        tabBtn.Size = UDim2.new(1, 0, 0, 32)
        tabBtn.BackgroundColor3 = isInitial and Theme.BgCard or Theme.BgSidebar
        tabBtn.BackgroundTransparency = isInitial and 0 or 1
        tabBtn.Text = ""
        tabBtn.AutoButtonColor = false
        tabBtn.Parent = Sidebar
        addCorner(tabBtn, 6)

        local activeBar = Instance.new("Frame")
        activeBar.Size = UDim2.new(0, 3, 0, 16)
        activeBar.Position = UDim2.new(0, 2, 0.5, -8)
        activeBar.BackgroundColor3 = Theme.Accent
        activeBar.BorderSizePixel = 0
        activeBar.Visible = isInitial
        activeBar.Parent = tabBtn
        addCorner(activeBar, 2)

        local tabIcon = Instance.new("ImageLabel")
        tabIcon.Size = UDim2.new(0, 14, 0, 14)
        tabIcon.Position = UDim2.new(0, 10, 0.5, -7)
        tabIcon.BackgroundTransparency = 1
        tabIcon.Image = resolveTabIcon(name, iconId)
        tabIcon.ImageColor3 = isInitial and Theme.Accent or Theme.TextMuted
        tabIcon.Parent = tabBtn

        local tabText = Instance.new("TextLabel")
        tabText.Size = UDim2.new(1, -32, 1, 0)
        tabText.Position = UDim2.new(0, 30, 0, 0)
        tabText.BackgroundTransparency = 1
        tabText.Text = tostring(name)
        tabText.TextColor3 = isInitial and Theme.TextPrimary or Theme.TextMuted
        tabText.Font = isInitial and Enum.Font.GothamBold or Enum.Font.GothamMedium
        tabText.TextSize = 11
        tabText.TextXAlignment = Enum.TextXAlignment.Left
        tabText.TextTruncate = Enum.TextTruncate.AtEnd
        tabText.Parent = tabBtn

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 2
        page.ScrollBarImageColor3 = Theme.BorderActive
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.Visible = isInitial
        page.Parent = ContentHolder
        addPadding(page, 10, 12, 14, 10)

        local pageLayout = Instance.new("UIListLayout")
        pageLayout.Padding = UDim.new(0, 7)
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Parent = page

        table.insert(tabs, {
            btn = tabBtn,
            bar = activeBar,
            icon = tabIcon,
            label = tabText,
            page = page
        })

        tabBtn.MouseButton1Click:Connect(function()
            for _, item in ipairs(tabs) do
                local active = (item.page == page)
                item.page.Visible = active
                item.bar.Visible = active
                item.label.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
                tween(item.btn, {
                    BackgroundColor3 = active and Theme.BgCard or Theme.BgSidebar,
                    BackgroundTransparency = active and 0 or 1
                }, 0.14)
                tween(item.icon, {
                    ImageColor3 = active and Theme.Accent or Theme.TextMuted
                }, 0.14)
                tween(item.label, {
                    TextColor3 = active and Theme.TextPrimary or Theme.TextMuted
                }, 0.14)
            end
        end)

        return page
    end

    -- ==========================================
    -- KOMPONEN UI (SECTION, PARAGRAPH, BUTTON, TOGGLE, SLIDER, DROPDOWN, INPUT)
    -- ==========================================
    function KopdesAPI.Section(tab, title)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 18)
        lbl.BackgroundTransparency = 1
        lbl.Text = string.upper(tostring(title))
        lbl.TextColor3 = Theme.Accent
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = tab
        return lbl
    end

    function KopdesAPI.Paragraph(tab, title, content)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 44)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = Theme.BgCard
        card.Parent = tab
        addCorner(card, 7)
        addStroke(card, 1, Theme.Border)
        addPadding(card, 8, 10, 8, 10)

        local tLbl = Instance.new("TextLabel")
        tLbl.Size = UDim2.new(1, 0, 0, 15)
        tLbl.BackgroundTransparency = 1
        tLbl.Text = tostring(title)
        tLbl.TextColor3 = Theme.TextPrimary
        tLbl.Font = Enum.Font.GothamBold
        tLbl.TextSize = 12
        tLbl.TextXAlignment = Enum.TextXAlignment.Left
        tLbl.Parent = card

        local cLbl = Instance.new("TextLabel")
        cLbl.Size = UDim2.new(1, 0, 0, 0)
        cLbl.Position = UDim2.new(0, 0, 0, 17)
        cLbl.AutomaticSize = Enum.AutomaticSize.Y
        cLbl.BackgroundTransparency = 1
        cLbl.Text = tostring(content)
        cLbl.TextColor3 = Theme.TextMuted
        cLbl.Font = Enum.Font.Gotham
        cLbl.TextSize = 11
        cLbl.TextWrapped = true
        cLbl.TextXAlignment = Enum.TextXAlignment.Left
        cLbl.Parent = card

        return {
            _type = "Paragraph",
            Set = function(_, data)
                if typeof(data) == "table" then
                    if data.Title or data.title then tLbl.Text = tostring(data.Title or data.title) end
                    if data.Content or data.content then cLbl.Text = tostring(data.Content or data.content) end
                end
            end
        }
    end

    function KopdesAPI.Button(tab, name, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 34)
        btn.BackgroundColor3 = Theme.BgCard
        btn.Text = tostring(name)
        btn.TextColor3 = Theme.TextPrimary
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.AutoButtonColor = false
        btn.Parent = tab
        addCorner(btn, 7)
        local stroke = addStroke(btn, 1, Theme.Border)

        btn.MouseButton1Click:Connect(function()
            tween(btn, { BackgroundColor3 = Theme.Accent }, 0.08)
            tween(stroke, { Color = Theme.Accent }, 0.08)
            task.delay(0.14, function()
                tween(btn, { BackgroundColor3 = Theme.BgCard }, 0.14)
                tween(stroke, { Color = Theme.Border }, 0.14)
            end)
            if callback then task.spawn(callback) end
        end)

        return {
            _type = "Button",
            Set = function(_, newText)
                btn.Text = tostring(newText)
            end
        }
    end

    function KopdesAPI.Toggle(tab, name, defaultVal, callback)
        local state = defaultVal == true

        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, 36)
        row.BackgroundColor3 = Theme.BgCard
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = tab
        addCorner(row, 7)
        addStroke(row, 1, Theme.Border)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -62, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = tostring(name)
        lbl.TextColor3 = Theme.TextPrimary
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Parent = row

        local pill = Instance.new("Frame")
        pill.Size = UDim2.new(0, 40, 0, 20)
        pill.Position = UDim2.new(1, -50, 0.5, -10)
        pill.BackgroundColor3 = state and Theme.Accent or Theme.OffTrack
        pill.Parent = row
        addCorner(pill, 10)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 14, 0, 14)
        knob.Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        knob.BackgroundColor3 = Theme.TextPrimary
        knob.Parent = pill
        addCorner(knob, 7)

        local function applyState(newState, fireCb)
            state = newState == true
            tween(pill, { BackgroundColor3 = state and Theme.Accent or Theme.OffTrack }, 0.15)
            tween(knob, { Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7) }, 0.15)
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
                applyState(newState, false)
            end
        }
    end

    function KopdesAPI.Slider(tab, name, minVal, maxVal, inc, suffix, defaultVal, callback)
        inc = inc or 1
        suffix = suffix or ""
        local current = math.clamp(defaultVal or minVal, minVal, maxVal)

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 48)
        card.BackgroundColor3 = Theme.BgCard
        card.Parent = tab
        addCorner(card, 7)
        addStroke(card, 1, Theme.Border)
        addPadding(card, 7, 10, 7, 10)

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(0.7, 0, 0, 15)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = tostring(name)
        titleLbl.TextColor3 = Theme.TextPrimary
        titleLbl.Font = Enum.Font.GothamMedium
        titleLbl.TextSize = 11
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
        titleLbl.Parent = card

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0.3, 0, 0, 15)
        valLbl.Position = UDim2.new(0.7, 0, 0, 0)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = tostring(current) .. suffix
        valLbl.TextColor3 = Theme.Accent
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 11
        valLbl.TextXAlignment = Enum.TextXAlignment.Right
        valLbl.Parent = card

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, 0, 0, 8)
        track.Position = UDim2.new(0, 0, 0, 24)
        track.BackgroundColor3 = Theme.BgInput
        track.Parent = card
        addCorner(track, 4)
        addStroke(track, 1, Theme.Border)

        local fill = Instance.new("Frame")
        local initAlpha = (current - minVal) / math.max(maxVal - minVal, 0.0001)
        fill.Size = UDim2.new(math.clamp(initAlpha, 0, 1), 0, 1, 0)
        fill.BackgroundColor3 = Theme.Accent
        fill.Parent = track
        addCorner(fill, 4)

        local draggingSlider = false
        local function updateFromInput(inputPos)
            local relX = math.clamp((inputPos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            local raw = minVal + (maxVal - minVal) * relX
            local stepped = math.floor((raw / inc) + 0.5) * inc
            stepped = tonumber(string.format("%.4f", math.clamp(stepped, minVal, maxVal)))
            current = stepped

            local alpha = (current - minVal) / math.max(maxVal - minVal, 0.0001)
            fill.Size = UDim2.new(math.clamp(alpha, 0, 1), 0, 1, 0)
            valLbl.Text = tostring(current) .. suffix
            if callback then task.spawn(callback, current) end
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = true
                updateFromInput(input.Position)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
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

    function KopdesAPI.Dropdown(tab, name, options, defaultOpt, callback)
        local currentOpt = defaultOpt or options[1] or "-"
        local expanded = false

        local wrapper = Instance.new("Frame")
        wrapper.Size = UDim2.new(1, 0, 0, 36)
        wrapper.AutomaticSize = Enum.AutomaticSize.Y
        wrapper.BackgroundColor3 = Theme.BgCard
        wrapper.Parent = tab
        addCorner(wrapper, 7)
        addStroke(wrapper, 1, Theme.Border)

        local header = Instance.new("TextButton")
        header.Size = UDim2.new(1, 0, 0, 36)
        header.BackgroundTransparency = 1
        header.Text = ""
        header.Parent = wrapper

        local headerLbl = Instance.new("TextLabel")
        headerLbl.Size = UDim2.new(1, -34, 1, 0)
        headerLbl.Position = UDim2.new(0, 10, 0, 0)
        headerLbl.BackgroundTransparency = 1
        headerLbl.Text = name .. ": " .. tostring(currentOpt)
        headerLbl.TextColor3 = Theme.TextPrimary
        headerLbl.Font = Enum.Font.GothamMedium
        headerLbl.TextSize = 11
        headerLbl.TextXAlignment = Enum.TextXAlignment.Left
        headerLbl.TextTruncate = Enum.TextTruncate.AtEnd
        headerLbl.Parent = header

        local chevron = Instance.new("ImageLabel")
        chevron.Size = UDim2.new(0, 14, 0, 14)
        chevron.Position = UDim2.new(1, -24, 0.5, -7)
        chevron.BackgroundTransparency = 1
        chevron.Image = Icons.ChevronDown
        chevron.ImageColor3 = Theme.TextMuted
        chevron.Parent = header

        local listFrame = Instance.new("Frame")
        listFrame.Size = UDim2.new(1, 0, 0, 0)
        listFrame.Position = UDim2.new(0, 0, 0, 36)
        listFrame.AutomaticSize = Enum.AutomaticSize.Y
        listFrame.BackgroundTransparency = 1
        listFrame.Visible = false
        listFrame.Parent = wrapper
        addPadding(listFrame, 2, 6, 6, 6)

        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, 4)
        listLayout.Parent = listFrame

        local function buildOptions(opts)
            for _, child in ipairs(listFrame:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
            for _, opt in ipairs(opts) do
                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1, 0, 0, 28)
                optBtn.BackgroundColor3 = Theme.BgInput
                optBtn.Text = "  " .. tostring(opt)
                optBtn.TextColor3 = Theme.TextPrimary
                optBtn.Font = Enum.Font.GothamMedium
                optBtn.TextSize = 11
                optBtn.TextXAlignment = Enum.TextXAlignment.Left
                optBtn.TextTruncate = Enum.TextTruncate.AtEnd
                optBtn.Parent = listFrame
                addCorner(optBtn, 5)
                addStroke(optBtn, 1, Theme.Border)

                optBtn.MouseButton1Click:Connect(function()
                    currentOpt = tostring(opt)
                    headerLbl.Text = name .. ": " .. currentOpt
                    expanded = false
                    listFrame.Visible = false
                    tween(chevron, { Rotation = 0 }, 0.14)
                    if callback then task.spawn(callback, currentOpt) end
                end)
            end
        end

        buildOptions(options)

        header.MouseButton1Click:Connect(function()
            expanded = not expanded
            listFrame.Visible = expanded
            tween(chevron, { Rotation = expanded and 180 or 0 }, 0.14)
        end)

        return {
            _type = "Dropdown",
            Refresh = function(_, newOptions)
                if typeof(newOptions) == "table" then
                    buildOptions(newOptions)
                end
            end
        }
    end

    function KopdesAPI.Input(tab, name, placeholder, callback)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 56)
        card.BackgroundColor3 = Theme.BgCard
        card.Parent = tab
        addCorner(card, 7)
        addStroke(card, 1, Theme.Border)
        addPadding(card, 7, 10, 7, 10)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 14)
        lbl.BackgroundTransparency = 1
        lbl.Text = tostring(name)
        lbl.TextColor3 = Theme.TextPrimary
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = card

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, 0, 0, 24)
        box.Position = UDim2.new(0, 0, 0, 19)
        box.BackgroundColor3 = Theme.BgInput
        box.Text = ""
        box.PlaceholderText = tostring(placeholder or "")
        box.PlaceholderColor3 = Theme.TextMuted
        box.TextColor3 = Theme.TextPrimary
        box.Font = Enum.Font.Gotham
        box.TextSize = 11
        box.ClearTextOnFocus = false
        box.Parent = card
        addCorner(box, 5)
        local boxStroke = addStroke(box, 1, Theme.Border)
        addPadding(box, 0, 8, 0, 8)

        box.Focused:Connect(function()
            tween(boxStroke, { Color = Theme.Accent }, 0.12)
        end)

        box.FocusLost:Connect(function()
            tween(boxStroke, { Color = Theme.Border }, 0.12)
            if callback then
                task.spawn(callback, box.Text)
            end
        end)

        return box
    end

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
