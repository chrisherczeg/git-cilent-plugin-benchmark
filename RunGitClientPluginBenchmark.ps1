# to run script, may need to run first
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
# in admin powershell

# Everything will be installed into this repo directory
# run git clean -xdf to delete everything

function InstallOpenJdk21()
{
    if (-not(Test-Path $PSScriptRoot/OpenJdk21))
    {
        mkdir OpenJdk21 -ErrorAction SilentlyContinue
    
        Invoke-WebRequest -OutFile $PSScriptRoot/OpenJdk21/OpenJdk21.zip -Uri https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_windows-x64_bin.zip

        Expand-Archive $PSScriptRoot/OpenJdk21/OpenJdk21.zip -DestinationPath $PSScriptRoot/OpenJdk21
    }
}

function InstallMicrosoftJdk21()
{
    if (-not(Test-Path $PSScriptRoot/MicrosoftJdk21))
    {
        mkdir MicrosoftJdk21 -ErrorAction SilentlyContinue

        Invoke-WebRequest -OutFile $PSScriptRoot/MicrosoftJdk21/MicrosoftJdk21.zip -Uri https://aka.ms/download-jdk/microsoft-jdk-21.0.2-windows-x64.zip

        Expand-Archive $PSScriptRoot/MicrosoftJdk21/MicrosoftJdk21.zip -DestinationPath $PSScriptRoot/MicrosoftJdk21
    }
}

function InstallMaven()
{
    if (-not(Test-Path $PSScriptRoot/Maven))
    {
        mkdir Maven -ErrorAction SilentlyContinue

        Invoke-WebRequest -OutFile $PSScriptRoot/Maven/Maven.zip -Uri https://dlcdn.apache.org/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.zip

        Expand-Archive $PSScriptRoot/Maven/Maven.zip -DestinationPath $PSScriptRoot/Maven
    }

    $env:PATH="$PSScriptRoot\Maven\apache-maven-3.9.6\bin;$env:PATH"
}

function InstallNode()
{
    if (-not(Test-Path $PSScriptRoot/node))
    {
        mkdir node -ErrorAction SilentlyContinue
    
        Invoke-WebRequest -OutFile $PSScriptRoot/Node/Node.zip -Uri https://nodejs.org/dist/v20.12.2/node-v20.12.2-win-x64.zip

        Expand-Archive $PSScriptRoot/Node/Node.zip -DestinationPath $PSScriptRoot/Node
    }

    $env:PATH="$PSScriptRoot\node_modules\npm\bin;$env:PATH"

    npm install -g yarn 
}

function CloneGitPluginRepo()
{
    if (-not(Test-Path $PSScriptRoot/GCP))
    {
        git clone https://github.com/jenkinsci/git-client-plugin.git GCP
    }
}

function CloneGitPluginPerformanceFork()
{
    if (-not(Test-Path $PSScriptRoot/GCP_Perf))
    {
        git clone https://github.com/chrisherczeg/oss-performance-git-client-plugin.git GCP_Perf
    }
}

function RunOpenJdkBenmarkMaster()
{
    $env:JAVA_HOME="$PSScriptRoot\OpenJdk21\jdk-21.0.2"

    mvn -v

    pushd .

    cd GCP

    git config --global --add safe.directory $(pwd)

    mvn -Dtest="$env:TEST_LIST" test > $PSScriptRoot\RunOpenJdkBenmarkMaster.log

    git clean -xdf

    popd
}

function RunMicrosoftJdkBenmarkMaster()
{
    $env:JAVA_HOME="$PSScriptRoot\MicrosoftJdk21\jdk-21.0.2+13"

    mvn -v

    pushd .

    cd GCP

    git config --global --add safe.directory $(pwd)

    mvn -Dtest="$env:TEST_LIST" test > $PSScriptRoot\RunMicrosoftJdkBenmarkMaster.log

    git clean -xdf

    popd
}

function RunOpenJdkBenmarkPerf()
{
    $env:JAVA_HOME="$PSScriptRoot\OpenJdk21\jdk-21.0.2"

    mvn -v

    pushd .

    cd GCP_Perf

    git config --global --add safe.directory $(pwd)

    git checkout dev/chrisherczeg/small_git_repo_oss_perf

    git pull

    mvn -Dtest="$env:TEST_LIST" test > $PSScriptRoot\RunOpenJdkBenmarkPerf.log

    git clean -xdf

    popd
}

function RunMicrosoftJdkBenmarkPerf()
{
    $env:JAVA_HOME="$PSScriptRoot\MicrosoftJdk21\jdk-21.0.2+13"

    mvn -v

    pushd .

    cd GCP_Perf

    git config --global --add safe.directory $(pwd)

    git checkout dev/chrisherczeg/small_git_repo_oss_perf

    git pull

    mvn -Dtest="$env:TEST_LIST" test > $PSScriptRoot\RunMicrosoftJdkBenmarkPerf.log

    git clean -xdf

    popd
}
$isAdmin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
if (-not $isAdmin) {
    Write-Host "Please run this script as an administrator."
    exit
}

# tidy up before starting
git restore $PSScriptRoot/.

# install the required tools
InstallOpenJdk21
InstallMicrosoftJdk21
InstallMaven
InstallNode
CloneGitPluginRepo
CloneGitPluginPerformanceFork

# remove Exclusion on the git repos
Remove-MpPreference -ExclusionPath "$PSScriptRoot\GCP" -ErrorAction SilentlyContinue
Remove-MpPreference -ExclusionPath "$PSScriptRoot\GCP_Perf" -ErrorAction SilentlyContinue

# set the commit message for the non exclusion benchmarks
$commitMessage = "$env:USERNAME - $(Get-Date)"
$branch = $(Get-Date -Format "yyyyMMddHHmmss")

# Set the mvn test to run for the git client plugin repo
$env:TEST_LIST="GitClientTest,GitAPITest,GitClientCloneTest"

# checkout the benchmarks branch, this is where non exclusions benchmark logs will
# be pushed
git checkout -b non_exclusion/$env:USERNAME/$branch
git push --set-upstream origin non_exclusion/$env:USERNAME/$branch

# get the disk drive stats
winsat disk -ran -write -drive C > $PSScriptRoot\disk_stats.log

# run tests
RunOpenJdkBenmarkMaster
RunMicrosoftJdkBenmarkMaster
RunOpenJdkBenmarkPerf
RunMicrosoftJdkBenmarkPerf

# push benchmark results to git
git add $PSScriptRoot/*.log
git commit -m"$commitMessage"
git push
git restore $PSScriptRoot/.
git checkout main

# checkout branch where exclusion benchmarks will be pushed
git checkout -b exclusion/$env:USERNAME/$branch
git push --set-upstream origin exclusion/$env:USERNAME/$branch

# get the disk drive stats
winsat disk -ran -write -drive C > $PSScriptRoot\disk_stats.log

# add windows defender exclusions
Add-MpPreference -ExclusionPath "$PSScriptRoot\GCP"
Add-MpPreference -ExclusionPath "$PSScriptRoot\GCP_Perf"

# run tests with exclusions on
RunOpenJdkBenmarkMaster
RunMicrosoftJdkBenmarkMaster
RunOpenJdkBenmarkPerf
RunMicrosoftJdkBenmarkPerf

# remove windows defender exclusions
Remove-MpPreference -ExclusionPath "$PSScriptRoot\GCP"
Remove-MpPreference -ExclusionPath "$PSScriptRoot\GCP_Perf"

# push benchmark results to git
git add $PSScriptRoot/*.log
git commit -m"$commitMessage"
git push
git restore $PSScriptRoot/.

# go back to main
git checkout main