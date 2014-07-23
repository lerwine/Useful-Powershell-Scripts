Function Get-YesOrNo {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        
        [Parameter(Mandatory = $false)]
        [object]$Default,
        
        [Parameter(Mandatory = $false)]
        [object]$YesValue = $true,
        
        [Parameter(Mandatory = $false)]
        [object]$Novalue = $false
    )
    
    while (1) {
        $rseult = (Read-Host -Prompt:$Prompt).Trim();
        
        if ($result -eq '') {
            if ($PSBoundParameters.ContainsKey("Default")) { return $Default }
        } else {
            if (($result -imatch '^\s*(y(es)?|true|-?0*[1-9]\d*(\.\d+)?)\s*$')) { return $YesValue }
            if (($result -imatch '^\s*(no?|false|-?0*(\.0+)?)\s*$')) { return $Novalue }
            Write-Warning -Message:'Invalid Response';
        }
    }
}

Function Get-CmdletStubCode {
    [CmdletBinding(DefaultParameterSetName = 'Separate')]
    Param(
        [Parameter(Mandatory = $false, ParameterSetName = 'Separate')]
        [ValidateScript({ $v = $_; @(Get-Verb | Where-Object { $_.Verb -ieq $v }).Count -gt 0 })]
        [string]$Verb,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Separate')]
        [ValidatePattern('^\s*[a-zA-Z][\w_]*\s*$')]
        [string]$Noun,
        
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Combined')]
        [ValidateScript({ ($_ -imatch '^\s*(?<verb>[a-z][\w_]*)-[a-z][\w_]*\s*$') -and (@(Get-Verb | Where-Object { $_.Verb -ieq $Matches['verb'] }).Count -gt 0) })]
        [string]$Name = $true
    )
    
    $validatedVerb = '';
    $validatedNoun = '';
    
    if ($PSCmdlet.ParameterSetName -eq 'Combined') {
        ($Name -imatch '^\s*(?<verb>[a-z][\w_]*)-(?<noun>[a-z][\w_]*)\s*$') | Out-Null;
        $validatedVerb = (Get-Verb | Where-Object { $_.Verb -ieq $Matches['verb'] }).Verb;
        $validatedNoun = $Matches['noun'];
    } else {
        $validatedVerb = $Verb.Trim();
        $validatedNoun = $Noun.Trim();
        
        if ($validatedVerb -eq '') {
            $vg = Get-Verb | Group-Object -Property:'Group' -AsHashTable -AsString;
            $prompt = $vg.Keys | ForEach-Object { ('{0}: {1}' -f $_, (($vg[$_] | ForEach-Object { $_.Verb }) -join ', ')) };
            $prompt = (($prompt + 'Enter verb name or blank to exit: ') | Out-String).Trim();
            while (1) {
                $validatedVerb = (Read-Host -Prompt:$prompt).Trim();
                if ($validatedVerb -eq '') { return }
                $validatedVerb = (Get-Verb | Where-Object { $_.Verb -ieq $validatedVerb] }).Verb;
                if ($validatedVerb -ne $null) { break }
                Write-Warning -Message:'Invalid verb name';
            }
        }
    }
    
    while ($validatedNoun -eq '') {
        $validatedNoun = (Read-Host -Prompt:'Enter noun name or blank to exit: ').Trim();
        if ($validatedNoun -eq '') { return }
        if (($validatedNoun -imatch '^\s*(?<noun>[a-z][\w_]*)\s*$')) {
            $validatedNoun = $Matches['noun'];
        } else {
            Write-Warning -Message:'Invalid characters in noun';
            $validatedNoun = '';
        }
    }
    
    $validatedNoun = $validatedNoun.Substring(0, 1).ToUpper() + $validatedNoun.Substring(1);
    
    $StringBuilder = New-Object System.Text.StringBuilder;
    $StringBuilder.AppendLine(('Function {0}-{1} {{' -f $validatedVerb, $validatedNoun)) | Out-Null;
    $StringBuilder.AppendLine("`t[CmdletBinding()]") | Out-Null;
    
    $paramCode = @(
        while (1) {
            $result = @{
                ParamName = '';
                ParamType = '';
                Mandatory = 'false';
                ValueFromPipeline = 'false';
                ValueFromPipelineByName = 'false'
                Position = '';
            };
            
            while ($result.ParamName -eq '') {
                $result.ParamName = (Read-Host -Prompt:'Enter parameter name or blank to continue: ').Trim();
                if ($result.ParamName -eq '') { break }
                if (($result.ParamName -imatch '^\s*(?<n>[a-z][\w_]*)\s*$')) {
                    $result.ParamName = $Matches['n'];
                } else {
                    Write-Warning -Message:'Invalid characters in parameter name';
                    $result.ParamName = '';
                }
            }
            
            if ($result.ParamName -eq '') { break }
            
            while ($result.ParamType -eq '') {
                $result.ParamType = (Read-Host -Prompt:'Enter parameter name or blank to continue: ').Trim();
                if ($result.ParamType -eq '') {
                    $result.ParamType = 'object';
                } else {
                    if (($result.ParamType -imatch '^\s*(?<n>[a-z][\w_]*(\.[a-z][\w_]*)*)\s*$')) {
                        $result.ParamType = $Matches['n'];
                    } else {
                        Write-Warning -Message:'Invalid characters in parameter type';
                        $result.ParamType = '';
                    }
                }
            }
            
            $result.Mandatory = Get-YesOrNo -Prompt:'Mandatory? ' -YesValue:'true' -Novalue:'false' -Default:'false';
            $result.ValueFromPipeline = Get-YesOrNo -Prompt:'Value from pipeline? ' -YesValue:'true' -Novalue:'false' -Default:'false';
            $result.ValueFromPipelineByName = Get-YesOrNo -Prompt:'Value from pipeline by name? ' -YesValue:'true' -Novalue:'false' -Default:'false';
            
            while ($result.Position -eq '') {
                $result.Position = (Read-Host -Prompt:'Enter parameter name or blank for none: ').Trim();
                if ($result.Position -eq '') { break }
                if (($result.Position -imatch '^\s*(?<n>\d+)\s*$')) {
                    $result.Position = $Matches['n'];
                } else {
                    Write-Warning -Message:'Invalid whole number';
                    $result.Position = '';
                }
            }
            
            $result | Write-Output;
        }
    };
    
    $acceptsFromPipeline = $false;
    if ($paramCode.Count -eq 0) {
        $StringBuilder.AppendLine("`tParam()") | Out-Null;
    } else {
        $StringBuilder.AppendLine("`tParam(") | Out-Null;
        for ($i = 0; $i -lt $paramCode.Count; $i++) {
            if ($i -gt 0) { $StringBuilder.AppendLine(',') | Out-Null }
            $StringBuilder.AppendFormat(("`t`t" + '[Parameter(Mandatory = ${0}', $paramCode[$i].Mandatory) | Out-Null;
            if ($paramCode[$i].ValueFromPipeline -ne 'false') {
                $acceptsFromPipeline = $true;
                $StringBuilder.Append(', ValueFromPipeline = $true') | Out-Null;
            }
            if ($paramCode[$i].ValueFromPipelineByName -ne 'false') {
                $acceptsFromPipeline = $true;
                $StringBuilder.Append(', ValueFromPipelineByName = $true') | Out-Null;
            }
            if ($paramCode[$i].Position -ne '') { $StringBuilder.AppendFormat((', Position = {0}', $paramCode[$i].Position) | Out-Null }
            $StringBuilder.AppendLine(")]") | Out-Null;
            $StringBuilder.AppendFormat(("`t`t" + '[{0}]${1}', $paramCode[$i].ParamType, $paramCode[$i].ParamName) | Out-Null;
        }
        $StringBuilder.AppendLine() | Out-Null;
        $StringBuilder.AppendLine("`t)") | Out-Null;
    }
    
    $StringBuilder.AppendLine() | Out-Null;
    $StringBuilder.AppendLine('}') | Out-Null;
    
    $StringBuilder.ToString() | Write-Output;
}
