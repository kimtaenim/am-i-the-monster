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
	LightingUpdateSeconds = 0.1, -- 하늘·안개를 바꾸는 간격
	EndCheckSeconds = 0.25, -- 탐사가 끝났는지 확인하는 간격

	-- 하늘 시계 (Lighting.ClockTime, 0~24)
	ClockDayStart = 7,
	ClockDayEnd = 16.5,
	ClockEveningEnd = 19,
	ClockNightEnd = 28.5, -- 24를 넘으면 다음날 새벽 (28.5 = 새벽 4시 반)
	ClockMorningEnd = 31, -- 다음날 아침 7시
}

----------------------------------------------------------------
-- 승패 규칙
----------------------------------------------------------------
Config.Rules = {
	MonsterWinSurvivors = 3, -- 살아 있는 고고학자가 이 수 이하가 되면 괴물 승리 (공포 엔딩)
}

----------------------------------------------------------------
-- 공포 엔딩 (괴물이 이길 때 : 생존자 3명 이하, 모닥불 꺼짐, 7일 동안 못 찾음)
----------------------------------------------------------------
Config.Ending = {
	IntroSeconds = 3, -- "안개가 걷히고..." 해설
	RevealSeconds = 4, -- 괴물의 정체 공개
	TransformSeconds = 3, -- 괴물로 변하는 장면
	DashSeconds = 0.6, -- 괴물이 한 사람에게 달려드는 시간
	CatchPauseSeconds = 1.2, -- 한 사람을 잡고 다음 사람까지 쉬는 시간
	FinalSeconds = 5, -- 마지막 해설
	CatchOffset = 3, -- 잡을 때 괴물이 멈추는 거리
	FlashSeconds = 0.5, -- 하얀 번쩍임
	DarkTransparency = 0.45, -- 화면을 덮는 어둠 (0 = 깜깜, 1 = 투명)
	TintColor = Color3.fromRGB(255, 150, 150), -- 붉은 화면
	TintBrightness = -0.15,
	TintSaturation = -0.4,
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
	PromptDistance = 8,
	WoodPerChop = 1,
	WoodSpotsActivePerDay = 24, -- 하루에 장작을 얻을 수 있는 나무 수
	WarnBeforeNightSeconds = 20, -- 밤이 오기 이만큼 전에 장작이 없으면 다시 경고해요
	WarnBlinkSeconds = 0.5, -- 화면 장작 숫자가 깜박이는 간격
}

----------------------------------------------------------------
-- 캠프
----------------------------------------------------------------
Config.Camp = {
	DeliverRadius = 22, -- 모닥불에서 이 거리 안에 오면 들고 온 장작·식량을 내려놔요
	DeliverCheckSeconds = 0.5,
	SafeRingTransparency = 0.8, -- 밤에 보이는 안전지대 테두리
	SafeRingHeight = 0.2,
	EmberRadius = 6, -- 장작이 0개일 때 남은 불씨 빛
	LightBrightness = 2.5,
}

----------------------------------------------------------------
-- 식량과 체력
----------------------------------------------------------------
Config.Food = {
	StartFood = 6,
	GatherSeconds = 2,
	PromptDistance = 8,
	FoodPerGather = 1,
	SpotsActivePerDay = 30, -- 하루에 나오는 식량 자리 수
	EatPerPerson = 1,
}

Config.Health = {
	Max = 3,
	Start = 3,
	LoseWhenHungry = 1,
	GainWhenFed = 1,
	-- 괴물에게 잡혔을 때 뿌리칠 확률 (체력 → 확률)
	EscapeChance = { [3] = 0.5, [2] = 0.25, [1] = 0 },
	EscapeCost = 1, -- 뿌리치면 깎이는 체력
	GhostTransparency = 0.6, -- 유령 몸 투명도
}

