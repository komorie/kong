--게임 밸런스 및 설정값 관리 - 수정 용이하도록

local Constants = {
	-- 시스템 설정
	System = {
		-- 맵 경계 (화면 크기)
		MAP_BOUNDS = {
			MIN_X = -8, MAX_X = 8,
			MIN_Y = -4.5, MAX_Y = 4.5
		},
		-- 단계별 성장 목표 크기 (플레이어가 이 크기에 도달하면 다음 단계로 진입)
		PHASE_PROGRESS_SCALES = { 1.1, 1.6, 2.1, 2.6, 3.1 }
	},

	-- 플레이어 설정
	Player = {
		START_POS = { x = 0, y = 0 },
		START_SCALE = 0.5,
		MAX_SCALE = 3.1,
		MAX_SPEED = 3.0,
		ACCELERATION = 4.0,    -- 이동 가속도
		FRICTION = 2.0,        -- 정지 마찰력
		-- 기본 충돌 박스 절반 크기 (Scale 1.0 기준)
		DEFAULT_HALF_BOX = { x = 0.275, y = 0.18 }
	},

	-- 보스 설정
	Boss = {
		SPAWN_TIME = 10,     -- 게임 시작 n초 후 등장
		SCALE = 3.5,
		SPEED = 2.5,
		DEFAULT_HALF_BOX = { x = 0.275, y = 0.18 },
		-- 순찰 경로 (웨이포인트)
		WAYPOINTS = {
			{ x = -6, y = 3 }, { x = 6, y = 3 },
			{ x = 6, y = -3 }, { x = -6, y = -3 }
		}
	},

	-- 일반 물고기 설정
	NormalFish = {
		SPAWN_INTERVAL = 1.0,  -- 생성 주기
		POOL_COUNT = 24,       -- 오브젝트 풀 크기
		BASE_SPEED = 2.0,
		DEFAULT_HALF_BOX = { x = 0.275, y = 0.13 },

		--물고기 외형 타입의 개수 (3종류)
		FISH_TYPE_COUNT = 3,

		-- 페이즈별 생성될 물고기 크기 목록
		SCALE_PER_PHASE = {
			{ 0.3, 0.5, 0.8 },
			{ 0.5, 0.8, 1.2 },
			{ 0.8, 1.2, 1.8 },
			{ 1.2, 1.8, 2.5 },
			{ 2.5, 3.0 }
		}
	}
}

return Constants