# This PowerShell script finds all unix symlinks and replace them
# with the Windows symlinks.

# Create file_list.txt and fill it with all files in current repo.
$file_exists = Test-Path -Path file_list.txt -PathType Leaf
if (-Not $file_exists) {
    git ls-files -s > file_list.txt
}
else {
    Clear-Content -Path "file_list.txt"
}

# Find all unix symlinks.
$sym_links = Select-String -Path file_list.txt -AllMatches -Pattern "120000"

# Get the full path of the symlink.
# By default command above (Select-String) will return
# the line which has: 
#   ..\path\to\file:[x]:mode sha stage_number  \t  \path\to\symlink.
# We will split this line by tab ("\t") separator. This function 
# returns the full path to the symlink.   
function GetSymlinkPath {
    param (
        [string[]]$line
    )

    if ($line.Length -eq 0) {
        return ""
    }

    $path = $line.Split("`t")
    
    if ($path.Count -ne 2) {
        Write-Error "Expected 2 items."  
        exit 1
    }    

    return $path[1]
}

# Put to the sym_link_path_array the paths of all symbolic links.
[array]$sym_link_path_array = @()

if ($sym_links.Count -ne 0) {
    foreach ($sym_link in $sym_links) {      
        $path = GetSymlinkPath($sym_link.ToString())
        if ($path.Length -ne 0) {
            $sym_link_path_array += $path 
        }
    }
}

# Transform unix symlinks into the Windows symlinks.
###############################################################################
if ($sym_link_path_array.Count -eq 0) {
    exit 0
}

# On Unix in file's path there is "/". So we should replace it with "\".
function GetWindowsPathToFile {
    param (
        [string[]]$unix_path
    )
    
    if ($unix_path.Length -eq 0) {
        return ""
    }
    else {
        return $unix_path.Replace("/", "\")
    }
}

foreach ($symlink in $sym_link_path_array) {
    # Get unix path to the original file.
    $unix_path_origin_file = Get-Content -Path $symlink
    # Get Windows path to the original file.
    $win_path_origin_file = GetWindowsPathToFile($unix_path_origin_file) 

    #Remove unix symlink.
    if (Test-Path -Path  $symlink -PathType Leaf) {
        Remove-Item -Path $symlink  
    }

    if ($win_path_origin_file.Length -eq 0) {
        continue
    }

    #Create Windows symlink.
    if (Test-Path -Path  $win_path_origin_file -PathType Leaf) {
        cmd /c mklink $symlink $win_path_origin_file
    }
    git update-index --assume-unchanged $symlink
}


