--타자. 플레이어 타격(타이밍 판정)과 AI 타격(확률 트리 기반)을 모두 처리
local Batter = class('Batter')

local HIT_RESULT = Enum.HIT_RESULT
local RUNNER_NIL = Enum.RUNNER_NIL

--확률 트리 leaf key → HIT_RESULT 매핑
local KEY_MAP = {
	swing = HIT_RESULT.STRIKE,
	looking = HIT_RESULT.STRIKE,
	runner_selection = HIT_RESULT.DOUBLE_PLAY,
	strike = HIT_RESULT.STRIKE,
	ball_thrown = HIT_RESULT.BALL_THROWN,
	ground_ball = HIT_RESULT.GROUND_BALL,
	fly_ball = HIT_RESULT.FLY_BALL,
	single = HIT_RESULT.SINGLE,
	double = HIT_RESULT.DOUBLE,
	home_run = HIT_RESULT.HOME_RUN,
}

--region 초기화/해제

function Batter:init()
	self.obj = nil
	self.common = nil
	self.scoreboard = nil
end

function Batter:Initialize(data)
	self.common = data.common
	self.scoreboard = data.scoreboard
end

function Batter:Dispose()
	self.obj = nil
	self.common = nil
	self.scoreboard = nil
end

function Batter:SetBeforeBattle(obj)
	self.obj = obj
end

--endregion

--region 플레이어 타격 (vs AI 투수)

---@class OpPitchInfo
---@field timing table       타이밍 범위 테이블 (duration, very_early, early, good, perfect, late, very_late)
---@field is_strike boolean  스트라이크 존 여부
---@field on_hit nil|function   안타 결과 가공 콜백 (MeteorPitcher QTE 등). (hit_result) → hit_result

---@param op_pitch_info OpPitchInfo
function Batter:PlayerBatting(op_pitch_info)
	local timing = op_pitch_info.timing
	local is_strike = op_pitch_info.is_strike
	local on_hit = op_pitch_info.on_hit

	--버튼 입력 대기
	local time_passed = self:WaitSwing(timing.duration)
	local is_swung = time_passed < timing.duration

	local hit_result

	if is_strike then
		hit_result = self:JudgePlayerTiming(time_passed, timing)
	elseif is_swung then
		--볼인데 휘두름 → 스트라이크
		hit_result = self:GetStrikeResult()
	else
		--볼이고 안 휘두름
		hit_result = self:GetBallResult()
	end

	--on_hit 콜백 (MeteorPitcher QTE 등)
	if is_swung and on_hit and self:IsContact(hit_result) then
		hit_result = on_hit(hit_result)
	end

	return hit_result
end

--endregion

--region AI 타격 (vs 플레이어 투수)

---@class PlayerPitchInfo
---@field swing_duration number           AI가 스윙해야 하는 타이밍 (초)
---@field hit_result_probability table    확률 트리 테이블
---@field is_strike boolean               스트라이크 존 여부

---@param player_pitch_info PlayerPitchInfo
function Batter:AiBatting(player_pitch_info)
	local swing_duration = player_pitch_info.swing_duration
	local hit_result_probability = player_pitch_info.hit_result_probability

	--스윙 타이밍까지 대기
	Util.Coroutine.WaitSec(swing_duration)

	--확률 트리에서 결과 선택
	local key = self:SelectLeafKey(hit_result_probability)
	local hit_result = self:MapKeyToResult(key)

	--삼진/볼넷/병살 보정
	hit_result = self:ApplyCorrections(hit_result)

	return hit_result
end

--endregion

--region 공통 로직

--버튼 누를 때까지 대기. 리턴: 경과 시간
function Batter:WaitSwing(duration)
	local button = 'swing'
	local time_passed = 0

	while not Util.Input.IsButtonDown(button) and time_passed < duration do
		time_passed = time_passed + Util.Time.DeltaTime()
		coroutine.yield()
	end

	return time_passed
end

