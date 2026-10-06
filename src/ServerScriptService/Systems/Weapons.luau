-- 창·도끼·활을 만들고, 캠프 무기 거치대에서 들 수 있게 해요. 무기는 한 번에 하나만 들어요.
-- 무기를 쓰면 서버가 맞았는지 판정해요. 창·화살은 날아가고, 도끼는 앞을 휘둘러요.
-- 무기는 사냥감에게만 맞아요. 사람과 NPC는 그냥 통과해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config)
local Remotes = require(ReplicatedStorage.Remotes)
local MapBuilder = require(ServerScriptService.Systems.MapBuilder)
local Hunting = require(ServerScriptService.Systems.Hunting)

local H = Config.Hunt
local COLORS = Config.Colors

local Weapons = {}

local templates = {} -- 무기 이름 → Tool 원본
local projectileFolder: Folder
local lastUse = {} -- 플레이어 → 마지막으로 무기 쓴 시각

----------------------------------------------------------------
-- 무기 모양 (긴 쪽이 Z. +Z 끝이 날·촉이에요)
----------------------------------------------------------------

local function toolPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.Wood
	part.Shape = shape or Enum.PartType.Block
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- 무기마다 : 몸통(Handle) 크기, 잡는 위치, 나머지 조각들
local WEAPON_SHAPES = {
	Spear = {
		HandleSize = Vector3.new(0.3, 0.3, 6),
		GripZ = -1.5,
		Extra = function(parent, handle)
			toolPart(parent, "Tip", Vector3.new(0.45, 0.45, 1.1), handle.CFrame * CFrame.new(0, 0, 3.4) * CFrame.Angles(0, 0, math.pi / 4), COLORS.WeaponStone, Enum.Material.Slate)
		end,
	},
	Axe = {
		HandleSize = Vector3.new(0.3, 0.3, 3.6),
		GripZ = -1.3,
		Extra = function(parent, handle)
			toolPart(parent, "Head", Vector3.new(0.35, 1.4, 0.9), handle.CFrame * CFrame.new(0, 0.6, 1.5), COLORS.WeaponStone, Enum.Material.Slate)
		end,
	},
	Bow = {
		HandleSize = Vector3.new(0.25, 0.25, 1.2),
		GripZ = 0,
		Extra = function(parent, handle)
			-- 활대 위·아래 두 조각과 활시위
			toolPart(parent, "LimbTop", Vector3.new(0.2, 0.2, 1.8), handle.CFrame * CFrame.new(0, 0.35, 1.4) * CFrame.Angles(0.35, 0, 0), COLORS.WeaponWood)
			toolPart(parent, "LimbBottom", Vector3.new(0.2, 0.2, 1.8), handle.CFrame * CFrame.new(0, 0.35, -1.4) * CFrame.Angles(-0.35, 0, 0), COLORS.WeaponWood)
			toolPart(parent, "String", Vector3.new(0.05, 0.05, 4.4), handle.CFrame * CFrame.new(0, 0.95, 0), COLORS.BowString, Enum.Material.Fabric)
		end,
	},
}

-- 날아가는 것(창, 화살)의 모양
local PROJECTILE_SHAPES = {
	Spear = function(model)
		local shaft = toolPart(model, "Shaft", Vector3.new(0.3, 0.3, 6), CFrame.new(), COLORS.WeaponWood)
		toolPart(model, "Tip", Vector3.new(0.45, 0.45, 1.1), CFrame.new(0, 0, 3.4) * CFrame.Angles(0, 0, math.pi / 4), COLORS.WeaponStone, Enum.Material.Slate)
		return shaft
	end,
	Bow = function(model)
		local shaft = toolPart(model, "Shaft", Vector3.new(0.12, 0.12, 2.6), CFrame.new(), COLORS.WeaponWood)
		toolPart(model, "Tip", Vector3.new(0.25, 0.25, 0.4), CFrame.new(0, 0, 1.4) * CFrame.Angles(0, 0, math.pi / 4), COLORS.WeaponStone, Enum.Material.Slate)
		toolPart(model, "Feather", Vector3.new(0.05, 0.35, 0.5), CFrame.new(0, 0, -1.1), COLORS.BowString, Enum.Material.Fabric)
		return shaft
	end,
}

local function weldAll(model: Instance, main: BasePart)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= main then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = main
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

local function buildTool(weaponId: string): Tool
	local def = H.Weapons[weaponId]
	local shape = WEAPON_SHAPES[weaponId]
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.ToolTip = def.Icon .. " " .. def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("WeaponId", weaponId)
	-- 칼처럼 위로 세워서 들어요
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)
	tool.GripPos = Vector3.new(0, 0, shape.GripZ)

	local handle = toolPart(tool, "Handle", shape.HandleSize, CFrame.new(), COLORS.WeaponWood)
	shape.Extra(tool, handle)
	weldAll(tool, handle)
	return tool
end

----------------------------------------------------------------
-- 무기 거치대 : 들고 가기
----------------------------------------------------------------

local function removeWeapons(player: Player)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, item in container:GetChildren() do
				if item:IsA("Tool") and item:GetAttribute("WeaponId") then
					item:Destroy()
				end
			end
		end
	end
end

