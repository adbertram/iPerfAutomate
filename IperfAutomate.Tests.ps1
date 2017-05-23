#region import modules
$ThisModule = "$($MyInvocation.MyCommand.Path -replace '\.Tests\.ps1$', '').psd1"
$ThisModuleName = (($ThisModule | Split-Path -Leaf) -replace '\.psd1')
Get-Module -Name $ThisModuleName -All | Remove-Module -Force

Import-Module -Name $ThisModule -Force -ErrorAction Stop
#endregion

InModuleScope $ThisModuleName {

	describe 'TestServerAvailability' {
	
		$commandName = 'TestServerAvailability'
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

	describe 'TestFolderCompare' {
	
		$commandName = 'TestFolderCompare'
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