-- 검은 그림자 괴물이에요. 저주 보유자가 조는 동안 그 자리에 나타나 빛 밖의 가장 가까운 사람을 쫓아요.
-- 한 명을 잡으면(뿌리쳐도) 바로 사라지고, 사라진 자리에 저주 보유자가 다시 나타나요. 하룻밤에 한 번만 잡아요.
-- 괴물 모델은 단순한 파츠 조합이고, 어떤 캐릭터의 모습 정보도 담지 않아요. (정체가 드러나지 않게)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config)
local Remotes = require(ReplicatedStorage.Remotes)
local Signal = require(ReplicatedStorage.Signal)
local Systems = ServerScriptService.Systems
local MapBuilder = require(Systems.MapBuilder)
local Roster = require(Systems.Roster)
local CampStore = require(Systems.CampStore)
local Health = require(Systems.Health)
local Visibility = require(Systems.Visibility)

local M = Config.Monster

local COLORS = Config.Colors
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local ROOT_HEIGHT = 4.5 -- 땅에서 몸 가운데까지

local Monster = {}

local function part(model: Model, root: BasePart, offset: CFrame, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = root.CFrame * offset
	p.Parent = model
	return p
end

-- groundCFrame : 괴물이 서 있을 땅 위치와 방향
function Monster.BuildShadow(groundCFrame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Monster"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(3, 6, 2)
	root.CFrame = groundCFrame * CFrame.new(0, ROOT_HEIGHT, 0)
	root.Parent = model
	model.PrimaryPart = root

	local body = COLORS.MonsterBody
	-- 몸통과 갈라진 돌 무늬
	part(model, root, CFrame.new(0, 0.5, 0), Vector3.new(3.4, 4, 2), body)
	part(model, root, CFrame.new(0.6, 1, -1.02), Vector3.new(0.2, 2.6, 0.05), COLORS.MonsterCrack)
	-- 머리 : 오래된 석상처럼 각진 얼굴
	part(model, root, CFrame.new(0, 3.4, 0), Vector3.new(2.2, 2, 2), body)
	part(model, root, CFrame.new(-0.5, 3.5, -1.02), Vector3.new(0.45, 0.3, 0.1), COLORS.MonsterEye, Enum.Material.Neon)
	part(model, root, CFrame.new(0.5, 3.5, -1.02), Vector3.new(0.45, 0.3, 0.1), COLORS.MonsterEye, Enum.Material.Neon)
	-- 길게 늘어진 팔
	part(model, root, CFrame.new(-2.3, 0, -0.3) * CFrame.Angles(0.25, 0, 0.1), Vector3.new(1, 5, 1), body)
	part(model, root, CFrame.new(2.3, 0, -0.3) * CFrame.Angles(0.25, 0, -0.1), Vector3.new(1, 5, 1), body)
	-- 다리
	part(model, root, CFrame.new(-0.8, -3, 0), Vector3.new(1.2, 3, 1.2), body)
	part(model, root, CFrame.new(0.8, -3, 0), Vector3.new(1.2, 3, 1.2), body)

	-- 몸에서 피어오르는 검은 안개
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE_TEXTURE
	smoke.Color = ColorSequence.new(COLORS.MonsterSmoke)
	smoke.Size = NumberSequence.new(3, 6)
	smoke.Transparency = NumberSequence.new(0.4, 1)
	smoke.Lifetime = NumberRange.new(1, 2)
	smoke.Rate = 12
	smoke.Speed = NumberRange.new(1, 3)
	smoke.LightInfluence = 0
	smoke.Parent = root

	return model
end

----------------------------------------------------------------
-- 밤 사냥
----------------------------------------------------------------

Monster.Activated = Signal.new() -- (holder, position) 괴물이 나타났어요
Monster.Caught = Signal.new() -- (victim, escaped, position) 누군가를 잡았어요 (뿌리쳤으면 escaped = true)
Monster.Vanished = Signal.new() -- (holder, position) 괴물이 사라지고 저주 보유자가 그 자리에 나타났어요

local rng = Random.new()
local active = nil -- { Holder, Model, Connection, CaughtTonight, Target, NextThink, Wander }
local caughtThisNight = false

function Monster.IsActive(): boolean
	return active ~= nil
end

function Monster.GetPosition(): Vector3?
	return active and active.Model:GetPivot().Position or nil
end

function Monster.GetHolder(): Instance?
	return active and active.Holder or nil
end

-- 텐트 안에 혼자 있으면 안전해요 (둘 이상이면 안전하지 않아요)
local function isSafeInTent(root: BasePart): boolean
	for _, tent in MapBuilder.Info.Tents do
		local zone = tent.Zone
		local localPos = zone.CFrame:PointToObjectSpace(root.Position)
		local half = zone.Size / 2
		if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y + 3 and math.abs(localPos.Z) <= half.Z then
			local count = 0
			for _, other in Roster.GetAlive() do
				local otherRoot = Roster.GetRoot(other)
				if otherRoot then
					local p = zone.CFrame:PointToObjectSpace(otherRoot.Position)
					if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y + 3 and math.abs(p.Z) <= half.Z then
						count += 1
					end
				end
			end
			return count <= Config.Night.TentCapacity
		end
	end
	return false
end

-- 텐트 안에 있나? (안개 속 목격 판정에도 써요 : 텐트 안 사람은 밖에서 안 보여요)
function Monster.IsInTent(root: BasePart): boolean
	for _, tent in MapBuilder.Info.Tents do
		local zone = tent.Zone
		local p = zone.CFrame:PointToObjectSpace(root.Position)
		local half = zone.Size / 2
		if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y + 3 and math.abs(p.Z) <= half.Z then
			return true
		end
	end
	return false
end

-- 지금 이 사람을 쫓을 수 있나? (빛 안이나 텐트 안이면 안전)
function Monster.IsHuntable(who: Instance): boolean
	local root = Roster.GetRoot(who)
	if not root or Roster.IsGhost(who) then
		return false
	end
	return not CampStore.IsInLight(root.Position) and not isSafeInTent(root)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- 빛 안으로는 못 들어가요 : 빛 가장자리 바깥으로 밀어내요
local function keepOutOfLight(position: Vector3): Vector3
	if not CampStore.IsInLight(position) then
		return position
	end
	local fire = MapBuilder.Info.FirePosition
	local out = flat(position - fire)
	out = out.Magnitude > 0 and out.Unit or Vector3.xAxis
	local edge = fire + out * (CampStore.GetLightRadius() + M.LightPushMargin)
	return Vector3.new(edge.X, position.Y, edge.Z)
end

local function pickTarget(from: Vector3, holder: Instance): Instance?
	local best, bestDist = nil, math.huge
	for _, who in Roster.GetAlive() do
		if who ~= holder and Monster.IsHuntable(who) then
			local root = Roster.GetRoot(who)
			local dist = (flat(root.Position) - flat(from)).Magnitude
			if dist < bestDist then
				best, bestDist = who, dist
			end
		end
	end
	return best
end

-- 잡았을 때 : 체력에 따라 뿌리칠 수 있어요
local function resolveCatch(victim: Instance, position: Vector3)
	local chance = Config.Health.EscapeChance[Health.Get(victim)] or 0
	local escaped = rng:NextNumber() < chance
	if escaped then
		Health.Damage(victim, Config.Health.EscapeCost, "Monster")
		if victim:IsA("Player") then
			Remotes.ScreenFlash:FireClient(victim, "😱 괴물을 뿌리치고 도망쳤어! 체력이 1칸 줄었어")
		end
	else
		if victim:IsA("Player") then
			Remotes.ScreenFlash:FireClient(victim, "👻 안개 속에서 무언가에게 잡혔어...")
		end
		Health.MakeGhost(victim, "Monster")
	end
	Monster.Caught:Fire(victim, escaped, position)
end

-- 괴물이 사라지고, 그 자리에 저주 보유자가 다시 나타나요
function Monster.Vanish()
	local state = active
	if not state then
		return
	end
	active = nil
	state.Connection:Disconnect()
	local position = state.Model:GetPivot().Position
	state.Model:Destroy()

	local holder = state.Holder
	local character = Roster.GetCharacter(holder)
	if character and character.Parent then
		local root = Roster.GetRoot(holder)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local height = humanoid and (humanoid.HipHeight + (root and root.Size.Y / 2 or 0)) or 3
		local ground = Vector3.new(position.X, MapBuilder.Info.Center.Y, position.Z)
		character:PivotTo(CFrame.new(ground + Vector3.new(0, height, 0)))
		Visibility.Show(character)
	end
	Monster.Vanished:Fire(holder, position)
end

local function step(dt: number)
	local state = active
	if not state then
		return
	end
	local model = state.Model
	local here = model:GetPivot().Position
	local now = os.clock()

	-- 가끔 쫓을 사람을 다시 골라요
	if now >= state.NextThink then
		state.NextThink = now + M.RepathSeconds
		state.Target = pickTarget(here, state.Holder)
		if not state.Target and (not state.Wander or (flat(state.Wander) - flat(here)).Magnitude < M.CatchDistance) then
			local angle = rng:NextNumber(0, math.pi * 2)
			state.Wander = here + Vector3.new(math.cos(angle), 0, math.sin(angle)) * M.WanderRadius
		end
	end

	local goal, speed
	local targetRoot = state.Target and Roster.GetRoot(state.Target)
	if targetRoot and Monster.IsHuntable(state.Target) then
		goal, speed = targetRoot.Position, M.WalkSpeed
	else
		state.Target = nil
		goal, speed = state.Wander or here, M.WalkSpeed * M.WanderSpeedFactor
	end

	local toGoal = flat(goal - here)
	local distance = toGoal.Magnitude
	-- 잡았다!
	if state.Target and distance <= M.CatchDistance and not caughtThisNight then
		caughtThisNight = true
		resolveCatch(state.Target, here)
		Monster.Vanish()
		return
	end
	if distance > 0.05 then
		local move = toGoal.Unit * math.min(speed * dt, distance)
		local nextPos = keepOutOfLight(here + move)
		model:PivotTo(CFrame.lookAt(nextPos, nextPos + toGoal.Unit))
	end
end

-- 저주 보유자가 졸기 시작하면 Sleep이 불러요
function Monster.Activate(holder: Instance)
	if active or caughtThisNight or Roster.IsGhost(holder) then
		return
	end
	local root = Roster.GetRoot(holder)
	local character = Roster.GetCharacter(holder)
	if not root or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local height = humanoid and (humanoid.HipHeight + root.Size.Y / 2) or 3
	local feet = root.Position - Vector3.new(0, height, 0)
	local look = root.CFrame.LookVector
	-- 원래 몸은 숨기고 그 자리에 괴물이 나타나요
	Visibility.Hide(character)
	local start = keepOutOfLight(feet)
	local model = Monster.BuildShadow(CFrame.lookAt(start, start + Vector3.new(look.X, 0, look.Z)))
	model.Parent = Workspace
	active = {
		Holder = holder,
		Model = model,
		Target = nil,
		Wander = nil,
		NextThink = 0,
		Connection = RunService.Heartbeat:Connect(step),
	}
	Monster.Activated:Fire(holder, start)
end

-- 새 밤 : 오늘 밤은 아직 아무도 안 잡았어요
function Monster.ResetNight()
	caughtThisNight = false
end

function Monster.Reset()
	Monster.Vanish()
	caughtThisNight = false
end

function Monster.Init()
end

return Monster
