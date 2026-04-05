# Testing metadata_manager.R
source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "code/functions/setup_functions.R"))
load_functions("metadata_manager")
load_functions("metadata")

################################################################################
# To backup (run once at start):
#source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools", "backup_directory_for_testing.R"))
# To restore (run anytime to reset):
source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools", "restore_directory_from_backup.R"))
################################################################################
metadata_manager()


################################################################################
# METADATA MANAGER TESTING CHECKLIST
# Run each test, check off when complete, restore if anything breaks
################################################################################

# === SETUP (ONE TIME) ===
# [X] Create backup of pristine metadata
#     source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools", "backup_metadata_for_testing.R"))

# === PHASE 1: READ-ONLY TESTS (SAFE - START HERE) ===

# [X] Test 1.1: View all device metadata
#     metadata_manager() → View/check metadata → All devices

# [X] Test 1.2: View metadata filtered by station
#     metadata_manager() → View/check metadata → Filter by station → Pick one

# [X] Test 1.3: View metadata filtered by status
#     metadata_manager() → View/check metadata → Filter by status → Pick one

# [X] Test 1.4: View all active port configurations
#     metadata_manager() → View/check metadata → Port configurations → All devices

# [X] Test 1.5: View specific device port history
#     metadata_manager() → View/check metadata → Port configurations → Specific device (all configs)

# [X] Test 1.6: View maintenance log (recent entries)
#     metadata_manager() → View/check metadata → Maintenance log → Recent entries

# [X] Test 1.7: View maintenance log filtered by station
#     metadata_manager() → View/check metadata → Maintenance log → Filter by station

# [X] Test 1.8: View download log
#     metadata_manager() → View/check metadata → Download log → Recent downloads

# === PHASE 2: SIMPLE TESTS (LOW RISK) ===

# [X] Test 2.1: Log routine maintenance - cleaning
#     metadata_manager() → Worked on existing → Routine maintenance
#     Action: cleaning, check maintenance_log.csv for new entry

# [X] Test 2.2: Log routine maintenance - battery
#     metadata_manager() → Worked on existing → Routine maintenance
#     Action: battery, check last_visit updated

# [X] Test 2.3: Log routine maintenance with status change to defunct
#     metadata_manager() → Worked on existing → Routine maintenance
#     Change status to "defunct", verify status updated in metadata

# [ ] Test 2.4: Log manual download for HOBO device
#     metadata_manager() → Worked on existing → Downloaded data
#     Check last_download_date updated

# [X] Test 2.5: Log manual download for Zentra local device
#     metadata_manager() → Worked on existing → Downloaded data
#     Check maintenance log entry created

# === PHASE 3: PORT CONFIGURATION TESTS (MEDIUM RISK) ===

# [X] Test 3.1: Change sensor depth on one port
#     metadata_manager() → Worked on existing → Port configuration change
#     Change depth on port 2, verify old config closed, new config created

# [X] Test 3.2: Swap sensor type on one port
#     metadata_manager() → Worked on existing → Port configuration change
#     Change TEROS-10 to TEROS-12, verify change logged correctly

# [X] Test 3.3: Add sensor to empty port
#     metadata_manager() → Worked on existing → Port configuration change
#     Add sensor to previously empty port, verify config created

# [X] Test 3.4: Remove sensor from occupied port
#     metadata_manager() → Worked on existing → Port configuration change
#     Empty an occupied port, verify config shows sensor="none"

# [X] Test 3.5: Mark sensor as defunct via port config
#     metadata_manager() → Worked on existing → Port configuration change
#     Mark a sensor defunct, verify status="defunct" in port config

# [X] Test 3.6: Change multiple ports at once
#     metadata_manager() → Worked on existing → Port configuration change
#     Change 3 ports, verify only changed ports get new configs


# === PHASE 4: DEVICE MANAGEMENT TESTS (HIGH RISK) ===

# [ ] Test 4.1: Add new device to existing station
#     metadata_manager() → Established new → New device at existing station
#     Add test device "z6-99999", initialize ports, verify created


# WHEN BEING ASKED TO ESTABLISH NEW SITE, NEED OPTION FOR NA FOR SELECT AREA
# AND POSSIBLY FOR APPROVAL OF DOWNLOAD - OR AT LEAST LANGUAGE SAYING, SAY NO IF LOCAL

# [ ] Test 4.2: Add HOBO device to existing station
#     metadata_manager() → Established new → New device at existing station
#     Add "h-99999", verify no port initialization offered


