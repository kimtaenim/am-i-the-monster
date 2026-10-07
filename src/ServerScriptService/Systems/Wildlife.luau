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
-- shape가 "Egg"면 크기에 맞춰 늘어난 둥근 공 모양이 돼요
local function piece(model: Model, cf: CFrame, offset: CFrame, size: Vector3, color: Color3, shape: any?, material: Enum.Material?, role: string?, side: number?)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "Egg" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	elseif shape then
		part.Shape = shape
	end
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
local NEON = Enum.Material.Neon

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

----------------------------------------------------------------
-- 동물 모양 (모두 -Z 쪽을 바라봐요)
----------------------------------------------------------------

local EGG = "Egg" -- 크기에 맞춰 늘어난 둥근 모양 (타원)

-- 반짝이는 동그란 눈 한 쌍. facing : -1이면 -Z쪽, 1이면 +Z쪽을 봐요
local function eyes(model, cf, x: number, y: number, z: number, size: number, facing: number, role: string?)
	for _, side in { -1, 1 } do
		piece(model, cf, CFrame.new(side * x, y, z), Vector3.one * size, COLORS.EyeBlack, BALL, nil, role)
		piece(model, cf, CFrame.new(side * x + side * size * 0.12, y + size * 0.2, z + facing * size * 0.38), Vector3.one * size * 0.35, COLORS.EyeShine, BALL, nil, role)
	end
end

local function buildParrot(model, cf)
	local color = pick(COLORS.Parrots)
	-- 통통한 몸과 동그란 머리
	piece(model, cf, CFrame.new(0, 0, 0) * CFrame.Angles(-0.35, 0, 0), Vector3.new(1.1, 1.5, 1.1), color, EGG)
	piece(model, cf, CFrame.new(0, 0.85, -0.25), Vector3.one * 0.85, color, BALL)
	-- 갈고리 부리
	piece(model, cf, CFrame.new(0, 0.75, -0.72) * CFrame.Angles(0.5, 0, 0), Vector3.new(0.28, 0.4, 0.3), COLORS.Beak, EGG)
	eyes(model, cf, 0.28, 0.95, -0.55, 0.16, -1)
	-- 길게 뻗은 꼬리 깃털
	piece(model, cf, CFrame.new(0, -0.6, 0.7) * CFrame.Angles(0.6, 0, 0), Vector3.new(0.35, 0.12, 1.5), COLORS.ParrotWing, EGG)
	piece(model, cf, CFrame.new(-0.55, 0.05, 0.1), Vector3.new(0.18, 0.9, 1.1), COLORS.ParrotWing, EGG, nil, "Wing", -1)
	piece(model, cf, CFrame.new(0.55, 0.05, 0.1), Vector3.new(0.18, 0.9, 1.1), COLORS.ParrotWing, EGG, nil, "Wing", 1)
end

local function buildToucan(model, cf)
	piece(model, cf, CFrame.new(0, 0, 0) * CFrame.Angles(-0.3, 0, 0), Vector3.new(1.2, 1.6, 1.2), COLORS.ToucanBody, EGG)
	piece(model, cf, CFrame.new(0, 0.3, -0.42), Vector3.new(0.8, 0.8, 0.4), COLORS.ToucanChest, EGG)
	piece(model, cf, CFrame.new(0, 0.95, -0.25), Vector3.one * 0.85, COLORS.ToucanBody, BALL)
	-- 크고 알록달록한 부리
	piece(model, cf, CFrame.new(0, 0.88, -1.05) * CFrame.Angles(0.15, 0, 0), Vector3.new(0.38, 0.45, 1.3), COLORS.ToucanBeak, EGG)
	piece(model, cf, CFrame.new(0, 0.82, -1.62), Vector3.new(0.2, 0.25, 0.25), COLORS.EyeBlack, EGG)
	eyes(model, cf, 0.3, 1.05, -0.55, 0.16, -1)
	piece(model, cf, CFrame.new(-0.6, 0.05, 0.1), Vector3.new(0.18, 0.9, 1.1), COLORS.ToucanBody, EGG, nil, "Wing", -1)
	piece(model, cf, CFrame.new(0.6, 0.05, 0.1), Vector3.new(0.18, 0.9, 1.1), COLORS.ToucanBody, EGG, nil, "Wing", 1)
