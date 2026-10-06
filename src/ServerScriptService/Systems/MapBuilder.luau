-- 게임이 시작될 때 정글 지도를 만들어요. (모닥불, 텐트, 유적 8곳, 나무, 식량, 늪, 덩굴)
-- 만든 것은 전부 Workspace/Generated 폴더에 들어가요.
-- Workspace/HandMade 폴더(손으로 꾸민 것)는 절대 건드리지 않아요.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config)

local MAP = Config.Map
local COLORS = Config.Colors
local TAU = math.pi * 2
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- 원기둥을 세우는 회전

local MapBuilder = {}
MapBuilder.Info = nil -- 다 만들면 여기에 위치 정보가 들어가요

local rng: Random
local occupied = {} -- 이미 무언가 놓인 자리들 { Pos, Radius }

----------------------------------------------------------------
-- 작은 도우미 함수들
----------------------------------------------------------------

-- 파츠 하나를 만들어요. props에 원하는 속성을 넣어요.
local function makePart(props): BasePart
	local className = props.ClassName or "Part"
	local part = Instance.new(className)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" and key ~= "ClassName" then
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- 장식용 파츠 : 부딪히지 않고 그림자도 없어서 가벼워요
local function makeDecor(props): BasePart
	props.CanCollide = false
	props.CanTouch = false
	props.CanQuery = false
	if props.CastShadow == nil then
		props.CastShadow = false
	end
	return makePart(props)
end

