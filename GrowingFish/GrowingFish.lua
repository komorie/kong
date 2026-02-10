--Lua에서 클래스 상속을 구현하기 위한 함수. (미테스트)
local function class(classname, super)
	local cls = {}
	cls.__index = cls
	cls.__classname = classname

	-- 상속 처리
	if super then
		setmetatable(cls, { __index = super })
		cls.super = super
	end

	-- 인스턴스 생성을 위한 메타테이블 설정
	local mt = getmetatable(cls) or {}

	mt.__call = function(_, ...)
		local instance = setmetatable({}, cls)
		if instance.init then
			instance:init(...)
		end
		return instance
	end

	setmetatable(cls, mt)

	return cls
end

--region Vector2
---@class Vector2 2차원 벡터 클래스. 사칙연산 오버로딩은 생략
---@field x number
---@field y number
local Vector2 = class("Vector2")

function Vector2:init(x, y)
	self.x = x
	self.y = y
end

--벡터의 길이 반환
function Vector2:Magnitude()
	return math.sqrt(self.x ^ 2 + self.y ^ 2)
end

--정규화된 벡터 반환
function Vector2:Normalized()
	local len = self:Magnitude()

	if len > 0 then
		return self / len
	end

	return Vector2.Zero()
end

-- [정적 함수] 내적 (Dot Product)
function Vector2.Dot(lhs, rhs)
	return lhs.x * rhs.x + lhs.y * rhs.y
end

-- [정적 함수] 선형 보간 (Lerp)
function Vector2.Lerp(a, b, t)
	return a + (b - a) * t -- 연산자 오버로딩 활용
end

-- [정적 함수] 거리 (Distance)
function Vector2.Distance(a, b)
	return (a - b):Magnitude()
end

function Vector2.Zero()
	return Vector2(0, 0)
end
--endregion

local MathUtil = {
	-- AABB 충돌 체크
	-- src, dest는 { min={x,y}, max={x,y} } 형태의 bounds 테이블
	CheckCollision = function(src, dest)
		return src.max.x >= dest.min.x and src.min.x <= dest.max.x and
				src.max.y >= dest.min.y and src.min.y <= dest.max.y
	end,

	-- 테이블 섞기 (Fisher-Yates Shuffle)
	Shuffle = function(t)
		for i = #t, 2, -1 do
			local j = math.random(i)
			t[i], t[j] = t[j], t[i]
		end
	end
}

--조이스틱 인풋 벡터 반환하는 추상 함수
local Input = {
	GetAxis = function()
		return Vector2.Zero()
	end
}

---상수 데이터 테이블
local Const = require("GrowingFishConstants")

---@class PlayerFish 플레이어 물고기 컨트롤러
local PlayerFish = class("PlayerFish")

function PlayerFish:init()
	self.data = Const.Player

	-- 트랜스폼 정보
	self.pos = Vector2.Zero()
	self.velocity = Vector2.Zero()
	self.scale = self.data.START_SCALE

	-- 충돌 박스 정보
	self.bounds = {
		center = Vector2.Zero(),
		half_extents = Vector2.Zero(),
		min = Vector2.Zero(),
		max = Vector2.Zero()
	}

	self:UpdateBoundsState()
end

