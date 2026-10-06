-- NPC 고고학자를 만들고(이름표·탐험모), 빈자리를 채우고, 플레이어와 자리를 바꿔요(드롭인).
-- 플레이어가 들어오면 NPC 하나가 "교대하러 갈게!" 하고 정글로 떠나요. 플레이어가 나가면 NPC가 새로 와요.
-- 저주를 가진 NPC는 교대하지 않아요. (저주가 끊기면 안 되니까요)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config)
local Remotes = require(ReplicatedStorage.Remotes)
local Systems = ServerScriptService.Systems
local MapBuilder = require(Systems.MapBuilder)
local Roster = require(Systems.Roster)
local Curse = require(Systems.Curse)
local NpcBrain = require(Systems.NpcBrain)

local NPC = Config.Npc
local TAU = math.pi * 2

local NpcManager = {}

local rng = Random.new()
local folder: Folder
local brains = {} -- 모델 → 생각(NpcBrain)
local usedNames = {}

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

----------------------------------------------------------------
-- 모습 : 몸 색, 탐험모, 이름표
----------------------------------------------------------------

local function addHat(head: BasePart)
	local function hatPart(name, shape, size, offset, color)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CFrame = head.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
		part.Parent = head.Parent
	end
	local top = head.Size.Y / 2
	-- 넓은 챙과 둥근 머리 (고고학자 탐험모)
	hatPart("HatBrim", Enum.PartType.Cylinder, Vector3.new(0.12, head.Size.X * 2, head.Size.X * 2), CFrame.new(0, top - 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2), NPC.HatColor)
	hatPart("HatDome", Enum.PartType.Ball, Vector3.one * head.Size.X * 1.15, CFrame.new(0, top + 0.1, 0), NPC.HatColor)
	hatPart("HatBand", Enum.PartType.Cylinder, Vector3.new(0.15, head.Size.X * 1.17, head.Size.X * 1.17), CFrame.new(0, top + 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2), NPC.HatBandColor)
end

