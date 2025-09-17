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

## Progress
### Mock API parity adjustments
- Matched the mock `LuaSurface.set_tiles` signature with Factorio through `raise_event` while documenting the unimplemented correction and collision flags.
- Removed the stray `surface.find_chart_tags` helper so tests exercise the proper `LuaForce.find_chart_tags` API.
### Event payload fixes
- Updated the script-raised tile event in the mock world so its payload mirrors Factorio and omits the non-existent `old_tile` field.

## Missing
- The mock still ignores `correct_tiles`, `remove_colliding_entities`, and `remove_colliding_decoratives` behavior when applying tile changes.
- Undo queue integration via the `player` and `undo_index` arguments of `set_tiles` remains unimplemented.
- Chart tag lookup mocks do not yet cover filters such as bounding boxes or tag names that the real API supports.

## Insights and Lessons Learned
- Aligning mock signatures with the real Factorio API prevents tests from passing with incorrect parameter ordering and surfaces integration gaps sooner.
- Routing tile changes through event-driven mocks keeps behavior close to Factorio and reduces test fragility.
- Waterfill should extend or merge water bodies; tests can verify area and volume adjustments.
- Multi‑tile landfill brushes remove several tiles at once, so mocks must support batch updates.
- Save/load scenarios require robust state serialization and are difficult to validate in the current mock framework.
- Well-scoped commits and thorough PR summaries speed up reviews and future development.
- Instrumenting queue helpers (e.g., wrapping `utils.Queue`) inside tests makes it possible to assert scan budgets, enqueue counts, and other performance characteristics without modifying game code.
- Recording `storage.CurrentUpdateBudget` resets and counting how often the per-cycle budget hits zero lets tests classify tile-limited, budget-limited, and balanced scenarios empirically, and validates the percentage of cycles that exhaust the budget.
- Matching the script-raised tile payload to Factorio highlights that downstream logic must tolerate missing historical tile data and rely on live surface queries when necessary.
