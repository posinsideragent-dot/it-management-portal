<#
.SYNOPSIS
  Creates the ITDMP SharePoint lists and columns with exact internal names.

.DESCRIPTION
  Reads scripts/itdmp_lists.json and creates every missing list and column
  through Microsoft Graph. Safe to run again: existing lists and columns are
  skipped. Never use "Create list from Excel": it names columns field_1,
  field_2 ... and the app cannot read them.

  Graph cannot set version history or break permission inheritance. Do these
  by hand afterwards (see docs/AdminSetup-DEV.md, Part I).

  Requires the Microsoft.Graph.Authentication module:
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser

  Run it as the setup admin only. The app never uses this account.

.PARAMETER SiteId
  Graph site ID. Defaults to the ITDMP-DEV site.

.PARAMETER Lists
  Optional list names to process. Default: all lists in the JSON file.

.PARAMETER ConfigPath
  Path to the JSON schema file. Default: itdmp_lists.json next to this script.

.PARAMETER UseDeviceCode
  Sign in with a code typed at https://microsoft.com/devicelogin. Use this if the browser sign-in fails.

.EXAMPLE
  .\Create-ItdmpLists.ps1 -WhatIf
  .\Create-ItdmpLists.ps1
  .\Create-ItdmpLists.ps1 -Lists IT_Tasks
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [string]$SiteId = 'sqlacc.sharepoint.com,626945d6-16e9-4fdd-8ad3-993720800677,f601c7c7-e0ff-4907-b2b3-05941f3acecf',
  [string[]]$Lists,
  [string]$ConfigPath = (Join-Path $PSScriptRoot 'itdmp_lists.json'),
  [string]$TenantId = 'de1751f9-e541-4dca-9fff-9366ccd7a998',
  [switch]$UseDeviceCode
)

$ErrorActionPreference = 'Stop'
$graph = 'https://graph.microsoft.com/v1.0'

function Invoke-Graph {
  param([string]$Method, [string]$Uri, $Body)
  if ($null -ne $Body) {
    $json = $Body | ConvertTo-Json -Depth 10 -Compress
    return Invoke-MgGraphRequest -Method $Method -Uri $Uri -Body $json -ContentType 'application/json'
  }
  return Invoke-MgGraphRequest -Method $Method -Uri $Uri
}

function Get-AllPages {
  param([string]$Uri)
  $items = @()
  while ($Uri) {
    $page = Invoke-Graph -Method GET -Uri $Uri
    $items += $page.value
    $Uri = $page.'@odata.nextLink'
  }
  return , $items
}

function New-ColumnBody {
  param($Col)
  $body = [ordered]@{
    name        = $Col.name
    displayName = $Col.name
    required    = [bool]$Col.required
    indexed     = [bool]($Col.indexed -or $Col.unique)
  }
  if ($Col.unique) {
    $body.enforceUniqueValues = $true
    $body.indexed = $true   # SharePoint requires an index for unique values
  }
  switch ($Col.type) {
    'text'      { $body.text = [ordered]@{ allowMultipleLines = $false; maxLength = 255 } }
    'multiline' { $body.text = [ordered]@{ allowMultipleLines = $true; textType = 'plain' } }
    'number'    {
      $n = [ordered]@{ decimalPlaces = 'automatic'; displayAs = 'number' }
      if ($null -ne $Col.min) { $n.minimum = $Col.min }
      if ($null -ne $Col.max) { $n.maximum = $Col.max }
      $body.number = $n
    }
    'dateTime'  { $body.dateTime = [ordered]@{ displayAs = 'default'; format = 'dateTime' } }
    'date'      { $body.dateTime = [ordered]@{ displayAs = 'default'; format = 'dateOnly' } }
    'bool'      { $body.boolean = @{} }
    'choice'    { $body.choice = [ordered]@{ allowTextEntry = $false; choices = @($Col.choices); displayAs = 'dropDownMenu' } }
    'hyperlink' { $body.hyperlinkOrPicture = [ordered]@{ isPicture = $false } }
    default     { throw "Unknown column type '$($Col.type)' for column '$($Col.name)'." }
  }
  if ($null -ne $Col.default) { $body.defaultValue = @{ value = [string]$Col.default } }
  return $body
}

if (-not (Test-Path $ConfigPath)) { throw "Schema file not found: $ConfigPath" }
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$targets = @($config.lists)
if ($Lists) { $targets = @($targets | Where-Object { $Lists -contains $_.name }) }
if ($targets.Count -eq 0) { throw 'No matching lists in the schema file.' }

$connect = @{ Scopes = 'Sites.Manage.All'; TenantId = $TenantId; NoWelcome = $true }
if ($UseDeviceCode) { $connect.UseDeviceCode = $true }
Connect-MgGraph @connect
$failures = New-Object System.Collections.Generic.List[string]
$summary = @()

try {
  $existingLists = Get-AllPages "$graph/sites/$SiteId/lists?`$select=id,name,displayName"

  foreach ($def in $targets) {
    Write-Host "`n== $($def.name)" -ForegroundColor Cyan
    $list = $existingLists | Where-Object { $_.displayName -eq $def.name -or $_.name -eq $def.name } | Select-Object -First 1

    if (-not $list) {
      if ($PSCmdlet.ShouldProcess($def.name, 'Create list')) {
        $list = Invoke-Graph -Method POST -Uri "$graph/sites/$SiteId/lists" -Body @{
          displayName = $def.name
          list        = @{ template = 'genericList' }
        }
        Write-Host "  created list $($list.id)" -ForegroundColor Green
      } else {
        Write-Host '  would create list'
        foreach ($c in $def.columns) { Write-Host "  would add column $($c.name) ($($c.type))" }
        continue
      }
    } else {
      Write-Host "  list exists $($list.id)"
    }

    $cols = Get-AllPages "$graph/sites/$SiteId/lists/$($list.id)/columns?`$select=name,displayName"
    $bad = @($cols | Where-Object { $_.name -match '^field_\d+$' })
    if ($bad.Count -gt 0) {
      $msg = "$($def.name): has columns named field_N (made by Excel import). Delete the list in SharePoint and run again."
      Write-Host "  ERROR $msg" -ForegroundColor Red
      $failures.Add($msg)
      continue
    }

    foreach ($c in $def.columns) {
      if ($c.name -eq 'Title') { continue }   # built in
      if ($cols | Where-Object { $_.name -eq $c.name }) { Write-Host "  skip $($c.name) (exists)"; continue }
      if ($PSCmdlet.ShouldProcess("$($def.name).$($c.name)", 'Create column')) {
        try {
          $null = Invoke-Graph -Method POST -Uri "$graph/sites/$SiteId/lists/$($list.id)/columns" -Body (New-ColumnBody $c)
          Write-Host "  added $($c.name)" -ForegroundColor Green
        } catch {
          $msg = "$($def.name).$($c.name): $($_.Exception.Message)"
          Write-Host "  FAILED $msg" -ForegroundColor Red
          $failures.Add($msg)
        }
      }
    }
    $summary += [pscustomobject]@{ List = $def.name; ListId = $list.id }
  }
}
finally {
  Disconnect-MgGraph | Out-Null
}

Write-Host "`n== List IDs (send the IT_Tasks one back so the app config can be updated)" -ForegroundColor Cyan
$summary | Format-Table -AutoSize
if ($failures.Count -gt 0) {
  Write-Host "`n$($failures.Count) problem(s):" -ForegroundColor Red
  $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}
Write-Host 'Done. Now do the manual steps in docs/AdminSetup-DEV.md Part I.' -ForegroundColor Green