end

local function buildFlockBird(model, cf)
	piece(model, cf, CFrame.new(0, 0, 0), Vector3.new(0.5, 0.4, 1.2), COLORS.FlockBird, EGG)
	piece(model, cf, CFrame.new(-0.85, 0, 0), Vector3.new(1.4, 0.1, 0.6), COLORS.FlockBird, EGG, nil, "Wing", -1)
	piece(model, cf, CFrame.new(0.85, 0, 0), Vector3.new(1.4, 0.1, 0.6), COLORS.FlockBird, EGG, nil, "Wing", 1)
end

local function buildMonkey(model, cf)
	-- 나무줄기(-Z)를 껴안고, 얼굴은 바깥(+Z)을 봐요
	piece(model, cf, CFrame.new(0, 0, 0), Vector3.new(1.6, 2, 1.5), COLORS.Monkey, EGG)
	piece(model, cf, CFrame.new(0, 0, 0.35), Vector3.new(1.0, 1.3, 0.9), COLORS.MonkeyFace, EGG)
	piece(model, cf, CFrame.new(0, 1.45, 0.1), Vector3.one * 1.3, COLORS.Monkey, BALL)
	piece(model, cf, CFrame.new(0, 1.35, 0.55), Vector3.new(0.95, 0.8, 0.5), COLORS.MonkeyFace, EGG)
	eyes(model, cf, 0.22, 1.55, 0.72, 0.18, 1)
	-- 동그란 귀
	piece(model, cf, CFrame.new(-0.7, 1.55, 0.1), Vector3.new(0.2, 0.45, 0.45), COLORS.MonkeyFace, EGG)
	piece(model, cf, CFrame.new(0.7, 1.55, 0.1), Vector3.new(0.2, 0.45, 0.45), COLORS.MonkeyFace, EGG)
	-- 나무를 껴안은 긴 팔과 다리
	for _, side in { -1, 1 } do
		piece(model, cf, CFrame.new(side * 0.75, 0.7, -0.55) * CFrame.Angles(0.9, 0, 0), Vector3.new(0.38, 1.4, 0.38), COLORS.Monkey, EGG)
		piece(model, cf, CFrame.new(side * 0.6, -0.8, -0.45) * CFrame.Angles(0.7, 0, 0), Vector3.new(0.42, 1.2, 0.42), COLORS.Monkey, EGG)
	end
	-- 동그랗게 말린 꼬리
	piece(model, cf, CFrame.new(0, -1.3, 0.6) * CFrame.Angles(0.4, 0, 0), Vector3.new(0.22, 1.6, 0.22), COLORS.Monkey, EGG)
	piece(model, cf, CFrame.new(0, -2.05, 0.95), Vector3.new(0.22, 0.6, 0.6), COLORS.Monkey, EGG)
end

