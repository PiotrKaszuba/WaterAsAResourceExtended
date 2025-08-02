TODO:

Needed:
1. Initial scans for pumps / poles when mod hasn't been initialized yet? + update mod func?
9. comprehensive tests - plan out test suite (especially for merging/splitting water bodies) etc, lifecycles etc. - somewhat - now do them

- WHAT happens when landfill is placed when there are some existing dry tiles?
-> landfill will take place of some water tile but maybe something breaks?
-> initial looks at code suggest its ok because landfill removes from grid
-> and depletion visuals are based on the grid tile data (current name vs original name)

Maybe:
- NEED to profile performance

2. Update budget on depletion appearance? - IDK
10. reevaluate mods additions (that were in original script) / mod updates, "ScenFunc" for scenario created games etc. - some additions that might handle logic in various cases and be useful
11. some stats commands etc.
13. consider the DriedTiles to be held in a separate indicator table of some levels - to quickly access and restore them - maybe the same for depletion happens gradually? like bootstrapping future computation if update budget is there? 


Someday:
14. consider re-adding drains?
