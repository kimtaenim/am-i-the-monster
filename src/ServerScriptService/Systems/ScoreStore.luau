-- 발굴 점수와 범인 맞힌 횟수를 저장해요. (DataStore) 탐사가 끝나도 계속 쌓여요.
-- 저장에 실패하면 몇 번 다시 시도해요. Studio에서 API 접근이 꺼져 있으면 경고만 하고 저장 없이 진행해요.
-- 화면 오른쪽 위 순위표(leaderstats)에도 점수가 보여요.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config)

local SAVE = Config.Save
local SCORE_NAME = "점수"
local HITS_NAME = "범인맞힘"

local ScoreStore = {}

local store = nil -- DataStore (못 쓰면 nil)
local enabled = true
local data = {} -- 플레이어 → { Score, CulpritHits }

local function keyOf(player: Player): string
	return "player_" .. player.UserId
end

-- 여러 번 시도하기. API가 꺼져 있으면 바로 포기해요
local function tryAsync(label: string, fn)
	if not enabled then
		return false, nil
	end
	for attempt = 1, SAVE.Retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		local message = tostring(result)
		if string.find(message, "Studio") or string.find(message, "403") then
			warn("[ScoreStore] Studio에서 DataStore가 꺼져 있어요. 점수는 저장되지 않고 진행해요. (게임 설정 → 보안 → API 서비스 허용)")
			enabled = false
			return false, nil
		end
		warn(string.format("[ScoreStore] %s 실패 (%d/%d): %s", label, attempt, SAVE.Retries, message))
		task.wait(SAVE.RetryWaitSeconds)
	end
	return false, nil
end

local function refreshStats(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	local entry = data[player]
	if stats and entry then
		stats[SCORE_NAME].Value = entry.Score
		stats[HITS_NAME].Value = entry.CulpritHits
	end
end

local function load(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local hits = Instance.new("IntValue")
	hits.Name = HITS_NAME
	hits.Parent = stats
	local score = Instance.new("IntValue")
	score.Name = SCORE_NAME
	score.Parent = stats
	stats.Parent = player

	data[player] = { Score = 0, CulpritHits = 0 }
	if store then
		local ok, saved = tryAsync("불러오기", function()
			return store:GetAsync(keyOf(player))
		end)
		if ok and type(saved) == "table" and data[player] then
			data[player].Score = tonumber(saved.Score) or 0
			data[player].CulpritHits = tonumber(saved.CulpritHits) or 0
		end
	end
	refreshStats(player)
end

local function save(player: Player)
	local entry = data[player]
	if not store or not entry then
		return
	end
	tryAsync("저장", function()
		store:SetAsync(keyOf(player), { Score = entry.Score, CulpritHits = entry.CulpritHits })
	end)
end

-- 점수 더하기 (NPC는 저장하지 않아요)
function ScoreStore.AddScore(who: Instance, amount: number)
	if not who:IsA("Player") or not data[who] then
		return
	end
	data[who].Score += amount
	refreshStats(who)
end

function ScoreStore.AddCulpritHit(who: Instance)
	if not who:IsA("Player") or not data[who] then
		return
	end
	data[who].CulpritHits += 1
	refreshStats(who)
end

function ScoreStore.Get(player: Player)
	return data[player]
end

function ScoreStore.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(SAVE.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[ScoreStore] DataStore를 열 수 없어요. 점수는 저장되지 않고 진행해요:", result)
		enabled = false
	end

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		data[player] = nil
	end)

	-- 가끔 자동 저장
	task.spawn(function()
		while true do
			task.wait(SAVE.AutoSaveSeconds)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)

	-- 서버가 꺼질 때 모두 저장
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)
end

return ScoreStore
