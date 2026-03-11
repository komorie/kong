--사인 곡선 그래프 기반으로 x좌표가 움직이는 마구를 던지는 상대 투수
local OppositePitcher = require('OppositePitcher')

local SinePitcher = class('SinePitcher', OppositePitcher)

function SinePitcher:init()
	self.super.init(self)
	self.pitch_const = Constants.SINE_PITCHER
end

--region 투구

function SinePitcher:Pitch()
	self.throw_count = self.throw_count + 1

	local is_strike = self:SelectStrike()
	local des = self:SelectEndPos(is_strike)
	local op_const = self.pitch_const
	local probability = op_const.probability

	local timing

	if self.throw_count == 1 then
		--초구는 직구
		timing = op_const.fastball.timing
		self:Fastball(des, timing.duration)
	elseif self:IsFullCount() then
		--풀카운트에서는 사인볼
		is_strike = true
		des = self:SelectEndPos(is_strike)
		timing = op_const.sine_ball.timing
		self:SineBall(des, timing.duration)
	else
		local rand = Util.Random.Int(1, 100)

		if rand <= probability.fastball then
			timing = op_const.fastball.timing
			self:Fastball(des, timing.duration)
		else
			is_strike = true
			des = self:SelectEndPos(is_strike)
			timing = op_const.sine_ball.timing
			self:SineBall(des, timing.duration)
		end
	end

	return {
		timing = timing,
		is_strike = is_strike,
	}
end

--사인 곡선 투구. x축을 사인파로 흔들며 이동
function SinePitcher:SineBall(des, duration)
	self:BeforePitchScene()

	local pitch_const = self.pitch_const.sine_ball
	local amplitude = pitch_const.amplitude
	local angular_freq = math.pi * pitch_const.wave_count

	self.ball:SetPath({
		{
			start_pos = self.pitch_start_pos,
			end_pos = des,
			duration = duration,
			x_move = function(progress, start_x, end_x)
				local base = (1 - progress) * start_x + progress * end_x
				return base + math.sin(angular_freq * progress) * amplitude
			end,
		},
	})
end

--endregion

return SinePitcher
