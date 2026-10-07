-- NPC가 머리 위 말풍선으로 말하게 해요. 문장은 전부 Dialogue/Lines.luau 에서 골라요.
-- 같은 문장을 최근 5개 안에 다시 쓰지 않고, 채팅창에는 올리지 않아요. (말풍선은 각자 화면이 그려요)
-- 아침에는 NPC마다 자기가 본 것을 근거로 단서를 말하거나, 근거 없이 아무나 의심해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Config)
local GameState = require(ReplicatedStorage.GameState)
local Lines = require(ReplicatedStorage.Dialogue.Lines)
local Remotes = require(ReplicatedStorage.Remotes)
local Systems = ServerScriptService.Systems
local Roster = require(Systems.Roster)
local Curse = require(Systems.Curse)
local Sleep = require(Systems.Sleep)
local NightLog = require(Systems.NightLog)
local Trade = require(Systems.Trade)
local Visibility = require(Systems.Visibility)

local D = Config.Dialogue

local DialogueService = {}

local rng = Random.new()
local recent = {} -- 문장 목록 → 최근에 쓴 문장들
local lastSpoke = 0

----------------------------------------------------------------
-- 한국어 조사 : 이름 끝 받침에 맞춰 이/가, 은/는, 을/를, 과/와
----------------------------------------------------------------

local JOSA = {
	["이"] = { "이", "가" },
	["은"] = { "은", "는" },
	["을"] = { "을", "를" },
	["과"] = { "과", "와" },
}

local function hasBatchim(word: string): boolean?
	local last = nil
	for _, code in utf8.codes(word) do
		last = code
	end
	if last and last >= 0xAC00 and last <= 0xD7A3 then
		return (last - 0xAC00) % 28 ~= 0
	end
	return nil -- 한글이 아니면 모름
end

local function withJosa(word: string, josa: string): string
	local pair = JOSA[josa]
	if not pair then
		return word .. josa
	end
	local batchim = hasBatchim(word)
	if batchim == nil then
		return word .. pair[1] .. "(" .. pair[2] .. ")" -- 영어 이름 등 : 이(가)
	end
	return word .. (batchim and pair[1] or pair[2])
end

-- "{이름:이} 수상해" → "보라가 수상해"
function DialogueService.Fill(template: string, values): string
	return (string.gsub(template, "{([^}:]+):?([^}]*)}", function(key, josa)
		local value = values[key]
		if value == nil then
			return "{" .. key .. "}"
		end
		value = tostring(value)
		if josa ~= "" then
			return withJosa(value, josa)
		end
		return value
	end))
end

