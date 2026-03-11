--전역 유틸. 다른 파일에서 require 없이 Util.xxx로 접근
Util = {}

--region Vector

Util.Vector = {}

--두 벡터 사이의 선형 보간. t = 0이면 a, t = 1이면 b
function Util.Vector.Lerp(a, b, t)
end

--두 벡터 사이의 거리 반환
function Util.Vector.Distance(a, b)
end

--Vector3 생성
function Util.Vector.New(x, y, z)
end

--endregion

--region Random

Util.Random = {}

--min~max 범위의 정수 랜덤 반환
function Util.Random.Int(min, max)
end

--endregion

--region Coroutine

Util.Coroutine = {}

--코루틴 시작
function Util.Coroutine.Start(func)
end

--지정 초만큼 대기
function Util.Coroutine.WaitSec(sec)
end

--endregion

--region Time

Util.Time = {}

--프레임 경과 시간 (Unity Time.deltaTime)
function Util.Time.DeltaTime()
end

--endregion

--region Input

Util.Input = {}

--지정 버튼이 눌려있는지 반환
function Util.Input.IsButtonDown(button)
end

--endregion

--region Obj

Util.Obj = {}

--이름으로 씬 오브젝트 참조 반환
function Util.Obj.Get(name)
end

--이름 기반 오브젝트 배열 반환. 인덱스로 각 요소에 접근
function Util.Obj.List(name)
end

--오브젝트 표시/숨김
function Util.Obj.SetVisible(obj, visible)
end

--endregion

--region Qte

Util.Qte = {}

--연타 QTE 실행. 제한 시간 내 count회 입력 성공 여부 반환
function Util.Qte.MashButton(count, time)
end

--endregion

--region Table

Util.Table = {}

--테이블 얕은 복사. 새 테이블 반환
function Util.Table.Copy(src)
end

--src의 내용을 dst에 덮어쓰기
function Util.Table.CopyInto(dst, src)
end

--endregion

--region Move

Util.Move = {}

--오브젝트를 목표 지점으로 duration초 동안 이동 (코루틴 내에서 동기 대기)
function Util.Move.To(obj, target_pos, duration)
end

--endregion

--region HitResult

Util.HitResult = {}

--타구가 맞은 결과인지 (스트라이크/볼/삼진/볼넷 제외)
function Util.HitResult.IsContact(hit_result)
	local HIT_RESULT = Enum.HIT_RESULT
	return hit_result ~= HIT_RESULT.STRIKE
		and hit_result ~= HIT_RESULT.STRIKEOUT
		and hit_result ~= HIT_RESULT.BALL_THROWN
		and hit_result ~= HIT_RESULT.WALK
end

--endregion

--region Timing

Util.Timing = {}

--시간이 범위 안에 있는지 판정. segments 지원
---@param time number
---@param range { start: number, finish?: number, segments?: { start: number, finish?: number }[] }
function Util.Timing.IsWithin(time, range)
	if range.segments then
		for _, seg in ipairs(range.segments) do
			if seg.finish then
				if time >= seg.start and time < seg.finish then
					return true
				end
			else
				if time >= seg.start then
					return true
				end
			end
		end
		return false
	end

	if range.finish then
		return time >= range.start and time < range.finish
	else
		return time >= range.start
	end
end

--endregion

--region StrikeZone

Util.StrikeZone = {}

--스트라이크 존 데이터 생성. { center, half_size }
function Util.StrikeZone.New(center, half_size)
	return { center = center, half_size = half_size }
end

--스/볼 여부에 따라 공 도착 지점 선택
function Util.StrikeZone.SelectEndPos(strike_zone, throw_pos, is_strike)
	if is_strike then
		local idx = Util.Random.Int(1, #throw_pos.strike)
		return strike_zone.center + throw_pos.strike[idx]
	else
		local idx = Util.Random.Int(1, #throw_pos.ball_thrown)
		return strike_zone.center + throw_pos.ball_thrown[idx]
	end
end

--endregion

--region Section

Util.Section = {}

--현재 섹션 ID 반환 (퀘스트 진행도 등에서 결정)
function Util.Section.GetId()
end

--endregion
