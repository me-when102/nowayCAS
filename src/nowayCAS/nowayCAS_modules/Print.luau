local Print = {}

-- the requirements
local DAGString = require(script.DAGString)
local String = require(script.String)
local ValuePrint = require(script.ValuePrint)
local Latex = require(script.Latex)
local ASTDebug = require(script.ASTDebug)

-- the assignments

Print._toString = String._toString
Print._toLatex = Latex._toLatex
Print._value = ValuePrint._value
Print._toDAGString = DAGString._toDAGString
Print._toASTRepresentation = ASTDebug._toASTRepresentation

-- The Printing sub-library.
return Print