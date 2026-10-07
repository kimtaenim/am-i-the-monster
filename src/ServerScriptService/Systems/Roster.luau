-- 고고학자 명단이에요. 고고학자는 플레이어일 수도, NPC일 수도 있어요.
-- 다른 시스템은 "누구"를 플레이어/NPC 구분 없이 여기서 물어봐요. (이름, 몸, 살아 있는지)
-- (마일스톤 4에서 NPC와 드롭인 교대를 더해요.)

local Players = game:GetService("Players")

local Signal = require(game:GetService("ReplicatedStorage").Signal)

local Roster = {}

Roster.Joined = Signal.new() -- (who) 새 고고학자가 들어왔어요
Roster.Left = Signal.new() -- (who) 고고학자가 떠나요 (아직 정보가 남아 있을 때 불려요)

local npcs = {} -- NPC 모델들
local nextId = 0

-- 고고학자마다 번호를 붙여요 (교환 상대를 고를 때 화면이 이 번호로 알려줘요)
local function giveId(who: Instance)
	if who:GetAttribute("ArchId") == nil then
		nextId += 1
		who:SetAttribute("ArchId", nextId)
	end
end

-- 번호로 고고학자 찾기
function Roster.FromId(id: number): Instance?
	for _, who in Roster.GetAll() do
		if who:GetAttribute("ArchId") == id then
			return who
		end
	end
	return nil
end

-- 모든 고고학자 (유령 포함)
function Roster.GetAll()
	local list = {}
	for _, player in Players:GetPlayers() do
		table.insert(list, player)
	end
	for _, npc in npcs do
		table.insert(list, npc)
	end
	return list
end

function Roster.IsGhost(who: Instance): boolean
	return who:GetAttribute("Ghost") == true
end

-- 살아 있는 고고학자만
function Roster.GetAlive()
	local list = {}
	for _, who in Roster.GetAll() do
		if not Roster.IsGhost(who) then
			table.insert(list, who)
		end
	end
	return list
end

function Roster.GetName(who: Instance): string
	if who:IsA("Player") then
		return who.DisplayName
	end
	return (who:GetAttribute("DisplayName") :: string?) or who.Name
end

-- 게임 속 몸 (플레이어는 Character, NPC는 모델 자신)
function Roster.GetCharacter(who: Instance): Model?
	if who:IsA("Player") then
		return who.Character
	end
	return who :: Model
end

function Roster.GetRoot(who: Instance): BasePart?
	local character = Roster.GetCharacter(who)
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- 몸의 주인이 누구인지 (프롬프트를 누른 플레이어 등)
function Roster.FromCharacter(character: Instance): Instance?
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		return player
	end
	if table.find(npcs, character) then
		return character
	end
	return nil
end

function Roster.AddNpc(model: Model)
	giveId(model)
	table.insert(npcs, model)
	Roster.Joined:Fire(model)
end

function Roster.RemoveNpc(model: Model)
	local index = table.find(npcs, model)
	if index then
		Roster.Left:Fire(model)
		table.remove(npcs, index)
	end
end

function Roster.Init()
	Players.PlayerAdded:Connect(function(player)
		giveId(player)
		Roster.Joined:Fire(player)
	end)
	for _, player in Players:GetPlayers() do
		giveId(player)
		Roster.Joined:Fire(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		Roster.Left:Fire(player)
	end)
end

return Roster
