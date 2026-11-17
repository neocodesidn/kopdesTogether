local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Hapus UI lama jika skrip dijalankan ulang
local parentGui = (gethui and gethui()) or CoreGui
local oldGui = parentGui:FindFirstChild("KopdesUI_Root")
if oldGui then
    oldGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KopdesUI_Root"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

-- ==========================================
-- PALET WARNA KOPDES UI
-- ==========================================
local THEME = {
    BgMain = Color3.fromRGB(16, 22, 36),
    BgHeader = Color3.fromRGB(22, 31, 50),
    BgCard = Color3.fromRGB(24, 34, 56),
    BgInput = Color3.fromRGB(12, 17, 29),
    Accent = Color3.fromRGB(45, 130, 255),
    AccentSoft = Color3.fromRGB(32, 86, 175),
    Success = Color3.fromRGB(34, 197, 94),
    Stroke = Color3.fromRGB(48, 68, 108),
    TextPrimary = Color3.fromRGB(241, 245, 249),
    TextSecondary = Color3.fromRGB(148, 163, 184),
    TextMuted = Color3.fromRGB(100, 116, 139)
}

local function addCorner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
    return c
end

local function addStroke(obj, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.Stroke
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

local function makeDraggable(dragHandle, targetFrame)
    local dragging = false
    local dragInput, dragStart, startPos

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

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            targetFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ==========================================
-- TOMBOL MELAYANG (KOPDES UI)
-- ==========================================
local FloatBtn = Instance.new("TextButton")
FloatBtn.Name = "FloatingToggle"
FloatBtn.Size = UDim2.new(0, 112, 0, 34)
FloatBtn.Position = UDim2.new(0, 16, 0, 96)
FloatBtn.BackgroundColor3 = THEME.BgMain
FloatBtn.Text = "⚙ Kopdes UI"
FloatBtn.TextColor3 = THEME.TextPrimary
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.TextSize = 12
FloatBtn.ClipsDescendants = true
FloatBtn.AutoButtonColor = true
FloatBtn.Parent = ScreenGui
addCorner(FloatBtn, 17)
addStroke(FloatBtn, THEME.Accent, 1.5)
makeDraggable(FloatBtn, FloatBtn)

-- ==========================================
-- WINDOW UTAMA
-- ==========================================
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainWindow"
MainFrame.Size = UDim2.new(0, 430, 0, 300)
MainFrame.Position = UDim2.new(0.5, -215, 0.5, -150)
MainFrame.BackgroundColor3 = THEME.BgMain
MainFrame.ClipsDescendants = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui
addCorner(MainFrame, 12)
addStroke(MainFrame, THEME.Stroke, 1.5)

FloatBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Header Window
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundColor3 = THEME.BgHeader
Header.ClipsDescendants = true
Header.Parent = MainFrame
makeDraggable(Header, MainFrame)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "KOPDES TOGETHER HUB"
TitleLabel.TextColor3 = THEME.TextPrimary
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
TitleLabel.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -32, 0.5, -13)
CloseBtn.BackgroundColor3 = THEME.BgCard
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = THEME.TextSecondary
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.Parent = Header
addCorner(CloseBtn, 6)
CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Bar Tab (Scroll Horizontal + Anti Overflow)
local TabBar = Instance.new("ScrollingFrame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -20, 0, 30)
TabBar.Position = UDim2.new(0, 10, 0, 44)
TabBar.BackgroundTransparency = 1
TabBar.ScrollBarThickness = 0
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TabBar.ClipsDescendants = true
TabBar.Parent = MainFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 6)
TabLayout.Parent = TabBar

-- Area Konten Tab
local ContentHolder = Instance.new("Frame")
ContentHolder.Name = "ContentHolder"
ContentHolder.Size = UDim2.new(1, -20, 1, -86)
ContentHolder.Position = UDim2.new(0, 10, 0, 78)
ContentHolder.BackgroundTransparency = 1
ContentHolder.ClipsDescendants = true
ContentHolder.Parent = MainFrame

