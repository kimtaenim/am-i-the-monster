-- 사냥감(멧돼지, 카피바라, 정글닭)을 정글에 풀어 놓고 움직여요.
-- 무기에 맞으면 놀라서 도망치고, 체력이 0이 되면 반짝이며 기절해서 사라지고 고기를 떨어뜨려요.
-- 피나 잔인한 모습은 없어요. 고기를 주우면 손에 들고 캠프로 가져가야 해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config)
local MapBuilder = require(ServerScriptService.Systems.MapBuilder)
local Gathering = require(ServerScriptService.Systems.Gathering)

local H = Config.Hunt
local COLORS = Config.Colors
local TAU = math.pi * 2
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local Hunting = {}

local rng = Random.new()
local preyFolder: Folder
local dropFolder: Folder
local preyList = {} -- 살아 있는 사냥감들
local byModel = {} -- 모델 → 사냥감 정보

----------------------------------------------------------------
-- 사냥감 모양 (모두 -Z 쪽을 바라봐요)
----------------------------------------------------------------

local BALL = Enum.PartType.Ball

-- 몸 조각 : 뿌리 파츠(HumanoidRootPart)에 붙어서 같이 움직여요
local function piece(model: Model, root: BasePart, offset: CFrame, size: Vector3, color: Color3, shape: Enum.PartType?)
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.Color = color
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- 동물마다 : 뿌리 크기, 땅에서 뿌리 바닥까지 높이(HipHeight), 몸 조각들
local PREY_SHAPES = {
	Boar = {
		RootSize = Vector3.new(2.4, 2, 4),
		HipHeight = 1,
		Build = function(model, root)
			piece(model, root, CFrame.new(0, 0, 0), Vector3.new(2.4, 2, 3.6), COLORS.Boar)
			piece(model, root, CFrame.new(0, 0.1, -2.3), Vector3.new(1.8, 1.6, 1.4), COLORS.Boar)
			piece(model, root, CFrame.new(0, -0.2, -3.1), Vector3.new(1, 0.8, 0.5), COLORS.BoarSnout)
			piece(model, root, CFrame.new(-0.55, -0.1, -3.2), Vector3.new(0.2, 0.6, 0.2), COLORS.Tusk)
			piece(model, root, CFrame.new(0.55, -0.1, -3.2), Vector3.new(0.2, 0.6, 0.2), COLORS.Tusk)
			piece(model, root, CFrame.new(-0.6, 1.05, -2.2), Vector3.new(0.4, 0.5, 0.3), COLORS.Boar)
			piece(model, root, CFrame.new(0.6, 1.05, -2.2), Vector3.new(0.4, 0.5, 0.3), COLORS.Boar)
			for _, x in { -0.8, 0.8 } do
				for _, z in { -1.2, 1.2 } do
					piece(model, root, CFrame.new(x, -1.4, z), Vector3.new(0.5, 1.2, 0.5), COLORS.Boar)
				end
			end
		end,
	},
	Capybara = {
		RootSize = Vector3.new(2, 1.8, 3.2),
		HipHeight = 0.6,
		Build = function(model, root)
			piece(model, root, CFrame.new(0, 0, 0), Vector3.new(2, 1.8, 3.2), COLORS.Capybara)
			piece(model, root, CFrame.new(0, 0.3, -1.9), Vector3.new(1.4, 1.3, 1.4), COLORS.Capybara)
			piece(model, root, CFrame.new(0, 0.2, -2.65), Vector3.new(0.8, 0.5, 0.2), COLORS.CapybaraNose)
			piece(model, root, CFrame.new(-0.5, 1.05, -1.6), Vector3.new(0.3, 0.3, 0.2), COLORS.CapybaraNose)
			piece(model, root, CFrame.new(0.5, 1.05, -1.6), Vector3.new(0.3, 0.3, 0.2), COLORS.CapybaraNose)
			for _, x in { -0.6, 0.6 } do
				for _, z in { -1, 1 } do
					piece(model, root, CFrame.new(x, -1.2, z), Vector3.new(0.4, 0.6, 0.4), COLORS.Capybara)
				end
			end
		end,
	},
	Fowl = {
		RootSize = Vector3.new(1, 1, 1.4),
		HipHeight = 0.7,
		Build = function(model, root)
			piece(model, root, CFrame.new(0, 0, 0), Vector3.one * 1.2, COLORS.Fowl, BALL)
			piece(model, root, CFrame.new(0, 0.7, -0.6), Vector3.one * 0.6, COLORS.Fowl, BALL)
			piece(model, root, CFrame.new(0, 1.05, -0.6), Vector3.new(0.12, 0.3, 0.4), COLORS.FowlComb)
			piece(model, root, CFrame.new(0, 0.65, -0.95), Vector3.new(0.15, 0.15, 0.3), COLORS.Banana)
			piece(model, root, CFrame.new(0, 0.5, 0.7) * CFrame.Angles(0.8, 0, 0), Vector3.new(0.2, 0.4, 1.2), COLORS.FowlTail)
			piece(model, root, CFrame.new(-0.25, -0.8, 0), Vector3.new(0.12, 0.8, 0.12), COLORS.Banana)
			piece(model, root, CFrame.new(0.25, -0.8, 0), Vector3.new(0.12, 0.8, 0.12), COLORS.Banana)
		end,
	},
}

