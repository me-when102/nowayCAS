local UserFunctions = {}

-------------------------------------------------------
-- User Functions
-------------------------------------------------------

UserFunctions.registry = {}

function UserFunctions.define(name, params, bodyAST)
	UserFunctions.registry[name] = {
		params = params,
		body = bodyAST,
	}
end

function UserFunctions.lookup(name)
	return UserFunctions.registry[name]
end

return UserFunctions