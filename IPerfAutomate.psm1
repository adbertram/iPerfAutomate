$iperfFileName = 'iperf3.exe'
$Defaults = @{
	IPerfSharedFolderPath = 'C:\Program Files\WindowsPowerShell\Modules\Iperf'
	IperfServerFolderPath = 'C:\Program Files\WindowsPowerShell\Modules\Iperf\bin'
	EmailNotificationRecipients = 'foo@var.com','ghi@whaev.com'
	SmtpServer = 'foo.test.local'
	InvokeIPerfPSSessionSuffix = '- iPerf'
}

$SiteServerMap = @{
	Reno = 'CLIENT1'
	Mcpherson = 'DC'
	Wichita = 'LABSQL'
	Carlisle = 'FOO'
	McDonough = 'FOO'
	Nashua = 'FOO'
	Broomfield = 'FOO'
}

Set-StrictMode -Version Latest

function ConvertToUncPath
{
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

function TestServerAvailability
{
	[OutputType([pscustomobject])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			foreach ($computer in $ComputerName) {
				$output = @{
					ComputerName = $computer
					Online = $false
				}
				if (Test-Connection -ComputerName $computer -Quiet -Count 1) {
					$output.Online = $true
				}
				[pscustomobject]$output
			}
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function TestFolderCompare
{
	[OutputType([bool])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ReferenceFolderPath,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$DifferenceFolderPath
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			Write-Verbose -Message "Comparing folder contents of [$($Defaults.IPerfSharedFolderPath)] and [$($unciPerfFolderPath)]..."
			$refHashes = Get-ChildItem -Path $ReferenceFolderPath -Recurse | Get-FileHash | Select-Object -ExpandProperty Hash
			$diffHashes = Get-ChildItem -Path $DifferenceFolderPath -Recurse | Get-FileHash | Select-Object -ExpandProperty Hash
			
			if (-not ($refHashes + $diffHashes)) { ## Both folders are empty
				$true
			} elseif ((-not $refHashes) -or (-not $diffHashes)) { ## Only one folder is empty
				$false
			} elseif (diff $refHashes $diffHashes) { ## Both folders are not empty and have diffs
				$false
			} else {
				$true
			}
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function InvokeIperf
{
	[OutputType([System.Management.Automation.Runspaces.PSSession])]
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
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
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
					$ComputerName = @($ComputerName).where({ $_ -notin $runningServers})
				}
				$icmParams.InDisconnectedSession = $true
			}

			Write-Verbose -Message "Invoking iPerf in [$($mode)] mode on computer(s) [$ComputerName] using args [$($Arguments)]..."
			$ComputerName | foreach {
				if ($mode -eq 'Server') {
					$icmParams.SessionName = "$_ - $mode - $($Defaults.InvokeIPerfPSSessionSuffix)"
				}
				Invoke-Command @icmParams -ScriptBlock {
					$VerbosePreference = 'Continue'
					## Convert to short name so that IEX doesn't puke when using quotes
					$fileShortPath = (New-Object -com scripting.filesystemobject).GetFile($args[0]).ShortPath
					$cliString = "$fileShortPath $($args[1])"
					Write-Verbose -Message "Invoking CLI [$($cliString)]"
					Invoke-Expression $cliString
				}
			}
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function StartIperfServer
{
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if ($runningServers = @($ComputerName).where({ TestIPerfServerSession -ComputerName $_ })) {
				Write-Verbose -Message "The server(s) [$(($runningServers -join ','))] are already running."
				$ComputerName = @($ComputerName).where({ $_ -notin $runningServers})
			}

			$iperfServerFilePath = Join-Path -Path $Defaults.IperfServerFolderPath -ChildPath $iperfFileName

			$null = InvokeIperf -ComputerName $ComputerName -Arguments '-s'
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function ConvertArgsToMode
{
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

function StopIPerfServer
{
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ComputerName
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$icmParams = @{
				ComputerName = $ComputerName
				ScriptBlock = { Get-Process -Name $args[0] -ErrorAction SilentlyContinue | Stop-Process }
				ArgumentList = [System.IO.Path]::GetFileNameWithoutExtension($iperfFileName)
			}
			Invoke-Command @icmParams
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		} finally {
			$ComputerName | foreach {
				Get-PSSession -Name "$_ - Server*" -ErrorAction SilentlyContinue | Remove-PSSession
			}
			
		}
	}
}

function TestIPerfServerSession
{
	[OutputType([bool])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$cimParams = @{
				ComputerName = $ComputerName
				ClassName = 'Win32_Process'
				Filter = "Name = 'iperf3.exe'"
				Property = 'CommandLine'
			}
			if (($serverProc =  Get-CimInstance @cimParams) -and ($serverProc.CommandLine -match '-s$')) {
				$true
			} else {
				$false
			}
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function New-IperfSchedule
{
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
		[Parameter(Mandatory,ParameterSetName = 'Site')]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Reno','Mcpherson','Wichita','Carlisle','McDonough','Nashua','Broomfield')]
		[string]$FromSite,

		[Parameter(Mandatory,ParameterSetName = 'Site')]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Reno','Mcpherson','Wichita','Carlisle','McDonough','Nashua','Broomfield')]
		[string[]]$ToSite,

		[Parameter(Mandatory,ParameterSetName = 'Server')]
		[ValidateNotNullOrEmpty()]
		[string]$FromServerName,

		[Parameter(Mandatory,ParameterSetName = 'Server')]
		[ValidateNotNullOrEmpty()]
		[string[]]$ToServerName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[bool]$Daily = $true,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[datetime]$Time = '06:00'
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if ($PSCmdlet.ParameterSetName -eq 'Site') {
				$ToServerName = $ToSite | foreach { $SiteServerMap.$_ }
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
			} -ArgumentList $localIperfFilePath,$ToServerName,$Daily,$Time,$Defaults.EmailNotificationRecipients
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function Install-IPerfModule
{
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$modulePath = ConvertToUncPath -LocalFilePath 'C:\Program Files\WindowsPowerShell\Modules' -ComputerName $ComputerName
			Write-Verbose -Message "Copying IPerf module to [$($modulePath)]..."
			Copy-Item -Path $PSScriptRoot -Destination $modulePath -Recurse -Force
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function Start-IPerfMonitorTest
{
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
		[Parameter(Mandatory,ParameterSetName = 'Site')]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Reno','Mcpherson','Wichita','Carlisle','McDonough','Nashua','Broomfield')]
		[string]$FromSite,

		[Parameter(Mandatory,ParameterSetName = 'Site')]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Reno','Mcpherson','Wichita','Carlisle','McDonough','Nashua','Broomfield')]
		[string[]]$ToSite,

		[Parameter(Mandatory,ParameterSetName = 'Server')]
		[ValidateNotNullOrEmpty()]
		[string]$FromServerName,

		[Parameter(Mandatory,ParameterSetName = 'Server')]
		[ValidateNotNullOrEmpty()]
		[string[]]$ToServerName
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			if ($PSCmdlet.ParameterSetName -eq 'Site') {
				$ToServerName = $ToSite | foreach { $SiteServerMap.$_ }
				$FromServerName = $SiteServerMap.$FromSite
			}

			## Ensure all servers are available
			if ($notavail = @(TestServerAvailability -ComputerName (@($FromServerName) + $ToServerName)).where({ -not $_.Online })) {
				throw "The server(s) [$(($notavail.ComputerName -join ','))] could not be contacted."
			}

			## Ensure the iPerf module is installed on all servers (if being invoked remotely)
			(@($FromServerName) + $ToServerName) | where { $_ -notlike "$env:COMPUTERNAME*"} | foreach {
				Install-IperfModule -ComputerName $_
			}

			## Ensure all To Servers have a server instance running
			if ($noservers = @($ToServerName).where({ -not (TestIPerfServerSession -ComputerName $_) })) {
				$noservers | foreach {
					Write-Verbose -Message "IPerf server not running on [$($_)]. Starting server..."
					StartIperfServer -ComputerName $_
				}
			}

			$ToServerName | foreach {
				InvokeIperf -ComputerName $FromServerName -Arguments "-c $_"
			}
		} catch {
			$PSCmdlet.ThrowTerminatingError($_)
		} finally {
			StopIperfServer -ComputerName $ToServerName
		}
	}
}