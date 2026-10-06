-- 내 화면에서 정글 동물들을 움직여요. (새가 날고, 원숭이가 오르내리고, 개구리가 폴짝)
-- 낮 동물(나비, 새 떼)은 밤에 숨고, 밤 동물(박쥐, 빛나는 눈, 반딧불)은 밤에만 나와요.
-- 내 화면에서만 움직이는 장식이라 서버에는 부담이 없어요.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Config)
local W = Config.Wildlife
local TAU = math.pi * 2

local DAY_ONLY = { Butterfly = true, FlockBird = true }
local NIGHT_ONLY = { Bat = true, Eyes = true }

local player = Players.LocalPlayer
local rng = Random.new()
local entries = {} -- 움직이는 동물 목록
local fireflies = {} -- 반딧불 파츠 목록
local clock = 0 -- 지금까지 흐른 시간

local function isNight(): boolean
	local t = Lighting.ClockTime
	return t >= W.NightStartsAt or t < W.NightEndsAt
end

local function viewerPosition(): Vector3
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position
	end
	return Workspace.CurrentCamera.CFrame.Position
end

----------------------------------------------------------------
-- 동물 등록
----------------------------------------------------------------

local function register(model: Instance)
	if not model:IsA("Model") then
		if model:GetAttribute("Kind") == "Fireflies" then
			table.insert(fireflies, model)
		end
		return
	end
	local root = model:FindFirstChild("Root")
	if not root then
		return
	end
	local home = root.CFrame
	local entry = {
		Model = model,
		Kind = model:GetAttribute("Kind"),
		Home = home,
		Phase = model:GetAttribute("Phase") or rng:NextNumber(0, TAU),
		Parts = {},
		Offsets = {},
		Roles = {},
		Sides = {},
		Hidden = false,
		State = { Timer = 0, Pos = home.Position, Facing = home.Rotation, HeadYaw = 0, HeadTarget = 0 },
	}
	-- Root 기준으로 각 조각이 어디 붙어 있는지 기억해요
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= root then
			table.insert(entry.Parts, part)
			table.insert(entry.Offsets, home:ToObjectSpace(part.CFrame))
			table.insert(entry.Roles, part:GetAttribute("Role") or "")
			table.insert(entry.Sides, part:GetAttribute("Side") or 0)
		end
	end
	-- 원을 그리며 도는 동물의 중심
	local cx, cz = model:GetAttribute("CenterX"), model:GetAttribute("CenterZ")
	if cx and cz then
		entry.Center = Vector3.new(cx, 0, cz)
		entry.Radius = model:GetAttribute("Radius")
		entry.Height = model:GetAttribute("Height") or 0
	end
	table.insert(entries, entry)
end

local function setHidden(entry, hidden: boolean)
	if entry.Hidden == hidden then
		return
	end
	entry.Hidden = hidden
	local value = hidden and 1 or 0
	for _, part in entry.Parts do
		part.LocalTransparencyModifier = value
	end
end

----------------------------------------------------------------
-- 동물마다 움직임
----------------------------------------------------------------

-- 원 위의 한 점과 진행 방향
local function circlePoint(entry, angle: number, wobble: number): (Vector3, Vector3)
	local r = entry.Radius * (1 + wobble * math.sin(angle * 3))
	local pos = entry.Center + Vector3.new(math.cos(angle) * r, entry.Height, math.sin(angle) * r)
	local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
	return pos, tangent
end

-- 앉아 있던 새가 가끔 한 바퀴 날았다가 돌아와요
local function updatePerchedBird(entry, dt, night)
	local s = entry.State
	if s.Flying then
		s.Timer += dt
		local a = math.min(s.Timer / W.BirdFlySeconds, 1) * TAU
		local function at(angle)
			local localPos = Vector3.new(W.BirdFlyRadius * math.sin(angle), W.BirdFlyRadius * 0.4 * math.sin(angle / 2), -W.BirdFlyRadius * (1 - math.cos(angle)))
			return entry.Home:PointToWorldSpace(localPos)
		end
		local pos = at(a)
		local ahead = at(a + 0.05)
		if s.Timer >= W.BirdFlySeconds then
			s.Flying = false
			return entry.Home, 0, 0
		end
		return CFrame.lookAt(pos, ahead), math.sin(clock * W.ButterflyFlapSpeed) * 0.9, 0
	end
	if not night and rng:NextNumber() < W.BirdFlyChancePerSecond * dt then
		s.Flying = true
		s.Timer = 0
	end
	local bob = math.sin(clock * W.PerchBobSpeed + entry.Phase) * 0.05
	local turn = math.sin(clock * 0.7 + entry.Phase) * 0.35
	return entry.Home * CFrame.new(0, bob, 0) * CFrame.Angles(0, turn, 0), 0, 0
