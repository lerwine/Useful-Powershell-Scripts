[Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null;

try {
    $Script:SettingsPath = Join-Path -Path:(Split-Path -Parent -Path:$MyInvocation.MyCommand.Path) -ChildPath:'GetPuppetModuleCommands.xml';
    if ($Script:SettingsPath | Test-Path -PathType:Leaf) {
        $Script:Settings = $Script:SettingsPath | Import-Clixml;
    } else {
        $Script:Settings = @{
            Module = @{
                UserName = "platinumStorm";
                ModuleName = "my_module_name";
                Version = "0.1.0";
            };
            System = @{
                PuppetPath = "/usr/local/bin/puppet";
                ModulePath = "/etc/puppetlabs/puppet/modules";
                WorkingDir = "~/puppet_dev";
            }
        };
    }       
} catch {
    $Error[0] | Out-String | Write-Host -ForegroundColor:Red;
    return;
}

Function Invoke-WriteAndCopy {
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string[]]$Text
    )
    
    Begin {
        $Result = @();
    }
    
    Process {
        $Result = @($Result) + $_;
    }
    
    End {
        [Windows.Forms.Clipboard]::SetText(($Result | Out-String).Trim());
        (@("", "Copied to clipboard:", "") + $Result) | Write-Host;
    }
}

$Script:DevCmdChoices = [System.Management.Automation.Host.ChoiceDescription[]]@(
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Create Boilerplate Code", "Commands for creating boilerplate module code")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Validate code", "Commands for validating your manifest/init.pp file")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("Build &Module", "Commands for building your module into a package file")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Remove Package", "Commands for removing the package files where were created when the module package was built")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Back", "Go back to main menu"))
);

Function Invoke-DevCmd {
	[CmdletBinding()]
	Param()
    
    $selectedCmd = 0;
    while ($selectedCmd -ne ($Script:DevCmdChoices.Length - 1)) {
        $selectedCmd = $host.ui.PromptforChoice("Select Command","Select Linux command you'd like to generate", $Script:DevCmdChoices, 4);
        switch ($selectedCmd) {
            0 {
                @(
                    ("cd {0}" -f $Script:Settings.System.WorkingDir),
                    ("{0} module generate {1}-{2}" -f $Script:Settings.System.PuppetPath, $Script:Settings.Module.UserName, $Script:Settings.Module.ModuleName)
                ) | Invoke-WriteAndCopy;
            }
            1 {
                @(
                    ("cd {0}/{1}-{2}" -f $Script:Settings.System.WorkingDir, $Script:Settings.Module.UserName, $Script:Settings.Module.ModuleName),
                    ("{0} parser validate manifests/init.pp" -f $Script:Settings.System.PuppetPath)
                ) | Invoke-WriteAndCopy;
            }
            2 {
                @(
                    ("cd {0}" -f $Script:Settings.System.WorkingDir),
                    ("{0} module build {1}-{2}" -f $Script:Settings.System.PuppetPath, $Script:Settings.Module.UserName, $Script:Settings.Module.ModuleName),
                    ("cd {0}-{1}" -f $Script:Settings.Module.UserName, $Script:Settings.Module.ModuleName),
                    'find . ! -type d -exec /bin/chmod 644 {} \;',
                    'find . -type d -exec /bin/chmod 755 {} \;'
                ) | Invoke-WriteAndCopy;
            }
            3 {
                @(
                    ("cd {0}/{1}-{2}" -f $Script:Settings.System.WorkingDir, $Script:Settings.Module.UserName, $Script:Settings.Module.ModuleName),
                    "sudo rm -r pkg"
                ) | Invoke-WriteAndCopy;
            }
        }
    }
}

$Script:InstallCmdChoices = [System.Management.Automation.Host.ChoiceDescription[]]@(
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Install", "Command to install your module from the package file")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Uninstall", "Command to uninstall your module")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&List installed modules", "Command to produce a list of installed modules")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("View Module &Path", "Command to display module paths")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Back", "Go back to main menu"))
);

