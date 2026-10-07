-- 단서 "동물들의 반응" : 저주 보유자 가까이에서는 새가 푸드득 날아가고 사냥감이 더 멀리서 도망쳐요.
-- 가끔은 다른 사람 근처에서도 그래요. 그래서 한 번 봤다고 확신하면 안 되고, 여러 번 지켜봐야 해요.
-- 화면에는 "이 위치 근처 동물이 놀랐어"만 보내요. 누구 때문인지는 보내지 않아요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Config)
local GameState = require(ReplicatedStorage.GameState)
local Remotes = require(ReplicatedStorage.Remotes)
local Systems = ServerScriptService.Systems
local Roster = require(Systems.Roster)
local Curse = require(Systems.Curse)

local CLUE = Config.Clue
local ACTIVE_PHASES = { Day = true, Evening = true, Morning = true }

local Omens = {}

local rng = Random.new()
local frightenUntil = {} -- 고고학자 → 이 시각까지 사냥감이 더 멀리서 도망쳐요

local function startle(who: Instance)
	local root = Roster.GetRoot(who)
	if not root then
		return
	end
	frightenUntil[who] = os.clock() + CLUE.OmenSeconds / Config.Time.TestSpeed
	Remotes.AnimalStartle:FireAllClients(root.Position)
end

-- 사냥감이 이 사람을 얼마나 무서워하나 (Hunting이 써요)
function Omens.GetFearScale(who: Instance): number
	local untilTime = frightenUntil[who]
	if untilTime and os.clock() < untilTime then
		return CLUE.PreyFearMultiplier
	end
	return 1
end

local function tick()
	if not ACTIVE_PHASES[GameState.Get("Phase")] then
		return
	end
	local holder = Curse.GetHolder()
	if holder and not Roster.IsGhost(holder) and rng:NextNumber() < CLUE.OmenChance then
		startle(holder)
	end
	-- 헷갈리게 : 다른 사람 근처에서도 가끔
	if rng:NextNumber() < CLUE.OmenNoiseChance then
		local others = {}
		for _, who in Roster.GetAlive() do
			if who ~= holder then
				table.insert(others, who)
			end
		end
		if #others > 0 then
			startle(others[rng:NextInteger(1, #others)])
		end
	end
end

function Omens.Init()
	task.spawn(function()
		while true do
			task.wait(CLUE.OmenSeconds / Config.Time.TestSpeed)
			tick()
		end
	end)
	Roster.Left:Connect(function(who)
		frightenUntil[who] = nil
	end)
end

return Omens
