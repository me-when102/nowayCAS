local Assume = {}

-------------------------------------------------------
-- Assumptions System
-------------------------------------------------------

-- Internal store: symbol -> { tag = true, ... }
local store = {}

-- Implication lattice: tag -> { implied_tag = true, ... }
local implies = {
	positive = { nonzero = true, real = true },
	negative = { nonzero = true, real = true },
	natural = { integer = true, positive = true },
	integer = { real = true },

	-- Additions
	zero = { real = true },
	nonzero = { real = true },  -- if needed explicitly
	rational = { real = true },
	irrational = { real = true },
	complex = {},  -- base for all

	prime = { integer = true, positive = true },
	even = { integer = true },
	odd = { integer = true },

	-- For domains
	real = { complex = true },
}

-- Normalize symbol
local function normalizeSymbol(symbol)
	if typeof(symbol) == "table" then
		if symbol.kind == "var" and typeof(symbol.name) == "string" then
			return symbol.name
		end
	end

	-- Fallback: assume it's already a string
	return symbol
end

-- Ensure
local function ensure(symbol)
	store[symbol] = store[symbol] or {}
	return store[symbol]
end

-------------------------------------------------------
-- Assumptions API
-------------------------------------------------------

-- Replace all Assume for a symbol
-- Accepts either a tag string or array of tags.
function Assume.set(symbol, tags)
	symbol = normalizeSymbol(symbol)
	local out = {}

	if typeof(tags) == "table" then
		for _, tag in ipairs(tags) do
			out[tag] = true
		end
	else
		out[tags] = true
	end

	store[symbol] = out
end

-- Gets the assumption for a symbol
function Assume.get(symbol)
	symbol = normalizeSymbol(symbol)
	return store[symbol]
end

-- Add a tag to an existing symbol
function Assume.add(symbol, tag)
	symbol = normalizeSymbol(symbol)
	ensure(symbol)[tag] = true
end

-- Remove a tag from an existing symbol
function Assume.remove(symbol, tag)
	symbol = normalizeSymbol(symbol)
	local tags = store[symbol]
	if tags then
		tags[tag] = nil
		-- Optional: clean up empty tables
		if next(tags) == nil then
			store[symbol] = nil
		end
	end
end

-- Direct membership check (no implications)
function Assume.has(symbol, tag)
	symbol = normalizeSymbol(symbol)
	local tags = store[symbol]
	return tags ~= nil and tags[tag] == true
end

-- Query with implication lattice
function Assume.is(symbol, tag)
	symbol = normalizeSymbol(symbol)
	local tags = store[symbol]
	if not tags then
		return false
	end

	-- Direct tag
	if tags[tag] then
		return true
	end

	-- Check implied tags
	for t in pairs(tags) do
		local implied = implies[t]
		if implied and implied[tag] then
			return true
		end
	end

	return false
end

-- Gets the tag from the implication table
function Assume.implies(tag)
	return implies[tag]
end

-- Determines if the symbol has any of these tags (or)
function Assume.any(symbol, tagList)
	for _, tag in ipairs(tagList) do
		if Assume.is(symbol, tag) then
			return true
		end
	end
	return false
end

-- Determines if the symbol has all of these tags (and)
function Assume.all(symbol, tagList)
	for _, tag in ipairs(tagList) do
		if not Assume.is(symbol, tag) then
			return false
		end
	end
	return true
end

-- Clear Assume for one symbol
function Assume.clear(symbol)
	symbol = normalizeSymbol(symbol)
	store[symbol] = nil
end

-- Reset all Assume
function Assume.reset()
	table.clear(store)
end

-- Dumps the assumptions table.
function Assume.dump()
	-- return a deep copy so users can't mutate internal state
	local out = {}
	for var, props in pairs(store) do
		out[var] = {}
		for prop, _ in pairs(props) do
			table.insert(out[var], prop)
		end
	end
	return out
end

---------------------------------------------------------------------
-- Scoped Assume
---------------------------------------------------------------------

-- NOTE: 
-- the scope doesn't work because it does not update the table for other modules.

--[[
function Assume.with(temp, fn)
	-- Save old state
	local backup = {}

	for symbol, tags in pairs(temp) do
		if typeof(tags) ~= "table" then error("Assume.with: tag list must be an array") end

		local s = normalizeSymbol(symbol)
		backup[s] = store[s] and table.clone(store[s]) or nil

		store[s] = {}
		for _, tag in ipairs(tags) do
			store[s][tag] = true
		end
	end

	-- Execute block
	local ok, result = pcall(fn)

	-- Restore old state
	for symbol, old in pairs(backup) do
		store[symbol] = old
	end

	return ok, result
end]]

-- The Assume sub-library.
return Assume