-- 화면 UI예요. 위쪽 : 며칠째·낮밤·남은 시간·장작·식량. 왼쪽 아래 : 체력·점수·들고 있는 것.
-- 오른쪽 아래 🎒 버튼을 누르면 내 유물 목록이 열려요. 시간이 바뀌면 가운데에 큰 글씨가 떠요.
-- 숫자는 서버가 정해 준 것을 보여 주기만 해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ArtifactDefs = require(ReplicatedStorage.ArtifactDefs)
local Config = require(ReplicatedStorage.Config)
local GameState = require(ReplicatedStorage.GameState)
local Remotes = require(ReplicatedStorage.Remotes)

local UI = Config.UI
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")

local DARK = Color3.fromRGB(20, 24, 18)
local WHITE = Color3.new(1, 1, 1)
local PANEL_TRANSPARENCY = 0.35
local LOW_WOOD = Color3.fromRGB(255, 90, 70)

local PHASE_BANNERS = {
	Day = "☀️ %d일째 낮 : 유물·장작·식량을 찾아!",
	Evening = "🌇 저녁 : 캠프에 모여 밥 먹을 시간",
	Night = "🌙 밤이 됐어 : 모닥불 빛 안에 있어!",
	Morning = "🌅 아침 : 어젯밤 무슨 일이 있었지?",
}

----------------------------------------------------------------
-- 만들기 도우미
----------------------------------------------------------------

