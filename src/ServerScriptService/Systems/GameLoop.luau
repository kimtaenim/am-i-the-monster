-- 하루(낮 → 저녁 → 밤 → 아침)를 돌리고, 탐사의 시작과 끝을 정해요.
-- 시간이 바뀌면 다른 시스템들에게 "지금 밤이야!" 같은 신호를 보내요.
-- 탐사가 끝나면 결과를 보여 주고 20초 뒤 새 탐사를 자동으로 시작해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config)
local GameState = require(ReplicatedStorage.GameState)
local Remotes = require(ReplicatedStorage.Remotes)
local Signal = require(ReplicatedStorage.Signal)

local TIME = Config.Time
local PHASES = {
	{ Name = "Day", Seconds = TIME.DaySeconds },
	{ Name = "Evening", Seconds = TIME.EveningSeconds },
	{ Name = "Night", Seconds = TIME.NightSeconds },
	{ Name = "Morning", Seconds = TIME.MorningSeconds },
}

local GameLoop = {}

GameLoop.ExpeditionStarted = Signal.new() -- ()
GameLoop.PhaseStarted = Signal.new() -- (phase, day)
GameLoop.ExpeditionEnded = Signal.new() -- (winner, reason) winner는 "Archaeologists" 또는 "Monster"

local ending = nil -- 끝내 달라는 요청 { Winner, Reason }

function GameLoop.GetPhase(): string
	return GameState.Get("Phase")
end

function GameLoop.GetDay(): number
	return GameState.Get("Day")
end

-- 다른 시스템이 탐사를 끝낼 때 불러요 (예 : 모닥불이 꺼짐, 범인 추방)
-- sequence : 결과 화면 전에 보여 줄 연출 (예 : 공포 엔딩). 없어도 돼요
function GameLoop.EndExpedition(winner: string, reason: string, sequence: (() -> ())?)
	if not ending then
		ending = { Winner = winner, Reason = reason, Sequence = sequence }
	end
end

-- 연출 중에 시간대 이름을 바꿀 때 (예 : "Ending")
function GameLoop.SetSpecialPhase(phase: string, seconds: number)
	GameState.Set("Phase", phase)
	GameState.Set("PhaseEndsAt", Workspace:GetServerTimeNow() + seconds)
end

local function setPhase(phase: string, seconds: number)
	GameState.Set("Phase", phase)
	GameState.Set("PhaseEndsAt", Workspace:GetServerTimeNow() + seconds)
	Remotes.PhaseChanged:FireAllClients(phase, GameState.Get("Day"))
	GameLoop.PhaseStarted:Fire(phase, GameState.Get("Day"))
end

-- 정해진 시간만큼 기다려요. 중간에 탐사가 끝나면 false
local function waitPhase(seconds: number): boolean
	local finish = os.clock() + seconds
	while os.clock() < finish do
		if ending then
			return false
		end
		task.wait(TIME.EndCheckSeconds)
	end
	return not ending
end

local function runExpedition()
	ending = nil
	GameState.Set("Expedition", GameState.Get("Expedition") + 1)
	GameState.Set("Day", 1)
	GameLoop.ExpeditionStarted:Fire()

	for day = 1, TIME.MaxDays do
		GameState.Set("Day", day)
		for _, phase in PHASES do
			setPhase(phase.Name, phase.Seconds / TIME.TestSpeed)
			if not waitPhase(phase.Seconds / TIME.TestSpeed) then
				return
			end
		end
	end
	GameLoop.EndExpedition("Monster", string.format("%d일 동안 범인을 찾지 못했어...", TIME.MaxDays))
end

local function showResult()
	local result = ending
	if result.Sequence then
		local ok, err = pcall(result.Sequence)
		if not ok then
			warn("[GameLoop] 엔딩 연출 오류:", err)
		end
	end
	local seconds = TIME.ResultSeconds / TIME.TestSpeed
	setPhase("Result", seconds)
	GameLoop.ExpeditionEnded:Fire(result.Winner, result.Reason)
	local title = result.Winner == "Archaeologists" and "🎉 고고학자 승리!" or "👹 괴물 승리..."
	Remotes.Notify:FireAllClients(title .. " " .. result.Reason)
	print("[GameLoop] 탐사 끝:", result.Winner, result.Reason)
	task.wait(seconds)
end

function GameLoop.Init()
	task.spawn(function()
		while true do
			runExpedition()
			showResult()
		end
	end)
end

return GameLoop
