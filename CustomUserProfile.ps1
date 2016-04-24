###################################################################
# Author		: Prateek Singh
# Email			: Prateeksingh1590@gmail.com
# Description	: Powershell script for Windows user profiling
###################################################################

Param(
    #[Parameter(Mandatory=$true,Position=0)] 
    $AccountPicturePath
    )

Function Set-UserAccountPicture
{
    Add-Type -TypeDefinition @'
    	using System; 
    	using System.Runtime.InteropServices; 
    
    	namespace WinAPIs
        { 
    	    public class UserAccountPicture
            { 
    	        [DllImport("shell32.dll", EntryPoint = "#262", CharSet = CharSet.Unicode, PreserveSig = false)] 
    	        public static extern void SetUserTile(string username, int notneeded, string picturefilename); 
            }
    	}
'@ -ErrorAction SilentlyContinue

    [WinAPIs.UserAccountPicture]::SetUserTile("$env:USERDOMAIN\$env:USERNAME",0,$AccountPicturePath)
    
    $Global:Flag1 = $?
}

Function Set-DesktopBackground
{
    # Adding drawing Assemblies to generate a BMP image for wallpaper
    Add-Type -AssemblyName System.Drawing

    Add-Type -TypeDefinition @'
    	using System; 
    	using System.Runtime.InteropServices; 
    
    	namespace Desktop
        { 
    	        public class ChangeBackground
                { 
    
    		        [DllImport("user32.dll")]
    		        [return: MarshalAs(UnmanagedType.Bool)]
    		        public static extern Boolean SetSysColors(Int32 cElements,Int32[] lpaElements,UInt32[] lpaRgbValues);
    
    		    }
    	}
'@ -ErrorAction SilentlyContinue
    
    [Int32[]]$Elements = 1 #Color desktop
    [Int32[]]$RGB_ToInteger = [Drawing.ColorTranslator]::ToWin32([Drawing.Color]::Black) #Required color
    
    Set-ItemProperty "HKCU:\control panel\desktop" -Name wallpaper -Value ""
    [Desktop.ChangeBackground]::SetSysColors($Elements.Length, $Elements, $RGB_ToInteger) | Out-Null
    $Global:Flag2 = $?
    RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters 1, True;

}

Function Edit-RegistryKeys
{
    #Set user account control settings to NEver notify
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA -Value 0
    $Global:Flag3 = $?

	$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
	
	Set-ItemProperty "$key\Advanced" Hidden 1
    $Global:Flag4 = $?
	Set-ItemProperty "$key\Advanced" HideFileExt 0
	$Global:Flag5 = $?
	Set-ItemProperty "$key\Advanced" TaskbarGlomLevel 1
	$Global:Flag6 = $?
	Set-ItemProperty $key -Name enableautotray -Value 0
	$Global:Flag7 = $?
	Set-ItemProperty "$key\advanced" -name Start_ShowSetProgramAccessAndDefaults -Value 0
	$Global:Flag8 = $?
		
	Stop-Process -ProcessName explorer
}

Function Disable-SleepAndHibernate
{
	#powercfg -change -monitor-timeout-ac 0
	powercfg -change -standby-timeout-ac 0
	powercfg -change -disk-timeout-ac 0
	powercfg -change -hibernate-timeout-ac 0   
    If($?)
    {
        $Global:Flag9 = $True
    }
    Else
    {
        $Global:Flag9 = $True
    }
}