local function makeFolder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function makeModel(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- 머리 위 이름표를 붙여요
local function makeLabel(adornee: BasePart, text: string, height: number, maxDistance: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(8, 2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 80
	gui.Adornee = adornee
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = COLORS.Label
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	return label
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- 이 자리에 다른 것과 겹치지 않고 놓을 수 있나?
local function isFree(pos: Vector3, radius: number): boolean
	for _, spot in occupied do
		if (spot.Pos - pos).Magnitude < spot.Radius + radius then
			return false
		end
	end
	return true
end

local function reserve(pos: Vector3, radius: number)
	table.insert(occupied, { Pos = flat(pos), Radius = radius })
end

-- 지도 안에서 빈자리를 찾아요 (못 찾으면 nil)
local function findFreeSpot(radius: number, margin: number): Vector3?
	local limit = MAP.HalfSize - margin
	for _ = 1, MAP.PlaceTries do
		local pos = Vector3.new(rng:NextNumber(-limit, limit), 0, rng:NextNumber(-limit, limit))
		if isFree(pos, radius) then
			return pos
		end
	end
	return nil
end

-- 기준 위치(cf)에서 offset만큼 떨어진 곳에 블록을 놓아요
local function addBlock(model: Instance, cf: CFrame, offset: CFrame, size: Vector3, color: Color3, material: Enum.Material?)
	return makePart({
		Parent = model,
		Size = size,
		CFrame = cf * offset,
		Color = color,
		Material = material or Enum.Material.Slate,
	})
end

-- 세워진 원기둥 (바닥에서 height만큼)
local function addPillar(model: Instance, cf: CFrame, offset: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?)
	return makePart({
		Parent = model,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cf * CFrame.new(offset + Vector3.new(0, height / 2, 0)) * UPRIGHT,
		Color = color,
		Material = material or Enum.Material.Slate,
	})
end

-- 이끼 모자 (돌 위에 얹는 초록 판)
local function addMoss(model: Instance, onTop: BasePart)
	local size = onTop.Size
	makeDecor({
		Parent = model,
		Size = Vector3.new(size.X * 0.8, 0.3, size.Z * 0.8),
		CFrame = onTop.CFrame * CFrame.new(0, size.Y / 2 + 0.1, 0),
		Color = COLORS.Moss,
		Material = Enum.Material.Grass,
	})
end

----------------------------------------------------------------
-- 바닥, 벽, 출발 지점
----------------------------------------------------------------

local function buildGround(root: Folder)
	local size = MAP.HalfSize * 2 + MAP.BoundaryInset * 4
	makePart({
		Name = "Ground",
		Parent = root,
		Size = Vector3.new(size, MAP.GroundThickness, size),
		CFrame = CFrame.new(0, -MAP.GroundThickness / 2, 0),
		Color = COLORS.Ground,
		Material = Enum.Material.Grass,
	})

	-- 지도 밖으로 못 나가게 보이지 않는 벽 4개
	local walls = makeFolder("Walls", root)
	local half = MAP.HalfSize
	local length = half * 2
	local h = MAP.WallHeight
	local wallSpecs = {
		{ Vector3.new(0, h / 2, half), Vector3.new(length, h, 1) },
		{ Vector3.new(0, h / 2, -half), Vector3.new(length, h, 1) },
		{ Vector3.new(half, h / 2, 0), Vector3.new(1, h, length) },
		{ Vector3.new(-half, h / 2, 0), Vector3.new(1, h, length) },
	}
	for _, spec in wallSpecs do
		makePart({
			Name = "Wall",
			Parent = walls,
			Size = spec[2],
			CFrame = CFrame.new(spec[1]),
			Transparency = 1,
			CanTouch = false,
		})
	end
end

local function buildSpawn(root: Folder): SpawnLocation
	local spawn = makePart({
		ClassName = "SpawnLocation",
		Name = "CampSpawn",
		Parent = root,
		Size = Vector3.new(6, 1, 6),
		CFrame = CFrame.new(MAP.SpawnOffset),
		Transparency = 1,
		CanCollide = false,
		Neutral = true,
		Duration = 0, -- 보호막 없음
	}) :: SpawnLocation
	return spawn
end

----------------------------------------------------------------
-- 캠프 : 모닥불, 앉는 통나무, 장작 더미, 식량 창고
----------------------------------------------------------------

local function buildLogPile(model: Model, center: Vector3)
	-- 통나무를 피라미드 모양으로 쌓아요
	local rows = { 3, 2, 1 }
	local d = MAP.FireLogDiameter * 1.4
	for rowIndex, count in rows do
		for i = 1, count do
			local x = (i - (count + 1) / 2) * d
			local y = d / 2 + (rowIndex - 1) * d * 0.85
			makePart({
				Parent = model,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(MAP.FireLogLength, d, d),
				CFrame = CFrame.new(center + Vector3.new(0, y, x)),
				Color = COLORS.Log,
				Material = Enum.Material.Wood,
			})
		end
	end
end

local function buildCamp(root: Folder)
	local camp = makeFolder("Camp", root)
	local info = {}

	-- 모닥불 돌 고리
	local fire = makeModel("Campfire", camp)
	for i = 1, MAP.FireStoneCount do
		local angle = i / MAP.FireStoneCount * TAU
		local pos = Vector3.new(math.cos(angle), 0, math.sin(angle)) * MAP.FireStoneRingRadius
		makePart({
			Parent = fire,
			Size = MAP.FireStoneSize,
			CFrame = CFrame.new(pos + Vector3.new(0, MAP.FireStoneSize.Y / 2, 0)) * CFrame.Angles(0, angle, 0),
			Color = COLORS.DarkStone,
			Material = Enum.Material.Slate,
		})
	end

	-- 엇갈린 장작 두 개
	for i = 0, 1 do
		makePart({
			Parent = fire,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(MAP.FireLogLength, MAP.FireLogDiameter, MAP.FireLogDiameter),
			CFrame = CFrame.new(0, MAP.FireLogDiameter / 2, 0) * CFrame.Angles(0, i * math.pi / 2, 0),
			Color = COLORS.Log,
			Material = Enum.Material.Wood,
		})
	end

	-- 불꽃 : 빛과 불 효과가 여기 붙어요
	local flame = makeDecor({
		Name = "Flame",
		Parent = fire,
		Size = MAP.FireFlameSize,
		CFrame = CFrame.new(0, MAP.FireFlameSize.Y / 2, 0),
		Transparency = 1,
	})
	local fireEffect = Instance.new("Fire")
	fireEffect.Heat = MAP.FireHeat
	fireEffect.Size = MAP.FireSize
	fireEffect.Color = COLORS.Flame
	fireEffect.SecondaryColor = COLORS.FireLight
	fireEffect.Parent = flame

	local light = Instance.new("PointLight")
	light.Name = "FireLight"
	light.Color = COLORS.FireLight
	light.Range = math.min(MAP.HalfSize, Config.Fire.BaseLightRadius + Config.Fire.RadiusPerWood * Config.Fire.StartWood)
	light.Brightness = 2
	light.Shadows = true
	light.Parent = flame

	fire.PrimaryPart = flame
	info.FirePosition = Vector3.zero
	info.FireFlame = flame
	info.FireLight = light
	info.FireEffect = fireEffect

	-- 둘러앉는 통나무
	for i = 1, MAP.SeatLogCount do
		local angle = (i + 0.5) / MAP.SeatLogCount * TAU
		local pos = Vector3.new(math.cos(angle), 0, math.sin(angle)) * MAP.SeatLogRadius
		makePart({
			Name = "SeatLog",
			Parent = camp,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(MAP.SeatLogLength, MAP.SeatLogDiameter, MAP.SeatLogDiameter),
			CFrame = CFrame.lookAt(pos, Vector3.zero) * CFrame.new(0, MAP.SeatLogDiameter / 2, 0),
			Color = COLORS.Log,
			Material = Enum.Material.Wood,
		})
	end

	-- 장작 더미
	local woodPile = makeModel("WoodPile", camp)
	buildLogPile(woodPile, MAP.WoodPilePosition)
	local woodAnchor = makeDecor({
		Name = "Anchor",
		Parent = woodPile,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(MAP.WoodPilePosition),
		Transparency = 1,
	})
	woodPile.PrimaryPart = woodAnchor
	info.WoodPile = woodPile
	info.WoodLabel = makeLabel(woodAnchor, "🪵 장작", MAP.StoreLabelHeight)

	-- 식량 창고 (나무 상자 + 바구니)
	local foodStore = makeModel("FoodStore", camp)
	local crate = makePart({
		Name = "Crate",
		Parent = foodStore,
		Size = Vector3.new(5, 3, 4),
		CFrame = CFrame.new(MAP.FoodStorePosition + Vector3.new(0, 1.5, 0)),
		Color = COLORS.Log,
		Material = Enum.Material.WoodPlanks,
	})
	makePart({
		Parent = foodStore,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 3, 3),
		CFrame = CFrame.new(MAP.FoodStorePosition + Vector3.new(3.8, 0.8, 0)) * UPRIGHT,
		Color = COLORS.Reed,
		Material = Enum.Material.Fabric,
	})
	foodStore.PrimaryPart = crate
	info.FoodStore = foodStore
	info.FoodLabel = makeLabel(crate, "🍌 식량", MAP.StoreLabelHeight - 1.5)

	reserve(Vector3.zero, MAP.CampClearRadius)
	return info
end

----------------------------------------------------------------
-- 텐트 : 하나에 한 명만 숨을 수 있어요
----------------------------------------------------------------

local function buildTents(root: Folder)
	local folder = makeFolder("Tents", root)
	local tents = {}
	local size = MAP.TentSize
	local w, h, l = size.X, size.Y, size.Z

	for i = 1, MAP.TentCount do
		local angle = (i - 1) / MAP.TentCount * TAU + math.pi / MAP.TentCount
		local pos = Vector3.new(math.cos(angle), 0, math.sin(angle)) * MAP.TentRingRadius
		-- 텐트 입구가 모닥불을 보게 해요
		local cf = CFrame.lookAt(pos, Vector3.zero)
		local model = makeModel("Tent" .. i, folder)

		-- 쐐기 두 개를 맞대서 세모 지붕을 만들어요
		for side = -1, 1, 2 do
			makePart({
				ClassName = "WedgePart",
				Parent = model,
				Size = Vector3.new(l, h, w / 2),
				CFrame = cf * CFrame.new(side * w / 4, h / 2, 0) * CFrame.Angles(0, -side * math.pi / 2, 0),
				Color = COLORS.Tent,
				Material = Enum.Material.Fabric,
			})
		end

		-- 바닥 깔개
		makeDecor({
			Parent = model,
			Size = Vector3.new(w - 1, 0.2, l),
			CFrame = cf * CFrame.new(0, 0.1, 0),
			Color = COLORS.Dirt,
			Material = Enum.Material.Fabric,
		})

		-- 텐트 안 공간 (보이지 않아요. 안에 있으면 안전)
		local zone = makePart({
			Name = "TentZone",
			Parent = model,
			Size = Vector3.new(w - 2, h - 1, l - 1),
			CFrame = cf * CFrame.new(0, (h - 1) / 2, 0),
			Transparency = 1,
			CanCollide = false,
			CanTouch = false,
		})
		zone:SetAttribute("TentIndex", i)

		table.insert(tents, { Index = i, Model = model, Zone = zone, Position = pos })
	end
	return tents
end

----------------------------------------------------------------
-- 유적 터 8곳 (모양이 다 달라요)
----------------------------------------------------------------

local STONE = COLORS.Stone
local DARK = COLORS.DarkStone

local RUIN_BUILDERS = {
	{
		Name = "무너진 기둥",
		Build = function(model, cf)
			local spots = { Vector3.new(-6, 0, 2), Vector3.new(-2, 0, 5), Vector3.new(2.5, 0, 5), Vector3.new(6.5, 0, 2) }
			for _, offset in spots do
				local pillar = addPillar(model, cf, offset, rng:NextNumber(4, 13), 3, STONE)
				if rng:NextNumber() < 0.5 then
					addMoss(model, pillar)
				end
			end
			-- 쓰러진 기둥 하나
			makePart({
				Parent = model,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(10, 3, 3),
				CFrame = cf * CFrame.new(-3, 1.4, -2) * CFrame.Angles(0, 0.4, 0),
				Color = DARK,
				Material = Enum.Material.Slate,
			})
		end,
	},
	{
		Name = "제단",
		Build = function(model, cf)
			addBlock(model, cf, CFrame.new(0, 1, 2), Vector3.new(12, 2, 9), DARK)
			addBlock(model, cf, CFrame.new(0, 3, 2), Vector3.new(9, 2, 6.5), STONE)
			local top = addBlock(model, cf, CFrame.new(0, 4.5, 2), Vector3.new(7, 1, 5), STONE)
			addMoss(model, top)
			addPillar(model, cf, Vector3.new(-5, 4, 4.5), 3, 1.2, DARK)
			addPillar(model, cf, Vector3.new(5, 4, 4.5), 3, 1.2, DARK)
		end,
	},
	{
		Name = "석상",
		Build = function(model, cf)
			addBlock(model, cf, CFrame.new(0, 1.5, 3), Vector3.new(6, 3, 6), DARK)
			addBlock(model, cf, CFrame.new(0, 6.5, 3), Vector3.new(3.6, 7, 2.6), STONE)
			local head = addBlock(model, cf, CFrame.new(0, 11.4, 3), Vector3.new(3, 2.8, 3), STONE)
			addBlock(model, cf, CFrame.new(-2.4, 7, 3), Vector3.new(1.2, 5, 1.4), STONE)
			addBlock(model, cf, CFrame.new(2.4, 7, 3), Vector3.new(1.2, 5, 1.4), STONE)
			addMoss(model, head)
		end,
	},
	{
		Name = "동굴 입구",
		Build = function(model, cf)
			addBlock(model, cf, CFrame.new(-5, 5, 4) * CFrame.Angles(0, 0, 0.08), Vector3.new(6, 10, 8), DARK, Enum.Material.Rock)
			addBlock(model, cf, CFrame.new(5, 5, 4) * CFrame.Angles(0, 0, -0.08), Vector3.new(6, 10, 8), DARK, Enum.Material.Rock)
			local top = addBlock(model, cf, CFrame.new(0, 11, 4), Vector3.new(17, 4, 9), STONE, Enum.Material.Rock)
			addMoss(model, top)
			-- 안쪽은 깜깜해요
			addBlock(model, cf, CFrame.new(0, 4.5, 7.5), Vector3.new(5, 9, 1), COLORS.CaveDark, Enum.Material.SmoothPlastic)
		end,
	},
	{
		Name = "우물",
		Build = function(model, cf)
			local ringCount = 8
			for i = 1, ringCount do
				local angle = i / ringCount * TAU
				local offset = Vector3.new(math.cos(angle) * 3.4, 1.5, 3 + math.sin(angle) * 3.4)
				addBlock(model, cf, CFrame.new(offset) * CFrame.Angles(0, -angle, 0), Vector3.new(1.4, 3, 2.9), STONE)
			end
			makeDecor({
				Parent = model,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, 5.6, 5.6),
				CFrame = cf * CFrame.new(0, 2.2, 3) * UPRIGHT,
				Color = COLORS.WellWater,
				Material = Enum.Material.SmoothPlastic,
				Reflectance = 0.15,
			})
			addPillar(model, cf, Vector3.new(-3.6, 0, 3), 7, 0.8, COLORS.Log, Enum.Material.Wood)
			addPillar(model, cf, Vector3.new(3.6, 0, 3), 7, 0.8, COLORS.Log, Enum.Material.Wood)
			addBlock(model, cf, CFrame.new(0, 7.2, 3), Vector3.new(8.4, 0.8, 0.8), COLORS.Log, Enum.Material.Wood)
		end,
	},
	{
		Name = "돌문",
		Build = function(model, cf)
			addBlock(model, cf, CFrame.new(-5.5, 6, 3), Vector3.new(3, 12, 3), STONE)
			addBlock(model, cf, CFrame.new(5.5, 6, 3), Vector3.new(3, 12, 3), STONE)
			local lintel = addBlock(model, cf, CFrame.new(0, 13.25, 3), Vector3.new(15, 2.5, 4), DARK)
			addMoss(model, lintel)
		end,
	},
	{
		Name = "계단 신전",
		Build = function(model, cf)
			local steps = { { 16, 3 }, { 12, 3 }, { 8, 3 }, { 4, 2 } }
			local y = 0
			local last
			for _, step in steps do
				local width, height = step[1], step[2]
				last = addBlock(model, cf, CFrame.new(0, y + height / 2, 7), Vector3.new(width, height, width), (y == 0) and DARK or STONE)
				y += height
			end
			addMoss(model, last)
		end,
	},
	{
		Name = "돌 고리",
		Build = function(model, cf)
			local count = 7
			for i = 1, count do
				local angle = i / count * TAU
				local offset = Vector3.new(math.cos(angle) * 7, 0, 4 + math.sin(angle) * 7)
				local height = rng:NextNumber(5, 9)
				local stone = addBlock(
					model,
					cf,
					CFrame.new(offset + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, -angle, rng:NextNumber(-0.1, 0.1)),
					Vector3.new(1.6, height, 2.4),
					STONE
				)
				if i % 2 == 0 then
					addMoss(model, stone)
				end
			end
		end,
	},
}

local function buildRuins(root: Folder)
	local folder = makeFolder("Ruins", root)
	local ruins = {}
	local startAngle = rng:NextNumber(0, TAU)

	for i = 1, MAP.RuinCount do
		local builder = RUIN_BUILDERS[(i - 1) % #RUIN_BUILDERS + 1]
		local angle = startAngle + (i - 1) / MAP.RuinCount * TAU + rng:NextNumber(-MAP.RuinAngleJitter, MAP.RuinAngleJitter)
		local dist = rng:NextNumber(MAP.RuinMinRadius, MAP.RuinMaxRadius)
		local pos = Vector3.new(math.cos(angle), 0, math.sin(angle)) * dist
		-- 유적 앞쪽(-Z)이 캠프를 보게 해요
		local cf = CFrame.lookAt(pos, Vector3.zero)

		local model = makeModel("Ruin" .. i, folder)
		builder.Build(model, cf)

		-- 발굴 자리 (흙더미)
		local digSpot = makePart({
			Name = "DigSpot",
			Parent = model,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(MAP.DigSpotSize.Y, MAP.DigSpotSize.X, MAP.DigSpotSize.Z),
			CFrame = cf * CFrame.new(0, MAP.DigSpotSize.Y / 2 - 0.4, -MAP.DigSpotOffset) * UPRIGHT,
			Color = COLORS.Dirt,
			Material = Enum.Material.Ground,
			CanCollide = false,
		})
		digSpot:SetAttribute("RuinId", i)
		digSpot:SetAttribute("RuinName", builder.Name)
		makeLabel(digSpot, "🏛️ " .. builder.Name, 5, 70)

		model.PrimaryPart = digSpot
		reserve(pos, MAP.RuinClearRadius)
		table.insert(ruins, { Id = i, Name = builder.Name, Model = model, DigSpot = digSpot, Position = pos })
	end
	return ruins
end

----------------------------------------------------------------
-- 늪, 쓰러진 거목, 이끼 석상
----------------------------------------------------------------

local function buildSwamps(root: Folder)
	local folder = makeFolder("Swamps", root)
	local swamps = {}
	for _ = 1, MAP.SwampCount do
		local size = rng:NextNumber(MAP.SwampSizeMin, MAP.SwampSizeMax)
		local pos = findFreeSpot(size / 2, size)
		if pos then
			reserve(pos, size / 2)
			table.insert(swamps, { Pos = pos, Size = size })
			local model = makeModel("Swamp", folder)
			-- 진흙 테두리
			makeDecor({
				Parent = model,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.1, size + 3, size + 3),
				CFrame = CFrame.new(pos + Vector3.new(0, 0.04, 0)) * UPRIGHT,
				Color = COLORS.Dirt,
				Material = Enum.Material.Mud,
			})
			-- 탁한 물
			makeDecor({
				Parent = model,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.1, size, size),
				CFrame = CFrame.new(pos + Vector3.new(0, 0.08, 0)) * UPRIGHT,
				Color = COLORS.Swamp,
				Material = Enum.Material.SmoothPlastic,
				Reflectance = 0.12,
				Transparency = 0.1,
			})
			-- 갈대
			for _ = 1, MAP.ReedsPerSwamp do
				local angle = rng:NextNumber(0, TAU)
				local r = size / 2 + rng:NextNumber(-1, 1)
				local height = rng:NextNumber(3, 6)
				makeDecor({
					Parent = model,
					Size = Vector3.new(0.3, height, 0.3),
					CFrame = CFrame.new(pos + Vector3.new(math.cos(angle) * r, height / 2, math.sin(angle) * r))
						* CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)),
					Color = COLORS.Reed,
					Material = Enum.Material.Grass,
				})
			end
		end
	end
	return swamps
