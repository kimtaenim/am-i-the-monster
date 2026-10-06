-- 정글에 사는 동물들(앵무새, 원숭이, 개구리, 부엉이, 박쥐, 반딧불…)을 만들어요.
-- 동물은 보기만 하는 장식이에요. 움직임은 각자의 화면(Wildlife.client)이 맡아요.
-- 그래서 서버는 동물을 "놓아두기"만 하고, 동물이 어디로 갈지는 신경 쓰지 않아요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config)

local W = Config.Wildlife
local COLORS = Config.Colors
local TAU = math.pi * 2
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local Wildlife = {}

local rng: Random

----------------------------------------------------------------
-- 도우미
----------------------------------------------------------------

-- 동물 모델의 뼈대 : 보이지 않는 Root 파츠가 기준점이에요
local function newAnimal(folder: Instance, kind: string, cf: CFrame): (Model, CFrame)
	local model = Instance.new("Model")
	model.Name = kind
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Kind", kind)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CFrame = cf
	root.Parent = model
	model.PrimaryPart = root

	model.Parent = folder
	return model, cf
end

-- 동물 몸 조각 하나. role은 화면에서 따로 움직일 부분(날개, 머리, 눈)이에요
local function piece(model: Model, cf: CFrame, offset: CFrame, size: Vector3, color: Color3, shape: Enum.PartType?, material: Enum.Material?, role: string?, side: number?)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CFrame = cf * offset
	if role then
		part:SetAttribute("Role", role)
	end
	if side then
		part:SetAttribute("Side", side)
	end
	part.Parent = model
	return part
end

local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder
local NEON = Enum.Material.Neon

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

----------------------------------------------------------------
-- 동물 모양 (모두 -Z 쪽을 바라봐요)
----------------------------------------------------------------

local function buildParrot(model, cf)
	local color = pick(COLORS.Parrots)
	piece(model, cf, CFrame.new(0, 0, 0), Vector3.one * 1.2, color, BALL)
	piece(model, cf, CFrame.new(0, 0.75, -0.35), Vector3.one * 0.8, color, BALL)
	piece(model, cf, CFrame.new(0, 0.65, -0.85), Vector3.new(0.25, 0.3, 0.35), COLORS.Beak)
	piece(model, cf, CFrame.new(0, -0.35, 0.8) * CFrame.Angles(0.5, 0, 0), Vector3.new(0.35, 0.12, 1.3), color)
	piece(model, cf, CFrame.new(-0.6, 0.1, 0.1), Vector3.new(0.12, 0.7, 1), COLORS.ParrotWing, nil, nil, "Wing", -1)
	piece(model, cf, CFrame.new(0.6, 0.1, 0.1), Vector3.new(0.12, 0.7, 1), COLORS.ParrotWing, nil, nil, "Wing", 1)
end

local function buildToucan(model, cf)
	piece(model, cf, CFrame.new(0, 0, 0), Vector3.one * 1.3, COLORS.ToucanBody, BALL)
	piece(model, cf, CFrame.new(0, 0.1, -0.45), Vector3.new(0.8, 0.8, 0.4), COLORS.ToucanChest)
	piece(model, cf, CFrame.new(0, 0.8, -0.3), Vector3.one * 0.8, COLORS.ToucanBody, BALL)
	piece(model, cf, CFrame.new(0, 0.75, -1.1), Vector3.new(0.35, 0.4, 1.2), COLORS.ToucanBeak)
	piece(model, cf, CFrame.new(-0.65, 0.1, 0.1), Vector3.new(0.12, 0.75, 1), COLORS.ToucanBody, nil, nil, "Wing", -1)
	piece(model, cf, CFrame.new(0.65, 0.1, 0.1), Vector3.new(0.12, 0.75, 1), COLORS.ToucanBody, nil, nil, "Wing", 1)
end

