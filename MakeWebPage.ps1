# Converts directory of .url and .website files to a web page
# Ben Manthey 2013

# Looks in favorites directory and puts web page on your desktop
# Can also use command line to override defaults
# For Example MakeWebPage.ps1 -RootDirectory c:\foo -FileName c:\bar\index.html -Recurse True
Param($RootDirectory = [Environment]::GetFolderPath("Favorites"), $FileName = [Environment]::GetFolderPath("Desktop")+"\index.html", $Recurse = $True, $List)

Clear-Host

#####################################################
#     Functions used by other parts of program      #
#####################################################

# Writes String to $Filename
Function WriteFile ($String) {
    Out-File $FileName -InputObject $String -append
}

# Calculates how many subdirectories in a given path
Function DirectoryDepth ($Directory) {
    $Depth = $Directory.Split("\\").Count - 1
    Return $Depth
}

# Generates multiple <ul>'s as necessary to indent subdirectories correctly
# also generates complimentary </ul>'s
Function Indent ($Depth, $Direction) {
    # Root directory specified by user will be indented by one <ul>
    # Next level below that will be indented by two <ul>'s, etc...
    for ($i=0; $i -le $Depth - $RootDepth; $i++) {
        # Chooses weather to generate <ul>'s or </ul>'s
        switch ($Direction) {
            1 {$String += "<ul class=`"a`">"}
            -1 {$String += "</ul>"}
        }
    }
    # Writes generated <ul>'s or </ul>'s to html file
    WriteFile $String
}

# Generates title for links in directory
Function WriteRelativeDirectory ($Directory){
    # delete root directory from full path
    # for example, if root directory is c:\a\
    # and subdirectory being parsed is c:\a\b
    # this will return \b
    if ($Directory -ne $RootDirectory) {
        $DirectoryName = "\"
        $DirectoryName += Split-Path $Directory -Leaf
    }
    # use root directory if in root directory
    else {$DirectoryName = $RootDirectory}
    # Write title to html file
    WriteFile "<summary><b>$DirectoryName</b></summary>"
}

# Converts array of shortcuts into html links and writes them to file
Function ParseShortcuts ($Shortcuts) {
    ForEach ($Shortcut in $Shortcuts) {
        # Title is name of file, minus .url
        $Title = $Shortcut.BaseName
        # Disables wildcards and regex to allow shortcut files with malformed names
        # For example, a filename that starts with a [
        $Shortcut = [Management.Automation.WildcardPattern]::Escape($Shortcut)
        # Find line in file that starts with URL
        $URL = Select-String $Shortcut  -pattern "^URL=" | %{($_.Line).TrimStart("URL=")}
        # Generates html link
        WriteFile "<li><a href=`"$URL`" target=`"_blank`">$Title</a></li>"
        }
}

# Finds all .url files in specified directory
Function ParseDirectory ($Directory) {
    # find how many subdirectory layers we are below specified root directory
    $Depth = DirectoryDepth $Directory
    # Get list of all shortcuts from specified directory
    $Shortcuts = Get-ChildItem -Path "$Directory\*.*" -include *.url, *.website | Sort-Object Name
    if ($Shortcuts -ne $null) {
        # Write <ul>'s to indent links correctly
        Indent $Depth 1
        # Open details tag
        $Details = "<details>"
        ForEach($Item in $List){
            If ($Directory -match "$Item"+"$")
            {$Details = "<details open>"; break}
            }
        WriteFile $Details
        # write title for list of shortcuts
        WriteRelativeDirectory $Directory
        # Call function that generates links in html file
        ParseShortcuts $Shortcuts
        # Close details tag
        WriteFile "</details>"
        # Write </ul>'s to unindent
        Indent $Depth -1
    }    
}

#####################################################
# Begin main program 
#####################################################

# trims trailing \ from specified directory, makes 'depth' counting correct, trailing \ can simply be omitted
$RootDirectory = $RootDirectory.TrimEnd("\\")
# find depth of specified root directory
$RootDepth = DirectoryDepth $RootDirectory
# determines if path is UNC or local
$RootDirectoryType = [System.Uri]$RootDirectory
# escapes root directory 
if($RootDirectoryType.IsUnc) {
    $LongRootDirectory = $RootDirectory.TrimStart("\\")
    $LongRootDirectory = "\\?\UNC\$LongRootDirectory"
    $RootDepth = $RootDepth + 2 }
    else {
    $LongRootDirectory = "\\?\$RootDirectory"
    $RootDepth = $RootDepth + 3 }

# Writes html to setup for list of links, title block, etc.
# Will not be explained in detail, check your html reference
New-Item $Filename -type file -force | out-null
WriteFile "<!DOCTYPE html>"
WriteFile "<html lang=`"en`">"
WriteFile "<head>"
WriteFile "<title>$RootDirectory</title>"
WriteFile "<style type=`"text/css`">"
WriteFile "`thtml * {font-family: sans-serif; color: darkslategray; font-weight: lighter; font-size: 15px;}"
WriteFile "`tul.a {list-style-type:none;}"
WriteFile "`tli {margin: 0; padding: 0;}"
WriteFile "`ta {text-decoration: none; color: slategray;}"
WriteFile "`ta:visited {color: darkslategray;}"
WriteFile "`ta:hover {color: black;}"
WriteFile "</style>"
WriteFile "<meta charset=`"UTF-8`">" 
WriteFile "<meta name=`"viewport`" content=`"width=device-width, initial-scale=1.0`">"
WriteFile "</head>"
WriteFile "<body id=`"top`" style=`"background-color: #F9F4E9;`">"
WriteFile "<a style=`"position:fixed;bottom:5px;right:5px;`" href=`"#top`">Jump to Top</a>"
WriteFile "<p><b>Index of $RootDirectory</b></p>"

# Parse .url files in specified root directory
#if ($Recurse -eq $True) {WriteFile "<a name=`"RootDir`"></a>"}
ParseDirectory $LongRootDirectory

if ($Recurse -eq $True){
# Get list of all subdirectories in specified root directory
$SubDirectories = @(Get-ChildItem -Path  "$LongRootDirectory" -Recurse | where {$_.PsIsContainer -eq $true} | Select FullName | Sort-Object FullName)
# parse any .url files in any subdirectories of specified root directory
if ($SubDirectories -ne $null){
    ForEach($SubDirectory in $SubDirectories){
    ParseDirectory $Subdirectory.FullName
        }
    }
}

# Prints 'half' to console for user information
"HALF"

# Setup up  html header for date sorted listing of .url files
WriteFile "<ul class=`"a`">"
WriteFile "<details>"
WriteFile "<summary><b>Sorted by Date</b></summary>"

# get list of all .url files in specified root directory and any subdirectories, sorts by date created (or modified)
if ($Recurse -eq $True){
$AllFiles = Get-ChildItem -Recurse -Path "$LongRootDirectory" -include *.url, *.website | Sort-Object LastWriteTime -desc}
else {$AllFiles = Get-ChildItem -Path "$LongRootDirectory\*.*" -include *.url, *.website | Sort-Object LastWriteTime -desc}

# Parses all .url files to html
if ($AllFiles -ne $null) { ParseShortcuts $AllFiles }

# counts number of files parsed
if ($AllFiles -ne $null) { $Length = $AllFiles.Length }
    else {$Length = 0}
$Date = Get-Date -format "HH:mm:ss on MM-dd-yyyy"

# Adds statistics and date and closes html file
WriteFile "</details>"
WriteFile "</ul><p><small><i>"
WriteFile "$Length files parsed at $Date"
WriteFile "</i></small></p></body></html>"

# Prints 'complete' to console for user information
"COMPLETE"