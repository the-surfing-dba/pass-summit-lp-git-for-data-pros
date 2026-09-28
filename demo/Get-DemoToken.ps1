<#
    Get-DemoToken.ps1  —  mint a SHORT-LIVED (1-hour) GitHub App installation
    token (ghs_...) for the push-protection demo in git-struggles-walkthrough.ps1.

    WHY: GitHub push protection only blocks REAL, recognized tokens (fabricated
    ones slip past). A GitHub App installation token is a real ghs_ token that
    AUTO-EXPIRES in an hour — the safe, scriptable "throwaway" for a repeatable
    demo, with nothing to revoke.

    ONE-TIME SETUP (do this once):
      1. Create a GitHub App:  https://github.com/settings/apps/new
         - Name: anything (e.g. "pass-demo-token"); Homepage URL: anything.
         - Under "Webhook", UNCHECK "Active".
         - Permissions: none needed (leave all "No access") — we only MINT a
           token to trigger push protection; we never use it for anything.
         - Click "Create GitHub App"; note the "App ID".
      2. On the app page: "Generate a private key" -> downloads a .pem.
         Save it locally, e.g.  demo/pass-demo.private-key.pem  (*.pem is gitignored).
      3. "Install App" -> install it on THIS repo.

    USAGE (set the two env vars once, then just call the script):
      $env:GH_DEMO_APP_ID  = '123456'
      $env:GH_DEMO_APP_KEY = './demo/pass-demo.private-key.pem'
      $token = ./demo/Get-DemoToken.ps1        # -> ghs_...  (valid 1 hour)

    Requires PowerShell 7+ (uses RSA.ImportFromPem / SignData).
#>
[CmdletBinding()]
param(
    [string]$AppId          = $env:GH_DEMO_APP_ID,
    [string]$PrivateKeyPath = $env:GH_DEMO_APP_KEY,
    [string]$Repo           = 'the-surfing-dba/pass-summit-lp-git-for-data-pros'
)

if (-not $AppId -or -not $PrivateKeyPath)
    {
        throw "Set -AppId and -PrivateKeyPath (or `$env:GH_DEMO_APP_ID / `$env:GH_DEMO_APP_KEY). See the setup notes at the top of this file."
    }  # end if (missing args)

# --- build a short-lived RS256 JWT signed with the app's private key ---------
$now    = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$b64url = { param($bytes) [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
$header  = & $b64url ([Text.Encoding]::UTF8.GetBytes((@{ alg = 'RS256'; typ = 'JWT' } | ConvertTo-Json -Compress)))
$payload = & $b64url ([Text.Encoding]::UTF8.GetBytes((@{ iat = $now - 60; exp = $now + 540; iss = $AppId } | ConvertTo-Json -Compress)))
$signingInput = "$header.$payload"

$rsa = [System.Security.Cryptography.RSA]::Create()
$rsa.ImportFromPem((Get-Content -Raw -Path $PrivateKeyPath))
$sigBytes = $rsa.SignData(
    [Text.Encoding]::UTF8.GetBytes($signingInput),
    [Security.Cryptography.HashAlgorithmName]::SHA256,
    [Security.Cryptography.RSASignaturePadding]::Pkcs1)
$jwt = "$signingInput." + (& $b64url $sigBytes)

# --- exchange the JWT for a 1-hour installation token (ghs_...) ---------------
$headers = @{
    Authorization          = "Bearer $jwt"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}
$installId = (Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Repo/installation").id
$token     = (Invoke-RestMethod -Method Post -Headers $headers -Uri "https://api.github.com/app/installations/$installId/access_tokens").token
$token   # -> ghs_...  (expires in 1 hour; nothing to revoke)
