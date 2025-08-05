TODO:

Needed:
1. Initial scans for pumps / poles when mod hasn't been initialized yet? + update mod func?
-> whole state - forces - techs need to be captured?

9. comprehensive tests - plan out test suite (especially for merging/splitting water bodies) etc, lifecycles etc. - somewhat - now do them / -> actually tested manually without looking at the file - might have missed something but was too lazy ;)

-> to test: techs unlocks (and forces)
-> to test: rejectEntityPlacement with mine instead of destroy - how waterfill behaves with it?

- WHAT happens when landfill is placed when there are some existing dry tiles?
-> landfill will take place of some water tile but maybe something breaks?
-> initial looks at code suggest its ok because landfill removes from grid
-> and depletion visuals are based on the grid tile data (current name vs original name)

Maybe:
- NEED to profile performance - partially done
-> profiling of other cases with corner tile fixing
-> can remake scan algorithm to start with EdgePattern and apply processTile for each there - our current 'already searched' method will trigger on these tiles so:
    then scan calling EdgePattern cannot block 'already searched' tiles because we haven't got their EdgePatterns yet
    we would need to check at EdgePattern iteration - before proceeding
    assumption is that the tile entering EdgePattern is already after processTile (added fully to waterbody)
    so starting search will not be as simple as adding to search queue but adding more explicitly - processing and adding to search Que
    then in scan it will go to EdgePattern (correctly assuming the initial tile has been added) and so on.. 

(DONE)
-> optimize small update loop - rework waterbody pumps storage to hold actual references to pumps
    to gain quicker access to object


-> separate scanning loop update?
-> that happens a few times per second?
-> and calculate water area only on big updates cause it takes some time?
-> update bounding box not after every tile but after whole batch - scan can hold min,max of visited tiles and then we can combine it at the end only!

(DONE)
-> DONT deplete waterbodies on small updates when its still scanning..
    need some 'temp restriction' - maybe another field ? that deactivates the pump but not THE same depletion interface - and no depletion message either
    water area recalc would add more water and then something else (or recalc?) can lift restriction - all of this on big update or scanning update? - big looks good


---
2. Update budget on depletion appearance? - IDK
10. reevaluate mods additions (that were in original script) / mod updates, "ScenFunc" for scenario created games etc. - some additions that might handle logic in various cases and be useful
11. some stats commands etc.
13. consider the DriedTiles to be held in a separate indicator table of some levels - to quickly access and restore them - maybe the same for depletion happens gradually? like bootstrapping future computation if update budget is there? 


Someday:
14. consider re-adding drains?
