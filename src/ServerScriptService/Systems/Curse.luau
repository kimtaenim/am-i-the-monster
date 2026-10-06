-- 어느 유물이 저주인지 서버만 기억해요. 클라이언트에는 절대 보내지 않아요.
-- 저주 유물은 절대 사라지거나 주인이 없어지면 안 돼요.
-- (마일스톤 6에서 채워요. 지금은 "아무도 저주가 없다"고만 답해요.)

local Curse = {}

-- 이 고고학자가 지금 저주 유물을 가지고 있나?
function Curse.IsHolder(_who: Instance): boolean
	return false
end

function Curse.Init()
end

return Curse
