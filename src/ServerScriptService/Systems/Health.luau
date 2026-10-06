-- 모든 고고학자는 체력 3칸(❤️❤️❤️)으로 시작해요. 체력은 머리 위와 화면에 보여요.
-- 저녁마다 한 사람에 식량 1개씩 먹어요. 먹으면 1칸 회복, 못 먹으면 1칸 줄어요. (어제 굶은 사람 먼저 먹여요)
-- 체력이 0이 되면 쓰러져서 유령이 되고, 유언으로 유물을 살아 있는 사람들에게 나눠 줘요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Config)
local Remotes = require(ReplicatedStorage.Remotes)
local Signal = require(ReplicatedStorage.Signal)
local Systems = ServerScriptService.Systems
local Roster = require(Systems.Roster)
local CampStore = require(Systems.CampStore)
local Inventory = require(Systems.Inventory)

local HEALTH = Config.Health

local Health = {}

Health.BecameGhost = Signal.new() -- (who, reason, willList)

local rng = Random.new()

local function hearts(value: number): string
	return string.rep("❤️", value) .. string.rep("🤍", HEALTH.Max - value)
end

function Health.Get(who: Instance): number
	return who:GetAttribute("Health") or HEALTH.Start
end

-- 머리 위 체력 표시
local function updateOverhead(who: Instance)
	local character = Roster.GetCharacter(who)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = head:FindFirstChild("HealthGui")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "HealthGui"
		gui.Size = UDim2.fromScale(3, 0.8)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 60
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Hearts"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Parent = gui
		gui.Parent = head
	end
	gui.Hearts.Text = Roster.IsGhost(who) and "👻" or hearts(Health.Get(who))
end

local function setHealth(who: Instance, value: number)
	who:SetAttribute("Health", math.clamp(value, 0, HEALTH.Max))
	updateOverhead(who)
end

-- 유령 모습 : 몸이 반쯤 투명해져요 (자세한 유령 모드는 마일스톤 8)
local function applyGhostLook(who: Instance)
	local character = Roster.GetCharacter(who)
	if not character then
		return
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Transparency = math.max(part.Transparency, HEALTH.GhostTransparency)
		end
	end
end

-- 유령 모습 지우기 (새 탐사에서 NPC가 다시 살아날 때)
local function clearGhostLook(who: Instance)
	local character = Roster.GetCharacter(who)
	if not character then
		return
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Transparency = 0
		end
	end
end

-- 쓰러져서 유령이 돼요
function Health.MakeGhost(who: Instance, reason: string)
	if Roster.IsGhost(who) then
		return
	end
	who:SetAttribute("Ghost", true)
	setHealth(who, 0)
	applyGhostLook(who)
	who:SetAttribute("CarriedWood", 0)
	who:SetAttribute("CarriedFood", 0)
	local will = Inventory.DistributeWill(who, reason)
	Remotes.Notify:FireAllClients(string.format("👻 %s이(가) 쓰러져서 유령이 됐어...", Roster.GetName(who)))
	Health.BecameGhost:Fire(who, reason, will)
end

-- 체력을 깎아요 (괴물 뿌리치기 등). 0이 되면 유령
function Health.Damage(who: Instance, amount: number, reason: string)
	setHealth(who, Health.Get(who) - amount)
	if Health.Get(who) <= 0 then
		Health.MakeGhost(who, reason)
	end
end

-- 저녁 식사
function Health.EveningMeal()
	local alive = Roster.GetAlive()
	-- 어제 굶은 사람 먼저, 나머지는 무작위 순서
	for i = #alive, 2, -1 do
		local j = rng:NextInteger(1, i)
		alive[i], alive[j] = alive[j], alive[i]
	end
	table.sort(alive, function(a, b)
		return (a:GetAttribute("Hungry") and 1 or 0) > (b:GetAttribute("Hungry") and 1 or 0)
	end)

	for _, who in alive do
		if CampStore.TakeFood(Config.Food.EatPerPerson) >= Config.Food.EatPerPerson then
			who:SetAttribute("Hungry", false)
			setHealth(who, Health.Get(who) + HEALTH.GainWhenFed)
			if who:IsA("Player") then
				Remotes.Notify:FireClient(who, "🍖 저녁을 먹었어! " .. hearts(Health.Get(who)))
			end
		else
			who:SetAttribute("Hungry", true)
			setHealth(who, Health.Get(who) - HEALTH.LoseWhenHungry)
			if who:IsA("Player") then
				Remotes.Notify:FireClient(who, "😢 먹을 게 모자라서 굶었어... " .. hearts(Health.Get(who)))
			end
			if Health.Get(who) <= 0 then
				Health.MakeGhost(who, "Starved")
			end
		end
	end
end

-- 새 탐사 : 모두 살아나고 체력 가득
function Health.Reset()
	for _, who in Roster.GetAll() do
		local wasGhost = Roster.IsGhost(who)
		who:SetAttribute("Ghost", false)
		who:SetAttribute("Hungry", false)
		setHealth(who, HEALTH.Start)
		if wasGhost and who:IsA("Player") and who.Character then
			who:LoadCharacter() -- 유령 모습을 지우고 캠프에서 다시 시작
		elseif wasGhost then
			clearGhostLook(who)
		end
	end
end

function Health.Init()
	local function setup(who: Instance)
		if who:GetAttribute("Health") == nil then
			who:SetAttribute("Health", HEALTH.Start)
		end
		if who:IsA("Player") then
			who.CharacterAdded:Connect(function(character)
				character:WaitForChild("Head")
				updateOverhead(who)
				if Roster.IsGhost(who) then
					applyGhostLook(who)
				end
			end)
			if who.Character then
				updateOverhead(who)
			end
		else
			updateOverhead(who)
			if Roster.IsGhost(who) then
				applyGhostLook(who)
			end
		end
	end
	Roster.Joined:Connect(setup)
end

return Health
