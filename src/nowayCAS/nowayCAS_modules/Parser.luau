local Parser = {}

local Node = require(script.Parent.Node)
-------------------------------------------------------
-- Parser
-- Converts a token list into an AST (expression tree).
-- Grammar (recursive descent):
--
-- expression 	-> term (("+" | "-" ) term)*
-- term 		-> factor (("*" | "/" | implicit) factor)*
-- factor 		-> power
-- power 		-> primary ("^" power)?
-- primary 		-> number
--					| identifier
--					| identifier "(" expression ")" -- function call
--					| "(" expression ")"
-------------------------------------------------------

-------------------------------------------------------
-- TokenStream helper
-------------------------------------------------------
local TokenStream = {}
TokenStream.__index = TokenStream

function TokenStream.new(tokens)
	return setmetatable({
		tokens = tokens,
		index = 1,
	}, TokenStream)
end

function TokenStream:peek()
	return self.tokens[self.index]
end

function TokenStream:next()
	local tok = self.tokens[self.index]
	self.index += 1
	return tok
end

function TokenStream:expect(kind, value)
	local tok = self:peek()
	if tok.kind ~= kind or (value and tok.value ~= value) then
		error(
			"Parser: Expected "
				.. kind
				.. (value and (" '" .. value .. "'") or "")
				.. ", got "
				.. tok.kind
				.. (tok.value and (" '" .. tok.value .. "'") or "")
		)
	end
	self:next()
	return tok
end

-------------------------------------------------------
-- Main Parser Functions
-------------------------------------------------------

-- Parses the tokened expression.
function Parser.parse(tokens)
	local stream = TokenStream.new(tokens)
	local expr = Parser._parseExpression(stream)
	stream:expect("eof")
	return expr
end

-- expression -> term (("+" | "-") term)*
function Parser._parseExpression(stream)
	local node = Parser._parseTerm(stream)

	while true do
		local tok = stream:peek()
		if tok.kind == "operator" and (tok.value == "+" or tok.value == "-") then
			stream:next()
			local right = Parser._parseTerm(stream)
			node = Node.Op(tok.value, node, right)
		else
			break
		end
	end

	return node
end

-- term -> factor (("*" | "/" | implicit) factor)*
function Parser._parseTerm(stream)
	local node = Parser._parseFactor(stream)

	while true do
		local tok = stream:peek()

		-- Explicit * or /
		if tok.kind == "operator" and (tok.value == "*" or tok.value == "/") then
			stream:next()
			local right = Parser._parseFactor(stream)
			node = Node.Op(tok.value, node, right)
			continue
		end

		-- Implicit multiplication:
		-- Triggered when the next token begins a primary expression.
		if Parser._startsPrimary(tok) then
			-- Treat as multiplication
			local right = Parser._parseFactor(stream)
			node = Node.Op("*", node, right)
			continue
		end

		break
	end

	return node
end

-- factor -> ("+" | "-") factor
--         | power
function Parser._parseFactor(stream)
	local tok = stream:peek()

	-- unary operators
	if tok.kind == "operator" and (tok.value == "+" or tok.value == "-") then
		stream:next()
		local operand = Parser._parseFactor(stream)

		-- Represent unary minus as multiplication by -1
		if tok.value == "-" then
			return Node.Op("*", Node.Num("-1"), operand)
		end

		-- Unary plus is a no-op
		return operand
	end

	return Parser._parsePower(stream)
end

-- power -> primary ("^" power)?
-- Right-associative
function Parser._parsePower(stream)
	local node = Parser._parsePrimary(stream)

	local tok = stream:peek()
	if tok.kind == "operator" and tok.value == "^" then
		stream:next()
		local right = Parser._parsePower(stream)
		node = Node.Op("^", node, right)
	end

	return node
end

-- list of known functions
local KNOWN_FUNCTIONS = {
	sin = true,
	cos = true,
	tan = true,
	exp = true,
	ln  = true,
	sqrt = true,
}

-- primary -> number
--          | identifier
--          | identifier "(" expression ")"
--          | "(" expression ")"
function Parser._parsePrimary(stream)
	local tok = stream:peek()

	-- number literal
	if tok.kind == "number" then
		stream:next()
		return Node.Num(tok.value)
	end

	-- identifier (variable or function)
	if tok.kind == "identifier" then
		stream:next()
		local name = tok.value

		-- function call only if name is known
		if KNOWN_FUNCTIONS[name] and stream:peek().kind == "lparen" then
			stream:next() -- consume "("
			local arg = Parser._parseExpression(stream)
			stream:expect("rparen")
			return Node.Func(name, arg)
		end

		-- otherwise it's a variable
		return Node.Var(name)
	end

	-- parenthesized expression
	if tok.kind == "lparen" then
		stream:next()
		local expr = Parser._parseExpression(stream)
		stream:expect("rparen")
		return expr
	end

	error("Parser: Unexpected token '" .. tok.kind .. "'")
end

-- Returns true if a token can start a primary expression.
function Parser._startsPrimary(tok)
	return tok.kind == "number"
		or tok.kind == "identifier"
		or tok.kind == "lparen"
end

-- The Parser sub-library
return Parser