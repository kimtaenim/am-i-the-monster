-- 저녁에 유물을 1:1로 바꾸는 일을 맡아요. 내가 유물 하나를 내밀면, 상대가 받아 주면서 자기 유물 하나를 골라 줘요.
-- 저주는 유물을 따라가요. "혹시 내가 괴물?" 싶은 사람은 바꾸고 싶겠지만, 교환 기록은 다음 날 아침 모두에게 공개돼요.
-- NPC는 받은 제안을 70% 확률로 받아 주고, 저녁마다 한 번 누군가에게 먼저 제안해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtifactDefs = require(ReplicatedStorage.ArtifactDefs)
local Config = require(ReplicatedStorage.Config)
local GameState = require(ReplicatedStorage.GameState)
local Remotes = require(ReplicatedStorage.Remotes)
local Systems = ServerScriptService.Systems
local Roster = require(Systems.Roster)
local Inventory = require(Systems.Inventory)
local Signal = require(ReplicatedStorage.Signal)

local TRADE = Config.Trade

local Trade = {}

Trade.Proposed = Signal.new() -- (from, to) 누가 누구에게 제안했어요 (NPC 말풍선용)
Trade.Answered = Signal.new() -- (to, accepted) 받은 사람이 대답했어요

local rng = Random.new()
local nextOfferId = 0
local offers = {} -- 제안 번호 → { Id, From, To, FromUid, Expires }
local lastPropose = {} -- 플레이어 → 마지막 제안 시각
local log = {} -- 지난 저녁 교환 기록 (아침 보고서용) { From, To, Gave, Got }

local function itemText(typeId: string): string
	local def = ArtifactDefs.ById[typeId]
	return def and (def.Icon .. " " .. def.Name) or typeId
end

local function tell(who: Instance, text: string)
	if who:IsA("Player") then
		Remotes.Notify:FireClient(who, text)
	end
end

local function isEvening(): boolean
	return GameState.Get("Phase") == "Evening"
end

local function offerFrom(who: Instance)
	for _, offer in offers do
		if offer.From == who then
			return offer
		end
	end
	return nil
end

local function offerTo(who: Instance)
	for _, offer in offers do
		if offer.To == who then
			return offer
		end
	end
	return nil
end

local function owns(who: Instance, uid: number): boolean
	local owner = Inventory.FindOwner(uid)
	return owner == who
end

----------------------------------------------------------------
-- 교환 끝내기
----------------------------------------------------------------

local function closeOffer(offer, reasonForProposer: string?)
	offers[offer.Id] = nil
	if reasonForProposer then
		tell(offer.From, reasonForProposer)
	end
	if offer.To:IsA("Player") then
		Remotes.TradeOffer:FireClient(offer.To, "Closed", { OfferId = offer.Id })
	end
end

local function complete(offer, toUid: number)
	local from, to = offer.From, offer.To
	-- 그사이에 유물 주인이 바뀌었으면 취소
	if not owns(from, offer.FromUid) or not owns(to, toUid) then
		closeOffer(offer, "🔄 교환이 취소됐어. (유물이 이미 다른 데 가 있었어)")
		return
	end
	local _, gave = Inventory.FindOwner(offer.FromUid)
	local _, got = Inventory.FindOwner(toUid)
	Inventory.Transfer(offer.FromUid, to, "Trade")
	Inventory.Transfer(toUid, from, "Trade")
	table.insert(log, { From = Roster.GetName(from), To = Roster.GetName(to), Gave = itemText(gave.TypeId), Got = itemText(got.TypeId) })
	offers[offer.Id] = nil
	tell(from, string.format("🔄 교환 성공! %s에게 %s을(를) 주고 %s을(를) 받았어", Roster.GetName(to), itemText(gave.TypeId), itemText(got.TypeId)))
	tell(to, string.format("🔄 교환 성공! %s에게 %s을(를) 주고 %s을(를) 받았어", Roster.GetName(from), itemText(got.TypeId), itemText(gave.TypeId)))
end