end

local function buildFallenLogs(root: Folder)
	local folder = makeFolder("FallenLogs", root)
	for _ = 1, MAP.FallenLogCount do
		local length = rng:NextNumber(MAP.FallenLogLengthMin, MAP.FallenLogLengthMax)
		local diameter = rng:NextNumber(MAP.FallenLogDiameterMin, MAP.FallenLogDiameterMax)
		local pos = findFreeSpot(length / 2, length / 2)
		if pos then
			reserve(pos, length / 2)
			local model = makeModel("FallenLog", folder)
			local cf = CFrame.new(pos + Vector3.new(0, diameter / 2 - 0.4, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
			makePart({
				Parent = model,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(length, diameter, diameter),
				CFrame = cf,
				Color = COLORS.Trunk,
				Material = Enum.Material.Wood,
				CastShadow = true,
			})
			-- 등에 난 이끼
			makeDecor({
				Parent = model,
				Size = Vector3.new(length * 0.6, 0.4, diameter * 0.5),
				CFrame = cf * CFrame.new(rng:NextNumber(-length * 0.1, length * 0.1), diameter / 2 - 0.05, 0),
				Color = COLORS.Moss,
				Material = Enum.Material.Grass,
			})
		end
	end
end

local function buildMossStatues(root: Folder)
	local folder = makeFolder("MossStatues", root)
	for _ = 1, MAP.MossStatueCount do
		local pos = findFreeSpot(4, 10)
		if pos then
			reserve(pos, 4)
			local model = makeModel("MossStatue", folder)
			local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
			addBlock(model, cf, CFrame.new(0, 1, 0), Vector3.new(3.5, 2, 3.5), DARK)
			addBlock(model, cf, CFrame.new(0, 4, 0), Vector3.new(2.4, 4, 1.8), STONE)
			local head = addBlock(model, cf, CFrame.new(0, 7, 0), Vector3.new(2, 2, 2), STONE)
			addMoss(model, head)
		end
	end
end

----------------------------------------------------------------
-- 나무와 덩굴
----------------------------------------------------------------

-- 나무 한 그루를 만들고, 잎 덩어리 목록을 돌려줘요
local function buildTree(folder: Instance, pos: Vector3, simple: boolean)
	local model = makeModel("Tree", folder)
	local height = rng:NextNumber(MAP.TreeHeightMin, MAP.TreeHeightMax)
	local trunkD = rng:NextNumber(MAP.TreeTrunkMin, MAP.TreeTrunkMax)
	makePart({
		Name = "Trunk",
		Parent = model,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, trunkD, trunkD),
		CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * UPRIGHT,
		Color = COLORS.Trunk,
		Material = Enum.Material.Wood,
		CastShadow = true,
	})

	local leaves = {}
	local ballCount = simple and MAP.TreeLeafBallsMin - 1 or rng:NextInteger(MAP.TreeLeafBallsMin, MAP.TreeLeafBallsMax)
	for _ = 1, ballCount do
		local leafSize = rng:NextNumber(MAP.TreeLeafSizeMin, MAP.TreeLeafSizeMax)
		local offset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 0.4), rng:NextNumber(-1, 1)) * leafSize * 0.45
		local leaf = makeDecor({
			Parent = model,
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * leafSize,
			CFrame = CFrame.new(pos + Vector3.new(0, height, 0) + offset),
			Color = pick(COLORS.Leaves),
			Material = Enum.Material.Grass,
			CastShadow = true,
		})
		table.insert(leaves, leaf)
	end
	return model, leaves, height, trunkD