----------------------------------------------------------------
-- 사냥 (무기는 동물에게만 맞아요. 사람·NPC에게는 안 맞아요)
----------------------------------------------------------------
Config.Hunt = {
	Weapons = {
		Spear = { Name = "창", Icon = "🔱", Kind = "Throw", Damage = 2, Cooldown = 1.2, Speed = 75, Gravity = 35, MaxDistance = 75 },
		Axe = { Name = "도끼", Icon = "🪓", Kind = "Melee", Damage = 2, Cooldown = 0.7, Range = 9 },
		Bow = { Name = "활", Icon = "🏹", Kind = "Throw", Damage = 1, Cooldown = 0.8, Speed = 150, Gravity = 18, MaxDistance = 140 },
		Slingshot = { Name = "새총", Icon = "🪨", Kind = "Throw", Damage = 2, Cooldown = 0.35, Speed = 140, Gravity = 25, MaxDistance = 120 },
	},
	WeaponOrder = { "Spear", "Axe", "Bow", "Slingshot" }, -- 캠프 무기 거치대에 놓이는 순서
	TakeWeaponSeconds = 0.5,

	-- 사냥감 : 기절하면 고기를 떨어뜨려요
	Prey = {
		Boar = { Name = "멧돼지", Count = 6, Health = 3, Food = 3, WalkSpeed = 8, FleeSpeed = 17, Skittish = 12 },
		Capybara = { Name = "카피바라", Count = 8, Health = 2, Food = 2, WalkSpeed = 6, FleeSpeed = 14, Skittish = 14 },
		Fowl = { Name = "정글닭", Count = 12, Health = 1, Food = 1, WalkSpeed = 7, FleeSpeed = 19, Skittish = 16 },
	},
	MinSpawnDistance = 60, -- 캠프에서 이만큼 떨어진 곳에 나타나요
	WanderRadius = 30, -- 집 주변 어슬렁거리는 범위
	WanderPauseMin = 2,
	WanderPauseMax = 6,
	ThinkSeconds = 0.5,
	FleeSeconds = 4,
	FleeDistance = 35,
	HitFlashSeconds = 0.25,
	FaintSeconds = 1, -- 기절해서 사라지는 시간
	DropLifetime = 120, -- 떨어진 고기가 남아 있는 시간
	PickupSeconds = 1,
	StuckSeconds = 3, -- 빗나간 화살·창이 땅에 꽂혀 있는 시간
	AimMaxDistance = 400,
	MapEdgeMargin = 12,
}

----------------------------------------------------------------
-- 유물 발굴
----------------------------------------------------------------
Config.Dig = {
	DigSeconds = 4,
	PromptDistance = 10,
	MinPerRuinPerDay = 2,
	MaxPerRuinPerDay = 3,
	LuckyFindChance = 0.25, -- 장작·식량·고기를 주울 때 유물을 우연히 발견할 확률
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
	SleepEndMargin = 3, -- 밤이 끝나기 이만큼 전에는 깨어나요
	WitnessSampleSeconds = 1, -- 괴물이 있는 동안 누가 누구를 봤는지 확인하는 간격
}

----------------------------------------------------------------
-- 단서
----------------------------------------------------------------
Config.Clue = {
	-- 동물들의 반응 : 저주 보유자 근처 동물이 놀라요 (가끔 다른 사람 근처에서도)
	OmenSeconds = 8, -- 이 간격마다 동물이 놀랄지 정해요
	OmenChance = 0.6, -- 저주 보유자 근처에서 놀랄 확률
	OmenNoiseChance = 0.25, -- 다른 사람 근처에서 놀랄 확률 (헷갈리게)
	StartleRadius = 25, -- 이 거리 안의 동물이 놀라요
	PreyFearMultiplier = 2, -- 놀란 사냥감은 이만큼 더 멀리서 도망쳐요

	-- 아침 보고서
	TrailSampleSeconds = 1, -- 괴물 발자국을 남기는 간격
	LandmarkRuinDistance = 60, -- 이 거리 안이면 "○○ 유적 근처"
	LandmarkSwampDistance = 40, -- 이 거리 안이면 "늪 근처"
	MapPixels = 240, -- 아침 보고서 지도 크기
}

