--공 오브젝트의 이동을 웨이포인트 큐 기반으로 처리하는 클래스. 직선/베지어 곡선 지원
local BallController = class('BallController')

--region 초기화/해제

function BallController:init()
	--움직일 공 오브젝트
	self.obj = nil

	--웨이포인트 큐. SetPath로 통으로 등록됨
	self.wp_queue = nil

	--현재 경로의 완료 콜백. 정상 완료/중도 정지 모두 이걸로 처리
	self.on_finish = nil
end

--오브젝트 세팅 및 초기 상태 설정
function BallController:Initialize(obj)
	self.obj = obj
	self.wp_queue = {}
	self.on_finish = nil
end

function BallController:Dispose()
	self.obj = nil
	self.wp_queue = nil
	self.on_finish = nil
end

--endregion

--region 이동 등록

--웨이포인트 테이블을 통으로 등록
--config.on_finish(completed): 이동 종료 시 콜백
--  completed = true  → 정상 완료 (모든 wp 소진)
--  completed = false → 중도 정지 (Stop 호출)
--
--waypoint 구조:
--  end_pos    : 도착 지점 (필수)
--  start_pos  : 시작 지점 (생략 시 이전 wp의 end_pos 또는 현재 fo 위치)
--  duration   : 이동 시간 (speed와 둘 중 하나)
--  speed      : 이동 속도 (duration과 둘 중 하나)
--  curve      : 곡선 설정 (생략 시 직선)
--    type     : Enum.CURVE_TYPE.BEZIER
--    x_max    : x축 베지어 제어점 최대값
--    y_max    : y축 베지어 제어점 최대값
--
--사용 예:
--  ball:SetPath({
--      { end_pos = pos1, duration = 0.5, curve = { type = Enum.CURVE_TYPE.BEZIER, y_max = 2 } },
--      { end_pos = pos2, speed = 8 },
--  }, {
--      on_finish = function(completed)
--          if completed then ... else ... end
--      end,
--  })
function BallController:SetPath(waypoints, config)
	config = config or {}
	self.wp_queue = {}
	self.on_finish = config.on_finish

	for i, wp in ipairs(waypoints) do
		local start_pos = wp.start_pos

		if not start_pos then
			if i > 1 then
				start_pos = waypoints[i - 1].end_pos
			else
				start_pos = self.obj.Position
			end
		end

		local duration = wp.duration

		if wp.speed and not duration then
			local dis = Util.Vector.Distance(start_pos, wp.end_pos)
			duration = dis / wp.speed
		end

		--곡선 함수 생성. 커스텀 함수가 있으면 우선 사용
		local x_move, y_move = self:BuildCurveFunctions(wp.curve)
		x_move = wp.x_move or x_move
		y_move = wp.y_move or y_move

		table.insert(self.wp_queue, {
			time_passed = 0,
			start_pos = start_pos,
			end_pos = wp.end_pos,
			duration = duration,
			x_move = x_move,
			y_move = y_move,
		})
	end
end

--endregion

--region 곡선 함수 생성

--2차 베지어 보간 함수 생성. max_val이 곡선의 정점
local function _build_bezier(max_val)
	return function(progress, start_val, end_val)
		local ctrl = 2 * max_val - (start_val + end_val) / 2
		local a = (1 - progress) * start_val + progress * ctrl
		local b = (1 - progress) * ctrl + progress * end_val
		return (1 - progress) * a + progress * b
	end
end

--curve 설정으로부터 x_move, y_move 함수를 만들어 반환
function BallController:BuildCurveFunctions(curve)
	if not curve then
		return nil, nil
	end

	local x_move, y_move

	if curve.type == Enum.CURVE_TYPE.BEZIER then
		if curve.x_max then
			x_move = _build_bezier(curve.x_max)
		end

		if curve.y_max then
			y_move = _build_bezier(curve.y_max)
		end
	end

	return x_move, y_move
end

--endregion

--region 이동 처리

--매 프레임 호출. 큐의 첫 번째 웨이포인트를 소비하며 이동
--코루틴 기반 move 호출 → 다음 프레임 update 사이에 1틱 깜빡임 방지를 위해 late_update에서 처리
function BallController:LateUpdate(dt)
	if self.obj == nil or #self.wp_queue == 0 then
		return
	end

	local current = self.wp_queue[1]

	current.time_passed = current.time_passed + dt

	local progress = math.min(current.time_passed / current.duration, 1)

	--기본 직선 보간
	local new_pos = Util.Vector.Lerp(current.start_pos, current.end_pos, progress)

	--곡선 함수가 있으면 해당 축 덮어쓰기
	if current.x_move then
		new_pos.x = current.x_move(progress, current.start_pos.x, current.end_pos.x)
	end

	if current.y_move then
		new_pos.y = current.y_move(progress, current.start_pos.y, current.end_pos.y)
	end

	self.obj.Position = new_pos

	--현재 웨이포인트 완료
	if progress >= 1 then
		self.obj.Position = current.end_pos

		-- NOTE: 이론상 QUEUE로 해야 하나 데이터수가 작아서 문제 없다고 생각.
		table.remove(self.wp_queue, 1)

		--프레임 스파이크 대응: 초과 시간이 다음 wp들의 duration보다 크면 계속 건너뜀
		local overflow = current.time_passed - current.duration

		while overflow > 0 and #self.wp_queue > 0 do
			local next_wp = self.wp_queue[1]

			if overflow >= next_wp.duration then
				--이 wp는 통째로 스킵
				self.obj.Position = next_wp.end_pos
				overflow = overflow - next_wp.duration
				table.remove(self.wp_queue, 1)
			else
				--남은 시간을 다음 wp에 넘겨줌
				next_wp.time_passed = overflow
				break
			end
		end

		--전체 경로 완료
		if #self.wp_queue == 0 then
			self:Finish(true)
		end
	end
end

--endregion

--region 대기/정지

--모든 웨이포인트 소진될 때까지 코루틴 대기
function BallController:WaitMoveEnd()
	while #self.wp_queue > 0 do
		coroutine.yield()
	end
end

--즉시 정지. on_finish(false) 호출 후 큐 비움
function BallController:Stop()
	self.wp_queue = {}
	self:Finish(false)
end

--on_finish 콜백 호출 및 상태 정리
function BallController:Finish(completed)
	local callback = self.on_finish
	self.on_finish = nil

	if callback then
		callback(completed)
	end
end

--endregion

return BallController
