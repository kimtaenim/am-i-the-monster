-- 어느 유물이 저주인지 서버만 기억해요. 클라이언트에는 절대 보내지 않아요. (공개는 탐사가 끝날 때만)
-- 첫날 저녁, 사람들이 캔 유물 중 하나를 저주 유물로 정해요. 저주는 유물을 따라다녀요.
-- 저주 유물은 번호(Uid)로만 기억해서 교환·유언으로 주인이 바뀌어도 그대로 따라가요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Systems = ServerScriptService.Systems
local Roster = require(Systems.Roster)
local Inventory = require(Systems.Inventory)
local Signal = require(ReplicatedStorage.Signal)

local Curse = {}

Curse.Designated = Signal.new() -- (item) 저주 유물이 정해졌어요 (서버 안에서만)

local rng = Random.new()
local cursedUid: number? = nil

-- 살아 있는 사람들이 가진 유물 중 하나를 저주로 정해요 (이미 정했으면 그대로)
function Curse.Designate(): boolean
	if cursedUid then
		return true
	end
	local candidates = {}
	for _, who in Roster.GetAlive() do
		for _, item in Inventory.Get(who) do
			table.insert(candidates, item)
		end
	end
	if #candidates == 0 then
		return false
	end
	local item = candidates[rng:NextInteger(1, #candidates)]
	cursedUid = item.Uid
	Curse.Designated:Fire(item)
	return true
end

function Curse.IsDesignated(): boolean
	return cursedUid ~= nil
end

-- 저주 유물과 그 주인
function Curse.GetCursedItem()
	if not cursedUid then
		return nil, nil
	end
	local owner, item = Inventory.FindOwner(cursedUid)
	return item, owner
end

function Curse.GetHolder(): Instance?
	local _, owner = Curse.GetCursedItem()
	return owner
end

-- 이 고고학자가 지금 저주 유물을 가지고 있나?
function Curse.IsHolder(who: Instance): boolean
	return cursedUid ~= nil and Curse.GetHolder() == who
end

-- 새 탐사 : 저주를 지워요 (새 저주는 첫날 저녁에)
function Curse.Reset()
	cursedUid = nil
end

function Curse.Init()
	-- Studio 테스트용 (진짜 서버에서는 만들지 않아요)
	--   print(game.ServerStorage.WhoIsCursed:Invoke())   → 지금 저주 보유자 이름
	--   game.ServerStorage.MakeMeCursed:Fire()           → 첫 번째 플레이어가 저주 보유자가 돼요
	if RunService:IsStudio() then
		local who = Instance.new("BindableFunction")
		who.Name = "WhoIsCursed"
		who.OnInvoke = function()
			local holder = Curse.GetHolder()
			return holder and Roster.GetName(holder) or "아직 정해지지 않았어요 (첫날 저녁에 정해져요)"
		end
		who.Parent = ServerStorage

		local makeMe = Instance.new("BindableEvent")
		makeMe.Name = "MakeMeCursed"
		makeMe.Event:Connect(function()
			local player = Players:GetPlayers()[1]
			if not player then
				return
			end
			local items = Inventory.Get(player)
			local item = items[1] or Inventory.Add(player, "Mask", { Day = 0 })
			cursedUid = item.Uid
			print("[Curse] 테스트 : 이제", player.DisplayName, "이(가) 저주 보유자예요")
		end)
		makeMe.Parent = ServerStorage
	end
end

return Curse
