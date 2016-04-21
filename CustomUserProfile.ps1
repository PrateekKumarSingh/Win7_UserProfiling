###################################################################
# Author		: Prateek Singh
# Email			: Prateeksingh1590@gmail.com
# Description	: Powershell script for Windows user profiling
###################################################################

Param(
    [Parameter(Mandatory=$true,Position=0)] $AccountPicturePath
    )
	
cls;

# Adding drawing Assemblies to generate a BMP image for wallpaper
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
	using System; 
	using System.Runtime.InteropServices; 

	namespace WinAPIs { 
	    public class UserAccountPicture { 
											[DllImport("shell32.dll", EntryPoint = "#262", CharSet = CharSet.Unicode, PreserveSig = false)] 
											public static extern void SetUserTile(string username, int notneeded, string picturefilename); 
										}
	}
'@ -ErrorAction SilentlyContinue

Add-Type -TypeDefinition @'
	using System; 
	using System.Runtime.InteropServices; 

	namespace Desktop { 
	    public class ChangeBackground { 

										[DllImport("user32.dll")]
										[return: MarshalAs(UnmanagedType.Bool)]
										public static extern Boolean SetSysColors(
										    Int32    cElements,
										    Int32[]  lpaElements,
										    UInt32[] lpaRgbValues
										);

		}
		}
'@ -ErrorAction SilentlyContinue

$homepageURL = "http://Google.com"
[Int32[]]$Elements = 1 #Color desktop
[Int32[]]$RGB_ToInteger = [Drawing.ColorTranslator]::ToWin32([Drawing.Color]::Black) #Required color

Function Edit-RegistryKeys
{
	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
	
	Set-ItemProperty "$key\Advanced" Hidden 1
	Write-Host "4. Show Hidden Files - Done" -Fore Yellow
	Set-ItemProperty "$key\Advanced" HideFileExt 0
	Write-Host "5. Show File Extensions - Done" -Fore Yellow
	Set-ItemProperty "$key\Advanced" TaskbarGlomLevel 1
	Write-Host "6. Set TaskBar items combine when Full - Done" -Fore Yellow
	Set-ItemProperty $key -Name enableautotray -Value 0
	Write-Host "7. Set System tray to Never Hide - Done" -Fore Yellow
	Set-ItemProperty "$key\advanced" -name Start_ShowSetProgramAccessAndDefaults -Value 0
	Write-Host "8. Hide Default programs from Start Menu - Done" -Fore Yellow
		
	Stop-Process -ProcessName explorer

}

Function Disable-SleepAndHibernate
{
	powercfg -change -monitor-timeout-ac 0
	powercfg -change -standby-timeout-ac 0
	powercfg -change -disk-timeout-ac 0
	powercfg -change -hibernate-timeout-ac 0
	Write-Host "9. Set Hibernate\Sleep\MonitorTimout to Never : Done" -Fore Yellow
}

Function PinUnPin-Application 
{ 
       [CmdletBinding()] 
       param( 
      [Parameter(Mandatory=$true)][string]$Action,  
      [Parameter(Mandatory=$true)][string]$FilePath 
       ) 
       if(-not (test-path $FilePath)) {  
           throw "FilePath does not exist."   
    } 
    
       function InvokeVerb { 
           param([string]$FilePath,$verb) 
        $verb = $verb.Replace("&","") 
        $path= split-path $FilePath 
        $shell=new-object -com "Shell.Application"  
        $folder=$shell.Namespace($path)    
        $item = $folder.Parsename((split-path $FilePath -leaf)) 
        $itemVerb = $item.Verbs() | ? {$_.Name.Replace("&","") -eq $verb} 
        if($itemVerb -eq $null){ 
            throw "Verb $verb not found."             
        } else { 
            $itemVerb.DoIt() 
        } 
            
       } 
    function GetVerb { 
        param([int]$verbId) 
        try { 
            $t = [type]"CosmosKey.Util.MuiHelper" 
        } catch { 
            $def = [Text.StringBuilder]"" 
            [void]$def.AppendLine('[DllImport("user32.dll")]') 
            [void]$def.AppendLine('public static extern int LoadString(IntPtr h,uint id, System.Text.StringBuilder sb,int maxBuffer);') 
            [void]$def.AppendLine('[DllImport("kernel32.dll")]') 
            [void]$def.AppendLine('public static extern IntPtr LoadLibrary(string s);') 
            add-type -MemberDefinition $def.ToString() -name MuiHelper -namespace CosmosKey.Util             
        } 
        if($global:CosmosKey_Utils_MuiHelper_Shell32 -eq $null){         
            $global:CosmosKey_Utils_MuiHelper_Shell32 = [CosmosKey.Util.MuiHelper]::LoadLibrary("shell32.dll") 
        } 
        $maxVerbLength=255 
        $verbBuilder = new-object Text.StringBuilder "",$maxVerbLength 
        [void][CosmosKey.Util.MuiHelper]::LoadString($CosmosKey_Utils_MuiHelper_Shell32,$verbId,$verbBuilder,$maxVerbLength) 
        return $verbBuilder.ToString() 
    } 
 
    $verbs = @{  
        "PintoStartMenu"=5381 
        "UnpinfromStartMenu"=5382 
        "PintoTaskbar"=5386 
        "UnpinfromTaskbar"=5387 
    } 
        
    if($verbs.$Action -eq $null){ 
           Throw "Action $action not supported`nSupported actions are:`n`tPintoStartMenu`n`tUnpinfromStartMenu`n`tPintoTaskbar`n`tUnpinfromTaskbar" 
    } 
    InvokeVerb -FilePath $FilePath -Verb $(GetVerb -VerbId $verbs.$action) 
} 

