# vjs_core

Low-memory JavaScript subset runtime written in V.

This repository is the neutral continuation of the reusable micro-JS engine previously embedded under browser product branding. It contains the lexer, parser, AST, value model, DOM-facing primitives, execution plan, policy, runtime, and tests.

Product-specific routing and compatibility fallback belong in `vjs_runtime`.
