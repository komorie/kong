--섹션 연출 베이스 클래스. 하이라이트 인트로/배틀 아웃트로 시 실행
local SceneBase = class('SceneBase')

--region 초기화/해제

function SceneBase:init()
	self.scoreboard = nil
	self.common = nil
	self.highlight_index = nil
end

function SceneBase:Initialize(data)
	self.scoreboard = data.scoreboard
	self.common = data.common
end

function SceneBase:Dispose()
	self.scoreboard = nil
	self.common = nil
	self.highlight_index = nil
end

--하이라이트 시작 전 호출
function SceneBase:SetBeforeHighlight(highlight_index)
	self.highlight_index = highlight_index
end

--endregion

--region 연출 의사함수 (파생 클래스에서 오버라이드)

--하이라이트 시작 연출 진입 전 세팅
function SceneBase:EnterHighlightIntro()
end

--하이라이트 시작 연출
function SceneBase:HighlightIntro()
end

--하이라이트 시작 연출 종료 후 세팅
function SceneBase:ExitHighlightIntro()
end

--득점 시 연출(베이스 밟는 순간)
function SceneBase:ScoredScene(hit_result)
end

--타격 종료 연출 진입 전 세팅
function SceneBase:EnterBattleOutro()
end

--타격 종료 연출
function SceneBase:BattleOutro(hit_result)
end

--타격 종료 연출 후 세팅
function SceneBase:ExitBattleOutro()
end

--수비/공격 캐릭터 기본 위치 배치
function SceneBase:PlaceDefaultPos()
end

--endregion

--region 커스텀 배틀 루틴 (파생 클래스에서 오버라이드)

---@class BattleApi
---@field default_battle function         기본 투타 대결 실행. () → hit_result
---@field scoreboard Scoreboard           스코어보드 참조
---@field player_pitcher PlayerPitcher    플레이어 투수
---@field opposite_pitcher OppositePitcher  상대 투수
---@field ball BallController             공 컨트롤러
---@field set_clear function              하이라이트 클리어 처리
---@field set_fail function               하이라이트 실패 처리

--이 하이라이트에서 커스텀 배틀 루틴을 사용할지(연출 및 특수 승리 조건 가미된 이벤트전 시)
function SceneBase:UseCustomBattle()
	return false
end

--커스텀 배틀 루틴 내용
---@param api BattleApi
function SceneBase:CustomBattleRoutine(api)
end

--endregion

return SceneBase
