-- 게임 서버가 켜지면 제일 먼저 실행돼요.
-- 정글 지도를 만들고, 각 시스템을 차례대로 깨워요.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Config = require(ReplicatedStorage.Config)
local Remotes = require(ReplicatedStorage.Remotes)
local Lines = require(ReplicatedStorage.Dialogue.Lines)

local Systems = ServerScriptService.Systems
local MapBuilder = require(Systems.MapBuilder)
local Wildlife = require(Systems.Wildlife)

local mapInfo = MapBuilder.Build()
Wildlife.Build(mapInfo)
MapBuilder.MoveToOrigin()
MapBuilder.DisableStraySpawns()

-- 순서가 중요해요 : 아래 시스템이 위 시스템을 쓸 수 있어요
local INIT_ORDER = {
	"ScoreStore",
	"CampStore",
	"Inventory",
	"Curse",
	"Health",
	"Gathering",
	"Hunting",
	"Weapons",
	"Excavation",
	"DialogueService",
	"Monster",
	"Sleep",
	"NightLog",
	"Omens",
	"NpcManager",
	"Trade",
	"Vote",
	"Ghost",
	"Ending",
	"DayCycle",
	"Roster", -- 다른 시스템들이 귀를 기울인 다음에 "고고학자가 들어왔어"를 알려요
}

local S = {}
for _, name in INIT_ORDER do
	S[name] = require(Systems[name])
	S[name].Init()
end
local GameLoop = require(Systems.GameLoop)

----------------------------------------------------------------
-- 시간이 바뀔 때 할 일 (하루의 흐름)
----------------------------------------------------------------

-- 새 탐사 : 창고·소지품·체력을 처음으로 되돌리고 유물·장작·식량·사냥감을 채워요
-- 밤마다 안개 해설 하나 (어제와 다른 문장)
local fogRng = Random.new()
local lastFog = 0
local function tellFogStory()
	local stories = Lines.FogNarration
	local index = fogRng:NextInteger(1, #stories)
	if #stories > 1 and index == lastFog then
		index = index % #stories + 1
	end
	lastFog = index
	Remotes.Narration:FireAllClients(stories[index])
end

GameLoop.ExpeditionStarted:Connect(function()
	S.Sleep.WakeAll()
	S.Monster.Reset()
	S.NightLog.Reset()
	S.Trade.CloseAll()
	S.Trade.ClearLog()
	S.Ending.Cleanup()
	S.Curse.Reset()
	S.NpcManager.ResetForExpedition()
	S.CampStore.Reset()
	S.Inventory.Reset()
	S.Health.Reset()
	for _, who in S.Roster.GetAll() do
		S.Gathering.ClearCarried(who)
	end
	S.Excavation.RefillAll()
	S.Gathering.RefillDaily()
	S.Hunting.RefillAll()
end)

-- 살아 있는 고고학자가 3명 이하가 되면 괴물 승리
local function checkSurvivors()
	if GameLoop.GetPhase() == "Result" then
		return
	end
	local alive = #S.Roster.GetAlive()
	if alive <= Config.Rules.MonsterWinSurvivors then
		GameLoop.EndExpedition("Monster", string.format("살아남은 고고학자가 %d명뿐이었어...", alive))
	end
end
S.Health.BecameGhost:Connect(checkSurvivors)

-- 괴물이 이기면 (생존자 3명 이하, 모닥불 꺼짐, 7일 동안 못 찾음) 언제나 공포 엔딩 :
-- 괴물의 정체가 밝혀지고 남은 사람들을 모두 잡아요
GameLoop.SetMonsterEnding(S.Ending.PlayHorror)

-- 모닥불 경고 : 낮 시작, 낮 중간, 저녁 시작, 밤 직전
local function warnLater(seconds: number, phase: string, day: number)
	task.delay(seconds / Config.Time.TestSpeed, function()
		if GameLoop.GetPhase() == phase and GameLoop.GetDay() == day then
			S.CampStore.WarnIfLow(phase)
		end
	end)
end

GameLoop.PhaseStarted:Connect(function(phase: string, day: number)
	if phase == "Day" then
		if day == 1 then
			S.CampStore.TellRules()
		else
			S.CampStore.WarnIfLow("Day")
		end
		warnLater(Config.Time.DaySeconds / 2, "Day", day)
	elseif phase == "Evening" then
		S.CampStore.WarnIfLow("Evening")
		warnLater(Config.Time.EveningSeconds - Config.Fire.WarnBeforeNightSeconds, "Evening", day)
	end

	if phase == "Day" and day > 1 then
		-- 새 하루 : 유물이 다시 묻히고, 장작·식량·사냥감이 다시 나와요
		S.Excavation.RefillAll()
		S.Gathering.RefillDaily()
		S.Hunting.RefillAll()
	elseif phase == "Evening" then
		S.Excavation.GuaranteeEveryone() -- 모두 유물 1개 이상 (저주를 정하기 전에)
		S.Curse.Designate() -- 첫날 저녁 : 사람들이 캔 유물 중 하나가 저주 유물이 돼요 (서버만 알아요)
		S.Health.EveningMeal()
		S.Trade.ScheduleNpcOffers(S.NpcManager.GetAll()) -- NPC들도 저녁마다 한 번씩 교환을 제안해요
	elseif phase == "Night" then
		S.Trade.CloseAll() -- 저녁이 끝나면 대답 안 한 제안은 취소
		if not S.CampStore.BurnForNight() then
			GameLoop.EndExpedition("Monster", "모닥불이 꺼져서 괴물이 캠프를 덮쳤어...")
		else
			tellFogStory()
			S.NightLog.StartNight(day)
			S.Sleep.ScheduleNight() -- 모두 무작위 시간에 졸아요. 저주 보유자가 졸면 괴물이 나와요
		end
	elseif phase == "Morning" then
		S.Sleep.WakeAll()
		S.NightLog.SendMorningReports() -- "어젯밤 본 것" (사람마다 자기가 본 것만)
	end
end)

GameLoop.Init() -- 맨 마지막 : 하루를 돌리기 시작해요
