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
local CYL = Enum.PartType.Cylinder
local EGG = "Egg" -- 길쭉하거나 납작한 둥근 모양 (타원)
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- 원기둥 세우기
local FORWARD = CFrame.Angles(0, math.pi / 2, 0) -- 원기둥을 앞(-Z)으로 눕히기

-- 몸 조각 : 뿌리 파츠(HumanoidRootPart)에 붙어서 같이 움직여요
-- shape가 "Egg"면 크기에 맞춰 늘어난 둥근 공 모양이 돼요
local function piece(model: Model, root: BasePart, offset: CFrame, size: Vector3, color: Color3, shape: any?)
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	if shape == EGG then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	elseif shape then
		part.Shape = shape
	end
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

-- 반짝이는 동그란 눈 한 쌍 (까만 눈동자 + 하얀 빛 점)
local function eyes(model: Model, root: BasePart, x: number, y: number, z: number, size: number)
	for _, side in { -1, 1 } do
		piece(model, root, CFrame.new(side * x, y, z), Vector3.one * size, COLORS.EyeBlack, BALL)
		piece(model, root, CFrame.new(side * x + side * size * 0.12, y + size * 0.2, z - size * 0.38), Vector3.one * size * 0.35, COLORS.EyeShine, BALL)
	end
end

-- 짧은 원기둥 다리 네 개 (+ 발굽)
local function legs(model: Model, root: BasePart, x: number, z: number, top: number, height: number, diameter: number, color: Color3, hoof: Color3?)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			piece(model, root, CFrame.new(sx * x, top - height / 2, sz * z) * UPRIGHT, Vector3.new(height, diameter, diameter), color, CYL)
			if hoof then
				piece(model, root, CFrame.new(sx * x, top - height + 0.12, sz * z) * UPRIGHT, Vector3.new(0.25, diameter * 1.08, diameter * 1.08), hoof, CYL)
			end
		end
	end
end

