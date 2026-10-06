-- NPC 한 명이 무엇을 할지 정하는 상태 머신이에요.
-- 낮 : 한 번 나갈 때마다 유물·장작·식량 셋 다 챙겨서 캠프로 돌아와요.
-- 저녁·아침 : 캠프에 모여요.
-- 밤 : 모닥불 빛 안이나 텐트로 가요. 길찾기는 목적지가 바뀔 때만 해요. (매 프레임 하지 않아요)

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Config)
local GameState = require(ReplicatedStorage.GameState)
local Systems = ServerScriptService.Systems
local MapBuilder = require(Systems.MapBuilder)
local Roster = require(Systems.Roster)
local CampStore = require(Systems.CampStore)
local Excavation = require(Systems.Excavation)
local Gathering = require(Systems.Gathering)

local NPC = Config.Npc
local TAU = math.pi * 2
local NEAR_WAYPOINT = NPC.NearWaypoint

local STATUS = {
	Dig = "⛏️",
	Wood = "🪵",
	Food = "🍖",
	Camp = "🔥",
	Tent = "⛺",
	Ghost = "👻",
	Rest = "💤",
}

local NpcBrain = {}
NpcBrain.__index = NpcBrain

local rng = Random.new()
local tentOwner = {} -- 텐트 번호 → NPC 모델 (텐트 하나에 한 명)

----------------------------------------------------------------
-- 만들기
----------------------------------------------------------------

function NpcBrain.new(model: Model, setStatus)
	local self = setmetatable({}, NpcBrain)
	self.Model = model
	self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	self.Root = model:FindFirstChild("HumanoidRootPart")
	self.SetStatus = setStatus
	self.Running = false
	self.Phase = nil
	self.Path = PathfindingService:CreatePath({
		AgentRadius = NPC.AgentRadius,
		AgentHeight = NPC.AgentHeight,
		AgentCanJump = true,
	})
	return self
end

----------------------------------------------------------------
-- 작은 도우미
----------------------------------------------------------------

-- 지금 하던 일을 그만둬야 하나? (시간대가 바뀜, 유령이 됨, 꺼짐)
function NpcBrain:Interrupted(): boolean
	return not self.Running
		or not self.Model.Parent
		or GameState.Get("Phase") ~= self.Phase
		or Roster.IsGhost(self.Model) ~= self.WasGhost
end

-- 플레이어와 멀면 느긋하게 확인해요 (성능)
function NpcBrain:IsFar(): boolean
	local here = self.Root.Position
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - here).Magnitude < NPC.FarDistance then
			return false
		end
	end
	return true
end

function NpcBrain:Poll(): number
	return self:IsFar() and NPC.FarPollSeconds or NPC.PollSeconds
end

-- 정해진 시간 동안 기다려요. 중간에 그만둬야 하면 false
function NpcBrain:WaitFor(seconds: number): boolean
	local finish = os.clock() + seconds
	while os.clock() < finish do
		if self:Interrupted() then
			return false
		end
		task.wait(math.min(self:Poll(), finish - os.clock()))
	end
	return not self:Interrupted()
end

-- 시간대가 바뀔 때까지 그 자리에서 기다려요
function NpcBrain:WaitUntilInterrupted()
	while not self:Interrupted() do
		task.wait(self:Poll())
	end
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- 한 지점까지 걸어가요. 도착하면 true
function NpcBrain:MoveStep(target: Vector3, closeEnough: number): boolean
	local humanoid = self.Humanoid
	for attempt = 1, 2 do
		humanoid:MoveTo(target)
		local finish = os.clock() + NPC.WaypointTimeout
		while os.clock() < finish do
			if self:Interrupted() then
				return false
			end
			if flatDistance(self.Root.Position, target) <= closeEnough then
				return true
			end
			task.wait(self:Poll())
		end
		humanoid.Jump = true -- 막혔으면 한 번 뛰어 보고 다시
		if attempt == 1 then
			task.wait(self:Poll())
		end
	end
	return false
