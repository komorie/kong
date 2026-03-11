--플레이어가 조작하는 투수 클래스. 구종 선택 → 게이지 QTE → 타이밍 판정 → 투구 실행
local PlayerPitcher = class('PlayerPitcher')

local PITCH_TYPE = Enum.PITCH_TYPE
local TIMING_RESULT = Enum.TIMING_RESULT
local POWER_STATE = Enum.POWER_STATE

--region 초기화/해제

function PlayerPitcher:init()
	self.obj = nil
	self.ball = nil
	self.common = nil
	self.pitch_const = nil
	self.strike_zone = nil
	self.pitch_start_pos = nil
	self.power_state = nil
end

function PlayerPitcher:Initialize(data)
	self.obj = data.obj
	self.ball = data.ball
	self.common = data.common
	self.pitch_const = Constants.PLAYER_PITCHER
	self.strike_zone = data.strike_zone
	self.power_state = POWER_STATE.NORMAL
	self.pitch_start_pos = self.obj.Bounds.center + self.common.pitcher.pitch_start_offset

	self:InitializeScene(data)
end

function PlayerPitcher:Dispose()
	self:DisposeScene()

	self.obj = nil
	self.ball = nil
	self.common = nil
	self.pitch_const = nil
	self.strike_zone = nil
	self.pitch_start_pos = nil
	self.power_state = nil
end

--각 타석 시작 전 호출
function PlayerPitcher:SetBeforeBattle(obj)
	self.obj = obj
	self.pitch_start_pos = self.obj.Bounds.center + self.common.pitcher.pitch_start_offset
end

--endregion

--region 투구

---@return PlayerPitchInfo
function PlayerPitcher:Pitch()
	--포수 리드: 포수가 구종을 제안
	local lead_type = self:RollLead()
	self:LeadScene(lead_type)

	--플레이어 구종 선택
	local pitch_type
	if self.power_state == POWER_STATE.FULL then
		pitch_type = PITCH_TYPE.VERY_FAST_BALL
	else
		pitch_type = self:PitchSelectScene()
	end

	--게이지 타이밍 테이블 결정
	local gauge_timing = self:GetGaugeTiming(pitch_type, lead_type)

	--게이지 QTE 실행
	local time_passed = self:GaugeAction(gauge_timing)

	--타이밍 판정
	local timing_result = self:JudgeTiming(time_passed, gauge_timing)

	--스트라이크 여부: WEAK만 볼, 나머지 전부 스트라이크
	local is_strike = (timing_result ~= TIMING_RESULT.WEAK)

	--투구 실행
	local des = self:SelectEndPos(is_strike)
	local pitch_data = self.pitch_const.pitches[pitch_type]
	local duration = pitch_data.duration[timing_result]
	local swing_duration = duration - pitch_data.swing_margin

	--타격 결과 확률 (구종 전용 테이블이 있으면 우선 사용)
	--NOTE: VERY_FAST_BALL은 [PERFECT]만 정의. gauge_timing이 전 구간 PERFECT이라 보장됨
	local probabilities = pitch_data.hit_result_probabilities or self.pitch_const.hit_result_probabilities
	local hit_result_probability = probabilities[timing_result]

	self:ExecutePitch(pitch_type, des, duration)

	return {
		swing_duration = swing_duration,
		hit_result_probability = hit_result_probability,
		is_strike = is_strike,
	}
end

--endregion

--region 공통 로직

--포수 리드 구종 결정
function PlayerPitcher:RollLead()
	local prob = self.pitch_const.lead_probability
	local total = prob.fastball + prob.slider + prob.curve
	local rand = Util.Random.Int(1, total)

	if rand <= prob.fastball then
		return PITCH_TYPE.FASTBALL
	elseif rand <= prob.fastball + prob.slider then
		return PITCH_TYPE.SLIDER
	else
		return PITCH_TYPE.CURVE
	end
end

--구종/리드/파워 상태에 따른 게이지 타이밍 테이블 반환
function PlayerPitcher:GetGaugeTiming(pitch_type, lead_type)
	local gauge = self.pitch_const.gauge

	--WEAK/FULL은 구종 무관 고정 타이밍
	if self.power_state ~= POWER_STATE.NORMAL then
		return gauge.power_timing[self.power_state]
	end

	local pitch_timing = gauge.pitch_timing[pitch_type]
	if pitch_type == lead_type then
		return pitch_timing.lead
	else
		return pitch_timing.not_lead
	end
end

