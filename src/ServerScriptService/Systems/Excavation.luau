-- 유적 터에서 유물을 발굴해요. 흙더미에서 4초 동안 누르고 있으면 유물 하나가 나와요.
-- 터마다 하루 2~3개만 나오고, 낮이 시작될 때마다 다시 묻혀요.
-- 발굴한 유물은 바로 그 사람 소지품이 돼요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtifactDefs = require(ReplicatedStorage.ArtifactDefs)
local Config = require(ReplicatedStorage.Config)
local GameState = require(ReplicatedStorage.GameState)
local Remotes = require(ReplicatedStorage.Remotes)
local Systems = ServerScriptService.Systems
local MapBuilder = require(Systems.MapBuilder)
local Roster = require(Systems.Roster)
local Inventory = require(Systems.Inventory)
local ScoreStore = require(Systems.ScoreStore)

local Excavation = {}

local rng = Random.new()
local sites = {} -- 유적 번호 → { Ruin, Prompt, Label, Remaining }

local function refreshSite(site)
	local name = site.Ruin.Name
	if site.Remaining > 0 then
		site.Label.Text = string.format("🏛️ %s (유물 %d)", name, site.Remaining)
	else
		site.Label.Text = string.format("🏛️ %s (오늘은 다 캤어)", name)
	end
	site.Prompt.Enabled = site.Remaining > 0
end

-- 유물 하나를 발굴해요 (플레이어든 NPC든). 나온 유물을 돌려줘요
function Excavation.Dig(who: Instance, ruinId: number)
	local site = sites[ruinId]
	if not site or site.Remaining <= 0 or Roster.IsGhost(who) then
		return nil
	end
	site.Remaining -= 1
	refreshSite(site)

	local typeId = ArtifactDefs.RandomId(rng)
	local item = Inventory.Add(who, typeId, { Day = GameState.Get("Day"), RuinId = ruinId })
	ScoreStore.AddScore(who, Config.Score.Dig)
	if who:IsA("Player") then
		local def = ArtifactDefs.ById[typeId]
		Remotes.Notify:FireClient(who, string.format("%s %s을(를) 발굴했어! (+%d점)", def.Icon, def.Name, Config.Score.Dig))
	end
	return item
end

-- 새 하루 : 터마다 2~3개씩 다시 묻어요
function Excavation.RefillAll()
	for _, site in sites do
		site.Remaining = rng:NextInteger(Config.Dig.MinPerRuinPerDay, Config.Dig.MaxPerRuinPerDay)
		refreshSite(site)
	end
end

-- NPC가 쓸 수 있게 : 아직 유물이 남은 터들
function Excavation.GetOpenRuins()
	local list = {}
	for _, site in sites do
		if site.Remaining > 0 then
			table.insert(list, site.Ruin)
		end
	end
	return list
end

function Excavation.Init()
	for _, ruin in MapBuilder.Info.Ruins do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "발굴하기"
		prompt.ObjectText = "🏛️ " .. ruin.Name
		prompt.HoldDuration = Config.Dig.DigSeconds
		prompt.MaxActivationDistance = Config.Dig.PromptDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = ruin.DigSpot

		local site = {
			Ruin = ruin,
			Prompt = prompt,
			Label = ruin.DigSpot:FindFirstChild("Label"):FindFirstChildOfClass("TextLabel"),
			Remaining = 0,
		}
		sites[ruin.Id] = site
		prompt.Triggered:Connect(function(player)
			Excavation.Dig(player, ruin.Id)
		end)
	end
	Excavation.RefillAll()
end

return Excavation
