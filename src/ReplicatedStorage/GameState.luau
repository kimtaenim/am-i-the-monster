-- 모두가 볼 수 있는 게임 상태(지금 낮인지 밤인지, 며칠째인지, 장작·식량 수)를 담아 둬요.
-- 서버만 바꿀 수 있고, 화면(클라이언트)은 읽기만 해요.
-- 비밀(저주 유물, 저주 보유자)은 절대 여기에 넣지 않아요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAME = "GameState"

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild(NAME)
	if not folder then
		folder = Instance.new("Configuration")
		folder.Name = NAME
		folder:SetAttribute("Phase", "Waiting")
		folder:SetAttribute("Day", 0)
		folder:SetAttribute("PhaseEndsAt", 0)
		folder:SetAttribute("Wood", 0)
		folder:SetAttribute("Food", 0)
		folder:SetAttribute("Expedition", 0)
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild(NAME)
end

local GameState = {}
GameState.Folder = folder

function GameState.Get(key: string)
	return folder:GetAttribute(key)
end

function GameState.Set(key: string, value)
	folder:SetAttribute(key, value)
end

function GameState.Changed(key: string)
	return folder:GetAttributeChangedSignal(key)
end

-- 낮/저녁/밤/아침 한국어 이름과 그림
GameState.PhaseInfo = {
	Waiting = { Name = "준비 중", Icon = "⏳" },
	Day = { Name = "낮", Icon = "☀️" },
	Evening = { Name = "저녁", Icon = "🌇" },
	Night = { Name = "밤", Icon = "🌙" },
	Morning = { Name = "아침", Icon = "🌅" },
	Result = { Name = "탐사 끝", Icon = "🏁" },
	Ending = { Name = "공포의 밤", Icon = "👹" },
}

return GameState
