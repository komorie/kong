--야구 미니게임 메인 루프.
--하이라이트 단위로 게임이 진행되며, 각 하이라이트 안에서 배틀(=타석)을 반복한다.
--하이라이트: 클리어/실패 조건이 있는 하나의 구간. 투수 모드면 3아웃까지, 타자 모드면 1타석일 수도 있음.
--배틀: 한 타자의 타석. 스트라이크/볼 투구를 반복하다 최종 타격 결과가 나오면 종료.

local Scoreboard = require('Scoreboard')
local BallController = require('BallController')
local Batter = require('Batter')
local PlayerPitcher = require('PlayerPitcher')
local HitScene = require('HitScene.HitScene')
local Defenders = require('HitScene.Defenders')
local Runners = require('HitScene.Runners')

local Game = class('Game')

local HIT_RESULT = Enum.HIT_RESULT
local MODE = Enum.MODE

---@class HighlightInfo
---@field mode number                    MODE.PITCHER or MODE.BATTER
---@field score_limit number|nil         투수 모드: 허용 실점 한도
---@field target_hit_result number|nil   타자 모드: 목표 HIT_RESULT
---@field base table                     초기 주자 배치 {타자idx, 1루, 2루, 3루}
---@field out number                     초기 아웃 카운트
---@field batter_count number            타순 인원 수 (기본 7)

--region 초기화/해제

function Game:init()
	--데이터
	self.section_id = Util.Section.GetId()
	self.common = Constants.COMMON
	self.highlight_infos = Constants.SECTION[self.section_id].highlight_infos
	self.player_team = Util.Obj.List('player_team')
	self.opposite_team = Util.Obj.List('opposite_team')

	--서브시스템 (Initialize에서 생성)
	self.scoreboard = nil
	self.ball = nil
	self.batter = nil
	self.opposite_pitcher = nil
	self.player_pitcher = nil
	self.hit_scene = nil
	self.defenders = nil
	self.runners = nil
	self.section = nil

	--상태
	self.cur_highlight_index = nil
	self.cur_batter_idx = nil
	self.cur_mode = nil
	self.offense_team = nil
	self.defense_team = nil
	self.cur_info = nil

	self:Initialize()
end

function Game:Initialize()
	local sz_obj = Util.Obj.Get('strike_zone')
	local strike_zone = Util.StrikeZone.New(sz_obj.Position, self.common.pitcher.strike_zone_half_size)

	--서브시스템 생성 및 초기화
	self.scoreboard = Scoreboard()

	self.ball = BallController()
	self.ball:Initialize(Util.Obj.Get('ball'))

	self.batter = Batter()
	self.batter:Initialize({ common = self.common, scoreboard = self.scoreboard })

	local op_class_name = Constants.SECTION[self.section_id].opposite_pitcher_class
	local OppositePitcherClass = require('OppositePitcher.' .. op_class_name)

	self.opposite_pitcher = OppositePitcherClass()
	self.opposite_pitcher:Initialize({
		ball = self.ball,
		scoreboard = self.scoreboard,
		common = self.common,
		strike_zone = strike_zone,
		obj = Util.Obj.Get('opposite_pitcher'),
	})

	self.player_pitcher = PlayerPitcher()
	self.player_pitcher:Initialize({
		ball = self.ball,
		common = self.common,
		strike_zone = strike_zone,
		obj = Util.Obj.Get('player_pitcher'),
	})

	self.defenders = Defenders()
	self.defenders:Initialize()

	self.runners = Runners()
	self.runners:Initialize({ runner_speed = self.common.runner_speed })

	self.hit_scene = HitScene()
	self.hit_scene:Initialize({
		ball = self.ball,
		common = self.common,
		defenders = self.defenders,
		runners = self.runners,
	})

	local SectionClass = require('Scenes.Section' .. self.section_id)
	self.section = SectionClass()
	self.section:Initialize({ scoreboard = self.scoreboard, common = self.common })

	self.cur_highlight_index = 1

	--게임 루틴 시작
	Util.Coroutine.Start(function()
		self:GameRoutine()
		self:Dispose()
	end)
end

function Game:Dispose()
	self.scoreboard:Dispose()
	self.ball:Dispose()
	self.batter:Dispose()
	self.opposite_pitcher:Dispose()
	self.player_pitcher:Dispose()
	self.hit_scene:Dispose()
	self.defenders:Dispose()
	self.runners:Dispose()
	self.section:Dispose()

	self.scoreboard = nil
	self.ball = nil
	self.batter = nil
	self.opposite_pitcher = nil
	self.player_pitcher = nil
	self.hit_scene = nil
	self.defenders = nil
	self.runners = nil
	self.section = nil
	self.section_id = nil
	self.common = nil
	self.highlight_infos = nil
	self.player_team = nil
	self.opposite_team = nil
	self.cur_highlight_index = nil
	self.cur_info = nil
	self.cur_batter_idx = nil
	self.cur_mode = nil
	self.offense_team = nil
	self.defense_team = nil
end

--endregion

--region 게임 루틴

