--예시 섹션. 실제 게임의 특정 섹션 구조를 의사코드로 재현

local SceneBase = require('SceneBase')

local Section13 = class('Section13', SceneBase)

local HIT_RESULT = Enum.HIT_RESULT

function Section13:init()
	self.super.init(self)
	self.cached_base = nil
end

function Section13:Dispose()
	self.super.Dispose(self)
	self.cached_base = nil
end

--region 연출 오버라이드

function Section13:HighlightIntro()
	if self.highlight_index == 1 then
		--카메라 이동, 타자 등장, 캐스터 대사 등
		self:FirstHighlightIntroScene()
	elseif self.highlight_index == 2 then
		--2회 인트로 연출
	end
end

function Section13:ScoredScene(hit_result)
	if self.highlight_index == 1 then
		if hit_result == HIT_RESULT.HOME_RUN then
			--홈런 득점 연출
		else
			--일반 득점 연출
		end
	elseif self.highlight_index == 2 then
		--2회 득점 연출
	end
end

function Section13:BattleOutro(hit_result)
	if self.highlight_index == 1 then
		if hit_result == HIT_RESULT.FLY_BALL then
			--뜬공 아웃 대사
		elseif hit_result == HIT_RESULT.GROUND_BALL then
			--땅볼 아웃 대사
		elseif hit_result == HIT_RESULT.STRIKEOUT then
			--삼진 대사
		elseif hit_result == HIT_RESULT.SINGLE then
			--안타 대사
		elseif hit_result == HIT_RESULT.DOUBLE then
			--2루타 대사
		end
	elseif self.highlight_index == 2 then
		--2회 타격 결과별 연출
	end
end

--endregion

--region 커스텀 배틀 루틴

function Section13:UseCustomBattle()
	return self.highlight_index == 4 or self.highlight_index == 5
end

---@param api BattleApi
function Section13:CustomBattleRoutine(api)
	if self.highlight_index == 4 then
		--기본 배틀 진행하되, 2아웃 잡으면 바로 다음 하이라이트로 넘김
		local hit_result = api.default_battle()

		if api.scoreboard.cur_highlight_score > 0 then
			api.set_fail()
		elseif api.scoreboard.out >= 2 then
			self.cached_base = Util.Table.Copy(api.scoreboard.base)
			api.set_clear()
		end

		return hit_result

	elseif self.highlight_index == 5 then
		--이벤트전: 스크립티드 배틀
		--이전 하이라이트의 주자 상태 복원
		api.scoreboard:SetBase(self.cached_base)

		self:EventBattleIntroScene()

		--투수가 직접 직구 스트라이크 투구
		local des = api.player_pitcher:SelectEndPos(true)
		api.player_pitcher:Fastball(des)
		api.ball:WaitMoveEnd()

		--이벤트 스트라이크 연출
		self:EventBattleStrikeScene()

		--다시 직구 투구
		des = api.player_pitcher:SelectEndPos(true)
		api.player_pitcher:Fastball(des)
		api.ball:WaitMoveEnd()

		--데드볼 연출
		self:EventBattleOutroScene()

		api.set_clear()

		return HIT_RESULT.WALK
	end
end

--endregion

--region 연출 의사함수

--1회 인트로 연출
function Section13:FirstHighlightIntroScene()
end

--이벤트전 진입 연출 (대타 등장 등)
function Section13:EventBattleIntroScene()
end

--이벤트전 스트라이크 연출
function Section13:EventBattleStrikeScene()
end

--이벤트전 종료 연출
function Section13:EventBattleOutroScene()
end

--endregion

return Section13
