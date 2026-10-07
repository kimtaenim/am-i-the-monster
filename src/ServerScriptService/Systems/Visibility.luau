-- 고고학자의 몸을 잠깐 투명하게 숨겼다가 다시 보이게 해요.
-- 저주 보유자가 괴물이 되는 동안 원래 몸은 이렇게 숨어 있어요. (부딪히지도 않아요)

local Visibility = {}

local saved = {} -- 몸(모델) → { [인스턴스] = 원래 값 }

function Visibility.Hide(character: Model)
	if saved[character] then
		return
	end
	local memory = {}
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") then
			memory[item] = { Transparency = item.Transparency, CanCollide = item.CanCollide }
			item.Transparency = 1
			item.CanCollide = false
		elseif item:IsA("Decal") then
			memory[item] = { Transparency = item.Transparency }
			item.Transparency = 1
		elseif item:IsA("BillboardGui") then
			memory[item] = { Enabled = item.Enabled }
			item.Enabled = false
		end
	end
	saved[character] = memory
end

function Visibility.Show(character: Model)
	local memory = saved[character]
	if not memory then
		return
	end
	for item, values in memory do
		if item.Parent then
			for key, value in values do
				item[key] = value
			end
		end
	end
	saved[character] = nil
end

function Visibility.IsHidden(character: Model): boolean
	return saved[character] ~= nil
end

return Visibility