--timing ranges로 타격 결과 판정
function Batter:JudgePlayerTiming(time_passed, timing)
	if Util.Timing.IsWithin(time_passed, timing.very_early) then
		return self:GetStrikeResult()
	elseif Util.Timing.IsWithin(time_passed, timing.early) then
		return self:EarlyLateProcess()
	elseif Util.Timing.IsWithin(time_passed, timing.good) then
		if Util.Timing.IsWithin(time_passed, timing.perfect) then
			return HIT_RESULT.HOME_RUN
		elseif Util.Timing.IsWithin(time_passed, timing.good.double) then
			return HIT_RESULT.DOUBLE
		elseif Util.Timing.IsWithin(time_passed, timing.good.single) then
			return HIT_RESULT.SINGLE
		end
	elseif Util.Timing.IsWithin(time_passed, timing.late) then
		return self:EarlyLateProcess()
	else
		--very_late 또는 안 누름
		return self:GetStrikeResult()
	end
end

--early/late 타이밍: 땅볼/뜬공 확률
function Batter:EarlyLateProcess()
	local data = self.common.opposite_pitcher.hit_probability.early_late
	local rand = Util.Random.Int(1, 100)

	if rand <= data.ground_ball.probability then
		return self:GetGroundBallResult(data.ground_ball)
	else
		return HIT_RESULT.FLY_BALL
	end
end

--땅볼/병살 판정
function Batter:GetGroundBallResult(ground_ball_data)
	--2아웃 이상이거나 1루 주자 없으면 병살 불가
	if self.scoreboard.out >= 2 or self.scoreboard.base[2] == RUNNER_NIL then
		return HIT_RESULT.GROUND_BALL
	end

	local rand = Util.Random.Int(1, 100)

	if rand <= ground_ball_data.double_play.probability then
		return HIT_RESULT.DOUBLE_PLAY
	else
		return HIT_RESULT.GROUND_BALL
	end
end

--스트라이크/삼진
function Batter:GetStrikeResult()
	if self.scoreboard.strike >= 2 then
		return HIT_RESULT.STRIKEOUT
	end
	return HIT_RESULT.STRIKE
end

--볼/볼넷
function Batter:GetBallResult()
	if self.scoreboard.ball_thrown >= 3 then
		return HIT_RESULT.WALK
	end
	return HIT_RESULT.BALL_THROWN
end

--타구가 맞은 결과인지
function Batter:IsContact(hit_result)
	return Util.HitResult.IsContact(hit_result)
end

--확률 트리에서 leaf key 선택 (재귀)
function Batter:SelectLeafKey(prob_table)
	local key, node = self:SelectChild(prob_table)
	if not node then
		return nil
	end

	--하위에 probability 테이블이 있으면 재귀
	for _, v in pairs(node) do
		if type(v) == 'table' and v.probability then
			return self:SelectLeafKey(node)
		end
	end

	return key
end

--probability 기반 자식 노드 하나 선택
function Batter:SelectChild(prob_table)
	local total = 0
	for _, data in pairs(prob_table) do
		if type(data) == 'table' and data.probability then
			total = total + data.probability
		end
	end

	local rand = Util.Random.Int(1, total)
	local cumulative = 0

	for key, data in pairs(prob_table) do
		if type(data) == 'table' and data.probability then
			cumulative = cumulative + data.probability
			if rand <= cumulative then
				return key, data
			end
		end
	end
end

--leaf key → HIT_RESULT 매핑
function Batter:MapKeyToResult(key)
	return KEY_MAP[key] or HIT_RESULT.STRIKE
end

--삼진/볼넷/병살 보정
function Batter:ApplyCorrections(hit_result)
	if hit_result == HIT_RESULT.STRIKE and self.scoreboard.strike >= 2 then
		return HIT_RESULT.STRIKEOUT
	elseif hit_result == HIT_RESULT.BALL_THROWN and self.scoreboard.ball_thrown >= 3 then
		return HIT_RESULT.WALK
	elseif hit_result == HIT_RESULT.DOUBLE_PLAY then
		if self.scoreboard.out >= 2 or self.scoreboard.base[2] == RUNNER_NIL then
			return HIT_RESULT.GROUND_BALL
		end
	end

	return hit_result
end

--endregion

return Batter
