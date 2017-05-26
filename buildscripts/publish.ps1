$ErrorActionPreference = 'Stop'

try {
	## Don't upload the build scripts and appveyor.yml to PowerShell Gallery
	$tempmoduleFolderPath = "$env:Temp\iPerfAutomate"
	$null = mkdir $tempmoduleFolderPath

	## Move all of the files/folders to exclude out of the main folder
	$excludeFromPublish = @(
		'iPerfAutomate\\buildscripts'
		'iPerfAutomate\\appveyor\.yml'
		'iPerfAutomate\\\.git'
		'iPerfAutomate\\README\.md'
	)
	$exclude = $excludeFromPublish -join '|'
	Get-ChildItem -Path $env:APPVEYOR_BUILD_FOLDER -Recurse | where { $_.FullName -match $exclude } | Move-Item -Destination $env:temp

	## Copy only the package contents to the module folder
	Get-ChildItem -Path $env:APPVEYOR_BUILD_FOLDER -Recurse | Copy-Item -Destination $tempmoduleFolderPath

	## Publish module to PowerShell Gallery
	$publishParams = @{
		Path = $tempmoduleFolderPath
		NuGetApiKey = $env:nuget_apikey
	}
	Publish-PMModule @publishParams

} catch {
	Write-Error -Message $_.Exception.Message
	$host.SetShouldExit($LastExitCode)
}