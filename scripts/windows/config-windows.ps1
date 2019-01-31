Param(
    [string]$config
)

# base64 decode and convert json string to obj of params
$paramJson = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($config))
$param = ConvertFrom-Json $paramJson

#turn into local vars
$ts_admin_un = $param.ts_admin_un
$ts_admin_pw = $param.ts_admin_pw
$reg_first_name = $param.reg_first_name
$reg_last_name = $param.reg_last_name
$reg_email = $param.reg_email
$reg_company = $param.reg_company
$reg_title = $param.reg_title
$reg_department = $param.reg_department
$reg_industry = $param.reg_industry
$reg_phone = $param.reg_phone
$reg_city = $param.reg_city
$reg_state = $param.reg_state
$reg_zip = $param.reg_zip
$reg_country = $param.reg_country
$license_key = $param.license_key
$install_script_url = $param.install_script_url
$local_admin_user = $param.local_admin_user
$local_admin_pass = $param.local_admin_pass

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

$secrets | ConvertTo-Json -depth 10 | Out-File "C:/tabsetup/secrets.json" -Encoding utf8

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

$registration | ConvertTo-Json -depth 10 | Out-File "C:/tabsetup/registration.json" -Encoding utf8

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

$config | ConvertTo-Json -depth 20 | Out-File "C:/tabsetup/myconfig.json" -Encoding utf8

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