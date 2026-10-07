-- 괴물이 이기면 나오는 공포 엔딩이에요. (생존자 3명 이하, 모닥불 꺼짐, 7일 동안 범인을 못 찾음)
-- 모두가 멈추고, 괴물의 정체와 저주 유물이 밝혀지고, 괴물이 남은 사람들을 차례로 잡아요.
-- 잡힌 사람은 화면이 하얗게 번쩍이고 유령이 돼요. 피나 잔인한 장면은 없어요.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ArtifactDefs = require(ReplicatedStorage.ArtifactDefs)
local Config = require(ReplicatedStorage.Config)
local Lines = require(ReplicatedStorage.Dialogue.Lines)
local Remotes = require(ReplicatedStorage.Remotes)
local Systems = ServerScriptService.Systems
local Roster = require(Systems.Roster)
local Curse = require(Systems.Curse)
local Health = require(Systems.Health)
local Monster = require(Systems.Monster)
local GameLoop = require(Systems.GameLoop)
local Sleep = require(Systems.Sleep)

local E = Config.Ending
local TEXT = Lines.HorrorEnding

local Ending = {}

local rng = Random.new()
local monsterModel: Model? = nil
local frozen = {} -- 멈춘 몸들 (Root 파츠)
local hiddenParts = {} -- 괴물로 변하며 숨긴 파츠 → 원래 투명도
local tint: ColorCorrectionEffect? = nil

local function fill(template: string, name: string?, artifact: string?): string
	local result = string.gsub(template, "{이름}", name or "")
	result = string.gsub(result, "{유물}", artifact or "")
	return result
end

local function groundUnder(root: BasePart): CFrame
	local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local height = humanoid and (humanoid.HipHeight + root.Size.Y / 2) or root.Size.Y
	local look = root.CFrame.LookVector
	local feet = root.Position - Vector3.new(0, height, 0)
	return CFrame.lookAt(feet, feet + Vector3.new(look.X, 0, look.Z))
end

-- 모두 그 자리에 멈춰요
local function freezeEveryone()
	for _, who in Roster.GetAll() do
		local root = Roster.GetRoot(who)
		if root and not root.Anchored then
			root.Anchored = true
			table.insert(frozen, root)
		end
	end
end

-- 괴물이 한 사람에게 순식간에 다가가요
local function dashTo(model: Model, target: Vector3)
	local from = model:GetPivot()
	local flatTarget = Vector3.new(target.X, from.Position.Y, target.Z)
	local direction = flatTarget - from.Position
	if direction.Magnitude < 0.1 then
		return
	end
	local stop = flatTarget - direction.Unit * E.CatchOffset
	local goal = CFrame.lookAt(stop, flatTarget)
	local value = Instance.new("CFrameValue")
	value.Value = from
	local connection = value.Changed:Connect(function(cf)
		model:PivotTo(cf)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(E.DashSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = goal })
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	value:Destroy()
	model:PivotTo(goal)
end

