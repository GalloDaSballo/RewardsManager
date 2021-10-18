# New Rewards Manager Contract for BADGER DAO


# Tests
1. Test that the no new badger reward points are added after the tree runs out of badgers balance

2. 1) So far in Badger the BADGER tokens schedules for each sett has been logged in a weekly basis and it is likely to keep similar schedule (best consult with Alex to triple check). 

It will be a great addition on the test suite to make sure that, say, schedules for 1st and 2nd week are set and depositors are able to claim  despite of posting a new schedule via the set(pid, allocPoint) method on the next week (3rd). In other words, if 1000BADGER were entitled for 1st week (for _pid=0), 960BADGER for 2nd week(for _pid=0) and 930 BADGER for 3rd week(for _pid=0) and an user has deposited on 1st X amount, he gets its amount entitled pro-rata based on the total lpSupply despite of only claiming on the 3rd week. The test should consider multiple setts and depositors to simulate proper scenario, as 1 depositor/sett check up will not bring corner cases.

# Notes

1. After doing a set() call it will change the allocPoint of all the pools. So we will need to do a massUpdatePool() call before calling the set() function.