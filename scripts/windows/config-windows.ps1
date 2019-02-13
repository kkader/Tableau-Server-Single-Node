Param(
    [string]$config
)

# base64 decode and convert json string to obj of params
$pJson = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($config))
$p = ConvertFrom-Json $pJson

## FILES
cd C:/
mkdir tabsetup

## 0. make install ps1 file
$cmd = "
try {
    Start-Process -FilePath \`"python.exe\`" -ArgumentList \`"C:/tabsetup/ScriptedInstaller.py install --secretsFile C:/tabsetup/secrets.json --configFile C:/tabsetup/myconfig.json --registrationFile C:/tabsetup/registration.json C:/tabsetup/tableau-server-installer.exe --start yes\`" -Wait -NoNewWindow -RedirectStandardOutput \`"C:\tabsetup\stdout.txt\`" -RedirectStandardError \`"C:\tabsetup\stderr.txt\`"
} catch {
    $_ | Out-File \`"C:\tabsetup\errors.txt\`" -Append
}
"

$cmd | Out-File "C:/tabsetup/installTableau.ps1"

## 1. make secrets.json file

$secrets = @{
    local_admin_user="$($p.local_admin_user)"
    local_admin_pass="$($p.local_admin_pass)"
    content_admin_user="$($p.ts_admin_un)"
    content_admin_pass="$($p.ts_admin_pw)"
    product_keys=@("$($p.license_key)")
}

$secrets | ConvertTo-Json -depth 10 | Out-File "C:/tabsetup/secrets.json" -Encoding ascii

## 2. make registration.json
$registration = @{
    first_name = "$($p.reg_first_name)"
    last_name = "$($p.reg_last_name)"
    email = "$($p.reg_email)"
    company = "$($p.reg_company)"
    title = "$($p.reg_title)"
    department = "$($p.reg_department)"
    industry = "$($p.reg_industry)"
    phone = "$($p.reg_phone)"
    city = "$($p.reg_city)"
    state = "$($p.reg_state)"
    zip = "$($p.reg_zip)"
    country = "$($p.reg_country)"
}

$registration | ConvertTo-Json -depth 10 | Out-File "C:/tabsetup/registration.json" -Encoding ascii

## 3. Create config file

$myconfig = @{
    configEntities = @{
        identityStore= @{
            _type= "identityStoreType"
            type= "local"
        }
    }
    topologyVersion = @{}
}

$myconfig | ConvertTo-Json -depth 20 | Out-File "C:/tabsetup/myconfig.json" -Encoding ascii

## 4. Download scripted installer .py (refers to Tableau's github page)
Invoke-WebRequest -Uri $p.install_script_url -OutFile "C:/tabsetup/ScriptedInstaller.py"

## 5. Download python .exe
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.7.0/python-3.7.0.exe" -OutFile "C:/tabsetup/python-3.7.0.exe"

## 6. Download Tableau Server 2018.2 .exe
Invoke-WebRequest -Uri "https://downloads.tableau.com/esdalt/2018.2.0/TableauServer-64bit-2018-2-0.exe" -Outfile "C:/tabsetup/tableau-server-installer.exe"

## COMMANDS

## 1. Install python (and add to path) - wait for install to finish
Start-Process -FilePath "C:/tabsetup/python-3.7.0.exe" -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait

## 2 Make tabinstall.txt
#New-Item c:/tabsetup/tabinstall.txt -ItemType file

## 3. Run installer script
cd "C:\Program Files (x86)\Python37-32\"

## Custom Script Extension is running as SYSTEM... does not have the permission to launch a process as another user
$securePassword = ConvertTo-SecureString $p.local_admin_pass -AsPlainText -Force
$usernameWithDomain = $env:COMPUTERNAME+"\"+$p.local_admin_user
$credentials = New-Object System.Management.Automation.PSCredential($usernameWithDomain, $securePassword)

$command = $file = "C:/tabsetup/installTableau.ps1"
Enable-PSRemoting –force
Invoke-Command -FilePath $command -Credential $credentials -ComputerName $env:COMPUTERNAME
Disable-PSRemoting -Force

#Invoke-Command -Credential $credentials -ComputerName $env:COMPUTERNAME -ScriptBlock {
    #################################
    # Elevated custom scripts go here 
    #################################

#    try {
#        Start-Process -FilePath "python.exe" -ArgumentList "C:/tabsetup/ScriptedInstaller.py install --secretsFile C:/tabsetup/secrets.json --configFile C:/tabsetup/myconfig.json --registrationFile C:/tabsetup/registration.json C:/tabsetup/tableau-server-installer.exe --start yes" -Wait -NoNewWindow -RedirectStandardOutput "C:\tabsetup\stdout.txt" -RedirectStandardError "C:\tabsetup\stderr.txt"
#    } catch {
#        $_ | Out-File "C:\tabsetup\errors.txt" -Append
#    }
#}

## 4. Open port 8850 for TSM access & 80 for Tableau Server access
New-NetFirewallRule -DisplayName "TSM Inbound" -Direction Inbound -Action Allow -LocalPort 8850 -Protocol TCP
New-NetFirewallRule -DisplayName "Tableau Server Inbound" -Direction Inbound -Action Allow -LocalPort 80 -Protocol TCP

## 4. Clean up secrets
del c:/tabsetup/secrets.json