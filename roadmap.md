# VI-FLO Engine: Automated System Architecture

## Layer 1: Atomic Operations (COMPLETE - v0.1.0)
Core functions that do one thing, assume metadata is correct:
- `download_zentra_station()` - Downloads station data (strict requirements)
- `download_zentra_device()` - Downloads device data
- `query_last_zentra_update()` - Gets fresh timestamps from API
- `get_zentra_metadata()` - Pulls device metadata from API

## Layer 1: Safe Wrappers (NEXT - v0.2.0)
Add guardrails and intelligence around atomic operations:

### `safe_download_station()`
- Checks last download timestamp (error if <7 days since last download)
- Trims requested period to available data (instead of erroring)
- Validates metadata freshness before proceeding
- Calls `download_zentra_station()`
- Stores raw output to `/raw/` with proper naming

### `refresh_station_metadata()`
- Queries Zentra API for latest device info
- Compares to local metadata
- Flags discrepancies for human review (DON'T auto-update critical fields!)
- Updates safe fields only: `last_update`, GPS coords (if drift < threshold), `subscription_expiry`
- Never auto-updates: port configs, sensor types, depths

### `validate_metadata_for_download()`
- Pre-download checks that catch errors before they happen:
  - Missing required fields
  - Overlapping port configs (same port, overlapping valid_from/valid_to)
  - Stations with no devices
  - Devices with no ports
  - Invalid dates (deploy_datetime > last_update)
  - Offline stations (last_update very old)
- Returns warnings/errors, prevents download if critical issues found

## Layer 2: Orchestration (FUTURE - v0.3.0)
High-level automation that runs on schedule:

### `weekly_data_update()`
Weekly automated job that:
1. Refreshes metadata (safe fields only via `refresh_station_metadata()`)
2. For each active station:
   - Check if >7 days since last download
   - Run `validate_metadata_for_download()`
   - If valid: call `safe_download_station()`
   - Store raw data
   - Run QA/QC (future)
   - Store intermediate data (future)
   - Log everything
3. Generate summary report
4. Email/notify on errors

---

## Development Order

**Phase 1: Validation**
Build the protective functions that catch problems:
- `validate_metadata_for_download()`
- `validate_port_config()` (helper)

**Phase 2: Safe Wrappers**
Build the intelligent wrappers:
- `safe_download_station()`
- `refresh_station_metadata()`

**Phase 3: Orchestration**
Build the automation:
- `weekly_data_update()`
- Logging infrastructure
- Error handling and reporting

---

## Key Design Principles

1. **Never auto-update critical metadata** - Port configs, sensor types, depths require human input
2. **Fail safely** - If metadata questionable, halt and notify rather than corrupt data
3. **Logging & traceability** - Every action logged with timestamp, version, outcome
4. **Raw data sanctity** - Never overwrite raw downloads, always preserve original API responses
5. **Human review for anomalies** - Flag suspicious changes (GPS drift, missing data) for review