local function buildFlockBird(model, cf)
	piece(model, cf, CFrame.new(0, 0, 0), Vector3.new(0.5, 0.35, 1.1), COLORS.FlockBird)
	piece(model, cf, CFrame.new(-0.85, 0, 0), Vector3.new(1.3, 0.08, 0.6), COLORS.FlockBird, nil, nil, "Wing", -1)
	piece(model, cf, CFrame.new(0.85, 0, 0), Vector3.new(1.3, 0.08, 0.6), COLORS.FlockBird, nil, nil, "Wing", 1)
end

local function buildMonkey(model, cf)
	piece(model, cf, CFrame.new(0, 0, 0), Vector3.one * 1.8, COLORS.Monkey, BALL)
	piece(model, cf, CFrame.new(0, 1.4, 0.1), Vector3.one * 1.3, COLORS.Monkey, BALL)
	piece(model, cf, CFrame.new(0, 1.35, 0.55), Vector3.one * 0.8, COLORS.MonkeyFace, BALL)
	-- 나무를 껴안은 팔
	piece(model, cf, CFrame.new(-0.8, 0.6, -0.6) * CFrame.Angles(0.6, 0, 0), Vector3.new(0.4, 0.4, 1.3), COLORS.Monkey)
	piece(model, cf, CFrame.new(0.8, 0.6, -0.6) * CFrame.Angles(0.6, 0, 0), Vector3.new(0.4, 0.4, 1.3), COLORS.Monkey)
	-- 길게 늘어진 꼬리
	piece(model, cf, CFrame.new(0, -1.4, 0.7) * CFrame.Angles(0.3, 0, 0), Vector3.new(0.25, 2.2, 0.25), COLORS.Monkey)
end

local function buildFrog(model, cf)
	piece(model, cf, CFrame.new(0, 0.45, 0), Vector3.one * 1.1, COLORS.Frog, BALL)
	piece(model, cf, CFrame.new(-0.3, 0.95, -0.3), Vector3.one * 0.35, COLORS.FrogEye, BALL)
	piece(model, cf, CFrame.new(0.3, 0.95, -0.3), Vector3.one * 0.35, COLORS.FrogEye, BALL)
	piece(model, cf, CFrame.new(-0.55, 0.2, 0.35), Vector3.new(0.3, 0.3, 0.8), COLORS.Frog)
	piece(model, cf, CFrame.new(0.55, 0.2, 0.35), Vector3.new(0.3, 0.3, 0.8), COLORS.Frog)
end

local function buildLizard(model, cf)
	piece(model, cf, CFrame.new(0, 0.18, 0), Vector3.new(0.5, 0.3, 1.5), COLORS.Lizard)
	piece(model, cf, CFrame.new(0, 0.2, -0.95), Vector3.new(0.45, 0.25, 0.5), COLORS.Lizard)
	piece(model, cf, CFrame.new(0, 0.12, 1.5), Vector3.new(0.18, 0.12, 1.6), COLORS.Lizard)
	for _, x in { -0.35, 0.35 } do
		piece(model, cf, CFrame.new(x, 0.08, -0.4), Vector3.new(0.35, 0.12, 0.15), COLORS.Lizard)
		piece(model, cf, CFrame.new(x, 0.08, 0.45), Vector3.new(0.35, 0.12, 0.15), COLORS.Lizard)
	end
end

local function buildButterfly(model, cf)
	local color = pick(COLORS.Butterflies)
	piece(model, cf, CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(0.6, 0.12, 0.12), COLORS.Bat, CYL)
	piece(model, cf, CFrame.new(-0.4, 0, 0), Vector3.new(0.7, 0.04, 0.6), color, nil, nil, "Wing", -1)
	piece(model, cf, CFrame.new(0.4, 0, 0), Vector3.new(0.7, 0.04, 0.6), color, nil, nil, "Wing", 1)
end

