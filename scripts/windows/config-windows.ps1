Param(
    [string]$ts_admin_un,
    [string]$ts_admin_pw,
    [string]$reg_first_name,
    [string]$reg_last_name,
    [string]$reg_email,
    [string]$reg_company,
    [string]$reg_title,
    [string]$reg_department,
    [string]$reg_industry,
    [string]$reg_phone,
    [string]$reg_city,
    [string]$reg_state,
    [string]$reg_zip,
    [string]$reg_country,
    [string]$license_key,
    [string]$install_script_url,
    [string]$local_admin_user,
    [string]$local_admin_pass
)

## FILES

## 1. make secrets.json file
cd C:/
mkdir tabsetup

$secrets = @{
    local_admin_user="$local_admin_user"
    local_admin_pass="$local_admin_pass"
    content_admin_user="$ts_admin_un"
    content_admin_pass="$ts_admin_pw"
    product_keys=@("$license_key")
}

$secrets | ConvertTo-Json -depth 10 | Out-File "C:/tabsetup/secrets.json" -Encoding ASCII

## 2. make registration.json
$registration = @{
    first_name = "$reg_first_name"
    last_name = "$reg_last_name"
    email = "$reg_email"
    company = "$reg_company"
    title = "$reg_title"
    department = "$reg_department"
    industry = "$reg_industry"
    phone = "$reg_phone"
    city = "$reg_city"
    state = "$reg_state"
    zip = "$reg_zip"
    country = "$reg_country"
}

$registration | ConvertTo-Json -depth 10 | Out-File "C:/tabsetup/registration.json" -Encoding ASCII

## 3. Create config file

$config = @{
    configEntities = @{
        identityStore= @{
            _type= "identityStoreType"
            type= "local"
        }
    }
    topologyVersion = @{}
}

$config | ConvertTo-Json -depth 20 | Out-File "C:/tabsetup/myconfig.json" -Encoding ASCII

## 4. Download scripted installer .py (refers to Tableau's github page)
Invoke-WebRequest -Uri $install_script_url -OutFile "C:/tabsetup/ScriptedInstaller.py"

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
$securePassword = ConvertTo-SecureString $local_admin_pass -AsPlainText -Force
$usernameWithDomain = $env:COMPUTERNAME+"\"+$local_admin_user
$credentials = New-Object System.Management.Automation.PSCredential($usernameWithDomain, $securePassword)

Invoke-Command -Credential $credentials -ComputerName $env:COMPUTERNAME -ArgumentList $ErrorLog -ScriptBlock {
    #################################
    # Elevated custom scripts go here 
    #################################
    Start-Process -FilePath "python.exe" -ArgumentList "C:/tabsetup/ScriptedInstaller.py install --secretsFile C:/tabsetup/secrets.json --configFile C:/tabsetup/myconfig.json --registrationFile C:/tabsetup/registration.json C:/tabsetup/tableau-server-installer.exe --start yes" -Wait -NoNewWindow
}

## 4. Open port 8850 for TSM access & 80 for Tableau Server access
New-NetFirewallRule -DisplayName "TSM Inbound" -Direction Inbound -Action Allow -LocalPort 8850 -Protocol TCP
New-NetFirewallRule -DisplayName "Tableau Server Inbound" -Direction Inbound -Action Allow -LocalPort 80 -Protocol TCP

## 4. Clean up secrets
del c:/tabsetup/secrets.json