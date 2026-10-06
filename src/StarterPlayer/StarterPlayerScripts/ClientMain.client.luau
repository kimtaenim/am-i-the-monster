-- 내 화면(클라이언트)에서 제일 먼저 실행돼요.
-- 화면 UI와 소리를 준비해요. 판정은 전부 서버가 하고, 여기선 보여주기만 해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)

-- 서버가 보내는 한 줄 알림 (마일스톤 2부터 화면에 띄워요)
Remotes.Notify.OnClientEvent:Connect(function(text: string)
	print("[알림]", text)
end)
