local Simplify = {}
local SIMPLIFY_CACHE = {}

local Node = require(script.Parent.Node)
local Rewrite = require(script.Parent.Rewrite)
local Util = require(script.Parent.Util)

local rules_algebraic = require(script.Parent.Rewrite.rules_algebraic)

-------------------------------------------------------
-- Simplifier
-- Applies algebraic rewrite rules to AST nodes.
-- Invariants:
--   - Simplification never mutates nodes.
--   - Always returns a new or original node.
--   - Recursively simplifies children before applying rules.
-------------------------------------------------------

Simplify.operators = {
	["+"] = require(script.operators.simplify_add),
	["-"] = require(script.operators.simplify_sub),
	["*"] = require(script.operators.simplify_mul),
	["/"] = require(script.operators.simplify_div),
	["^"] = require(script.operators.simplify_pow),
	["or"] = require(script.operators.simplify_boolean_op),
	["and"] = require(script.operators.simplify_boolean_op),
	["<"]  = require(script.operators.simplify_compare),
	["<="] = require(script.operators.simplify_compare),
	[">"]  = require(script.operators.simplify_compare),
	[">="] = require(script.operators.simplify_compare),
	["=="] = require(script.operators.simplify_compare),
	["!="] = require(script.operators.simplify_compare),
}

Simplify.functions = {
	-- Basic trig
	sin  = require(script.functions.simplify_basic_trig),
	cos  = require(script.functions.simplify_basic_trig),
	tan  = require(script.functions.simplify_basic_trig),

	-- Reciprocal trig
	sec  = require(script.functions.simplify_recip_trig),
	csc  = require(script.functions.simplify_recip_trig),
	cot  = require(script.functions.simplify_recip_trig),

	-- Inverse trig
	asin = require(script.functions.simplify_inv_trig),
	acos = require(script.functions.simplify_inv_trig),
	atan = require(script.functions.simplify_inv_trig),

	-- Inverse reciprocal trig
	asec = require(script.functions.simplify_inv_recip_trig),
	acsc = require(script.functions.simplify_inv_recip_trig),
	acot = require(script.functions.simplify_inv_recip_trig),

	-- Hyperbolic
	sinh = require(script.functions.simplify_basic_hyperbolic),
	cosh = require(script.functions.simplify_basic_hyperbolic),
	tanh = require(script.functions.simplify_basic_hyperbolic),

	-- Reciprocal hyperbolic
	sech = require(script.functions.simplify_recip_hyperbolic),
	csch = require(script.functions.simplify_recip_hyperbolic),
	coth = require(script.functions.simplify_recip_hyperbolic),

	-- Inverse hyperbolic
	asinh = require(script.functions.simplify_inv_hyperbolic),
	acosh = require(script.functions.simplify_inv_hyperbolic),
	atanh = require(script.functions.simplify_inv_hyperbolic),

	-- Inverse reciprocal hyperbolic
	asech = require(script.functions.simplify_inv_recip_hyperbolic),
	acsch = require(script.functions.simplify_inv_recip_hyperbolic),
	acoth = require(script.functions.simplify_inv_recip_hyperbolic),

	-- Exponential / log
	exp   = require(script.functions.simplify_exp_log),
	ln    = require(script.functions.simplify_exp_log),
	log10 = require(script.functions.simplify_exp_log),
	log   = require(script.functions.simplify_exp_log),

	-- Misc
	sqrt     = require(script.functions.simplify_misc),
	abs      = require(script.functions.simplify_misc),
	floor    = require(script.functions.simplify_misc),
	ceil     = require(script.functions.simplify_misc),
	sign     = require(script.functions.simplify_misc),
	factorial = require(script.functions.simplify_misc),

	-- Boolean
	["not"] = require(script.functions.simplify_not),
}

local simplifyPiecewise = require(script.misc.simplify_piecewise)
local simplifyComplex = require(script.misc.simplify_complex)

local function applyRules(rules, ...)
	for _, rule in ipairs(rules) do
		local out = rule(...)
		if out then return out end
	end
end

local function simplifyChildren(node)
	if Util.isOp(node) then
		return Node.Op(node.op,
			Simplify.simplify(node.left),
			Simplify.simplify(node.right)
		)

	elseif Util.isFunc(node) then
		local args = {}
		for i, a in ipairs(node.args) do
			args[i] = Simplify.simplify(a)
		end
		return Node.Func(node.name, args)

	elseif Util.isComplex(node) then
		return Node.Complex(
			Simplify.simplify(node.real),
			Simplify.simplify(node.imag)
		)

	elseif Util.isPiecewise(node) then
		local branches = {}
		for i, pair in ipairs(node.branches) do
			branches[i] = {
				Simplify.simplify(pair[1]),
				Simplify.simplify(pair[2])
			}
		end
		return simplifyPiecewise(branches)
	end

	return node
end


local function simplifyNode(node)
	if Util.isOp(node) then
		local rules = Simplify.operators[node.op]
		if rules then
			local out = applyRules(rules, node.left, node.right)
			if out then return out end
		end

	elseif Util.isFunc(node) then
		local rules = Simplify.functions[node.name]
		if rules then
			local out = applyRules(rules, node.name, table.unpack(node.args))
			if out then return out end
		end

	elseif Util.isComplex(node) then
		local out = applyRules(simplifyComplex, node.real, node.imag)
		if out then return out end
	end

	return node
end

-- Simplifies the node.
function Simplify.simplify(node)
	local cached = SIMPLIFY_CACHE[node]
	if cached then return cached end

	-- Recurse
	local out = simplifyChildren(node)

	-- Apply operator/function rules
	out = simplifyNode(out)

	-- Apply algebraic rewrite rules
	out = Rewrite.apply(out, rules_algebraic.simplify)

	SIMPLIFY_CACHE[node] = out
	return out
end

-- Performs a fixed-point simplify on the node.
-- Keeps simplifying the node until it is unchanged or been iterating higher than maxSteps.
function Simplify.simplifyDeep(node, maxSteps)
	maxSteps = maxSteps or 20
	local steps = 0

	while steps < maxSteps do
		local next = Simplify.simplify(node)

		-- If Simplify made no change, we reached a fixed point
		if Util.nodeEquals(node, next) then
			return next
		end

		node = next
		steps += 1
	end

	return node
end

-- The Simplifier sub-library.
return Simplify