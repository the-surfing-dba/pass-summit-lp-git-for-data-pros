<#
    Sync-DbaAvailabilityGroup — copy instance-level objects (logins, jobs,
    linked servers, etc.) from the primary replica to all secondaries in the
    specified AG so failovers don't lose supporting objects.

    Requires dbatools:  Install-Module dbatools -Scope CurrentUser
#>

[CmdletBinding(SupportsShouldProcess)]
param
    (
        [string] $Primary          = 'PASS',
        [string] $AvailabilityGroup = 'githublearningpath',
        [pscredential] $SqlCredential
    )

Import-Module dbatools -ErrorAction Stop

<#######################################
 #######################################
   Verify AG exists and gather replicas 
 #######################################  
 #######################################>
$agParams = @{
    SqlInstance       = $Primary
    AvailabilityGroup = $AvailabilityGroup
    EnableException   = $true
}
if ($SqlCredential) { $agParams.SqlCredential = $SqlCredential }

$ag = Get-DbaAvailabilityGroup @agParams
if (-not $ag)
    {
        throw "AG '$AvailabilityGroup' not found on '$Primary'."
    }  # end if (AG missing)

Write-Host "Primary:    $($ag.PrimaryReplica)"
Write-Host "Secondaries: $((($ag.AvailabilityReplicas | Where-Object Name -ne $ag.PrimaryReplica).Name) -join ', ')"

<#######################################
 #######################################
   Run the sync — dbatools discovers 
   secondaries from the AG automatically 
 #######################################  
 #######################################>
$syncParams = @{
    Primary           = $Primary
    AvailabilityGroup = $AvailabilityGroup
    EnableException   = $true
}
if ($SqlCredential) { $syncParams.PrimarySqlCredential = $SqlCredential }

try
    {
        Sync-DbaAvailabilityGroup @syncParams -Verbose
        Write-Host "Sync of '$AvailabilityGroup' from '$Primary' complete." -ForegroundColor Green
    }
catch
    {
        Write-Error "Sync failed: $($_.Exception.Message)"
        throw
    }  # end try/catch (sync)
