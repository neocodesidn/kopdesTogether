-- core/ui.lua
-- Kopdes Together UI Engine
-- Responsive desktop/mobile layout with a restrained, professional visual system.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local CustomUI = {}

-- =========================================================
-- THEME
-- Neutral graphite surfaces, restrained blue accent, clear hierarchy.
-- =========================================================
local Theme = {
    BgMain          = Color3.fromRGB(17, 21, 29),
    BgSidebar       = Color3.fromRGB(20, 25, 34),
    BgSurface       = Color3.fromRGB(27, 33, 44),
    BgSurfaceHover  = Color3.fromRGB(34, 41, 54),
    BgInput         = Color3.fromRGB(14, 18, 25),
    Border          = Color3.fromRGB(47, 56, 70),
    BorderSoft      = Color3.fromRGB(38, 46, 59),
    Accent          = Color3.fromRGB(83, 143, 235),
    AccentHover     = Color3.fromRGB(101, 157, 242),
    AccentSoft      = Color3.fromRGB(34, 54, 83),
    TextPrimary     = Color3.fromRGB(238, 242, 247),
    TextSecondary   = Color3.fromRGB(177, 186, 199),
    TextMuted       = Color3.fromRGB(126, 137, 153),
    Success         = Color3.fromRGB(83, 177, 132),
    OffTrack        = Color3.fromRGB(65, 75, 91),
}

-- Roblox asset icons already used by the project.
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

local function resolveTabIcon(tabName, customIconId)
    if typeof(customIconId) == "number" and customIconId > 0 and customIconId ~= 4483362458 then
        return "rbxassetid://" .. tostring(customIconId)
    end

    local lower = tostring(tabName):lower()
    if lower:find("dash") or lower:find("home") then return Icons.Dashboard end
    if lower:find("shop") or lower:find("restok") then return Icons.Shop end
    if lower:find("operasional") or lower:find("ops") or lower:find("gudang") then return Icons.Operasional end
    if lower:find("musik") or lower:find("sound") then return Icons.Musik end
    if lower:find("smart") then return Icons.SmartPayroll end
    if lower:find("bank") or lower:find("payroll") then return Icons.Bank end
    if lower:find("sewa") or lower:find("pekerja") then return Icons.SewaPekerja end
    if lower:find("quest") then return Icons.Quest end
    if lower:find("webhook") or lower:find("discord") then return Icons.Webhook end
    return Icons.Brand
end

-- =========================================================
-- HELPERS
-- =========================================================
local function tween(object, properties, duration)
    if not object or not object.Parent then return end
    TweenService:Create(
        object,
        TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        properties
    ):Play()
end

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 7)
    corner.Parent = parent
    return corner
end

local function addStroke(parent, color, transparency, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Theme.Border
    stroke.Transparency = transparency == nil and 0 or transparency
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local function addPadding(parent, top, right, bottom, left)
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, top or 8)
    padding.PaddingRight = UDim.new(0, right or 8)
    padding.PaddingBottom = UDim.new(0, bottom or 8)
    padding.PaddingLeft = UDim.new(0, left or 8)
    padding.Parent = parent
    return padding
end

