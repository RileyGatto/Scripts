# Scripts

PowerShell scripts for IT administration tasks.

---

## Get-ADUsersMissingPhoneNumbers.ps1

Audits phone numbers for all enabled users across both on-prem Active Directory and cloud-only Entra ID accounts.

### What it does

- Pulls all enabled users from AD and cloud-only Entra ID
- Flags users who have an unauthorised 1300 number (only Customer Service Officers are allowed to hold the 1300 number)
- Flags users who have no telephone AND no mobile set
- Exports a CSV report sorted by issue type, then name
- Prints a summary to the console when complete

### Requirements

- ActiveDirectory PowerShell module
- Microsoft.Graph.Users PowerShell module
- Permissions: `User.Read.All` in Microsoft Graph

### Configuration

At the top of the script, edit these variables before running:

| Variable | Description |
|---|---|
| `$CSGroup` | Name of the AD group whose members are allowed to hold the 1300 number |
| `$CS1300` | The 1300 number reserved for Customer Service |
| `$ReportPath` | Where the CSV report is saved (defaults to a `Reports` subfolder) |

### Output

A CSV saved to `Reports\PhoneAudit_yyyy-MM-dd_HHmm.csv` with columns:

| Column | Description |
|---|---|
| Name | Display name of the user |
| Source | `AD` for on-prem users, `Entra` for cloud-only users |
| Title | Job title |
| Telephone | Office phone number |
| Mobile | Mobile number |
| Issue | What was flagged |

### Usage

```powershell
.\Get-ADUsersMissingPhoneNumbers.ps1
```

---

## Script Name

> Description of what this script does.

### What it does

-

### Requirements

-

### Configuration

-

### Usage

```powershell

```

---

## Script Name

> Description of what this script does.

### What it does

-

### Requirements

-

### Configuration

-

### Usage

```powershell

```

---
