<#
    Get-DbSecret — the RIGHT way to get a database credential into a script.

    Contrast with mysql/grant-all-michael-dspain.sql, which hardcodes
    `IDENTIFIED BY 'ChangeMe!123'` — a password that would be committed to
    Git history forever. This script never stores the secret in source:

      1. Prefers Azure Key Vault (audited, rotatable, RBAC-controlled).
      2. Falls back to an environment variable (e.g. from a .gitignored .env).
      3. Never writes the secret to disk or the console.

    Demo point: run `git log -p` on a hardcoded password vs. this approach —
    the secret is in NEITHER the working tree NOR the history.

    Requires (for Key Vault path): Install-Module Az.KeyVault -Scope CurrentUser
#>

[CmdletBinding()]
param
    (
        [Parameter(Mandatory)]
        [string] $SecretName,

        [string] $VaultName = $env:KEY_VAULT_NAME,

        # Name of the env var to fall back to if Key Vault isn't available.
        [string] $EnvVarFallback
    )

<#######################################
 #######################################
   1. Try Azure Key Vault first
 #######################################
 #######################################>
if ($VaultName)
    {
        try
            {
                $secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -AsPlainText -ErrorAction Stop
                if ($secret)
                    {
                        Write-Verbose "Retrieved '$SecretName' from Key Vault '$VaultName'."
                        return $secret
                    }  # end if (secret found)
            }
        catch
            {
                Write-Verbose "Key Vault lookup failed: $($_.Exception.Message). Falling back to env var."
            }  # end try/catch (key vault)
    }  # end if ($VaultName)

<#######################################
 #######################################
   2. Fall back to an environment variable
 #######################################
 #######################################>
if ($EnvVarFallback)
    {
        $val = [Environment]::GetEnvironmentVariable($EnvVarFallback)
        if ($val)
            {
                Write-Verbose "Retrieved '$SecretName' from env var '$EnvVarFallback'."
                return $val
            }  # end if (env var set)
    }  # end if ($EnvVarFallback)

throw "Secret '$SecretName' not found in Key Vault '$VaultName' or env var '$EnvVarFallback'. Nothing hardcoded — by design."
