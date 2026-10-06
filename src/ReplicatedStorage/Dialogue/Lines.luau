-- NPC들이 하는 말 100문장을 모두 모아 두는 곳이에요.
-- 아들과 함께 문장을 고치려면 이 파일만 고치면 돼요.
-- (마일스톤 7에서 100문장을 채워요. 지금은 빈 칸이에요.)

local Lines = {
	DigChat = {}, -- 15 : 발굴·정글·유적 감상
	DayClue = {}, -- 15 : 밤 사건 근거 ({이름}, {방향}, {유물} 치환)
	DayRedHerring = {}, -- 15 : 무작위 지목
	TradeTalk = {}, -- 10 : 교환 제안·거절
	CursedExcuse = {}, -- 10 : 저주 NPC의 어리둥절
	NightMood = {}, -- 15 : 밤 분위기
	VoteReaction = {}, -- 10 : 투표 반응
	RoundFlow = {}, -- 10 : 탐사 진행
}

return Lines
