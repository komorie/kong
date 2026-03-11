--전역 상수 테이블. 다른 파일에서 require 없이 Constants.xxx로 접근
Constants = {}

local HIT_RESULT = Enum.HIT_RESULT
local TIMING_RESULT = Enum.TIMING_RESULT
local PITCH_TYPE = Enum.PITCH_TYPE
local POWER_STATE = Enum.POWER_STATE
local RUNNER_NIL = Enum.RUNNER_NIL
local MODE = Enum.MODE

--region 공통

Constants.COMMON = {
	--투수 포지션 인덱스 (팀 배열 내)
	pitcher_idx = 1,

	--주자 이동 속도
	runner_speed = 5,

	--타격 결과별 세부 타입 수
	hit_type_count = {
		[HIT_RESULT.GROUND_BALL] = 4,
		[HIT_RESULT.FLY_BALL] = 3,
		[HIT_RESULT.DOUBLE_PLAY] = 3,
		[HIT_RESULT.SINGLE] = 4,
		[HIT_RESULT.DOUBLE] = 4,
		[HIT_RESULT.HOME_RUN] = 3,
	},

	pitcher = {
		--투수 오브젝트 중심으로부터 투구 시작 위치 오프셋
		pitch_start_offset = Util.Vector.New(-0.15, 0, 0),

		--스트라이크 존 반크기 (중심으로부터 x, y 거리)
		strike_zone_half_size = Util.Vector.New(0.5, 0.8, 0),

		--스트라이크 존 중심으로부터의 도착 오프셋
		throw_pos = {
			strike = {
				Util.Vector.New(0.3, 0, 0),
				Util.Vector.New(0, 0, 0),
				Util.Vector.New(-0.3, 0, 0),
			},
			ball_thrown = {
				Util.Vector.New(0.7, 0, 0),
				Util.Vector.New(-0.7, 0, 0),
			},
		},
	},

	opposite_pitcher = {
		--카운트별 스트라이크 존 안으로 던질 확률. [스트라이크][볼] = 확률
		strike_probability = {
			[0] = { [0] = 50, [1] = 70, [2] = 70, [3] = 100 },
			[1] = { [0] = 50, [1] = 70, [2] = 60, [3] = 100 },
			[2] = { [0] = 40, [1] = 40, [2] = 50, [3] = 100 },
		},

		--타이밍 판정별 타격 결과 확률
		hit_probability = {
			early_late = {
				ground_ball = {
					probability = 50,
					double_play = { probability = 70 },
					runner_selection = { probability = 30 },
				},
				fly_ball = { probability = 50 },
			},
		},
	},

	--타격 결과별 타구 연출 데이터. [HIT_RESULT][type] = { ball_bounces }
	--ball_bounces: 바운스 구간 배열. duration은 누적 시간, y_max는 베지어 높이
	hit_result_scene = {
		[HIT_RESULT.GROUND_BALL] = {
			--1루수 방향 땅볼
			[1] = {
				ball_bounces = {
					{ duration = 0.5, y_max = 1 },
					{ duration = 0.8, y_max = 0.3 },
					{ duration = 1, y_max = 0 },
				},
			},
			--2루수 방향 땅볼
			[2] = {
				ball_bounces = {
					{ duration = 0.5, y_max = 1 },
					{ duration = 1, y_max = 0.3 },
				},
			},
			--3루수 방향 땅볼
			[3] = {
				ball_bounces = {
					{ duration = 0.2, y_max = 1 },
					{ duration = 0.5, y_max = 0.3 },
				},
			},
			--투수 방향 땅볼
			[4] = {
				ball_bounces = {
					{ duration = 0.2, y_max = 0.3 },
					{ duration = 1, y_max = 3.5 },
				},
			},
		},

		[HIT_RESULT.FLY_BALL] = {
			[1] = { ball_bounces = { { duration = 4, y_max = 10 } } },
			[2] = { ball_bounces = { { duration = 4, y_max = 10 } } },
			[3] = { ball_bounces = { { duration = 4, y_max = 10 } } },
		},

		[HIT_RESULT.DOUBLE_PLAY] = {
			[1] = {
				ball_bounces = {
					{ duration = 0.2, y_max = 1 },
					{ duration = 0.5, y_max = 0.3 },
				},
			},
			[2] = {
				ball_bounces = {
					{ duration = 0.5, y_max = 1 },
					{ duration = 0.8, y_max = 0.3 },
					{ duration = 1, y_max = 0 },
				},
			},
			[3] = {
				ball_bounces = {
					{ duration = 0.5, y_max = 1 },
					{ duration = 1, y_max = 0.3 },
				},
			},
		},

		[HIT_RESULT.SINGLE] = {
			[1] = { ball_bounces = { { duration = 0.3, y_max = 2 }, { duration = 1.5, y_max = 0.5 } } },
			[2] = { ball_bounces = { { duration = 0.3, y_max = 2 }, { duration = 1.5, y_max = 0.5 } } },
			[3] = { ball_bounces = { { duration = 0.3, y_max = 2 }, { duration = 1.5, y_max = 0.5 } } },
			[4] = { ball_bounces = { { duration = 0.3, y_max = 2 }, { duration = 1.5, y_max = 0.5 } } },
		},

		[HIT_RESULT.DOUBLE] = {
			[1] = { ball_bounces = { { duration = 0.5, y_max = 3 }, { duration = 2, y_max = 1 } } },
			[2] = { ball_bounces = { { duration = 0.5, y_max = 3 }, { duration = 2, y_max = 1 } } },
			[3] = { ball_bounces = { { duration = 0.5, y_max = 3 }, { duration = 2, y_max = 1 } } },
			[4] = { ball_bounces = { { duration = 0.5, y_max = 3 }, { duration = 2, y_max = 1 } } },
		},

		[HIT_RESULT.HOME_RUN] = {
			[1] = { ball_bounces = { { duration = 5, y_max = 15 } } },
			[2] = { ball_bounces = { { duration = 5, y_max = 15 } } },
			[3] = { ball_bounces = { { duration = 5, y_max = 15 } } },
		},
	},
}