end

-- 길을 찾아서 목적지까지 걸어가요
function NpcBrain:WalkTo(target: Vector3): boolean
	if flatDistance(self.Root.Position, target) <= NPC.ArriveDistance then
		return true
	end
	local ok = pcall(function()
		self.Path:ComputeAsync(self.Root.Position, target)
	end)
	local waypoints
	if ok and self.Path.Status == Enum.PathStatus.Success then
		waypoints = self.Path:GetWaypoints()
	else
		waypoints = { { Position = target, Action = Enum.PathWaypointAction.Walk } } -- 길을 못 찾으면 곧장
	end

	for index, waypoint in waypoints do
		if index > 1 or #waypoints == 1 then
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				self.Humanoid.Jump = true
			end
			local last = index == #waypoints
			if not self:MoveStep(waypoint.Position, last and NPC.ArriveDistance or NEAR_WAYPOINT) then
				return false
			end
		end
	end
	return flatDistance(self.Root.Position, target) <= NPC.ArriveDistance + NEAR_WAYPOINT
end

-- 모닥불 둘레의 아무 곳 (min~max 거리)
local function pointAroundFire(minRadius: number, maxRadius: number): Vector3
	local fire = MapBuilder.Info.FirePosition
	local angle = rng:NextNumber(0, TAU)
	local radius = rng:NextNumber(minRadius, math.max(minRadius, maxRadius))
	return fire + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

