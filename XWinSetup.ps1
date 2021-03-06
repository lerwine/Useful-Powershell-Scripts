Param(
	[switch]$NoElevate
)

$puttyInstallDir = "C:\Program Files (x86)\Putty";
$xMingInstallDir = "C:\Program Files (x86)\Xming"; # :0 -clipboard -multiwindow
$puttyBasePath = "HKCU:\Software\SimonTatham\PuTTY";
# TODO: Key names are different because we're setting up XMing and we're not checking ItssRestrictions (code had been copied from FixChmFileSecurity.ps1)
$keyName = "ItssRestrictions";
$propertyName = "MaxAllowedZone";
$propertyValue = [UInt32]0x00000003;

Function Test-WasReInvokedAsElevated {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$ScriptPath,
		[Parameter(Mandatory = $true)]
		[bool]$NoElevate
	)
	
	$currentPrincipal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent();
	
	if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { return $false }
	
    "You are not currently running this under Administrative privileges!" | Write-Warning;
	
	if ($NoElevate) { return $false; }
	
    $choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&Run as Admin", "&Continue with current Credentials", "&Exit");
    $userchoice = $host.ui.PromptforChoice("Warning","Please select whether to use Administrative or current credentials to run command", $choices, 0);
  
    if ($userchoice -eq 1) {
        "Using current credentials" | Write-Host;
		return $false;
    }
	
	if ($userChoice -eq 2) {
		"Aborting" | Write-Warning;
		return $true;
	}
	
	$tempBase = [Environment]::GetEnvironmentVariable("Temp","Machine") | Join-Path -ChildPath ("{0}_tmp" -f ([Guid]::NewGuid()).ToString("N"));
	$tempBatchFile = "{0}.bat" -f $tempBase;
	$tempScript = "{0}.ps1" -f $tempBase;
	$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False);
	[IO.File]::WriteAllLines($tempBatchFile, @(
		'@echo off',
		('powershell -ExecutionPolicy Bypass -File "{0}" -NoElevate' -f $tempScript)
		'pause'
	), $Utf8NoBomEncoding);
	try {
		$ScriptPath | Copy-Item -Destination:$tempScript -Force;
		try {
			$proc = Start-Process "cmd.exe" ('/C "{0}"' -f $tempBatchFile) -Verb:"RunAs" -PassThru;
			$proc.WaitForExit();
		} catch {
			("Error starting process: {0}" -f ($_ | Out-String)) | Write-Error;
		} finally {
			Remove-Item $tempScript -Force;
		}
	} catch {
		("Error starting process: {0}" -f ($_ | Out-String)) | Write-Error;
	} finally {
		Remove-Item $tempBatchFile -Force;
	}
	
	return $true;
}

Function Get-ExePath {
	[CmdletBinding()]
	Param(
		[Parameter(ValueFromPipeline = $true, Position = 0, Mandatory = $true)]
		[string]$BasePath,
		[Parameter(Position = 1, Mandatory = $true)]
		[string]$Name
	)
	
	$result = $BasePath | Join-Path -ChildPath: $Name;
	
	if ($result | Test-Path -PathType:Leaf) { return $result }
	("Cannot set up XWindows because {0} was not found in {1}." -f $Name, $BasePath) | Write-Error;
}

Function Invoke-XWinSetup {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$ScriptPath,
		[Parameter(Mandatory = $true)]
		[bool]$NoElevate
	)
	
	if (Test-WasReInvokedAsElevated -ScriptPath:$ScriptPath -NoElevate:$NoElevate) { return }
	
	[Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null;

	$puttyExePath = $puttyInstallDir | Get-ExePath -Name: "PUTTY.EXE";
	$pScpExePath = $puttyInstallDir | Get-ExePath -Name: "pscp.exe";
	$xMingExePath = $xMingInstallDir | Get-ExePath -Name: "Xming.exe";

	if ($puttyExePath -eq $null -or $pScpExePath -eq $null -or $xMingExePath -eq $null) {
		"Press a enter to continue..." | Write-Host;
		Read-Host | Out-Null;
		return;
	}

	if (-not ($puttyBasePath | Test-Path)) {
		("Cannot set up XWindows because Registry path {0} was not found: Either PUTTY was not installed, or it has never been used." -f $puttyBasePath) | Write-Error;
		"Press a enter to continue..." | Write-Host;
		Read-Host | Out-Null;
		return;
	}

	$keyPath = $puttyBasePath | Join-Path -ChildPath:"Sessions";
	if ($keyPath | Test-Path) {
		$Script:Sessions = $choices = [System.Management.Automation.Host.ChoiceDescription[]] @("[Create New]", ($keyPath | Get-Item).GetSubKeyNames());
	} else {
		$Script:Sessions = @();
	}

	if ($Script:Sessions.Length -gt 0) {
		$Script:UserChoice = $host.ui.PromptforChoice("Select Saved Session", "Please select saved session to use or [Create New] to create a new saved session", $choices, 0);
	} else {
		$Script:UserChoice = 0;
	}

	if ($Script:UserChoice -gt 0) {
		$Script:UserChoice = $choices[$Script:UserChoice];
		$Script:SessionKey = $keyPath | Join-Path -ChildPath:$Script:UserChoice | Get-Item;
	} else {
		$Script:UserChoice = "Enter name for session" | Read-Host;
		if ($Script:UserChoice -eq $null) { return }
		$Script:UserChoice = [System.Web.HttpUtility]::UrlEncode($Script:UserChoice.Trim());
		if ($Script:UserChoice.Length -eq 0) { return }
		$Script:SessionKey =  Join-Path -ChildPath:$Script:UserChoice | New-Item;
	}

	throw "Not implemented. Code following this throw command is not ready"
	
	try {
		$value = $Script:SessionKey | Get-ItemProperty -Name:$propertyName;
		if ($value.MaxAllowedZone -eq $propertyValue) {
			("{0} in {1} already set to {2}." -f $propertyName, $keyPath, $propertyValue) | Write-Host;
		} else {
			if ($value.MaxAllowedZone -eq $null) {
				("Adding DWord value of {0} to {1}." -f $propertyValue, $keyPath) | Write-Host;
			} else {
				("Changing value of {0} in {1} from ""{2}"" to ""{3}""." -f $propertyName, $keyPath, $value.MaxAllowedZone, $propertyValue) | Write-Host;
			}
			$Script:key | Set-ItemProperty -Name:$propertyName -Value:$propertyValue -ErrorAction:Stop;
			"Registry updated." | Write-Host;
		}
	} catch {
		if ($error[0].Exception -ne $null -and $error[0].Exception -is [System.Security.SecurityException]) {
			("Registry access writing to {0} is not allowed." -f $keyPath) | Write-Error;
		} else {
			("Error writing to registry path {0}: {1}" -f $keyPath, $error[0].Message) | Write-Error;
		}
	}

	"Press a enter to continue..." | Write-Host;
	Read-Host | Out-Null;
}

try {
	Invoke-XWinSetup -ScriptPath:($MyInvocation.MyCommand.Path) -NoElevate:$NoElevate;
} catch {
	("Unexpected Error: {0}" -f ($_ | Out-String)) | Write-Error;
	"Press a enter to continue..." | Write-Host;
	Read-Host | Out-Null;
}