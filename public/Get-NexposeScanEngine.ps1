Function Get-NexposeScanEngine {
<#
    .SYNOPSIS
        Returns scan engines available to use for scanning

    .DESCRIPTION
        Returns scan engines available to use for scanning

    .PARAMETER Id
        The identifier of the scan engine

    .PARAMETER Name
        The name of the scan engine

    .PARAMETER Address
        The ip address of the scan engine

    .PARAMETER SiteId
        The identifier of a site the scan engine is assigned to

    .PARAMETER IncludeEnginePools
        Switch to include any engine pools.  This is off by default

    .PARAMETER RefreshedOffset
        The number of hours to show if a scan engine is offline or not.  Default value is 2 hours

    .EXAMPLE
        Get-NexposeScanEngine -SiteId 5

    .EXAMPLE
        Get-NexposeScanEngine -Name 'DR Site'

    .NOTES
        For additional information please see my GitHub wiki page

    .FUNCTIONALITY
        GET: scan_engines
        GET: scan_engines/{id}
        GET: sites/{id}/scan_engine
        GET: SKIPPED - scan_engines/{id}/scan_engine_pools    # Returned data has this information
        GET: SKIPPED - scan_engines/{id}/sites                # Returned data has this information

    .LINK
        https://github.com/My-Random-Thoughts/Rapid7Nexpose
#>

    [CmdletBinding(DefaultParameterSetName = 'byId')]
    Param (
        [Parameter(ParameterSetName = 'byId')]
        [int]$Id = 0,

        [Parameter(Mandatory = $true, ParameterSetName = 'byName')]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'byAddress')]
        [string]$Address,

        [Parameter(Mandatory = $true, ParameterSetName = 'bySite')]
        [string]$SiteId,

        [switch]$IncludeEnginePools,

        [int]$RefreshedOffset = 2
    )

    Switch ($PSCmdlet.ParameterSetName) {
        'byId' {
            If ($Id -gt 0) {
                $engines = (Invoke-NexposeQuery -UrlFunction "scan_engines/$Id" -RestMethod Get)
            }
            Else {
                $engines = @(Invoke-NexposeQuery -UrlFunction 'scan_engines' -RestMethod Get)    # Return All
            }
        }

        'bySite' {
            $engines = (Invoke-NexposeQuery -UrlFunction "sites/$SiteId/scan_engine" -RestMethod Get)
        }

        Default {
            $engineList = @(Invoke-NexposeQuery -UrlFunction 'scan_engines' -RestMethod Get)
            Switch ($PSCmdlet.ParameterSetName) {
                'byName'    { $engines =  @($engineList | Where-Object { $_.name    -eq $Name    }) }
                'byAddress' { $engines =  @($engineList | Where-Object { $_.address -eq $Address }) }
            }
        }
    }

    # Get detailed information for "Status"
    [pscustomobject[]]$cmdObject = (Get-NexposeScanEngineAlternative)

    ForEach ($scan In ($engines | Sort-Object -Property id)) {
        # One of: Active, Pending-Auth, Incompatible, Not-Responding, Unknown
        [string]$status = ($cmdObject | Where-Object { $_.name -eq $scan.name }).status

        # Check last refreshed date, should be updated evey hour
        If ($scan.lastRefreshedDate) {
            [int]$Offset = ((Get-Date) - ($scan.lastRefreshedDate -as [datetime]))
            If (($Offset -gt $RefreshedOffset) -and ($status -eq 'Active')) {
                $status = 'Stale'
            }
        }

        If ($scan.port -eq '-1') { $status = 'Pool'      }
        If ($status    -eq   '') { $status = 'Undefined' }

        If ((($scan.port -eq '-1') -and ($IncludeEnginePools.IsPresent)) -or ($scan.port -ne '-1')) {
            [void]($scan | Add-Member -MemberType NoteProperty -Name 'status' -Value $status)
            Write-Output $scan
        }
    }
}
