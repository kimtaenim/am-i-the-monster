-- 유물 12종의 이름, 색깔, 그림(이모지)을 적어 둔 곳이에요.
-- 겉모습만 다르고 게임에서 하는 일은 모두 같아요.
-- 여기에는 "저주" 정보가 없어요. 저주는 서버만 알아요.

local ArtifactDefs = {}

ArtifactDefs.List = {
	{ Id = "Mask", Name = "가면", Icon = "🎭", Color = Color3.fromRGB(200, 160, 70) },
	{ Id = "Figurine", Name = "조각상", Icon = "🗿", Color = Color3.fromRGB(140, 135, 120) },
	{ Id = "Ring", Name = "반지", Icon = "💍", Color = Color3.fromRGB(230, 200, 90) },
	{ Id = "Scroll", Name = "두루마리", Icon = "📜", Color = Color3.fromRGB(225, 205, 160) },
	{ Id = "Dagger", Name = "단검", Icon = "🗡️", Color = Color3.fromRGB(170, 170, 180) },
	{ Id = "Mirror", Name = "거울", Icon = "🪞", Color = Color3.fromRGB(180, 210, 220) },
	{ Id = "Bell", Name = "방울", Icon = "🔔", Color = Color3.fromRGB(210, 170, 60) },
	{ Id = "Orb", Name = "구슬", Icon = "🔮", Color = Color3.fromRGB(150, 110, 200) },
	{ Id = "Tablet", Name = "석판", Icon = "🪨", Color = Color3.fromRGB(120, 115, 105) },
	{ Id = "Crown", Name = "왕관", Icon = "👑", Color = Color3.fromRGB(240, 200, 50) },
	{ Id = "Pottery", Name = "토기", Icon = "🏺", Color = Color3.fromRGB(180, 100, 60) },
	{ Id = "Amulet", Name = "부적", Icon = "🧿", Color = Color3.fromRGB(60, 120, 200) },
}

-- Id로 빨리 찾을 수 있게 표를 하나 더 만들어요
ArtifactDefs.ById = {}
for _, def in ArtifactDefs.List do
	ArtifactDefs.ById[def.Id] = def
end

-- 유물 종류 하나를 무작위로 골라요
function ArtifactDefs.RandomId(rng: Random): string
	return ArtifactDefs.List[rng:NextInteger(1, #ArtifactDefs.List)].Id
end

return ArtifactDefs
