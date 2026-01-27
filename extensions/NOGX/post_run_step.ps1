$YYPLATFORM_name = $env:YYPLATFORM_name
$YYoutputFolder = $env:YYoutputFolder
$YYprojectName = $env:YYprojectName
$YYTARGET_runtime = $env:YYTARGET_runtime

$YYEXTOPT_NOGX_Enable = $env:YYEXTOPT_NOGX_Enable

Write-Host "NOGX extension post_run_step"

if ($YYEXTOPT_NOGX_Enable -ne "True") {
	Write-Host "The extension is disabled."
	exit 0
}

Write-Host "Current platform: $YYPLATFORM_name"

if ($YYPLATFORM_name -ine "Opera GX" -and $YYPLATFORM_name -ine "operagx") {
	Write-Host "Aborting: This script is only for Opera GX platform."
	exit 0
}

$outputDir = [System.IO.Path]::Combine($YYoutputFolder, "runner")
$webfilesDir = [System.IO.Path]::Combine($PSScriptRoot, "..", "..", "webfiles")
$webfilesDir = [System.IO.Path]::GetFullPath($webfilesDir)
$defaultIndexFile = [System.IO.Path]::Combine($PSScriptRoot, "index.html")

Write-Host "Project name: $YYprojectName"
Write-Host "Target runtime: $YYTARGET_runtime"
Write-Host "Output dir: $outputDir"
Write-Host "Webfiles dir: $webfilesDir"

if (!(Test-Path $outputDir)) {
	Write-Error "Output directory does not exist."
	exit 1
}

if (Test-Path $webfilesDir) {
	Write-Host "Copying 'webfiles' folder content."
	Copy-Item -Path "$webfilesDir\*" -Destination $outputDir -Recurse -Force
} else {
	Write-Host "'webfiles' folder does not exist."
}

$sourceFile = [System.IO.Path]::Combine($webfilesDir, "index.html")
if (!(Test-Path $sourceFile)) {
	Write-Host "File 'index.html' not found. Using the default file 'index.html' from the extension."
	$sourceFile = $defaultIndexFile
}

if ($YYTARGET_runtime -ieq "YYC") {
	$runnerFile = Join-Path $outputDir "$YYprojectName.html"
	Copy-Item -Path $sourceFile -Destination $runnerFile -Force

	$jsFile = Join-Path $outputDir "$YYprojectName.js"
	if (Test-Path $jsFile) {
		Move-Item -Path $jsFile -Destination (Join-Path $outputDir "runner.js") -Force
	}
}
elseif ($YYTARGET_runtime -ieq "VM") {
	$runnerFile = Join-Path $outputDir "runner.html"
	Copy-Item -Path $sourceFile -Destination $runnerFile -Force
}
else {
	Write-Error "Unknown runtime target '$YYTARGET_runtime'."
	exit 1
}

Write-Host "Finished."
exit 0

