-- 서버와 화면(클라이언트)이 서로 말을 주고받는 통로를 모아 둔 곳이에요.
-- 서버가 통로를 만들고, 클라이언트는 만들어질 때까지 기다렸다가 써요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

-- 서버 → 클라이언트, 클라이언트 → 서버 신호 이름들
local EVENT_NAMES = {
	"PhaseChanged", -- 낮/저녁/밤/아침이 바뀜
	"StateUpdate", -- 장작·식량·점수·체력 같은 숫자 갱신
	"InventoryUpdate", -- 내 소지품 목록
	"Notify", -- 화면에 한 줄 알림
	"SleepState", -- 졸음 시작/끝
	"MorningReport", -- 아침 "어젯밤 본 것"
	"TradeOffer", -- 교환 제안
	"TradeRespond", -- 교환 응답
	"VoteCast", -- 투표하기
	"VoteUpdate", -- 투표 현황
	"GhostMessage", -- 유령 메시지 버튼
	"ExpeditionResult", -- 탐사 결과
	"Leaderboard", -- 리더보드
	"UseWeapon", -- 무기 쓰기 (조준한 위치)
	"Narration", -- 화면 가운데 해설 (안개 이야기)
	"Ending", -- 공포 엔딩 연출 (단계, 정보)
}

local Remotes = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local folder = getFolder()
for _, name in EVENT_NAMES do
	if RunService:IsServer() then
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		Remotes[name] = remote
	else
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