Function UnPin-WinMediaplayer 
{ 
    $FilePath = "C:\Program Files (x86)\Windows Media Player\wmplayer.exe"
    $Action = "UnpinFromTaskbar"
		
		if(-not (test-path $FilePath)){
			throw "FilePath does not exist."   
		} 
    
		Function InvokeVerb
		{ 
			Param([string]$FilePath,$verb) 

			$Verb = $Verb.Replace("&","") 
			$Path = Split-Path $FilePath 
			$Shell = New-object -com "Shell.Application"  
			$Folder = $Shell.Namespace($path)    
			$Item = $Folder.Parsename((split-path $FilePath -leaf)) 

			$ItemVerb = $Item.Verbs() | ? {$_.Name.Replace("&","") -eq $Verb} 

			if($ItemVerb -eq $null)
			{ 
			    $Global:Flag10 = $False
			}
			else
			{ 
			    $itemVerb.DoIt()
                $Global:Flag10 = $True
			} 
            
		} 
		
		Function GetVerb
		{ 

			Param([int]$verbId) 
			Try
			{ 
				$t = [type]"CosmosKey.Util.MuiHelper" 
			} 
			Catch
			{ 
			    $def = [Text.StringBuilder]"" 
			    [void]$def.AppendLine('[DllImport("user32.dll")]') 
			    [void]$def.AppendLine('public static extern int LoadString(IntPtr h,uint id, System.Text.StringBuilder sb,int maxBuffer);') 
			    [void]$def.AppendLine('[DllImport("kernel32.dll")]') 
			    [void]$def.AppendLine('public static extern IntPtr LoadLibrary(string s);') 
			    add-type -MemberDefinition $def.ToString() -name MuiHelper -namespace CosmosKey.Util             
			}
			 
			if($global:CosmosKey_Utils_MuiHelper_Shell32 -eq $null)
			{         
			    $global:CosmosKey_Utils_MuiHelper_Shell32 = [CosmosKey.Util.MuiHelper]::LoadLibrary("shell32.dll") 
			}
			 
			$maxVerbLength=255 
			$verbBuilder = new-object Text.StringBuilder "",$maxVerbLength 
			[void][CosmosKey.Util.MuiHelper]::LoadString($CosmosKey_Utils_MuiHelper_Shell32,$verbId,$verbBuilder,$maxVerbLength) 
			
			Return $verbBuilder.ToString() 
		} 
 
		$verbs = @{  
					"PintoStartMenu"=5381 
					"UnpinfromStartMenu"=5382 
					"PintoTaskbar"=5386 
					"UnpinfromTaskbar"=5387 
		} 
        
		if($verbs.$Action -eq $null)
		{ 
			Throw "Action $action not supported`nSupported actions are:`n`tPintoStartMenu`n`tUnpinfromStartMenu`n`tPintoTaskbar`n`tUnpinfromTaskbar" 
		} 
		
		InvokeVerb -FilePath $FilePath -Verb $(GetVerb -VerbId $verbs.$action) 
}