Function Remove-StartMenuShortcuts
{
	(gci "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\" -Recurse -exclude *sticky*lnk,*calc*lnk,*snipping*lnk).fullname`
	|?{$_ -notlike "*accessor*" -and $_ -notlike "*maintenance*" -and $_ -notlike "*Administrative Tools*"} `
	|Remove-Item -Recurse -Confirm:$false -ErrorAction SilentlyContinue
}

Function Tweak-InternetExplorer
{
	#Sets Homepage on IE
	Write-Host "11. Set Homepage in Internet Explorer as $HomepageURL : Done" -Fore Yellow
	Set-ItemProperty -Path "HKCU:\Software\Microsoft\Internet Explorer\Main" “Start Page” $HomepageURL
	#Enables Menu, Command, Favourites and the Status Bar on IE 
	Write-Host "12. Enable MenuBar in Internet Explorer : Done" -Fore Yellow
	Set-ItemProperty -Path "HKCU:\Software\Microsoft\Internet Explorer\Minie" alwaysshowmenus -Value 1
	Write-Host "13. Enable FavoriteBar in Internet Explorer : Done" -Fore Yellow
	Set-ItemProperty -Path "HKCU:\Software\Microsoft\Internet Explorer\Minie" LinksBandEnabled -Value 1
	Write-Host "14. Enable StatusBar in Internet Explorer : Done" -Fore Yellow
	Set-ItemProperty -Path "HKCU:\Software\Microsoft\Internet Explorer\Minie" showstatusbar -Value 1
	Write-Host "15. Enable CommandBar in Internet Explorer : Done" -Fore Yellow
	Set-ItemProperty -Path "HKCU:\Software\Microsoft\Internet Explorer\Minie" commandbarenabled -Value 1

	Write-Host "16. Remove unwanted Favorites from Internet Explorer : Done" -Fore Yellow
	gci $([Environment]::GetFolderPath('Favorites','None')) -Recurse | Remove-Item -Recurse -Force
}

Function Main
{
	[WinAPIs.UserAccountPicture]::SetUserTile("$env:USERDOMAIN\$env:USERNAME",0,$AccountPicturePath)
	Write-Host "1. Set User Account Picture as $AccountPicturePath : Done" -Fore Yellow
	Set-ItemProperty "HKCU:\control panel\desktop" -Name wallpaper -Value ""
	[Desktop.ChangeBackground]::SetSysColors($Elements.Length, $Elements, $RGB_ToInteger) | Out-Null
	RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters 1, True;
	Write-Host "2. Set Desktop Background to solid Black : Done" -Fore Yellow
	Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA -Value 0
	Write-Host "3. Set user account control setting to Never Notify : Done" -Fore Yellow
	Edit-RegistryKeys
	Disable-SleepAndHibernate
	PinUnPin-Application -Action unpinfromtaskbar -FilePath "C:\Program Files (x86)\Windows Media Player\wmplayer.exe"
	Write-Host "10. Unpin Windows Media Player : Done" -Fore Yellow
	Tweak-InternetExplorer
	#Remove-StartMenuShortcuts
	Write-Host "17. Unpin StartMenu Shortcuts : Done" -Fore Yellow
	Write-Host "18. Remove Sample Music and Pictures : Done" -Fore Yellow
	Get-ChildItem "C:\Users\Public\Music\Sample Pictures" | Remove-Item -Force -ErrorAction SilentlyContinue
	Get-Childitem "C:\Users\Public\Music\Sample MUsic" | Remove-Item -Force -ErrorAction SilentlyContinue
}

Main
