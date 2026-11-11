# EpmTools GUI

> A WPF-based graphical interface for the **Microsoft Endpoint Privilege Management (EPM)** PowerShell module (`EpmCmdlets.dll`). Provides a dark-themed, point-and-click wrapper around the EPM Agent cmdlets — no command line required.

![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20x64-5391FE?logo=powershell&logoColor=white)
![ARM64](https://img.shields.io/badge/ARM64-supported-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## 📋 Requirements

- **Windows 10 / 11** with the Microsoft EPM Agent installed via Intune
- **EPM policy** deployed to the device
- **Windows PowerShell 5.1 x64** — the script auto-relaunches under x64 if needed (ARM64 supported)
- Module path:
  ```
  C:\Program Files\Microsoft EPM Agent\EpmTools\EpmCmdlets.dll
  ```

## 🚀 Usage

1. Right-click the script → **Run with PowerShell**, or launch it manually:

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -STA -File "EpmTools-GUI.ps1"
   ```

2. Click **⚡ Load EpmTools Module** in the sidebar.
3. Navigate to a cmdlet tab, set parameters, and click **Run**.
4. Results appear in the **Results Grid** tab. Use **Export CSV** or **Export JSON** to save data.

## ✨ Features

### Supported cmdlets

| Cmdlet | Description |
|--------|-------------|
| `Get-Policies` | Retrieve **ElevationRules** or **ClientSettings** policies from the EPM Agent |
| `Get-DeclaredConfiguration` | List WinDC documents targeted to this device |
| `Get-DeclaredConfigurationAnalysis` | Check which MSFTPolicies are processed by the EPM Agent |
| `Get-ElevationRules` | Look up elevation rules by **FileName** or **CertificatePayload** |
| `Get-ClientSettings` | Display effective client settings used by EPM on this device |
| `Get-FileAttributes` | Extract publisher and CA certificates from an `.exe` for rule building |
| **Create Rule** (Intune) | Build an elevation rule and push it to an Intune elevation rules policy via Graph |
| **Rule Policies** (Intune) | Browse and export Intune elevation rules policies |
| **Client Settings** (Intune) | Create, deploy and edit Intune elevation settings policies |

### Reports

**REPORTS → Reports** uses the Intune reporting service (`POST /beta/deviceManagement/reports/exportJobs`):
the tool starts an export job, waits for it to finish and downloads the result.

| Report | Intune report name |
|---|---|
| Elevation events (last 7 / 30 / 90 days or everything) | `EpmElevationReportElevationEvent` |
| By application | `EpmAggregationReportByApplicationV2` (falls back to `EpmAggregationReportByApplication`) |
| By publisher | `EpmAggregationReportByPublisherV2` (fallback without V2) |
| By user | `EpmAggregationReportByUserV2` (fallback without V2) |
| Denied | `EpmDeniedReport` |
| Most frequent | `EpmInsightsMostFrequentElevations` |
| Elevation trend | `EpmInsightsElevationTrend` |

Every report opens in its own **report window**:
- **Filters per column**, built from the data: a checklist with counts for columns with few distinct values
  (e.g. ElevationType, Result, Publisher), from/to for number and date columns, "contains" for the rest,
  plus a search across all columns and *Clear all filters*.
- **Column chooser**, sortable and reorderable columns, multi-row selection, live row counts.
- **Export filtered rows** or **Export selected rows** to CSV or JSON (visible columns, in their order),
  **Copy selected** to the clipboard.
- Elevation events: **Create rule from selection** opens the event in the Create Rule wizard.

User accounts need an Intune role with **Endpoint Privilege Management Policy Authoring › View Reports**
(`EpmPolicy.ViewReports`); without it Intune returns 403.
The elevation event report doesn't include the signing certificate, so rules created from an event match on hash
(add a certificate on the Rule details step if you want one).

### Intune: authentication

**INTUNE → Authentication** holds the one Microsoft Graph connection used by Reports and every Intune page
(the sidebar shows whether you're connected). Choose:

- **User account** — browser sign-in (OAuth2 with PKCE, delegated). Requests
  `DeviceManagementManagedDevices.Read.All`, `DeviceManagementConfiguration.ReadWrite.All` and
  `Group.Read.All`; admin consent may be required.
- **Service principal + secret** — tenant ID, client ID and client secret of an app registration with the
  same three *application* permissions and admin consent. The token renews automatically. The secret stays
  in memory only; tenant and client ID can be remembered in `%APPDATA%\EpmTools\settings.json`.

The page shows the account, tenant, token expiry and granted permissions (and any that are missing).
**Disconnect** clears the token and secret from memory.

### Intune: create EPM rules

The **INTUNE → Create Rule** page builds an elevation rule and pushes it to an Intune
*Elevation rules policy* through Microsoft Graph (beta). The EPM agent is **not** needed for this,
so you can run it from an admin workstation.

1. Sign in once on **INTUNE → Authentication** (see below).
2. **Source** — pick an `.exe` (SHA-256, version info, publisher and CA certificate are read
   locally), an **elevation event** from the EPM report, a saved **draft**, or start blank.
   Tick which attributes the rule should match on.
3. **Rule details** — file match, signature (upload a certificate or use a reusable one),
   elevation type (Automatic, User confirmed, Support approved, Elevate as current user, Deny),
   validation and child-process behaviour. A strength meter and a live payload preview update as you type.
4. **Target policy** — add to an existing elevation rules policy (warns about existing rules for the
   same file and can replace them) or create a new policy and assign it to all users, all devices or a group.
5. **Review & push** — **Dry run** shows the exact Graph request in *Raw Output* without changing
   anything; **Push** saves a JSON backup of the policy to `Documents\EpmTools\Backups` first.

### Intune: EPM client settings

**INTUNE → Client Settings** creates, deploys and edits Windows *Elevation settings policies*:
Endpoint Privilege Management (enabled/disabled), default elevation response (not configured, deny all,
require support approval, require user confirmation with optional business justification / Windows
authentication), send elevation data for reporting and reporting scope.

- Lists existing elevation settings policies with their values and assignments, and warns when more
  than one exists (a device should get only one, or matching values).
- **Create & deploy** assigns the new policy to all users, all devices or a group; **Edit selected**
  loads a policy into the form and saves changes (assignments are kept). **Dry run** shows the request.
- The setting IDs are read from your tenant's template and matched by name; if they can't be read,
  nothing is sent.

**INTUNE → Rule Policies** lists your elevation rules policies, shows their rules in the grid and exports them as JSON.

> Settings Catalog IDs are read from your tenant's own setting definitions at push time, with
> built-in IDs as a fallback. Try a dry run (or a test policy) the first time you use it.

### Output panes

| Pane | Description |
|------|-------------|
| 🖥️ **Console Log** | Timestamped log with `INFO` / `OK` / `WARN` / `ERR` levels, including verbose output from cmdlets |
| 📄 **Raw Output** | JSON or formatted text view of the last result |
| 📊 **Results Grid** | Sortable, scrollable data grid |

### Export

CSV and JSON export via Save dialog, available after any successful query.

## 📝 Notes

- The script **auto-detects and relaunches** under Windows PowerShell x64 if running under PowerShell 7 or a 32-bit process, since `EpmCmdlets.dll` is x64-only.
- `Get-FileAttributes` **auto-discovers** the correct parameter names from the loaded cmdlet to handle version differences between EPM Agent releases.
- If the module path is missing, the tool shows a **clear error** pointing to the Intune policy requirement.