local function buildOwl(model, cf)
	piece(model, cf, CFrame.new(0, 0, 0), Vector3.one * 1.6, COLORS.Owl, BALL)
	piece(model, cf, CFrame.new(0, 1.1, 0), Vector3.one * 1.2, COLORS.Owl, BALL, nil, "Head")
	piece(model, cf, CFrame.new(0, 1.1, -0.5), Vector3.new(0.95, 0.75, 0.2), COLORS.OwlFace, nil, nil, "Head")
	piece(model, cf, CFrame.new(-0.22, 1.18, -0.62), Vector3.one * 0.28, COLORS.OwlEye, BALL, NEON, "Head")
	piece(model, cf, CFrame.new(0.22, 1.18, -0.62), Vector3.one * 0.28, COLORS.OwlEye, BALL, NEON, "Head")
	piece(model, cf, CFrame.new(-0.35, 1.75, 0), Vector3.new(0.2, 0.4, 0.2), COLORS.Owl, nil, nil, "Head")
	piece(model, cf, CFrame.new(0.35, 1.75, 0), Vector3.new(0.2, 0.4, 0.2), COLORS.Owl, nil, nil, "Head")
end

local function buildBat(model, cf)
	piece(model, cf, CFrame.new(0, 0, 0), Vector3.one * 0.6, COLORS.Bat, BALL)
	piece(model, cf, CFrame.new(-0.8, 0, 0), Vector3.new(1.2, 0.06, 0.7), COLORS.Bat, nil, nil, "Wing", -1)
	piece(model, cf, CFrame.new(0.8, 0, 0), Vector3.new(1.2, 0.06, 0.7), COLORS.Bat, nil, nil, "Wing", 1)
end

local function buildEyes(model, cf)
	piece(model, cf, CFrame.new(-0.35, 0, 0), Vector3.one * 0.3, COLORS.GlowEye, BALL, NEON, "Eye")
	piece(model, cf, CFrame.new(0.35, 0, 0), Vector3.one * 0.3, COLORS.GlowEye, BALL, NEON, "Eye")
end

local function buildCroc(model, cf)
	-- 물 위로 코와 눈, 등만 살짝 나와 있어요
	piece(model, cf, CFrame.new(0, 0.05, -1.8), Vector3.new(1.2, 0.35, 2.4), COLORS.Croc)
	piece(model, cf, CFrame.new(-0.4, 0.3, -0.5), Vector3.one * 0.5, COLORS.Croc, BALL)
	piece(model, cf, CFrame.new(0.4, 0.3, -0.5), Vector3.one * 0.5, COLORS.Croc, BALL)
	piece(model, cf, CFrame.new(-0.4, 0.4, -0.7), Vector3.one * 0.18, COLORS.FrogEye, BALL, NEON)
	piece(model, cf, CFrame.new(0.4, 0.4, -0.7), Vector3.one * 0.18, COLORS.FrogEye, BALL, NEON)
	for i = 1, 4 do
		piece(model, cf, CFrame.new(0, 0.05, i * 0.9), Vector3.new(0.5, 0.3, 0.5), COLORS.Croc)
	end
end

----------------------------------------------------------------
-- 앉을 자리 찾기
----------------------------------------------------------------

-- 나무줄기에서 뻗은 가지를 하나 만들고, 가지 끝 자리를 돌려줘요 (밖을 바라봐요)
local function makeBranchPerch(tree): CFrame
	local angle = rng:NextNumber(0, TAU)
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local y = tree.Height * rng:NextNumber(0.45, 0.75)
	local start = tree.Pos + dir * tree.TrunkRadius + Vector3.new(0, y, 0)
	local finish = start + dir * W.BranchLength

	local branch = Instance.new("Part")
	branch.Name = "Branch"
	branch.Anchored = true
	branch.CanCollide = false
	branch.CanTouch = false
	branch.CanQuery = false
	branch.Size = Vector3.new(0.5, 0.5, W.BranchLength)
	branch.CFrame = CFrame.lookAt((start + finish) / 2, finish)
	branch.Color = COLORS.Trunk
	branch.Material = Enum.Material.Wood
	branch.Parent = tree.Model

	local perch = finish - dir * 0.6 + Vector3.new(0, 0.85, 0)
	return CFrame.lookAt(perch, perch + dir)