local function giveWeapon(player: Player, weaponId: string)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not humanoid or humanoid.Health <= 0 or not backpack then
		return
	end
	removeWeapons(player)
	local tool = templates[weaponId]:Clone()
	tool.Parent = backpack
	humanoid:EquipTool(tool)
	local def = H.Weapons[weaponId]
	Remotes.Notify:FireClient(player, string.format("%s %s을(를) 들었어!", def.Icon, def.Name))
end

local function setupRack()
	for _, stand in MapBuilder.Info.WeaponStands do
		local weaponId = stand:GetAttribute("WeaponId")
		local def = H.Weapons[weaponId]

		-- 받침대 위에 무기를 세워서 보여줘요
		local display = templates[weaponId]:Clone()
		local model = Instance.new("Model")
		model.Name = "Display_" .. weaponId
		for _, part in display:GetChildren() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.Parent = model
			end
		end
		display:Destroy()
		model.PrimaryPart = model:FindFirstChild("Handle")
		local top = stand.CFrame * CFrame.new(0, stand.Size.Y / 2 + model:GetExtentsSize().Z / 2, 0)
		model:PivotTo(top * CFrame.Angles(-math.pi / 2, 0, 0))
		model.Parent = stand.Parent

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = def.Name .. " 들기"
		prompt.ObjectText = def.Icon .. " " .. def.Name
		prompt.HoldDuration = H.TakeWeaponSeconds
		prompt.RequiresLineOfSight = false
		prompt.Parent = stand
		prompt.Triggered:Connect(function(player)
			giveWeapon(player, weaponId)
		end)
	end
end

----------------------------------------------------------------
-- 날아가는 창·화살
----------------------------------------------------------------

-- 사람·NPC·날아가는 것들은 무시하고 부딪혀요
local function makeRayParams(): RaycastParams
	local ignore = { projectileFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local npcFolder = Workspace:FindFirstChild("Archaeologists")
	if npcFolder then
		table.insert(ignore, npcFolder)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

local function launch(weaponId: string, origin: Vector3, direction: Vector3)
	local def = H.Weapons[weaponId]
	local model = Instance.new("Model")
	model.Name = weaponId .. "Projectile"
	local main = PROJECTILE_SHAPES[weaponId](model)
	for _, part in model:GetChildren() do
		part.Anchored = true
	end
	model.PrimaryPart = main
	model.Parent = projectileFolder

	local params = makeRayParams()
	local position = origin
	local velocity = direction * def.Speed
	local travelled = 0
	local gravity = Vector3.new(0, -def.Gravity, 0)

	-- +Z가 날아가는 쪽을 보게 돌려요
	local function aim(pos: Vector3, vel: Vector3): CFrame
		return CFrame.lookAt(pos, pos + vel) * CFrame.Angles(0, math.pi, 0)
	end
	model:PivotTo(aim(position, velocity))

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		velocity += gravity * dt
		local step = velocity * dt
		local result = Workspace:Raycast(position, step, params)
		if result then
			connection:Disconnect()
			local prey = Hunting.FindPrey(result.Instance)
			if prey then
				Hunting.Damage(prey, def.Damage, origin)
				model:Destroy()
			else
				-- 땅이나 나무에 꽂혔다가 사라져요
				model:PivotTo(aim(result.Position, velocity))
				task.delay(H.StuckSeconds, function()
					model:Destroy()
				end)
			end
			return
		end
		position += step
		travelled += step.Magnitude
		model:PivotTo(aim(position, velocity))
		if travelled > def.MaxDistance or position.Y < -Config.Map.GroundThickness then
			connection:Disconnect()
			model:Destroy()
		end
	end)
end

----------------------------------------------------------------
-- 무기 쓰기 (화면에서 "여기를 노렸어"가 와요)
----------------------------------------------------------------

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < math.huge and math.abs(v.Y) < math.huge and math.abs(v.Z) < math.huge
end

local function onUseWeapon(player: Player, target)
	if typeof(target) ~= "Vector3" or not isFiniteVector(target) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	-- 지금 손에 든 무기만 쓸 수 있어요
	local tool = character:FindFirstChildOfClass("Tool")
	local weaponId = tool and tool:GetAttribute("WeaponId")
	local def = weaponId and H.Weapons[weaponId]
	if not def then
		return
	end
	local now = os.clock()
	if lastUse[player] and now - lastUse[player] < def.Cooldown then
		return
	end
	lastUse[player] = now

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local offset = target - origin
	local direction
	if offset.Magnitude < 1 or offset.Magnitude > H.AimMaxDistance then
		direction = root.CFrame.LookVector
	else
		direction = offset.Unit
	end

	if def.Kind == "Melee" then
		local prey = Hunting.FindPreyInFront(root.Position, direction, def.Range)
		if prey then
			Hunting.Damage(prey, def.Damage, root.Position)
		end
	else
		launch(weaponId, origin + direction * 2, direction)
	end
end

----------------------------------------------------------------
-- 시작
----------------------------------------------------------------

function Weapons.Init()
	for _, weaponId in H.WeaponOrder do
		templates[weaponId] = buildTool(weaponId)
	end
	projectileFolder = Instance.new("Folder")
	projectileFolder.Name = "Projectiles"
	projectileFolder.Parent = MapBuilder.Info.Root

	setupRack()
	Remotes.UseWeapon.OnServerEvent:Connect(onUseWeapon)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return Weapons
