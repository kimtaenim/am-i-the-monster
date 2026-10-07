-- 밤마다 모든 고고학자가 무작위 시간에 15~20초 동안 졸아요. 조는 동안은 움직일 수 없어요.
-- 저주 보유자가 조는 시간이 바로 괴물이 돌아다니는 시간이에요. 본인은 아무것도 몰라요.
-- 깨어나면 저주 보유자는 괴물이 사라진 자리에 서 있어요. ("...어, 내가 왜 여기 있지?")
-- 누가 조는지는 서버만 알아요. (화면에 알리면 괴물 시간과 맞춰 보고 범인을 알 수 있으니까요)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Config)
local Remotes = require(ReplicatedStorage.Remotes)
local Signal = require(ReplicatedStorage.Signal)
local Systems = ServerScriptService.Systems
local Roster = require(Systems.Roster)
local Curse = require(Systems.Curse)
local Monster = require(Systems.Monster)

local NIGHT = Config.Night
local WAKE_CONFUSED = "...어, 내가 왜 여기 있지?"

local Sleep = {}

Sleep.Started = Signal.new() -- (who)
Sleep.Ended = Signal.new() -- (who)

local rng = Random.new()
local nightToken = 0 -- 밤마다 바뀌는 번호 (지난밤 예약이 오늘 밤에 끼어들지 않게)
local savedMovement = {} -- 몸 → { WalkSpeed, JumpPower, JumpHeight }
local sleeping = {} -- 조는 사람 → true
local wokeElsewhere = {} -- 괴물이 먼저 사라져서 엉뚱한 곳에서 깰 사람 → true
local confusedTonight = {} -- 오늘 밤 엉뚱한 곳에서 깨어난 사람 → true (NPC는 어리둥절해서 아침까지 그 자리에)

function Sleep.IsSleeping(who: Instance): boolean
	return sleeping[who] == true
end

local function freeze(who: Instance, frozen: boolean)
	local character = Roster.GetCharacter(who)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if frozen then
		savedMovement[humanoid] = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight }
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	else
		local saved = savedMovement[humanoid]
		if saved then
			humanoid.WalkSpeed = saved.WalkSpeed
			humanoid.JumpPower = saved.JumpPower
			humanoid.JumpHeight = saved.JumpHeight
			savedMovement[humanoid] = nil
		end
	end
end

local function fallAsleep(who: Instance)
	if Sleep.IsSleeping(who) or Roster.IsGhost(who) then
		return
	end
	sleeping[who] = true
	freeze(who, true)
	if who:IsA("Player") then
		Remotes.SleepState:FireClient(who, true)
	end
	Sleep.Started:Fire(who)
	-- 저주 보유자가 졸면 괴물이 나타나요
	if Curse.IsHolder(who) then
		Monster.Activate(who)
	end
end

local function wakeUp(who: Instance)
	if not Sleep.IsSleeping(who) then
		return
	end
	local wasMonster = Monster.GetHolder() == who
	if wasMonster then
		Monster.Vanish() -- 괴물이 사라지고 그 자리에 다시 나타나요
	end
	-- 괴물이 오늘 밤 누군가를 잡고 먼저 사라졌어도, 저주 보유자는 엉뚱한 곳에서 깨어나요
	local confused = wasMonster or wokeElsewhere[who] == true
	wokeElsewhere[who] = nil
	sleeping[who] = nil
	if confused then
		confusedTonight[who] = true
	end
	freeze(who, false)
	if who:IsA("Player") then
		Remotes.SleepState:FireClient(who, false, confused and WAKE_CONFUSED or nil)
	end
	Sleep.Ended:Fire(who)
end

-- 밤이 시작되면 모두의 졸음 시간을 정해요
-- 오늘 밤 엉뚱한 곳에서 깨어났나? (서버만 알아요)
function Sleep.IsConfused(who: Instance): boolean
	return confusedTonight[who] == true
end

function Sleep.ScheduleNight()
	nightToken += 1
	table.clear(confusedTonight)
	local token = nightToken
	Monster.ResetNight()
	local speed = Config.Time.TestSpeed
	for _, who in Roster.GetAlive() do
		local duration = rng:NextNumber(NIGHT.SleepMinSeconds, NIGHT.SleepMaxSeconds)
		local latest = math.max(NIGHT.SleepEarliest, Config.Time.NightSeconds - duration - NIGHT.SleepEndMargin)
		local start = rng:NextNumber(NIGHT.SleepEarliest, latest)
		task.delay(start / speed, function()
			if token ~= nightToken then
				return
			end
			fallAsleep(who)
			task.delay(duration / speed, function()
				if token == nightToken then
					wakeUp(who)
				end
			end)
		end)
	end
end

-- 아침이 되면 모두 깨워요 (혹시 남은 졸음이 있어도)
function Sleep.WakeAll()
	nightToken += 1
	for _, who in Roster.GetAll() do
		wakeUp(who)
	end
	Monster.Vanish()
end

function Sleep.Init()
	-- 괴물이 누군가를 잡고 먼저 사라지면, 저주 보유자는 졸음이 끝날 때 "내가 왜 여기 있지?"
	Monster.Vanished:Connect(function(holder)
		if Sleep.IsSleeping(holder) then
			wokeElsewhere[holder] = true
		end
	end)
	-- 떠난 사람의 졸음 기록을 지워요
	Roster.Left:Connect(function(who)
		sleeping[who] = nil
		wokeElsewhere[who] = nil
	end)
end

return Sleep
