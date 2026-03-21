# UI Functions To Do List

Functions called by `metadata_manager()` that need to be built.

---

## **CORE WORKFLOW FUNCTIONS**

### **✅ Already Built:**
1. **`ui_log_maintenance()`** 
   - **Status:** Built but needs simplification
   - **Changes needed:** Remove relocation handling (Section 13.5)
   - **Returns:** `list(device_serial, station_id, action_type, ports_updated)` or NULL

---

### **❌ To Build (Priority Order):**

### **HIGH PRIORITY** (Most commonly used)

2. **`ui_add_device(is_new_station = TRUE/FALSE)`**
   - **What it does:** Add new device to metadata
   - **Prompts for:** 
     - If new station: watershed, area, site_full, site, station_type, station_id
     - If existing: select station (inherits site info)
     - Device details: serial, role, name, manufacturer
     - Location: lat, lon, elev
     - Timing: interval, timezone, deploy_datetime
     - Status, download approval, expiry date
   - **Calls:** `add_new_device(device_data)`
   - **Returns:** `list(device_serial = "z6-12345")` or NULL

3. **`ui_initialize_ports(device_serial)`**
   - **What it does:** Set up initial port configuration for new device
   - **Prompts for each port 1-6:**
     - Is this port occupied? (Y/N)
     - If yes: sensor type, depth (if applicable), defunct? (Y/N)
     - Auto-determines type (vwc/weather) from sensor name
   - **Calls:** `initialize_ports(device_serial, port_config)`
   - **Returns:** TRUE or NULL

4. **`ui_update_ports()`**
   - **What it does:** Update port configuration for existing device
   - **Prompts for:**
     - Device selection
     - Shows current config
     - Change datetime
     - For each port: Change? (Y/N), if yes reconfigure
   - **Calls:** `update_ports(device_serial, port_config, change_datetime)`
   - **Returns:** TRUE or NULL

---

### **MEDIUM PRIORITY** (Field work functions)

5. **`ui_log_download()`**
   - **What it does:** Log manual data download (for HOBO/local devices)
   - **Similar to:** `ui_log_maintenance()` but simpler
   - **Prompts for:**
     - Field visit date
     - Station selection
     - Device selection
     - Details
     - Who logged it
   - **Calls:** 
     - `create_maintenance_entry()` with action_type = "download"
     - `update_last_visit()`
     - Updates `last_download_date` = `field_visit_date`
   - **Returns:** `list(device_serial, station_id)` or NULL

6. **`ui_replace_device()`**
   - **What it does:** Mark old device as "replaced" and add new device
   - **Prompts for:**
     - Station selection
     - Confirm old device to replace
     - New device details (calls ui_add_device logic)
   - **Calls:** 
     - `update_station_status()` to set old device to "replaced"
     - `add_new_device()` for new device
   - **Returns:** `list(old_device_serial, new_device_serial)` or NULL

7. **`ui_relocate_station()`**
   - **What it does:** Move station to new location
   - **Prompts for:**
     - Station selection
     - New lat/lon
     - Deployment datetime at new location
     - Status at new location
     - Download approval
   - **Calls:** `relocate_station(station_id, new_lat, new_lon, deploy_datetime, new_status, download_approved)`
   - **Returns:** TRUE or NULL

8. **`ui_decommission_station()`**
   - **What it does:** Shut down station permanently
   - **Prompts for:**
     - Station selection
     - Confirmation
   - **Calls:** `update_station_status(station_id, "decommissioned")`
   - **Returns:** TRUE or NULL

9. **`ui_reactivate_station()`**
   - **What it does:** Reactivate a decommissioned station
   - **Prompts for:**
     - Select from decommissioned stations
     - Same location or new location?
     - If new: new lat/lon
     - New device details
     - Status, download approval
   - **Calls:** `add_new_device()` with inherited metadata from old station
   - **Returns:** `list(device_serial)` or NULL

---

### **LOW PRIORITY** (View/reference functions)

10. **`ui_view_metadata()`**
    - **What it does:** Display device metadata in readable format
    - **Prompts for:** Filter options (all, by station, by status, etc.)
    - **Calls:** `load_zentra_metadata()`
    - **Returns:** NULL

11. **`ui_view_ports()`**
    - **What it does:** Display port configurations
    - **Prompts for:** Device selection or all devices
    - **Calls:** `load_zentra_ports_data()`, `get_current_port_config()`
    - **Returns:** NULL

12. **`ui_view_maintenance_log()`**
    - **What it does:** Display maintenance log entries
    - **Prompts for:** Filter options (recent, by station, by action type, etc.)
    - **Calls:** `load_maintenance_log()`
    - **Returns:** NULL

13. **`ui_view_download_log()`**
    - **What it does:** Display download log entries
    - **Prompts for:** Filter options
    - **Calls:** `load_download_log()`
    - **Returns:** NULL

---

## **Build Order Recommendation:**

1. ✅ Simplify `ui_log_maintenance()` (remove Section 13.5)
2. ❌ `ui_add_device()` - Foundation for many workflows
3. ❌ `ui_initialize_ports()` - Pairs with add_device
4. ❌ `ui_update_ports()` - Common field task
5. ❌ `ui_log_download()` - Simple, similar to maintenance
6. ❌ `ui_replace_device()` - Builds on add_device
7. ❌ `ui_relocate_station()` - Uses relocate_station logic
8. ❌ `ui_decommission_station()` - Simple status update
9. ❌ `ui_reactivate_station()` - Builds on add_device
10. ❌ View functions (can wait until everything else works)

---

## **Notes:**

- All functions should handle 'q' to quit gracefully
- All should use the helper UI functions (ui_yes_no, ui_select_from_menu, etc.)
- All should return NULL if user quits, data structure if successful
- HOBO device handling is done in `metadata_manager()`, not in individual functions
