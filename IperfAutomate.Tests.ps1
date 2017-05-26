#region import modules
$ThisModule = "$($MyInvocation.MyCommand.Path -replace '\.Tests\.ps1$', '').psd1"
$ThisModuleName = (($ThisModule | Split-Path -Leaf) -replace '\.psd1')
Get-Module -Name $ThisModuleName -All | Remove-Module -Force

Import-Module -Name $ThisModule -Force -ErrorAction Stop
#endregion

describe 'Module-level tests' {
	
	it 'should validate the module manifest' {
	
		{ Test-ModuleManifest -Path $ThisModule -ErrorAction Stop } | should not throw
	}

	it 'should pass all script analyzer rules' {

		$excludedRules = @(
			'PSUseShouldProcessForStateChangingFunctions',
			'PSUseToExportFieldsInManifest',
			'PSAvoidInvokingEmptyMembers',
			'PSAvoidUsingInvokeExpression'
		)
		Invoke-ScriptAnalyzer -Path $PSScriptRoot -ExcludeRule $excludedRules | should benullorempty
	}

}

InModuleScope $ThisModuleName {

	$Defaults = @{
		IPerfSharedFolderPath = 'C:\Program Files\WindowsPowerShell\Modules\Iperf'
		IperfServerFolderPath = 'C:\Program Files\WindowsPowerShell\Modules\Iperf\bin'
		EmailNotificationRecipients = 'foo@var.com','ghi@whaev.com'
		SmtpServer = 'foo.test.local'
		InvokeIPerfPSSessionSuffix = 'iPerf'
	}

	describe 'ConvertToUncPath' {
	
		$commandName = 'ConvertToUncPath'
		$command = Get-Command -Name $commandName
		
		$parameterSets = @(
			@{
				LocalFilePath = 'C:\Folder\File.txt'
				ComputerName = 'computer'
				ExpectedString = '\\computer\c$\Folder\File.txt'
				TestName = 'File'
			}
			@{
				LocalFilePath = 'C:\Folder'
				ComputerName = 'computer'
				ExpectedString = '\\computer\c$\Folder'
				TestName = 'Folder'
			}
		)
	
		$testCases = @{
			All = $parameterSets
		}

		it 'should returns the expected object count: <TestName>' -TestCases $testCases.All {
			param($LocalFilePath,$ComputerName)
		
			$result = & $commandName @PSBoundParameters
			@($result).Count | should be 1
		}
	
		it 'returns the same object type as defined in OutputType: <TestName>' -TestCases $testCases.All {
			param($LocalFilePath,$ComputerName)
	
			& $commandName @PSBoundParameters | should beoftype $command.OutputType.Name
	
		}

		it 'should return the expected string: <TestName>' -TestCases $testCases.All {
			param($LocalFilePath,$ComputerName,$ExpectedString)
		
			$result = & $commandName -LocalFilePath $LocalFilePath -ComputerName $ComputerName
			$result | should be $ExpectedString
		}
		
	}

	describe 'TestServerAvailability' {
	
		$commandName = 'TestServerAvailability'
		$command = Get-Command -Name $commandName
	
		#region Mocks
			mock 'Test-Connection' {
				$false
			} -ParameterFilter { $ComputerName -eq 'offlinecomputer' }

			mock 'Test-Connection' {
				$true
			} -ParameterFilter { $ComputerName -eq 'onlinecomputer' }
		#endregion
		
		$parameterSets = @(
			@{
				ComputerName = 'offlinecomputer'
				TestName = 'Online computer'
			}
			@{
				ComputerName = 'onlinecomputer'
				TestName = 'Offline computer'
			}
		)
	
		$testCases = @{
			All = $parameterSets
		}
		
		it 'returns the same object type as defined in OutputType: <TestName>' -TestCases $testCases.All {
			param($ComputerName)
	
			& $commandName @PSBoundParameters | should beoftype $command.OutputType.Name
	
		}

		it 'should return the expected object properties: <TestName>' -TestCases $testCases.All {
			param($ComputerName)
		
			$result = & $commandName @PSBoundParameters

			Compare-Object $result.PSObject.Properties.Name @('ComputerName','Online') | should benullorempty
		}

		it 'should return the expected object count: <TestName>' -TestCases $testCases.All {
			param($ComputerName)
		
			$result = & $commandName @PSBoundParameters
			@($result).Count | should be @($ComputerName).Count
		}

	}

	describe 'InvokeIperf' {
	
		$commandName = 'InvokeIperf'
	
		#region Mocks
			mock 'ConvertArgsToMode' {
				'Client'
			}

			mock 'Invoke-Command'

			mock 'TestIPerfServerSession' {
				$true
			} -ParameterFilter { $ComputerName -match 'RUNNING' }

			mock 'TestIPerfServerSession' {
				$false
			} -ParameterFilter { $ComputerName -match 'NOTRUNNING' }
		#endregion
		
		$parameterSets = @(
			@{
				Arguments = '-s'
				ComputerName = 'RUNNINGSRV'
				TestName = 'Server mode'
			}
			@{
				Arguments = '-s'
				ComputerName = 'RUNNINGSRV','RUNNINGSRV2'
				TestName = 'Multiple computers / Both running'
			}
			@{
				Arguments = '-s'
				ComputerName = 'RUNNINGSRV','NOTRUNNINGSRV2'
				TestName = 'Multiple computers / One running'
			}
			@{
				Arguments = '-c COMPUTER'
				ComputerName = 'CLIENT'
				TestName = 'Client mode'
			}
			@{
				ComputerName = 'RUNNINGSRV'
				Arguments = 'dfdfdf'
				TestName = 'Bogus arguments'
			}
			@{
				ComputerName = 'NOTRUNNINGSRV'
				Arguments = '-s'
				TestName = 'Offline computer'
			}
		)
	
		$testCases = @{
			All = $parameterSets
			Servers = $parameterSets.where({$_.ComputerName -match 'SRV'})
			Clients = $parameterSets.where({$_.ComputerName -match 'CLIENT'})
		}
	
		it 'returns nothing: <TestName>' -TestCases $testCases.All {
			param($ComputerName,$Arguments)
	
			& $commandName @PSBoundParameters | should benullorempty
	
		}

		context 'when the mode is Server' {
		
			mock 'ConvertArgsToMode' {
				'Server'
			}

			it 'should not attempt to create a new server: <TestName>' -TestCases $testCases.Servers {
				param($ComputerName,$Arguments)
			
				$null = & $commandName @PSBoundParameters

				$assMParams = @{
					CommandName = 'Invoke-Command'
					Times = @($ComputerName | Where-Object {$_ -match 'NOTRUNNING'}).Count
					Exactly = $true
					Scope = 'It'
				}
				Assert-MockCalled @assMParams
			}

			it 'when a server is not already running, should create the session disconnected: <TestName>' -TestCases $testCases.Servers {
				param($ComputerName,$Arguments)
			
				$null = & $commandName @PSBoundParameters

				$assMParams = @{
					CommandName = 'Invoke-Command'
					Times = @($ComputerName | Where-Object {$_ -match 'NOTRUNNING'}).Count
					Exactly = $true
					Scope = 'It'
					ParameterFilter = { 
						$PSBoundParameters.InDisconnectedSession 
					}
				}
				Assert-MockCalled @assMParams
			}

			it 'when a server is not already running, should create a session with the expected name: <TestName>' -TestCases $testCases.Servers {
				param($ComputerName,$Arguments)

				$notRunningServers = $ComputerName | Where-Object { $_ -match 'NOTRUNNING' }
			
				$null = & $commandName @PSBoundParameters

				foreach ($computer in $notRunningServers) {
					$assMParams = @{
						CommandName = 'Invoke-Command'
						Times = 1
						Exactly = $true
						Scope = 'It'
						ParameterFilter = {
							$PSBoundParameters.SessionName -eq "$computer - Server - $($Defaults.InvokeIPerfPSSessionSuffix)"
						}
							
					}
					Assert-MockCalled @assMParams
				}
			}
		
		}


		
	}

	describe 'StartIperfServer' {
	
		$commandName = 'StartIperfServer'
		$command = Get-Command -Name $commandName
	
		#region Mocks
			
		#endregion
		
		$parameterSets = @(
			@{
				TestName = ''
			}
		)
	
		$testCases = @{
			All = $parameterSets
		}
	
		it 'returns the same object type as defined in OutputType: <TestName>' -Skip -TestCases $testCases.All {
			param()
	
			& $commandName @PSBoundParameters | should beoftype $command.OutputType.Name
	
		}
		
	}

	describe 'ConvertArgsToMode' {
	
		$commandName = 'ConvertArgsToMode'
		$command = Get-Command -Name $commandName
	
		#region Mocks
			
		#endregion
		
		$parameterSets = @(
			@{
				TestName = ''
			}
		)
	
		$testCases = @{
			All = $parameterSets
		}
	
		it 'returns the same object type as defined in OutputType: <TestName>' -Skip -TestCases $testCases.All {
			param()
	
			& $commandName @PSBoundParameters | should beoftype $command.OutputType.Name
	
		}
		
	}

	describe 'StopIPerfServer' {
	
		$commandName = 'StopIPerfServer'
		$command = Get-Command -Name $commandName
	
		#region Mocks
			
		#endregion
		
		$parameterSets = @(
			@{
				TestName = ''
			}
		)
	
		$testCases = @{
			All = $parameterSets
		}
	
		it 'returns the same object type as defined in OutputType: <TestName>' -Skip -TestCases $testCases.All {
			param()
	
			& $commandName @PSBoundParameters | should beoftype $command.OutputType.Name
	
		}
		
	}

	describe 'TestIPerfServerSession' {
	
		$commandName = 'TestIPerfServerSession'
		$command = Get-Command -Name $commandName
	
		#region Mocks
			
		#endregion
		
		$parameterSets = @(
			@{
				TestName = ''
			}
		)
	
		$testCases = @{
			All = $parameterSets
		}
	
		it 'returns the same object type as defined in OutputType: <TestName>' -Skip -TestCases $testCases.All {
			param()
	
			& $commandName @PSBoundParameters | should beoftype $command.OutputType.Name
	
		}
		
	}

	describe 'New-IperfSchedule' {
	
		$commandName = 'New-IperfSchedule'
		$command = Get-Command -Name $commandName
	
		#region Mocks
			
		#endregion
		
		$parameterSets = @(
			@{
				TestName = ''
			}
		)
	
		$testCases = @{
			All = $parameterSets
		}
	
		it 'returns the same object type as defined in OutputType: <TestName>' -Skip -TestCases $testCases.All {
			param()
	
			& $commandName @PSBoundParameters | should beoftype $command.OutputType.Name
	
		}
		
	}

	describe 'Install-IPerfModule' {
	
		$commandName = 'Install-IPerfModule'
		$command = Get-Command -Name $commandName
	
		#region Mocks
			
		#endregion
		
		$parameterSets = @(
			@{
				TestName = ''
			}
		)
	
		$testCases = @{
			All = $parameterSets
		}
	
		it 'returns the same object type as defined in OutputType: <TestName>' -Skip -TestCases $testCases.All {
			param()
	
			& $commandName @PSBoundParameters | should beoftype $command.OutputType.Name
	
		}
		
	}

	describe 'Start-IPerfMonitorTest' {
	
		$commandName = 'Start-IPerfMonitorTest'
		$command = Get-Command -Name $commandName
	
		#region Mocks
			
		#endregion
		
		$parameterSets = @(
			@{
				TestName = ''
			}
		)
	
		$testCases = @{
			All = $parameterSets
		}
	
		it 'returns the same object type as defined in OutputType: <TestName>' -Skip -TestCases $testCases.All {
			param()
	
			& $commandName @PSBoundParameters | should beoftype $command.OutputType.Name
	
		}
		
	}
}