--endregion

--region 투수별 상수

Constants.FASTBALL_PITCHER = {
	fastball = {
		-- 플레이어가 타격 버튼 누를 시, 해당 테이블의 시간초에 맞게 타이밍 결과를 리턴
		timing = {
			duration = 1.2,
			very_early = { start = 0, finish = 0.84 },
			early = { start = 0.84, finish = 0.9 },
			good = {
				start = 0.9, finish = 1.08,
				single = { segments = { { start = 0.9, finish = 0.936 }, { start = 1.044, finish = 1.08 } } },
				double = { segments = { { start = 0.936, finish = 0.972 }, { start = 1.008, finish = 1.044 } } },
			},
			perfect = { start = 0.972, finish = 1.008 },
			late = { start = 1.08, finish = 1.14 },
			very_late = { start = 1.14 },
		},
	},
}

Constants.SINE_PITCHER = {
	--구종 선택 확률
	probability = {
		fastball = 50,
		sine_ball = 50,
	},

	fastball = {
		timing = {
			duration = 1,
			very_early = { start = 0, finish = 0.7 },
			early = { start = 0.7, finish = 0.75 },
			good = {
				start = 0.75, finish = 0.9,
				single = { segments = { { start = 0.75, finish = 0.78 }, { start = 0.87, finish = 0.9 } } },
				double = { segments = { { start = 0.78, finish = 0.81 }, { start = 0.84, finish = 0.87 } } },
			},
			perfect = { start = 0.81, finish = 0.84 },
			late = { start = 0.9, finish = 1 },
			very_late = { start = 1 },
		},
	},

	sine_ball = {
		--사인파 진폭
		amplitude = 0.5,

		--사인파 반복 횟수
		wave_count = 20,

		timing = {
			duration = 2,
			very_early = { start = 0, finish = 1.4 },
			early = { start = 1.4, finish = 1.5 },
			good = {
				start = 1.5, finish = 1.8,
				single = { segments = { { start = 1.5, finish = 1.56 }, { start = 1.74, finish = 1.8 } } },
				double = { segments = { { start = 1.56, finish = 1.62 }, { start = 1.68, finish = 1.74 } } },
			},
			perfect = { start = 1.62, finish = 1.68 },
			late = { start = 1.8, finish = 1.9 },
			very_late = { start = 1.9 },
		},
	},
}

