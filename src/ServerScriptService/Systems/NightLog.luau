-- 밤에 일어난 일을 기록해요. (괴물이 나온 시간, 안개 속에서 누가 안 보였는지, 괴물 발자국, 사라진 곳)
-- 아침이 되면 사람마다 "자기가 깨어 있을 때 본 것"만 골라 아침 보고서를 보내요. 발자국 지도는 모두에게 보여요.
-- NPC들의 단서 대사와 투표도 이 기록을 써요. (저주 보유자가 누구인지는 절대 보고서에 쓰지 않아요)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Config)
local GameState = require(ReplicatedStorage.GameState)
local Lines = require(ReplicatedStorage.Dialogue.Lines)
local Remotes = require(ReplicatedStorage.Remotes)
local Systems = ServerScriptService.Systems
local MapBuilder = require(Systems.MapBuilder)
local Roster = require(Systems.Roster)
local CampStore = require(Systems.CampStore)
local Inventory = require(Systems.Inventory)
local Health = require(Systems.Health)
local Monster = require(Systems.Monster)
local Sleep = require(Systems.Sleep)
local Visibility = require(Systems.Visibility)
local Trade = require(Systems.Trade)

local CLUE = Config.Clue
local TEXT = Lines.MorningReport
local COMPASS = { "북", "북동", "동", "남동", "남", "남서", "서", "북서" }

local NightLog = {}

local night = nil -- 오늘 밤 기록
local dayEvents = {} -- 아침 이후 생긴 일 (유언, 떠남, 굶주림)
local observations = {} -- 고고학자 → 지난밤에 본 것 (NPC 대사·투표용)
local lastTrades = {} -- 어제 저녁 교환 기록 (NPC 대사·투표용)
local lastOutside = {} -- 아침에 캠프 밖에 있던 사람 { Who, Place } (NPC 대사·투표용)

local function fill(template: string, values): string
	local result = template
	for key, value in values do
		result = string.gsub(result, "{" .. key .. "}", tostring(value))
	end
	return result
end

----------------------------------------------------------------
-- 장소 이름 : "제단 근처", "늪 근처", "북동쪽 정글"
----------------------------------------------------------------