Config.Monster = {
	WalkSpeed = 17,
	WanderSpeedFactor = 0.6, -- 쫓을 사람이 없을 때는 천천히 어슬렁
	CatchDistance = 4,
	RepathSeconds = 0.5, -- 쫓는 대상 위치 다시 확인하는 간격
	WanderRadius = 30,
	LightPushMargin = 1, -- 빛 가장자리에서 이만큼 바깥에 멈춰요
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
	Names = { "보라", "민준", "두부", "하늘", "초코", "봄이", "도윤", "서아", "지호", "루나", "단비", "호두" },
	Title = "고고학자",
	StartDelay = 2, -- 서버가 켜지고 첫 플레이어를 기다렸다가 NPC를 채워요

	-- 생각하는 간격 : 플레이어와 멀리 있는 NPC는 느긋하게 (성능)
	ThinkSeconds = 0.5,
	FarThinkSeconds = 1.5,
	PollSeconds = 0.15, -- 걷는 동안 도착했는지 확인하는 간격
	FarPollSeconds = 0.4,
	FarDistance = 120,

	-- 낮에는 한 번 나갈 때마다 유물·장작·식량 셋 다 챙겨서 캠프로 돌아와요
	WorkPause = 0.5, -- 일 끝나고 잠깐 쉬기

	-- 길찾기
	AgentRadius = 2,
	AgentHeight = 5,
	ArriveDistance = 4, -- 이만큼 가까우면 도착
	NearWaypoint = 2.5, -- 중간 길목은 이만큼만 가까워도 다음으로
	NearestChoices = 3, -- 가까운 몇 곳 중에서 고를까 (모두 같은 곳으로 몰리지 않게)
	WaypointTimeout = 4, -- 한 걸음에 이 시간 넘게 걸리면 막힌 거예요
	CampMeetRadiusMin = 8, -- 저녁·아침에 모이는 거리 (모닥불에서)
	CampMeetRadiusMax = 15,
	NightFireRadiusFactor = 0.6, -- 밤에는 빛 반경의 이 비율 안으로
	NightFireMinRadius = 6,
	TentChance = 0.3, -- 밤에 텐트로 숨는 NPC 비율

	-- 교대 (드롭인)
	LeaveSeconds = 6, -- "교대하러 간다" 하고 정글로 걸어가는 시간
	LeaveWalkDistance = 60,
	StatusSeconds = 3,

	-- 모습
	HatColor = Color3.fromRGB(205, 180, 125),
	HatBandColor = Color3.fromRGB(90, 60, 35),
	SkinColors = {
		Color3.fromRGB(255, 220, 185),
		Color3.fromRGB(234, 192, 150),
		Color3.fromRGB(198, 145, 100),
		Color3.fromRGB(150, 100, 70),
	},
	ShirtColors = {
		Color3.fromRGB(190, 170, 120),
		Color3.fromRGB(120, 140, 90),
		Color3.fromRGB(160, 110, 70),
		Color3.fromRGB(90, 120, 140),
		Color3.fromRGB(170, 80, 70),
		Color3.fromRGB(110, 100, 150),
	},
	PantsColors = {
		Color3.fromRGB(110, 95, 70),
		Color3.fromRGB(70, 70, 60),
		Color3.fromRGB(95, 80, 60),
	},
	NameTagHeight = 3.6,
	NameTagDistance = 40, -- 안개 속 보이는 거리와 같아요 (멀리서 이름표로 정체를 알아내지 못하게)

	-- 걷기 애니메이션 (Roblox 기본 R15 애니메이션)
	Animations = {
		Idle = "507766388",
		Walk = "507777826",
	},
	WalkAnimThreshold = 0.5, -- 이보다 빨리 움직이면 걷는 모습
}

----------------------------------------------------------------
-- 대사
----------------------------------------------------------------
Config.Dialogue = {
	RecentNoRepeat = 5, -- 최근 몇 문장은 다시 안 씀
	BubbleSeconds = 4,
}

