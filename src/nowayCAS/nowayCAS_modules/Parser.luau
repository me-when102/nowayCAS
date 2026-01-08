local Parser = {}

local Node = require(script.Parent.Node)
local UserConstants = require(script.Parent.UserConstants)

-------------------------------------------------------
-- Parser
-- Converts a token list into an AST (expression tree).
-- Grammar (recursive descent):
--
-- logic_or 	   -> logic_and ("or" logic_and)*
-- logic_and 	   -> logic_not ("and" logic_not)*
-- logic_not 	   -> ("not")* comparison
--
-- comparison 	   -> expression ((">" | "<" | ">=" | "<=" | "==" | "!=") expression)*
--
-- expression      -> term (("+" | "-") term)*
--
-- term            -> factor (("*" | "/" | implicit) factor)*
--
-- factor          -> ("+" | "-") factor
--                  | power
--
-- postfix         -> primary ("!")*
--
-- power           -> postfix ("^" power)?        -- right-associative
--
-- primary         -> number
--                  | identifier
--                  | identifier "(" expression ")"    -- function call
--                  | "(" expression ")"
--                  | "{" piecewise_branch_list "}"    -- piecewise literal
--
-- piecewise_branch_list
--                  -> piecewise_branch (";" piecewise_branch)* ";"?
--
-- piecewise_branch
--                  -> expression ":" expression
--
-- Notes:
--   * Implicit multiplication is triggered when a token can start a primary.
--   * Piecewise blocks are first-class expressions and bind like parentheses.
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
	local expr = Parser._parseLogicOr(stream)
	stream:expect("eof")
	return expr
end

-- logic_or -> logic_and ("or" logic_and)*
function Parser._parseLogicOr(stream)
	local node = Parser._parseLogicAnd(stream)

	while true do
		local tok = stream:peek()
		if tok.kind == "operator" and tok.value == "or" then
			stream:next()
			local right = Parser._parseLogicAnd(stream)
			node = Node.Op("or", node, right)
		else
			break
		end
	end

	return node
end

-- logic_and -> logic_not ("and" logic_not)*
function Parser._parseLogicAnd(stream)
	local node = Parser._parseLogicNot(stream)

	while true do
		local tok = stream:peek()
		if tok.kind == "operator" and tok.value == "and" then
			stream:next()
			local right = Parser._parseLogicNot(stream)
			node = Node.Op("and", node, right)
		else
			break
		end
	end

	return node
end

-- logic_not -> ("not")* comparison
function Parser._parseLogicNot(stream)
	local tok = stream:peek()

	if tok.kind == "operator" and tok.value == "not" then
		stream:next()
		local operand = Parser._parseLogicNot(stream)
		return Node.Func("not", { operand })
	end

	return Parser._parseComparison(stream)
end

-- comparison -> expression ((">" | "<" | ">=" | "<=" | "==" | "!=") expression)*
function Parser._parseComparison(stream)
	local node = Parser._parseExpression(stream)

	while true do
		local tok = stream:peek()
		if tok.kind == "operator" and (
			tok.value == ">" or tok.value == "<" or
				tok.value == ">=" or tok.value == "<=" or
				tok.value == "==" or tok.value == "!="
			) then
			stream:next()
			local right = Parser._parseExpression(stream)
			node = Node.Op(tok.value, node, right)
		else
			break
		end
	end

	return node
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
	local node = Parser._parsePostfix(stream)

	local tok = stream:peek()
	if tok.kind == "operator" and tok.value == "^" then
		stream:next()
		local right = Parser._parsePower(stream)
		node = Node.Op("^", node, right)
	end

	return node
end

-- postfix -> primary ("!")*
function Parser._parsePostfix(stream)
	local node = Parser._parsePrimary(stream)

	while true do
		local tok = stream:peek()
		if tok.kind == "operator" and tok.value == "!" then
			stream:next()
			node = Node.Func("factorial", { node })
		else
			break
		end
	end

	return node
end

-- Lists of known constants
local CONSTANTS = {
	pi = true,
	phi = true,
	tau = true,
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

	-- identifier (variable, constant, or function)
	if tok.kind == "identifier" then
		stream:next()
		local name = tok.value
		
		-- boolean literals
		if name == "true" then
			return Node.Const("true")
		elseif name == "false" then
			return Node.Const("false")
		end
		
		local args = {}
		
		-- is it a constant + user-defined constant?
		if CONSTANTS[name] or UserConstants.isConstant(name) then
			return Node.Const(name)
		end
		
		-- is it a function?
		if stream:peek().kind == "lparen" then
			stream:next() -- consume "("
			
			local args = {}
			if stream:peek().kind ~= "rparen" then
				table.insert(args, Parser._parseExpression(stream))
				while stream:peek().kind == "comma" do
					stream:next() -- consume comma
					table.insert(args, Parser._parseExpression(stream))
				end
			end
			stream:expect("rparen")
			return Node.Func(name, args)
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

	-- piecewise literal: { cond : expr ; ... }
	if tok.kind == "lbrace" then
		return Parser._parsePiecewise(stream)
	end

	error("Parser: Unexpected token '" .. tok.kind .. "'")
end

-- Special case: Parse piecewise.
function Parser._parsePiecewise(stream)
	stream:expect("lbrace")

	local branches = {}

	while true do
		-- Parse condition
		local cond = Parser._parseLogicOr(stream)

		-- Expect ':'
		stream:expect("colon")

		-- Parse expression
		local expr = Parser._parseLogicOr(stream)

		table.insert(branches, { cond, expr })

		local tok = stream:peek()

		-- Semicolon means more branches
		if tok.kind == "semicolon" then
			stream:next()
			continue
		end

		-- End of piecewise
		if tok.kind == "rbrace" then
			break
		end

		error("Parser: Expected ';' or '}' in piecewise block")
	end

	stream:expect("rbrace")
	return Node.Piecewise(branches)
end

-- Returns true if a token can start a primary expression.
function Parser._startsPrimary(tok)
	return tok.kind == "number"
		or tok.kind == "identifier"
		or tok.kind == "lparen"
		or tok.kind == "lbrace"
end

-- The Parser sub-library
return Parser