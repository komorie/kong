--스트라이크/볼/아웃 카운트, 현재 주자, 득점 데이터를 저장하고 갱신하는 클래스
local Scoreboard = class('Scoreboard')

--region 상수

local HIT_RESULT = Enum.HIT_RESULT
local RUNNER_NIL = Enum.RUNNER_NIL
local MAX_OUT = 3
local BASE_COUNT = 4

--endregion

--region 초기화/해제

function Scoreboard:init()
	self.strike = 0
	self.ball_thrown = 0
	self.out = 0

	--진루해 있는 주자들의 배열. [1]=타자, [2]=1루, [3]=2루, [4]=3루
	self.base = { RUNNER_NIL, RUNNER_NIL, RUNNER_NIL, RUNNER_NIL }

	--이전 하이라이트에서 타자 팀이 득점한 총 점수
	self.prev_highlight_score = 0

	--현재 하이라이트에서 타자 팀이 득점한 총 점수
	self.cur_highlight_score = 0

	--현재 배틀(타석)에서 득점한 점수
	self.cur_hit_score = 0
end

function Scoreboard:Dispose()
	self.strike = nil
	self.ball_thrown = nil
	self.out = nil
	self.base = nil
	self.prev_highlight_score = nil
	self.cur_highlight_score = nil
	self.cur_hit_score = nil
end

--endregion

--region 하이라이트/배틀 전 세팅

--주자 배치 덮어쓰기
function Scoreboard:SetBase(base_src)
	for i = 1, BASE_COUNT do
		self.base[i] = base_src[i]
	end
end

--하이라이트 시작 전 초기화. 시작시 주자 배치와 아웃 카운트를 외부에서 받음
function Scoreboard:SetBeforeHighlight(base_const, out)
	self.strike = 0
	self.ball_thrown = 0
	self.out = out
	self:SetBase(base_const)
	self.cur_highlight_score = 0
	self.cur_hit_score = 0
end

--개별 배틀(타석) 시작 전 초기화
function Scoreboard:SetBeforeBattle(cur_batter_idx)
	self.strike = 0
	self.ball_thrown = 0
	self.base[1] = cur_batter_idx
	self.cur_hit_score = 0
end

--endregion

--region 카운트 조작

function Scoreboard:AddStrike()
	self.strike = self.strike + 1
end

function Scoreboard:AddBallThrown()
	self.ball_thrown = self.ball_thrown + 1
end

function Scoreboard:AddOut(count)
	count = count or 1

	self.strike = 0
	self.ball_thrown = 0
	self.out = self.out + count

	if self.out >= MAX_OUT then
		self.out = MAX_OUT
	end
end

function Scoreboard:IsInningEnd()
	return self.out >= MAX_OUT
end

--endregion

--region 타격 결과 처리

--타격 결과에 따라 스코어보드 갱신 (아웃, 주자 위치, 점수)
--스코어보드 상태 변경은 이 함수로만 이루어짐
--Type은 해당 HIT_RESULT 내 세부 유형
function Scoreboard:RefreshWithHitResult(hit_result, type)
	--각 주자가 얼만큼 진루할지 (RUNNER_NIL이면 아웃)
	local progress = { 0, 0, 0, 0 }

	if hit_result == HIT_RESULT.STRIKE then
		self:AddStrike()

	elseif hit_result == HIT_RESULT.BALL_THROWN then
		self:AddBallThrown()

	elseif hit_result == HIT_RESULT.STRIKEOUT then
		--타자 아웃
		progress[1] = RUNNER_NIL
		self:AddOut()

	elseif hit_result == HIT_RESULT.WALK then
		self.strike = 0
		self.ball_thrown = 0
		progress[1] = 1

		--밀어내기: 앞에 주자가 차있으면 연쇄 진루
		if self.base[2] ~= RUNNER_NIL then
			progress[2] = 1
			if self.base[3] ~= RUNNER_NIL then
				progress[3] = 1
				if self.base[4] ~= RUNNER_NIL then
					progress[4] = 1
				end
			end
		end

	elseif hit_result == HIT_RESULT.GROUND_BALL then
		--타자 아웃
		progress[1] = RUNNER_NIL

		--1루수 땅볼 시 2, 3루 주자 진루
		if type == 1 then
			progress[3] = 1
			progress[4] = 1
		end

		self:AddOut()

	elseif hit_result == HIT_RESULT.FLY_BALL then
		--타자 아웃
		progress[1] = RUNNER_NIL
		self:AddOut()

	elseif hit_result == HIT_RESULT.DOUBLE_PLAY then
		--타자, 1루 주자 아웃
		progress[1] = RUNNER_NIL
		progress[2] = RUNNER_NIL

		--2, 3루 주자 진루
		progress[3] = 1
		progress[4] = 1

		self:AddOut(2)

	elseif hit_result == HIT_RESULT.SINGLE then
		for i = 1, BASE_COUNT do
			progress[i] = 1
		end

	elseif hit_result == HIT_RESULT.DOUBLE then
		for i = 1, BASE_COUNT do
			progress[i] = 2
		end

	elseif hit_result == HIT_RESULT.HOME_RUN then
		for i = 1, BASE_COUNT do
			progress[i] = 4
		end
	end

	--쓰리아웃 시 주자 전부 아웃
	if self.out >= MAX_OUT then
		for i = 1, BASE_COUNT do
			progress[i] = RUNNER_NIL
		end
	end

	--주자/점수 갱신 (역순으로 처리해야 겹침 방지)
	for i = BASE_COUNT, 1, -1 do
		local move_count = progress[i]
		local next_base = i + move_count
		local runner_idx = self.base[i]

		--기존 위치에서 제거
		self.base[i] = RUNNER_NIL

		--주자가 살아있는 경우
		if runner_idx ~= RUNNER_NIL and move_count ~= RUNNER_NIL then
			if next_base > BASE_COUNT then
				--홈 도착 → 득점
				self.cur_hit_score = self.cur_hit_score + 1
			else
				--진루
				self.base[next_base] = runner_idx
			end
		end
	end

	--현재 하이라이트 총 점수 갱신
	self.cur_highlight_score = self.cur_highlight_score + self.cur_hit_score

	return hit_result
end

--endregion

return Scoreboard
