local Token = {}

local table_insert = table.insert

-------------------------------------------------------
-- Tokenizer
-- Converts an input string into a stream of tokens.
-- Token kinds:
--   number, identifier, operator, lparen, rparen, comma, eof
-------------------------------------------------------

-- Token constructor
local function makeToken(kind, value)
	return { kind = kind, value = value }
end

-- Character classification helpers

-- checks if c is a digit
local function isDigit(c)
	return c >= "0" and c <= "9"
end

-- checks if c is a letter
local function isLetter(c)
	return (c >= "a" and c <= "z")
		or (c >= "A" and c <= "Z")
end

-- checks if c is an identity character
local function isIdentChar(c)
	return isLetter(c) or isDigit(c) or c == "_"
end

-- Main tokenizer function
-- tokenizer a mathematical expression string into a flat token array.
function Token._tokenize(input: string)
	local tokens = {}
	local i = 1
	local n = #input

	local function peek()
		if i > n then
			return ""
		end
		return input:sub(i, i)
	end


	local function advance()
		i += 1
	end

	-- Skip whitespace
	local function skipWhitespace()
		while i <= n do
			local c = peek()
			if c == " " or c == "\t" or c == "\n" or c == "\r" then
				advance()
			else
				break
			end
		end
	end

	while i <= n do
		skipWhitespace()
		if i > n then break end

		local c = peek()

		-------------------------------------------------------
		-- Numbers
		-------------------------------------------------------
		local nextChar = (i < n) and input:sub(i+1, i+1) or ""

		if isDigit(c) or (c == "." and isDigit(nextChar)) then
			local start = i
			local hasDot = false

			-- integer or leading dot
			if c == "." then
				hasDot = true
				advance()
			end

			-- digits before/after dot
			while i <= n and isDigit(peek()) do
				advance()
			end

			-- decimal part
			if peek() == "." and not hasDot then
				hasDot = true
				advance()
				while i <= n and isDigit(peek()) do
					advance()
				end
			end

			-- exponent part
			if peek() == "e" or peek() == "E" then
				advance()
				if peek() == "+" or peek() == "-" then
					advance()
				end
				while i <= n and isDigit(peek()) do
					advance()
				end
			end

			local num = input:sub(start, i-1)
			table_insert(tokens, makeToken("number", num))
			continue
		end

		-------------------------------------------------------
		-- Identifiers (variables, functions, keywords)
		-------------------------------------------------------
		if isLetter(c) then
			local start = i
			advance()
			while i <= n and isIdentChar(peek()) do
				advance()
			end
			local ident = input:sub(start, i-1)

			-- Boolean operators (keywords)
			if ident == "and" or ident == "or" then
				table_insert(tokens, makeToken("operator", ident))
				continue
			end

			if ident == "not" then
				table_insert(tokens, makeToken("operator", ident))
				continue
			end

			-- Otherwise it's a normal identifier
			table_insert(tokens, makeToken("identifier", ident))
			continue
		end

		-------------------------------------------------------
		-- Operators
		-------------------------------------------------------
		if c == "+" or c == "-" or c == "*" or c == "/" or c == "^" or c == "!" then
			table_insert(tokens, makeToken("operator", c))
			advance()
			continue
		end

		-------------------------------------------------------
		-- Parentheses and comma
		-------------------------------------------------------
		if c == "(" then
			table_insert(tokens, makeToken("lparen", c))
			advance()
			continue
		end

		if c == ")" then
			table_insert(tokens, makeToken("rparen", c))
			advance()
			continue
		end

		if c == "," then
			table_insert(tokens, makeToken("comma", c))
			advance()
			continue
		end
		
		-------------------------------------------------------
		-- Braces for piecewise
		-------------------------------------------------------
		if c == "{" then
			table_insert(tokens, makeToken("lbrace", c))
			advance()
			continue
		end

		if c == "}" then
			table_insert(tokens, makeToken("rbrace", c))
			advance()
			continue
		end

		-------------------------------------------------------
		-- Colon for piecewise branches
		-------------------------------------------------------
		if c == ":" then
			table_insert(tokens, makeToken("colon", c))
			advance()
			continue
		end

		-------------------------------------------------------
		-- Semicolon for branch separators
		-------------------------------------------------------
		if c == ";" then
			table_insert(tokens, makeToken("semicolon", c))
			advance()
			continue
		end

		-------------------------------------------------------
		-- Comparison Operators
		-------------------------------------------------------

		-- <= or <
		if c == "<" then
			local nextChar = (i < n) and input:sub(i+1, i+1) or ""
			if nextChar == "=" then
				table_insert(tokens, makeToken("operator", "<="))
				i += 2
			else
				table_insert(tokens, makeToken("operator", "<"))
				i += 1
			end
			continue
		end

		-- >= or >
		if c == ">" then
			local nextChar = (i < n) and input:sub(i+1, i+1) or ""
			if nextChar == "=" then
				table_insert(tokens, makeToken("operator", ">="))
				i += 2
			else
				table_insert(tokens, makeToken("operator", ">"))
				i += 1
			end
			continue
		end

		-- == (equality)
		if c == "=" then
			local nextChar = (i < n) and input:sub(i+1, i+1) or ""
			if nextChar == "=" then
				table_insert(tokens, makeToken("operator", "=="))
				i += 2
				continue
			end
			error("nowayCAS.Tokenizer: Unexpected '=' - did you mean '=='?")
		end

		-- != (not equal)
		if c == "!" then
			local nextChar = (i < n) and input:sub(i+1, i+1) or ""
			if nextChar == "=" then
				table_insert(tokens, makeToken("operator", "!="))
				i += 2
				continue
			end

			-- fallback: factorial
			table_insert(tokens, makeToken("operator", "!"))
			i += 1
			continue
		end

		-------------------------------------------------------
		-- Unknown character
		-------------------------------------------------------
		error("nowayCAS.Tokenizer: Unexpected character '" .. c .. "' at position " .. i)
	end

	table_insert(tokens, makeToken("eof", nil))
	return tokens
end

-- The Token sub-library.
return Token