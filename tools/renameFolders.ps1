Param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$OldCodeFolderName, 
        [Parameter(Position=1, Mandatory=$true)]
        [string]$NewCodeFolderName     
    )

$excludedFoldersRegex = "\\(obj|bin|.git|.hg)\\?"

function Update-FileContent
{
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$StartPath,
        [Parameter(Position=1, Mandatory=$true)]
        [string]$OldValue,
        [Parameter(Position=2, Mandatory=$true)]
        [string]$NewValue,
        [Parameter(Position=3, Mandatory=$true)]
        [string]$FileExtensionsRegex
    )

    $filesToUpdate = Get-ChildItem -File -Path "$StartPath" -Recurse -Force | Where-Object { ( $_.FullName -notmatch $excludedFoldersRegex) -and ($_.Name -match $FileExtensionsRegex) } | Select-String -Pattern $OldValue | Group-Object Path | Select-Object -ExpandProperty Name
    $filesToUpdate | ForEach-Object { 
		$currentContent = (Get-Content $_ ) 
		$newContentValue = $NewValue
		
		# Exception for .yml files - remove dots (.) from file content - item name
		if ($NewValue -like "*.*" -and $_ -like "*.yml" ) { 
			$newContentValue = $NewValue -Replace "\.", ""
		}
		
		$currentContent -ireplace [regex]::Escape($OldValue), $newContentValue | Set-Content $_ -Force 

        Write-Host "Replace done" -ForegroundColor Magenta
	}
}



function buildVS
{
    param
    (
        [parameter(Mandatory=$true)]
        [String] $path,

        [parameter(Mandatory=$false)]
        [bool] $nuget = $true,
        
        [parameter(Mandatory=$false)]
        [bool] $clean = $true
    )
    process
    {
        $msBuildExe = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\msbuild.exe'

        if ($nuget) {
            Write-Host "Restoring NuGet packages" -foregroundcolor green
            nuget restore "$($path)"
        }

        if ($clean) {
            Write-Host "Cleaning $($path)" -foregroundcolor green
            & "$($msBuildExe)" "$($path)" /t:Clean /m
        }

        Write-Host "Building $($path)" -foregroundcolor green
        & "$($msBuildExe)" "$($path)" /t:Build /m
    }
}



function Modify-Folder-Structure{

    Write-Host "Updating folder structure" -ForegroundColor Magenta

    $startPath = Split-Path $PSScriptRoot -Parent
    $sourceFolder = $startPath+"\src"

    $includedFolders = "\\(Feature|Foundation|Project|Website)\\?"
    $InternalFoldersToModify = "\\($($OldCodeFolderName))\\?"

    $childFolders = Get-ChildItem -Directory $sourceFolder | Where-Object {$_.FullName -match $includedFolders} 

    $childFolders | ForEach-Object {
        $currentFolder = (Get-Item  $_.FullName )

        Write-Host $currentFolder
        
        $intDirSecLvl = Get-ChildItem -Directory $currentFolder 

        $intDirSecLvl | ForEach-Object{
            $currentFolderSecLvl = (Get-Item  $_.FullName )
        
            Write-Host $currentFolderSecLvl

            $intDirThirdLvl = Get-ChildItem -Directory $currentFolderSecLvl | Where-Object {$_.FullName -match $InternalFoldersToModify}

            $intDirThirdLvl | ForEach-Object {

                $currentFolderThirdLvl = (Get-Item  $_.FullName )
                Write-Host $currentFolderThirdLvl

                Write-Host "Folder name before rename: $($OldCodeFolderName)"  -ForegroundColor Yellow
        
                $currentFolderThirdLvl | Rename-Item -NewName{
                
                    $newItemName = $NewCodeFolderName

                    $_.Name -replace $OldCodeFolderName, $newItemName


                } -Force

                
                
                Write-Host "Folder name after rename: $($NewCodeFolderName)"    -ForegroundColor Green

            }

        }
        
    }


}

try{

    $startPath = Split-Path $PSScriptRoot -Parent

    

    $fileExtensionsToUpdateContentRegex = "(.sln)$"

    $oldNamespacePrefix = $OldCodeFolderName
    $newNamespacePrefix = $NewCodeFolderName
    #$solutionPath = $startPath+"\"+$SolutionName+".sln"


    Write-Host "Update folder structure" -ForegroundColor Magenta

    Modify-Folder-Structure

    Write-Host "Update Solution File" -ForegroundColor Magenta

    Update-FileContent -StartPath "$startPath" -OldValue $oldNamespacePrefix -NewValue $newNamespacePrefix -FileExtensionsRegex $fileExtensionsToUpdateContentRegex

    #Write-Host $solutionPath

    #buildVS -path $solutionPath -nuget $true -clean $true

    Write-Host "Done" -ForegroundColor Green

    
}
catch{

    Write-Host "Modifying folders failed" -ForegroundColor Red
    Write-Host $($_.Exception.Message) -ForegroundColor Red
    Break

}