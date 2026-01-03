# Contributing to nowayCAS
Thanks for your interest in contributing! nowayCAS is a symbolic math engine built for clarity, correctness, and extensibility - and we welcome contributions from developers, math enthusiasts, and curious learners of all experience levels.

This guide explains how to get started, how to propose changes, and how to collaborate effectively.

## 🧱 Guiding Principles
nowayCAS is built on a few core values:
- **Clarity over cleverness** - readable code beats "smart" code
- **Determinism** - stable, predictable behavior is essential for symbolic math
- **Extensibility** - new rules, functions, and modules should fit naturally
- **Safety** - no dynamic code execution, no loadstring hacks
- **Developer experience** - clean APIs, good docs, and helpful error messages
If your contribution aligns with these values, you're already on the right track.

## 🚀 How to Get Started

### 1. Fork the repository
Create your own fork and clone it locally.

### 2. Install dependencies

nowayCAS is pure Luau - no external dependencies required.
You can develop using:
- Roblox Studio
- Rojo (optional)
- Any Luau-aware editor

### 3. Explore the codebase

nowayCAS has a ton of modules that is worth looking at. Here are some useful entry points:
- `src/nowayCAS.luau` - This is where the external API belongs. Expression instance included in here.
- `src/nowayCAS_modules/Simplify.luau` - This is the module containing code responsible for simplifying expressions.
- `src/nowayCAS_modules/Canon.luau` - Makes expressions canonicalized (like combining like terms)
- `src/nowayCAS_modules/Print.luau` - This is where expressions are displayed.
- `src/nowayCAS_modules/Node.luau` - This is the foundation of the AST + DAG system: node constructors and table caching.

If you are unsure where something belong's open an issue - we are happy to help.

## 🧪 Testing Your Changes
Before submitting a PR:
- Add tests for new features
- Ensure existing tests pass
- Include examples when appropriate
- Keep behavior deterministic
Symbolic engines are subtle - tests help us avoid regressions.

## 💡 What You Can Contribute
Here are great ways to help:
### 🧮 Algebraic rules
- Enhancing and improving factoring / expansion
- New simplification identities
- Additional canonicalization rules

### 📚 Documentation
- Improving README examples
- Adding explanation for tricky modules
- Writing developer notes or diagrams

### 🧩 New functions and Features
- Factorials
- Sum and Product
- Integrals

### 🐛 Bug fixes
- Incorrect simplifications and edge-cases
- Incorrect parsing edge cases
- Invariant failures

### 🧱 Architecture improvements
- Better and enhance module boundaries
- Performance optimizations
- Cleaner internal APIs

If you're unsure whether an idea fits, open an issues - discussion is welcome.

## 🔄 Pull Request Process
1. Open an issue describing the change (optional but recommended)
2. Create a branch for your work
3. Keep commits focused and readable
4. Ensure tests pass
5. Submit a PR with a clear description of:
    - What changed
    - Why it changed
    - Any edge cases or limitiations
We reveal PRs with an emphasis on clarity, correctness, and maintainability.

## 🤝 Code of Conduct
By participating in this project, you agree to follow the [nowayCAS Code of Conduct](./CODE_OF_CONDUCT.md)

We aim to keep discussions respectful, constructive, and welcoming.

## 💙 Thank You
Every contribution, from fixing a typo to implementing a new algebraic rule, helps make nowayCAS a better tool for the entire Roblox developer community.

We're excited to build this math ecosystem with you.