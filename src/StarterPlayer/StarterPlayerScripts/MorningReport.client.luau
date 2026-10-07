-- 아침마다 "어젯밤 본 것" 보고서를 보여줘요. 왼쪽은 괴물 발자국 지도, 오른쪽은 내가 본 것.
-- 지도 : 🔥 캠프(빛), 🏛️ 유적, 늪, 빨간 점 = 괴물 발자국, ❌ = 사라진 곳, 💥 = 누가 잡힌 곳, 하얀 점 = 아침에 캠프 밖에 있던 사람.
-- 닫아도 오른쪽 아래 📜 버튼으로 다시 볼 수 있어요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config)
local Remotes = require(ReplicatedStorage.Remotes)

local CLUE = Config.Clue
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")

local DARK = Color3.fromRGB(20, 24, 18)
local WHITE = Color3.new(1, 1, 1)
local MAP_BG = Color3.fromRGB(35, 60, 30)
local TRAIL = Color3.fromRGB(230, 60, 50)
local CAMP = Color3.fromRGB(255, 170, 80)
local SWAMP = Color3.fromRGB(45, 55, 35)
local RUIN = Color3.fromRGB(170, 165, 150)

local function round(item: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = item
end

local function label(parent: Instance, text: string, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = WHITE
	l.Font = Enum.Font.FredokaOne
	l.TextSize = size
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

----------------------------------------------------------------
-- 창 만들기
----------------------------------------------------------------

local panel = Instance.new("Frame")
panel.Name = "MorningReport"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.52)
panel.Size = UDim2.new(0.92, 0, 0, CLUE.MapPixels + 90)
panel.BackgroundColor3 = DARK
panel.BackgroundTransparency = 0.15
panel.Visible = false
panel.ZIndex = 30
panel.Parent = gui
round(panel, UDim.new(0, 14))
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(760, 600)
sizeLimit.Parent = panel

local title = label(panel, "", 24)
title.Position = UDim2.new(0, 14, 0, 8)
title.Size = UDim2.new(1, -70, 0, 32)
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 31

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -8, 0, 8)
close.Size = UDim2.new(0, 44, 0, 36)
close.BackgroundColor3 = Color3.fromRGB(80, 50, 40)
close.TextColor3 = WHITE
close.Font = Enum.Font.FredokaOne
close.TextScaled = true
close.Text = "✖"
close.ZIndex = 31
close.Parent = panel
round(close, UDim.new(0, 8))

local map = Instance.new("Frame")
map.Name = "Map"
map.Position = UDim2.new(0, 14, 0, 50)
map.Size = UDim2.new(0, CLUE.MapPixels, 0, CLUE.MapPixels)
map.BackgroundColor3 = MAP_BG
map.ClipsDescendants = true
map.ZIndex = 31
map.Parent = panel
round(map, UDim.new(0, 10))

local text = Instance.new("ScrollingFrame")
text.Name = "Lines"
text.Position = UDim2.new(0, CLUE.MapPixels + 28, 0, 50)
text.Size = UDim2.new(1, -(CLUE.MapPixels + 42), 1, -60)
text.BackgroundTransparency = 1
text.BorderSizePixel = 0
text.ScrollBarThickness = 6
text.AutomaticCanvasSize = Enum.AutomaticSize.Y
text.CanvasSize = UDim2.new()
text.ZIndex = 31
text.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = text

local reopen = Instance.new("TextButton")
reopen.Name = "ReportButton"
reopen.AnchorPoint = Vector2.new(1, 1)
reopen.Position = UDim2.new(1, -10, 1, -80)
reopen.Size = UDim2.new(0, 150, 0, 50)
reopen.BackgroundColor3 = DARK
reopen.BackgroundTransparency = 0.35
reopen.TextColor3 = WHITE
reopen.Font = Enum.Font.FredokaOne
reopen.TextScaled = true
reopen.Text = "📜 어젯밤"
reopen.Visible = false
reopen.Parent = gui
round(reopen, UDim.new(0, 12))

close.Activated:Connect(function()
	panel.Visible = false
end)
reopen.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)

----------------------------------------------------------------
-- 지도 그리기
----------------------------------------------------------------

-- 지도 좌표(-1~1)를 화면 위치로
local function at(point): UDim2
	return UDim2.fromScale(0.5 + point.X / 2, 0.5 + point.Y / 2)
end

local function dot(point, pixels: number, color: Color3, z: number): Frame
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = at(point)
	d.Size = UDim2.new(0, pixels, 0, pixels)
	d.BackgroundColor3 = color
	d.BorderSizePixel = 0
	d.ZIndex = z
	d.Parent = map
	round(d, UDim.new(0.5, 0))
	return d
end

local function marker(point, icon: string, size: number, z: number)
	local m = label(map, icon, size)
	m.AnchorPoint = Vector2.new(0.5, 0.5)
	m.Position = at(point)
	m.Size = UDim2.new(0, size * 2, 0, size * 2)
	m.ZIndex = z
	return m
end

local function drawMap(data)
	for _, child in map:GetChildren() do
		if not child:IsA("UICorner") then
			child:Destroy()
		end
	end
	local pixels = CLUE.MapPixels
	for _, swamp in data.Swamps do
		local d = dot(swamp, math.max(4, swamp.Size * pixels / 2), SWAMP, 32)
		d.BackgroundTransparency = 0.2
	end
	-- 캠프 = 모닥불 빛 반경
	local camp = dot({ X = 0, Y = 0 }, math.max(8, data.CampRadius * pixels), CAMP, 33)
	camp.BackgroundTransparency = 0.45
	marker({ X = 0, Y = 0 }, "🔥", 12, 34)
	for _, ruin in data.Ruins do
		local d = dot(ruin, 8, RUIN, 34)
		round(d, UDim.new(0, 2))
		local name = label(map, ruin.Name, 10)
		name.AnchorPoint = Vector2.new(0.5, 0)
		name.Position = at(ruin) + UDim2.fromOffset(0, 5)
		name.Size = UDim2.new(0, 70, 0, 12)
		name.TextColor3 = RUIN
		name.ZIndex = 34
	end
	-- 괴물 발자국
	for _, point in data.Trail do
		dot(point, 4, TRAIL, 35)
	end
	if data.Catch then
		marker(data.Catch, "💥", 14, 37)
	end
	if data.Vanish then
		marker(data.Vanish, "❌", 14, 37)
	end
	-- 아침에 캠프 밖에 있던 사람
	for _, person in data.Outside do
		dot(person, 6, WHITE, 36)
		local name = label(map, person.Name, 11)
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = at(person) - UDim2.fromOffset(0, 4)
		name.Size = UDim2.new(0, 70, 0, 12)
		name.ZIndex = 36
	end
	marker({ X = 0, Y = -0.92 }, "북 ⬆", 11, 38)
end

----------------------------------------------------------------
-- 보고서 받기
----------------------------------------------------------------

Remotes.MorningReport.OnClientEvent:Connect(function(report)
	title.Text = report.Title
	for _, child in text:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for index, line in report.Lines do
		local l = label(text, line, 18)
		l.LayoutOrder = index
		l.Size = UDim2.new(1, -8, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.ZIndex = 32
	end
	drawMap(report.Map)
	panel.Visible = true
	reopen.Visible = true
end)