local function buildFrog(model, cf)
	-- 납작하고 동그란 몸과 툭 튀어나온 눈
	piece(model, cf, CFrame.new(0, 0.4, 0), Vector3.new(1.3, 0.8, 1.4), COLORS.Frog, EGG)
	piece(model, cf, CFrame.new(0, 0.3, -0.35), Vector3.new(0.9, 0.45, 0.6), COLORS.FrogBelly, EGG)
	for _, side in { -1, 1 } do
		piece(model, cf, CFrame.new(side * 0.32, 0.85, -0.35), Vector3.one * 0.38, COLORS.Frog, BALL)
	end
	eyes(model, cf, 0.32, 0.9, -0.48, 0.22, -1)
	-- 접은 뒷다리와 앞다리
	piece(model, cf, CFrame.new(-0.6, 0.2, 0.35), Vector3.new(0.4, 0.35, 0.9), COLORS.Frog, EGG)
	piece(model, cf, CFrame.new(0.6, 0.2, 0.35), Vector3.new(0.4, 0.35, 0.9), COLORS.Frog, EGG)
	piece(model, cf, CFrame.new(-0.4, 0.12, -0.55), Vector3.new(0.2, 0.2, 0.45), COLORS.Frog, EGG)
	piece(model, cf, CFrame.new(0.4, 0.12, -0.55), Vector3.new(0.2, 0.2, 0.45), COLORS.Frog, EGG)
end

local function buildLizard(model, cf)
	piece(model, cf, CFrame.new(0, 0.2, 0), Vector3.new(0.55, 0.35, 1.5), COLORS.Lizard, EGG)
	piece(model, cf, CFrame.new(0, 0.24, -0.95), Vector3.new(0.45, 0.3, 0.6), COLORS.Lizard, EGG)
	eyes(model, cf, 0.17, 0.33, -1.05, 0.1, -1)
	-- 점점 가늘어지는 꼬리
	piece(model, cf, CFrame.new(0, 0.15, 1.15), Vector3.new(0.3, 0.2, 1.0), COLORS.Lizard, EGG)
	piece(model, cf, CFrame.new(0.1, 0.1, 1.9) * CFrame.Angles(0, 0.3, 0), Vector3.new(0.16, 0.12, 0.9), COLORS.Lizard, EGG)
	for _, x in { -0.35, 0.35 } do
		piece(model, cf, CFrame.new(x, 0.08, -0.4), Vector3.new(0.35, 0.12, 0.16), COLORS.Lizard, EGG)
		piece(model, cf, CFrame.new(x, 0.08, 0.45), Vector3.new(0.35, 0.12, 0.16), COLORS.Lizard, EGG)
	end
end

local function buildButterfly(model, cf)
	local color = pick(COLORS.Butterflies)
	piece(model, cf, CFrame.new(0, 0, 0), Vector3.new(0.12, 0.12, 0.6), COLORS.Bat, EGG)
	-- 앞날개(크게)와 뒷날개(작게)
	piece(model, cf, CFrame.new(-0.4, 0, -0.12), Vector3.new(0.75, 0.04, 0.6), color, EGG, nil, "Wing", -1)
	piece(model, cf, CFrame.new(0.4, 0, -0.12), Vector3.new(0.75, 0.04, 0.6), color, EGG, nil, "Wing", 1)
	piece(model, cf, CFrame.new(-0.3, 0, 0.25), Vector3.new(0.5, 0.04, 0.45), color, EGG, nil, "Wing", -1)
	piece(model, cf, CFrame.new(0.3, 0, 0.25), Vector3.new(0.5, 0.04, 0.45), color, EGG, nil, "Wing", 1)
end

