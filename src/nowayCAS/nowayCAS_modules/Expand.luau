local Expand = {}

local Node = require(script.Parent.Node)
local Util = require(script.Parent.Util)
local Canon = require(script.Parent.Canon)

-- Phase Modules
local expand_sign = require(script.expand_sign)
local expand_add  = require(script.expand_add)
local expand_mul  = require(script.expand_mul)
local expand_pow  = require(script.expand_pow)

-------------------------------------------------------
-- Expand.expand
-- Runs the full expansion pipeline in deterministic order.
-- Each phase is responsible for a single structural rewrite.
-------------------------------------------------------

-- Expands the node.
function Expand.expand(node)
	-- distribute unary minus and normalize signs
	node = expand_sign.apply(node)

	-- expand powers (multinomial, binomial, etc.)
	node = expand_pow.apply(node)

	-- distribute multiplication over addition
	node = expand_mul.apply(node)

	-- flatten additive chains (a + (b + c) -> a + b + c)
	node = expand_add.apply(node)

	-- Final canonicalization
	node = Canon.canonical(node)

	return node
end

-- Performs a fixed-point expansion on the node.
-- Keeps expanding the node until it is unchanged.
function Expand.expandDeep(node)
	local prev = nil
	local curr = node
	
	while true do
		prev = curr
		curr = Expand.expand(curr)
		if Util.nodeEquals(curr, prev) then
			break
		end
	end

	return curr
end

-- The Expand sub-library.
return Expand