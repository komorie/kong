--전역 열거형 테이블. 다른 파일에서 require 없이 Enum.xxx로 접근
Enum = {}

--타격 결과
Enum.HIT_RESULT = {
	STRIKE = 1,
	BALL_THROWN = 2,
	STRIKEOUT = 3,
	WALK = 4,
	GROUND_BALL = 5,
	FLY_BALL = 6,
	DOUBLE_PLAY = 7,
	SINGLE = 8,
	DOUBLE = 9,
	HOME_RUN = 10,
}

--주자 없음을 나타내는 값
Enum.RUNNER_NIL = -1

--곡선 타입
Enum.CURVE_TYPE = {
	BEZIER = 1,
}

--플레이어 구종
Enum.PITCH_TYPE = {
	FASTBALL = 1,
	SLIDER = 2,
	CURVE = 3,
	VERY_FAST_BALL = 4,
}

--게이지 타이밍 판정
Enum.TIMING_RESULT = {
	WEAK = 1,
	GOOD = 2,
	GREAT = 3,
	PERFECT = 4,
	MISS = 5,
}

--플레이 모드
Enum.MODE = {
	PITCHER = 1,
	BATTER = 2,
}

--투수 파워 상태
Enum.POWER_STATE = {
	NORMAL = 1,
	WEAK = 2,
	FULL = 3,
}