local function buildOwl(model, cf)
	piece(model, cf, CFrame.new(0, 0, 0), Vector3.new(1.5, 1.9, 1.4), COLORS.Owl, EGG)
	piece(model, cf, CFrame.new(0, -0.1, -0.45), Vector3.new(1.0, 1.3, 0.6), COLORS.OwlFace, EGG)
	piece(model, cf, CFrame.new(0, 1.2, 0), Vector3.new(1.35, 1.15, 1.25), COLORS.Owl, EGG, nil, "Head")
	-- 하트 모양 얼굴판과 큰 눈
	piece(model, cf, CFrame.new(0, 1.15, -0.45), Vector3.new(1.05, 0.85, 0.35), COLORS.OwlFace, EGG, nil, "Head")
	piece(model, cf, CFrame.new(-0.24, 1.22, -0.62), Vector3.one * 0.32, COLORS.OwlEye, BALL, NEON, "Head")
	piece(model, cf, CFrame.new(0.24, 1.22, -0.62), Vector3.one * 0.32, COLORS.OwlEye, BALL, NEON, "Head")
	piece(model, cf, CFrame.new(-0.24, 1.22, -0.76), Vector3.one * 0.14, COLORS.EyeBlack, BALL, nil, "Head")
	piece(model, cf, CFrame.new(0.24, 1.22, -0.76), Vector3.one * 0.14, COLORS.EyeBlack, BALL, nil, "Head")
	piece(model, cf, CFrame.new(0, 1.0, -0.68), Vector3.new(0.14, 0.22, 0.14), COLORS.Beak, EGG, nil, "Head")
	-- 뾰족한 귀깃
	piece(model, cf, CFrame.new(-0.42, 1.8, 0) * CFrame.Angles(0, 0, 0.35), Vector3.new(0.22, 0.5, 0.22), COLORS.Owl, EGG, nil, "Head")
	piece(model, cf, CFrame.new(0.42, 1.8, 0) * CFrame.Angles(0, 0, -0.35), Vector3.new(0.22, 0.5, 0.22), COLORS.Owl, EGG, nil, "Head")
end

local function buildBat(model, cf)
	piece(model, cf, CFrame.new(0, 0, 0), Vector3.new(0.5, 0.5, 0.7), COLORS.Bat, EGG)
	piece(model, cf, CFrame.new(-0.15, 0.3, -0.15), Vector3.new(0.12, 0.25, 0.12), COLORS.Bat, EGG)
	piece(model, cf, CFrame.new(0.15, 0.3, -0.15), Vector3.new(0.12, 0.25, 0.12), COLORS.Bat, EGG)
	piece(model, cf, CFrame.new(-0.8, 0, 0), Vector3.new(1.3, 0.06, 0.75), COLORS.Bat, EGG, nil, "Wing", -1)
	piece(model, cf, CFrame.new(0.8, 0, 0), Vector3.new(1.3, 0.06, 0.75), COLORS.Bat, EGG, nil, "Wing", 1)
end

local function buildEyes(model, cf)
	piece(model, cf, CFrame.new(-0.35, 0, 0), Vector3.one * 0.3, COLORS.GlowEye, BALL, NEON, "Eye")
	piece(model, cf, CFrame.new(0.35, 0, 0), Vector3.one * 0.3, COLORS.GlowEye, BALL, NEON, "Eye")
end

local function buildCroc(model, cf)
	-- 물 위로 둥근 코와 눈, 울퉁불퉁한 등만 살짝 나와 있어요
	piece(model, cf, CFrame.new(0, 0.05, -1.8), Vector3.new(1.2, 0.4, 2.6), COLORS.Croc, EGG)
	piece(model, cf, CFrame.new(-0.25, 0.22, -3.0), Vector3.one * 0.22, COLORS.Croc, BALL)
	piece(model, cf, CFrame.new(0.25, 0.22, -3.0), Vector3.one * 0.22, COLORS.Croc, BALL)
	piece(model, cf, CFrame.new(-0.4, 0.3, -0.5), Vector3.one * 0.55, COLORS.Croc, BALL)
	piece(model, cf, CFrame.new(0.4, 0.3, -0.5), Vector3.one * 0.55, COLORS.Croc, BALL)
	piece(model, cf, CFrame.new(-0.4, 0.42, -0.72), Vector3.one * 0.2, COLORS.FrogEye, BALL, NEON)
	piece(model, cf, CFrame.new(0.4, 0.42, -0.72), Vector3.one * 0.2, COLORS.FrogEye, BALL, NEON)
	for i = 1, 4 do
		piece(model, cf, CFrame.new(0, 0.08, i * 0.9), Vector3.new(0.55 - i * 0.06, 0.35, 0.6), COLORS.Croc, EGG)
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
			model:SetAttribute("Height", 0.1)
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
