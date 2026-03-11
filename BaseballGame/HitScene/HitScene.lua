--타격 결과에 맞는 타구 연출이 구현된 클래스.
--타구 이동, 수비, 주자 진루 연출 등 실행
local HitScene = class('HitScene')

local HIT_RESULT = Enum.HIT_RESULT
local CURVE_TYPE = Enum.CURVE_TYPE

--region 초기화/해제

function HitScene:init()
	self.ball = nil
	self.common = nil
	self.defenders = nil
	self.runners = nil
end

function HitScene:Initialize(data)
	self.ball = data.ball
	self.common = data.common
	self.defenders = data.defenders
	self.runners = data.runners
end

function HitScene:Dispose()
	self.ball = nil
	self.common = nil
	self.defenders = nil
	self.runners = nil
end

--endregion

--region 실행

--hit_result별 함수 디스패치 테이블
local DISPATCH = {
	[HIT_RESULT.STRIKE]      = 'StrikeScene',
	[HIT_RESULT.BALL_THROWN]  = 'BallThrownScene',
	[HIT_RESULT.STRIKEOUT]   = 'StrikeoutScene',
	[HIT_RESULT.WALK]        = 'WalkScene',
	[HIT_RESULT.GROUND_BALL] = 'GroundBallScene',
	[HIT_RESULT.FLY_BALL]    = 'FlyBallScene',
	[HIT_RESULT.DOUBLE_PLAY] = 'DoublePlayScene',
	[HIT_RESULT.SINGLE]      = 'SingleScene',
	[HIT_RESULT.DOUBLE]      = 'DoubleScene',
	[HIT_RESULT.HOME_RUN]    = 'HomeRunScene',
}

--타격 결과 연출 진입점
function HitScene:Execute(hit_result, hit_type)
	--타구가 맞았으면 공 즉시 멈춤, 아니면 투구 끝까지 대기
	if Util.HitResult.IsContact(hit_result) then
		self.ball:Stop()
	else
		self.ball:WaitMoveEnd()
	end

	local func_name = DISPATCH[hit_result]
	self[func_name](self, hit_type)
end

--endregion

--region 타구 이동 공통

--hit_result, hit_type에 따른 타구 도착 지점 반환용 의사 함수
function HitScene:GetHitEndPos(hit_result, hit_type)
end

--Constants의 ball_bounces 데이터로 바운스 궤적 생성
function HitScene:HitBallMove(hit_result, hit_type, end_pos)
	local scene_data = self.common.hit_result_scene[hit_result][hit_type]
	local ball_bounces = scene_data.ball_bounces

	local start_pos = self.ball.obj.Position

	--전체 duration (마지막 바운스의 duration이 총 시간)
	local total_duration = ball_bounces[#ball_bounces].duration

	--바운스별 웨이포인트 생성
	local waypoints = {}
	local prev_duration = 0

	for _, bounce in ipairs(ball_bounces) do
		--전체 경로에서 이 바운스가 끝나는 비율로 중간 위치 계산
		local progress = bounce.duration / total_duration
		local bounce_end_pos = Util.Vector.Lerp(start_pos, end_pos, progress)

		--y축은 바운스 궤적이므로 지면(0)으로 고정
		bounce_end_pos.y = 0

		local wp = {
			end_pos = bounce_end_pos,
			duration = bounce.duration - prev_duration,
		}

		--y_max > 0이면 베지어 곡선으로 바운스
		if bounce.y_max and bounce.y_max > 0 then
			wp.curve = { type = CURVE_TYPE.BEZIER, y_max = bounce.y_max }
		end

		table.insert(waypoints, wp)
		prev_duration = bounce.duration
	end

	self.ball:SetPath(waypoints)
end

--endregion

--region hit_result별 연출

--땅볼 연출
function HitScene:GroundBallScene(hit_type)
	if hit_type == 1 then
		--1루수 방향 땅볼
		local catch_pos = self:GetHitEndPos(HIT_RESULT.GROUND_BALL, hit_type)

		--동시 실행: 타구 이동 + 1루수 포구 지점 이동 + 전원 진루
		self:HitBallMove(HIT_RESULT.GROUND_BALL, hit_type, catch_pos)
		self.defenders:Move(3, catch_pos, 1)
		self.runners:ProgressAll(1)

		self.ball:WaitMoveEnd()
		self.defenders:WaitMoveEnd()

		--공 숨기고 1루수가 직접 1루 베이스로 이동
		Util.Obj.SetVisible(self.ball.obj, false)
		self.defenders:Move(3, self.runners:GetBasePos(2), 0.5)
		self.defenders:WaitMoveEnd()
		Util.Obj.SetVisible(self.ball.obj, true)

		--타자 아웃
		self.runners:Out(1)
		self.runners:WaitAll()

	elseif hit_type == 2 then
		--2루수 방향 땅볼

	elseif hit_type == 3 then
		--3루수 방향 땅볼

	elseif hit_type == 4 then
		--투수 방향 땅볼

	end
end

--뜬공 연출 (땅볼과 비슷한 구조로 구현)
function HitScene:FlyBallScene(hit_type)
end

--병살 연출 (땅볼과 비슷한 구조 + 2루 → 1루 이중 송구)
function HitScene:DoublePlayScene(hit_type)
end

--안타 연출 (타구 이동 후 주자 전원 1루 진루)
function HitScene:SingleScene(hit_type)
end

--2루타 연출 (타구 이동 후 주자 전원 2루 진루)
function HitScene:DoubleScene(hit_type)
end

--홈런 연출 (타구 이동 후 주자 전원 홈까지 진루)
function HitScene:HomeRunScene(hit_type)
end

--스트라이크 연출 (심판 콜)
function HitScene:StrikeScene(hit_type)
end

--볼 연출 (심판 콜)
function HitScene:BallThrownScene(hit_type)
end

--삼진 연출 (심판 콜 + 타자 퇴장)
function HitScene:StrikeoutScene(hit_type)
end

--볼넷 연출 (타자 1루 진루 + 주자 밀어내기)
function HitScene:WalkScene(hit_type)
end

--endregion

return HitScene
