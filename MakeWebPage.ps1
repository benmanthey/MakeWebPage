# Converts directory of .url and .website files to a web page
# Ben Manthey
# Version 1.0,  June 2013

# Parse command line
# Looks in favorites directory and puts web page on your desktop
# Can also use command line to override defaults
# For Example MakeWebPage.ps1 -RootDirectory c:\foo -FileName c:\bar\index.html -Recurse True
Param($RootDirectory = [Environment]::GetFolderPath("Favorites"), $FileName = [Environment]::GetFolderPath("Desktop")+"\index.html", $Recurse = $True)

#####################################################
# Sub-Routines
#####################################################

# Writes String to $Filename
Function WriteFile ($String) {
    Out-File $FileName -InputObject $String -append
}

# Calculates how many subdirectories in a given path
Function DirectoryDepth ($Directory) {
    $Depth = $Directory.Split("\\").Count-1
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
        $DirectoryName = $Directory.Replace("$RootDirectory", "")
    }
    # use root directory if in root directory
    else {$DirectoryName = $RootDirectory}
    # Write title to html file
    WriteFile "<b>$DirectoryName</b>"
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
        # write title for list of shortcuts
        WriteRelativeDirectory $Directory
        # Call function that generates links in html file
        ParseShortcuts $Shortcuts
        # Write </ul>'s to unindent
        Indent $Depth -1
    }    
}

#####################################################
# Main program 
#####################################################

# trims trailing \ from specified directory, makes 'depth' counting correct, trailing \ can simply be omitted
$RootDirectory = $RootDirectory.TrimEnd("\\")
# find depth of specified root directory
$RootDepth = DirectoryDepth $RootDirectory

# Writes html to setup for list of links, title block, etc.
# Will not be explained in detail, check your html reference
New-Item $Filename -type file -force | out-null
WriteFile "<!DOCTYPE HTML PUBLIC `"-//W3C//DTD HTML 4.01//EN`" `"http://www.w3.org/TR/html4/strict.dtd`">"
WriteFile "<html lang=`"en-US`"><head>"
WriteFile "<title>$RootDirectory</title>"
WriteFile "<style type=`"text/css`">"
WriteFile "ul.a {list-style-type:none;}"
WriteFile "li {margin: 0; padding: 0;}"
WriteFile "</style>"
WriteFile "</head><body id=`"top`">"
WriteFile "<a style=`"display:scroll;position:fixed;bottom:5px;right:5px;`" href=`"#top`">Jump to Top</a>"
WriteFile "<b>Index of $RootDirectory</b>"
WriteFile "<br><a href=`"#DateSorted`">Jump to Sorted by Date</a>"
WriteFile "<p><hr><p>"

# Parse .url files in specified root directory
ParseDirectory $RootDirectory

if ($Recurse -eq $True){
# Get list of all subdirectories in specified root directory
$SubDirectories = @(Get-ChildItem -Path  "$RootDirectory" -Recurse | where {$_.PsIsContainer -eq $true} | Select FullName | Sort-Object FullName)
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
WriteFile "<hr><p><ul class=`"a`">"
WriteFile "<b><a name=`"DateSorted`">Sorted by Date</a></b>"

# get list of all .url files in specified root directory and any subdirectories, sorts by date created (or modified)
if ($Recurse -eq $True){
$AllFiles = Get-ChildItem -Recurse -Path "$RootDirectory" -include *.url, *.website | Sort-Object LastWriteTime -desc}
else {$AllFiles = Get-ChildItem -Path "$RootDirectory\*.*" -include *.url, *.website | Sort-Object LastWriteTime -desc}

# Parses all .url files to html
if ($AllFiles -ne $null) { ParseShortcuts $AllFiles }

# counts number of files parsed
if ($AllFiles -ne $null) { $Length = $AllFiles.Length }
    else {$Length = 0}
$Date = Get-Date

# Adds statistics and date and closes html file
WriteFile "</ul><hr>"
WriteFile "$Length files parsed at $Date"
WriteFile "</body></html>"

# Prints 'complete' to console for user information
"COMPLETE"
"$Length files parsed"