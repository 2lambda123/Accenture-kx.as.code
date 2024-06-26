#  The .\startLauncher.ps1 script has the following options:
#              -i  [i]gnore warnings and start the launcher anyway, knowing that this may cause issues
#              -d  [d]estroy and rebuild Jenkins environment. All history is also deleted
#              -f  [f]ully destroy and rebuild, including ALL built images and ALL KX.AS.CODE virtual machines!
#              -h  [h]elp me and show this help text
#              -r  [r]ecreate Jenkins jobs with updated parameters. Will keep history
#              -s  [s]top the Jenkins build environment
#              -u  [u]ninstall and give me back my disk space

$scriptParam = ($MyInvocation.Line -replace ('^.*' + [regex]::Escape($MyInvocation.InvocationName)) -split '[;|]')[0].Trim()
$currentDirectory=(Get-Item .).FullName
cd base-vm\build\jenkins
Invoke-Expression ".\launchLocalBuildEnvironment.ps1 $scriptParam"
cd $currentDirectory
