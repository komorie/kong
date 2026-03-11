--클래스 상속 구현. 전역 class() 함수를 제공
--사용: local MyClass = class('MyClass', SuperClass)
--인스턴스 생성: local obj = MyClass(args)
--부모 메서드 호출: self.super.init(self) (: 아님, . 으로 호출해야 self가 올바르게 전달됨)
function class(classname, super)
	local cls = {}
	cls.__index = cls
	cls.__classname = classname

	local mt = {}

	if super then
		mt.__index = super
		cls.super = super
	end

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
