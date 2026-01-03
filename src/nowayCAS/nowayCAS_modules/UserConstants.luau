local UserConstants = {}

-------------------------------------------------------
-- User-defined Functions
-- Constants that are created via definition and can be used globally.
-------------------------------------------------------

UserConstants.registry = {}

-- Defines a user-defined constant.
-- Name: the name of the constant.
-- Value: the value that the constant will hold.
function UserConstants.define(name, value)
	UserConstants.registry[name] = value
end

-- Look-ups the constant with the constant's name into the registry.
function UserConstants.lookup(name)
	return UserConstants.registry[name]
end

-- Checks if the name (identifier) is a constant.
function UserConstants.isConstant(name)
	return UserConstants.registry[name] ~= nil
end

-- The User-defined Constants sub-library.
return UserConstants