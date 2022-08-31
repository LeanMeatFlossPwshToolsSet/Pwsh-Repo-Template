param(
    [string]
    $NugetKey,
    [string]
    $GitHubKey
)
$PSVersionTable
$env:PSModulePath+=[IO.Path]::PathSeparator+"$($env:GITHUB_WORKSPACE)/PwshUtils"

git config user.name "CD Process"
git config user.email "CD.Process@users.noreply.github.com"



Write-Host "
The Ps modules path are:
$env:PSModulePath
"
dir env:
Set-PSRepository PSGallery -InstallationPolicy Trusted
git fetch --all --tags
Write-Host "Current Tags:"
git tag
$taggedVersions=@()+(git tag -l "v[0-9.]*" --sort="v:refname")
$taggedVersions|Write-Host

$taggedVersion=$taggedVersions[-1]
if($LASTEXITCODE -ne 0){
    $taggedVersion="v0.0.1"
    Write-Host "Using $taggedVersion as the init version."
}
$taggedVersionArray=$taggedVersion.Split([string[]]@(".","v"),[System.StringSplitOptions]::RemoveEmptyEntries)
$taggedVersionArray[-1]=([int]$taggedVersionArray[-1]+1).ToString()




$submitVersion=$taggedVersionArray -join "."
$GitNewTaggedVersion="v$($submitVersion)"

# increasing the version
$rev=$env:GITHUB_SHA
Write-Host "
Current Commit $rev
New Version need to be tagged $GitNewTaggedVersion
"
$gitRepoName=($gitUrl.replace(".git","") -split "/")[-1]
Write-Host "Current git repo name is $gitUgitRepoNamerl"
$moduleBaseName=$gitRepoName.Replace("-","")
Get-ChildItem -Path "$($env:GITHUB_WORKSPACE)/$moduleBaseName" -Directory |ForEach-Object{
    
    $moduleOnCloud=Find-Module -Name $_.Name -ErrorAction Continue
    # $moduleOnCloud|Write-Host
    if($moduleOnCloud){
        $cloudVersion=$moduleOnCloud.Version.Split([string[]]@(".","v"),[System.StringSplitOptions]::RemoveEmptyEntries)
        for ($i = 0; $i -lt $cloudVersion.Count; $i++) {
            <# Action that will repeat until the condition is met #>
            if($taggedVersionArray[$i] -le $cloudVersion[$i]){
                $taggedVersionArray[$i]=$cloudVersion[$i]
                if($i -eq 2){
                    $taggedVersionArray[$i]=(([int]$cloudVersion[$i])+1).ToString()
                }
            }
            $newSubmitVersion=$taggedVersionArray -join "."
            if(-not $newSubmitVersion.Equals($submitVersion)){
                $submitVersion=$taggedVersionArray -join "."
                $GitNewTaggedVersion="v$($submitVersion)"
                Write-Host "
                Version update
                New Version need to be tagged $GitNewTaggedVersion
                "
            }
            
        }
    }
    Update-ModuleManifest -Path (Join-Path $_.FullName "$($_.Name).psd1") -ModuleVersion $submitVersion
    Test-ModuleManifest -Path (Join-Path $_.FullName "$($_.Name).psd1")
    if($env:GITHUB_REF_NAME -eq "main"){
        # main branch methods
        Publish-Module -Path "$($_.FullName)" -NuGetApiKey $NugetKey -Verbose -Force
        
    }
    else {
        # sub branch methods
        Publish-Module -Path "$($_.FullName)" -NuGetApiKey $NugetKey -WhatIf -Verbose
       
    }
}
if($env:GITHUB_REF_NAME -eq "main"){
    # main branch methods
    "Push tag to Repo"|Write-Host
    git tag -a $GitNewTaggedVersion $rev -m "Continous Delivery Version Submitted"
    git push origin "$GitNewTaggedVersion"
    
}
else{
    "In branch don't push the tag"|Write-Host
}

