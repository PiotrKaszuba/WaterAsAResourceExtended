TODO:

Needed:
1. Initial scans for pumps / poles when mod hasn't been initialized yet? + update mod func?
-> whole state - forces - techs need to be captured?

9. comprehensive tests - plan out test suite (especially for merging/splitting water bodies) etc, lifecycles etc. - somewhat - now do them / -> actually tested manually without looking at the file - might have missed something but was too lazy ;)

-> to test: techs unlocks (and forces)
-> (DONE) to test: rejectEntityPlacement with mine instead of destroy - how waterfill behaves with it?

-> WHAT happens when landfill is placed when there are some existing dry tiles?
    
    (THIS OK)
    initial looks at code suggest its ok because landfill removes from grid
    and depletion visuals are based on the grid tile data (current name vs original name)
    
    (DONE)
    fix dry tiles being forgotten (orphaned) when waterbody removed (split) - they are still water tiles
    and they should be treated as water tiles when scanning again after split
    account for them (orphaned) in waterbody merge - no need to make orphans

    test a bit more


-> Optimize the depletion appearance as it is very slow. Options include (can be mixed with re-trials to grab WBs tiles to change):
    guessing tiles around focus point
    sampling limited tiles and sorting - sorting too expensive in full way? so maybe just taking some of the the tiles below moving average? some will be worse (or maybe initial ones can be dropped regardless until moving average stabilizes)
        moving average can be kept between ticks - idk when should it be reset - when focus point changes? - i.e. pump built / removed / Min/Max change?
        should we use center of mass of body or min /max center is ok - we could build it up when scanning too..
        focus point calculated also can be stored or even separately min/max center and pumps center - but should probably be invalidated/removed on action changing it - or give it a little leeway?

    BTW. we can also use for that taking connected tiles but first we need to hit some tile close to focus point. we could try tile then edge pattern then expand somehow else until we hit something? 
    and after we obtain a tile that BELONGS to WB that we believe is close to focus point we could take larger and larger areas of connected tiles for depletion - some focus point leeway could be given because this search for tile can also make some inaccuracies anyway?
-> I believe all dried tiles should be held on a stack so on restoration we don't care about patterns / or if they changed (pumps/shapes) we just take from stack and restore that - only adding to a way to add to stack might change.


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


(DONE - need test)
-> separate scanning loop update?
    that happens a few times per second?
    (DONE - need test)
    and calculate water area only on big updates cause it takes some time?
    
    (DONE - need test)
    - looks good but need to add again update message on tile added on big updates - how?
    Update message after calculate if flag on state to update msg is true - add this flag.
    (DONE - need test)
    Waterbodies could have their scan amounts at default value but after split only the retaining wb would have full scan value, and others will be have lower not to block different wbs too much - make that into as weight when dividing wbs scan amounts.

-> Track waterbody mass center by accumulating x and y and dividing by added tiles - then formula with some state value of it - for efficiency.

    Use above to determine waterbody split by split tiles distance and maybe retain the name and other states that should be kept. Merge waterbodies on priority - maybe waterbody type lake/sea etc that would be retained after split, only after on current scanned area.



-> update bounding box not after every tile but after whole batch - scan can hold min,max of visited tiles and then we can combine it at the end only!

(DONE)
-> DONT deplete waterbodies on small updates when its still scanning..
    need some 'temp restriction' - maybe another field ? that deactivates the pump but not THE same depletion interface - and no depletion message either
    water area recalc would add more water and then something else (or recalc?) can lift restriction - all of this on big update or scanning update? - big looks good

-> What if we held global tile info including tile_name and original name (not only waterBodyId) - probably bad idea because slower access to waterBodyId + still would rather have waterGridWithData for depletion - tile selection purposes - then it might be indicator but w/e. HOWEVER option with separate than waterBodyId would mitigate this problem only increase WRITE time when scanning + general maintenance of this part - but it might be viable because then less grabbing tiles from surface. AND this would eliminate OrphanedDryTiles.
-> CONTRARY TO ABOVE - we could have less grabbing tiles from surface by grabbing connected chunks of water+dry tiles when scanning in some relatively big area, storing it in tiles to 'search' or 'process' and then processing them with or without edgepattern - both are viable but without edge pattern we wont have EdgeGrid. However, EdgeGrid seems to have no effect currently other than limiting search (already searched)

-> BTW. we could make sure that small orphaned waterbodies if not used won't pile up - we can make event hashmap on ticks and it would be known in advance on which tick we check (big update?) and we would ask hashmap for our internal events planned at this tick - which would involve recycling invalid waterbody after the water has 'regenerated' in it even though we dont compute/maintain regeneration we can store tick (in invalid WB) at which it went invalid and then we can setup this event to be on tick that the calculated 100% of water would be - still dont know if 100% of water per WB - (problem with taking over some or different types shallow/deep or if there were special tiles with higher regen) or per tile - hard to distinguish between shallow/deep if there is only 1 WB ref - however maybe it would setup 2 events?? moment when shallow and moment when deep tiles regenerate.
    But then - what about different water amount with multipliers of body type and of tiletype?
    Maybe it shouldn't be that way actually..
    What if all there was to water amount was shallow/deep but other values modified regen?
    AND also - just recalled - we can make 1 'event' to delete waterbody at point where last of its tiles would regenerate to full!
    AND when taking over tiles (new WBs) instead of fixed penalty - if after some time the penalty would be 'eased' by regen that has occured since previous WB was invalidated - it can most likely be easily calculated with a formula having max water amount on tile, current amount (which might require some thought) and tick when invalidated, and regen rate with tick when taking that tile.

-> Another idea is to remove dry tiles of waterbodies removed but on split it hardly makes sense.. does make sense for waterbody removed by orphaning or depletion + orphaned -> so, so.. idk.. it makes sense for it to happen on fully depleted but then all dry tiles disappear - and WB wouldn't be able to regen to deactivate pumps. So maybe depletion + orphaning if we want to have option for depleted water body to disappear - some decision (OR SETTING) should be made.. if depletion + orphaning then only orphaning partially depleted with dry tiles should also make sense to remove them.
    BTW. removing dry tiles would mean swapping them to tiles that dry tiles were created from - so no visible difference but no longer treated as water tile that can be part of WB.

---
2. Update budget on depletion appearance? - IDK
10. reevaluate mods additions (that were in original script) / mod updates, "ScenFunc" for scenario created games etc. - some additions that might handle logic in various cases and be useful
11. some stats commands etc.
13. consider the DriedTiles to be held in a separate indicator table of some levels - to quickly access and restore them - maybe the same for depletion happens gradually? like bootstrapping future computation if update budget is there? 


Someday:
14. consider re-adding drains?