local function addNameTag(model: Model, name: string)
	local head = model:FindFirstChild("Head")
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromScale(6, 1.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, NPC.NameTagHeight, 0)
	gui.MaxDistance = NPC.NameTagDistance
	gui.LightInfluence = 0
	gui.Adornee = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 0.6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextColor3 = Config.Colors.Label
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Text = name
	nameLabel.Parent = gui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Position = UDim2.fromScale(0, 0.6)
	titleLabel.Size = UDim2.fromScale(1, 0.4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextColor3 = Config.Colors.Label
	titleLabel.TextStrokeTransparency = 0.5
	titleLabel.Text = NPC.Title
	titleLabel.Parent = gui

	gui.Parent = head
end

-- 머리 위 직함 옆에 지금 하는 일 그림을 붙여요 (⛏️ 🪵 🍖 🔥 ⛺)
local function setStatus(model: Model, icon: string)
	local head = model:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("NameTag")
	if tag then
		tag.TitleLabel.Text = string.format("%s %s", NPC.Title, icon)
	end
end

-- 걷는 모습 (Roblox 기본 R15 애니메이션)
local function setupAnimation(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local function load(id: string)
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. id
		return animator:LoadAnimation(animation)
	end
	local idle = load(NPC.Animations.Idle)
	local walk = load(NPC.Animations.Walk)
	idle.Looped = true
	walk.Looped = true
	idle:Play()
	humanoid.Running:Connect(function(speed)
		if speed > NPC.WalkAnimThreshold then
			if not walk.IsPlaying then
				idle:Stop()
				walk:Play()
			end
		elseif not idle.IsPlaying then
			walk:Stop()
			idle:Play()
		end
	end)
end

local function takeName(): string
	local free = {}
	for _, name in NPC.Names do
		if not usedNames[name] then
			table.insert(free, name)
		end
	end
	local name = #free > 0 and pick(free) or pick(NPC.Names)
	usedNames[name] = true
	return name
end

local function campPoint(): Vector3
	local fire = MapBuilder.Info.FirePosition
	local angle = rng:NextNumber(0, TAU)
	local radius = rng:NextNumber(NPC.CampMeetRadiusMin, NPC.CampMeetRadiusMax)
	return fire + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

----------------------------------------------------------------
-- NPC 만들기 / 보내기
----------------------------------------------------------------

-- state : 물려받을 상태 { Ghost, Health } (없으면 새 사람)
function NpcManager.Spawn(state)
	local description = Instance.new("HumanoidDescription")
	local skin = pick(NPC.SkinColors)
	local shirt = pick(NPC.ShirtColors)
	local pants = pick(NPC.PantsColors)
	description.HeadColor = skin
	description.LeftArmColor = shirt
	description.RightArmColor = shirt
	description.TorsoColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	local name = takeName()
	model.Name = name
	model:SetAttribute("DisplayName", name)
	model:SetAttribute("IsNpc", true)
	if state then
		model:SetAttribute("Ghost", state.Ghost == true)
		model:SetAttribute("Health", state.Health)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.WalkSpeed = NPC.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) -- NPC는 쓰러지지 않아요 (유령은 따로 표시)

	local head = model:FindFirstChild("Head")
	if head then
		addHat(head)
		addNameTag(model, name)
	end

	model:PivotTo(CFrame.new(campPoint() + Vector3.new(0, humanoid.HipHeight + 3, 0)))
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		root:SetNetworkOwner(nil) -- 서버가 직접 움직여요
	end
	setupAnimation(humanoid)

	local brain = NpcBrain.new(model, function(icon)
		setStatus(model, icon)
	end)
	brains[model] = brain
	Roster.AddNpc(model)
	brain:Start()
	return model
end

-- "교대하러 갈게!" 하고 정글 쪽으로 걸어가서 사라져요
function NpcManager.SendAway(model: Model)
	local brain = brains[model]
	if brain then
		brain:Stop()
		brains[model] = nil
	end
	Roster.RemoveNpc(model) -- 짐(유물)은 이때 남은 사람들에게 맡겨요
	usedNames[model.Name] = nil
	setStatus(model, "👋 교대하러 갈게!")

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid and root then
		local away = Vector3.new(root.Position.X - MapBuilder.Info.FirePosition.X, 0, root.Position.Z - MapBuilder.Info.FirePosition.Z)
		away = away.Magnitude > 0 and away.Unit or Vector3.xAxis
		humanoid:MoveTo(root.Position + away * NPC.LeaveWalkDistance)
	end
	task.delay(NPC.LeaveSeconds, function()
		model:Destroy()
	end)
end

function NpcManager.GetAll()
	local list = {}
	for model in brains do
		table.insert(list, model)
	end
	return list
end

----------------------------------------------------------------
-- 드롭인 : 플레이어가 들어오고 나갈 때
----------------------------------------------------------------

-- 교대할 NPC 고르기 : 살아 있고 저주 없는 NPC 먼저, 없으면 유령 NPC
local function pickSwapTarget(): Model?
	local alive, ghosts = {}, {}
	for model in brains do
		if not Curse.IsHolder(model) then
			if Roster.IsGhost(model) then
				table.insert(ghosts, model)
			else
				table.insert(alive, model)
			end
		end
	end
	if #alive > 0 then
		return pick(alive)
	end
	if #ghosts > 0 then
		return pick(ghosts)
	end
	return nil
end

local function onPlayerJoined(player: Player)
	if #NpcManager.GetAll() + #Players:GetPlayers() <= Config.Server.MaxSlots then
		return -- 아직 자리가 남아 있어요
	end
	local target = pickSwapTarget()
	if not target then
		return
	end
	-- 유령 NPC 자리를 받으면 유령으로 들어와서 다음 탐사부터 참여해요
	local becomesGhost = Roster.IsGhost(target)
	player:SetAttribute("Ghost", becomesGhost)
	player:SetAttribute("Health", becomesGhost and 0 or Config.Health.Start)
	NpcManager.SendAway(target)
	Remotes.Notify:FireAllClients(string.format("🧭 새로 도착한 고고학자 %s! (%s은(는) 교대하러 갔어)", player.DisplayName, target.Name))
end

local function onPlayerLeft(player: Player)
	-- 빈자리는 NPC가 채워요. 살아 있음/유령, 체력을 물려받아요
	task.defer(function()
		local model = NpcManager.Spawn({
			Ghost = Roster.IsGhost(player),
			Health = player:GetAttribute("Health"),
		})
		Remotes.Notify:FireAllClients(string.format("🧭 %s이(가) 떠나고 %s이(가) 왔어", player.DisplayName, model.Name))
	end)
end

-- 빈자리를 모두 NPC로 채워요
function NpcManager.FillSlots()
	local missing = Config.Server.MaxSlots - #Players:GetPlayers() - #NpcManager.GetAll()
	for _ = 1, missing do
		NpcManager.Spawn(nil)
	end
end

-- 새 탐사 : 모두 캠프로 모여요
function NpcManager.ResetForExpedition()
	for model, brain in brains do
		brain:ResetForExpedition()
		model:PivotTo(CFrame.new(campPoint() + Vector3.new(0, model:FindFirstChildOfClass("Humanoid").HipHeight + 3, 0)))
	end
end

function NpcManager.Init()
	folder = Instance.new("Folder")
	folder.Name = "Archaeologists"
	folder.Parent = Workspace

	Roster.Joined:Connect(function(who)
		if who:IsA("Player") then
			onPlayerJoined(who)
		end
	end)
	Roster.Left:Connect(function(who)
		if who:IsA("Player") then
			onPlayerLeft(who)
		end
	end)

	-- 첫 플레이어가 들어올 시간을 조금 주고 나서 채워요
	task.delay(NPC.StartDelay, NpcManager.FillSlots)
end

return NpcManager
