-- 정글 소리를 틀어요. 낮엔 새·벌레, 밤엔 귀뚜라미, 밤낮으로 으스스한 바람.
-- 가끔 근처 동물(부엉이, 원숭이, 개구리…)이 있는 자리에서 울음소리가 들려요.
-- 소리 번호는 Config.Sounds에서 바꿀 수 있어요. 빈칸이면 그 소리는 안 나요.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config)
local S = Config.Sounds
local W = Config.Wildlife

local rng = Random.new()

local function isNight(): boolean
	local t = Lighting.ClockTime
	return t >= W.NightStartsAt or t < W.NightEndsAt
end

local function assetId(id: string): string
	return "rbxassetid://" .. id
end

----------------------------------------------------------------
-- 계속 깔리는 배경 소리
----------------------------------------------------------------

local function makeLoop(name: string, id: string): Sound?
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = assetId(id)
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	return sound
end

local dayLoop = makeLoop("JungleDay", S.DayLoop)
local nightLoop = makeLoop("JungleNight", S.NightLoop)
local eerieLoop = makeLoop("JungleEerie", S.EerieLoop)

local fadeInfo = TweenInfo.new(S.FadeSeconds, Enum.EasingStyle.Sine)
local function fadeTo(sound: Sound?, volume: number)
	if sound then
		TweenService:Create(sound, fadeInfo, { Volume = volume }):Play()
	end
end

local lastNight = nil
local function updateLoops()
	local night = isNight()
	if night == lastNight then
		return
	end
	lastNight = night
	fadeTo(dayLoop, night and 0 or S.DayLoopVolume)
	fadeTo(nightLoop, night and S.NightLoopVolume or 0)
	fadeTo(eerieLoop, night and S.EerieNightVolume or S.EerieDayVolume)
end

----------------------------------------------------------------
-- 가끔 들리는 동물 울음소리
----------------------------------------------------------------

-- 지금 울 수 있는 동물 종류들 (소리 번호가 있고, 시간대가 맞는 것)
local function callableKinds(night: boolean)
	local kinds = {}
	for kind, call in S.Calls do
		if call.Id ~= "" and (call.Night == nil or call.Night == night) then
			table.insert(kinds, kind)
		end
	end
	return kinds
end

local function playCall()
	local folder = Workspace:FindFirstChild("Generated")
	folder = folder and folder:FindFirstChild("Wildlife")
	if not folder then
		return
	end
	local kinds = callableKinds(isNight())
	if #kinds == 0 then
		return
	end
	local kind = kinds[rng:NextInteger(1, #kinds)]
	local camera = Workspace.CurrentCamera.CFrame.Position

	-- 가까운 그 동물 중 하나가 울어요
	local nearby = {}
	for _, model in folder:GetChildren() do
		if model:GetAttribute("Kind") == kind then
			local root = model:FindFirstChild("Root")
			if root and (root.Position - camera).Magnitude < S.CallMaxDistance then
				table.insert(nearby, root)
			end
		end
	end
	if #nearby == 0 then
		return
	end
	local root = nearby[rng:NextInteger(1, #nearby)]
	local call = S.Calls[kind]

	local sound = Instance.new("Sound")
	sound.SoundId = assetId(call.Id)
	sound.Volume = call.Volume
	sound.PlaybackSpeed = rng:NextNumber(0.9, 1.1)
	sound.RollOffMinDistance = S.CallRollOffMin
	sound.RollOffMaxDistance = S.CallRollOffMax
	sound.Parent = root
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(S.CallMaxSeconds * 4, function()
		if sound.Parent then
			sound:Destroy() -- 소리를 못 불러왔을 때를 대비한 청소
		end
	end)
	sound:Play()
end

----------------------------------------------------------------
-- 시작
----------------------------------------------------------------

task.spawn(function()
	while true do
		updateLoops()
		task.wait(1)
	end
end)

task.spawn(function()
	while true do
		task.wait(rng:NextNumber(S.CallMinSeconds, S.CallMaxSeconds))
		playCall()
	end
end)