Function Invoke-InstallCmd {
	[CmdletBinding()]
	Param()
    
    $selectedCmd = 0;
    while ($selectedCmd -ne $Script:InstallCmdChoices.Length - 1) {
        "" | Write-Host;
        $selectedCmd = $host.ui.PromptforChoice("Select Command","Select Linux command you'd like to generate", $Script:InstallCmdChoices, 4);
        switch ($selectedCmd) {
            0 {
                @(
                    ("cd {0}/{1}-{2}" -f $Script:Settings.System.WorkingDir, $Script:Settings.Module.UserName, $Script:Settings.Module.ModuleName),
                    ("sudo {0} module install pkg/{1}-{2}-{3}.tar.gz" -f $Script:Settings.System.PuppetPath, $Script:Settings.Module.UserName, $Script:Settings.Module.ModuleName, $Script:Settings.Module.Version),
                    ("cd {0}/{1}" -f $Script:Settings.System.ModulePath, $Script:Settings.Module.ModuleName),
                    'sudo find . ! -type d -exec chmod 644 {} \;',
                    'sudo find . -type d -exec chmod 755 {} \;'
                ) | Invoke-WriteAndCopy;
            }
            1 {
                ("sudo {0} module uninstall {1}-{2}" -f $Script:Settings.System.PuppetPath, $Script:Settings.Module.UserName, $Script:Settings.Module.ModuleName) | Invoke-WriteAndCopy;
            }
            2 {
                ("sudo {0} module list --tree" -f $Script:Settings.System.WorkingDir) | Invoke-WriteAndCopy;
            }
            3 {
                ("sudo ls -al {0}" -f $Script:Settings.System.ModulePath) | Invoke-WriteAndCopy;
            }
        }
    }
}

$Script:ChangeModuleCmdChoices = [System.Management.Automation.Host.ChoiceDescription[]]@(
    (New-Object System.Management.Automation.Host.ChoiceDescription("&UserName", "Change UserName associated with your module")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&ModuleName", "Change name of module")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Version", "Change moduel version")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Back", "Go back to main menu"))
);

Function Invoke-ChangeModule {
	[CmdletBinding()]
	Param()
    
    $selectedCmd = 0;
    while ($selectedCmd -ne $Script:ChangeModuleCmdChoices.Length - 1) {
        @(
            "",
            "Change Module Parameters",
            "",
            ("        User Name: {0}" -f $Script:Settings.Module.UserName),
            ("      Module Name: {0}" -f $Script:Settings.Module.ModuleName),
            ("          Version: {0}" -f $Script:Settings.Module.Version)
            ("Package File Name: {0}-{1}-{2}.tar.gz" -f $Script:Settings.Module.UserName, $Script:Settings.Module.ModuleName, $Script:Settings.Module.Version),
            ""
        ) | Write-Host;

        $selectedCmd = $host.ui.PromptforChoice("Select Command","Please select parameter you'd like to change", $Script:ChangeModuleCmdChoices, 3);
        switch ($selectedCmd) {
            0 {
                @(
                    "",
                    ("Current user name: {0}" -f $Script:Settings.Module.UserName),
                    ""
                ) | Write-Host;
                $v = (Read-Host -Prompt:"Enter User Name portion of module (enter blank to accept current value)");
                if ($v -ne $null -and $v.Trim().Length -gt 0) { $Script:Settings.Module.UserName = $v }
            }
            1 {
                @(
                    "",
                    ("Current module name: {0}" -f $Script:Settings.Module.ModuleName),
                    ""
                ) | Write-Host;
                $v = (Read-Host -Prompt:"Enter Module Name portion of module (enter blank to accept current value)");
                if ($v -ne $null -and $v.Trim().Length -gt 0) { $Script:Settings.Module.ModuleName = $v }
            }
            2 {
                @(
                    "",
                    ("Current version: {0}" -f $Script:Settings.Module.Version),
                    ""
                ) | Write-Host;
                $v = (Read-Host -Prompt:"Enter Module Version (enter blank to accept current value)");
                if ($v -ne $null -and $v.Trim().Length -gt 0) { $Script:Settings.Module.Version = $v }
            }
        }
        Export-Clixml -Path:$Script:SettingsPath -InputObject:$Script:Settings -Force
    }
}