Constants.METEOR_PITCHER = {
	probability = {
		fastball = 25,
		meteor_ball = 75,
	},

	fastball = {
		timing = {
			duration = 0.8,
			very_early = { start = 0, finish = 0.56 },
			early = { start = 0.56, finish = 0.6 },
			good = {
				start = 0.6, finish = 0.72,
				single = { segments = { { start = 0.6, finish = 0.624 }, { start = 0.696, finish = 0.72 } } },
				double = { segments = { { start = 0.624, finish = 0.648 }, { start = 0.672, finish = 0.696 } } },
			},
			perfect = { start = 0.648, finish = 0.672 },
			late = { start = 0.72, finish = 0.8 },
			very_late = { start = 0.8 },
		},
	},

	meteor_ball = {
		--공 시작 위치 오프셋 (투수 기준)
		ball_start_offset = Util.Vector.New(0, 0, -1),

		--상승 도착 위치 오프셋 (투수 기준)
		hover_offset = Util.Vector.New(0, 2.35, 0),

		--1단계 투수 머리위 상승 궤적
		rise_duration = 1,
		rise_y_max = 3,

		--QTE 터치 수
		qte_count = 10,

		--QTE 제한 시간
		qte_time = 4,

		--2단계 이동 궤적(1단계 종료 위치로부터 더 올라갔다 내려옴)
		trajectory = {
			first_half_offset = Util.Vector.New(0, 10, -8),
			first_half_duration = 1,
			last_half_duration = 1,
		},

		timing = {
			duration = 2,

			very_early = { start = 0, finish = 1.35 },
			early = { start = 1.35, finish = 1.45 },
			good = {
				start = 1.45, finish = 1.75,
				single = { segments = { { start = 1.45, finish = 1.51 }, { start = 1.69, finish = 1.75 } } },
				double = { segments = { { start = 1.51, finish = 1.55 }, { start = 1.65, finish = 1.69 } } },
			},
			perfect = { start = 1.55, finish = 1.65 },
			late = { start = 1.75, finish = 1.85 },
			very_late = { start = 1.85 },
		},
	},
}

Constants.TRICK_PITCHER = {
	--구종 선택 확률
	probability = {
		fastball = 20,
		zigzag_ball = 40,
		invisible_ball = 40,
	},

	--풀카운트 시 구종 확률
	probability_2s3b = {
		zigzag_ball = 50,
		invisible_ball = 50,
	},

	fastball = {
		timing = {
			duration = 0.8,
			very_early = { start = 0, finish = 0.56 },
			early = { start = 0.56, finish = 0.6 },
			good = {
				start = 0.6, finish = 0.72,
				single = { segments = { { start = 0.6, finish = 0.624 }, { start = 0.696, finish = 0.72 } } },
				double = { segments = { { start = 0.624, finish = 0.648 }, { start = 0.672, finish = 0.696 } } },
			},
			perfect = { start = 0.648, finish = 0.672 },
			late = { start = 0.72, finish = 0.8 },
			very_late = { start = 0.8 },
		},
	},

	zigzag_ball = {
		--경유 지점 (투수 위치 기준 오프셋)
		offsets = {
			Util.Vector.New(2, 0, -2),
			Util.Vector.New(1.5, 1, -2.5),
			Util.Vector.New(-2, 0, -2),
			Util.Vector.New(-1.5, 0, -3),
			Util.Vector.New(0, 0, -2.5),
			Util.Vector.New(0.5, 1, -3.5),
		},

		timing = {
			duration = 1.2,
			very_early = { start = 0, finish = 0.84 },
			early = { start = 0.84, finish = 0.9 },
			good = {
				start = 0.9, finish = 1.08,
				single = { segments = { { start = 0.9, finish = 0.936 }, { start = 1.044, finish = 1.08 } } },
				double = { segments = { { start = 0.936, finish = 0.972 }, { start = 1.008, finish = 1.044 } } },
			},
			perfect = { start = 0.972, finish = 1.008 },
			late = { start = 1.08, finish = 1.2 },
			very_late = { start = 1.2 },
		},
	},

	invisible_ball = {
		--사라지는 시점 (투구 시작 기준)
		disappear_time = 0.4,

		--나타나는 시점
		appear_time = 1.4,

		timing = {
			duration = 2,
			very_early = { start = 0, finish = 1.4 },
			early = { start = 1.4, finish = 1.5 },
			good = {
				start = 1.5, finish = 1.8,
				single = { segments = { { start = 1.5, finish = 1.56 }, { start = 1.74, finish = 1.8 } } },
				double = { segments = { { start = 1.56, finish = 1.62 }, { start = 1.68, finish = 1.74 } } },
			},
			perfect = { start = 1.62, finish = 1.68 },
			late = { start = 1.8, finish = 1.9 },
			very_late = { start = 1.9 },
		},
	},
}

