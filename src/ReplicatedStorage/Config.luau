-- 게임에 나오는 숫자는 전부 여기 모여 있어요.
-- 숫자를 바꾸면 게임이 바로 달라져요. (예: 낮 길이, 괴물 속도, 지도 크기)
-- 다른 파일에는 숫자를 직접 쓰지 않고 여기 값을 가져다 써요.

local Config = {}

----------------------------------------------------------------
-- 서버 인원
----------------------------------------------------------------
Config.Server = {
	MaxSlots = 12, -- 고고학자 자리 수 (플레이어 + NPC)
}

----------------------------------------------------------------
-- 시간 (초)
----------------------------------------------------------------
Config.Time = {
	DaySeconds = 120, -- 낮 (발굴)
	EveningSeconds = 45, -- 저녁 (교환)
	NightSeconds = 60, -- 밤 (괴물)
	MorningSeconds = 45, -- 아침 (회의·투표)
	MaxDays = 7, -- 탐사 최대 일수
	ResultSeconds = 20, -- 결과 화면 보여주는 시간
	TestSpeed = 1, -- 테스트용 배속 (2면 모든 시간이 절반)

	-- 하늘 시계 (Lighting.ClockTime, 0~24)
	ClockDayStart = 7,
	ClockDayEnd = 16.5,
	ClockEveningEnd = 19,
	ClockNightEnd = 28.5, -- 24를 넘으면 다음날 새벽 (28.5 = 새벽 4시 반)
	ClockMorningEnd = 31, -- 다음날 아침 7시
}

----------------------------------------------------------------
-- 점수
----------------------------------------------------------------
Config.Score = {
	Dig = 10, -- 유물 1개 발굴
	Wood = 3, -- 장작 1개 캠프에 가져오기
	Food = 3, -- 식량 1개 캠프에 가져오기
}

----------------------------------------------------------------
-- 장작과 모닥불
----------------------------------------------------------------
Config.Fire = {
	StartWood = 6, -- 탐사 시작 장작
	BurnPerNight = 2, -- 밤마다 타는 장작
	BaseLightRadius = 14, -- 장작이 1개일 때 빛 반경 (스터드)
	RadiusPerWood = 3, -- 장작 1개마다 늘어나는 반경
	MaxLightRadius = 45, -- 최대 빛 반경
	ChopSeconds = 3, -- 장작 줍는 시간
	WoodPerChop = 1,
	WoodSpotsActivePerDay = 14, -- 하루에 장작을 얻을 수 있는 나무 수
}

----------------------------------------------------------------
-- 식량과 체력
----------------------------------------------------------------
Config.Food = {
	StartFood = 6,
	GatherSeconds = 2,
	FoodPerGather = 1,
	SpotsActivePerDay = 14, -- 하루에 나오는 식량 개수
	EatPerPerson = 1,
}

Config.Health = {
	Max = 3,
	LoseWhenHungry = 1,
	GainWhenFed = 1,
	-- 괴물에게 잡혔을 때 뿌리칠 확률 (체력 → 확률)
	EscapeChance = { [3] = 0.5, [2] = 0.25, [1] = 0 },
	EscapeCost = 1, -- 뿌리치면 깎이는 체력
}

----------------------------------------------------------------
-- 유물 발굴
----------------------------------------------------------------
Config.Dig = {
	DigSeconds = 4,
	MinPerRuinPerDay = 2,
	MaxPerRuinPerDay = 3,
}

----------------------------------------------------------------
-- 교환
----------------------------------------------------------------
Config.Trade = {
	NpcAcceptChance = 0.7, -- NPC가 제안을 받아줄 확률
	NpcOffersPerDay = 1, -- NPC가 하루에 하는 제안 수
	OfferTimeoutSeconds = 15, -- 제안에 답할 시간
}

----------------------------------------------------------------
-- 밤 : 졸음, 괴물, 안개
----------------------------------------------------------------
Config.Night = {
	SleepMinSeconds = 15,
	SleepMaxSeconds = 20,
	SleepEarliest = 5, -- 밤 시작 후 몇 초부터 졸 수 있나
	FogSightRadius = 40, -- 밤 안개 속에서 보이는 거리 (목격 판정)
	TentCapacity = 1,
}

Config.Monster = {
	WalkSpeed = 17,
	CatchDistance = 4,
	RepathSeconds = 0.5, -- 쫓는 대상 위치 다시 확인하는 간격
	WanderRadius = 30,
}

----------------------------------------------------------------
-- 투표
----------------------------------------------------------------
Config.Vote = {
	NpcAccuracy = 0.55, -- NPC가 단서를 믿는 정도 (0~1)
	NpcAbstainBelow = 0.35, -- 확신이 이보다 낮으면 기권
	NpcWeightMissing = 3, -- 괴물 시간에 안 보인 사람 가중치
	NpcWeightTradePath = 2, -- 교환 경로에 있던 사람 가중치
}

----------------------------------------------------------------
-- NPC
----------------------------------------------------------------
Config.Npc = {
	WalkSpeed = 14,
	ThinkSeconds = 0.5, -- 가까운 NPC 생각 간격
	FarThinkSeconds = 1.5, -- 플레이어와 먼 NPC 생각 간격
	FarDistance = 120,
	ChatChancePerMinute = 0.6,
	Names = { "보라", "민준", "두부", "하늘", "초코", "봄이", "도윤", "서아", "지호", "루나", "단비", "호두" },
	Title = "고고학자",
}

----------------------------------------------------------------
-- 대사
----------------------------------------------------------------
Config.Dialogue = {
	RecentNoRepeat = 5, -- 최근 몇 문장은 다시 안 씀
	BubbleSeconds = 4,
}

