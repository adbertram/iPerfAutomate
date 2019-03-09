$ErrorActionPreference = 'Stop'

try {

	$manifestFilePath = "$env:APPVEYOR_BUILD_FOLDER\iPerfAutomate.psd1"
	$manifestContent = Get-Content -Path $manifestFilePath -Raw

	$functionsToExport = @(
		'New-IperfSchedule',
		'Start-IPerfMonitorTest',
		'Test-IPerfServer'
	)

	## Update the module version based on the build version and limit exported functions
	$replacements = @{
		"ModuleVersion = '.*'"     = "ModuleVersion = '$env:APPVEYOR_BUILD_VERSION'"
		"FunctionsToExport = '\*'" = 'FunctionsToExport = @({0})' -f "'$($functionsToExport -join "','")'"
	}		

	$replacements.GetEnumerator() | foreach {
		$manifestContent = $manifestContent -replace $_.Key, $_.Value
	}

	$manifestContent | Set-Content -Path $manifestFilePath

	Write-Host '=============================================='
	Write-Host 'Manifest to publish'
	Write-Host '=============================================='
	Write-Host (Get-Content -Path $manifestFilePath -Raw)
	Write-Host '=============================================='

} catch {
	Write-Error -Message $_.Exception.Message
	$host.SetShouldExit($LastExitCode)
}