--수비수 오브젝트 연출 관리 클래스
--수비수 이동, 송구, 비동기 이동 대기 처리
local Defenders = class('Defenders')

--region 초기화/해제

function Defenders:init()
	self.objs = nil
	self.move_count = nil
end

function Defenders:Initialize()
	self.objs = {}
	self.move_count = 0
end

function Defenders:Dispose()
	self.objs = nil
	self.move_count = nil
end

--하이라이트 시작 전 수비수 오브젝트 배치
function Defenders:SetBeforeHighlight(objs)
	self.objs = objs
end

--endregion

--region 조회

--수비 포지션 인덱스로 수비수 오브젝트 반환
function Defenders:Get(def_idx)
	return self.objs[def_idx]
end

--endregion

--region 이동

--수비수를 목표 지점으로 이동 (비동기)
function Defenders:Move(def_idx, target_pos, duration)
	local obj = self.objs[def_idx]
	self.move_count = self.move_count + 1

	Util.Coroutine.Start(function()
		Util.Move.To(obj, target_pos, duration)
		self.move_count = self.move_count - 1
	end)
end

--수비수 간 송구. 공을 from에서 to로 이동
function Defenders:Throw(ball, from_idx, to_idx, duration)
	local from_pos = self.objs[from_idx].Position
	local to_pos = self.objs[to_idx].Position

	ball:SetPath({
		{ start_pos = from_pos, end_pos = to_pos, duration = duration },
	})
	ball:WaitMoveEnd()
end

--전원 이동 완료 대기
function Defenders:WaitMoveEnd()
	while self.move_count > 0 do
		coroutine.yield()
	end
end

--endregion

return Defenders