----------------------------------------------------------------
-- 점수 저장
----------------------------------------------------------------
Config.Save = {
	StoreName = "AmITheMonster_v1",
	Retries = 3,
	RetryWaitSeconds = 2,
	AutoSaveSeconds = 120,
	LeaderboardSize = 10,
}

----------------------------------------------------------------
-- 지도 (스터드 단위)
----------------------------------------------------------------
Config.Map = {
	Seed = 20261006, -- 같은 숫자면 항상 같은 정글이 만들어져요
	HalfSize = 200, -- 지도 가운데에서 끝까지 거리
	GroundThickness = 4,
	WallHeight = 80, -- 보이지 않는 벽 높이

	CampClearRadius = 48, -- 캠프 주변엔 나무를 안 심어요
	SpawnOffset = Vector3.new(0, 0.5, -18),

	-- 모닥불
	FireStoneCount = 10,
	FireStoneRingRadius = 4,
	FireStoneSize = Vector3.new(1.6, 1.2, 1.6),
	FireLogLength = 5,
	FireLogDiameter = 0.9,
	FireFlameSize = Vector3.new(2.5, 3, 2.5),
	FireHeat = 9,
	FireSize = 6,
	SeatLogCount = 4,
	SeatLogRadius = 10,
	SeatLogLength = 6,
	SeatLogDiameter = 1.4,

	-- 장작 더미 · 식량 창고
	WoodPilePosition = Vector3.new(14, 0, 10),
	FoodStorePosition = Vector3.new(-14, 0, 10),
	StoreLabelHeight = 6,

	-- 텐트
	TentCount = 6,
	TentRingRadius = 32,
	TentSize = Vector3.new(9, 7, 11), -- 폭, 높이, 길이

	-- 유적 터
	RuinCount = 8,
	RuinMinRadius = 105,
	RuinMaxRadius = 165,
	RuinAngleJitter = 0.25, -- 각도 흔들림 (라디안)
	RuinClearRadius = 20, -- 유적 주변엔 나무를 안 심어요
	DigSpotOffset = 9, -- 유적 앞 몇 스터드에 발굴 자리가 있나
	DigSpotSize = Vector3.new(6, 1.6, 6),

	-- 나무
	TreeCount = 75,
	ChoppableTreeCount = 26,
	TreeSpacing = 11,
	TreeHeightMin = 18,
	TreeHeightMax = 32,
	TreeTrunkMin = 2.4,
	TreeTrunkMax = 4,
	TreeLeafBallsMin = 3,
	TreeLeafBallsMax = 5,
	TreeLeafSizeMin = 9,
	TreeLeafSizeMax = 16,
	BoundaryTreeSpacing = 13,
	BoundaryInset = 6,

	-- 식량
	FoodSpotCount = 34,
	FoodSpotSpacing = 9,

	-- 장식
	BushCount = 170,
	VineCount = 110,
	VineLengthMin = 6,
	VineLengthMax = 16,
	FallenLogCount = 8,
	FallenLogLengthMin = 28,
	FallenLogLengthMax = 44,
	FallenLogDiameterMin = 4,
	FallenLogDiameterMax = 6.5,
	SwampCount = 7,
	SwampSizeMin = 18,
	SwampSizeMax = 34,
	ReedsPerSwamp = 6,
	MossStatueCount = 6,
	PlaceTries = 60, -- 빈자리 찾기 시도 횟수
}

----------------------------------------------------------------
-- 분위기 (안개 · 빛)
----------------------------------------------------------------
Config.Atmosphere = {
	DayDensity = 0.42,
	NightDensity = 0.72, -- 밤에는 정체불명의 안개가 짙어져요
	Offset = 0.25,
	Haze = 2.2,
	Glare = 0,
	DayColor = Color3.fromRGB(150, 180, 130),
	DayDecay = Color3.fromRGB(70, 105, 60),
	NightColor = Color3.fromRGB(70, 85, 95),
	NightDecay = Color3.fromRGB(25, 35, 40),
	DayAmbient = Color3.fromRGB(95, 115, 90),
	NightAmbient = Color3.fromRGB(25, 30, 40),
	DayBrightness = 2,
	NightBrightness = 0.4,
}

----------------------------------------------------------------
-- 색깔
----------------------------------------------------------------
Config.Colors = {
	Ground = Color3.fromRGB(58, 86, 40),
	Dirt = Color3.fromRGB(105, 78, 50),
	Stone = Color3.fromRGB(128, 126, 115),
	DarkStone = Color3.fromRGB(85, 84, 78),
	Moss = Color3.fromRGB(75, 110, 50),
	Trunk = Color3.fromRGB(88, 62, 40),
	Leaves = {
		Color3.fromRGB(34, 85, 30),
		Color3.fromRGB(45, 100, 38),
		Color3.fromRGB(28, 70, 35),
		Color3.fromRGB(55, 110, 45),
	},
	Vine = Color3.fromRGB(40, 90, 35),
	Swamp = Color3.fromRGB(52, 62, 38),
	Reed = Color3.fromRGB(110, 120, 60),
	Tent = Color3.fromRGB(176, 150, 105),
	Log = Color3.fromRGB(110, 75, 45),
	Flame = Color3.fromRGB(255, 150, 50),
	FireLight = Color3.fromRGB(255, 170, 90),
	CaveDark = Color3.fromRGB(10, 10, 12),
	WellWater = Color3.fromRGB(20, 35, 40),
	Mushroom = Color3.fromRGB(200, 70, 55),
	MushroomStem = Color3.fromRGB(235, 225, 200),
	Berry = Color3.fromRGB(150, 40, 90),
	Banana = Color3.fromRGB(240, 210, 60),
	Label = Color3.fromRGB(255, 245, 220),
}

return Config
