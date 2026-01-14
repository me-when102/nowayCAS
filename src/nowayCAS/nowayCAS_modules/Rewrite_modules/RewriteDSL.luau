local RewriteDSL = {}

local Node = require(script.Parent.Parent.Node)
local Util = require(script.Parent.Parent.Util)

-------------------------------------------------------
-- RewriteDSL
-------------------------------------------------------

-------------------------------------------------------
-- Tokenizer
-------------------------------------------------------

local function tokenize(str)
	local tokens = {}
	local i = 1
	local n = #str

	while i <= n do
		local c = str:sub(i,i)

		-- skip whitespace
		if c:match("%s") then
			i += 1

			-- identifier or wildcard (_x, foo, _xs)
		elseif c:match("[%a_]") then
			local start = i
			i += 1
			while i <= n and str:sub(i,i):match("[%w_]") do
				i += 1
			end
			table.insert(tokens, str:sub(start, i-1))

			-- number
		elseif c:match("%d") then
			local start = i
			i += 1
			while i <= n and str:sub(i,i):match("%d") do
				i += 1
			end
			table.insert(tokens, str:sub(start, i-1))

			-- single-character operators and punctuation
		elseif c:match("[%(%),%+%-%*/%^]") then
			table.insert(tokens, c)
			i += 1

		else
			error("Unexpected character in RewriteDSL: " .. c)
		end
	end

	return tokens
end

local function peek(tokens)
	return tokens[1]
end

local function pop(tokens)
	return table.remove(tokens, 1)
end

-- Forward declarations

local parseExpr
local parseAtom

-- Parse atomic: number, variable, wildcard, function call, parenthesis
function parseAtom(tokens)
	local t = peek(tokens)
	if not t then
		error("Unexpected end of input")
	end
	-- Parenthesized expression
	if t == "(" then
		pop(tokens)
		local expr = parseExpr(tokens)
		if pop(tokens) ~= ")" then
			error("Expected ')'")
		end
		return expr
	end

	-- number
	if t:match("^%d+$") then
		pop(tokens)
		return Node.Num(tostring(t))
	end

	-- wildcard or variable
	if t:match("^_%a+") then
		pop(tokens)
		return Node.Var(t)
	end

	-- variable or function name
	if t:match("^%a+") then
		pop(tokens)
		local name = t
		
		-- check if complex number first
		if name == "complex" and peek(tokens) == "(" then
			pop(tokens) -- "("
			local real = parseExpr(tokens)
			if pop(tokens) ~= "," then error("Expected ',' in complex()") end
			local imag = parseExpr(tokens)
			if pop(tokens) ~= ")" then error("Expected ')' in complex()") end
			return Node.Complex(real, imag)
		end

		-- function call?
		if peek(tokens) == "(" then
			pop(tokens) -- "("
			local args = {}

			if peek(tokens) ~= ")" then
				while true do
					table.insert(args, parseExpr(tokens))
					if peek(tokens) == "," then
						pop(tokens)
					elseif peek(tokens) == ")" then
						break
					else
						error("Expected ',' or ')'")
					end
				end
			end

			pop(tokens) -- final ")"
			return Node.Func(name, args)
		end

		return Node.Var(name)
	end

	error("Unexpected token: " .. tostring(t))
end

-------------------------------------------------------
-- Parse binary expressions (left-associative)
-- NOTE: This is a simple pattern RewriteDSL, not a full math parser.
-------------------------------------------------------

local function parsePower(tokens)
	local left = parseAtom(tokens)

	while peek(tokens) == "^" do
		pop(tokens)
		local right = parseAtom(tokens)
		left = Node.Op("^", left, right)
	end

	return left
end

local function parseFactor(tokens)
	local t = peek(tokens)

	-- unary minus
	if t == "-" then
		pop(tokens)
		local factor = parseFactor(tokens)

		if Util.isNum(factor) then
			-- numeric literals: just negate the string value
			local val = tonumber(factor.value)
			return Node.Num(tostring(-val))
		else
			-- everything else: -1 * expr   (as per invariants)
			return Node.Op("*", Node.Num("-1"), factor)
		end
	end

	return parsePower(tokens)
end

function parseExpr(tokens)
	local left = parseFactor(tokens)

	while true do
		local op = peek(tokens)

		-- STOP conditions for expression:
		-- closing parenthesis or comma or end
		if op == ")" or op == "," or op == nil then
			break
		end

		if op == "+" or op == "-" or op == "*" or op == "/" then
			pop(tokens)
			local right = parseFactor(tokens)
			left = Node.Op(op, left, right)
		else
			break
		end
	end

	return left
end

-------------------------------------------------------
-- Public API
-------------------------------------------------------

function RewriteDSL.parse(str)
	local tokens = tokenize(str)
	local node = parseExpr(tokens)

	if #tokens > 0 then
		error("Unexpected trailing tokens: " .. table.concat(tokens, " "))
	end

	return node
end

-- The RewriteDSL system.
return RewriteDSL