--게이지 결과에서 타이밍 판정
function PlayerPitcher:JudgeTiming(time_passed, gauge_timing)
	if Util.Timing.IsWithin(time_passed, gauge_timing.weak) then
		return TIMING_RESULT.WEAK
	elseif Util.Timing.IsWithin(time_passed, gauge_timing.good) then
		return TIMING_RESULT.GOOD
	elseif Util.Timing.IsWithin(time_passed, gauge_timing.great) then
		return TIMING_RESULT.GREAT
	elseif Util.Timing.IsWithin(time_passed, gauge_timing.perfect) then
		return TIMING_RESULT.PERFECT
	else
		return TIMING_RESULT.MISS
	end
end

--스/볼 여부에 따라 공 도착 지점 선택
function PlayerPitcher:SelectEndPos(is_strike)
	return Util.StrikeZone.SelectEndPos(self.strike_zone, self.common.pitcher.throw_pos, is_strike)
end

--직구. 직선 궤적
function PlayerPitcher:Fastball(des, duration)
	if not duration then
		duration = self.pitch_const.pitches[PITCH_TYPE.FASTBALL].duration[TIMING_RESULT.GOOD]
	end

	self:BeforePitchScene()

	self.ball:SetPath({
		{ start_pos = self.pitch_start_pos, end_pos = des, duration = duration },
	})
end

--슬라이더. x축 베지어 곡선
function PlayerPitcher:Slider(des, duration, x_offset)
	self:BeforePitchScene()

	self.ball:SetPath({
		{
			start_pos = self.pitch_start_pos,
			end_pos = des,
			duration = duration,
			curve = { type = Enum.CURVE_TYPE.BEZIER, x_max = x_offset },
		},
	})
end

--커브. y축 베지어 곡선
function PlayerPitcher:Curve(des, duration, y_offset)
	self:BeforePitchScene()

	self.ball:SetPath({
		{
			start_pos = self.pitch_start_pos,
			end_pos = des,
			duration = duration,
			curve = { type = Enum.CURVE_TYPE.BEZIER, y_max = y_offset },
		},
	})
end

--구종 선택 후 투구 실행. pitch_info에서 구종별 궤적 자동 결정
function PlayerPitcher:ExecutePitch(pitch_type, des, duration)
	local pitch_info = self.pitch_const.pitches[pitch_type]

	if pitch_info.x_offset then
		self:Slider(des, duration, pitch_info.x_offset)
	elseif pitch_info.y_offset then
		self:Curve(des, duration, pitch_info.y_offset)
	else
		self:Fastball(des, duration)
	end
end

--파워 상태 전환
function PlayerPitcher:SetPowerState(state)
	self.power_state = state
	self:PowerStateScene(state)
end

--endregion

--region 연출 의사함수

--초기화 시 리소스 로드 등
function PlayerPitcher:InitializeScene(data)
end

--해제 시 리소스 정리
function PlayerPitcher:DisposeScene()
end

--포수 리드 연출 (이모티콘 버블)
function PlayerPitcher:LeadScene(lead_type)
end

--구종 선택 UI. 리턴: 선택한 PITCH_TYPE
function PlayerPitcher:PitchSelectScene()
end

--게이지 UI 표시 (타이밍 구간별 색상 세팅)
function PlayerPitcher:GaugeShowScene(gauge_timing)
end

--게이지 UI 숨김
function PlayerPitcher:GaugeHideScene()
end

--게이지 QTE 실행. 리턴: time_passed
function PlayerPitcher:GaugeAction(gauge_timing)
	local gauge_duration = self.pitch_const.gauge.duration
	local button = 'pitch'

	self:GaugeShowScene(gauge_timing)

	--버튼 누를 때까지 대기
	while not Util.Input.IsButtonDown(button) do
		coroutine.yield()
	end

	--누르고 있는 동안 시간 측정
	local time_passed = 0

	while Util.Input.IsButtonDown(button) and time_passed < gauge_duration do
		time_passed = time_passed + Util.Time.DeltaTime()
		coroutine.yield()
	end

	self:GaugeHideScene()

	return time_passed
end

--투구 전 연출 (투구폼, 방향 전환)
function PlayerPitcher:BeforePitchScene()
end

--파워 상태 전환 연출
function PlayerPitcher:PowerStateScene(state)
end

--피드백 대사 (포수가 타이밍에 따라 코멘트)
function PlayerPitcher:FeedbackSpeech(time_passed, gauge_timing)
end

--endregion

return PlayerPitcher
