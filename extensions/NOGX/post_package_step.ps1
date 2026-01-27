$YYPLATFORM_name = $env:YYPLATFORM_name
$YYtargetFile = $env:YYtargetFile
$YYprojectName = $env:YYprojectName
$YYTARGET_runtime = $env:YYTARGET_runtime

$YYEXTOPT_NOGX_Enable = $env:YYEXTOPT_NOGX_Enable
$YYEXTOPT_NOGX_YaFix = $env:YYEXTOPT_NOGX_YaFix

Write-Host "NOGX extension post_package_step"

if ($YYEXTOPT_NOGX_Enable -ne "True") {
	Write-Host "The extension is disabled."
	exit 0
}

Write-Host "Current platform: $YYPLATFORM_name"

if ($YYPLATFORM_name -ine "Opera GX" -and $YYPLATFORM_name -ine "operagx") {
	Write-Host "Aborting: This script is only for Opera GX platform."
	exit 0
}

$webfilesDir = [System.IO.Path]::Combine($PSScriptRoot, "..", "..", "webfiles")
$webfilesDir = [System.IO.Path]::GetFullPath($webfilesDir)
$defaultIndexFile = [System.IO.Path]::Combine($PSScriptRoot, "index.html")

Write-Host "Project name: $YYprojectName"
Write-Host "Target runtime: $YYTARGET_runtime"
Write-Host "Target file: $YYtargetFile"
Write-Host "Webfiles dir: $webfilesDir"

if (!(Test-Path $YYtargetFile)) {
	Write-Host "Aborting: Target file not found."
	exit 1
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function RemoveFile-Zip {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[System.IO.Compression.ZipArchive]$Zip,
		
		[Parameter(Mandatory)]
		[string]$FileName
	)
	
	Write-Host "Remove '$FileName'"
	$entry = $Zip.GetEntry($FileName)
	if ($entry -ne $null) {
		$entry.Delete()
	}
}

function RenameFile-Zip {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[System.IO.Compression.ZipArchive]$Zip,
		
		[Parameter(Mandatory)]
		[string]$OldName,
		
		[Parameter(Mandatory)]
		[string]$NewName
	)
	
	Write-Host "Rename '$OldName' -> '$NewName'"
	$entry = $Zip.GetEntry($OldName)
	if ($entry -ne $null) {
		$stream = $entry.Open()
		$memoryStream = New-Object System.IO.MemoryStream
		$stream.CopyTo($memoryStream)
		$stream.Close()
		$memoryStream.Position = 0
		
		$newEntry = $zip.CreateEntry($NewName)
		$newStream = $newEntry.Open()
		$memoryStream.CopyTo($newStream)
		$newStream.Close()
		$memoryStream.Dispose()
		
		$entry.Delete()
	}
}

Write-Host "Repacking target file..."
$zip = [System.IO.Compression.ZipFile]::Open($YYtargetFile, 'Update')

# delete extra files
RemoveFile-Zip -Zip $zip -FileName "index.html"

if ($YYTARGET_runtime -ieq "YYC") {
	RemoveFile-Zip -Zip $zip -FileName "runner.html"
	RemoveFile-Zip -Zip $zip -FileName "runner.json"
	RemoveFile-Zip -Zip $zip -FileName "run.xml"
	RemoveFile-Zip -Zip $zip -FileName "runner-sw.js"
	RemoveFile-Zip -Zip $zip -FileName "$YYprojectName.html"
	RenameFile-Zip -Zip $zip -OldName "$YYprojectName.js" -NewName "runner.js"
}
elseif ($YYTARGET_runtime -ieq "VM") {
	RemoveFile-Zip -Zip $zip -FileName "runner.json"
}
else {
	Write-Error "Unknown runtime target '$YYTARGET_runtime'."
	exit 1
}

# fix "Ya" conflict
if ($YYEXTOPT_NOGX_YaFix -eq "True") {
	Write-Host "Fixing Ya variable conflict."
	$entryPath = "runner.js"
	$entry = $zip.GetEntry($entryPath)
	if ($entry -ne $null) {
		$encoding = [System.Text.Encoding]::UTF8
		
		$stream = $entry.Open()
		$reader = New-Object System.IO.StreamReader($stream, $encoding)
		$content = $reader.ReadToEnd()
		$reader.Dispose()
		$stream.Dispose()
		$entry.Delete()
		
		# 1. Replace "Ya" -> "Yv"
		# 2. Replace WebAssembly.instantiate(d,b)
		# 3. Replace (d=>WebAssembly.instantiateStreaming(d,a).then(b,function(e){l(`wasm streaming compile failed: `);l("falling back to ArrayBuffer instantiation");return Lb(c,a,b)}))
		
		$updatedContent = $content.Replace("Ya", "Yv").Replace(
				"WebAssembly.instantiate(d,b)",
				"{b.a.Ya=b.a.Yv;return WebAssembly.instantiate(d,b);}"
			).Replace(
				'(d=>WebAssembly.instantiateStreaming(d,a).then(b,function(e){l(`wasm streaming compile failed: `);l("falling back to ArrayBuffer instantiation");return Lb(c,a,b)}))',
				'(d=>{a.a.Ya=a.a.Yv;return WebAssembly.instantiateStreaming(d,a).then(b,function(e){l(`wasm streaming compile failed: `);l("falling back to ArrayBuffer instantiation");return Lb(c,a,b)})})'
			).Replace(
				'(d=>WebAssembly.instantiateStreaming(d,a).then(b,function(e){l(`wasm streaming compile failed: `);l("falling back to ArrayBuffer instantiation");return Mb(c,a,b)}))',
				'(d=>{a.a.Ya=a.a.Yv;return WebAssembly.instantiateStreaming(d,a).then(b,function(e){l(`wasm streaming compile failed: `);l("falling back to ArrayBuffer instantiation");return Mb(c,a,b)})})'
			)
		
		$tempFile = [System.IO.Path]::GetTempFileName()
		try {
			[System.IO.File]::WriteAllText($tempFile, $updatedContent, $encoding)
			[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $tempFile, (Split-Path $entryPath -Leaf)) | Out-Null
		}
		catch {
			Write-Error "Repacking failed!"
			exit 1
		}
		finally {
			Remove-Item -Path $tempFile -Force
		}
	}
}

# add files from 'webfiles' folder
if (Test-Path $webfilesDir) {
	Write-Host "Add 'webfiles' folder content."
	Push-Location -Path $webfilesDir
	try {
		$files = Get-ChildItem -Recurse -File
		
		foreach ($file in $files) {
			$relativePath = Resolve-Path -Path $file.FullName -Relative
			$relativePath = $relativePath.Substring(2).Replace('\', '/')
			
			$entry = $zip.GetEntry($relativePath)
			if ($entry -ne $null) { $entry.Delete() }
			
			Write-Host "Add '$relativePath'"
			[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $relativePath) | Out-Null
		}
	}
	catch {
		Write-Error "Repacking failed!"
		exit 1
	}
	finally {
		Pop-Location
	}
} else {
	Write-Host "'webfiles' folder does not exist."
}

# add 'index.html' from extension folder if it was not in 'webfiles' folder
$indexEntry = $zip.GetEntry("index.html")
if ($indexEntry -eq $null) {
	Write-Host "Add 'index.html' from extension folder."
	[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $defaultIndexFile, "index.html") | Out-Null
}

$zip.Dispose()

Write-Host "Repacking complete!"

exit 0