local function makeLabel(parent, text, size, color, font, alignment)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = tostring(text or "")
    label.TextColor3 = color or Theme.TextPrimary
    label.Font = font or Enum.Font.Gotham
    label.TextSize = size or 12
    label.TextXAlignment = alignment or Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local function makeDraggable(dragHandle, targetFrame)
    local dragging = false
    local dragStart
    local startPosition

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = targetFrame.Position

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

        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
        local delta = input.Position - dragStart
        local maxX = math.max(8, viewport.X - targetFrame.AbsoluteSize.X - 8)
        local maxY = math.max(8, viewport.Y - targetFrame.AbsoluteSize.Y - 8)
        local x = math.clamp(startPosition.X.Offset + delta.X, 8, maxX)
        local y = math.clamp(startPosition.Y.Offset + delta.Y, 8, maxY)
        targetFrame.Position = UDim2.fromOffset(x, y)
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- =========================================================
-- ATTACH UI ENGINE TO THE SHARED KOPDES API
-- =========================================================
function CustomUI.AttachToAPI(KopdesAPI, config)
    config = config or {}

    local guiParent
    if typeof(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then guiParent = result end
    end
    guiParent = guiParent or CoreGui
    if not guiParent then
        guiParent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end

    local oldGui = guiParent:FindFirstChild("KopdesDarkBlueSuite")
    if oldGui then oldGui:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "KopdesDarkBlueSuite"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 50
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = guiParent

    -- Window shell.
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainWindow"
    MainFrame.BackgroundColor3 = Theme.BgMain
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    addCorner(MainFrame, 9)
    addStroke(MainFrame, Theme.Border, 0, 1)

    -- Top bar.
    local Topbar = Instance.new("Frame")
    Topbar.Name = "Topbar"
    Topbar.Size = UDim2.new(1, 0, 0, 52)
    Topbar.BackgroundColor3 = Theme.BgMain
    Topbar.BorderSizePixel = 0
    Topbar.Active = true
    Topbar.Parent = MainFrame
    makeDraggable(Topbar, MainFrame)

    local BrandBadge = Instance.new("Frame")
    BrandBadge.Size = UDim2.fromOffset(28, 28)
    BrandBadge.Position = UDim2.new(0, 14, 0.5, -14)
    BrandBadge.BackgroundColor3 = Theme.AccentSoft
    BrandBadge.BorderSizePixel = 0
    BrandBadge.Parent = Topbar
    addCorner(BrandBadge, 6)

    local BrandIcon = Instance.new("ImageLabel")
    BrandIcon.Size = UDim2.fromOffset(15, 15)
    BrandIcon.Position = UDim2.new(0.5, -7.5, 0.5, -7.5)
    BrandIcon.BackgroundTransparency = 1
    BrandIcon.Image = Icons.Brand
    BrandIcon.ImageColor3 = Theme.TextPrimary
    BrandIcon.Parent = BrandBadge

    local TitleLabel = makeLabel(
        Topbar,
        config.Title or "Kopdes Together",
        13,
        Theme.TextPrimary,
        Enum.Font.GothamBold
    )
    TitleLabel.Name = "Title"
    TitleLabel.Position = UDim2.new(0, 52, 0, 7)
    TitleLabel.Size = UDim2.new(1, -112, 0, 18)
    TitleLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local SubLabel = makeLabel(
        Topbar,
        config.Subtitle or "Modular Management Suite",
        10,
        Theme.TextMuted,
        Enum.Font.Gotham
    )
    SubLabel.Name = "Subtitle"
    SubLabel.Position = UDim2.new(0, 52, 0, 27)
    SubLabel.Size = UDim2.new(1, -112, 0, 14)
    SubLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local MinBtn = Instance.new("TextButton")
    MinBtn.Name = "MinimizeButton"
    MinBtn.Size = UDim2.fromOffset(30, 30)
    MinBtn.Position = UDim2.new(1, -42, 0.5, -15)
    MinBtn.BackgroundColor3 = Theme.BgSurface
    MinBtn.BorderSizePixel = 0
    MinBtn.Text = ""
    MinBtn.AutoButtonColor = false
    MinBtn.Parent = Topbar
    addCorner(MinBtn, 6)
    addStroke(MinBtn, Theme.Border, 0, 1)

    local MinIcon = Instance.new("ImageLabel")
    MinIcon.Size = UDim2.fromOffset(14, 14)
    MinIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
    MinIcon.BackgroundTransparency = 1
    MinIcon.Image = Icons.Minimize
    MinIcon.ImageColor3 = Theme.TextSecondary
    MinIcon.Parent = MinBtn

    -- Restore control, used while the main window is minimized.
    local FloatBtn = Instance.new("TextButton")
    FloatBtn.Name = "FloatingRestore"
    FloatBtn.Size = UDim2.fromOffset(142, 36)
    FloatBtn.Position = UDim2.fromOffset(14, 64)
    FloatBtn.BackgroundColor3 = Theme.BgSidebar
    FloatBtn.BorderSizePixel = 0
    FloatBtn.Text = ""
    FloatBtn.Visible = false
    FloatBtn.AutoButtonColor = false
    FloatBtn.Active = true
    FloatBtn.Parent = ScreenGui
    addCorner(FloatBtn, 7)
    addStroke(FloatBtn, Theme.Border, 0, 1)
    makeDraggable(FloatBtn, FloatBtn)

    local FloatIcon = Instance.new("ImageLabel")
    FloatIcon.Size = UDim2.fromOffset(16, 16)
    FloatIcon.Position = UDim2.new(0, 11, 0.5, -8)
    FloatIcon.BackgroundTransparency = 1
    FloatIcon.Image = Icons.Brand
    FloatIcon.ImageColor3 = Theme.Accent
    FloatIcon.Parent = FloatBtn

    local FloatText = makeLabel(FloatBtn, "Kopdes Together", 11, Theme.TextPrimary, Enum.Font.GothamMedium)
    FloatText.Position = UDim2.new(0, 34, 0, 0)
    FloatText.Size = UDim2.new(1, -42, 1, 0)

    MinBtn.Activated:Connect(function()
        MainFrame.Visible = false
        FloatBtn.Visible = true
    end)

    FloatBtn.Activated:Connect(function()
        FloatBtn.Visible = false
        MainFrame.Visible = true
    end)

    -- Navigation and page containers.
    local Sidebar = Instance.new("ScrollingFrame")
    Sidebar.Name = "Navigation"
    Sidebar.BackgroundColor3 = Theme.BgSidebar
    Sidebar.BorderSizePixel = 0
    Sidebar.ScrollBarThickness = 3
    Sidebar.ScrollBarImageColor3 = Theme.Border
    Sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    Sidebar.ClipsDescendants = true
    Sidebar.Parent = MainFrame

    local SideLayout = Instance.new("UIListLayout")
    SideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SideLayout.Padding = UDim.new(0, 5)
    SideLayout.Parent = Sidebar

    local SideDivider = Instance.new("Frame")
    SideDivider.Name = "NavigationDivider"
    SideDivider.BackgroundColor3 = Theme.BorderSoft
    SideDivider.BorderSizePixel = 0
    SideDivider.Parent = MainFrame

    local ContentHolder = Instance.new("Frame")
    ContentHolder.Name = "Content"
    ContentHolder.BackgroundTransparency = 1
    ContentHolder.ClipsDescendants = true
    ContentHolder.Parent = MainFrame

    local tabs = {}
    local firstTab = true
    local isCompact = false
    local NotifHolder, NotifLayout
    local SidebarPadding = addPadding(Sidebar, 12, 9, 12, 9)

    local function applyResponsiveLayout()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1024, 768)
        local previousCompact = isCompact
        isCompact = viewport.X < 720 or viewport.Y < 500
        if previousCompact ~= isCompact then
            Sidebar.CanvasPosition = Vector2.new(0, 0)
        end

        local winW
        local winH
        if isCompact then
            winW = math.max(220, math.min(560, viewport.X - 16))
            winH = math.max(190, viewport.Y - 20)
        else
            winW = math.min(820, math.max(560, viewport.X - 40))
            winH = math.min(620, math.max(400, viewport.Y - 48))
        end

        MainFrame.Size = UDim2.fromOffset(winW, winH)
        MainFrame.Position = UDim2.fromOffset(
            math.max(8, math.floor((viewport.X - winW) / 2)),
            math.max(8, math.floor((viewport.Y - winH) / 2))
        )

        if isCompact then
            -- On phones, navigation becomes a horizontal strip to preserve content width.
            Sidebar.Position = UDim2.new(0, 0, 0, 52)
            Sidebar.Size = UDim2.new(1, 0, 0, 44)
            Sidebar.ScrollingDirection = Enum.ScrollingDirection.X
            Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.X
            Sidebar.ScrollBarThickness = 0
            SidebarPadding.PaddingTop = UDim.new(0, 5)
            SidebarPadding.PaddingRight = UDim.new(0, 8)
            SidebarPadding.PaddingBottom = UDim.new(0, 5)
            SidebarPadding.PaddingLeft = UDim.new(0, 8)

            SideLayout.FillDirection = Enum.FillDirection.Horizontal
            SideLayout.Padding = UDim.new(0, 6)

            SideDivider.Position = UDim2.new(0, 0, 0, 96)
            SideDivider.Size = UDim2.new(1, 0, 0, 1)

            ContentHolder.Position = UDim2.new(0, 0, 0, 97)
            ContentHolder.Size = UDim2.new(1, 0, 1, -97)
        else
            local sideW = math.clamp(math.floor(winW * 0.235), 164, 190)
            Sidebar.Position = UDim2.new(0, 0, 0, 52)
            Sidebar.Size = UDim2.new(0, sideW, 1, -52)
            Sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
            Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
            Sidebar.ScrollBarThickness = 3
            SidebarPadding.PaddingTop = UDim.new(0, 12)
            SidebarPadding.PaddingRight = UDim.new(0, 9)
            SidebarPadding.PaddingBottom = UDim.new(0, 12)
            SidebarPadding.PaddingLeft = UDim.new(0, 9)

            SideLayout.FillDirection = Enum.FillDirection.Vertical
            SideLayout.Padding = UDim.new(0, 5)

            SideDivider.Position = UDim2.new(0, sideW, 0, 52)
            SideDivider.Size = UDim2.new(0, 1, 1, -52)

            ContentHolder.Position = UDim2.new(0, sideW + 1, 0, 52)
            ContentHolder.Size = UDim2.new(1, -(sideW + 1), 1, -52)
        end

        for _, item in ipairs(tabs) do
            if isCompact then
                item.btn.Size = UDim2.fromOffset(116, 34)
                item.bar.Size = UDim2.fromOffset(22, 3)
                item.bar.Position = UDim2.new(0.5, -11, 1, -3)
                item.icon.Position = UDim2.new(0, 9, 0.5, -7)
                item.label.Position = UDim2.new(0, 29, 0, 0)
                item.label.Size = UDim2.new(1, -34, 1, 0)
                item.label.TextSize = 10
            else
                item.btn.Size = UDim2.new(1, 0, 0, 38)
                item.bar.Size = UDim2.fromOffset(3, 18)
                item.bar.Position = UDim2.new(0, 2, 0.5, -9)
                item.icon.Position = UDim2.new(0, 11, 0.5, -7)
                item.label.Position = UDim2.new(0, 34, 0, 0)
                item.label.Size = UDim2.new(1, -42, 1, 0)
                item.label.TextSize = 11
            end
        end

        local notifWidth = math.min(292, math.max(220, viewport.X - 24))
        NotifHolder.Size = UDim2.new(0, notifWidth, 0, 180)
        if isCompact then
            NotifHolder.Position = UDim2.new(0.5, -math.floor(notifWidth / 2), 0, 104)
            NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Top
        else
            NotifHolder.Position = UDim2.new(1, -notifWidth - 14, 1, -194)
            NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        end
    end

    -- Notification stack.
    NotifHolder = Instance.new("Frame")
    NotifHolder.Name = "Notifications"
    NotifHolder.Size = UDim2.fromOffset(292, 180)
    NotifHolder.Position = UDim2.new(1, -306, 1, -194)
    NotifHolder.BackgroundTransparency = 1
    NotifHolder.Parent = ScreenGui

    NotifLayout = Instance.new("UIListLayout")
    NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
    NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    NotifLayout.Padding = UDim.new(0, 7)
    NotifLayout.Parent = NotifHolder

    applyResponsiveLayout()
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
    end
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local camera = workspace.CurrentCamera
        if camera then
            camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
            task.defer(applyResponsiveLayout)
        end
    end)

    function KopdesAPI.Notify(title, content, duration)
        task.spawn(function()
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, 0, 0, 0)
            card.AutomaticSize = Enum.AutomaticSize.Y
            card.BackgroundColor3 = Theme.BgSurface
            card.BorderSizePixel = 0
            card.Parent = NotifHolder
            addCorner(card, 7)
            addStroke(card, Theme.Border, 0, 1)
            addPadding(card, 10, 12, 10, 12)

            local accentLine = Instance.new("Frame")
            accentLine.Size = UDim2.new(0, 3, 1, -16)
            accentLine.Position = UDim2.new(0, 0, 0, 8)
            accentLine.BackgroundColor3 = Theme.Accent
            accentLine.BorderSizePixel = 0
            accentLine.Parent = card
            addCorner(accentLine, 2)

            local titleLabel = makeLabel(card, title, 12, Theme.TextPrimary, Enum.Font.GothamBold)
            titleLabel.Position = UDim2.new(0, 10, 0, 0)
            titleLabel.Size = UDim2.new(1, -10, 0, 17)
            titleLabel.TextTruncate = Enum.TextTruncate.AtEnd

            local contentLabel = makeLabel(card, content, 11, Theme.TextSecondary, Enum.Font.Gotham)
            contentLabel.Position = UDim2.new(0, 10, 0, 21)
            contentLabel.Size = UDim2.new(1, -10, 0, 0)
            contentLabel.AutomaticSize = Enum.AutomaticSize.Y
            contentLabel.TextWrapped = true
            contentLabel.TextYAlignment = Enum.TextYAlignment.Top

            task.wait(tonumber(duration) or 3)
            if card and card.Parent then
                tween(card, { BackgroundTransparency = 1 }, 0.15)
                task.wait(0.16)
                if card and card.Parent then card:Destroy() end
            end
        end)
    end

    -- =====================================================
    -- TAB CREATION AND NAVIGATION
    -- =====================================================
    function KopdesAPI.CreateTab(name, iconId)
        local isInitial = firstTab
        firstTab = false

        local tabButton = Instance.new("TextButton")
        tabButton.Name = "Tab_" .. tostring(name):gsub("%W", "")
        tabButton.Size = isCompact and UDim2.fromOffset(116, 34) or UDim2.new(1, 0, 0, 38)
        tabButton.BackgroundColor3 = isInitial and Theme.BgSurface or Theme.BgSidebar
        tabButton.BackgroundTransparency = isInitial and 0 or 1
        tabButton.BorderSizePixel = 0
        tabButton.Text = ""
        tabButton.AutoButtonColor = false
        tabButton.Parent = Sidebar
        addCorner(tabButton, 6)

        local activeBar = Instance.new("Frame")
        activeBar.BackgroundColor3 = Theme.Accent
        activeBar.BorderSizePixel = 0
        activeBar.Visible = isInitial
        activeBar.Parent = tabButton
        addCorner(activeBar, 2)

        local tabIcon = Instance.new("ImageLabel")
        tabIcon.Size = UDim2.fromOffset(14, 14)
        tabIcon.BackgroundTransparency = 1
        tabIcon.Image = resolveTabIcon(name, iconId)
        tabIcon.ImageColor3 = isInitial and Theme.Accent or Theme.TextMuted
        tabIcon.Parent = tabButton

        local tabLabel = makeLabel(
            tabButton,
            name,
            isCompact and 10 or 11,
            isInitial and Theme.TextPrimary or Theme.TextMuted,
            isInitial and Enum.Font.GothamBold or Enum.Font.GothamMedium
        )
        tabLabel.TextTruncate = Enum.TextTruncate.AtEnd
        tabLabel.Parent = tabButton

        local page = Instance.new("ScrollingFrame")
        page.Name = "Page_" .. tostring(name):gsub("%W", "")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = Theme.Border
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.Visible = isInitial
        page.Parent = ContentHolder
        addPadding(page, 13, 14, 16, 14)

        local pageLayout = Instance.new("UIListLayout")
        pageLayout.Padding = UDim.new(0, 8)
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Parent = page

        local tabRecord = {
            btn = tabButton,
            bar = activeBar,
            icon = tabIcon,
            label = tabLabel,
            page = page,
        }
        table.insert(tabs, tabRecord)

        -- Apply the correct tab dimensions after it has been registered.
        if isCompact then
            activeBar.Size = UDim2.fromOffset(22, 3)
            activeBar.Position = UDim2.new(0.5, -11, 1, -3)
            tabIcon.Position = UDim2.new(0, 9, 0.5, -7)
            tabLabel.Position = UDim2.new(0, 29, 0, 0)
            tabLabel.Size = UDim2.new(1, -34, 1, 0)
        else
            activeBar.Size = UDim2.fromOffset(3, 18)
            activeBar.Position = UDim2.new(0, 2, 0.5, -9)
            tabIcon.Position = UDim2.new(0, 11, 0.5, -7)
            tabLabel.Position = UDim2.new(0, 34, 0, 0)
            tabLabel.Size = UDim2.new(1, -42, 1, 0)
        end

        tabButton.Activated:Connect(function()
            for _, item in ipairs(tabs) do
                local active = item.page == page
                item.page.Visible = active
                item.bar.Visible = active
                item.label.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
                tween(item.btn, {
                    BackgroundColor3 = active and Theme.BgSurface or Theme.BgSidebar,
                    BackgroundTransparency = active and 0 or 1,
                }, 0.13)
                tween(item.icon, {
                    ImageColor3 = active and Theme.Accent or Theme.TextMuted,
                }, 0.13)
                tween(item.label, {
                    TextColor3 = active and Theme.TextPrimary or Theme.TextMuted,
                }, 0.13)
            end
        end)

        return page
    end

    -- =====================================================
    -- COMPONENTS
    -- =====================================================
    function KopdesAPI.Section(tab, title)
        local holder = Instance.new("Frame")
        holder.Name = "Section"
        holder.Size = UDim2.new(1, 0, 0, 23)
        holder.BackgroundTransparency = 1
        holder.Parent = tab

        local marker = Instance.new("Frame")
        marker.Size = UDim2.fromOffset(2, 12)
        marker.Position = UDim2.new(0, 1, 0.5, -6)
        marker.BackgroundColor3 = Theme.Accent
        marker.BorderSizePixel = 0
        marker.Parent = holder
        addCorner(marker, 1)

        local label = makeLabel(holder, title, 11, Theme.TextSecondary, Enum.Font.GothamBold)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.Size = UDim2.new(1, -10, 1, 0)
        return label
    end

    function KopdesAPI.Paragraph(tab, title, content)
        local card = Instance.new("Frame")
        card.Name = "Paragraph"
        card.Size = UDim2.new(1, 0, 0, 0)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = Theme.BgSurface
        card.BorderSizePixel = 0
        card.Parent = tab
        addCorner(card, 7)
        addStroke(card, Theme.BorderSoft, 0, 1)
        addPadding(card, 11, 12, 11, 12)

        local titleLabel = makeLabel(card, title, 12, Theme.TextPrimary, Enum.Font.GothamBold)
        titleLabel.Size = UDim2.new(1, 0, 0, 18)
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd

        local contentLabel = makeLabel(card, content, 11, Theme.TextSecondary, Enum.Font.Gotham)
        contentLabel.Position = UDim2.new(0, 0, 0, 23)
        contentLabel.Size = UDim2.new(1, 0, 0, 0)
        contentLabel.AutomaticSize = Enum.AutomaticSize.Y
        contentLabel.TextWrapped = true
        contentLabel.TextYAlignment = Enum.TextYAlignment.Top

        return {
            _type = "Paragraph",
            Set = function(_, data)
                if typeof(data) ~= "table" then return end
                if data.Title ~= nil or data.title ~= nil then
                    titleLabel.Text = tostring(data.Title ~= nil and data.Title or data.title)
                end
                if data.Content ~= nil or data.content ~= nil then
                    contentLabel.Text = tostring(data.Content ~= nil and data.Content or data.content)
                end
            end,
        }
    end

    function KopdesAPI.Button(tab, name, callback)
        local button = Instance.new("TextButton")
        button.Name = "ActionButton"
        button.Size = UDim2.new(1, 0, 0, 40)
        button.BackgroundColor3 = Theme.BgSurface
        button.BorderSizePixel = 0
        button.Text = tostring(name)
        button.TextColor3 = Theme.TextPrimary
        button.Font = Enum.Font.GothamBold
        button.TextSize = 11
        button.TextWrapped = true
        button.AutoButtonColor = false
        button.Parent = tab
        addCorner(button, 7)
        local stroke = addStroke(button, Theme.BorderSoft, 0, 1)

        button.MouseEnter:Connect(function()
            tween(button, { BackgroundColor3 = Theme.BgSurfaceHover }, 0.12)
            tween(stroke, { Color = Theme.Accent, Transparency = 0.15 }, 0.12)
        end)
        button.MouseLeave:Connect(function()
            tween(button, { BackgroundColor3 = Theme.BgSurface }, 0.12)
            tween(stroke, { Color = Theme.BorderSoft, Transparency = 0 }, 0.12)
        end)
        button.Activated:Connect(function()
            tween(button, { BackgroundColor3 = Theme.AccentSoft }, 0.08)
            task.delay(0.1, function()
                if button and button.Parent then
                    tween(button, { BackgroundColor3 = Theme.BgSurfaceHover }, 0.12)
                end
            end)
            if callback then task.spawn(callback) end
        end)

        return {
            _type = "Button",
            Set = function(_, newText)
                button.Text = tostring(newText)
            end,
        }
    end

    function KopdesAPI.Toggle(tab, name, defaultValue, callback)
        local state = defaultValue == true

        local row = Instance.new("TextButton")
        row.Name = "Toggle"
        row.Size = UDim2.new(1, 0, 0, 42)
        row.BackgroundColor3 = Theme.BgSurface
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = tab
        addCorner(row, 7)
        addStroke(row, Theme.BorderSoft, 0, 1)

        local label = makeLabel(row, name, 11, Theme.TextPrimary, Enum.Font.GothamMedium)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.Size = UDim2.new(1, -72, 1, 0)
        label.TextTruncate = Enum.TextTruncate.AtEnd

        local track = Instance.new("Frame")
        track.Size = UDim2.fromOffset(38, 20)
        track.Position = UDim2.new(1, -50, 0.5, -10)
        track.BackgroundColor3 = state and Theme.Accent or Theme.OffTrack
        track.BorderSizePixel = 0
        track.Parent = row
        addCorner(track, 10)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(14, 14)
        knob.Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        knob.BackgroundColor3 = Theme.TextPrimary
        knob.BorderSizePixel = 0
        knob.Parent = track
        addCorner(knob, 7)

        local function applyState(newState, fireCallback)
            state = newState == true
            tween(track, { BackgroundColor3 = state and Theme.Accent or Theme.OffTrack }, 0.14)
            tween(knob, {
                Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
            }, 0.14)
            if fireCallback and callback then task.spawn(callback, state) end
        end

        row.Activated:Connect(function()
            applyState(not state, true)
        end)

        return {
            _type = "Toggle",
            Set = function(_, newState)
                applyState(newState, false)
            end,
        }
    end

    function KopdesAPI.Slider(tab, name, minValue, maxValue, increment, suffix, defaultValue, callback)
        increment = tonumber(increment) or 1
        if increment <= 0 then increment = 1 end
        suffix = suffix or ""
        minValue = tonumber(minValue) or 0
        maxValue = tonumber(maxValue) or 100
        if maxValue < minValue then maxValue = minValue end

        local current = math.clamp(tonumber(defaultValue) or minValue, minValue, maxValue)
        local card = Instance.new("Frame")
        card.Name = "Slider"
        card.Size = UDim2.new(1, 0, 0, 64)
        card.BackgroundColor3 = Theme.BgSurface
        card.BorderSizePixel = 0
        card.Parent = tab
        addCorner(card, 7)
        addStroke(card, Theme.BorderSoft, 0, 1)
        addPadding(card, 9, 12, 9, 12)

        local titleLabel = makeLabel(card, name, 11, Theme.TextPrimary, Enum.Font.GothamMedium)
        titleLabel.Size = UDim2.new(0.72, 0, 0, 17)
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd

        local valueLabel = makeLabel(card, tostring(current) .. suffix, 11, Theme.Accent, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
        valueLabel.Position = UDim2.new(0.72, 0, 0, 0)
        valueLabel.Size = UDim2.new(0.28, 0, 0, 17)

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, 0, 0, 6)
        track.Position = UDim2.new(0, 0, 0, 31)
        track.BackgroundColor3 = Theme.BgInput
        track.BorderSizePixel = 0
        track.Active = true
        track.Parent = card
        addCorner(track, 3)

        local fill = Instance.new("Frame")
        local initialAlpha = (current - minValue) / math.max(maxValue - minValue, 0.0001)
        fill.Size = UDim2.new(math.clamp(initialAlpha, 0, 1), 0, 1, 0)
        fill.BackgroundColor3 = Theme.Accent
        fill.BorderSizePixel = 0
        fill.Parent = track
        addCorner(fill, 3)

        local draggingSlider = false
        local function setValue(value, fireCallback)
            local raw = math.clamp(value, minValue, maxValue)
            local stepped = minValue + math.floor(((raw - minValue) / increment) + 0.5) * increment
            current = tonumber(string.format("%.4f", math.clamp(stepped, minValue, maxValue)))
            local alpha = (current - minValue) / math.max(maxValue - minValue, 0.0001)
            fill.Size = UDim2.new(math.clamp(alpha, 0, 1), 0, 1, 0)
            valueLabel.Text = tostring(current) .. suffix
            if fireCallback and callback then task.spawn(callback, current) end
        end

        local function updateFromPosition(position)
            local relativeX = math.clamp(
                (position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1),
                0,
                1
            )
            setValue(minValue + (maxValue - minValue) * relativeX, true)
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = true
                updateFromPosition(input.Position)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateFromPosition(input.Position)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSlider = false
            end
        end)

        return card
    end

    function KopdesAPI.Dropdown(tab, name, options, defaultOption, callback)
        options = typeof(options) == "table" and options or {}
        local currentOption = defaultOption or options[1] or "-"
        local expanded = false

        local wrapper = Instance.new("Frame")
        wrapper.Name = "Dropdown"
        wrapper.Size = UDim2.new(1, 0, 0, 48)
        wrapper.AutomaticSize = Enum.AutomaticSize.Y
        wrapper.BackgroundColor3 = Theme.BgSurface
        wrapper.BorderSizePixel = 0
        wrapper.Parent = tab
        addCorner(wrapper, 7)
        addStroke(wrapper, Theme.BorderSoft, 0, 1)

        local header = Instance.new("TextButton")
        header.Name = "DropdownHeader"
        header.Size = UDim2.new(1, 0, 0, 48)
        header.BackgroundTransparency = 1
        header.BorderSizePixel = 0
        header.Text = ""
        header.AutoButtonColor = false
        header.Parent = wrapper

        local nameLabel = makeLabel(header, name, 10, Theme.TextMuted, Enum.Font.GothamMedium)
        nameLabel.Position = UDim2.new(0, 12, 0, 5)
        nameLabel.Size = UDim2.new(1, -42, 0, 13)
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

        local valueLabel = makeLabel(header, currentOption, 11, Theme.TextPrimary, Enum.Font.GothamMedium)
        valueLabel.Position = UDim2.new(0, 12, 0, 21)
        valueLabel.Size = UDim2.new(1, -42, 0, 18)
        valueLabel.TextTruncate = Enum.TextTruncate.AtEnd

        local chevron = Instance.new("ImageLabel")
        chevron.Size = UDim2.fromOffset(14, 14)
        chevron.Position = UDim2.new(1, -25, 0.5, -7)
        chevron.BackgroundTransparency = 1
        chevron.Image = Icons.ChevronDown
        chevron.ImageColor3 = Theme.TextMuted
        chevron.Parent = header

        local listFrame = Instance.new("Frame")
        listFrame.Name = "Options"
        listFrame.Position = UDim2.new(0, 0, 0, 48)
        listFrame.Size = UDim2.new(1, 0, 0, 0)
        listFrame.AutomaticSize = Enum.AutomaticSize.Y
        listFrame.BackgroundTransparency = 1
        listFrame.Visible = false
        listFrame.Parent = wrapper
        addPadding(listFrame, 2, 8, 8, 8)

        local listLayout = Instance.new("UIListLayout")
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Padding = UDim.new(0, 4)
        listLayout.Parent = listFrame

        local function buildOptions(newOptions)
            for _, child in ipairs(listFrame:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end

            for _, option in ipairs(newOptions) do
                local optionText = tostring(option)
                local optionButton = Instance.new("TextButton")
                optionButton.Size = UDim2.new(1, 0, 0, 34)
                optionButton.BackgroundColor3 = Theme.BgInput
                optionButton.BorderSizePixel = 0
                optionButton.Text = "  " .. optionText
                optionButton.TextColor3 = Theme.TextSecondary
                optionButton.Font = Enum.Font.GothamMedium
                optionButton.TextSize = 11
                optionButton.TextXAlignment = Enum.TextXAlignment.Left
                optionButton.TextTruncate = Enum.TextTruncate.AtEnd
                optionButton.AutoButtonColor = false
                optionButton.Parent = listFrame
                addCorner(optionButton, 5)

                optionButton.MouseEnter:Connect(function()
                    tween(optionButton, { BackgroundColor3 = Theme.BgSurfaceHover, TextColor3 = Theme.TextPrimary }, 0.1)
                end)
                optionButton.MouseLeave:Connect(function()
                    tween(optionButton, { BackgroundColor3 = Theme.BgInput, TextColor3 = Theme.TextSecondary }, 0.1)
                end)
                optionButton.Activated:Connect(function()
                    currentOption = optionText
                    valueLabel.Text = currentOption
                    expanded = false
                    listFrame.Visible = false
                    tween(chevron, { Rotation = 0 }, 0.12)
                    if callback then task.spawn(callback, currentOption) end
                end)
            end
        end

        buildOptions(options)

        header.Activated:Connect(function()
            expanded = not expanded
            listFrame.Visible = expanded
            tween(chevron, { Rotation = expanded and 180 or 0 }, 0.12)
        end)

        return {
            _type = "Dropdown",
            Refresh = function(_, newOptions)
                if typeof(newOptions) ~= "table" then return end
                options = newOptions
                local found = false
                for _, option in ipairs(options) do
                    if tostring(option) == tostring(currentOption) then
                        found = true
                        break
                    end
                end
                if not found then currentOption = options[1] or "-" end
                valueLabel.Text = tostring(currentOption)
                buildOptions(options)
            end,
            Set = function(_, newOption)
                currentOption = tostring(newOption)
                valueLabel.Text = currentOption
            end,
        }
    end

    function KopdesAPI.Input(tab, name, placeholder, callback)
        local card = Instance.new("Frame")
        card.Name = "Input"
        card.Size = UDim2.new(1, 0, 0, 68)
        card.BackgroundColor3 = Theme.BgSurface
        card.BorderSizePixel = 0
        card.Parent = tab
        addCorner(card, 7)
        addStroke(card, Theme.BorderSoft, 0, 1)
        addPadding(card, 8, 11, 8, 11)

        local label = makeLabel(card, name, 11, Theme.TextPrimary, Enum.Font.GothamMedium)
        label.Size = UDim2.new(1, 0, 0, 16)
        label.TextTruncate = Enum.TextTruncate.AtEnd

        local textBox = Instance.new("TextBox")
        textBox.Name = "TextInput"
        textBox.Size = UDim2.new(1, 0, 0, 28)
        textBox.Position = UDim2.new(0, 0, 0, 23)
        textBox.BackgroundColor3 = Theme.BgInput
        textBox.BorderSizePixel = 0
        textBox.Text = ""
        textBox.PlaceholderText = tostring(placeholder or "")
        textBox.PlaceholderColor3 = Theme.TextMuted
        textBox.TextColor3 = Theme.TextPrimary
        textBox.Font = Enum.Font.Gotham
        textBox.TextSize = 11
        textBox.TextXAlignment = Enum.TextXAlignment.Left
        textBox.ClearTextOnFocus = false
        textBox.Parent = card
        addCorner(textBox, 5)
        local textStroke = addStroke(textBox, Theme.Border, 0, 1)
        addPadding(textBox, 0, 9, 0, 9)

        textBox.Focused:Connect(function()
            tween(textStroke, { Color = Theme.Accent }, 0.12)
        end)
        textBox.FocusLost:Connect(function()
            tween(textStroke, { Color = Theme.Border }, 0.12)
            if callback then task.spawn(callback, textBox.Text) end
        end)

        return textBox
    end

    function KopdesAPI.SetElementText(element, newText, newContent)
        if not element then return end
        pcall(function()
            if typeof(element) == "Instance" then
                if element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox") then
                    element.Text = tostring(newText)
                end
                return
            end

            if element._type == "Paragraph" and element.Set then
                element:Set({ Title = newText, Content = newContent })
            elseif element.Set then
                element:Set(newText)
            end
        end)
    end

    return ScreenGui
end

return CustomUI
