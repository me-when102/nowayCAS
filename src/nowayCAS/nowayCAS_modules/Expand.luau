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

	-- flatten additive chains (a + (b + c) -> a + b + c)
	node = expand_add.apply(node)

	-- distribute multiplication over addition
	node = expand_mul.apply(node)

	-- expand powers (multinomial, binomial, etc.)
	node = expand_pow.apply(node)

	-- Final canonicalization
	node = Canon.canonical(node)

	return node
end

-- The Expand sub-library.
return Expand