-- NPC가 받은 제안 : 잠깐 고민하고 70% 확률로 받아 줘요
local function npcAnswer(offer)
	task.delay(TRADE.NpcThinkSeconds / Config.Time.TestSpeed, function()
		if offers[offer.Id] ~= offer then
			return
		end
		local mine = Inventory.Get(offer.To)
		if #mine == 0 or rng:NextNumber() >= TRADE.NpcAcceptChance or not isEvening() then
			Trade.Answered:Fire(offer.To, false)
			closeOffer(offer, string.format("🙅 %s이(가) 교환을 거절했어", Roster.GetName(offer.To)))
			return
		end
		Trade.Answered:Fire(offer.To, true)
		complete(offer, mine[rng:NextInteger(1, #mine)].Uid)
	end)
end

----------------------------------------------------------------
-- 제안하기 / 답하기 (플레이어든 NPC든)
----------------------------------------------------------------

function Trade.Propose(from: Instance, to: Instance, fromUid: number): (boolean, string?)
	if not isEvening() then
		return false, "교환은 저녁에만 할 수 있어"
	end
	if from == to or Roster.IsGhost(from) or Roster.IsGhost(to) then
		return false, "그 사람과는 교환할 수 없어"
	end
	if not owns(from, fromUid) then
		return false, "그 유물은 네 것이 아니야"
	end
	if #Inventory.Get(to) == 0 then
		return false, "상대에게 바꿀 유물이 없어"
	end
	if offerFrom(from) then
		return false, "이미 보낸 제안이 있어. 답을 기다려 줘"
	end
	if offerTo(to) then
		return false, "상대가 다른 제안을 고민하고 있어. 조금 있다가 해 봐"
	end

	nextOfferId += 1
	local offer = {
		Id = nextOfferId,
		From = from,
		To = to,
		FromUid = fromUid,
		Expires = os.clock() + TRADE.OfferTimeoutSeconds,
	}
	offers[offer.Id] = offer
	local _, item = Inventory.FindOwner(fromUid)
	Trade.Proposed:Fire(from, to)

	if to:IsA("Player") then
		Remotes.TradeOffer:FireClient(to, "Incoming", {
			OfferId = offer.Id,
			FromName = Roster.GetName(from),
			ItemType = item.TypeId,
			Seconds = TRADE.OfferTimeoutSeconds,
		})
		task.delay(TRADE.OfferTimeoutSeconds, function()
			if offers[offer.Id] == offer then
				closeOffer(offer, string.format("⌛ %s이(가) 대답하지 않았어", Roster.GetName(to)))
			end
		end)
	else
		npcAnswer(offer)
	end
	return true, nil
end

-- 받은 사람이 답해요 : 받아 주면 줄 유물 번호(toUid)도 같이
function Trade.Respond(to: Instance, offerId: number, accept: boolean, toUid: number?)
	local offer = offers[offerId]
	if not offer or offer.To ~= to then
		return
	end
	if not accept or not isEvening() then
		closeOffer(offer, string.format("🙅 %s이(가) 교환을 거절했어", Roster.GetName(to)))
		return
	end
	if typeof(toUid) ~= "number" or not owns(to, toUid) then
		return
	end
	complete(offer, toUid)
end

----------------------------------------------------------------
-- NPC가 먼저 제안하기 (저녁마다 한 번)
----------------------------------------------------------------

function Trade.ScheduleNpcOffers(npcs)
	local latest = Config.Time.EveningSeconds * TRADE.NpcOfferLatestFraction
	for _, npc in npcs do
		for _ = 1, TRADE.NpcOffersPerDay do
			task.delay(rng:NextNumber(TRADE.NpcOfferEarliest, latest) / Config.Time.TestSpeed, function()
				if not npc.Parent or Roster.IsGhost(npc) or not isEvening() then
					return
				end
				local mine = Inventory.Get(npc)
				if #mine == 0 then
					return
				end
				local others = {}
				for _, who in Roster.GetAlive() do
					if who ~= npc and #Inventory.Get(who) > 0 and not offerTo(who) then
						table.insert(others, who)
					end
				end
				if #others == 0 then
					return
				end
				Trade.Propose(npc, others[rng:NextInteger(1, #others)], mine[rng:NextInteger(1, #mine)].Uid)
			end)
		end
	end
end

-- 저녁이 끝나면 남은 제안은 모두 취소
function Trade.CloseAll()
	for _, offer in table.clone(offers) do
		closeOffer(offer, nil)
	end
end

-- 아침 보고서용 : 지난 저녁 교환 기록
function Trade.GetLog()
	return log
end

function Trade.ClearLog()
	table.clear(log)
end

function Trade.Init()
	Remotes.TradeOffer.OnServerEvent:Connect(function(player, action, targetId, uid)
		if action ~= "Propose" or typeof(targetId) ~= "number" or typeof(uid) ~= "number" then
			return
		end
		local now = os.clock()
		if lastPropose[player] and now - lastPropose[player] < TRADE.ProposeCooldown then
			tell(player, "조금만 기다렸다가 다시 제안해 줘")
			return
		end
		lastPropose[player] = now
		local target = Roster.FromId(targetId)
		if not target then
			tell(player, "그 사람을 찾을 수 없어")
			return
		end
		local ok, why = Trade.Propose(player, target, uid)
		if ok then
			tell(player, string.format("📨 %s에게 교환을 제안했어. 대답을 기다리는 중...", Roster.GetName(target)))
		else
			tell(player, "🙅 " .. (why or "교환할 수 없어"))
		end
	end)
	Remotes.TradeRespond.OnServerEvent:Connect(function(player, offerId, accept, uid)
		if typeof(offerId) ~= "number" then
			return
		end
		Trade.Respond(player, offerId, accept == true, uid)
	end)
	Roster.Left:Connect(function(who)
		for _, offer in table.clone(offers) do
			if offer.From == who or offer.To == who then
				closeOffer(offer, offer.To == who and "🙅 상대가 떠나서 교환이 취소됐어" or nil)
			end
		end
		lastPropose[who] = nil
	end)
end

return Trade