end

-- 장작을 주울 수 있는 나뭇가지 더미
local function buildWoodSpot(model: Model, treePos: Vector3, index: number)
	local dir = flat(treePos).Magnitude > 0 and -flat(treePos).Unit or Vector3.xAxis
	local pos = treePos + dir * 3.5
	local spot = makePart({
		Name = "WoodSpot",
		Parent = model,
		Size = Vector3.new(3, 1, 3),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)),
		Transparency = 1,
		CanCollide = false,
	})
	spot:SetAttribute("WoodSpotId", index)
	for i = 1, 3 do
		makeDecor({
			Parent = model,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.2, 0.5, 0.5),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.25 + (i - 1) * 0.3, 0)) * CFrame.Angles(0, i * 1.1, 0),
			Color = COLORS.Log,
			Material = Enum.Material.Wood,
		})
	end
	return spot
end

local function buildTrees(root: Folder)
	local folder = makeFolder("Trees", root)
	local leafBalls = {}
	local woodSpots = {}
	local trees = {} -- 동물들이 앉을 나무 정보

	for i = 1, MAP.TreeCount do
		local pos = findFreeSpot(MAP.TreeSpacing / 2, MAP.BoundaryInset * 2)
		if pos then
			reserve(pos, MAP.TreeSpacing / 2)
			local model, leaves, height, trunkD = buildTree(folder, pos, false)
			table.insert(trees, { Pos = pos, Height = height, TrunkRadius = trunkD / 2, Model = model })
			for _, leaf in leaves do
				table.insert(leafBalls, leaf)
			end
			if i <= MAP.ChoppableTreeCount then
				model.Name = "ChoppableTree"
				local spot = buildWoodSpot(model, pos, #woodSpots + 1)
				table.insert(woodSpots, { Id = #woodSpots + 1, Part = spot, Model = model })
			end
		end
	end

	-- 지도 가장자리를 빽빽한 나무로 둘러요
	local edge = makeFolder("EdgeTrees", root)
	local limit = MAP.HalfSize - MAP.BoundaryInset
	local step = MAP.BoundaryTreeSpacing
	local along = -limit
	while along <= limit do
		for _, pos in { Vector3.new(along, 0, limit), Vector3.new(along, 0, -limit), Vector3.new(limit, 0, along), Vector3.new(-limit, 0, along) } do
			buildTree(edge, pos + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)), true)
		end
		along += step
	end

	-- 덩굴 : 나뭇잎에서 아래로 늘어져요
	local vines = makeFolder("Vines", root)
	for _ = 1, MAP.VineCount do
		if #leafBalls == 0 then
			break
		end
		local leaf = pick(leafBalls)
		local length = rng:NextNumber(MAP.VineLengthMin, MAP.VineLengthMax)
		local r = leaf.Size.X / 2
		local angle = rng:NextNumber(0, TAU)
		local top = leaf.Position + Vector3.new(math.cos(angle) * r * 0.7, -r * 0.5, math.sin(angle) * r * 0.7)
		makeDecor({
			Parent = vines,
			Size = Vector3.new(0.35, length, 0.35),
			CFrame = CFrame.new(top - Vector3.new(0, length / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08)),
			Color = COLORS.Vine,
			Material = Enum.Material.Grass,
		})
	end

	return woodSpots, trees
end

----------------------------------------------------------------
-- 식량 자리 (버섯, 열매, 바나나, 덫)
----------------------------------------------------------------

local FOOD_BUILDERS = {
	Mushroom = function(model, pos)
		for i = 1, 3 do
			local p = pos + Vector3.new(math.cos(i * 2.1), 0, math.sin(i * 2.1)) * 0.9
			local stemH = 1 + i * 0.2
			makeDecor({
				Parent = model,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(stemH, 0.5, 0.5),
				CFrame = CFrame.new(p + Vector3.new(0, stemH / 2, 0)) * UPRIGHT,
				Color = COLORS.MushroomStem,
				Material = Enum.Material.SmoothPlastic,
			})
			makeDecor({
				Parent = model,
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 1.5,
				CFrame = CFrame.new(p + Vector3.new(0, stemH + 0.2, 0)),
				Color = COLORS.Mushroom,
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end,
	Berry = function(model, pos)
		makeDecor({
			Parent = model,
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 4,
			CFrame = CFrame.new(pos + Vector3.new(0, 1.4, 0)),
			Color = COLORS.Leaves[2],
			Material = Enum.Material.Grass,
		})
		for i = 1, 6 do
			local angle = i / 6 * TAU
			makeDecor({
				Parent = model,
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.6,
				CFrame = CFrame.new(pos + Vector3.new(math.cos(angle) * 1.9, 1.2 + (i % 2) * 0.8, math.sin(angle) * 1.9)),
				Color = COLORS.Berry,
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end,
	Banana = function(model, pos)
		makeDecor({
			Parent = model,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, 0.8, 0.8),
			CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) * UPRIGHT,
			Color = COLORS.Trunk,
			Material = Enum.Material.Wood,
		})
		for i = 1, 4 do
			makeDecor({
				Parent = model,
				Size = Vector3.new(0.2, 1.2, 5),
				CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, -2.2) * CFrame.Angles(0.5, 0, 0),
				Color = COLORS.Leaves[4],
				Material = Enum.Material.Grass,
			})
		end
		for i = 1, 4 do
			makeDecor({
				Parent = model,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.2, 0.4, 0.4),
				CFrame = CFrame.new(pos + Vector3.new(0.6, 4.6 - i * 0.1, 0)) * CFrame.Angles(0, i * 0.6, 1.2),
				Color = COLORS.Banana,
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end,
	Trap = function(model, pos)
		-- 열매를 모으는 나무 덫 (상자 + 막대)
		makeDecor({
			Parent = model,
			Size = Vector3.new(2.4, 1.2, 2.4),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0)),
			Color = COLORS.Log,
			Material = Enum.Material.WoodPlanks,
		})
		makeDecor({
			Parent = model,
			Size = Vector3.new(0.3, 2.6, 0.3),
			CFrame = CFrame.new(pos + Vector3.new(1.4, 1.3, 0)) * CFrame.Angles(0, 0, 0.3),
			Color = COLORS.Trunk,
			Material = Enum.Material.Wood,
		})
	end,
}
local FOOD_KINDS = { "Mushroom", "Berry", "Banana", "Trap" }

local function buildFoodSpots(root: Folder)
	local folder = makeFolder("FoodSpots", root)
	local spots = {}
	for i = 1, MAP.FoodSpotCount do
		local pos = findFreeSpot(MAP.FoodSpotSpacing / 2, MAP.BoundaryInset * 3)
		if pos then
			reserve(pos, MAP.FoodSpotSpacing / 2)
			local kind = FOOD_KINDS[(i - 1) % #FOOD_KINDS + 1]
			local model = makeModel("Food_" .. kind, folder)
			local anchor = makePart({
				Name = "FoodSpot",
				Parent = model,
				Size = Vector3.new(3, 1, 3),
				CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)),
				Transparency = 1,
				CanCollide = false,
			})
			anchor:SetAttribute("FoodKind", kind)
			anchor:SetAttribute("FoodSpotId", #spots + 1)
			FOOD_BUILDERS[kind](model, pos)
			model.PrimaryPart = anchor
			table.insert(spots, { Id = #spots + 1, Kind = kind, Part = anchor, Model = model })
		end
	end
	return spots
end

----------------------------------------------------------------
-- 덤불
----------------------------------------------------------------

local function buildBushes(root: Folder)
	local folder = makeFolder("Bushes", root)
	local bushes = {}
	for _ = 1, MAP.BushCount do
		local size = rng:NextNumber(3, 6)
		local pos = findFreeSpot(size / 2, MAP.BoundaryInset)
		if pos then
			reserve(pos, size / 3)
			table.insert(bushes, { Pos = pos, Size = size })
			makeDecor({
				Parent = folder,
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * size,
				CFrame = CFrame.new(pos + Vector3.new(0, size * 0.2, 0)),
				Color = pick(COLORS.Leaves),
				Material = Enum.Material.Grass,
			})
		end
	end
	return bushes
end

----------------------------------------------------------------
-- 땅에 깔리는 물안개 (늪 위와 정글 곳곳)
----------------------------------------------------------------

local MIST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local function addMist(folder: Instance, pos: Vector3, width: number)
	local A = Config.Atmosphere
	local emitterPart = makeDecor({
		Name = "Mist",
		Parent = folder,
		Size = Vector3.new(width, 1, width),
		CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)),
		Transparency = 1,
	})
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = MIST_TEXTURE
	mist.Rate = A.MistRate
	mist.Lifetime = NumberRange.new(A.MistLifetime * 0.7, A.MistLifetime)
	mist.Size = NumberSequence.new(A.MistSize * 0.6, A.MistSize)
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, A.MistTransparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Color = ColorSequence.new(A.MistColor)
	mist.Speed = NumberRange.new(0.3, 1)
	mist.SpreadAngle = Vector2.new(180, 10)
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-8, 8)
	mist.LightInfluence = 1
	mist.Shape = Enum.ParticleEmitterShape.Box
	mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	mist.Parent = emitterPart