-- 가까운 몇 곳 중 하나를 골라요 (모두 같은 곳으로 몰리지 않게)
function NpcBrain:PickNearby(list, positionOf)
	table.sort(list, function(a, b)
		return (positionOf(a) - self.Root.Position).Magnitude < (positionOf(b) - self.Root.Position).Magnitude
	end)
	return list[rng:NextInteger(1, math.min(NPC.NearestChoices, #list))]
end

----------------------------------------------------------------
-- 낮 : 유물·장작·식량 챙기기
----------------------------------------------------------------

function NpcBrain:ReturnToCamp()
	self.SetStatus(STATUS.Camp)
	self:WalkTo(pointAroundFire(NPC.CampMeetRadiusMin, NPC.CampMeetRadiusMax))
end

-- 가까운 유적에서 유물 하나 발굴
function NpcBrain:DoDig(): boolean
	local ruins = Excavation.GetOpenRuins()
	if #ruins == 0 then
		return false
	end
	local ruin = self:PickNearby(ruins, function(r)
		return r.DigSpot.Position
	end)
	self.SetStatus(STATUS.Dig)
	if not self:WalkTo(ruin.DigSpot.Position) then
		return false
	end
	if not self:WaitFor(Config.Dig.DigSeconds) then
		return false
	end
	return Excavation.Dig(self.Model, ruin.Id) ~= nil
end

-- 가까운 곳에서 장작이나 식량 하나 줍기
function NpcBrain:DoGather(kind: string): boolean
	local spots = kind == "Wood" and Gathering.GetActiveWoodSpots() or Gathering.GetActiveFoodSpots()
	local free = {}
	for _, entry in spots do
		if entry.ReservedBy == nil or entry.ReservedBy == self.Model then
			table.insert(free, entry)
		end
	end
	if #free == 0 then
		return false
	end
	local entry = self:PickNearby(free, function(e)
		return e.Spot.Position
	end)
	entry.ReservedBy = self.Model
	self.SetStatus(STATUS[kind])
	local taken = false
	if self:WalkTo(entry.Spot.Position) and entry.Active then
		local seconds = kind == "Wood" and Config.Fire.ChopSeconds or Config.Food.GatherSeconds
		if self:WaitFor(seconds) then
			taken = Gathering.TakeSpot(entry, self.Model)
		end
	end
	if entry.ReservedBy == self.Model then
		entry.ReservedBy = nil
	end
	return taken
end

-- 낮 : 유물 → 장작 → 식량을 차례로 챙기고 캠프로 돌아와요 (한 바퀴)
-- 다 떨어진 것은 건너뛰어요. 셋 다 없으면 캠프에서 쉬어요
function NpcBrain:DoDay()
	local anything = false
	for _, job in { "Dig", "Wood", "Food" } do
		if self:Interrupted() then
			return
		end
		local done
		if job == "Dig" then
			done = self:DoDig()
		else
			done = self:DoGather(job)
		end
		anything = anything or done
	end
	if self:Interrupted() then
		return
	end
	self:ReturnToCamp() -- 모닥불 가까이 오면 장작·식량은 저절로 창고에 들어가요
	if not anything then
		self.SetStatus(STATUS.Rest)
		self:WaitUntilInterrupted()
		return
	end
	self:WaitFor(NPC.WorkPause)
end

----------------------------------------------------------------
-- 저녁·아침 : 캠프에 모이기 / 밤 : 빛 안이나 텐트로
----------------------------------------------------------------

function NpcBrain:DoCamp()
	self.SetStatus(STATUS.Camp)
	self:WalkTo(pointAroundFire(NPC.CampMeetRadiusMin, NPC.CampMeetRadiusMax))
	self:WaitUntilInterrupted()
end

function NpcBrain:ReleaseTent()
	for index, owner in tentOwner do
		if owner == self.Model then
			tentOwner[index] = nil
		end
	end
end

function NpcBrain:DoNight()
	-- 빈 텐트가 있으면 가끔 텐트로 숨어요
	if rng:NextNumber() < NPC.TentChance then
		for _, tent in MapBuilder.Info.Tents do
			if tentOwner[tent.Index] == nil then
				tentOwner[tent.Index] = self.Model
				self.SetStatus(STATUS.Tent)
				self:WalkTo(tent.Zone.Position)
				self:WaitUntilInterrupted()
				self:ReleaseTent()
				return
			end
		end
	end
	local safe = CampStore.GetLightRadius() * NPC.NightFireRadiusFactor
	self.SetStatus(STATUS.Camp)
	self:WalkTo(pointAroundFire(NPC.NightFireMinRadius, safe))
	self:WaitUntilInterrupted()
end

function NpcBrain:DoGhost()
	self.SetStatus(STATUS.Ghost)
	self:WalkTo(pointAroundFire(NPC.CampMeetRadiusMax, NPC.CampMeetRadiusMax * 2))
	self:WaitUntilInterrupted()
end

----------------------------------------------------------------
-- 생각 반복
----------------------------------------------------------------

function NpcBrain:Start()
	if self.Running then
		return
	end
	self.Running = true
	task.spawn(function()
		while self.Running and self.Model.Parent do
			self.Phase = GameState.Get("Phase")
			self.WasGhost = Roster.IsGhost(self.Model)
			local ok, err = pcall(function()
				if self.WasGhost then
					self:DoGhost()
				elseif self.Phase == "Day" then
					self:DoDay()
				elseif self.Phase == "Night" then
					self:DoNight()
				elseif self.Phase == "Ending" or self.Phase == "Result" then
					self:WaitUntilInterrupted() -- 엔딩·결과 화면에서는 가만히
				else
					self:DoCamp()
				end
			end)
			if not ok then
				warn("[NpcBrain]", self.Model.Name, err)
			end
			task.wait(self:IsFar() and NPC.FarThinkSeconds or NPC.ThinkSeconds)
		end
		self:ReleaseTent()
	end)
end

function NpcBrain:Stop()
	self.Running = false
	self:ReleaseTent()
	if self.Humanoid then
		self.Humanoid:MoveTo(self.Root.Position)
	end
end

function NpcBrain:ResetForExpedition()
	self:ReleaseTent()
end

return NpcBrain