--전체 하이라이트 루프. 코루틴에서 실행
function Game:GameRoutine()
	while self.cur_highlight_index <= #self.highlight_infos do
		self:SetBeforeHighlight()

		--하이라이트 시작 연출
		self.section:EnterHighlightIntro()
		self.section:HighlightIntro()
		self.section:ExitHighlightIntro()

		local is_clear = false
		local is_fail = false

		--첫 타석 세팅
		self:SetBeforeBattle()

		--배틀 루프: 클리어 or 실패할 때까지 타석 반복
		while not is_clear and not is_fail do
			local hit_result

			if self.section:UseCustomBattle() then
				--커스텀 배틀 (이벤트전 등)
				local api = self:BuildBattleApi(
					function() is_clear = true end,
					function() is_fail = true end
				)

				hit_result = self.section:CustomBattleRoutine(api)
			else
				--기본 투타 대결
				hit_result = self:DefaultBattleRoutine()

				if self:CheckFail(hit_result) then
					is_fail = true
				elseif self:CheckClear(hit_result) then
					is_clear = true
				end
			end

			--타격 종료 연출
			self.section:EnterBattleOutro()
			self.section:BattleOutro(hit_result)
			self.section:ExitBattleOutro()

			--클리어/실패 아니면 다음 타자로
			if not is_clear and not is_fail then
				self:SetBeforeNextBattle()
			end
		end

		--클리어 시 다음 하이라이트로, 실패 시 같은 하이라이트 반복
		if is_clear then
			self.scoreboard.prev_highlight_score = self.scoreboard.cur_highlight_score
			self.cur_highlight_index = self.cur_highlight_index + 1
		end
	end

	--전체 클리어
	self:GameClearScene()
end

--단일 투타 대결. 스/볼은 내부 루프, 그 외 결과 시 리턴
function Game:DefaultBattleRoutine()
	while true do
		local hit_result

		if self.cur_mode == MODE.PITCHER then
			local pitch_info = self.player_pitcher:Pitch()
			hit_result = self.batter:AiBatting(pitch_info)
		else
			local pitch_info = self.opposite_pitcher:Pitch()
			hit_result = self.batter:PlayerBatting(pitch_info)
		end

		--세부 타입 랜덤 선택
		local type_count = self.common.hit_type_count[hit_result] or 1
		local hit_type = Util.Random.Int(1, type_count)

		--스코어보드 갱신(데이터는 여기서 한번에 변경)
		self.scoreboard:RefreshWithHitResult(hit_result, hit_type)

		--타격 연출(오직 로직만)
		self.hit_scene:Execute(hit_result, hit_type)

		--스/볼이면 다음 투구 계속, 그 외는 타석 종료
		if hit_result ~= HIT_RESULT.STRIKE and hit_result ~= HIT_RESULT.BALL_THROWN then
			return hit_result
		end
	end
end

--endregion

--region 세팅

--하이라이트 시작 전 세팅
function Game:SetBeforeHighlight()
	self.cur_info = self.highlight_infos[self.cur_highlight_index]
	self.cur_mode = self.cur_info.mode
	self.cur_batter_idx = self.cur_info.base[1]

	--공수 팀 결정
	if self.cur_mode == MODE.PITCHER then
		self.defense_team = self.player_team
		self.offense_team = self.opposite_team
	else
		self.defense_team = self.opposite_team
		self.offense_team = self.player_team
	end

	--스코어보드 초기화
	self.scoreboard:SetBeforeHighlight(self.cur_info.base, self.cur_info.out)

	--수비수 배치 (팀 배열 자체가 수비수 오브젝트 목록)
	self.defenders:SetBeforeHighlight(self.defense_team)

	--섹션 연출 초기화
	self.section:SetBeforeHighlight(self.cur_highlight_index)
end

--개별 타석 시작 전 세팅
function Game:SetBeforeBattle()
	self.scoreboard:SetBeforeBattle(self.cur_batter_idx)
	self.runners:SetBeforeBattle(self.offense_team, self.scoreboard.base)
	self.section:PlaceDefaultPos()

	--투수 세팅
	local pitcher_obj = self.defense_team[self.common.pitcher_idx]

	if self.cur_mode == MODE.PITCHER then
		self.player_pitcher:SetBeforeBattle(pitcher_obj)
	else
		self.opposite_pitcher:SetBeforeBattle(pitcher_obj)
	end

	--타자 세팅
	local batter_obj = self.offense_team[self.cur_batter_idx]
	self.batter:SetBeforeBattle(batter_obj)
end

--다음 타자로 교체 후 타석 세팅
function Game:SetBeforeNextBattle()
	local batter_count = self.cur_info.batter_count or 7

	self.cur_batter_idx = self.cur_batter_idx % batter_count + 1
	self:SetBeforeBattle()
end

--endregion

--region 승패 판정

--실패 조건 검사
function Game:CheckFail(hit_result)
	if self.cur_mode == MODE.BATTER then
		--타자: 목표가 있고, 목표 결과가 아니면 실패
		local target = self.cur_info.target_hit_result
		return target and hit_result ~= target
	else
		--투수: 실점 한도 이상이면 실패
		local limit = self.cur_info.score_limit
		return limit and self.scoreboard.cur_highlight_score >= limit
	end
end

--클리어 조건 검사
function Game:CheckClear(hit_result)
	if self.cur_mode == MODE.BATTER then
		--타자: 목표 달성 시 클리어 (목표 없으면 자동 클리어)
		local target = self.cur_info.target_hit_result
		return not target or hit_result == target
	else
		--투수: 3아웃 잡으면 클리어
		return self.scoreboard:IsInningEnd()
	end
end

--endregion

--region BattleApi

--커스텀 배틀 루틴에 전달할 파사드 생성
function Game:BuildBattleApi(set_clear, set_fail)
	return {
		default_battle = function()
			return self:DefaultBattleRoutine()
		end,
		scoreboard = self.scoreboard,
		player_pitcher = self.player_pitcher,
		opposite_pitcher = self.opposite_pitcher,
		ball = self.ball,
		set_clear = set_clear,
		set_fail = set_fail,
	}
end

--endregion

--region 연출 의사함수

--전체 클리어 시 연출
function Game:GameClearScene()
end

--endregion

return Game