----------------------------------------------------------------
-- 위치 도우미
----------------------------------------------------------------

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- 지도 안, 캠프 밖으로 위치를 맞춰요
local function clampToJungle(pos: Vector3): Vector3
	local limit = Config.Map.HalfSize - H.MapEdgeMargin
	local p = Vector3.new(math.clamp(pos.X, -limit, limit), 0, math.clamp(pos.Z, -limit, limit))
	local minDist = Config.Map.CampClearRadius
	if p.Magnitude < minDist then
		p = (p.Magnitude > 0 and p.Unit or Vector3.xAxis) * minDist
	end
	return p
end

local function randomSpawnPoint(): Vector3
	local limit = Config.Map.HalfSize - H.MapEdgeMargin
	for _ = 1, Config.Map.PlaceTries do
		local p = Vector3.new(rng:NextNumber(-limit, limit), 0, rng:NextNumber(-limit, limit))
		if p.Magnitude >= H.MinSpawnDistance then
			return p
		end
	end
	return Vector3.new(H.MinSpawnDistance, 0, 0)
end

-- 사냥감을 놀라게 하는 것들 : 플레이어와 NPC 고고학자
local function threatPositions()
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			table.insert(list, root.Position)
		end
	end
	local npcFolder = Workspace:FindFirstChild("Archaeologists")
	if npcFolder then
		for _, npc in npcFolder:GetChildren() do
			local root = npc:FindFirstChild("HumanoidRootPart")
			if root and not Players:GetPlayerFromCharacter(npc) then
				table.insert(list, root.Position)
			end
		end
	end
	return list
end

----------------------------------------------------------------
-- 사냥감 만들기
----------------------------------------------------------------