----------------------------------------------------------------
-- 화면 (UI)
----------------------------------------------------------------
Config.UI = {
	NotifySeconds = 3, -- 알림 한 줄이 떠 있는 시간
	NotifyFadeSeconds = 0.5,
	MaxNotifies = 3, -- 한 번에 보이는 알림 수
	NotifyTextSize = 24,
	NotifyTop = 110, -- 화면 위에서 떨어진 거리 (픽셀)
	BannerSeconds = 3, -- "밤이 됐어" 큰 글씨가 떠 있는 시간
	NarrationDelay = 1.5, -- 큰 글씨 뒤 해설이 나오기까지
	NarrationSeconds = 7, -- 해설이 떠 있는 시간
	NarrationFadeSeconds = 1.5,
	NarrationTextSize = 30,
	HudTextSize = 22,
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
	HalfSize = 350, -- 지도 가운데에서 끝까지 거리
	-- 지도 가운데(모닥불) 위치. 베이스플레이트 한가운데·같은 높이를 피해서 겹쳐 깨지지 않게 해요
	Origin = Vector3.new(450, 30, 450),
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

	-- 무기 거치대 (창·도끼·활)
	WeaponRackPosition = Vector3.new(12, 0, -16),
	WeaponRackSpacing = 4,

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
	RuinMinRadius = 150,
	RuinMaxRadius = 300,
	RuinAngleJitter = 0.25, -- 각도 흔들림 (라디안)
	RuinClearRadius = 22, -- 유적 주변엔 나무를 안 심어요
	DigSpotOffset = 9, -- 유적 앞 몇 스터드에 발굴 자리가 있나
	DigSpotSize = Vector3.new(6, 1.6, 6),

	-- 나무
	TreeCount = 230,
	ChoppableTreeCount = 50,
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
	FoodSpotCount = 70,
	FoodSpotSpacing = 9,

	-- 장식
	BushCount = 420,
	VineCount = 260,
	VineLengthMin = 6,
	VineLengthMax = 16,
	FallenLogCount = 16,
	FallenLogLengthMin = 28,
	FallenLogLengthMax = 44,
	FallenLogDiameterMin = 4,
	FallenLogDiameterMax = 6.5,
	SwampCount = 12,
	SwampSizeMin = 18,
	SwampSizeMax = 34,
	ReedsPerSwamp = 6,
	MossStatueCount = 12,
	PlaceTries = 60, -- 빈자리 찾기 시도 횟수
}

----------------------------------------------------------------
-- 분위기 (안개 · 빛)
----------------------------------------------------------------
Config.Atmosphere = {
	-- 낮에도 해가 잘 안 드는 음산한 정글이에요
	DayDensity = 0.5,
	NightDensity = 0.75, -- 밤에는 정체불명의 안개가 짙어져요
	Offset = 0.3,
	Haze = 2.6,
	Glare = 0,
	DayColor = Color3.fromRGB(125, 145, 118),
	DayDecay = Color3.fromRGB(48, 68, 48),
	NightColor = Color3.fromRGB(60, 72, 82),
	NightDecay = Color3.fromRGB(18, 26, 30),
	DayAmbient = Color3.fromRGB(72, 88, 70),
	NightAmbient = Color3.fromRGB(22, 26, 36),
	DayBrightness = 1.4,
	NightBrightness = 0.3,

	-- 화면 색 보정 : 색을 살짝 빼서 축축하고 어둡게
	Saturation = -0.25,
	Contrast = 0.12,
	Tint = Color3.fromRGB(215, 232, 210),

	-- 잿빛 구름이 하늘을 덮어요
	CloudCover = 0.85,
	CloudDensity = 0.6,
	CloudColor = Color3.fromRGB(150, 155, 150),

	-- 땅에 깔리는 물안개
	MistSpotCount = 35, -- 늪 말고도 정글 곳곳에 생기는 안개
	MistRate = 1.2,
	MistLifetime = 9,
	MistSize = 14,
	MistTransparency = 0.85,
	MistColor = Color3.fromRGB(200, 215, 205),
}

