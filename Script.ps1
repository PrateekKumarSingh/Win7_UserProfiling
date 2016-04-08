﻿Param(
    [Parameter(Mandatory=$true,Position=0)] $AccountPicturePath
    )

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

[Int32[]]$Elements = 1 #Color desktop
[Int32[]]$RGB_ToInteger = [Drawing.ColorTranslator]::ToWin32([Drawing.Color]::Black) #Required color

Function Edit-RegistryKeys
{
	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
	
	Set-ItemProperty "$key\Advanced" Hidden 1
	Write-Host "3. Show Hidden Files - Done" -Fore Yellow
	Set-ItemProperty "$key\Advanced" HideFileExt 0
	Write-Host "4. Show File Extensions - Done" -Fore Yellow
	Set-ItemProperty "$key\Advanced" TaskbarGlomLevel 1
	Write-Host "5. Set TaskBar items combine when Full - Done" -Fore Yellow
	Set-ItemProperty $key -Name enableautotray -Value 0
	Write-Host "6. Set System tray to Never Hide - Done" -Fore Yellow
	Set-ItemProperty "$key\advanced" -name Start_ShowSetProgramAccessAndDefaults -Value 0
	Write-Host "7. Hide Default programs from Start Menu - Done" -Fore Yellow
		
	Stop-Process -ProcessName explorer

}

Function Disable-SleepAndHibernate
{
	powercfg -change -monitor-timeout-ac 0
	powercfg -change -standby-timeout-ac 0
	powercfg -change -disk-timeout-ac 0
	powercfg -change -hibernate-timeout-ac 0
	Write-Host "8. Set Hibernate\Sleep\MonitorTimout to Never : Done" -Fore Yellow
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
	(gci "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\" -Recurse -exclude *sticky*lnk,*calc*lnk,*snipping*lnk,*visual*lnk,*powershell*ise*lnk).fullname`
	|?{$_ -notlike "*accessor*" -and $_ -notlike "*maintenance*" -and $_ -notlike "*Administrative Tools*"} `
	|Remove-Item -Recurse -Confirm:$false -ErrorAction SilentlyContinue
}

Function Tweak-InternetExplorer
{
	#Sets Homepage on IE
	Set-ItemProperty -Path "HKCU:\Software\Microsoft\Internet Explorer\Main" “Start Page” "http://Google.com"
	#Enables Favourites Bar on IE 
	Set-ItemProperty -Path "HKCU:\Software\Microsoft\Internet Explorer\Minie" LinksBandEnabled -Value 1
}

Function Main
{
	[WinAPIs.UserAccountPicture]::SetUserTile("$env:USERDOMAIN\$env:USERNAME",0,$AccountPicturePath)
	Write-Host "1. Set User Account Picture as $AccountPicturePath : Done" -Fore Yellow
	[Desktop.ChangeBackground]::SetSysColors($Elements.Length, $Elements, $RGB_ToInteger) | Out-Null
	Write-Host "2. Set Desktop Background to solid Black : Done" -Fore Yellow
	Edit-RegistryKeys
	Disable-SleepAndHibernate
	PinUnPin-Application -Action unpinfromtaskbar -FilePath "C:\Program Files (x86)\Windows Media Player\wmplayer.exe"
	Write-Host "9. Unpin Windows Media Player : Done" -Fore Yellow
	#Remove-StartMenuShortcuts
	Write-Host "10. Unpin StartMenu Shortcuts : Done" -Fore Yellow
}

Main


#if(get-ItemProperty -Path "HKCU:\Software\Microsoft\Internet Explorer\Main" -Name StatusBarOther -ErrorAction SilentlyContinue){
#	Set-ItemProperty -Path "HKCU:\Software\Microsoft\Internet Explorer\Main" -Name StatusBarOther -Value 1
#}
#else{
#		New-Item -Path "HKCU:\Software\Microsoft\Internet Explorer\Main" -Name StatusbarOther -Value 1
#}