end

local function randomInMap(margin: number): Vector3
	local limit = Config.Map.HalfSize - margin
	return Vector3.new(rng:NextNumber(-limit, limit), 0, rng:NextNumber(-limit, limit))
end

----------------------------------------------------------------
-- 동물 놓기
----------------------------------------------------------------

local function placePerchedBirds(folder, trees, kind, count, builder)
	for _ = 1, count do
		local model, cf = newAnimal(folder, kind, makeBranchPerch(pick(trees)))
		model:SetAttribute("Phase", rng:NextNumber(0, TAU))
		builder(model, cf)
	end
end

local function placeMonkeys(folder, trees)
	for _ = 1, W.Monkeys do
		local tree = pick(trees)
		local angle = rng:NextNumber(0, TAU)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local bottom = tree.Height * 0.2
		local top = tree.Height * 0.8
		local pos = tree.Pos + dir * (tree.TrunkRadius + 0.9) + Vector3.new(0, (bottom + top) / 2, 0)
		-- 나무를 껴안도록 줄기를 바라봐요
		local model, cf = newAnimal(folder, "Monkey", CFrame.lookAt(pos, pos - dir))
		model:SetAttribute("Bottom", bottom)
		model:SetAttribute("Top", top)
		model:SetAttribute("Phase", rng:NextNumber(0, TAU))
		buildMonkey(model, cf)
	end
end

local function placeCircling(folder, kind, center: Vector3, radius: number, height: number, builder)
	local phase = rng:NextNumber(0, TAU)
	local pos = center + Vector3.new(math.cos(phase) * radius, height, math.sin(phase) * radius)
	local model, cf = newAnimal(folder, kind, CFrame.new(pos))
	model:SetAttribute("CenterX", center.X)
	model:SetAttribute("CenterZ", center.Z)
	model:SetAttribute("Radius", radius)
	model:SetAttribute("Height", height)
	model:SetAttribute("Phase", phase)
	builder(model, cf)
end

local function placeFlocks(folder)
	for _ = 1, W.BirdFlocks do
		local center = randomInMap(W.FlockRadiusMax)
		local radius = rng:NextNumber(W.FlockRadiusMin, W.FlockRadiusMax)
		for _ = 1, W.BirdsPerFlock do
			placeCircling(folder, "FlockBird", center, radius + rng:NextNumber(-6, 6), W.FlockHeight + rng:NextNumber(-4, 4), buildFlockBird)
		end
	end
end

local function placeBats(folder)
	for _ = 1, W.Bats do
		-- 박쥐는 캠프 둘레 정글 위를 맴돌아요
		local angle = rng:NextNumber(0, TAU)
		local dist = rng:NextNumber(Config.Map.CampClearRadius, Config.Map.RuinMaxRadius)
		local center = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		placeCircling(folder, "Bat", center, W.BatRadius * rng:NextNumber(0.6, 1.3), W.BatHeight + rng:NextNumber(-6, 6), buildBat)
	end
end

local function placeSwampAnimals(folder, swamps)
	for _, swamp in swamps do
		for _ = 1, W.FrogsPerSwamp do
			local angle = rng:NextNumber(0, TAU)
			local r = swamp.Size / 2 + 0.8
			local pos = swamp.Pos + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
			local model, cf = newAnimal(folder, "Frog", CFrame.lookAt(pos, swamp.Pos))
			buildFrog(model, cf)
		end
		if swamp.Size >= W.CrocMinSwampSize then
			local model, cf = newAnimal(folder, "Croc", CFrame.new(swamp.Pos + Vector3.new(0, 0.1, 0)))
			model:SetAttribute("CenterX", swamp.Pos.X)
			model:SetAttribute("CenterZ", swamp.Pos.Z)
			model:SetAttribute("Radius", swamp.Size * 0.25)
			model:SetAttribute("Phase", rng:NextNumber(0, TAU))
			buildCroc(model, cf)
		end
	end
end