----------------------------------------------------------------
-- 정글 동물들 (보기만 하는 장식이에요. 게임 판정에는 안 쓰여요)
----------------------------------------------------------------
Config.Wildlife = {
	-- 몇 마리?
	Parrots = 24, -- 앵무새 (낮, 나무 위)
	Toucans = 10, -- 큰부리새 (낮, 나무 위)
	BirdFlocks = 5, -- 하늘을 도는 새 떼 (낮)
	BirdsPerFlock = 6,
	Monkeys = 18, -- 원숭이 (나무줄기 오르내리기)
	FrogsPerSwamp = 3, -- 개구리 (늪가에서 폴짝)
	CrocMinSwampSize = 24, -- 이보다 큰 늪엔 악어 눈이 떠 있어요
	Lizards = 12, -- 도마뱀 (유적 돌 위)
	Butterflies = 28, -- 나비 (낮)
	Owls = 14, -- 부엉이 (밤에 눈이 빛나요)
	Bats = 16, -- 박쥐 (밤)
	FireflyClusters = 24, -- 반딧불 (밤)
	EyePairs = 24, -- 덤불 속에서 빛나는 눈 (밤, 다가가면 사라져요)

	BranchLength = 4, -- 새가 앉는 나뭇가지 길이

	-- 움직임
	UpdateHz = 30, -- 1초에 몇 번 움직일까
	ActiveDistance = 160, -- 이 거리 안의 동물만 움직여요 (성능)
	PerchBobSpeed = 2.5,
	BirdFlyChancePerSecond = 0.04, -- 앉아 있던 새가 날아오를 확률
	BirdFlySeconds = 6,
	BirdFlyRadius = 14,
	FlockRadiusMin = 60,
	FlockRadiusMax = 130,
	FlockHeight = 45,
	FlockSpeed = 0.18, -- 1초에 도는 각도 (라디안)
	MonkeyClimbSpeed = 0.35,
	FrogHopChancePerSecond = 0.15,
	FrogHopSeconds = 0.45,
	FrogHopDistance = 3,
	FrogHopHeight = 1.6,
	LizardDashChancePerSecond = 0.2,
	LizardDashSeconds = 0.35,
	LizardDashDistance = 4,
	LizardRange = 8,
	ButterflyRange = 10,
	ButterflySpeed = 0.6,
	ButterflyFlapSpeed = 18,
	OwlHeadTurnChancePerSecond = 0.25,
	BatRadius = 18,
	BatHeight = 26,
	BatSpeed = 1.6,
	EyeBlinkChancePerSecond = 0.3,
	EyeBlinkSeconds = 0.15,
	EyeHideDistance = 18, -- 이만큼 다가가면 눈이 사라져요
	CrocDriftSpeed = 0.08,
	FireflyRate = 4,

	-- 밤 판정 (Lighting.ClockTime)
	NightStartsAt = 18.5,
	NightEndsAt = 5.5,
}