--endregion

--region 플레이어 투수

Constants.PLAYER_PITCHER = {
	--포수 리드 확률
	lead_probability = {
		fastball = 40,
		slider = 30,
		curve = 30,
	},

	--게이지 설정
	gauge = {
		duration = 0.9,

		--파워 상태별 고정 타이밍. [POWER_STATE] = 타이밍 테이블
		--NORMAL은 여기 없음 — pitch_timing에서 구종/리드별로 결정
		power_timing = {
			--WEAK: 전 구간 위크 (이벤트성 상태)
			[POWER_STATE.WEAK] = {
				weak = { start = 0, finish = 0.9 },
				good = { start = -1, finish = -1 },
				great = { start = -1, finish = -1 },
				perfect = { start = -1, finish = -1 },
				miss = { start = -1, finish = -1 },
			},

			--FULL: 전 구간 퍼펙트 (이벤트성 상태)
			[POWER_STATE.FULL] = {
				weak = { start = -1, finish = -1 },
				good = { start = -1, finish = -1 },
				great = { start = -1, finish = -1 },
				perfect = { start = 0, finish = 0.9 },
				miss = { start = -1, finish = -1 },
			},
		},

		--구종/리드별 게이지 타이밍. [PITCH_TYPE] = { lead, not_lead }
		--segments: 게이지가 대칭 구조라 구간이 둘로 나뉨
		pitch_timing = {
			--직구
			[PITCH_TYPE.FASTBALL] = {
				lead = {
					miss = { segments = { { start = 0, finish = 0.09 }, { start = 0.81, finish = 0.9 } } },
					weak = { segments = { { start = 0.09, finish = 0.27 }, { start = 0.63, finish = 0.81 } } },
					good = { segments = { { start = 0.27, finish = 0.315 }, { start = 0.585, finish = 0.63 } } },
					great = { segments = { { start = 0.315, finish = 0.36 }, { start = 0.54, finish = 0.585 } } },
					perfect = { start = 0.36, finish = 0.54 },
				},
				not_lead = {
					miss = { segments = { { start = 0, finish = 0.09 }, { start = 0.81, finish = 0.9 } } },
					weak = { segments = { { start = 0.09, finish = 0.315 }, { start = 0.585, finish = 0.81 } } },
					good = { segments = { { start = 0.315, finish = 0.36 }, { start = 0.54, finish = 0.585 } } },
					great = { segments = { { start = 0.36, finish = 0.405 }, { start = 0.495, finish = 0.54 } } },
					perfect = { start = 0.405, finish = 0.495 },
				},
			},

			--슬라이더
			[PITCH_TYPE.SLIDER] = {
				lead = {
					miss = { segments = { { start = 0, finish = 0.045 }, { start = 0.675, finish = 0.9 } } },
					weak = { segments = { { start = 0.045, finish = 0.09 }, { start = 0.45, finish = 0.675 } } },
					good = { segments = { { start = 0.09, finish = 0.135 }, { start = 0.405, finish = 0.45 } } },
					great = { segments = { { start = 0.135, finish = 0.18 }, { start = 0.36, finish = 0.405 } } },
					perfect = { start = 0.18, finish = 0.36 },
				},
				not_lead = {
					miss = { segments = { { start = 0, finish = 0.09 }, { start = 0.675, finish = 0.9 } } },
					weak = { segments = { { start = 0.09, finish = 0.135 }, { start = 0.405, finish = 0.675 } } },
					good = { segments = { { start = 0.135, finish = 0.18 }, { start = 0.36, finish = 0.405 } } },
					great = { segments = { { start = 0.18, finish = 0.225 }, { start = 0.315, finish = 0.36 } } },
					perfect = { start = 0.225, finish = 0.315 },
				},
			},

			--커브
			[PITCH_TYPE.CURVE] = {
				lead = {
					miss = { segments = { { start = 0, finish = 0.225 }, { start = 0.855, finish = 0.9 } } },
					weak = { segments = { { start = 0.225, finish = 0.45 }, { start = 0.81, finish = 0.855 } } },
					good = { segments = { { start = 0.45, finish = 0.495 }, { start = 0.765, finish = 0.81 } } },
					great = { segments = { { start = 0.495, finish = 0.54 }, { start = 0.72, finish = 0.765 } } },
					perfect = { start = 0.54, finish = 0.72 },
				},
				not_lead = {
					miss = { segments = { { start = 0, finish = 0.225 }, { start = 0.81, finish = 0.9 } } },
					weak = { segments = { { start = 0.225, finish = 0.495 }, { start = 0.765, finish = 0.81 } } },
					good = { segments = { { start = 0.495, finish = 0.54 }, { start = 0.72, finish = 0.765 } } },
					great = { segments = { { start = 0.54, finish = 0.585 }, { start = 0.675, finish = 0.72 } } },
					perfect = { start = 0.585, finish = 0.675 },
				},
			},

		},
	},

	--타이밍별 타격 결과 확률. [TIMING_RESULT] = 확률 테이블
	hit_result_probabilities = {
		--WEAK: 무조건 볼
		[TIMING_RESULT.WEAK] = {
			ball_thrown = 100,
		},

		--GOOD
		[TIMING_RESULT.GOOD] = {
			out_strike = {
				probability = 60,
				strike = { probability = 60 },
				ground_ball = {
					probability = 20,
					double_play = { probability = 70 },
					runner_selection = { probability = 30 },
				},
				fly_ball = { probability = 20 },
			},
			safe = {
				probability = 40,
				single = { probability = 60 },
				double = { probability = 30 },
				home_run = { probability = 10 },
			},
		},

		--GREAT
		[TIMING_RESULT.GREAT] = {
			out_strike = {
				probability = 80,
				strike = { probability = 60 },
				ground_ball = {
					probability = 20,
					double_play = { probability = 70 },
					runner_selection = { probability = 30 },
				},
				fly_ball = { probability = 20 },
			},
			safe = {
				probability = 20,
				single = { probability = 70 },
				double = { probability = 25 },
				home_run = { probability = 5 },
			},
		},

		--PERFECT: 100% 아웃/스트라이크
		[TIMING_RESULT.PERFECT] = {
			out_strike = {
				probability = 100,
				strike = { probability = 60 },
				ground_ball = {
					probability = 20,
					double_play = { probability = 70 },
					runner_selection = { probability = 30 },
				},
				fly_ball = { probability = 20 },
			},
		},

		--MISS: 거의 안타
		[TIMING_RESULT.MISS] = {
			out_strike = {
				probability = 10,
				ground_ball = {
					probability = 50,
					double_play = { probability = 70 },
					runner_selection = { probability = 30 },
				},
				fly_ball = { probability = 50 },
			},
			safe = {
				probability = 90,
				single = { probability = 60 },
				double = { probability = 30 },
				home_run = { probability = 10 },
			},
		},
	},

	--구종별 투구 데이터. [PITCH_TYPE] = { duration[TIMING_RESULT], swing_margin, ... }
	--구종에 hit_result_probabilities가 있으면 공통 테이블 대신 사용
	pitches = {
		--직구
		[PITCH_TYPE.FASTBALL] = {
			duration = {
				[TIMING_RESULT.WEAK] = 1.1, [TIMING_RESULT.GOOD] = 0.6, [TIMING_RESULT.GREAT] = 0.5,
				[TIMING_RESULT.PERFECT] = 0.4, [TIMING_RESULT.MISS] = 1.6,
			},
			swing_margin = 0.2,
		},

		--슬라이더
		[PITCH_TYPE.SLIDER] = {
			duration = {
				[TIMING_RESULT.WEAK] = 1.6, [TIMING_RESULT.GOOD] = 1.1, [TIMING_RESULT.GREAT] = 0.9,
				[TIMING_RESULT.PERFECT] = 0.7, [TIMING_RESULT.MISS] = 2.1,
			},
			swing_margin = 0.2,
			x_offset = 2,
		},

		--커브
		[PITCH_TYPE.CURVE] = {
			duration = {
				[TIMING_RESULT.WEAK] = 2.1, [TIMING_RESULT.GOOD] = 1.6, [TIMING_RESULT.GREAT] = 1.5,
				[TIMING_RESULT.PERFECT] = 1.4, [TIMING_RESULT.MISS] = 2.6,
			},
			swing_margin = 0.2,
			y_offset = 2,
		},

		--400km 직구 (각성). 타이밍 무관 동일 duration, 전용 확률 테이블
		[PITCH_TYPE.VERY_FAST_BALL] = {
			duration = {
				[TIMING_RESULT.WEAK] = 0.1, [TIMING_RESULT.GOOD] = 0.1, [TIMING_RESULT.GREAT] = 0.1,
				[TIMING_RESULT.PERFECT] = 0.1, [TIMING_RESULT.MISS] = 0.1,
			},
			swing_margin = 0.05,
			hit_result_probabilities = {
				[TIMING_RESULT.PERFECT] = {
					swing = { probability = 50 },
					looking = { probability = 50 },
				},
			},
		},
	},
}

