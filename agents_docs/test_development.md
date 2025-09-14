# Test Development Guidelines

## User Directives
- Mock Factorio internals so tests do not depend on the actual mod code. Trigger tile updates through events like `tiles.handleTileEventsInternal`.
- Simulate waterfill via entity builds and treat landfill as standard player tile placement. Include large brush scenarios.
- Use `other_docs/grok_test_cases.md` as inspiration. Modify, extend or merge cases when useful.
- Ignore save/load game testing for now; state tracking across saves is outside current scope.
- Start with simple cases and iterate toward more complex ones while enhancing the mock engine as needed.
- Run `lua tests/run.lua` after every change and fix issues before proceeding.
- Create separate commits for each test or mock improvement with descriptive messages.
- Keep a running summary of changes to craft a clear, comprehensive PR description.

## Insights and Lessons Learned
- Routing tile changes through event-driven mocks keeps behavior close to Factorio and reduces test fragility.
- Waterfill should extend or merge water bodies; tests can verify area and volume adjustments.
- Multi‑tile landfill brushes remove several tiles at once, so mocks must support batch updates.
- Save/load scenarios require robust state serialization and are difficult to validate in the current mock framework.
- Well-scoped commits and thorough PR summaries speed up reviews and future development.