function NightLog.DescribePlace(position: Vector3): string
	local info = MapBuilder.Info
	local best, bestDist = nil, CLUE.LandmarkRuinDistance
	for _, ruin in info.Ruins do
		local d = (Vector3.new(ruin.Position.X, 0, ruin.Position.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
		if d < bestDist then
			best, bestDist = ruin.Name, d
		end
	end
	if best then
		return best .. " 근처"
	end
	for _, swamp in info.Swamps do
		local d = (Vector3.new(swamp.Pos.X, 0, swamp.Pos.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
		if d < CLUE.LandmarkSwampDistance + swamp.Size / 2 then
			return "늪 근처"
		end
	end
	local fire = info.FirePosition
	local dx, dz = position.X - fire.X, position.Z - fire.Z
	local angle = math.deg(math.atan2(dx, -dz)) % 360 -- 북쪽 = -Z
	local index = math.floor((angle + 22.5) / 45) % 8 + 1
	return COMPASS[index] .. "쪽 정글"
end

-- 지도용 좌표 (-1 ~ 1, 모닥불이 가운데, 위쪽이 북쪽)
local function mapPoint(position: Vector3)
	local fire = MapBuilder.Info.FirePosition
	local half = Config.Map.HalfSize
	return { X = (position.X - fire.X) / half, Y = (position.Z - fire.Z) / half }
end

----------------------------------------------------------------
-- 밤 기록
----------------------------------------------------------------

function NightLog.StartNight(day: number)
	night = {
		Day = day,
		StartedAt = os.clock(),
		MonsterStart = nil,
		Trail = {},
		Catch = nil,
		VanishAt = nil,
		Watch = {}, -- 보는 사람 → { Awake, Seen = { [사람] = true }, SawMonster }
		AwakeAtVanish = {},
	}
end

-- 괴물이 있는 동안 1초마다 : 누가 누구를 봤는지, 괴물 발자국
local function sample(holder: Instance)
	if not night then
		return
	end
	local monsterPos = Monster.GetPosition()
	if monsterPos then
		table.insert(night.Trail, mapPoint(monsterPos))
	end
	local alive = Roster.GetAlive()
	for _, observer in alive do
		if observer ~= holder and not Sleep.IsSleeping(observer) then
			local eye = Roster.GetRoot(observer)
			if eye then
				local watch = night.Watch[observer] or { Awake = 0, Seen = {}, SawMonster = false }
				night.Watch[observer] = watch
				watch.Awake += 1
				for _, other in alive do
					local character = Roster.GetCharacter(other)
					local root = Roster.GetRoot(other)
					if other ~= observer and root and character and not Visibility.IsHidden(character) then
						local close = (root.Position - eye.Position).Magnitude <= Config.Night.FogSightRadius
						if close and not Monster.IsInTent(root) then
							watch.Seen[other] = true
						end
					end
				end
				if monsterPos and (monsterPos - eye.Position).Magnitude <= Config.Night.FogSightRadius then
					watch.SawMonster = true
				end
			end
		end
	end
end

local function startSampling(holder: Instance)
	if not night then
		return
	end
	night.MonsterStart = (os.clock() - night.StartedAt) * Config.Time.TestSpeed
	task.spawn(function()
		while Monster.IsActive() do
			sample(holder)
			task.wait(Config.Night.WitnessSampleSeconds / Config.Time.TestSpeed)
		end
	end)
end

----------------------------------------------------------------
-- 아침 보고서
----------------------------------------------------------------

local function namesOf(list): string
	local names = {}
	for _, who in list do
		table.insert(names, Roster.GetName(who))
	end
	table.sort(names)
	return table.concat(names, ", ")
end

-- 한 사람이 본 것 (NPC 투표·대사용으로도 저장)
local function observe(who: Instance)
	local result = { Awake = false, NotSeen = {}, SawMonster = false, SawVanish = false }
	if not night or not night.MonsterStart then
		return result
	end
	local watch = night.Watch[who]
	if watch and watch.Awake > 0 then
		result.Awake = true
		result.SawMonster = watch.SawMonster
		for _, other in Roster.GetAll() do
			if other ~= who and not watch.Seen[other] and (not Roster.IsGhost(other) or (night.Catch and night.Catch.Victim == other)) then
				table.insert(result.NotSeen, other)
			end
		end
	end
	result.SawVanish = night.AwakeAtVanish[who] == true
	return result
end

local function buildReport(who: Instance, outside, mapData)
	local lines = {}
	local seen = observations[who]
	if not night or not night.MonsterStart then
		table.insert(lines, TEXT.QuietNight)
	elseif not seen.Awake then
		table.insert(lines, TEXT.Slept)
	else
		table.insert(lines, fill(TEXT.MonsterTime, { ["초"] = math.floor(night.MonsterStart) }))
		if #seen.NotSeen > 0 then
			table.insert(lines, fill(TEXT.NotSeen, { ["이름들"] = namesOf(seen.NotSeen) }))
		else
			table.insert(lines, TEXT.AllSeen)
		end
		if seen.SawMonster then
			table.insert(lines, TEXT.SawMonster)
		end
	end
	if night and night.VanishPlace and seen.SawVanish then
		table.insert(lines, fill(TEXT.Vanished, { ["장소"] = night.VanishPlace }))
	end
	if night and night.Catch then
		local key = night.Catch.Escaped and TEXT.Escaped or TEXT.Caught
		table.insert(lines, fill(key, { ["이름"] = night.Catch.Name }))
	end
	if #outside > 0 then
		table.insert(lines, fill(TEXT.Outside, { ["이름들"] = table.concat(outside, ", ") }))
	else
		table.insert(lines, TEXT.AllInside)
	end
	for _, event in dayEvents do
		table.insert(lines, event)
	end
	-- 어제 저녁 교환 기록 (모두에게 공개)
	for _, record in Trade.GetLog() do
		table.insert(lines, fill(TEXT.Trade, {
			["이름"] = record.From,
			["받은사람"] = record.To,
			["유물1"] = record.Gave,
			["유물2"] = record.Got,
		}))
	end
	if #mapData.Trail > 0 then
		table.insert(lines, TEXT.Footprints)
	end
	return {
		Title = fill(TEXT.Title, { ["날"] = GameState.Get("Day") }),
		Lines = lines,
		Map = mapData,
	}
end

-- 아침 : 모두에게 보고서를 보내요
function NightLog.SendMorningReports()
	local info = MapBuilder.Info

	-- 아침에 캠프(빛) 밖에 있던 사람들 (저주 보유자는 늘 빛 밖에서 깨어나요)
	local outside, outsideDots = {}, {}
	table.clear(lastOutside)
	for _, who in Roster.GetAlive() do
		local root = Roster.GetRoot(who)
		if root and not CampStore.IsInLight(root.Position) then
			local place = NightLog.DescribePlace(root.Position)
			table.insert(lastOutside, { Who = who, Place = place })
			table.insert(outside, string.format("%s(%s)", Roster.GetName(who), place))
			local dot = mapPoint(root.Position)
			dot.Name = Roster.GetName(who)
			table.insert(outsideDots, dot)
		end
	end
	table.sort(outside)

	-- 모두가 보는 발자국 지도
	local ruins = {}
	for _, ruin in info.Ruins do
		local p = mapPoint(ruin.Position)
		p.Name = ruin.Name
		table.insert(ruins, p)
	end
	local swamps = {}
	for _, swamp in info.Swamps do
		local p = mapPoint(swamp.Pos)
		p.Size = swamp.Size / Config.Map.HalfSize
		table.insert(swamps, p)
	end
	local mapData = {
		CampRadius = CampStore.GetLightRadius() / Config.Map.HalfSize,
		Ruins = ruins,
		Swamps = swamps,
		Trail = night and night.Trail or {},
		Vanish = night and night.VanishPoint or nil,
		Catch = night and night.Catch and night.Catch.Point or nil,
		Outside = outsideDots,
	}

	table.clear(observations)
	for _, who in Roster.GetAll() do
		observations[who] = observe(who)
	end
	for _, who in Roster.GetAll() do
		if who:IsA("Player") then
			Remotes.MorningReport:FireClient(who, buildReport(who, outside, mapData))
		end
	end
	table.clear(dayEvents)
	lastTrades = table.clone(Trade.GetLog())
	Trade.ClearLog()
end

-- 어제 저녁 교환 기록 { From, To, Gave, Got } (이름과 유물 글자)
function NightLog.GetLastTrades()
	return lastTrades
end

-- 아침에 캠프 밖에 있던 사람들 { Who, Place }
function NightLog.GetOutside()
	return lastOutside
end

-- NPC가 쓸 수 있게 : 지난밤 이 사람이 본 것
function NightLog.GetObservation(who: Instance)
	return observations[who]
end

function NightLog.GetNight()
	return night
end

function NightLog.Reset()
	night = nil
	lastTrades = {}
	table.clear(lastOutside)
	table.clear(dayEvents)
	table.clear(observations)
end

function NightLog.Init()
	Monster.Activated:Connect(function(holder)
		startSampling(holder)
	end)
	Monster.Caught:Connect(function(victim, escaped, position)
		if night then
			night.Catch = { Victim = victim, Name = Roster.GetName(victim), Escaped = escaped, Point = mapPoint(position) }
		end
	end)
	Monster.Vanished:Connect(function(holder, position)
		if not night then
			return
		end
		night.VanishPlace = NightLog.DescribePlace(position)
		night.VanishPoint = mapPoint(position)
		table.insert(night.Trail, mapPoint(position))
		for _, who in Roster.GetAlive() do
			if who ~= holder and not Sleep.IsSleeping(who) then
				night.AwakeAtVanish[who] = true
			end
		end
	end)
	-- 유언과 떠남 기록
	Inventory.Moved:Connect(function(_item, from, to, reason)
		if reason == "Trade" then
			return -- 교환 기록은 Trade가 따로 남겨요
		end
		local key = (reason == "Left") and TEXT.LeftWill or TEXT.GhostWill
		local line = fill(key, { ["이름"] = Roster.GetName(from), ["받은사람"] = Roster.GetName(to) })
		if not table.find(dayEvents, line) then
			table.insert(dayEvents, line)
		end
	end)
	Health.BecameGhost:Connect(function(who, reason)
		if reason == "Starved" then
			table.insert(dayEvents, fill(TEXT.Starved, { ["이름"] = Roster.GetName(who) }))
		end
	end)
end

return NightLog