-- 공포 엔딩 연출 (GameLoop가 결과 화면 전에 불러요)
function Ending.PlayHorror()
	Sleep.WakeAll() -- 졸던 사람은 깨우고, 돌아다니던 괴물은 사라져요
	-- 괴물의 정체 : 저주 보유자 (아직 없으면 지금 정해요)
	Curse.Designate()
	local item, holder = Curse.GetCursedItem()
	if not holder or Roster.IsGhost(holder) then
		local alive = Roster.GetAlive()
		holder = #alive > 0 and alive[rng:NextInteger(1, #alive)] or nil
	end
	if not holder then
		return
	end
	local holderName = Roster.GetName(holder)
	local def = item and ArtifactDefs.ById[item.TypeId]
	local artifactText = def and (def.Icon .. " " .. def.Name) or "???"

	local total = E.IntroSeconds + E.RevealSeconds + E.TransformSeconds + E.FinalSeconds
	GameLoop.SetSpecialPhase("Ending", total + #Roster.GetAlive() * (E.DashSeconds + E.CatchPauseSeconds))
	freezeEveryone()

	-- 붉고 어두운 화면
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "EndingTint"
	effect.TintColor = E.TintColor
	effect.Brightness = E.TintBrightness
	effect.Saturation = E.TintSaturation
	effect.Parent = Lighting
	tint = effect

	-- 1) 해설
	Remotes.Ending:FireAllClients("Intro", { Text = TEXT.Intro })
	task.wait(E.IntroSeconds)

	-- 2) 정체 공개
	Remotes.Ending:FireAllClients("Reveal", {
		Text = fill(TEXT.Reveal, holderName),
		Sub = fill(TEXT.Artifact, nil, artifactText),
	})
	task.wait(E.RevealSeconds)

	-- 3) 괴물로 변해요 : 사람 모습은 숨기고 그 자리에 그림자 괴물
	local holderRoot = Roster.GetRoot(holder)
	if not holderRoot then
		return
	end
	local character = Roster.GetCharacter(holder)
	if character then
		for _, p in character:GetDescendants() do
			if p:IsA("BasePart") or p:IsA("Decal") then
				hiddenParts[p] = p.Transparency
				p.Transparency = 1
			elseif p:IsA("BillboardGui") then
				p.Enabled = false
			end
		end
	end
	local monster = Monster.BuildShadow(groundUnder(holderRoot))
	monster.Parent = Workspace
	monsterModel = monster
	Remotes.Ending:FireAllClients("Transform", {
		Text = fill(TEXT.Transform, holderName),
		Focus = monster.PrimaryPart,
	})
	task.wait(E.TransformSeconds)

	-- 4) 남은 사람들을 가까운 순서로 차례차례
	local victims = {}
	for _, who in Roster.GetAlive() do
		if who ~= holder then
			table.insert(victims, who)
		end
	end
	while #victims > 0 do
		local here = monster:GetPivot().Position
		table.sort(victims, function(a, b)
			local ra, rb = Roster.GetRoot(a), Roster.GetRoot(b)
			local da = ra and (ra.Position - here).Magnitude or math.huge
			local db = rb and (rb.Position - here).Magnitude or math.huge
			return da < db
		end)
		local victim = table.remove(victims, 1)
		local root = Roster.GetRoot(victim)
		if root then
			dashTo(monster, root.Position)
		end
		Health.MakeGhost(victim, "Monster", true)
		Remotes.Ending:FireAllClients("Catch", { Text = fill(TEXT.Catch, Roster.GetName(victim)) })
		task.wait(E.CatchPauseSeconds)
	end

	-- 5) 마지막 해설
	Remotes.Ending:FireAllClients("Final", { Text = TEXT.Final })
	task.wait(E.FinalSeconds)
end

-- 새 탐사 : 엔딩 흔적을 모두 치워요
function Ending.Cleanup()
	for _, root in frozen do
		if root.Parent then
			root.Anchored = false
		end
	end
	table.clear(frozen)
	for p, transparency in hiddenParts do
		if p.Parent then
			p.Transparency = transparency
		end
	end
	table.clear(hiddenParts)
	for _, who in Roster.GetAll() do
		local character = Roster.GetCharacter(who)
		if character then
			for _, gui in character:GetDescendants() do
				if gui:IsA("BillboardGui") then
					gui.Enabled = true
				end
			end
		end
	end
	if monsterModel then
		monsterModel:Destroy()
		monsterModel = nil
	end
	if tint then
		tint:Destroy()
		tint = nil
	end
	Remotes.Ending:FireAllClients("Clear", {})
end

function Ending.Init()
	-- Studio 테스트용 : 명령 창에서 game.ServerStorage.TestHorrorEnding:Fire() 하면 공포 엔딩을 바로 볼 수 있어요
	if RunService:IsStudio() then
		local test = Instance.new("BindableEvent")
		test.Name = "TestHorrorEnding"
		test.Parent = ServerStorage
		test.Event:Connect(function()
			GameLoop.EndExpedition("Monster", "테스트 공포 엔딩", Ending.PlayHorror)
		end)
	end
end

return Ending
