TODO:

# Pump water usage calculation

Since there is no function to query CURRENT pumping speed of offshore pump below approach is not viable atm:

## suggested approach with current pumping speed available

-> Pump water usage - get pumping speed every X ticks of each offshore pump
-> use estimation algorithm of water usage throughout the whole arbitrary period using the stats - in the edge case where every tick collects pumping speed -> we get exact algorithm

THE OTHER ONE IS ALSO IMPOSSIBLE - TURNS out you cannot differentiate between prototypes when getting production stats..

## the other approach - using force production statistics per prototype

-> prepare more prototypes i.e. 10 ? of offshore pumps and place them accordingly:
-> each force tracks its own unique waterbody per surface - it replaces pumps to OTHER - indexed - prototypes per waterbody
-> it allows to get force water usage per unique waterbody - not per exact pump but its enough for all current purposes

## The Electricity used approach -> seems viable

-> prepare generated prototypes (i.e. 10?) of offshore pumps and place them accordingly:
-> track valid waterbody index per surface - it replaces pumps to indexed prototypes with this index
-> disable quality / make sure no modules / nothing can change water pumped to energy usage ratio of pumps - all pumps of the same prototype use the same water pumped to energy usage ratio
-> do not drain energy passively from energy buffers
-> track energy buffers
-> this way there's a proxy to calculate (through per surface energy usage of prototype) the total water pumped per waterbody (but not per force / player neither per pump)


----
CURRENT PLAN:

0. maybe require only 1 pole in range of an offshore-pump? reject placement if another is there? - on teleported too?
1. Finish tracking of Pumps / Poles and cleaning of Poles if no Pumps are around
2. for active pumps require some pole? -> pump.is_connected_to_electric_network(), 
3. get rid of force/surface tracking 
4. check whether you can get rid of no fluid pumps by deactivating (active=0) pumps
5. check if even pickier dollies is enabled, add it to optional dependencies, blacklist offshore pumps (and drains) for even pickier dollies; check whether all transport belts are also blacklisted
6. handle script_raised_teleported (and test it) on power poles (and on offshore pumps IF point 5. cannot be done)
7. pole / pump.electric_network_id

8. you can probably get input_position of pump from entity property


----

1. Initial scans for pumps / poles when mod hasn't been initialized yet?
2. Update budget on depletion appearance?
3. Map Marker
4. regen algorithm with bonuses -> i.e. more water used a bit more regen but maybe goes down with depletion?
5. validating forces data
6. tech tracking again
7. tech now decreases the actual water drainage instead of increasing the amnt water and regen? need to change descriptions too in files etc.
8. a general review of all settings in settings.lua and their descriptions in the locale file would be good to ensure they perfectly - there TODOs about it in control.lua
9. comprehensive tests - plan out test suite (especially for merging/splitting water bodies) etc, lifecycles etc.
10. reevaluate mods additions (that were in original script) / mod updates, "ScenFunc" for scenario created games etc. - some additions that might handle logic in various cases and be useful
11. some stats commands etc.
12. consider re-adding drains?