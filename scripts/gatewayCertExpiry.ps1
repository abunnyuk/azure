# Display expiry dates for Application Gateway SSL certs

param (
    [Parameter(Mandatory)]
    [string] $ResourceGroup,

    [Parameter(Mandatory)]
    [string] $GatewayName
)

$sslCerts = az network application-gateway ssl-cert list `
    --resource-group $ResourceGroup `
    --gateway-name $GatewayName `
    --query '[].publicCertData' `
    --output tsv

function Format-Certificate($publicCertData) {
    $certBytes = [Convert]::FromBase64String($publicCertData)
    $p7b = New-Object System.Security.Cryptography.Pkcs.SignedCms
    $p7b.Decode($certBytes)
    return $p7b.Certificates[0]
}

if ($sslCerts) {
    foreach ($cert in $sslCerts) {
        $x509 = Format-Certificate $cert

        [PSCustomObject] @{
            SSLCertSubject    = $x509.Subject;
            SSLCertThumbprint = $x509.Thumbprint;
            SSLCertExpiration = $x509.NotAfter;
        }
    }
}

# TODO - Auth Certs

# $authCerts = az network application-gateway auth-cert list `
#     --resource-group $ResourceGroup `
#     --gateway-name $GatewayName `
#     --query '[].data' `
#     --output tsv

# if ($authCerts) {
#     foreach ($cert in $authCerts) {
#         $x509 = Format-Certificate $cert

#         [PSCustomObject] @{
#             AuthCertSubject    = $x509.Subject;
#             AuthCertThumbprint = $x509.Thumbprint;
#             AuthCertExpiration = $x509.NotAfter;
#         }
#     }
# }
