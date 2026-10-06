-- 누가 어떤 유물을 가졌는지 기억해요. 버리기는 없어요. 유물이 손을 떠나는 길은 교환과 유언뿐이에요.
-- 화면(클라이언트)에는 내 유물의 번호와 종류만 보내요. 저주 여부는 여기 없어요 (Curse가 따로 기억해요).
-- 고고학자가 쓰러지거나 떠나면 유물을 살아 있는 사람들에게 나눠 줘요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Remotes)
local Signal = require(ReplicatedStorage.Signal)
local Roster = require(ServerScriptService.Systems.Roster)

local Inventory = {}

Inventory.Moved = Signal.new() -- (item, from, to, reason) 유물이 다른 사람에게 갔어요

local itemsByOwner = {} -- 주인 → { item, ... }
local nextUid = 0
local rng = Random.new()

local function listOf(who: Instance)
	local list = itemsByOwner[who]
	if not list then
		list = {}
		itemsByOwner[who] = list
	end
	return list
end

-- 플레이어 화면에 내 소지품 목록을 보내요 (번호와 종류만)
function Inventory.Sync(who: Instance)
	if not who:IsA("Player") then
		return
	end
	local list = {}
	for _, item in listOf(who) do
		table.insert(list, { Uid = item.Uid, TypeId = item.TypeId })
	end
	Remotes.InventoryUpdate:FireClient(who, list)
end

-- 새 유물 (발굴)
function Inventory.Add(who: Instance, typeId: string, meta)
	nextUid += 1
	local item = {
		Uid = nextUid,
		TypeId = typeId,
		FoundBy = who,
		FoundDay = meta and meta.Day,
		RuinId = meta and meta.RuinId,
	}
	table.insert(listOf(who), item)
	Inventory.Sync(who)
	return item
end

function Inventory.Get(who: Instance)
	return listOf(who)
end

function Inventory.FindOwner(uid: number): (Instance?, any)
	for owner, list in itemsByOwner do
		for _, item in list do
			if item.Uid == uid then
				return owner, item
			end
		end
	end
	return nil, nil
end

-- 유물 하나를 다른 사람에게 옮겨요 (교환, 유언)
function Inventory.Transfer(uid: number, to: Instance, reason: string)
	local from, item = Inventory.FindOwner(uid)
	if not from or not item then
		return false
	end
	local fromList = listOf(from)
	table.remove(fromList, table.find(fromList, item))
	table.insert(listOf(to), item)
	Inventory.Sync(from)
	Inventory.Sync(to)
	Inventory.Moved:Fire(item, from, to, reason)
	return true
end

-- 쓰러지거나 떠나는 사람의 유물을 살아 있는 사람들에게 골고루 나눠요 (유언)
-- 받은 사람 목록을 돌려줘요 : { { Item, To } }
function Inventory.DistributeWill(who: Instance, reason: string)
	local heirs = {}
	for _, other in Roster.GetAlive() do
		if other ~= who then
			table.insert(heirs, other)
		end
	end
	local given = {}
	if #heirs == 0 then
		return given -- 받을 사람이 없으면 그대로 둬요 (탐사가 곧 끝나요)
	end
	-- 받을 사람 순서를 섞어서 차례로 하나씩
	for i = #heirs, 2, -1 do
		local j = rng:NextInteger(1, i)
		heirs[i], heirs[j] = heirs[j], heirs[i]
	end
	local items = table.clone(listOf(who))
	for index, item in items do
		local heir = heirs[(index - 1) % #heirs + 1]
		Inventory.Transfer(item.Uid, heir, reason)
		table.insert(given, { Item = item, To = heir })
	end
	return given
end

-- 새 탐사 : 모두 빈손
function Inventory.Reset()
	table.clear(itemsByOwner)
	for _, player in Players:GetPlayers() do
		Inventory.Sync(player)
	end
end

function Inventory.Init()
	Roster.Joined:Connect(function(who)
		Inventory.Sync(who)
	end)
	Roster.Left:Connect(function(who)
		-- 떠나는 사람의 짐은 남은 사람에게 맡겨요
		Inventory.DistributeWill(who, "Left")
		itemsByOwner[who] = nil
	end)
end

return Inventory
