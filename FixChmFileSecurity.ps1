Param(
	[switch]$NoElevate
)

$parentKeyPath = "HKLM:\SOFTWARE\Microsoft\HTMLHelp\1.x";
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
	
	"" | Write-Host;
    "You are not currently running this under Administrative privileges!" | Write-Warning;
	"This system may requires elevated privileges to edit registry values." | Write-Host;
	
	if ($NoElevate) { return $false; }
	
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]@(
		(New-Object System.Management.Automation.Host.ChoiceDescription("&Run as Admin", "Elevate your login to Administrative privileges")),
		(New-Object System.Management.Automation.Host.ChoiceDescription("Use &Alternate Credentials", "Supply alternate credentials which may have administrative privileges")),
		(New-Object System.Management.Automation.Host.ChoiceDescription("&Continue with current Credentials", "Attempt to execute script with your current permissions")),
		(New-Object System.Management.Automation.Host.ChoiceDescription("&Quit", "Exit and do nothing"))
	);
    $userchoice = $host.ui.PromptforChoice("Warning","Please select to use Alternate Credentials or current credentials to run command", $choices, 0);
  
    if ($userchoice -eq 2) {
        @("", "Using current credentials") | Write-Host;
		return $false;
    }
	
	if ($userChoice -eq 3) {
		@("", "Aborting") | Write-Warning;
		return $true;
	}
	
	$tempBase = [Environment]::GetEnvironmentVariable("Temp","Machine") | Join-Path -ChildPath ("{0}_tmp" -f ([Guid]::NewGuid()).ToString("N"));
	$tempBatchFile = "{0}.bat" -f $tempBase;
	$tempScript = "{0}.ps1" -f $tempBase;
	$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False);
	$txt = "";
	if ($userChoice -ne 1) { $txt = ' -NoElevate' }
	
	[IO.File]::WriteAllLines($tempBatchFile, @(
		'@echo off',
		('powershell -ExecutionPolicy Bypass -File "{0}"{1}' -f $tempScript, $txt)
		'pause'
	), $Utf8NoBomEncoding);
	try {
		$ScriptPath | Copy-Item -Destination:$tempScript -Force;
		try {
			$proc = $null;
			if ($userChoice -eq 0) {
				$proc = Start-Process "cmd.exe" ('/C "{0}"' -f $tempBatchFile) -Verb:"RunAs" -PassThru;
			} else {
				$proc = Start-Process "cmd.exe" ('/C "{0}"' -f $tempBatchFile) -Credential:(Get-Credential) -PassThru;
			}
			
			$proc.WaitForExit();
		} catch {
			"" | Write-Host;
			("Error starting process: {0}" -f ($_ | Out-String)) | Write-Error;
		} finally {
			Remove-Item $tempScript -Force;
		}
	} catch {
		"" | Write-Host;
		("Error starting process: {0}" -f ($_ | Out-String)) | Write-Error;
	} finally {
		Remove-Item $tempBatchFile -Force;
	}
	
	return $true;
}

Function Invoke-FixChmFileSecurity {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true)]
		[string]$ScriptPath,
		[Parameter(Mandatory = $true)]
		[bool]$NoElevate
	)
	
	if (Test-WasReInvokedAsElevated -ScriptPath:$ScriptPath -NoElevate:$NoElevate) { return }

	if (-not ($parentKeyPath | Test-Path)) {
		"" | Write-Host;
		("Cannot fix CHM file viewing security because {0} was not found." -f $parentKeyPath) | Write-Error;
		if (-not $NoElevate) {
			@('', "Press a enter to continue...") | Write-Host;
			Read-Host | Out-Null;
		}
		return;
	}

	$keyPath = $parentKeyPath | Join-Path -ChildPath:$keyName;
	if ($keyPath | Test-Path) {
		$Script:key = $keyPath | Get-Item;
	} else {
		@('', ("Creating key {0} in {1}" -f $keyName, $parentKeyPath)) | Write-Host;
		$Script:key = New-Item -Path:$keyPath;
	}

	try {
		$value = $Script:key | Get-ItemProperty -Name:$propertyName;
		if ($value.MaxAllowedZone -eq $propertyValue) {
			@('', ("{0} in {1} already set to {2}." -f $propertyName, $keyPath, $propertyValue)) | Write-Host;
		} else {
			if ($value.MaxAllowedZone -eq $null) {
				@('', ("Adding DWord value of {0} to {1}." -f $propertyValue, $keyPath)) | Write-Host;
			} else {
				@('', ("Changing value of {0} in {1} from ""{2}"" to ""{3}""." -f $propertyName, $keyPath, $value.MaxAllowedZone, $propertyValue)) | Write-Host;
			}
			$Script:key | Set-ItemProperty -Name:$propertyName -Value:$propertyValue -ErrorAction:Stop;
			@(
				"",
				"Registry updated."
			) | Write-Host;
		}
		@(
			'',
			'Please note that there is probably still a bug relating to displaying CHM files, if the a name within file''s path contains symbols (such as "C:\Program Files (x86)"',
			'This is due to a bug which Microsoft never fixed.',
			'To successfully view a Compiled Help File, simply copy it to a path that does not contain symbols (such as "C:\Windows\Temp").'
		) | Write-Host;
	} catch {
		if ($error[0].Exception -ne $null -and $error[0].Exception -is [System.Security.SecurityException]) {
			"" | Write-Host;
			("Registry access writing to {0} is not allowed." -f $keyPath) | Write-Error;
		} else {
			"" | Write-Host;
			("Error writing to registry path {0}: {1}" -f $keyPath, $error[0].Message) | Write-Error;
		}
	}

	'' | Write-Host;
	
	if ($NoElevate) { return; }

	"Press a enter to continue..." | Write-Host;
	
	Read-Host | Out-Null;
}

if (-not $NoElevate) {
	@(
		'',
		'This script resolves the following Compiled Help File Display issue:',
		'',
		'Symptom:',
		'When trying to view a help file in CHM format, the index displays, but all pages are blank',
		'',
		'This script fixes this by changing the "zone" from which Microsoft Help is allowed to retreive content.',
		('This setting exists under "{0}\{1}", where the property named "{2}" will be set to a DWORD value of {3}.' -f $parentKeyPath, $keyName, $propertyName, $propertyValue),
		''
	) | Write-Host;

	$choices = [System.Management.Automation.Host.ChoiceDescription[]]@(
		(New-Object System.Management.Automation.Host.ChoiceDescription("&Yes", "Fix Compiled Help File Display issue")),
		(New-Object System.Management.Automation.Host.ChoiceDescription("&No", "Exit and do nothing"))
	);
	$userchoice = $host.ui.PromptforChoice("Proceed?","Would you like this script to proceed?", $choices, 1);
	if ($userchoice -ne 0) { return }
}

try {
	Invoke-FixChmFileSecurity -ScriptPath:($MyInvocation.MyCommand.Path) -NoElevate:$NoElevate;
} catch {
	"" | Write-Host;
	("Unexpected Error: {0}" -f ($_ | Out-String)) | Write-Error;
	@('', "Press a enter to continue...") | Write-Host;
	Read-Host | Out-Null;
}