-- 최근에 쓴 문장은 빼고 하나 골라요
local function pick(list, filter)
	local memory = recent[list]
	if not memory then
		memory = {}
		recent[list] = memory
	end
	local choices = {}
	for _, line in list do
		if not table.find(memory, line) and (not filter or filter(line)) then
			table.insert(choices, line)
		end
	end
	if #choices == 0 then
		for _, line in list do
			if not filter or filter(line) then
				table.insert(choices, line)
			end
		end
	end
	if #choices == 0 then
		return nil
	end
	local line = choices[rng:NextInteger(1, #choices)]
	table.insert(memory, line)
	if #memory > D.RecentNoRepeat then
		table.remove(memory, 1)
	end
	return line
end

----------------------------------------------------------------
-- 말하기
----------------------------------------------------------------

-- 지금 말할 수 있는 NPC인가? (살아 있고, 깨어 있고, 괴물로 숨어 있지 않음)
local function canSpeak(npc: Instance): boolean
	if npc:IsA("Player") or not npc.Parent or Roster.IsGhost(npc) or Sleep.IsSleeping(npc) then
		return false
	end
	return not Visibility.IsHidden(npc :: Model)
end

function DialogueService.Say(npc: Instance, text: string, force: boolean?)
	if not canSpeak(npc) then
		return
	end
	local now = os.clock()
	if not force and now - lastSpoke < D.MinGapSeconds then
		return
	end
	lastSpoke = now
	Remotes.NpcSay:FireAllClients(npc, text)
end

local function aliveNpcs()
	local list = {}
	for _, who in Roster.GetAlive() do
		if not who:IsA("Player") and canSpeak(who) then
			table.insert(list, who)
		end
	end
	return list
end

local function randomOther(npc: Instance): Instance?
	local others = {}
	for _, who in Roster.GetAlive() do
		if who ~= npc then
			table.insert(others, who)
		end
	end
	return #others > 0 and others[rng:NextInteger(1, #others)] or nil
end

----------------------------------------------------------------
-- 아침 단서
----------------------------------------------------------------

local function needs(line: string, key: string): boolean
	return string.find(line, "{" .. key, 1, true) ~= nil
end

-- 근거 있는 단서 하나 (없으면 nil)
local function clueLine(npc: Instance): string?
	local options = {}
	local seen = NightLog.GetObservation(npc)
	-- 1) 괴물이 나왔을 때 안 보인 사람
	if seen and seen.Awake and #seen.NotSeen > 0 then
		local target = seen.NotSeen[rng:NextInteger(1, #seen.NotSeen)]
		table.insert(options, function()
			local line = pick(Lines.DayClue, function(l)
				return needs(l, "이름") and not needs(l, "장소") and not needs(l, "이름2") and not needs(l, "유물")
			end)
			return line and DialogueService.Fill(line, { ["이름"] = Roster.GetName(target) })
		end)
	end
	-- 2) 괴물이 사라진 곳
	local night = NightLog.GetNight()
	if seen and seen.SawVanish and night and night.VanishPlace then
		table.insert(options, function()
			local line = pick(Lines.DayClue, function(l)
				return needs(l, "장소") and not needs(l, "이름")
			end)
			return line and DialogueService.Fill(line, { ["장소"] = night.VanishPlace })
		end)
	end
	-- 3) 아침에 캠프 밖에 있던 사람
	local outside = {}
	for _, entry in NightLog.GetOutside() do
		if entry.Who ~= npc then
			table.insert(outside, entry)
		end
	end
	if #outside > 0 then
		local entry = outside[rng:NextInteger(1, #outside)]
		table.insert(options, function()
			local line = pick(Lines.DayClue, function(l)
				return needs(l, "이름") and needs(l, "장소")
			end)
			return line and DialogueService.Fill(line, { ["이름"] = Roster.GetName(entry.Who), ["장소"] = entry.Place })
		end)
	end
	-- 4) 어제 저녁 교환
	local trades = NightLog.GetLastTrades()
	if #trades > 0 then
		local record = trades[rng:NextInteger(1, #trades)]
		table.insert(options, function()
			local line = pick(Lines.DayClue, function(l)
				return needs(l, "이름2")
			end)
			-- 유물 글자에서 그림을 빼고 이름만 ("🪞 거울" → "거울")
			local itemName = string.match(record.Gave, "%s(.+)$") or record.Gave
			return line and DialogueService.Fill(line, { ["이름"] = record.From, ["이름2"] = record.To, ["유물"] = itemName })
		end)
	end
	if #options == 0 then
		return nil
	end
	return options[rng:NextInteger(1, #options)]()
end

local function morningLine(npc: Instance): string?
	-- 엉뚱한 곳에서 깨어난 사람 : 어리둥절 (저주 NPC가 더 자주, 캠프 밖에서 깬 다른 NPC도 가끔)
	if Sleep.IsConfused(npc) and Curse.IsHolder(npc) and rng:NextNumber() < D.CursedExcuseChance then
		return pick(Lines.CursedExcuse)
	end
	for _, entry in NightLog.GetOutside() do
		if entry.Who == npc and not Curse.IsHolder(npc) and rng:NextNumber() < D.OutsideExcuseChance then
			return pick(Lines.CursedExcuse)
		end
	end
	if rng:NextNumber() < D.ClueChance then
		local line = clueLine(npc)
		if line then
			return line
		end
	end
	-- 근거 없이 아무나 의심하기 (저주 보유자도 똑같은 확률)
	local target = randomOther(npc)
	local line = target and pick(Lines.DayRedHerring)
	return line and DialogueService.Fill(line, { ["이름"] = Roster.GetName(target) })
end

-- 아침 : NPC마다 한마디씩, 시간을 나눠서
function DialogueService.MorningTalk()
	local latest = Config.Time.MorningSeconds * D.MorningTalkLatestFraction
	for _, npc in aliveNpcs() do
		task.delay(rng:NextNumber(D.MorningTalkEarliest, latest) / Config.Time.TestSpeed, function()
			if GameState.Get("Phase") ~= "Morning" then
				return
			end
			local line = morningLine(npc)
			if line then
				DialogueService.Say(npc, line, true)
			end
		end)
	end
end

----------------------------------------------------------------
-- 그 밖의 때
----------------------------------------------------------------

-- 하루의 흐름 : moment = "Start" / "Day" / "Evening" / "Morning"
function DialogueService.RoundFlow(moment: string, day: number)
	local speakers = aliveNpcs()
	for _ = 1, math.min(D.RoundFlowSpeakers, #speakers) do
		local npc = table.remove(speakers, rng:NextInteger(1, #speakers))
		local list = Lines.RoundFlow[moment]
		if moment == "Day" and day > 1 and rng:NextNumber() < D.RoundFlowLaterChance then
			list = Lines.RoundFlow.Later
		end
		local line = list and pick(list)
		if line then
			task.delay(rng:NextNumber(0, D.RoundFlowDelayMax), function()
				DialogueService.Say(npc, DialogueService.Fill(line, { ["날"] = day }), true)
			end)
		end
	end
end

-- 유물·장작·식량을 챙겼을 때 가끔 수다
function DialogueService.MaybeDigChat(npc: Instance)
	if rng:NextNumber() < D.DigChatChance then
		local line = pick(Lines.DigChat)
		if line then
			DialogueService.Say(npc, line)
		end
	end
end

-- 저녁·밤 분위기 : 가끔 누군가 한마디
local function moodLoop()
	while true do
		task.wait(D.NightMoodSeconds / Config.Time.TestSpeed)
		local phase = GameState.Get("Phase")
		if (phase == "Night" or phase == "Evening") and rng:NextNumber() < D.NightMoodChance then
			local speakers = aliveNpcs()
			if #speakers > 0 then
				local line = pick(Lines.NightMood)
				if line then
					DialogueService.Say(speakers[rng:NextInteger(1, #speakers)], line)
				end
			end
		end
	end
end

function DialogueService.Init()
	Trade.Proposed:Connect(function(from)
		if not from:IsA("Player") then
			local line = pick(Lines.TradeTalk.Offer)
			if line then
				DialogueService.Say(from, line, true)
			end
		end
	end)
	Trade.Answered:Connect(function(to, accepted)
		if not to:IsA("Player") then
			local line = pick(accepted and Lines.TradeTalk.Accept or Lines.TradeTalk.Reject)
			if line then
				DialogueService.Say(to, line, true)
			end
		end
	end)
	task.spawn(moodLoop)
end

return DialogueService