-- Container Notifikasi
local NotifHolder = Instance.new("Frame")
NotifHolder.Name = "NotifHolder"
NotifHolder.Size = UDim2.new(0, 260, 1, -20)
NotifHolder.Position = UDim2.new(1, -270, 0, 10)
NotifHolder.BackgroundTransparency = 1
NotifHolder.ClipsDescendants = true
NotifHolder.Parent = ScreenGui

local NotifLayout = Instance.new("UIListLayout")
NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
NotifLayout.Padding = UDim.new(0, 6)
NotifLayout.Parent = NotifHolder

-- ==========================================
-- FUNGSI API KOMPONEN UI
-- ==========================================
local UI = {}
local tabs = {}
local activeTab = nil

local function pilihTab(tabObj)
    for _, t in ipairs(tabs) do
        local isSelected = (t == tabObj)
        t.Page.Visible = isSelected
        t.Button.BackgroundColor3 = isSelected and THEME.Accent or THEME.BgCard
        t.Button.TextColor3 = isSelected and Color3.new(1, 1, 1) or THEME.TextSecondary
    end
    activeTab = tabObj
end

function UI.CreateTab(name)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(0, 84, 1, 0)
    tabBtn.BackgroundColor3 = THEME.BgCard
    tabBtn.Text = tostring(name)
    tabBtn.TextColor3 = THEME.TextSecondary
    tabBtn.Font = Enum.Font.GothamSemibold
    tabBtn.TextSize = 12
    tabBtn.TextTruncate = Enum.TextTruncate.AtEnd
    tabBtn.ClipsDescendants = true
    tabBtn.Parent = TabBar
    addCorner(tabBtn, 7)

    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. tostring(name)
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = THEME.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.ClipsDescendants = true
    page.Visible = false
    page.Parent = ContentHolder

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0, 6)
    pageLayout.Parent = page

    local pagePad = Instance.new("UIPadding")
    pagePad.PaddingBottom = UDim.new(0, 8)
    pagePad.PaddingRight = UDim.new(0, 4)
    pagePad.Parent = page

    local tabObj = { Button = tabBtn, Page = page }
    table.insert(tabs, tabObj)

    tabBtn.MouseButton1Click:Connect(function()
        pilihTab(tabObj)
    end)

    if not activeTab then
        pilihTab(tabObj)
    end

    return page
end

function UI.Section(tabPage, title)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = "  " .. tostring(title):upper()
    lbl.TextColor3 = THEME.Accent
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ClipsDescendants = true
    lbl.Parent = tabPage
    return lbl
end

function UI.Paragraph(tabPage, title, desc)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = THEME.BgCard
    card.ClipsDescendants = true
    card.Parent = tabPage
    addCorner(card, 8)
    addStroke(card, THEME.Stroke, 1)

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 3)
    layout.Parent = card

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, 0, 0, 0)
    titleLbl.AutomaticSize = Enum.AutomaticSize.Y
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = tostring(title or "")
    titleLbl.TextColor3 = THEME.TextPrimary
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 12
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextWrapped = true
    titleLbl.ClipsDescendants = true
    titleLbl.Parent = card

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, 0, 0, 0)
    descLbl.AutomaticSize = Enum.AutomaticSize.Y
    descLbl.BackgroundTransparency = 1
    descLbl.Text = tostring(desc or "")
    descLbl.TextColor3 = THEME.TextSecondary
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextSize = 11
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.TextWrapped = true
    descLbl.ClipsDescendants = true
    descLbl.Parent = card

    return { Frame = card, Title = titleLbl, Desc = descLbl }
end

function UI.SetElementText(element, title, desc)
    if not element then return end
    if element.Title and title ~= nil then
        element.Title.Text = tostring(title)
    end
    if element.Desc and desc ~= nil then
        element.Desc.Text = tostring(desc)
    end
end

