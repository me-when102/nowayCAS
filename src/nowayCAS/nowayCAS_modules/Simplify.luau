local Simplify = {}
local SIMPLIFY_CACHE = {}

local Canon = require(script.Parent.Canon)
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

-- Simplifies the node.
function Simplify.simplify(node)
	-- memoization
	local cached = SIMPLIFY_CACHE[node]
	if cached then return cached end

	local out

	if Util.isOp(node) then
		local op = node.op
		local left = Simplify.simplify(node.left)
		local right = Simplify.simplify(node.right)

		local rules = Simplify.operators[op]
		if rules then
			out = applyRules(rules, left, right)
			if out then
				out = Canon.canonical(out)
				SIMPLIFY_CACHE[node] = out
				return out
			end
		end

		out = Node.Op(op, left, right)

	elseif Util.isComplex(node) then
		local real = Simplify.simplify(node.real)
		local imag = Simplify.simplify(node.imag)

		out = applyRules(simplifyComplex, real, imag)
		out = Canon.canonical(out)

	elseif Util.isFunc(node) then
		local name = node.name
		local args = {}
		for i, a in ipairs(node.args) do
			args[i] = Simplify.simplify(a)
		end

		local rules = Simplify.functions[name]
		if rules then
			out = applyRules(rules, name, table.unpack(args))
			if out then
				out = Canon.canonical(out)
				SIMPLIFY_CACHE[node] = out
				return out
			end
		end

		out = Node.Func(name, args)

	elseif Util.isPiecewise(node) then
		local newBranches = {}
		for i, pair in ipairs(node.branches) do
			local cond = Simplify.simplify(pair[1])
			local expr = Simplify.simplify(pair[2])
			newBranches[i] = { cond, expr }
		end
		out = simplifyPiecewise(newBranches)

	else
		-- num, var, const, rat, etc.
		out = node
	end

	-- apply algebraic rewrite rules
	out = Rewrite.apply(out, rules_algebraic.simplify)

	-- canonicalize
	out = Canon.canonical(out)

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

		-- canonical equality check
		if Util.nodeEquals(Canon.canonical(node), next) then
			return next
		end

		node = next
		steps += 1
	end

	return node
end

-- The Simplifier sub-library.
return Simplify