-- 동물마다 : 뿌리 크기, 땅에서 뿌리 바닥까지 높이(HipHeight), 몸 조각들
local PREY_SHAPES = {
	Boar = {
		RootSize = Vector3.new(2.4, 2, 4),
		HipHeight = 0.85,
		Build = function(model, root)
			-- 통통한 몸과 등에 난 갈기
			piece(model, root, CFrame.new(0, 0, 0), Vector3.new(2.6, 2.2, 3.8), COLORS.Boar, EGG)
			piece(model, root, CFrame.new(0, 1.0, 0.1), Vector3.new(0.6, 0.7, 3), COLORS.BoarMane, EGG)
			-- 머리와 납작한 분홍 코
			piece(model, root, CFrame.new(0, 0.3, -2.05), Vector3.new(1.9, 1.7, 1.8), COLORS.Boar, EGG)
			piece(model, root, CFrame.new(0, 0.05, -3.0) * FORWARD, Vector3.new(0.5, 1.0, 1.0), COLORS.BoarSnout, CYL)
			piece(model, root, CFrame.new(-0.2, 0.08, -3.27), Vector3.one * 0.16, COLORS.EyeBlack, BALL)
			piece(model, root, CFrame.new(0.2, 0.08, -3.27), Vector3.one * 0.16, COLORS.EyeBlack, BALL)
			-- 작은 엄니
			piece(model, root, CFrame.new(-0.48, -0.15, -2.9) * CFrame.Angles(0, 0, 0.35), Vector3.new(0.16, 0.5, 0.16), COLORS.Tusk, EGG)
			piece(model, root, CFrame.new(0.48, -0.15, -2.9) * CFrame.Angles(0, 0, -0.35), Vector3.new(0.16, 0.5, 0.16), COLORS.Tusk, EGG)
			eyes(model, root, 0.5, 0.75, -2.78, 0.26)
			-- 쫑긋한 귀
			piece(model, root, CFrame.new(-0.62, 1.15, -1.85) * CFrame.Angles(0.2, 0, 0.4), Vector3.new(0.45, 0.65, 0.18), COLORS.BoarMane, EGG)
			piece(model, root, CFrame.new(0.62, 1.15, -1.85) * CFrame.Angles(0.2, 0, -0.4), Vector3.new(0.45, 0.65, 0.18), COLORS.BoarMane, EGG)
			legs(model, root, 0.8, 1.2, -0.75, 1.1, 0.55, COLORS.Boar, COLORS.Hoof)
			-- 동그란 꼬리
			piece(model, root, CFrame.new(0, 0.5, 1.95), Vector3.one * 0.35, COLORS.BoarMane, BALL)
		end,
	},
	Capybara = {
		RootSize = Vector3.new(2.2, 1.8, 3.4),
		HipHeight = 0.45,
		Build = function(model, root)
			-- 동글동글한 몸
			piece(model, root, CFrame.new(0, 0, 0), Vector3.new(2.4, 2, 3.4), COLORS.Capybara, EGG)
			-- 네모난 듯 둥근 얼굴과 코
			piece(model, root, CFrame.new(0, 0.55, -1.75) * CFrame.Angles(-0.15, 0, 0), Vector3.new(1.6, 1.5, 1.9), COLORS.Capybara, EGG)
			piece(model, root, CFrame.new(0, 0.38, -2.5), Vector3.new(1.3, 1.0, 0.9), COLORS.CapybaraSnout, EGG)
			piece(model, root, CFrame.new(-0.22, 0.55, -2.92), Vector3.one * 0.17, COLORS.EyeBlack, BALL)
			piece(model, root, CFrame.new(0.22, 0.55, -2.92), Vector3.one * 0.17, COLORS.EyeBlack, BALL)
			eyes(model, root, 0.55, 0.98, -2.2, 0.26)
			-- 작은 귀
			piece(model, root, CFrame.new(-0.52, 1.3, -1.45), Vector3.new(0.35, 0.32, 0.2), COLORS.CapybaraDark, EGG)
			piece(model, root, CFrame.new(0.52, 1.3, -1.45), Vector3.new(0.35, 0.32, 0.2), COLORS.CapybaraDark, EGG)
			legs(model, root, 0.7, 1.0, -0.65, 0.75, 0.5, COLORS.CapybaraDark, nil)
			-- 머리 위에 귤 하나 (카피바라는 귤을 좋아해요)
			piece(model, root, CFrame.new(0, 1.45, -1.7), Vector3.one * 0.5, COLORS.Orange, BALL)
			piece(model, root, CFrame.new(0, 1.72, -1.7), Vector3.new(0.18, 0.08, 0.3), COLORS.Leaf, EGG)
		end,
	},
	Fowl = {
		RootSize = Vector3.new(1, 1, 1.4),
		HipHeight = 0.7,
		Build = function(model, root)
			-- 동그란 몸과 주황 가슴
			piece(model, root, CFrame.new(0, 0, 0), Vector3.new(1.2, 1.2, 1.5), COLORS.Fowl, EGG)
			piece(model, root, CFrame.new(0, -0.05, -0.5), Vector3.new(0.9, 0.95, 0.7), COLORS.FowlBreast, EGG)
			-- 머리, 볏, 부리, 턱볏
			piece(model, root, CFrame.new(0, 0.75, -0.55), Vector3.one * 0.68, COLORS.Fowl, BALL)
			for i, z in { -0.4, -0.55, -0.7 } do
				piece(model, root, CFrame.new(0, 1.1 + (i == 2 and 0.06 or 0), z), Vector3.one * 0.22, COLORS.FowlComb, BALL)
			end
			piece(model, root, CFrame.new(0, 0.7, -0.95), Vector3.new(0.16, 0.13, 0.32), COLORS.Banana, EGG)
			piece(model, root, CFrame.new(0, 0.5, -0.82), Vector3.new(0.14, 0.3, 0.14), COLORS.FowlComb, EGG)
			eyes(model, root, 0.26, 0.85, -0.78, 0.13)
			-- 날개
			piece(model, root, CFrame.new(-0.6, 0.05, 0.05), Vector3.new(0.25, 0.75, 1.0), COLORS.FowlTail, EGG)
			piece(model, root, CFrame.new(0.6, 0.05, 0.05), Vector3.new(0.25, 0.75, 1.0), COLORS.FowlTail, EGG)
			-- 위로 치솟은 꼬리 깃털 세 개
			for i = -1, 1 do
				piece(model, root, CFrame.new(i * 0.15, 0.6, 0.75) * CFrame.Angles(-0.6, 0, i * 0.3), Vector3.new(0.15, 1.1, 0.4), COLORS.FowlTail, EGG)
			end
			-- 가느다란 다리
			piece(model, root, CFrame.new(-0.22, -0.85, 0) * UPRIGHT, Vector3.new(0.7, 0.12, 0.12), COLORS.Banana, CYL)
			piece(model, root, CFrame.new(0.22, -0.85, 0) * UPRIGHT, Vector3.new(0.7, 0.12, 0.12), COLORS.Banana, CYL)
		end,
	},
}

----------------------------------------------------------------
-- 위치 도우미
----------------------------------------------------------------

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- 지도 안, 캠프 밖으로 위치를 맞춰요 (지도 가운데 기준으로 계산하고 실제 위치로 돌려줘요)
local function clampToJungle(pos: Vector3): Vector3
	local center = MapBuilder.Info.Center
	local limit = Config.Map.HalfSize - H.MapEdgeMargin
	local p = Vector3.new(math.clamp(pos.X - center.X, -limit, limit), 0, math.clamp(pos.Z - center.Z, -limit, limit))
	local minDist = Config.Map.CampClearRadius
	if p.Magnitude < minDist then
		p = (p.Magnitude > 0 and p.Unit or Vector3.xAxis) * minDist
	end
	return p + center
end

local function randomSpawnPoint(): Vector3
	local center = MapBuilder.Info.Center
	local limit = Config.Map.HalfSize - H.MapEdgeMargin
	for _ = 1, Config.Map.PlaceTries do
		local p = Vector3.new(rng:NextNumber(-limit, limit), 0, rng:NextNumber(-limit, limit))
		if p.Magnitude >= H.MinSpawnDistance then
			return p + center
		end
	end
	return Vector3.new(H.MinSpawnDistance, 0, 0) + center
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
	base.CFrame = CFrame.new(Vector3.new(position.X, MapBuilder.Info.Center.Y + 0.8, position.Z))
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
		prey.Humanoid:MoveTo(clampToJungle(pos + away * H.FleeDistance))
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
