-- 저녁 교환 화면이에요. 오른쪽 아래 🔄 교환 버튼 → 사람 고르기 → 내밀 유물 고르기 → 보내기.
-- 누가 나에게 제안하면 가운데에 창이 떠요 : 받아 주면서 내 유물 하나를 고르거나, 거절해요.
-- 손가락으로 누르기 쉽게 버튼을 크게 만들었어요. 판정은 모두 서버가 해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArtifactDefs = require(ReplicatedStorage.ArtifactDefs)
local GameState = require(ReplicatedStorage.GameState)
local Remotes = require(ReplicatedStorage.Remotes)

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("MainGui")

local DARK = Color3.fromRGB(20, 24, 18)
local BUTTON = Color3.fromRGB(70, 95, 60)
local NO = Color3.fromRGB(120, 55, 45)
local WHITE = Color3.new(1, 1, 1)

local myItems = {} -- 내 유물 { Uid, TypeId }
local chosenTarget = nil -- 교환할 상대 번호

local function round(item: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = item
end

local function button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.TextColor3 = WHITE
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Text = text
	b.Parent = parent
	round(b, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	return b
end

local function panel(name: string, height: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.new(0.9, 0, 0, height)
	f.BackgroundColor3 = DARK
	f.BackgroundTransparency = 0.1
	f.Visible = false
	f.ZIndex = 20
	f.Parent = gui
	round(f, 14)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, height)
	limit.Parent = f
	return f
end

local function title(parent: Instance, text: string): TextLabel
	local l = Instance.new("TextLabel")
	l.Position = UDim2.new(0, 12, 0, 8)
	l.Size = UDim2.new(1, -24, 0, 50)
	l.BackgroundTransparency = 1
	l.TextColor3 = WHITE
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextWrapped = true
	l.Text = text
	l.ZIndex = 21
	l.Parent = parent
	return l
end

local function grid(parent: Instance, top: number, bottom: number, cell: Vector2): ScrollingFrame
	local g = Instance.new("ScrollingFrame")
	g.Position = UDim2.new(0, 12, 0, top)
	g.Size = UDim2.new(1, -24, 1, -(top + bottom))
	g.BackgroundTransparency = 1
	g.BorderSizePixel = 0
	g.ScrollBarThickness = 8
	g.AutomaticCanvasSize = Enum.AutomaticSize.Y
	g.CanvasSize = UDim2.new()
	g.ZIndex = 21
	g.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = g
	return g
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
end

-- 유물 버튼 (그림 + 이름)
local function itemButton(container: Instance, item, order: number): TextButton
	local def = ArtifactDefs.ById[item.TypeId]
	local b = button(container, def and (def.Icon .. "\n" .. def.Name) or item.TypeId, def and def.Color or BUTTON)
	b.LayoutOrder = order
	b.ZIndex = 22
	return b
end

----------------------------------------------------------------
-- 🔄 교환 버튼 (저녁에만 보여요)
----------------------------------------------------------------

local openButton = button(gui, "🔄 교환", BUTTON)
openButton.Name = "TradeButton"
openButton.AnchorPoint = Vector2.new(1, 1)
openButton.Position = UDim2.new(1, -10, 1, -140)
openButton.Size = UDim2.new(0, 150, 0, 54)
openButton.Visible = false

-- 1단계 : 사람 고르기
local pickPerson = panel("TradePickPerson", 360)
title(pickPerson, "🔄 누구와 바꿀까?")
local peopleGrid = grid(pickPerson, 66, 66, Vector2.new(140, 52))
local cancel1 = button(pickPerson, "닫기", NO)
cancel1.AnchorPoint = Vector2.new(0.5, 1)
cancel1.Position = UDim2.new(0.5, 0, 1, -10)
cancel1.Size = UDim2.new(0, 160, 0, 46)
cancel1.ZIndex = 22

-- 2단계 : 내밀 유물 고르기
local pickItem = panel("TradePickItem", 360)
local pickItemTitle = title(pickItem, "")
local myGrid = grid(pickItem, 66, 66, Vector2.new(90, 90))
local cancel2 = button(pickItem, "뒤로", NO)
cancel2.AnchorPoint = Vector2.new(0.5, 1)
cancel2.Position = UDim2.new(0.5, 0, 1, -10)
cancel2.Size = UDim2.new(0, 160, 0, 46)
cancel2.ZIndex = 22

-- 지금 교환할 수 있는 사람들 (살아 있는 플레이어와 NPC, 나는 빼고)
local function tradePartners()
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and not other:GetAttribute("Ghost") and other:GetAttribute("ArchId") then
			table.insert(list, { Id = other:GetAttribute("ArchId"), Name = other.DisplayName })
		end
	end
	local folder = Workspace:FindFirstChild("Archaeologists")
	if folder then
		for _, npc in folder:GetChildren() do
			if not npc:GetAttribute("Ghost") and npc:GetAttribute("ArchId") then
				table.insert(list, { Id = npc:GetAttribute("ArchId"), Name = npc:GetAttribute("DisplayName") or npc.Name })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

local function showItemPicker(targetName: string)
	pickItemTitle.Text = string.format("%s에게 어떤 유물을 내밀까?", targetName)
	clear(myGrid)
	for index, item in myItems do
		local b = itemButton(myGrid, item, index)
		b.Activated:Connect(function()
			Remotes.TradeOffer:FireServer("Propose", chosenTarget, item.Uid)
			pickItem.Visible = false
		end)
	end
	pickPerson.Visible = false
	pickItem.Visible = true
end

local function showPeople()
	clear(peopleGrid)
	for index, partner in tradePartners() do
		local b = button(peopleGrid, partner.Name, BUTTON)
		b.LayoutOrder = index
		b.ZIndex = 22
		b.Activated:Connect(function()
			chosenTarget = partner.Id
			showItemPicker(partner.Name)
		end)
	end
	pickPerson.Visible = true
end

openButton.Activated:Connect(function()
	if pickPerson.Visible or pickItem.Visible then
		pickPerson.Visible = false
		pickItem.Visible = false
	elseif #myItems > 0 then
		showPeople()
	end
end)
cancel1.Activated:Connect(function()
	pickPerson.Visible = false
end)
cancel2.Activated:Connect(function()
	pickItem.Visible = false
	pickPerson.Visible = true
end)

----------------------------------------------------------------
-- 받은 제안
----------------------------------------------------------------

local incoming = panel("TradeIncoming", 380)
local incomingTitle = title(incoming, "")
incomingTitle.Size = UDim2.new(1, -24, 0, 70)
local giveGrid = grid(incoming, 86, 66, Vector2.new(90, 90))
local refuse = button(incoming, "거절할래", NO)
refuse.AnchorPoint = Vector2.new(0.5, 1)
refuse.Position = UDim2.new(0.5, 0, 1, -10)
refuse.Size = UDim2.new(0, 180, 0, 46)
refuse.ZIndex = 22
local currentOffer = nil

refuse.Activated:Connect(function()
	if currentOffer then
		Remotes.TradeRespond:FireServer(currentOffer, false)
		currentOffer = nil
	end
	incoming.Visible = false
end)

Remotes.TradeOffer.OnClientEvent:Connect(function(kind: string, data)
	if kind == "Incoming" then
		currentOffer = data.OfferId
		local def = ArtifactDefs.ById[data.ItemType]
		local itemName = def and (def.Icon .. " " .. def.Name) or data.ItemType
		incomingTitle.Text = string.format("%s이(가) %s을(를) 줄 테니\n네 유물 하나랑 바꾸자고 해! 받으려면 줄 유물을 골라", data.FromName, itemName)
		clear(giveGrid)
		for index, item in myItems do
			local b = itemButton(giveGrid, item, index)
			b.Activated:Connect(function()
				if currentOffer == data.OfferId then
					Remotes.TradeRespond:FireServer(data.OfferId, true, item.Uid)
					currentOffer = nil
					incoming.Visible = false
				end
			end)
		end
		incoming.Visible = true
	elseif kind == "Closed" then
		if currentOffer == data.OfferId then
			currentOffer = nil
			incoming.Visible = false
		end
	end
end)

----------------------------------------------------------------
-- 내 유물 목록과 버튼 보이기
----------------------------------------------------------------

Remotes.InventoryUpdate.OnClientEvent:Connect(function(list)
	myItems = list
end)

local function refreshButton()
	local evening = GameState.Get("Phase") == "Evening"
	openButton.Visible = evening and not player:GetAttribute("Ghost")
	if not evening then
		pickPerson.Visible = false
		pickItem.Visible = false
		incoming.Visible = false
		currentOffer = nil
	end
end
GameState.Changed("Phase"):Connect(refreshButton)
player:GetAttributeChangedSignal("Ghost"):Connect(refreshButton)
refreshButton()
