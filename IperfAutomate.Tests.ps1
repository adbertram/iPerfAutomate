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
			'PSAvoidInvokingEmptyMembers'
		)
		Invoke-ScriptAnalyzer -Path $PSScriptRoot -ExcludeRule $excludedRules | should benullorempty
	}

}

InModuleScope $ThisModuleName {

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