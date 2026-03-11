--주자 오브젝트 연출 관리 클래스.
--진루, 아웃 퇴장, 비동기 이동 대기 처리
local Runners = class('Runners')

local RUNNER_NIL = Enum.RUNNER_NIL

--region 초기화/해제

function Runners:init()
	self.objs = nil
	self.move_count = nil
	self.runner_speed = nil
end

function Runners:Initialize(data)
	self.objs = {}
	self.move_count = 0
	self.runner_speed = data.runner_speed
end

function Runners:Dispose()
	self.objs = nil
	self.move_count = nil
	self.runner_speed = nil
end

--각 타석 시작 전, 스코어보드의 base 배열로 주자 세팅
function Runners:SetBeforeBattle(team, base)
	for i = 1, #base do
		if base[i] ~= RUNNER_NIL then
			self.objs[i] = team[base[i]]
		else
			self.objs[i] = nil
		end
	end
end

--endregion

--region 조회

function Runners:Get(runner_num)
	return self.objs[runner_num]
end

--endregion

--region 진루

--특정 주자를 count만큼 진루 (비동기)
function Runners:Progress(runner_num, count)
	local obj = self.objs[runner_num]
	if not obj then return end

	self.move_count = self.move_count + 1

	Util.Coroutine.Start(function()
		--현재 루 → 목표 루까지 한 루씩 이동
		for i = 1, count do
			local next_base = runner_num + i
			local target = self:GetBasePos(next_base)
			if not target then break end

			local distance = Util.Vector.Distance(obj.Position, target)
			local duration = distance / self.runner_speed
			Util.Move.To(obj, target, duration)
		end

		self.move_count = self.move_count - 1
	end)
end

--전원 진루
function Runners:ProgressAll(count)
	for i = 1, 4 do
		self:Progress(i, count)
	end
end

--아웃 처리 (주자 퇴장)
function Runners:Out(runner_num)
	local obj = self.objs[runner_num]
	if not obj then return end

	self.objs[runner_num] = nil
	self:OutScene(obj)
end

--전원 이동 완료 대기
function Runners:WaitAll()
	while self.move_count > 0 do
		coroutine.yield()
	end
end

--endregion

--region 의사함수

--베이스 번호에 해당하는 위치 반환(1~4)
function Runners:GetBasePos(base_num)
end

--아웃 퇴장 연출
function Runners:OutScene(obj)
end

--endregion

return Runners
