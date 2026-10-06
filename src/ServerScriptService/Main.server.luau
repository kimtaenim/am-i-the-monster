-- 게임 서버가 켜지면 제일 먼저 실행돼요.
-- 정글 지도를 만들고, 각 시스템을 차례대로 깨워요.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Remotes) -- 통로를 먼저 만들어 둬요

local Systems = ServerScriptService.Systems
local MapBuilder = require(Systems.MapBuilder)
local Wildlife = require(Systems.Wildlife)

local mapInfo = MapBuilder.Build()
Wildlife.Build(mapInfo)

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
	"Roster",
	"NpcManager",
	"Sleep",
	"Monster",
	"Trade",
	"Vote",
	"Ghost",
	"DayCycle",
	"GameLoop", -- 맨 마지막 : 하루를 돌리기 시작해요
}

for _, name in INIT_ORDER do
	local system = require(Systems[name])
	system.Init()
end