end

local function updateOwl(entry, dt)
	local s = entry.State
	if rng:NextNumber() < W.OwlHeadTurnChancePerSecond * dt then
		s.HeadTarget = rng:NextNumber(-1.6, 1.6) -- 부엉이는 고개를 휙 돌려요
	end
	s.HeadYaw += (s.HeadTarget - s.HeadYaw) * math.min(dt * 6, 1)
	return entry.Home, 0, s.HeadYaw
end

local function updateMonkey(entry)
	local bottom = entry.Model:GetAttribute("Bottom")
	local top = entry.Model:GetAttribute("Top")
	local k = 0.5 + 0.5 * math.sin(clock * W.MonkeyClimbSpeed + entry.Phase)
	local y = bottom + (top - bottom) * k
	local home = entry.Home
	local sway = math.sin(clock * 3 + entry.Phase) * 0.08
	return CFrame.new(home.X, y, home.Z) * home.Rotation * CFrame.Angles(0, 0, sway), 0, 0
end

local function updateCircling(entry, speed, wobble, flapSpeed, bobHeight)
	local angle = entry.Phase + clock * speed
	local pos, tangent = circlePoint(entry, angle, wobble)
	pos += Vector3.new(0, math.sin(clock * 1.3 + entry.Phase) * bobHeight, 0)
	return CFrame.lookAt(pos, pos + tangent), math.sin(clock * flapSpeed + entry.Phase) * 0.8, 0
end

local function updateFrog(entry, dt)
	local s = entry.State
	if s.Hopping then
		s.Timer += dt
		local k = math.min(s.Timer / W.FrogHopSeconds, 1)
		local pos = s.From:Lerp(s.To, k) + Vector3.new(0, math.sin(k * math.pi) * W.FrogHopHeight, 0)
		if k >= 1 then
			s.Hopping = false
			s.Pos = s.To
		end
		return CFrame.new(pos) * s.Facing, 0, 0
	end
	if rng:NextNumber() < W.FrogHopChancePerSecond * dt then
		-- 집에서 멀어지면 집 쪽으로 뛰어요
		local home = entry.Home.Position
		local dir
		if (s.Pos - home).Magnitude > W.FrogHopDistance * 1.5 then
			dir = (home - s.Pos).Unit
		else
			local a = rng:NextNumber(0, TAU)
			dir = Vector3.new(math.cos(a), 0, math.sin(a))
		end
		s.Hopping = true
		s.Timer = 0
		s.From = s.Pos
		s.To = s.Pos + dir * W.FrogHopDistance
		s.Facing = CFrame.lookAt(Vector3.zero, dir).Rotation
	end
	return CFrame.new(s.Pos) * s.Facing, 0, 0
end

local function updateLizard(entry, dt)
	local s = entry.State
	if s.Dashing then
		s.Timer += dt
		local k = math.min(s.Timer / W.LizardDashSeconds, 1)
		local pos = s.From:Lerp(s.To, k)
		if k >= 1 then
			s.Dashing = false
			s.Pos = s.To
		end
		return CFrame.new(pos) * s.Facing, 0, 0
	end
	if rng:NextNumber() < W.LizardDashChancePerSecond * dt then
		local home = entry.Home.Position
		local a = rng:NextNumber(0, TAU)
		local target = s.Pos + Vector3.new(math.cos(a), 0, math.sin(a)) * W.LizardDashDistance
		if (target - home).Magnitude > W.LizardRange then
			target = home
		end
		if (target - s.Pos).Magnitude > 0.1 then
			s.Dashing = true
			s.Timer = 0
			s.From = s.Pos
			s.To = target
			s.Facing = CFrame.lookAt(s.Pos, target).Rotation
		end
	end
	return CFrame.new(s.Pos) * s.Facing, 0, 0
end

local function updateButterfly(entry)
	local t = clock * W.ButterflySpeed + entry.Phase
	local function at(time)
		return entry.Home.Position
			+ Vector3.new(math.sin(time * 1.3) * W.ButterflyRange * 0.5, math.sin(time * 2.1) * 1, math.cos(time) * W.ButterflyRange * 0.5)
	end
	local pos = at(t)
	local ahead = at(t + 0.05)
	return CFrame.lookAt(pos, ahead), math.sin(clock * W.ButterflyFlapSpeed + entry.Phase) * 1.1, 0