----------------------------------------------------------------
-- 소리 (rbxassetid 번호)
-- 비어 있는 칸("")은 소리가 안 나요.
-- Studio 도구상자 → 마켓플레이스 → 오디오에서 "jungle", "owl" 등을 검색해서
-- 마음에 드는 소리를 오른쪽 클릭 → "자산 ID 복사" 한 다음 숫자만 붙여 넣으면 돼요.
----------------------------------------------------------------
Config.Sounds = {
	-- 계속 깔리는 배경 소리
	DayLoop = "", -- 낮 정글 (새·벌레). 추천 검색어 : jungle ambience, rainforest
	NightLoop = "9119298682", -- 밤 귀뚜라미 (Roblox 공식 효과음)
	EerieLoop = "9112775175", -- 밤낮으로 깔리는 으스스한 바람 (Roblox 공식 효과음)
	DayLoopVolume = 0.45,
	NightLoopVolume = 0.5,
	EerieDayVolume = 0.15,
	EerieNightVolume = 0.4,
	FadeSeconds = 4,

	-- 가끔 들리는 동물 소리 (동물이 있는 자리에서 들려요)
	Calls = {
		Owl = { Id = "", Volume = 0.7, Night = true }, -- 부엉이 : owl hoot
		Monkey = { Id = "", Volume = 0.6, Night = false }, -- 원숭이 : monkey
		Parrot = { Id = "", Volume = 0.5, Night = false }, -- 앵무새 : parrot, tropical bird
		Toucan = { Id = "", Volume = 0.5, Night = false }, -- 큰부리새 : toucan, bird call
		Frog = { Id = "", Volume = 0.6, Night = nil }, -- 개구리 : frog croak (밤낮 모두)
		Bat = { Id = "", Volume = 0.4, Night = true }, -- 박쥐 : bat squeak
	},
	CallMinSeconds = 3, -- 동물 소리 사이 최소 간격
	CallMaxSeconds = 9,
	CallMaxDistance = 140, -- 이 거리 안의 동물만 소리를 내요
	CallRollOffMin = 10,
	CallRollOffMax = 150,
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

	-- 동물
	Parrots = {
		Color3.fromRGB(210, 40, 40),
		Color3.fromRGB(40, 110, 210),
		Color3.fromRGB(40, 170, 70),
		Color3.fromRGB(240, 200, 40),
	},
	ParrotWing = Color3.fromRGB(30, 80, 170),
	Beak = Color3.fromRGB(240, 170, 40),
	ToucanBody = Color3.fromRGB(25, 25, 28),
	ToucanChest = Color3.fromRGB(245, 230, 120),
	ToucanBeak = Color3.fromRGB(250, 130, 30),
	FlockBird = Color3.fromRGB(35, 35, 40),
	Monkey = Color3.fromRGB(100, 70, 45),
	MonkeyFace = Color3.fromRGB(210, 175, 135),
	Frog = Color3.fromRGB(70, 160, 60),
	FrogEye = Color3.fromRGB(240, 220, 60),
	FrogBelly = Color3.fromRGB(190, 220, 120),
	Lizard = Color3.fromRGB(90, 140, 80),
	Butterflies = {
		Color3.fromRGB(80, 160, 255),
		Color3.fromRGB(255, 150, 40),
		Color3.fromRGB(230, 90, 200),
		Color3.fromRGB(250, 240, 120),
	},
	Owl = Color3.fromRGB(110, 90, 70),
	OwlFace = Color3.fromRGB(190, 170, 140),
	OwlEye = Color3.fromRGB(255, 200, 40),
	Bat = Color3.fromRGB(30, 25, 35),
	GlowEye = Color3.fromRGB(255, 230, 90),
	Croc = Color3.fromRGB(55, 75, 45),
	Firefly = Color3.fromRGB(220, 255, 120),

	-- 사냥감과 무기
	Boar = Color3.fromRGB(95, 80, 70),
	BoarSnout = Color3.fromRGB(190, 140, 130),
	Tusk = Color3.fromRGB(245, 240, 225),
	Capybara = Color3.fromRGB(150, 105, 65),
	CapybaraNose = Color3.fromRGB(60, 45, 35),
	Fowl = Color3.fromRGB(170, 70, 35),
	FowlComb = Color3.fromRGB(220, 30, 40),
	FowlTail = Color3.fromRGB(30, 80, 60),
	FowlBreast = Color3.fromRGB(230, 140, 50),
	BoarMane = Color3.fromRGB(60, 50, 45),
	Hoof = Color3.fromRGB(45, 38, 32),
	CapybaraSnout = Color3.fromRGB(120, 85, 55),
	CapybaraDark = Color3.fromRGB(95, 65, 40),
	Orange = Color3.fromRGB(255, 150, 40),
	Leaf = Color3.fromRGB(70, 150, 60),
	EyeBlack = Color3.fromRGB(20, 18, 18),
	EyeShine = Color3.fromRGB(255, 255, 255),
	Meat = Color3.fromRGB(175, 90, 60),
	Bone = Color3.fromRGB(245, 240, 225),
	WeaponWood = Color3.fromRGB(120, 85, 50),
	WeaponStone = Color3.fromRGB(110, 110, 115),
	BowString = Color3.fromRGB(230, 225, 210),
	SlingBand = Color3.fromRGB(150, 60, 40),
	HitFlash = Color3.fromRGB(255, 255, 255),

	-- 괴물 (검은 그림자 석상)
	MonsterBody = Color3.fromRGB(14, 14, 18),
	MonsterCrack = Color3.fromRGB(45, 42, 50),
	MonsterEye = Color3.fromRGB(255, 70, 40),
	MonsterSmoke = Color3.fromRGB(20, 20, 25),
}

return Config