function PlayerFish:Update(dt)
	local input = Input.GetAxis()
	local is_moving = (input.x ~= 0 or input.y ~= 0)

	local acc = self.data.ACCELERATION
	local friction = self.data.FRICTION
	local map = Const.System.MAP_BOUNDS

	--가속도 및 저항 물리 로직
	if is_moving then
		-- X축 로직
		if input.x > 0 then
			-- 오른쪽 입력일 때, 만약 오른쪽 벽과 충돌 중이면 감속
			if self.bounds.max.x >= map.MAX_X then
				self.velocity.x = self.velocity.x - (acc * dt)
			else
				self.velocity.x = self.velocity.x + (acc * dt * input.x)
			end
		elseif input.x < 0 then
			-- 왼쪽 입력일 때, 만약 왼쪽 벽과 충돌 중이면 감속
			if self.bounds.min.x <= map.MIN_X then
				self.velocity.x = self.velocity.x + (acc * dt)
			else
				self.velocity.x = self.velocity.x + (acc * dt * input.x)
			end
		end

		-- Y축 로직
		if input.y > 0 then
			if self.bounds.max.y >= map.MAX_Y then
				self.velocity.y = self.velocity.y - (acc * dt)
			else
				self.velocity.y = self.velocity.y + (acc * dt * input.y)
			end
		elseif input.y < 0 then
			if self.bounds.min.y <= map.MIN_Y then
				self.velocity.y = self.velocity.y + (acc * dt)
			else
				self.velocity.y = self.velocity.y + (acc * dt * input.y)
			end
		end

		--이동 편의를 위해 가던 방향과 반대쪽 키를 누르면 빠르게 감속
		if Vector2.Dot(self.velocity, input) < 0 then
			local brake_force = self.velocity:Normalized() * (acc * dt)
			self.velocity = self.velocity - brake_force
		end

		-- 최대 속도 제한
		local speed = self.velocity:Magnitude()
		if speed > self.data.MAX_SPEED then
			self.velocity = self.velocity:Normalized() * self.data.MAX_SPEED
		end
	else
		--입력이 없을 때 마찰력에 의한 자연 감속
		local speed = self.velocity:Magnitude()
		local drop = friction * dt

		if speed > drop then
			local drop_vec = self.velocity:Normalized() * drop
			self.velocity = self.velocity - drop_vec
		else
			self.velocity = Vector2.Zero()
		end
	end

	--위치 업데이트 및 화면 이탈 방지
	local next_pos = self.pos + (self.velocity * dt)

	-- X축 이탈 체크 후 보정
	if (next_pos.x + self.bounds.half_extents.x) > map.MAX_X then
		next_pos.x = map.MAX_X - self.bounds.half_extents.x
	elseif (next_pos.x - self.bounds.half_extents.x) < map.MIN_X then
		next_pos.x = map.MIN_X + self.bounds.half_extents.x
	end

	-- Y축 이탈 체크 후 보정
	if (next_pos.y + self.bounds.half_extents.y) > map.MAX_Y then
		next_pos.y = map.MAX_Y - self.bounds.half_extents.y
	elseif (next_pos.y - self.bounds.half_extents.y) < map.MIN_Y then
		next_pos.y = map.MIN_Y + self.bounds.half_extents.y
	end

	-- 최종 위치 적용 및 바운드 갱신
	self.pos = next_pos
	self:UpdateBoundsState()
end

function PlayerFish:UpdateBoundsState()
	-- 기본 박스 크기에 현재 스케일을 곱해 실제 크기 계산
	local def = self.data.DEFAULT_HALF_BOX
	self.bounds.half_extents = Vector2(def.x * self.scale, def.y * self.scale)

	self.bounds.center = self.pos
	self.bounds.min = self.pos - self.bounds.half_extents
	self.bounds.max = self.pos + self.bounds.half_extents
end

function PlayerFish:Grow(amount)
	self.scale = self.scale + amount
	self:UpdateBoundsState()
end

---@class BossFish 보스 물고기 컨트롤러
local BossFish = class("BossFish")

function BossFish:init()
	self.data = Const.Boss
	self.active = false

	self.pos = Vector2.Zero()
	self.scale = self.data.SCALE

	self.bounds = {
		center = Vector2.Zero(),
		half_extents = Vector2.Zero(),
		min = Vector2.Zero(),
		max = Vector2.Zero()
	}

	--첫 NextWaypoint 호출 시 1번 웨이포인트를 바라보게 함
	self.wp_idx = 0
	self.time_passed = 0
	self.start_pos = Vector2.Zero();
	self.target_pos = Vector2.Zero()
	self.move_t = 0;
	self.duration = 0

	self:UpdateBoundsState()
end

