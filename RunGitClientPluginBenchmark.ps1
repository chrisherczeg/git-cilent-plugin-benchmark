# to run script, may need to run first
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
# in admin powershell

# Everything will be installed into this repo directory
# run git clean -xdf to delete everything

function InstallOpenJdk21()
{
    mkdir OpenJdk21 -ErrorAction SilentlyContinue
    
    Invoke-WebRequest -OutFile $PSScriptRoot/OpenJdk21/OpenJdk21.zip -Uri https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_windows-x64_bin.zip

    Expand-Archive $PSScriptRoot/OpenJdk21/OpenJdk21.zip -DestinationPath $PSScriptRoot/OpenJdk21
}

function InstallMicrosoftJdk21()
{
    mkdir MicrosoftJdk21 -ErrorAction SilentlyContinue

    Invoke-WebRequest -OutFile $PSScriptRoot/MicrosoftJdk21/MicrosoftJdk21.zip -Uri https://aka.ms/download-jdk/microsoft-jdk-21.0.2-windows-x64.zip

    Expand-Archive $PSScriptRoot/MicrosoftJdk21/MicrosoftJdk21.zip -DestinationPath $PSScriptRoot/MicrosoftJdk21
}

function InstallMaven()
{
    mkdir Maven -ErrorAction SilentlyContinue

    Invoke-WebRequest -OutFile $PSScriptRoot/Maven/Maven.zip -Uri https://dlcdn.apache.org/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.zip

    Expand-Archive $PSScriptRoot/Maven/Maven.zip -DestinationPath $PSScriptRoot/Maven

    $env:PATH="$PSScriptRoot\Maven\apache-maven-3.9.6\bin;$env:PATH"
}

function InstallNode()
{
    mkdir node -ErrorAction SilentlyContinue
    
    Invoke-WebRequest -OutFile $PSScriptRoot/Node/Node.zip -Uri https://nodejs.org/dist/v20.12.2/node-v20.12.2-win-x64.zip

    Expand-Archive $PSScriptRoot/Node/Node.zip -DestinationPath $PSScriptRoot/Node

    $env:PATH="$PSScriptRoot\node_modules\npm\bin;$env:PATH"

    npm install -g yarn 
}

function CloneGitPluginRepo()
{
    git clone https://github.com/jenkinsci/git-client-plugin.git GCP
}

function CloneGitPluginPerformanceFork()
{
    git clone https://github.com/chrisherczeg/oss-performance-git-client-plugin.git GCP_Perf
}

function RunOpenJdkBenmarkMaster()
{
    $env:JAVA_HOME="$PSScriptRoot\OpenJdk21\jdk-21.0.2"

    mvn -v

    pushd .

    cd GCP

    mvn test -Dtest=$env:TEST_LIST > $PSScriptRoot\RunOpenJdkBenmarkMaster.log

    git clean -xdf

    popd
}

function RunMicrosoftJdkBenmarkMaster()
{
    $env:JAVA_HOME="$PSScriptRoot\MicrosoftJdk21\jdk-21.0.2+13"

    mvn -v

    pushd .

    cd GCP

    mvn test -Dtest=$env:TEST_LIST > $PSScriptRoot\RunMicrosoftJdkBenmarkMaster.log

    git clean -xdf

    popd
}

function RunOpenJdkBenmarkPerf()
{
    $env:JAVA_HOME="$PSScriptRoot\OpenJdk21\jdk-21.0.2"

    mvn -v

    pushd .

    cd GCP_Perf

    git checkout dev/chrisherczeg/small_git_repo_oss_perf

    mvn test -Dtest=$env:TEST_LIST > $PSScriptRoot\RunOpenJdkBenmarkPerf.log

    git clean -xdf

    popd
}

function RunMicrosoftJdkBenmarkPerf()
{
    $env:JAVA_HOME="$PSScriptRoot\MicrosoftJdk21\jdk-21.0.2+13"

    mvn -v

    pushd .

    cd GCP_Perf

    git checkout dev/chrisherczeg/small_git_repo_oss_perf

    mvn test -Dtest=$env:TEST_LIST > $PSScriptRoot\RunMicrosoftJdkBenmarkPerf.log

    git clean -xdf

    popd
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

# Set the mvn test to run for the git client plugin repo
$env:TEST_LIST="GitClientCloneTest,GitClientTest"

# checkout the benchmarks branch, this is where non exclusions benchmark logs will
# be pushed
git checkout benchmarks

# get the disk drive stats
winsat disk -ran -write -drive C > disk_stats.log

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

# checkout branch where exclusion benchmarks will be pushed
git checkout exclusion_benmarks

# get the disk drive stats
winsat disk -ran -write -drive C > disk_stats.log

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