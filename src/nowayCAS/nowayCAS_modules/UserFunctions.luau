local UserFunctions = {}

-------------------------------------------------------
-- User-defined Functions
-- Functions that are created via definition and can be used globally.
-------------------------------------------------------

-- list of available functions
UserFunctions.registry = {}

-- Defines a user-defined function.
-- Name: the name of the function, eg: 'f' = "f(...params)" when called.
-- Params: the parameters to substitute into the bodyString.
-- bodyString: the contents of the function, eg: 7x + 3
-- Eg: f(7, 4) = (2*(3y + 7x)) / 3 (x, y are params, f is name, (2*(3y + 7x)) / 3 is bodyString).
function UserFunctions.define(name, params, bodyAST)
	UserFunctions.registry[name] = {
		params = params,
		body = bodyAST,
	}
end

-- Look-ups the function with the function's name into the registry.
function UserFunctions.lookup(name)
	return UserFunctions.registry[name]
end

-- The User-defined Functions sub library.
return UserFunctions