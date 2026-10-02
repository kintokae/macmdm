# TDX Mass Update

A native macOS (SwiftUI) app for bulk-updating **TeamDynamix (TDX) assets** from a CSV, modeled on
[Jamf's MUT](https://github.com/jamf/mut): connect, download a template, load a CSV, review the
pre-flight checks, preview the changes, then submit.

## Requirements
- macOS 13 Ventura or later
- Xcode 15+ (or the Swift 5.9+ command-line toolchain)
- A TDX account with permission to edit assets in the target Assets/CIs app, **or** an admin
  service account (BEID + Web Services Key)

## Build & run
```bash
swift run                 # quick start
./build-app.sh            # produces "TDX Mass Update.app"
open Package.swift        # or open in Xcode and press ⌘R
```
`build-app.sh` adds the icon from `Resources/AppIcon.icns`. In an Xcode project, drag
`Resources/AppIcon.appiconset` into your asset catalog instead.

If you move this into a sandboxed Xcode app target, enable **Outgoing Connections (Client)** and
**User Selected File: Read/Write**.

## Connecting
| Setting | Example |
|---|---|
| Web API URL | `https://yourorg.teamdynamix.com/TDWebApi` (use `/SBTDWebApi` for sandbox) |
| Assets app ID | The number in your Assets app URL, e.g. `.../Apps/42/Assets/...` |
| Sign in | Username/password (`/api/auth/login`) or BEID + Web Services Key (`/api/auth/loginadmin`) |

**Verify Connection** signs in and loads the app's asset statuses, which also shows you the
`StatusID` values to put in your CSV. Passwords/keys are kept in the login keychain.

## CSV format
- **Column 1** identifies the asset. Choose what it holds in the toolbar: *Asset ID*,
  *Serial Number*, or *Asset Tag*. Serial and tag lookups must match exactly one asset.
- **Other columns** are fields to set. Headers are case-insensitive:

  `Name, SerialNumber, Tag, ExternalID, StatusID, LocationID, LocationRoomID, OwningCustomerID,
  OwningDepartmentID, RequestingCustomerID, RequestingDepartmentID, ManufacturerID, ProductModelID,
  SupplierID, ParentID, MaintenanceScheduleID, PurchaseCost, AcquisitionDate, ExpectedReplacementDate`

- **Custom attributes:** `Attribute:<AttributeID>` (e.g. `Attribute:10234`). For choice
  attributes, the value is the choice ID.
- **Blank cell** = leave the current value alone. **`CLEAR!`** = empty the field (as in MUT).
- Customer columns take the person's UID (GUID). Dates accept `YYYY-MM-DD` or `M/D/YYYY`.

```csv
SerialNumber,StatusID,LocationID,Attribute:10234
C02XK0ABJGH5,12,301,Lab 4
C02YL1CDJGH6,12,,CLEAR!
```

## How an update works
For each ready row the app looks up the asset (search by serial/tag if needed), `GET`s the full
asset, applies only the cells you filled in, and — if anything actually differs — `POST`s the full
asset back to `api/{appId}/assets/{id}`. Rows that already match are marked *Skipped*.

- **Dry run is on by default.** It performs the lookups and shows the exact before → after diff for
  every row without saving anything. Turn it off and confirm to write changes.
- Requests are throttled (default 60/min, adjustable) and HTTP 429 responses are retried after the
  rate-limit reset. Expired tokens are refreshed automatically.
- **Export Results…** writes a CSV of line, identifier, status, changes and message.

## Notes
- TDX replaces an asset's custom attribute set when it's edited, so the app always sends every
  existing attribute back; `CLEAR!` on an attribute column removes that one.
- Test in your sandbox (`SBTDWebApi`) first.
