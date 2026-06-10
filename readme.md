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