Function UnPin-StartMenuShortcuts
{
    $Shortcuts = (gci "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\" -Recurse -exclude *sticky*lnk,*calc*lnk,*snipping*lnk,*desktop*).fullname`
    |?{$_ -notlike "*accessor*" -and $_ -notlike "*maintenance*" -and $_ -notlike "*Administrative Tools*"}

    $Shortcuts | Remove-Item -Recurse -Confirm:$false -ErrorAction SilentlyContinue
    $?
}

Function Set-IEConfigurations
{
    #IE registry and path variables
	$IEHomepageURL = "https://www.Google.com/"
	$IEHomepageRegistryPath = "HKCU:\Software\Microsoft\Internet Explorer\Main"
	$IEBarRegistryPath = "HKCU:\Software\Microsoft\Internet Explorer\Minie"
	$IEFavoritesFolderPath = $([Environment]::GetFolderPath('Favorites','None'))
    
    #Sets Homepage on IE
	Set-ItemProperty -Path $IEHomepageRegistrypath “Start Page” $IEHomepageURL
	
    If( (Get-ItemProperty $IEHomepageRegistryPath -Name "start page").'start page' -eq $IEHomepageURL)
	{
		$Global:Flag11 = $True
	}
	Else
	{
		$Global:Flag11 = $False
	}

	#Enables Menu, Command, Favourites and the Status Bar on IE 
	Set-ItemProperty -Path $IEBarRegistryPath alwaysshowmenus -Value 1
	Set-ItemProperty -Path $IEBarRegistryPath LinksBandEnabled -Value 1
	Set-ItemProperty -Path $IEBarRegistryPath showstatusbar -Value 1
	Set-ItemProperty -Path $IEBarRegistryPath commandbarenabled -Value 1

	# Checks current value of registry post enabling IE Bars and favourites
	$BarSettings = Get-ItemProperty $IEBarRegistryPath

	If($BarSettings.AlwaysShowMenus){$Global:Flag12 = $True}Else{$Global:Flag12 = $False}
	If($BarSettings.LinksBandEnabled){$Global:Flag13 = $True}Else{$Global:Flag13 = $False}
	If($BarSettings.ShowStatusBar){$Global:Flag14 = $True}Else{$Global:Flag14 = $False}
	If($BarSettings.CommandBarEnabled){$Global:Flag15 = $True}Else{$Global:Flag15 = $False}

	Get-ChildItem $IEFavoritesFolderPath -Recurse | Remove-Item -Recurse -Force

	If(Get-ChildItem $IEFavoritesFolderPath -Recurse | ?{$_.extension -eq '.url'})
	{
		$Global:Flag16 = $False
	}
	else
	{
		$Global:Flag16 = $True
	}

	
}

Function Remove-SampleFiles
{
    $SamplePicturePath = "C:\Users\Public\Pictures\Sample Pictures"
    $SampleMusicPath = "C:\Users\Public\Music\Sample MUsic"
    Get-ChildItem $SamplePicturePath | Remove-Item -Force -ErrorAction SilentlyContinue
    $Picture = $?
	Get-Childitem $SampleMusicPath | Remove-Item -Force -ErrorAction SilentlyContinue
    $Music = $?

    If($Music -and $Picture)
    {
        $Global:Flag18 = $true
    }
    Else
    {
        $Global:Flag18 = $False    
    }
}

Function Show-TaskResults
{
    ''|Select @{n='Task';e={"1. Set User Account Picture as $AccountPicturePath"}}, @{n='Status';e={$Global:Flag1}}
    ''|Select @{n='Task';e={"2. Set Desktop Background to solid Black"}}, @{n='Status';e={$Global:Flag2}}
    ''|Select @{n='Task';e={"3. Set user account control setting to Never Notify"}}, @{n='Status';e={$Global:Flag3}}
    ''|Select @{n='Task';e={"4. Show Hidden Files"}}, @{n='Status';e={$Global:Flag4}}
    ''|Select @{n='Task';e={"5. Show File Extensions"}}, @{n='Status';e={$Global:Flag5}}
    ''|Select @{n='Task';e={"6. Set TaskBar items combine when Full"}}, @{n='Status';e={$Global:Flag6}}
    ''|Select @{n='Task';e={"7. Set System tray to Never Hide"}}, @{n='Status';e={$Global:Flag7}}
    ''|Select @{n='Task';e={"8. Hide Default programs from Start Menu"}}, @{n='Status';e={$Global:Flag8}}
    ''|Select @{n='Task';e={"9. Set Hibernate\Sleep to Never"}}, @{n='Status';e={$Global:Flag9}}
    ''|Select @{n='Task';e={"10. Unpin Windows MediaPlayer from TaskBar"}}, @{n='Status';e={$Global:Flag10}}
    ''|Select @{n='Task';e={"11. Set Homepage in Internet Explorer as"}}, @{n='Status';e={$Global:Flag11}}
    ''|Select @{n='Task';e={"12. Enable MenuBar in Internet Explorer"}}, @{n='Status';e={$Global:Flag12}}
    ''|Select @{n='Task';e={"13. Enable FavoriteBar in Internet Explorer"}}, @{n='Status';e={$Global:Flag13}}
    ''|Select @{n='Task';e={"14. Enable StatusBar in Internet Explorer"}}, @{n='Status';e={$Global:Flag14}}
    ''|Select @{n='Task';e={"15. Enable CommandBar in Internet Explorer"}}, @{n='Status';e={$Global:Flag15}}
    ''|Select @{n='Task';e={"16. Remove unwanted Favorites from IE"}}, @{n='Status';e={$Global:Flag16}}
    ''|Select @{n='Task';e={"17. Unpin StartMenu Shortcuts"}}, @{n='Status';e={$Global:Flag17}}
    ''|Select @{n='Task';e={"18. Remove Sample Music and Pictures"}}, @{n='Status';e={$Global:Flag18}}
}

Function Main
{
#Start Tasks

    Set-UserAccountPicture
    Set-DesktopBackground
    Edit-RegistryKeys
    Disable-SleepAndHibernate
    UnPin-WinMediaplayer
    Set-IEConfigurations
    UnPin-StartMenuShortcuts
    Remove-SampleFiles

#End Tasks

    Show-TaskResults
}

Main
