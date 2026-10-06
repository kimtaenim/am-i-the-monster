-- 하늘 시계(해와 달)와 안개를 시간에 맞춰 천천히 바꿔요.
-- 밤에는 정체불명의 짙은 안개가 끼고, 모닥불 빛 반경(장작 수에 비례)이 안전지대가 돼요.
-- 저녁·밤에는 안전지대 테두리가 땅에 보여요.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config)
local GameState = require(ReplicatedStorage.GameState)
local MapBuilder = require(ServerScriptService.Systems.MapBuilder)
local CampStore = require(ServerScriptService.Systems.CampStore)

local TIME = Config.Time
local A = Config.Atmosphere

-- 시간대마다 하늘 시계가 어디서 어디로 가는지
local CLOCK = {
	Day = { TIME.ClockDayStart, TIME.ClockDayEnd },
	Evening = { TIME.ClockDayEnd, TIME.ClockEveningEnd },
	Night = { TIME.ClockEveningEnd, TIME.ClockNightEnd },
	Morning = { TIME.ClockNightEnd, TIME.ClockMorningEnd },
	Result = { TIME.ClockDayStart, TIME.ClockDayStart },
	Ending = { 0, 0 }, -- 한밤중
	Waiting = { TIME.ClockDayStart, TIME.ClockDayStart },
}

local DayCycle = {}

local phaseStartedAt = 0

-- 지금 시간대가 얼마나 지났나 (0~1)
local function progress(): number
	local endsAt = GameState.Get("PhaseEndsAt")
	local total = endsAt - phaseStartedAt
	if total <= 0 then
		return 1
	end
	return math.clamp((Workspace:GetServerTimeNow() - phaseStartedAt) / total, 0, 1)
end

-- 얼마나 밤인가 (0 = 낮, 1 = 한밤)
local function nightAmount(phase: string, k: number): number
	if phase == "Evening" then
		return k
	elseif phase == "Night" or phase == "Ending" then
		return 1
	elseif phase == "Morning" then
		return 1 - k
	end
	return 0
end

local function update()
	local phase = GameState.Get("Phase")
	local k = progress()
	local clock = CLOCK[phase] or CLOCK.Day
	Lighting.ClockTime = (clock[1] + (clock[2] - clock[1]) * k) % 24

	local n = nightAmount(phase, k)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = A.DayDensity + (A.NightDensity - A.DayDensity) * n
		atmosphere.Color = A.DayColor:Lerp(A.NightColor, n)
		atmosphere.Decay = A.DayDecay:Lerp(A.NightDecay, n)
	end
	Lighting.Ambient = A.DayAmbient:Lerp(A.NightAmbient, n)
	Lighting.OutdoorAmbient = Lighting.Ambient
	Lighting.Brightness = A.DayBrightness + (A.NightBrightness - A.DayBrightness) * n

	-- 모닥불 빛과 안전지대 테두리
	local info = MapBuilder.Info
	local radius = CampStore.GetLightRadius()
	info.FireLight.Range = radius
	info.FireLight.Brightness = Config.Camp.LightBrightness
	info.FireEffect.Enabled = CampStore.GetWood() > 0 or phase ~= "Night"
	local ring = info.SafeRing
	ring.Size = Vector3.new(ring.Size.X, radius * 2, radius * 2)
	ring.Transparency = 1 - (1 - Config.Camp.SafeRingTransparency) * n
end

function DayCycle.Init()
	GameState.Changed("PhaseEndsAt"):Connect(function()
		phaseStartedAt = Workspace:GetServerTimeNow()
	end)
	task.spawn(function()
		while true do
			update()
			task.wait(TIME.LightingUpdateSeconds)
		end
	end)
end

return DayCycle
