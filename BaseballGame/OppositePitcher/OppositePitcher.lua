--AI 기반 상대 투수 베이스 클래스.
--현재 볼카운트 기반하여 스트라이크/볼 중 고르는 로직과 공통 투구 로직 제공
local OppositePitcher = class('OppositePitcher')

--region 초기화/해제

function OppositePitcher:init()
	self.obj = nil
	self.ball = nil
	self.scoreboard = nil
	self.common = nil
	self.pitch_const = nil
	self.throw_count = nil
	self.strike_zone = nil
	self.pitch_start_pos = nil
end

function OppositePitcher:Initialize(data)
	self.obj = data.obj
	self.ball = data.ball
	self.scoreboard = data.scoreboard
	self.common = data.common
	self.strike_zone = data.strike_zone
	self.throw_count = 0
	self.pitch_start_pos = self.obj.Bounds.center + self.common.pitcher.pitch_start_offset
	--pitch_const는 각 서브클래스 init()에서 세팅
end

function OppositePitcher:Dispose()
	self.obj = nil
	self.ball = nil
	self.scoreboard = nil
	self.common = nil
	self.pitch_const = nil
	self.throw_count = nil
	self.strike_zone = nil
	self.pitch_start_pos = nil
end

--각 타석 시작 전 호출
function OppositePitcher:SetBeforeBattle(obj)
	self.obj = obj
	self.throw_count = 0
	self.pitch_start_pos = self.obj.Bounds.center + self.common.pitcher.pitch_start_offset
end

--endregion

--region 공통 로직

--풀카운트(2S-3B) 여부
function OppositePitcher:IsFullCount()
	return self.scoreboard.strike == 2 and self.scoreboard.ball_thrown == 3
end

--볼 카운트 기반 스/볼 확률 판정
function OppositePitcher:SelectStrike()
	local probability = self.common.opposite_pitcher.strike_probability
	local percent = Util.Random.Int(1, 100)

	return percent <= probability[self.scoreboard.strike][self.scoreboard.ball_thrown]
end

--스/볼 여부에 따라 공 도착 지점 선택
function OppositePitcher:SelectEndPos(is_strike)
	return Util.StrikeZone.SelectEndPos(self.strike_zone, self.common.pitcher.throw_pos, is_strike)
end

--직구. 직선 궤적으로 투구
function OppositePitcher:Fastball(des, duration)
	if not duration then
		duration = self.pitch_const.fastball.timing.duration
	end

	self:BeforePitchScene()

	self.ball:SetPath({
		{ start_pos = self.pitch_start_pos, end_pos = des, duration = duration },
	})
end

--endregion

--region 추상/오버라이드

--투구 수행. 파생 클래스에서 오버라이드
---@return OpPitchInfo
function OppositePitcher:Pitch()
end

--endregion

--region 연출 의사함수

--투구 전 연출 (투구폼 등)
function OppositePitcher:BeforePitchScene()
end

--endregion

return OppositePitcher
