-- 검은 그림자 괴물을 만들어요. 유적의 석상이 움직이는 것 같은 모습이에요.
-- 괴물 모델은 단순한 파츠 조합이고, 어떤 캐릭터의 모습 정보도 담지 않아요. (정체가 드러나지 않게)
-- (밤 사냥은 마일스톤 5에서 채워요. 지금은 모델 만들기만 있어요.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config)

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

function Monster.Init()
end

return Monster