--endregion

--region 섹션별 상수

Constants.SECTION = {
	--섹션 13 (예시)
	[13] = {
		--이 섹션에서 사용할 상대 투수 클래스 이름
		opposite_pitcher_class = 'FastballPitcher',

		highlight_infos = {
			--1회: 타자 모드, 주자 없음
			{ mode = MODE.BATTER, base = { 1, RUNNER_NIL, RUNNER_NIL, RUNNER_NIL }, out = 0 },
			--2회: 타자 모드, 홈런 달성 시 클리어
			{ mode = MODE.BATTER, target_hit_result = HIT_RESULT.HOME_RUN, base = { 1, RUNNER_NIL, RUNNER_NIL, RUNNER_NIL }, out = 0 },
			--3회: 투수 모드, 실점 한도 3
			{ mode = MODE.PITCHER, score_limit = 3, base = { 1, RUNNER_NIL, RUNNER_NIL, RUNNER_NIL }, out = 0 },
			--4회: 투수 모드, 커스텀 배틀 (2아웃 클리어)
			{ mode = MODE.PITCHER, score_limit = 1, base = { 1, RUNNER_NIL, RUNNER_NIL, RUNNER_NIL }, out = 0 },
			--5회: 투수 모드, 커스텀 배틀 (이벤트전)
			{ mode = MODE.PITCHER, base = { 1, RUNNER_NIL, RUNNER_NIL, RUNNER_NIL }, out = 0 },
		},
	},
}

--endregion
