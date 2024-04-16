# to run script, may need to run first
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
# in admin powershell

function InstallOpenJdk21()
{
    # mkdir OpenJdk21 -ErrorAction SilentlyContinue
    
    # Invoke-WebRequest -OutFile $PSScriptRoot/OpenJdk21/OpenJdk21.zip -Uri https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_windows-x64_bin.zip

    # Expand-Archive $PSScriptRoot/OpenJdk21/OpenJdk21.zip -DestinationPath $PSScriptRoot/OpenJdk21
}

function InstallMicrosoftJdk21()
{
    # mkdir MicrosoftJdk21 -ErrorAction SilentlyContinue

    # Invoke-WebRequest -OutFile $PSScriptRoot/MicrosoftJdk21/MicrosoftJdk21.zip -Uri https://aka.ms/download-jdk/microsoft-jdk-21.0.2-windows-x64.zip

    # Expand-Archive $PSScriptRoot/MicrosoftJdk21/MicrosoftJdk21.zip -DestinationPath $PSScriptRoot/MicrosoftJdk21
}

function InstallMaven()
{
    # mkdir Maven -ErrorAction SilentlyContinue

    # Invoke-WebRequest -OutFile $PSScriptRoot/Maven/Maven.zip -Uri https://dlcdn.apache.org/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.zip

    # Expand-Archive $PSScriptRoot/Maven/Maven.zip -DestinationPath $PSScriptRoot/Maven

    $env:PATH="$PSScriptRoot\Maven\apache-maven-3.9.6\bin;$env:PATH"
}

function InstallNode()
{
    # mkdir node -ErrorAction SilentlyContinue
    
    # Invoke-WebRequest -OutFile $PSScriptRoot/Node/Node.zip -Uri https://nodejs.org/dist/v20.12.2/node-v20.12.2-win-x64.zip

    # Expand-Archive $PSScriptRoot/Node/Node.zip -DestinationPath $PSScriptRoot/Node

    $env:PATH="$PSScriptRoot\node_modules\npm\bin;$env:PATH"

    # npm install -g yarn 

}

function CloneGitPluginRepo()
{
    # git clone https://github.com/jenkinsci/jenkins.git GCP
}

function CloneGitPluginPerformanceFork()
{
    # git clone https://github.com/chrisherczeg/oss-performance-git-client-plugin.git GCP_Perf
}

function RunOpenJdkBenmarkMaster()
{
    $env:JAVA_HOME="$PSScriptRoot\OpenJdk21\jdk-21.0.2"

    mvn -v

    pushd .

    cd GCP

    mvn test -Dtest=GitClientTest > $PSScriptRoot\RunOpenJdkBenmarkMaster.log

    popd
}

function RunMicrosoftJdkBenmarkMaster()
{
    $env:JAVA_HOME="$PSScriptRoot\MicrosoftJdk21\jdk-21.0.2+13"

    mvn -v

    pushd .

    cd GCP

    mvn test -Dtest=GitClientTest > $PSScriptRoot\RunMicrosoftJdkBenmarkMaster.log

    popd
}

InstallOpenJdk21
InstallMicrosoftJdk21
InstallMaven
InstallNode
CloneGitPluginRepo
CloneGitPluginPerformanceFork

# git checkout -b benchmark_jdk/$env:USERNAME

RunOpenJdkBenmarkMaster
RunMicrosoftJdkBenmarkMaster