end

local function buildMist(root: Folder, swamps)
	local folder = makeFolder("Mist", root)
	for _, swamp in swamps do
		addMist(folder, swamp.Pos, swamp.Size)
	end
	local limit = MAP.HalfSize - MAP.BoundaryInset * 2
	for _ = 1, Config.Atmosphere.MistSpotCount do
		local pos = Vector3.new(rng:NextNumber(-limit, limit), 0, rng:NextNumber(-limit, limit))
		addMist(folder, pos, Config.Atmosphere.MistSize * 2)
	end
end

----------------------------------------------------------------
-- 하늘과 안개 (낮 기본값. 밤 변화는 DayCycle이 맡아요)
----------------------------------------------------------------

function MapBuilder.SetupLighting()
	local A = Config.Atmosphere
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = A.DayDensity
	atmosphere.Offset = A.Offset
	atmosphere.Color = A.DayColor
	atmosphere.Decay = A.DayDecay
	atmosphere.Glare = A.Glare
	atmosphere.Haze = A.Haze

	Lighting.ClockTime = Config.Time.ClockDayStart
	Lighting.Ambient = A.DayAmbient
	Lighting.OutdoorAmbient = A.DayAmbient
	Lighting.Brightness = A.DayBrightness
	Lighting.GlobalShadows = true

	-- 색을 살짝 빼서 축축하고 음산하게
	local correction = Lighting:FindFirstChild("JungleColor")
	if not correction then
		correction = Instance.new("ColorCorrectionEffect")
		correction.Name = "JungleColor"
		correction.Parent = Lighting
	end
	correction.Saturation = A.Saturation
	correction.Contrast = A.Contrast
	correction.TintColor = A.Tint

	-- 잿빛 구름
	local terrain = Workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Parent = terrain
	end
	clouds.Cover = A.CloudCover
	clouds.Density = A.CloudDensity
	clouds.Color = A.CloudColor
