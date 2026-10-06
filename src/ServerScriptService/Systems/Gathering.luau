-- 나무 밑에서 장작을, 정글에서 식량(버섯·열매·바나나·덫, 사냥한 고기)을 주워요.
-- 주운 것은 손에 들고 있다가, 모닥불 가까이 오면 자동으로 캠프 창고에 내려놔요.
-- 하루에 나오는 장작·식량 자리 수는 정해져 있고 낮이 시작될 때마다 새로 나와요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Config)
local Remotes = require(ReplicatedStorage.Remotes)
local Systems = ServerScriptService.Systems
local MapBuilder = require(Systems.MapBuilder)
local Roster = require(Systems.Roster)
local CampStore = require(Systems.CampStore)
local ScoreStore = require(Systems.ScoreStore)
local Excavation = require(Systems.Excavation)

local Gathering = {}

local KIND_LABELS = {
	Food = "🍖 식량",
	Wood = "🪵 장작",
}
local FOOD_NAMES = {
	Mushroom = "버섯",
	Berry = "열매",
	Banana = "바나나",
	Trap = "덫",
}

local rng = Random.new()
local woodSpots = {} -- { Spot, Prompt, Active }
local foodSpots = {}

----------------------------------------------------------------
-- 손에 든 것
----------------------------------------------------------------

-- 손에 든 개수는 플레이어(또는 NPC)에 "CarriedFood", "CarriedWood"로 붙어 있어요
function Gathering.GetCarried(who: Instance, kind: string): number
	return (who:GetAttribute("Carried" .. kind) :: number?) or 0
end

function Gathering.AddCarried(who: Instance, kind: string, amount: number)
	local total = Gathering.GetCarried(who, kind) + amount
	who:SetAttribute("Carried" .. kind, total)
	if who:IsA("Player") then
		Remotes.Notify:FireClient(who, string.format("%s %d개를 주웠어! 모닥불로 가져가자 (들고 있는 것 %d개)", KIND_LABELS[kind], amount, total))
	end
	Excavation.RollLuckyFind(who, kind == "Wood" and "나뭇가지 밑 흙 속에서" or "풀숲을 뒤지다가")
end

-- 들고 있는 것을 캠프 창고에 내려놔요
function Gathering.Deliver(who: Instance)
	local wood = Gathering.GetCarried(who, "Wood")
	local food = Gathering.GetCarried(who, "Food")
	if wood == 0 and food == 0 then
		return
	end
	who:SetAttribute("CarriedWood", 0)
	who:SetAttribute("CarriedFood", 0)
	CampStore.AddWood(wood)
	CampStore.AddFood(food)
	local points = wood * Config.Score.Wood + food * Config.Score.Food
	ScoreStore.AddScore(who, points)
	if who:IsA("Player") then
		local parts = {}
		if wood > 0 then
			table.insert(parts, string.format("🪵 장작 %d개", wood))
		end
		if food > 0 then
			table.insert(parts, string.format("🍖 식량 %d개", food))
		end
		Remotes.Notify:FireClient(who, string.format("%s를 캠프에 내려놨어! (+%d점)", table.concat(parts, ", "), points))
	end
end

-- 손에 든 것을 버려요 (쓰러졌을 때, 새 탐사)
function Gathering.ClearCarried(who: Instance)
	who:SetAttribute("CarriedWood", 0)
	who:SetAttribute("CarriedFood", 0)
end

----------------------------------------------------------------
-- 장작·식량 자리
----------------------------------------------------------------

local function setVisible(parts, visible: boolean)
	for _, part in parts do
		part.Transparency = visible and 0 or 1
	end
end

local function setActive(entry, active: boolean)
	entry.Active = active
	entry.ReservedBy = nil
	entry.Prompt.Enabled = active
	setVisible(entry.Visuals, active)
end

local function makeSpot(part: BasePart, visuals, actionText: string, objectText: string, seconds: number, distance: number, onTaken)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = seconds
	prompt.MaxActivationDistance = distance
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	local entry = { Spot = part, Prompt = prompt, Visuals = visuals, Active = true, OnTaken = onTaken, ReservedBy = nil }
	prompt.Triggered:Connect(function(player)
		Gathering.TakeSpot(entry, player)
	end)
	return entry
end

-- 자리 하나를 가져가요 (플레이어든 NPC든)
function Gathering.TakeSpot(entry, who: Instance)
	if not entry.Active or Roster.IsGhost(who) then
		return false
	end
	setActive(entry, false)
	entry.OnTaken(who)
	return true
end

-- 오늘 나올 자리를 무작위로 골라요
local function refill(list, activeCount: number)
	local order = {}
	for i = 1, #list do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for rank, index in order do
		setActive(list[index], rank <= activeCount)
	end
end

function Gathering.RefillDaily()
	refill(woodSpots, Config.Fire.WoodSpotsActivePerDay)
	refill(foodSpots, Config.Food.SpotsActivePerDay)
end

-- NPC가 쓸 수 있게 : 지금 주울 수 있는 자리들
function Gathering.GetActiveWoodSpots()
	local list = {}
	for _, entry in woodSpots do
		if entry.Active then
			table.insert(list, entry)
		end
	end
	return list
end

function Gathering.GetActiveFoodSpots()
	local list = {}
	for _, entry in foodSpots do
		if entry.Active then
			table.insert(list, entry)
		end
	end
	return list
end

----------------------------------------------------------------
-- 시작
----------------------------------------------------------------

function Gathering.Init()
	local info = MapBuilder.Info

	for _, wood in info.WoodSpots do
		local visuals = {}
		for _, part in wood.Model:GetChildren() do
			if part.Name == "WoodPiece" then
				table.insert(visuals, part)
			end
		end
		local entry = makeSpot(wood.Part, visuals, "장작 줍기", "🪵 나뭇가지", Config.Fire.ChopSeconds, Config.Fire.PromptDistance, function(who)
			Gathering.AddCarried(who, "Wood", Config.Fire.WoodPerChop)
		end)
		entry.Kind = "Wood"
		table.insert(woodSpots, entry)
	end

	for _, food in info.FoodSpots do
		local visuals = {}
		for _, part in food.Model:GetDescendants() do
			if part:IsA("BasePart") and part ~= food.Part then
				table.insert(visuals, part)
			end
		end
		local name = FOOD_NAMES[food.Kind] or food.Kind
		local entry = makeSpot(food.Part, visuals, "줍기", "🍖 " .. name, Config.Food.GatherSeconds, Config.Food.PromptDistance, function(who)
			Gathering.AddCarried(who, "Food", Config.Food.FoodPerGather)
		end)
		entry.Kind = "Food"
		table.insert(foodSpots, entry)
	end

	Gathering.RefillDaily()

	-- 모닥불 가까이 온 사람은 들고 온 것을 자동으로 내려놔요
	task.spawn(function()
		while true do
			task.wait(Config.Camp.DeliverCheckSeconds)
			local fire = MapBuilder.Info.FirePosition
			for _, who in Roster.GetAlive() do
				local root = Roster.GetRoot(who)
				if root and (root.Position - fire).Magnitude <= Config.Camp.DeliverRadius then
					Gathering.Deliver(who)
				end
			end
		end
	end)
end

return Gathering
