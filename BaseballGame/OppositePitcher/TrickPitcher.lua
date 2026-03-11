--지그재그 궤적 마구와 투명화 마구를 섞어 던지는 상대 투수 클래스
local OppositePitcher = require('OppositePitcher')

local TrickPitcher = class('TrickPitcher', OppositePitcher)

function TrickPitcher:init()
	self.super.init(self)
	self.pitch_const = Constants.TRICK_PITCHER
end

--region 투구

function TrickPitcher:Pitch()
	self.throw_count = self.throw_count + 1

	local is_strike = self:SelectStrike()
	local des = self:SelectEndPos(is_strike)
	local op_const = self.pitch_const
	local probability = op_const.probability
	local probability_2s3b = op_const.probability_2s3b

	local timing

	if self.throw_count == 1 then
		timing = op_const.fastball.timing
		self:Fastball(des, timing.duration)
	elseif self:IsFullCount() then
		--풀카운트: 지그재그/인비저블 확률
		local rand = Util.Random.Int(1, 100)

		is_strike = true
		des = self:SelectEndPos(is_strike)

		if rand <= probability_2s3b.zigzag_ball then
			timing = op_const.zigzag_ball.timing
			self:ZigzagBall(des, timing.duration)
		else
			timing = op_const.invisible_ball.timing
			self:InvisibleBall(des, timing.duration)
		end
	else
		local total = probability.fastball + probability.zigzag_ball + probability.invisible_ball
		local rand = Util.Random.Int(1, total)

		if rand <= probability.fastball then
			timing = op_const.fastball.timing
			self:Fastball(des, timing.duration)
		elseif rand <= probability.fastball + probability.zigzag_ball then
			is_strike = true
			des = self:SelectEndPos(is_strike)
			timing = op_const.zigzag_ball.timing
			self:ZigzagBall(des, timing.duration)
		else
			is_strike = true
			des = self:SelectEndPos(is_strike)
			timing = op_const.invisible_ball.timing
			self:InvisibleBall(des, timing.duration)
		end
	end

	return {
		timing = timing,
		is_strike = is_strike,
	}
end

--지그재그 볼. 복수 경유 지점을 거쳐 이동
function TrickPitcher:ZigzagBall(des, duration)
	self:BeforePitchScene()

	local offsets = self.pitch_const.zigzag_ball.offsets

	--경유 지점 생성
	local points = { self.pitch_start_pos }
	for i = 1, #offsets do
		points[i + 1] = self.pitch_start_pos + offsets[i]
	end
	table.insert(points, des)

	--총 거리로 속도 계산
	local total_distance = 0
	for i = 1, #points - 1 do
		total_distance = total_distance + Util.Vector.Distance(points[i], points[i + 1])
	end
	local speed = total_distance / duration

	--모든 구간을 waypoint로 변환
	local waypoints = {}
	for i = 1, #points - 1 do
		table.insert(waypoints, {
			start_pos = points[i],
			end_pos = points[i + 1],
			speed = speed,
		})
	end

	self.ball:SetPath(waypoints)
end

--인비저블 볼. 직선 궤적이나 도중에 공이 사라졌다 나타남
function TrickPitcher:InvisibleBall(des, duration)
	self:BeforePitchScene()

	local pitch_const = self.pitch_const.invisible_ball
	local disappear_time = pitch_const.disappear_time
	local appear_time = pitch_const.appear_time

	self.ball:SetPath({
		{ start_pos = self.pitch_start_pos, end_pos = des, duration = duration },
	})

	--공 사라짐/나타남 타이밍 (비동기)
	Util.Coroutine.Start(function()
		Util.Coroutine.WaitSec(disappear_time)
		Util.Obj.SetVisible(self.ball.obj, false)

		Util.Coroutine.WaitSec(appear_time - disappear_time)
		Util.Obj.SetVisible(self.ball.obj, true)
	end)
end

--endregion

return TrickPitcher