local function round(item: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = item
end

local function panel(name: string, anchor: Vector2, position: UDim2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = DARK
	frame.BackgroundTransparency = PANEL_TRANSPARENCY
	frame.Parent = gui
	round(frame, 12)
	return frame
end

local function text(parent: Instance, name: string, position: UDim2, size: UDim2, align: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.TextColor3 = WHITE
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = align or Enum.TextXAlignment.Center
	label.Text = ""
	label.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = UI.HudTextSize
	limit.Parent = label
	return label
end

----------------------------------------------------------------
-- 위쪽 : 날짜·시간·창고
----------------------------------------------------------------

local top = panel("TopBar", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 6), UDim2.new(0, 360, 0, 64))
local phaseLabel = text(top, "Phase", UDim2.new(0, 0, 0, 4), UDim2.new(1, 0, 0.5, -2))
local campLabel = text(top, "Camp", UDim2.new(0, 0, 0.5, 0), UDim2.new(1, 0, 0.5, -4))

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function refreshTop()
	local phase = GameState.Get("Phase")
	local info = GameState.PhaseInfo[phase] or GameState.PhaseInfo.Waiting
	local left = GameState.Get("PhaseEndsAt") - Workspace:GetServerTimeNow()
	if phase == "Waiting" or phase == "Result" then
		phaseLabel.Text = string.format("%s %s", info.Icon, info.Name)
	else
		phaseLabel.Text = string.format("%s %d일째 %s   ⏱ %s", info.Icon, GameState.Get("Day"), info.Name, formatTime(left))
	end
	local wood = GameState.Get("Wood")
	campLabel.Text = string.format("모닥불 장작 🪵 %d    식량 창고 🍖 %d", wood, GameState.Get("Food"))
	-- 장작이 모자라면 빨갛게 깜박여요
	if wood <= Config.Fire.BurnPerNight then
		local blinkOn = math.floor(os.clock() / Config.Fire.WarnBlinkSeconds) % 2 == 0
		campLabel.TextColor3 = blinkOn and LOW_WOOD or WHITE
	else
		campLabel.TextColor3 = WHITE
	end
end

----------------------------------------------------------------
-- 왼쪽 아래 : 체력·점수·들고 있는 것
----------------------------------------------------------------

local me = panel("Me", Vector2.new(0, 1), UDim2.new(0, 10, 1, -10), UDim2.new(0, 240, 0, 96))
local heartsLabel = text(me, "Hearts", UDim2.new(0, 10, 0, 4), UDim2.new(1, -20, 0.33, 0), Enum.TextXAlignment.Left)
local scoreLabel = text(me, "Score", UDim2.new(0, 10, 0.33, 0), UDim2.new(1, -20, 0.33, 0), Enum.TextXAlignment.Left)
local carryLabel = text(me, "Carry", UDim2.new(0, 10, 0.66, -2), UDim2.new(1, -20, 0.33, 0), Enum.TextXAlignment.Left)

local function refreshMe()
	if player:GetAttribute("Ghost") then
		heartsLabel.Text = "👻 유령이 됐어"
	else
		local value = player:GetAttribute("Health") or Config.Health.Start
		heartsLabel.Text = string.rep("❤️", value) .. string.rep("🤍", Config.Health.Max - value)
	end

	local stats = player:FindFirstChild("leaderstats")
	local score = stats and stats:FindFirstChild("점수")
	scoreLabel.Text = string.format("⭐ 점수 %d", score and score.Value or 0)

	local wood = player:GetAttribute("CarriedWood") or 0
	local food = player:GetAttribute("CarriedFood") or 0
	if wood == 0 and food == 0 then
		carryLabel.Text = "🤲 빈손"
	else
		carryLabel.Text = string.format("들고 있는 것 🪵 %d  🍖 %d", wood, food)
	end
end

----------------------------------------------------------------
-- 오른쪽 아래 : 🎒 유물 가방
----------------------------------------------------------------

local bagButton = Instance.new("TextButton")
bagButton.Name = "BagButton"
bagButton.AnchorPoint = Vector2.new(1, 1)
bagButton.Position = UDim2.new(1, -10, 1, -10)
bagButton.Size = UDim2.new(0, 150, 0, 60)
bagButton.BackgroundColor3 = DARK
bagButton.BackgroundTransparency = PANEL_TRANSPARENCY
bagButton.TextColor3 = WHITE
bagButton.Font = Enum.Font.FredokaOne
bagButton.TextScaled = true
bagButton.Text = "🎒 유물 0"
bagButton.Parent = gui
round(bagButton, 12)

local bag = panel("Bag", Vector2.new(1, 1), UDim2.new(1, -10, 1, -80), UDim2.new(0, 330, 0, 300))
bag.Visible = false
local bagTitle = text(bag, "Title", UDim2.new(0, 10, 0, 6), UDim2.new(1, -20, 0, 30), Enum.TextXAlignment.Left)
bagTitle.Text = "🎒 내 유물 (버릴 수 없어요)"

local grid = Instance.new("ScrollingFrame")
grid.Name = "Grid"
grid.Position = UDim2.new(0, 10, 0, 42)
grid.Size = UDim2.new(1, -20, 1, -52)
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 8
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.CanvasSize = UDim2.new()
grid.Parent = bag
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.new(0, 70, 0, 80)
layout.CellPadding = UDim2.new(0, 6, 0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

local emptyLabel = text(bag, "Empty", UDim2.new(0, 10, 0.4, 0), UDim2.new(1, -20, 0, 30))
emptyLabel.Text = "아직 없어. 유적에서 발굴해 봐!"

bagButton.Activated:Connect(function()
	bag.Visible = not bag.Visible
end)

local function showInventory(list)
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, item in list do
		local def = ArtifactDefs.ById[item.TypeId]
		if def then
			local cell = Instance.new("Frame")
			cell.LayoutOrder = index
			cell.BackgroundColor3 = def.Color
			cell.BackgroundTransparency = 0.5
			cell.Parent = grid
			round(cell, 10)
			local icon = text(cell, "Icon", UDim2.new(0, 0, 0, 2), UDim2.new(1, 0, 0.65, 0))
			icon.Text = def.Icon
			local limit = icon:FindFirstChildOfClass("UITextSizeConstraint")
			limit.MaxTextSize = 40
			local name = text(cell, "Name", UDim2.new(0, 0, 0.65, 0), UDim2.new(1, 0, 0.35, -2))
			name.Text = def.Name
		end
	end
	emptyLabel.Visible = #list == 0
	bagButton.Text = string.format("🎒 유물 %d", #list)
end

----------------------------------------------------------------
-- 가운데 큰 글씨 (시간이 바뀔 때)
----------------------------------------------------------------

local banner = text(gui, "Banner", UDim2.new(0.1, 0, 0.32, 0), UDim2.new(0.8, 0, 0, 60))
banner.TextStrokeTransparency = 0.2
banner.TextTransparency = 1
banner.TextStrokeTransparency = 1
banner:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 44

local function showBanner(message: string)
	banner.Text = message
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.2
	task.delay(UI.BannerSeconds, function()
		if banner.Text == message then
			TweenService:Create(banner, TweenInfo.new(UI.NotifyFadeSeconds), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

Remotes.PhaseChanged.OnClientEvent:Connect(function(phase: string, day: number)
	local format = PHASE_BANNERS[phase]
	if format then
		showBanner(string.format(format, day))
	end
end)

----------------------------------------------------------------
-- 가운데 해설 (밤마다 안개 이야기)
----------------------------------------------------------------

local narration = panel("Narration", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0.42, 0), UDim2.new(0.8, 0, 0, 110))
narration.BackgroundColor3 = Color3.new(0, 0, 0)
narration.Visible = false
local narrationLabel = text(narration, "Text", UDim2.new(0, 16, 0, 10), UDim2.new(1, -32, 1, -20))
narrationLabel.TextWrapped = true
narrationLabel.TextColor3 = Color3.fromRGB(215, 230, 220)
narrationLabel.Font = Enum.Font.Fantasy
narrationLabel:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = UI.NarrationTextSize

local narrationCount = 0
Remotes.Narration.OnClientEvent:Connect(function(message: string)
	narrationCount += 1
	local myTurn = narrationCount
	task.wait(UI.NarrationDelay)
	if myTurn ~= narrationCount then
		return
	end
	narrationLabel.Text = message
	narration.BackgroundTransparency = 1
	narrationLabel.TextTransparency = 1
	narration.Visible = true
	local fade = TweenInfo.new(UI.NarrationFadeSeconds)
	TweenService:Create(narration, fade, { BackgroundTransparency = PANEL_TRANSPARENCY }):Play()
	TweenService:Create(narrationLabel, fade, { TextTransparency = 0 }):Play()
	task.wait(UI.NarrationSeconds)
	if myTurn ~= narrationCount then
		return
	end
	TweenService:Create(narration, fade, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(narrationLabel, fade, { TextTransparency = 1 }):Play()
	task.wait(UI.NarrationFadeSeconds)
	if myTurn == narrationCount then
		narration.Visible = false
	end
end)

----------------------------------------------------------------
-- 시작
----------------------------------------------------------------

Remotes.InventoryUpdate.OnClientEvent:Connect(showInventory)
showInventory({})

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= Config.Time.LightingUpdateSeconds then
		elapsed = 0
		refreshTop()
		refreshMe()
	end
end)