end

----------------------------------------------------------------
-- 전부 만들기
----------------------------------------------------------------

function MapBuilder.Build()
	rng = Random.new(MAP.Seed)
	occupied = {}

	-- 예전에 만든 지도가 있으면 지우고 새로 만들어요 (HandMade는 그대로)
	local old = Workspace:FindFirstChild("Generated")
	if old then
		old:Destroy()
	end
	local root = makeFolder("Generated", Workspace)

	buildGround(root)
	local spawn = buildSpawn(root)
	local camp = buildCamp(root)
	local tents = buildTents(root)
	local ruins = buildRuins(root)
	local swamps = buildSwamps(root)
	buildFallenLogs(root)
	buildMossStatues(root)
	local woodSpots, trees = buildTrees(root)
	local foodSpots = buildFoodSpots(root)
	local bushes = buildBushes(root)
	buildMist(root, swamps)
	MapBuilder.SetupLighting()

	local info = {
		Root = root,
		Spawn = spawn,
		FirePosition = camp.FirePosition,
		FireFlame = camp.FireFlame,
		FireLight = camp.FireLight,
		FireEffect = camp.FireEffect,
		WoodPile = camp.WoodPile,
		WoodLabel = camp.WoodLabel,
		FoodStore = camp.FoodStore,
		FoodLabel = camp.FoodLabel,
		Tents = tents,
		Ruins = ruins,
		WoodSpots = woodSpots,
		FoodSpots = foodSpots,
		Trees = trees,
		Swamps = swamps,
		Bushes = bushes,
	}
	MapBuilder.Info = info

	print(
		string.format(
			"[MapBuilder] 정글 완성! 유적 %d곳, 장작 나무 %d그루, 식량 자리 %d곳, 텐트 %d개",
			#ruins,
			#woodSpots,
			#foodSpots,
			#tents
		)
	)
	return info
end

return MapBuilder