local function spawnPrey(kind: string)
	local def = H.Prey[kind]
	local shape = PREY_SHAPES[kind]
	local model = Instance.new("Model")
	model.Name = kind
	model:SetAttribute("PreyKind", kind)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = shape.RootSize
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	shape.Build(model, root)

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = shape.HipHeight
	humanoid.WalkSpeed = def.WalkSpeed
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, state in { Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.Climbing } do
		humanoid:SetStateEnabled(state, false)
	end
	humanoid.Parent = model

	-- 머리 위 이름표
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(5, 1.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, shape.RootSize.Y / 2 + 1.5, 0)
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = COLORS.Label
	label.TextStrokeTransparency = 0.4
	label.Text = def.Name
	label.Parent = gui
	gui.Parent = root

	local home = randomSpawnPoint()
	model:PivotTo(CFrame.new(home + Vector3.new(0, shape.HipHeight + shape.RootSize.Y / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0))
	model.Parent = preyFolder
	root:SetNetworkOwner(nil) -- 서버가 직접 움직여요 (부정행위 방지)

	local prey = {
		Kind = kind,
		Def = def,
		Model = model,
		Root = root,
		Humanoid = humanoid,
		Label = label,
		Home = home,
		Health = def.Health,
		Fainted = false,
		NextWander = 0,
		FleeUntil = 0,
	}
	table.insert(preyList, prey)
	byModel[model] = prey
	return prey
end

----------------------------------------------------------------
-- 떨어진 고기
----------------------------------------------------------------

local function dropMeat(position: Vector3, amount: number)
	local model = Instance.new("Model")
	model.Name = "MeatDrop"
	local base = Instance.new("Part")
	base.Name = "Meat"
	base.Shape = Enum.PartType.Ball
	base.Size = Vector3.one * 1.4
	base.Color = COLORS.Meat
	base.Material = Enum.Material.SmoothPlastic
	base.Anchored = true
	base.CanCollide = false
	base.CFrame = CFrame.new(flat(position) + Vector3.new(0, 0.8, 0))
	base.Parent = model
	local bone = Instance.new("Part")
	bone.Shape = Enum.PartType.Cylinder
	bone.Size = Vector3.new(1.6, 0.35, 0.35)
	bone.Color = COLORS.Bone
	bone.Anchored = true
	bone.CanCollide = false
	bone.CFrame = base.CFrame * CFrame.new(0.9, 0, 0)
	bone.Parent = model
	model.PrimaryPart = base

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "줍기"
	prompt.ObjectText = string.format("🍖 고기 ×%d", amount)
	prompt.HoldDuration = H.PickupSeconds
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	local taken = false
	prompt.Triggered:Connect(function(player)
		if taken then
			return
		end
		taken = true
		Gathering.AddCarried(player, "Food", amount)
		model:Destroy()
	end)

	model.Parent = dropFolder
	task.delay(H.DropLifetime, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

----------------------------------------------------------------
-- 맞았을 때, 기절했을 때
----------------------------------------------------------------

local function flash(prey)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = COLORS.HitFlash
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 1
	highlight.Parent = prey.Model
	task.delay(H.HitFlashSeconds, function()
		highlight:Destroy()
	end)
end

local function faint(prey)
	prey.Fainted = true
	byModel[prey.Model] = nil
	local index = table.find(preyList, prey)
	if index then
		table.remove(preyList, index)
	end

	local root = prey.Root
	local position = root.Position
	prey.Humanoid.WalkSpeed = 0
	root.Anchored = true
	prey.Label.Text = "💫"

	-- 반짝이며 사라져요
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = SPARKLE_TEXTURE
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.6, 0)
	sparkles.Lifetime = NumberRange.new(0.6, 1)
	sparkles.Speed = NumberRange.new(4, 8)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Enabled = false
	sparkles.Parent = root
	sparkles:Emit(30)

	local info = TweenInfo.new(H.FaintSeconds)
	for _, part in prey.Model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			TweenService:Create(part, info, { Transparency = 1 }):Play()
		end
	end
	task.delay(H.FaintSeconds, function()
		prey.Model:Destroy()
		dropMeat(position, prey.Def.Food)
	end)
end

-- 무기에 맞은 사냥감 (Weapons가 불러요)
function Hunting.Damage(prey, amount: number, fromPosition: Vector3)
	if prey.Fainted then
		return
	end
	prey.Health -= amount
	flash(prey)
	if prey.Health <= 0 then
		faint(prey)
		return
	end
	-- 놀라서 반대쪽으로 도망쳐요
	prey.FleeFrom = fromPosition
	prey.FleeUntil = os.clock() + H.FleeSeconds
	prey.NextWander = 0
end

-- 파츠가 사냥감의 일부면 그 사냥감을 돌려줘요
function Hunting.FindPrey(part: Instance?)
	while part and part ~= preyFolder do
		local prey = byModel[part]
		if prey then
			return prey
		end
		part = part.Parent
	end
	return nil
end

-- 도끼처럼 가까이서 휘두를 때 : 앞쪽 가장 가까운 사냥감
function Hunting.FindPreyInFront(origin: Vector3, direction: Vector3, range: number)
	local best, bestDist = nil, range
	local forward = flat(direction)
	forward = forward.Magnitude > 0 and forward.Unit or Vector3.zAxis
	for _, prey in preyList do
		local offset = flat(prey.Root.Position - origin)
		local dist = offset.Magnitude
		if dist < bestDist and (dist < 1 or offset.Unit:Dot(forward) > 0.3) then
			best, bestDist = prey, dist
		end
	end
	return best
end

function Hunting.GetPreyFolder(): Folder
	return preyFolder
end

-- 모자란 사냥감을 다시 채워요 (아침마다 GameLoop가 불러요)
function Hunting.RefillAll()
	local counts = {}
	for _, prey in preyList do
		counts[prey.Kind] = (counts[prey.Kind] or 0) + 1
	end
	for kind, def in H.Prey do
		for _ = (counts[kind] or 0) + 1, def.Count do
			spawnPrey(kind)
		end
	end
end

----------------------------------------------------------------
-- 생각하기 : 어슬렁거리다가, 사람이 다가오거나 맞으면 도망쳐요
----------------------------------------------------------------

local function think(prey, threats, now)
	local pos = prey.Root.Position

	-- 가까운 사람이 있나?
	local nearest, nearestDist = nil, prey.Def.Skittish
	for _, threat in threats do
		local dist = (threat - pos).Magnitude
		if dist < nearestDist then
			nearest, nearestDist = threat, dist
		end
	end
	if nearest then
		prey.FleeFrom = nearest
		prey.FleeUntil = math.max(prey.FleeUntil, now + H.FleeSeconds / 2)
	end

	if now < prey.FleeUntil and prey.FleeFrom then
		local away = flat(pos - prey.FleeFrom)
		away = away.Magnitude > 0 and away.Unit or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
		prey.Humanoid.WalkSpeed = prey.Def.FleeSpeed
		prey.Humanoid:MoveTo(clampToJungle(flat(pos) + away * H.FleeDistance))
		return
	end

	prey.Humanoid.WalkSpeed = prey.Def.WalkSpeed
	if now >= prey.NextWander then
		local angle = rng:NextNumber(0, TAU)
		local target = prey.Home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(0, H.WanderRadius)
		prey.Humanoid:MoveTo(clampToJungle(target))
		prey.NextWander = now + rng:NextNumber(H.WanderPauseMin, H.WanderPauseMax)
	end
end

----------------------------------------------------------------
-- 시작
----------------------------------------------------------------

function Hunting.Init()
	local root = MapBuilder.Info.Root
	preyFolder = Instance.new("Folder")
	preyFolder.Name = "Prey"
	preyFolder.Parent = root
	dropFolder = Instance.new("Folder")
	dropFolder.Name = "MeatDrops"
	dropFolder.Parent = root

	Hunting.RefillAll()

	task.spawn(function()
		while true do
			task.wait(H.ThinkSeconds)
			local threats = threatPositions()
			local now = os.clock()
			for _, prey in table.clone(preyList) do
				if prey.Model.Parent and not prey.Fainted then
					think(prey, threats, now)
				end
			end
		end
	end)
end

return Hunting