-- ==========================================
-- KOMPONEN INPUT NOMINAL & TEKS (ANTI OVERFLOW)
-- ==========================================
function UI.Input(tabPage, labelText, placeholder, defaultVal, suffix, callback, opts)
    opts = opts or {}
    local numericOnly = opts.numericOnly ~= false -- default true untuk nominal/angka
    local allowDecimal = opts.allowDecimal == true
    local minVal = opts.min
    local maxVal = opts.max

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = THEME.BgCard
    row.ClipsDescendants = true
    row.Parent = tabPage
    addCorner(row, 8)
    addStroke(row, THEME.Stroke, 1)

    -- Label kiri dibatasi lebarnya agar tidak bertabrakan dengan kotak input
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -154, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = tostring(labelText or "Input")
    lbl.TextColor3 = THEME.TextPrimary
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ClipsDescendants = true
    lbl.Parent = row

    -- Kotak pembungkus input dengan ClipsDescendants agar teks panjang tidak keluar batas
    local boxWrapper = Instance.new("Frame")
    boxWrapper.Size = UDim2.new(0, 134, 0, 26)
    boxWrapper.Position = UDim2.new(1, -142, 0.5, -13)
    boxWrapper.BackgroundColor3 = THEME.BgInput
    boxWrapper.ClipsDescendants = true
    boxWrapper.Parent = row
    addCorner(boxWrapper, 6)
    local boxStroke = addStroke(boxWrapper, THEME.Stroke, 1)

    local hasSuffix = (suffix ~= nil and tostring(suffix) ~= "")
    local suffixWidth = hasSuffix and 30 or 0

    if hasSuffix then
        local suffixLbl = Instance.new("TextLabel")
        suffixLbl.Size = UDim2.new(0, suffixWidth, 1, 0)
        suffixLbl.Position = UDim2.new(1, -(suffixWidth + 6), 0, 0)
        suffixLbl.BackgroundTransparency = 1
        suffixLbl.Text = tostring(suffix):gsub("^%s+", "")
        suffixLbl.TextColor3 = THEME.TextMuted
        suffixLbl.Font = Enum.Font.GothamSemibold
        suffixLbl.TextSize = 11
        suffixLbl.TextXAlignment = Enum.TextXAlignment.Right
        suffixLbl.TextTruncate = Enum.TextTruncate.AtEnd
        suffixLbl.ClipsDescendants = true
        suffixLbl.Parent = boxWrapper
    end

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -(12 + suffixWidth), 1, 0)
    textBox.Position = UDim2.new(0, 7, 0, 0)
    textBox.BackgroundTransparency = 1
    textBox.Text = defaultVal ~= nil and tostring(defaultVal) or ""
    textBox.PlaceholderText = tostring(placeholder or "Isi nominal...")
    textBox.PlaceholderColor3 = THEME.TextMuted
    textBox.TextColor3 = THEME.TextPrimary
    textBox.Font = Enum.Font.GothamSemibold
    textBox.TextSize = 12
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.TextWrapped = false
    textBox.ClearTextOnFocus = false
    textBox.ClipsDescendants = true
    textBox.Parent = boxWrapper

    local nilaiTerakhir = defaultVal

    local function parseNominal(rawText)
        if not numericOnly then
            return rawText
        end
        local str = tostring(rawText):gsub("%s+", "")
        if allowDecimal then
            str = str:gsub(",", "."):gsub("[^%d%.%-]", "")
        else
            -- Hapus titik/koma pemisah ribuan (misal 50.000 -> 50000)
            str = str:gsub("[^%d%-]", "")
        end
        local num = tonumber(str)
        if not num then return nil end
        if minVal ~= nil then num = math.max(minVal, num) end
        if maxVal ~= nil then num = math.min(maxVal, num) end
        return num
    end

    textBox.Focused:Connect(function()
        boxStroke.Color = THEME.Accent
    end)

    textBox.FocusLost:Connect(function()
        boxStroke.Color = THEME.Stroke
        if numericOnly then
            local parsed = parseNominal(textBox.Text)
            if parsed ~= nil then
                nilaiTerakhir = parsed
                textBox.Text = tostring(parsed)
                if callback then callback(parsed) end
            else
                textBox.Text = nilaiTerakhir ~= nil and tostring(nilaiTerakhir) or ""
            end
        else
            nilaiTerakhir = textBox.Text
            if callback then callback(textBox.Text) end
        end
    end)

    return {
        SetValue = function(_, newVal)
            nilaiTerakhir = newVal
            textBox.Text = tostring(newVal)
        end,
        GetValue = function()
            return nilaiTerakhir
        end
    }
