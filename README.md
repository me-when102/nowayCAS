<p align="center"> 
    <img src="./assets/logo/nowayCAS_logo.jpg" alt="nowayCAS Logo" width="400"> 
</p>

<h1 align="center">nowayCAS</h1>

<p align="center">
    <strong>A full-featured Computer Algebra System for Luau & Roblox Studio</strong> 🔥🧮
</p>

## Why nowayCAS?
Roblox's built-in math is purely **numerical** - great for games, but useless for symbolic manipulation.

You can't natively:
- Parse `"3x + pi^7"` and keep it exact
- Simplify `(x^2 - y^2)/(x - y)` → `x + y` (beta)
- Substituting expressions with values and other expressions
- Evalute reciprocal functions (csc, sec, cot) and inverse hyperbolic functions
- Differentiate, factor, or rewrite expressions symbolically

But if you really had to, you need to use `loadstring()` enabled,
- Which makes your game vulnerable.
- and it can't do algebra.

**nowayCAS changes everything.**

<p align="center">
    <img src="./assets/images/nowayCAS-capability.png" alt="nowayCAS capabilities" width="700">
</p>

## Features 🚀

nowayCAS is a **full-featured symbolic engine** built from the ground up in pure Luau:

- **Expression parsing** from strings → optimized **AST → DAG** representation (shared subexpressions for speed & memory)
- **Natural math syntax** via operator overloading (`x^2 + 2*x + 1`)
- **Symbolic manipulation**:
  - Simplification (algebraic identities, rational forms)
  - Expansion & factoring of polynomials (partially)
  - Symbolic **differentiation** (`var:diff()`)
  - Variable/expression **substitution** (`:substitute({x: AST_node = 3})`)
- **Evaluation**: Numerical results with parameter tables (`:eval({x=5})`)
- **Extensibility**:
  - Built-in functions & constants (sin, cos, pi, e, etc.)
  - **User-defined functions and constants**
- **Output formats**:
  - `.toString()` → clean pretty-printed Unicode
  - `.toLaTeX()` → ready for docs/export
  - `.toDAGString()` & `.toASTRepresentation()` → debugging/power-user tools
- **Modular design** → easy to extend with new rules, parsers, or backends

All of this runs natively in Roblox Studio - no external services needed.

## **Development Status**
**nowayCAS** started in **1st January 2026** and it's currently in **beta**. Expect:
- Some edge-case bugs
- Incomplete features and function coverage
- API changes as it stabilizes

## **Roadmap (needs help)**
- Enhance simplification.
- Add more factorising kinds.
- Support equations (`x = y + 3`)
    - Solve equations
    - Solve simultaneous equations
    - ...etc
- Factorial (unary operator)
- Sum and product
- Polynomial factoring engine

## ❤️ Contributing
We are going to make Roblox Studio have its own **CAS** system!
We're wide open to:
- Bug reports & fixes
- New rewrite rules
- Feature ideas (solvers? plotting hooks? etc)
- Documentation & examples
- Performance tweaks
Check out [CONTRIBUTING.md](CONTRIBUTING.md) for how to get started. No contribution too small, even a single test case helps!

## 🔨 Installation
- Will come soon with a .rbxm model or other things (like Wally or Rojo setup if possible)