$iperfFileName = 'iperf3.exe'
$Defaults = @{
	IPerfSharedFolderPath       = 'C:\Program Files\WindowsPowerShell\Modules\IperfAutomate'
	IperfServerFolderPath       = 'C:\Program Files\WindowsPowerShell\Modules\IperfAutomate\bin'
	EmailNotificationRecipients = 'foo@var.com', 'ghi@whaev.com'
	SmtpServer                  = 'foo.test.local'
	InvokeIPerfPSSessionSuffix  = 'iPerf'
}

$SiteServerMap = @{
	'<YourSiteHere1>' = '<AHostAtThisSite>'
	'<YourSiteHere2>' = '<AHostAtThisSite>'
	
}

Set-StrictMode -Version Latest

function ConvertToUncPath {
	[OutputType([string])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$LocalFilePath,

		[Parameter(Mandatory)]
		[string]$ComputerName
	)

	$RemoteFilePathDrive = ($LocalFilePath | Split-Path -Qualifier).TrimEnd(':')
	"\\$ComputerName\$RemoteFilePathDrive`$$($LocalFilePath | Split-Path -NoQualifier)"
}

function TestServerAvailability {
	[OutputType([pscustomobject])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			foreach ($computer in $ComputerName) {
				$output = @{
					ComputerName = $computer
					Online       = $false
				}
				if (Test-Connection -ComputerName $computer -Quiet -Count 1) {
					$output.Online = $true
				}
				[pscustomobject]$output
			}
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function InvokeIperf {
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Arguments
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$iperfServerFilePath = Join-Path -Path $Defaults.IperfServerFolderPath -ChildPath $iperfFileName

			$mode = ConvertArgsToMode -IPerfArgs $Arguments

			$icmParams = @{
				ComputerName = $ComputerName
				ArgumentList = $iperfServerFilePath, $Arguments
			}

			if ($mode -eq 'Server') {
				## Do not invoke server mode for servers that already have it running
				if ($runningServers = @($ComputerName).where({ TestIPerfServerSession -ComputerName $_ })) {
					Write-Verbose -Message "The server(s) [$(($runningServers -join ','))] are already running."
					[string[]]$ComputerName = @($ComputerName).where({ $_ -notin $runningServers})
				}
				$icmParams.InDisconnectedSession = $true
			}

			Write-Verbose -Message "Invoking iPerf in [$($mode)] mode on computer(s) [$ComputerName] using args [$($Arguments)]..."
			$ComputerName | ForEach-Object {
				if ($mode -eq 'Server') {
					$icmParams.SessionName = "$_ - $mode - $($Defaults.InvokeIPerfPSSessionSuffix)"
				}
				Invoke-Command @icmParams -ScriptBlock {
					$VerbosePreference = 'Continue'
					## Convert to short name so that IEX doesn't puke when using quotes
					$fileShortPath = (New-Object -com scripting.filesystemobject).GetFile($args[0]).ShortPath
					$cliString = "$fileShortPath $($args[1])"
					Invoke-Expression -Command $cliString
				}
			}
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function StartIperfServer {
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			if ($runningServers = @($ComputerName).where({ TestIPerfServerSession -ComputerName $_ })) {
				Write-Verbose -Message "The server(s) [$(($runningServers -join ','))] are already running."
				$ComputerName = @($ComputerName).where({ $_ -notin $runningServers})
			}

			$null = InvokeIperf -ComputerName $ComputerName -Arguments '-s'
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function ConvertArgsToMode {
	[OutputType([string])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$IPerfArgs
	)
	switch ($IPerfArgs) {
		'-s' {
			'Server'
		}
		{$_ -like '*-c*'} {
			'Client'
		}
		default {
			throw "Unrecognized input: [$_]"
		}
	}
}

function StopIPerfServer {
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$icmParams = @{
				ComputerName = $ComputerName
				ScriptBlock  = { Get-Process -Name $args[0] -ErrorAction SilentlyContinue | Stop-Process }
				ArgumentList = [System.IO.Path]::GetFileNameWithoutExtension($iperfFileName)
			}
			Invoke-Command @icmParams
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		} finally {
			$ComputerName | ForEach-Object {
				Get-PSSession -Name "$_ - Server*" -ErrorAction SilentlyContinue | Remove-PSSession
			}
			
		}
	}
}

function TestIPerfServerSession {
	[OutputType([bool])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$cimParams = @{
				ComputerName = $ComputerName
				ClassName    = 'Win32_Process'
				Filter       = "Name = 'iperf3.exe'"
				Property     = 'CommandLine'
			}
			if (($serverProc =  Get-CimInstance @cimParams) -and ($serverProc.CommandLine -match '-s$')) {
				$true
			} else {
				$false
			}
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function New-IperfSchedule {
	<#
		.SYNOPSIS
			This function find the server mapped to FromSite and creates one or more Windows scheduled task on that server to 
			kick off Iperf pointed to all of the sites specified. If more than one site is specified in ToSite, it will
			create that respective number of scheduled tasks.

		.PARAMETER FromSite
			 A mandatory string parameter representing a single Viega site. This can be Reno, Mchpherson, Wichita, Carlisle,
			 McDonough,Nashua or Broomfield. This is the site in which Iperf will be invoked from.

		.PARAMETER ToSite
			 A mandatory string parameter representing a single Viega site. This can be Reno, Mchpherson, Wichita, Carlisle,
			 McDonough,Nashua or Broomfield. This is the site IPerf will reach out to.

		.PARAMETER Daily
			 A optional bool parameter to use if the scheduled task is to be executed every day. By default, this is set
			 to $true.

		.PARAMETER Time
			 A optional datetime parameter representing the time to kick off the scheduled task(s). By default, this is set
			 to 6AM.
	
		.EXAMPLE
			PS> New-IperfSchedule -FromSite Reno -ToSite 'Mchpherson','Carlisle','Nashua'
	
	#>
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ParameterSetName = 'Site')]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Reno', 'Mcpherson', 'Wichita', 'Carlisle', 'McDonough', 'Nashua', 'Broomfield')]
		[string]$FromSite,

		[Parameter(Mandatory, ParameterSetName = 'Site')]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Reno', 'Mcpherson', 'Wichita', 'Carlisle', 'McDonough', 'Nashua', 'Broomfield')]
		[string[]]$ToSite,

		[Parameter(Mandatory, ParameterSetName = 'Server')]
		[ValidateNotNullOrEmpty()]
		[string]$FromServerName,

		[Parameter(Mandatory, ParameterSetName = 'Server')]
		[ValidateNotNullOrEmpty()]
		[string[]]$ToServerName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[bool]$Daily = $true,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[datetime]$Time = '06:00'
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			if ($PSCmdlet.ParameterSetName -eq 'Site') {
				$ToServerName = $ToSite | ForEach-Object { $SiteServerMap.$_ }
				$FromServerName = $SiteServerMap.$FromSite
			}

			$localIperfFilePath = Join-Path -Path $Defaults.IperfServerFolderPath -ChildPath $iperfFileName

			## Ensure the latest copy is on the remote computer
			Install-IperfModule -ComputerName $FromServerName
			
			Invoke-Command -ComputerName $FromServerName -ScriptBlock {
				$trigParams = @{
					At = $args[3]
				}
				if ($args[2]) {
					$trigParams.Daily = $true
				}
				$trigger = New-ScheduledTaskTrigger @trigParams
				$settings = New-ScheduledTaskSettingsSet
				
				$toServers = $args[1]
				$psCommand = "
					try {
						`$results = Start-IPerfMonitorTest -FromServerName $(hostname) -ToServerName $toServers;
						Send-MailMessage -SmtpServer $($Defaults.SmtpServer) -To $($args[4]) -From `"Network Test From $(hostname) to $($args[1] -join ',')`" -Subject 'Network Monitor Test' -Body `$results
					} catch {
						Add-Content -Path `$env:TEMP\IperfMonitor.log -Value `$_.Exception.Message;
						`$Host.SetShouldExit(1)
					} finally {
						Add-Content -Path `$env:TEMP\IperfMonitor.log -Value `$results;
					}
				"
				$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Unrestricted -Command `"$psCommand`""
				$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings
				Register-ScheduledTask "IPerf Network Test - [$($args[1] -join ',')]" -InputObject $task
			} -ArgumentList $localIperfFilePath, $ToServerName, $Daily, $Time, $Defaults.EmailNotificationRecipients
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function Install-IPerfModule {
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			$modulePath = ConvertToUncPath -LocalFilePath 'C:\Program Files\WindowsPowerShell\Modules' -ComputerName $ComputerName
			Write-Verbose -Message "Copying IPerf module to [$($modulePath)]..."
			if ($PSScriptRoot -eq 'iPerfAutomate') {
				$path = $PSScriptRoot
			} else {
				$path = $PSScriptRoot | Split-Path -Parent
			}
			Copy-Item -Path $PSScriptRoot -Destination $modulePath -Recurse -Force
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function NewTestFile {
	[OutputType([System.IO.FileInfo])]
	[CmdletBinding()]
	param
	()
	
	$testFilePath = "$env:temp\testfile.txt"
	$file = [IO.File]::Create($testFilePath)
	$file.SetLength((Invoke-Expression -Command $FileSize))
	$file.Close()
	Get-Item -Path $testFilePath
}

function Start-IPerfMonitorTest {
	<#
		.SYNOPSIS
			This function invokes Iperf from the server at site FromSite to all of the sites specified in ToSite.

		.PARAMETER FromSite
			 A mandatory string parameter representing a single Viega site. This can be Reno, Mchpherson, Wichita, Carlisle,
			 McDonough,Nashua or Broomfield. This is the site that IPerf will be invoked from.
			
		.PARAMETER ToSite
			 A mandatory string parameter representing a single Viega site. This can be Reno, Mchpherson, Wichita, Carlisle,
			 McDonough,Nashua or Broomfield. This is the site(s) that Iperf will connect to.

		.EXAMPLE
			PS> Start-IPerfMonitorTest -FromSite Reno -ToSite 'Wichita','Broomfield'
	
	#>
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory, ParameterSetName = 'Site')]
		[ValidateNotNullOrEmpty()]
		[string]$FromSite,

		[Parameter(Mandatory, ParameterSetName = 'Site')]
		[ValidateNotNullOrEmpty()]
		[string[]]$ToSite,

		[Parameter(Mandatory, ParameterSetName = 'Server')]
		[ValidateNotNullOrEmpty()]
		[string]$FromServerName,

		[Parameter(Mandatory, ParameterSetName = 'Server')]
		[ValidateNotNullOrEmpty()]
		[string[]]$ToServerName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({
				if ($_ -notmatch 'KB$') {
					throw "FileSize must end with 'KB' to indicate kilobytes"
				} else {
					$true
				}
			})]
		[string]$WindowSize = '712KB',

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({
				if ($_ -notmatch 'MB$') {
					throw "FileSize must end with 'MB' to indicate megabytes"
				} else {
					$true
				}
			})]
		[string]$FileSize
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try {
			if ($PSCmdlet.ParameterSetName -eq 'Site') {
				$ToServerName = $ToSite | ForEach-Object { $SiteServerMap.$_ }
				$FromServerName = $SiteServerMap.$FromSite
			}

			## Ensure all servers are available
			if ($notavail = @(TestServerAvailability -ComputerName (@($FromServerName) + $ToServerName)).where({ -not $_.Online })) {
				throw "The server(s) [$(($notavail.ComputerName -join ','))] could not be contacted."
			}

			## Ensure the iPerf module is installed on all servers (if being invoked remotely)
			$serverNames = @($FromServerName) + $ToServerName
			$serverNames.where({ $_ -notlike "$env:COMPUTERNAME*" -and $_ -ne 'localhost' }) | ForEach-Object {
				Install-IperfModule -ComputerName $_
			}

			## Ensure all To Servers have a server instance running
			if ($noservers = @($ToServerName).where({ -not (TestIPerfServerSession -ComputerName $_) })) {
				$noservers | ForEach-Object {
					Write-Verbose -Message "IPerf server not running on [$($_)]. Starting server..."
					StartIperfServer -ComputerName $_
				}
			}

			## Create the test file and copy it to clients, if necessary
			if ($PSBoundParameters.ContainsKey('FileSize')) {
				$testFile = NewTestFile
				$localTestFilePath = 'C:\{0}' -f $testFile.Name
				$copiedTestFiles = [System.Collections.ArrayList]@()
				@($FromServerName).foreach({
						$uncTestFilePath = ConvertToUncPath -LocalFilePath $localTestFilePath -ComputerName $_
						Write-Verbose -Message "Copying test file [$($testFile.FullName)] to $uncTestFilePath..."
						$null = $copiedTestFiles.Add((Copy-Item -Path $testFile.FullName -Destination $uncTestFilePath -PassThru))
					})
				
			}
			
			$ToServerName | ForEach-Object {
				$iPerfArgs = ('-c {0} -w {1}' -f $_, $WindowSize)
				if ($PSBoundParameters.ContainsKey('FileSize')) {
					$iPerfArgs += " -F `"$localTestFilePath`""
				}
				InvokeIperf -ComputerName $FromServerName -Arguments $iPerfArgs
			}
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		} finally {
			StopIperfServer -ComputerName $ToServerName
			if (Get-Variable -Name testFile -ErrorAction Ignore) {
				Write-Verbose -Message "Removing local test file [$($testFile.FullName)]"
				Remove-Item -Path $testFile.FullName -ErrorAction Ignore
			}

			if (Get-Variable -Name copiedTestFiles -ErrorAction Ignore) {
				Write-Verbose -Message "Removing copied test files [$($copiedTestFiles.FullName -join ',')]"
				Remove-Item -Path $copiedTestFiles.FullName -ErrorAction Ignore
			}
		}
	}
}