end

local function updateEyes(entry, dt, viewer)
	local s = entry.State
	-- 너무 가까이 오면 사라져요
	local tooClose = (entry.Home.Position - viewer).Magnitude < W.EyeHideDistance
	if s.Blink then
		s.Timer += dt
		if s.Timer >= W.EyeBlinkSeconds then
			s.Blink = false
		end
	elseif rng:NextNumber() < W.EyeBlinkChancePerSecond * dt then
		s.Blink = true
		s.Timer = 0
	end
	setHidden(entry, tooClose or s.Blink)
	return nil
end

local function updateCroc(entry)
	local angle = entry.Phase + clock * W.CrocDriftSpeed
	local pos, tangent = circlePoint(entry, angle, 0)
	return CFrame.lookAt(pos, pos + tangent), 0, 0
end

----------------------------------------------------------------
-- 한 번 움직이기
----------------------------------------------------------------

local movedParts = {}
local movedFrames = {}

local function step(dt: number)
	clock += dt
	local night = isNight()
	local viewer = viewerPosition()
	table.clear(movedParts)
	table.clear(movedFrames)

	for i = #entries, 1, -1 do
		local entry = entries[i]
		if not entry.Model.Parent then
			table.remove(entries, i)
			continue
		end
		local kind = entry.Kind

		-- 낮/밤에 맞춰 숨기기
		local wrongTime = (DAY_ONLY[kind] and night) or (NIGHT_ONLY[kind] and not night)
		if kind ~= "Eyes" or wrongTime then
			setHidden(entry, wrongTime)
		end
		if wrongTime then
			continue
		end

		-- 멀리 있는 동물은 쉬어요 (성능)
		local here = entry.Center or entry.Home.Position
		if (here - viewer).Magnitude > W.ActiveDistance + (entry.Radius or 0) then
			continue
		end

		local rootCF, flap, headYaw
		if kind == "Parrot" or kind == "Toucan" then
			rootCF, flap, headYaw = updatePerchedBird(entry, dt, night)
		elseif kind == "Owl" then
			rootCF, flap, headYaw = updateOwl(entry, dt)
		elseif kind == "Monkey" then
			rootCF, flap, headYaw = updateMonkey(entry)
		elseif kind == "FlockBird" then
			rootCF, flap, headYaw = updateCircling(entry, W.FlockSpeed, 0, 6, 2)
		elseif kind == "Bat" then
			rootCF, flap, headYaw = updateCircling(entry, W.BatSpeed, 0.3, 22, 4)
		elseif kind == "Frog" then
			rootCF, flap, headYaw = updateFrog(entry, dt)
		elseif kind == "Lizard" then
			rootCF, flap, headYaw = updateLizard(entry, dt)
		elseif kind == "Butterfly" then
			rootCF, flap, headYaw = updateButterfly(entry)
		elseif kind == "Eyes" then
			rootCF = updateEyes(entry, dt, viewer)
		elseif kind == "Croc" then
			rootCF, flap, headYaw = updateCroc(entry)
		end

		if rootCF then
			for j, part in entry.Parts do
				local role = entry.Roles[j]
				local offset = entry.Offsets[j]
				local cf
				if role == "Wing" then
					cf = rootCF * CFrame.Angles(0, 0, entry.Sides[j] * flap) * offset
				elseif role == "Head" then
					cf = rootCF * CFrame.Angles(0, headYaw, 0) * offset
				else
					cf = rootCF * offset
				end
				table.insert(movedParts, part)
				table.insert(movedFrames, cf)
			end
		end
	end

	if #movedParts > 0 then
		Workspace:BulkMoveTo(movedParts, movedFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	for _, part in fireflies do
		local emitter = part:FindFirstChildOfClass("ParticleEmitter")
		if emitter then
			emitter.Enabled = night
		end
	end
end

----------------------------------------------------------------
-- 시작
----------------------------------------------------------------

local generated = Workspace:WaitForChild("Generated")
local folder = generated:WaitForChild("Wildlife")
for _, child in folder:GetChildren() do
	register(child)
end
folder.ChildAdded:Connect(function(child)
	task.defer(register, child)
end)

local interval = 1 / W.UpdateHz
local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated >= interval then
		step(accumulated)
		accumulated = 0
	end
end)