local function placeLizards(folder, ruins)
	for _ = 1, W.Lizards do
		local ruin = pick(ruins)
		local angle = rng:NextNumber(0, TAU)
		local pos = ruin.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(4, W.LizardRange)
		local model, cf = newAnimal(folder, "Lizard", CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0))
		buildLizard(model, cf)
	end
end

local function placeButterflies(folder, bushes)
	for _ = 1, W.Butterflies do
		local bush = pick(bushes)
		local pos = bush.Pos + Vector3.new(0, rng:NextNumber(2, 4), 0)
		local model, cf = newAnimal(folder, "Butterfly", CFrame.new(pos))
		model:SetAttribute("Phase", rng:NextNumber(0, TAU))
		buildButterfly(model, cf)
	end
end

local function placeEyes(folder, bushes)
	-- 캠프에서 먼 덤불만 골라요
	local far = {}
	for _, bush in bushes do
		if bush.Pos.Magnitude > Config.Map.CampClearRadius + W.EyeHideDistance then
			table.insert(far, bush)
		end
	end
	if #far == 0 then
		return
	end
	for _ = 1, W.EyePairs do
		local bush = pick(far)
		local toCamp = -bush.Pos.Unit
		local pos = bush.Pos + toCamp * (bush.Size * 0.45) + Vector3.new(0, bush.Size * 0.25, 0)
		local model, cf = newAnimal(folder, "Eyes", CFrame.lookAt(pos, pos + toCamp))
		buildEyes(model, cf)
	end
end

local function placeFireflies(folder, bushes, swamps)
	local spots = {}
	for _, swamp in swamps do
		table.insert(spots, swamp.Pos)
	end
	while #spots < W.FireflyClusters and #bushes > 0 do
		table.insert(spots, pick(bushes).Pos)
	end
	for i = 1, math.min(#spots, W.FireflyClusters) do
		local part = Instance.new("Part")
		part.Name = "Fireflies"
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Transparency = 1
		part.Size = Vector3.new(14, 4, 14)
		part.CFrame = CFrame.new(spots[i] + Vector3.new(0, 2.5, 0))
		part:SetAttribute("Kind", "Fireflies")

		local emitter = Instance.new("ParticleEmitter")
		emitter.Enabled = false -- 밤이 되면 화면에서 켜요
		emitter.Texture = SPARKLE_TEXTURE
		emitter.Rate = W.FireflyRate
		emitter.Lifetime = NumberRange.new(3, 5)
		emitter.Size = NumberSequence.new(0.25)
		emitter.Color = ColorSequence.new(COLORS.Firefly)
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Speed = NumberRange.new(0.3, 0.8)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(0.7, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		emitter.Parent = part
		part.Parent = folder
	end
end

----------------------------------------------------------------
-- 전부 놓기
----------------------------------------------------------------

function Wildlife.Build(mapInfo)
	rng = Random.new(Config.Map.Seed + 1)
	local folder = Instance.new("Folder")
	folder.Name = "Wildlife"
	folder.Parent = mapInfo.Root

	local trees = mapInfo.Trees
	if #trees > 0 then
		placePerchedBirds(folder, trees, "Parrot", W.Parrots, buildParrot)
		placePerchedBirds(folder, trees, "Toucan", W.Toucans, buildToucan)
		placePerchedBirds(folder, trees, "Owl", W.Owls, buildOwl)
		placeMonkeys(folder, trees)
	end
	placeFlocks(folder)
	placeBats(folder)
	placeSwampAnimals(folder, mapInfo.Swamps)
	if #mapInfo.Ruins > 0 then
		placeLizards(folder, mapInfo.Ruins)
	end
	if #mapInfo.Bushes > 0 then
		placeButterflies(folder, mapInfo.Bushes)
		placeEyes(folder, mapInfo.Bushes)
	end
	placeFireflies(folder, mapInfo.Bushes, mapInfo.Swamps)

	print(string.format("[Wildlife] 정글 동물 %d마리가 자리를 잡았어요", #folder:GetChildren()))
end

return Wildlife