# [ ] Test 4.3: Replace Zentra device
#     metadata_manager() → Worked on existing → Device replacement
#     Replace test device, verify old status="replaced", new device created

# [ ] Test 4.4: Replace device and initialize ports
#     metadata_manager() → Worked on existing → Device replacement
#     Replace device, say Yes to port init, verify ports configured

# [ ] Test 4.5: Replace device at same location
#     Verify new device inherits lat/lon from old device

# [ ] Test 4.6: Replace device at different location
#     When prompted, enter new coordinates, verify location updated


# === PHASE 5: STATION LIFECYCLE TESTS (VERY HIGH RISK) ===

# [ ] Test 5.1: Create brand new station
#     metadata_manager() → Established new → Brand new station
#     Create "test_station_999" with all metadata, verify created

# [ ] Test 5.2: Create new station and initialize ports
#     Create new station, say Yes to port init, verify 6-port config

# [ ] Test 5.3: Relocate station to new coordinates
#     metadata_manager() → Worked on existing → Station relocated
#     Move test station, verify old device="relocated", new device at new location

# [ ] Test 5.4: Decommission station
#     metadata_manager() → Worked on existing → Station decommissioned
#     Decommission test station, verify status="decommissioned"

# [ ] Test 5.5: Reactivate station at same location
#     metadata_manager() → Established new → Reactivate decommissioned
#     Reactivate at same location, verify new device created with old coordinates

# [ ] Test 5.6: Reactivate station at new location
#     metadata_manager() → Established new → Reactivate decommissioned
#     Reactivate at new location, verify new device at new coordinates


# === PHASE 6: WORKFLOW TESTS (EDGE CASES) ===

# [ ] Test 6.1: Cancel mid-workflow (routine maintenance)
#     Start logging maintenance, press 'q' to quit, verify nothing written

# [ ] Test 6.2: Cancel mid-workflow (add device)
#     Start adding device, quit halfway, verify no partial data

# [ ] Test 6.3: Wrong workflow selection - use delete feature
#     Log routine maintenance when you meant to do port change
#     Say "Yes" to also doing port changes, cancel routine log, verify deleted

# [ ] Test 6.4: Do maintenance THEN port change (correct order)
#     Log maintenance, say Yes to anything else, do port change
#     Verify both logged correctly

# [ ] Test 6.5: Replace device then immediately configure new ports
#     Replace device, initialize ports for new device, verify chain works


# === PHASE 7: DATA INTEGRITY CHECKS ===

# [ ] Test 7.1: Check for duplicate unique_ids
#     metadata <- load_zentra_metadata()
#     any(duplicated(metadata$unique_id))  # Should be FALSE

# [ ] Test 7.2: Check all CSVs still parse correctly
#     metadata <- load_zentra_metadata()
#     ports <- load_zentra_ports_data()
#     maint <- load_maintenance_log()
#     # Should all load without errors

# [ ] Test 7.3: Check temporal consistency in ports
#     ports <- load_zentra_ports_data()
#     # For each device, verify valid_to dates < valid_from dates of next config

# [ ] Test 7.4: Check replaced devices have new rows
#     metadata <- load_zentra_metadata()
#     # Filter to status="replaced", verify each has a newer row at same station

# [ ] Test 7.5: Check relocated devices have new rows
#     metadata <- load_zentra_metadata()
#     # Filter to status="relocated", verify each has newer row with different coords


# === AFTER ALL TESTS ===

# [ ] Final restore to remove all test data
#     source(file.path(Sys.getenv("VI_FLO_ENGINE_ROOT"), "tools", "restore_metadata_from_backup.R"))

# [ ] Manually remove any test devices that were created
#     (Like "z6-99999", "test_station_999", etc.)

# [ ] Run metadata_manager() once on real data to verify everything works

# [ ] Keep backup folder for future testing sessions


################################################################################
# AFTER EACH TEST RUN THIS:

# Load and inspect
metadata <- load_zentra_metadata()
ports <- load_zentra_ports_data()
maint <- load_maintenance_log()

# Check for obvious issues
cat("Device count:", nrow(metadata), "\n")
cat("Any duplicate unique_ids?", any(duplicated(metadata$unique_id)), "\n")
cat("Any NA device_serials?", any(is.na(metadata$device_serial)), "\n")
cat("Port config count:", nrow(ports), "\n")
cat("Maintenance entries:", nrow(maint), "\n")

# View last few rows of each
tail(metadata, 3)
tail(ports, 3)
tail(maint, 3)

