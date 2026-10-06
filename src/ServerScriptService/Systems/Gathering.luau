-- 나무에서 장작을, 정글에서 식량을 줍는 일을 맡아요.
-- 주운 것은 손에 들고 있다가 캠프에 가져가야 창고에 쌓여요.
-- (마일스톤 3에서 마저 채워요. 지금은 "손에 들기"만 있어요.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)

local Gathering = {}

local KIND_LABELS = {
	Food = "🍖 식량",
	Wood = "🪵 장작",
}

-- 손에 든 개수는 플레이어(또는 NPC)에 "CarriedFood", "CarriedWood"로 붙어 있어요
function Gathering.GetCarried(who: Instance, kind: string): number
	return (who:GetAttribute("Carried" .. kind) :: number?) or 0
end

function Gathering.AddCarried(who: Instance, kind: string, amount: number)
	local total = Gathering.GetCarried(who, kind) + amount
	who:SetAttribute("Carried" .. kind, total)
	if who:IsA("Player") then
		Remotes.Notify:FireClient(who, string.format("%s %d개를 주웠어! (들고 있는 것 : %d개)", KIND_LABELS[kind] or kind, amount, total))
	end
end

function Gathering.Init()
end

return Gathering
