local Canon = {}
local CANON_CACHE = {}

local Node = require(script.Parent.Node)
local Util = require(script.Parent.Util)

local AlgebraicCanon = require(script.AlgebraicCanon)
local StructuralCanon = require(script.StructuralCanon)

local table_insert = table.insert
local table_sort = table.sort

local ipairs = ipairs

-------------------------------------------------------
-- Canonicalizer
-- Produces a unique, normalized AST form.
-------------------------------------------------------

-- Canonicalizes the node.
function Canon.canonical(node)
	-- DAG-aware memoization
	local cached = CANON_CACHE[node]
	if cached then
		return cached
	end

	-- Algebraic normalization first
	local n1 = AlgebraicCanon.normalize(node)

	-- Structural normalization second
	local n2 = StructuralCanon.normalize(n1)

	CANON_CACHE[node] = n2
	return n2
end

-- Canonicalizes the node structurally (no memoization).
function Canon.canonicalStructure(node)
	return AlgebraicCanon.normalize(node)
end

-- Canonicalizes the node algebraically (no memoization).
function Canon.canonicalAlgebraic(node)
	return StructuralCanon.normalize(node)
end

-- The Canonical sub-library.
return Canon