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
	"NightLog",
	"NpcManager",
	"Sleep",
	"Monster",
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
		-- 공포 엔딩 : 괴물의 정체가 밝혀지고 남은 사람들을 모두 잡아요
		GameLoop.EndExpedition("Monster", string.format("살아남은 고고학자가 %d명뿐이었어...", alive), S.Ending.PlayHorror)
	end
end
S.Health.BecameGhost:Connect(checkSurvivors)

GameLoop.PhaseStarted:Connect(function(phase: string, day: number)
	if phase == "Day" and day > 1 then
		-- 새 하루 : 유물이 다시 묻히고, 장작·식량·사냥감이 다시 나와요
		S.Excavation.RefillAll()
		S.Gathering.RefillDaily()
		S.Hunting.RefillAll()
	elseif phase == "Evening" then
		S.Excavation.GuaranteeEveryone() -- 모두 유물 1개 이상 (저주를 정하기 전에)
		S.Curse.Designate() -- 첫날 저녁 : 사람들이 캔 유물 중 하나가 저주 유물이 돼요 (서버만 알아요)
		S.Health.EveningMeal()
	elseif phase == "Night" then
		if not S.CampStore.BurnForNight() then
			GameLoop.EndExpedition("Monster", "모닥불이 꺼져서 괴물이 캠프를 덮쳤어...")
		else
			tellFogStory()
		end
	end
end)

GameLoop.Init() -- 맨 마지막 : 하루를 돌리기 시작해요