function BossFish:Update(dt)
	self.time_passed = self.time_passed + dt

	--스폰 시간이 되면 스폰
	if not self.active then
		if self.time_passed >= self.data.SPAWN_TIME then
			self:Spawn()
		end

		return
	end

	--선형 보간으로 다음 목적지 이동
	self.move_t = self.move_t + dt
	local t = self.move_t / self.duration

	if t >= 1.0 then
		self:NextWaypoint()
	else
		self.pos = Vector2.Lerp(self.start_pos, self.target_pos, t)
	end

	--히트박스 갱신
	self:UpdateBoundsState()
end

function BossFish:UpdateBoundsState()
	local def = self.data.DEFAULT_HALF_BOX
	self.bounds.half_extents = Vector2(def.x * self.scale, def.y * self.scale)
	self.bounds.min = self.pos - self.bounds.half_extents
	self.bounds.max = self.pos + self.bounds.half_extents
end

--시작 위치에 생성
function BossFish:Spawn()
	self.active = true

	local start = self.data.START_POS
	self.pos = Vector2(start.x, start.y)
	self:NextWaypoint()
end

--다음 wp로 목적지 지정
function BossFish:NextWaypoint()
	self.wp_idx = (self.wp_idx % #self.data.WAYPOINTS) + 1
	self.start_pos = self.pos

	local wp = self.data.WAYPOINTS[self.wp_idx]
	self.target_pos = Vector2(wp.x, wp.y)

	self.duration = Vector2.Distance(self.start_pos, self.target_pos) / self.data.SPEED
	self.move_t = 0
end

---@class NormalFish
local NormalFish = class("NormalFish")

function NormalFish:init(type)
	self.active = false
	self.pos = Vector2.Zero()
	self.scale = 1.0

	--외형 타입 (1, 2, 3 중 하나)
	self.fish_type = type

	self.bounds = { half_extents = Vector2.Zero(), min = Vector2.Zero(), max = Vector2.Zero() }
	self.start_pos = Vector2.Zero();
	self.end_pos = Vector2.Zero()
	self.duration = 0;
	self.timer = 0
end

function NormalFish:Setup(start_pos, end_pos, scale, speed)
	self.active = true
	self.pos = start_pos
	self.start_pos = start_pos;
	self.end_pos = end_pos
	self.scale = scale
	self.duration = Vector2.Distance(start_pos, end_pos) / speed
	self.timer = 0

	self:UpdateBoundsState()
end

function NormalFish:Update(dt)
	if not self.active then
		return
	end

	self.timer = self.timer + dt
	local t = self.timer / self.duration

	if t >= 1.0 then
		self.active = false
	else
		self.pos = Vector2.Lerp(self.start_pos, self.end_pos, t)
		self:UpdateBoundsState()
	end
end

function NormalFish:UpdateBoundsState()
	local def = Const.NormalFish.DEFAULT_HALF_BOX
	self.bounds.half_extents = Vector2(def.x * self.scale, def.y * self.scale)
	self.bounds.min = self.pos - self.bounds.half_extents
	self.bounds.max = self.pos + self.bounds.half_extents
end


---@class FishPool 오브젝트풀
local FishPool = class("FishPool")

function FishPool:init(max_count)
	self.available_stack = {}

	--3가지 타입을 균등하게 생성하여 넣음
	local type_count = Const.NormalFish.FISH_TYPE_COUNT
	local count_per_type = math.floor(max_count / type_count)

	for type_idx = 1, type_count do
		for i = 1, count_per_type do
			local fish = NormalFish(type_idx)

			table.insert(self.available_stack, fish)
		end
	end

	while #self.available_stack < max_count do
		local fish = NormalFish(1)
		table.insert(self.available_stack, fish)
	end

	--초기화 시 한 번 섞어서 랜덤 순서 보장
	MathUtil.Shuffle(self.available_stack)
end

-- 스택에서 객체 꺼내기
function FishPool:Get()
	if #self.available_stack > 0 then
		return table.remove(self.available_stack)
	end

	return nil
end

-- 스택에 객체 반납 (Push)
function FishPool:Return(fish)
	table.insert(self.available_stack, fish)
end

---@class GrowingFishGame 미니게임 본체
local GrowingFishGame = class("GrowingFishGame")

function GrowingFishGame:init()
	self.states = {
		PLAYING = 1,
		CLEAR = 2,
		FAIL = 3
	}

	self.current_state = self.states.PLAYING
	self.phase = 1

	self.player = PlayerFish()
	self.boss = BossFish()
	self.active_fishes = {} -- 활성화된 물고기 리스트
	self.fish_pool = FishPool(Const.NormalFish.POOL_COUNT)
	self.spawn_timer = 0
end

function GrowingFishGame:Update(dt)
	if self.current_state ~= self.states.PLAYING then
		return
	end

	self.player:Update(dt)
	self.boss:Update(dt)

	-- 활성 물고기 업데이트 (역순 순회로 안전하게 제거)
	for i = #self.active_fishes, 1, -1 do
		local fish = self.active_fishes[i]

		fish:Update(dt)

		--물고기가 비활성 상태면 관리자가 수거
		if not fish.active then
			self:DespawnNormalFish(i)
		end
	end

	self:UpdateSpawner(dt)
	self:CheckCollisions()
	self:CheckGameCondition()
end

--일반 물고기 수거 통합 함수
function GrowingFishGame:DespawnNormalFish(index)
	local fish = self.active_fishes[index]

	if fish then
		fish.active = false             -- 확실하게 끄기
		self.fish_pool:Return(fish)     -- 풀에 반납
		table.remove(self.active_fishes, index) -- 리스트 제거
	end
end

--좌우에서 일반 물고기 주기적으로 스폰
function GrowingFishGame:UpdateSpawner(dt)
	self.spawn_timer = self.spawn_timer + dt
	if self.spawn_timer >= Const.NormalFish.SPAWN_INTERVAL then
		self.spawn_timer = 0

		-- 풀에서 물고기 가져오기
		local fish = self.fish_pool:Get()
		if fish then
			local map = Const.System.MAP_BOUNDS
			-- Y축 랜덤 위치, 좌우 끝 중 어디에 소환할지 방향 결정
			local y_pos = math.random() * (map.MAX_Y - map.MIN_Y) + map.MIN_Y
			local is_left = math.random() > 0.5

			local start_pos = Vector2(is_left and map.MIN_X or map.MAX_X, y_pos)
			local end_pos = Vector2(is_left and map.MAX_X or map.MIN_X, y_pos)

			local scales = Const.NormalFish.SCALE_PER_PHASE[self.phase]
			local scale = scales[math.random(#scales)]

			fish:Setup(start_pos, end_pos, scale, Const.NormalFish.BASE_SPEED)
			table.insert(self.active_fishes, fish)
		end
	end
end

function GrowingFishGame:CheckCollisions()
	-- 보스와 충돌 체크 (AABB)
	if self.boss.active and MathUtil.CheckCollision(self.player.bounds, self.boss.bounds) then
		self:SetGameOver(false);
		return
	end

	-- 일반 물고기들과 충돌 체크
	for i = #self.active_fishes, 1, -1 do
		local fish = self.active_fishes[i]
		if MathUtil.CheckCollision(self.player.bounds, fish.bounds) then
			if self.player.scale >= fish.scale then
				self.player:Grow(0.1)
				self:DespawnNormalFish(i)-- 먹힘 -> 풀 반납
			else
				self:SetGameOver(false);
				return
			end
		end
	end
end

--페이즈 상승 및 클리어 조건 체크
function GrowingFishGame:CheckGameCondition()
	local next_scale = Const.System.PHASE_PROGRESS_SCALES[self.phase]

	if next_scale and self.player.scale >= next_scale then
		self.phase = self.phase + 1
	end

	if self.player.scale >= Const.Player.MAX_SCALE then
		self:SetGameOver(true)
	end
end

function GrowingFishGame:SetGameOver(is_clear)
	self.current_state = is_clear and self.states.CLEAR or self.states.FAIL
	print(is_clear and "Game Clear!" or "Game Over...")
end

return GrowingFishGame