$Script:ChangeSysParamCmdChoices = [System.Management.Automation.Host.ChoiceDescription[]]@(
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Puppet Path", "Change path to the Puppet executable")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Module Path", "Change path where puppet places your module when it is installed")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Working Dir", "Change your working directory on the Linux server")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Back", "Go back to main menu"))
);

Function Invoke-ChangeSysParam {
	[CmdletBinding()]
	Param()
    
    $selectedCmd = 0;
    while ($selectedCmd -ne $Script:ChangeSysParamCmdChoices.Length - 1) {
        @(
            "",
            "Change Linux System Parameters",
            "",
            ("     Puppet Path: {0}" -f $Script:Settings.System.PuppetPath),
            ("     Module Path: {0}" -f $Script:Settings.System.ModulePath),
            ("Your Working Dir: {0}" -f $Script:Settings.System.WorkingDir),
            ""
        ) | Write-Host;

        $selectedCmd = $host.ui.PromptforChoice("Select Command","Please select the parameter you'd like to change", $Script:ChangeSysParamCmdChoices, 3);
        switch ($selectedCmd) {
            0 {
                @(
                    "",
                    ("Current Puppet path: {0}" -f $Script:Settings.System.PuppetPath),
                    ""
                ) | Write-Host;
                $v = (Read-Host -Prompt:"Enter path to Puppet Executable (enter blank to accept current value)");
                if ($v -ne $null -and $v.Trim().Length -gt 0) { $Script:Settings.System.PuppetPath = $v }
            }
            1 {
                @(
                    "",
                    ("Current Module path: {0}" -f $Script:Settings.System.ModulePath),
                    ""
                ) | Write-Host;
                $v = (Read-Host -Prompt:"Enter path to installed modules (enter blank to accept current value)");
                if ($v -ne $null -and $v.Trim().Length -gt 0) { $Script:Settings.System.ModulePath = $v }
            }
            2 {
                @(
                    "",
                    ("Current Working Directory: {0}" -f $Script:Settings.System.WorkingDir),
                    ""
                ) | Write-Host;
                $v = (Read-Host -Prompt:"Enter path to your working directory on linux server (enter blank to accept current value)");
                if ($v -ne $null -and $v.Trim().Length -gt 0) { $Script:Settings.System.WorkingDir = $v }
            }
        }
        Export-Clixml -Path:$Script:SettingsPath -InputObject:$Script:Settings -Force
    }
}

$selectedCmdGroup = 0;
$cmdGroupChoices = [System.Management.Automation.Host.ChoiceDescription[]]@(
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Development Commands", "Generate bash commands relevant to Puppet script development")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Install/Uninstall Commands", "Generate bash commands relevant to installing and uninstalling your module")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("Change &Module Name", "Change module name and version")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("Change &System Parameters", "Change parametrs which tells this script about your Linux environment")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Quit", "Quit this PowerShell app"))
);

while ($selectedCmdGroup -ne $cmdGroupChoices.Length - 1) {
    @(
        "",
        "Puppet Module Development Command Generator",
        "",
        ("     Puppet Path: {0}" -f $Script:Settings.System.PuppetPath),
        ("     Module Path: {0}" -f $Script:Settings.System.ModulePath),
        ("Your Working Dir: {0}" -f $Script:Settings.System.WorkingDir),
        ("       User Name: {0}" -f $Script:Settings.Module.UserName),
        ("     Module Name: {0}" -f $Script:Settings.Module.ModuleName),
        ("         Version: {0}" -f $Script:Settings.Module.Version)
    ) | Write-Host;
    $selectedCmdGroup = $host.ui.PromptforChoice("Select Command Group","Please select the command type", $cmdGroupChoices, 4);
    switch ($selectedCmdGroup) {
        0 { Invoke-DevCmd }
        1 { Invoke-InstallCmd }
        2 { Invoke-ChangeModule }
        3 { Invoke-ChangeSysParam }
    }
}