end

-- ==========================================
-- KONVERSI OTOMATIS: SEMUA API.Slider JADI INPUT NOMINAL
-- ==========================================
function UI.Slider(tabPage, labelText, minVal, maxVal, stepVal, suffix, defaultVal, callback)
    local isDecimal = (typeof(stepVal) == "number" and stepVal < 1)
        or (typeof(defaultVal) == "number" and defaultVal % 1 ~= 0)

    return UI.Input(
        tabPage,
        labelText,
        tostring(defaultVal or minVal or 0),
        defaultVal,
        suffix,
        callback,
        {
            numericOnly = true,
            allowDecimal = isDecimal,
            min = minVal,
            max = maxVal
        }
    )
end

function UI.Toggle(tabPage, labelText, defaultVal, callback)
    local state = defaultVal == true

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = THEME.BgCard
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ClipsDescendants = true
    btn.Parent = tabPage
    addCorner(btn, 8)
    addStroke(btn, THEME.Stroke, 1)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -64, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = tostring(labelText or "Toggle")
    lbl.TextColor3 = THEME.TextPrimary
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ClipsDescendants = true
    lbl.Parent = btn

    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0, 40, 0, 20)
    pill.Position = UDim2.new(1, -50, 0.5, -10)
    pill.BackgroundColor3 = state and THEME.Success or THEME.BgInput
    pill.Parent = btn
    addCorner(pill, 10)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 14, 0, 14)
    dot.Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    dot.BackgroundColor3 = Color3.new(1, 1, 1)
    dot.Parent = pill
    addCorner(dot, 7)

    local function updateVisual()
        TweenService:Create(pill, TweenInfo.new(0.15), {
            BackgroundColor3 = state and THEME.Success or THEME.BgInput
        }):Play()
        TweenService:Create(dot, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        }):Play()
    end

    btn.MouseButton1Click:Connect(function()
        state = not state
        updateVisual()
        if callback then callback(state) end
    end)

    return {
        Set = function(_, newState)
            state = newState == true
            updateVisual()
        end
    }
end

function UI.Button(tabPage, labelText, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = THEME.AccentSoft
    btn.Text = tostring(labelText or "Button")
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.ClipsDescendants = true
    btn.Parent = tabPage
    addCorner(btn, 8)
    addStroke(btn, THEME.Accent, 1)

    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)

    return btn
end

function UI.Notify(title, desc, duration)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = THEME.BgHeader
    card.ClipsDescendants = true
    card.Parent = NotifHolder
    addCorner(card, 8)
    addStroke(card, THEME.Accent, 1.2)

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 7)
    pad.PaddingBottom = UDim.new(0, 7)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 2)
    layout.Parent = card

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, 0, 0, 0)
    tLbl.AutomaticSize = Enum.AutomaticSize.Y
    tLbl.BackgroundTransparency = 1
    tLbl.Text = tostring(title or "Info")
    tLbl.TextColor3 = THEME.TextPrimary
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextSize = 12
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.TextWrapped = true
    tLbl.ClipsDescendants = true
    tLbl.Parent = card

    local dLbl = Instance.new("TextLabel")
    dLbl.Size = UDim2.new(1, 0, 0, 0)
    dLbl.AutomaticSize = Enum.AutomaticSize.Y
    dLbl.BackgroundTransparency = 1
    dLbl.Text = tostring(desc or "")
    dLbl.TextColor3 = THEME.TextSecondary
    dLbl.Font = Enum.Font.Gotham
    dLbl.TextSize = 11
    dLbl.TextXAlignment = Enum.TextXAlignment.Left
    dLbl.TextWrapped = true
    dLbl.ClipsDescendants = true
    dLbl.Parent = card

    task.delay(duration or 3, function()
        if card and card.Parent then
            card:Destroy()
        end
    end)
end

return UI
