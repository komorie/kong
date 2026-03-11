--상승 후 낙하하며, 안타 시 연타 QTE 발동하는 메테오 마구를 던지는 상대 투수 클래스.
local OppositePitcher = require('OppositePitcher')

local MeteorPitcher = class('MeteorPitcher', OppositePitcher)

local HIT_RESULT = Enum.HIT_RESULT

function MeteorPitcher:init()
	self.super.init(self)
	self.pitch_const = Constants.METEOR_PITCHER
end

--region 투구

function MeteorPitcher:Pitch()
	self.throw_count = self.throw_count + 1

	local is_strike = self:SelectStrike()
	local des = self:SelectEndPos(is_strike)
	local op_const = self.pitch_const
	local probability = op_const.probability

	local timing
	local on_hit

	if self.throw_count == 1 then
		timing = op_const.fastball.timing
		self:Fastball(des, timing.duration)
	elseif self:IsFullCount() then
		is_strike = true
		des = self:SelectEndPos(is_strike)
		timing = op_const.meteor_ball.timing
		on_hit = self:MeteorBall(des, timing.duration)
	else
		local rand = Util.Random.Int(1, 100)

		if rand <= probability.fastball then
			timing = op_const.fastball.timing
			self:Fastball(des, timing.duration)
		else
			is_strike = true
			des = self:SelectEndPos(is_strike)
			timing = op_const.meteor_ball.timing
			on_hit = self:MeteorBall(des, timing.duration)
		end
	end

	return {
		timing = timing,
		is_strike = is_strike,
		on_hit = on_hit,
	}
end

--메테오 볼. 베지어 곡선으로 상승 후, 2단계 직선으로 낙하
function MeteorPitcher:MeteorBall(des, duration)
	self:BeforePitchScene()

	local meteor_const = self.pitch_const.meteor_ball
	local ball_start_pos = self.obj.Position + meteor_const.ball_start_offset
	local hover_pos = self.obj.Position + meteor_const.hover_offset

	--Phase 1: 베지어 곡선으로 투수 머리 위까지 상승
	self.ball:SetPath({
		{
			start_pos = ball_start_pos,
			end_pos = hover_pos,
			duration = meteor_const.rise_duration,
			curve = { type = Enum.CURVE_TYPE.BEZIER, y_max = meteor_const.rise_y_max },
		},
	})

	self.ball:WaitMoveEnd()

	--Phase 2: 2단계 직선으로 타자 방향 낙하
	local trajectory = meteor_const.trajectory

	self.ball:SetPath({
		{
			end_pos = hover_pos + trajectory.first_half_offset,
			duration = trajectory.first_half_duration,
		},
		{
			end_pos = des,
			duration = trajectory.last_half_duration,
		},
	})

	--on_hit: 안타 시 QTE 처리. 실패하면 스트라이크로 전환
	local on_hit = function(hit_result)
		local is_out = hit_result == HIT_RESULT.GROUND_BALL
				or hit_result == HIT_RESULT.DOUBLE_PLAY
				or hit_result == HIT_RESULT.FLY_BALL

		if is_out then
			return hit_result
		end

		--안타 판정 시 QTE 발동
		self.ball:Stop()

		local qte_success = Util.Qte.MashButton(meteor_const.qte_count, meteor_const.qte_time)

		if not qte_success then
			if self.scoreboard.strike >= 2 then
				return HIT_RESULT.STRIKEOUT
			else
				return HIT_RESULT.STRIKE
			end
		end

		return hit_result
	end

	return on_hit
end

--endregion

return MeteorPitcher
