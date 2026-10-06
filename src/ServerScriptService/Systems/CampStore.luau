-- 캠프의 장작 더미와 식량 창고 숫자를 관리해요.
-- 장작 수에 따라 모닥불 빛 반경(안전지대)이 커지고 작아져요. 밤마다 장작이 타요.
-- 밤이 시작될 때 장작이 하나도 없으면 괴물이 캠프를 덮쳐요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Config)
local GameState = require(ReplicatedStorage.GameState)
local MapBuilder = require(ServerScriptService.Systems.MapBuilder)

local FIRE = Config.Fire

local CampStore = {}

local function refreshLabels()
	local info = MapBuilder.Info
	info.WoodLabel.Text = string.format("🪵 장작 %d", GameState.Get("Wood"))
	info.FoodLabel.Text = string.format("🍖 식량 %d", GameState.Get("Food"))
end

function CampStore.GetWood(): number
	return GameState.Get("Wood")
end

function CampStore.GetFood(): number
	return GameState.Get("Food")
end

function CampStore.AddWood(amount: number)
	GameState.Set("Wood", CampStore.GetWood() + amount)
	refreshLabels()
end

function CampStore.AddFood(amount: number)
	GameState.Set("Food", CampStore.GetFood() + amount)
	refreshLabels()
end

-- 식량을 꺼내요. 실제로 꺼낸 개수를 돌려줘요
function CampStore.TakeFood(amount: number): number
	local taken = math.min(amount, CampStore.GetFood())
	GameState.Set("Food", CampStore.GetFood() - taken)
	refreshLabels()
	return taken
end

-- 밤이 시작될 때 장작을 태워요. 장작이 하나도 없었으면 false
function CampStore.BurnForNight(): boolean
	local wood = CampStore.GetWood()
	if wood <= 0 then
		return false
	end
	GameState.Set("Wood", math.max(0, wood - FIRE.BurnPerNight))
	refreshLabels()
	return true
end

-- 지금 장작으로 빛이 닿는 거리 (안전지대 반경)
function CampStore.GetLightRadius(): number
	local wood = CampStore.GetWood()
	if wood <= 0 then
		return Config.Camp.EmberRadius
	end
	return math.min(FIRE.MaxLightRadius, FIRE.BaseLightRadius + FIRE.RadiusPerWood * (wood - 1))
end

-- 이 위치가 모닥불 빛 안인가? (괴물은 빛 안으로 못 들어와요)
function CampStore.IsInLight(position: Vector3): boolean
	local fire = MapBuilder.Info.FirePosition
	local offset = Vector3.new(position.X - fire.X, 0, position.Z - fire.Z)
	return offset.Magnitude <= CampStore.GetLightRadius()
end

function CampStore.Reset()
	GameState.Set("Wood", FIRE.StartWood)
	GameState.Set("Food", Config.Food.StartFood)
	refreshLabels()
end

function CampStore.Init()
	CampStore.Reset()
end

return CampStore
