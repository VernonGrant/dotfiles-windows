# Wsl

function Sync-WSL-SSH-Keys
{
    wsl -e bash -c "cp -r /mnt/c/Users/$env:UserName/.ssh ~/.ssh"
    wsl -e bash -c "chmod 600 ~/.ssh/id_rsa"
}

# News Clipping Helpers

function Edit-Cleanup-Clipping-Links
{
    Param(
        [Parameter(Mandatory)]
        [String]$SourceFile
    )

    # Remove all lines that dont contain http.
    (Get-Content $SourceFile) | Where-Object { $_ -match "http" } | Set-Content $SourceFile

    # Sort lines and remove duplicates.
    (Get-Content $SourceFile) | Sort-Object | Get-Unique | Set-Content $SourceFile

    # Remove lines that don't start with a link.
    (Get-Content $SourceFile) | Where-Object { $_ -match "^https?" } | Set-Content $SourceFile
}

# Project Helpers

$ProjectsDirectory = $HOME + "\Devenv\projects\"

function Clear-Projects-Generated-Files
{
    # Get all source folders.
    $SourceFolders = Get-ChildItem $ProjectsDirectory -Depth 2 -Attributes Directory -Filter "source"

    # Perform these operations for each folder.
    foreach ($Folder in $SourceFolders)
    {
        # Delete node_modules folders.
        Get-Childitem $Folder.Fullname -Depth 2 -Attributes Directory -Filter "node_modules" |
                Remove-Item -Force -Recurse

        # Delete vendor folders.
        Get-Childitem $Folder.Fullname -Depth 2 -Attributes Directory -Filter "vendor" |
                Remove-Item -Force -Recurse
    }
}

# Remote Server Helpers

function Get-Remote-Database
{
    Param(
        [Parameter(Mandatory)]
        [String]$RemoteHost,
        [Parameter(Mandatory)]
        [String]$DatabaseUser,
        [Parameter(Mandatory)]
        [String]$DatabaseUserPass,
        [Parameter(Mandatory)]
        [String]$DatabaseName,
        [Parameter(Mandatory)]
        [String]$Destination
    )

    # dump database on server.
    ssh $RemoteHost "mkdir -p ~/temp && mysqldump --user=`"$DatabaseUser`" --password=`"$DatabaseUserPass`" $DatabaseName > ~/temp/$DatabaseName.sql && ls -la ~/temp/"

    # rsync it down.
    wsl -e bash -c "rsync -auv $RemoteHost`:~/temp/$DatabaseName.sql $Destination"
}

function Get-Remote-Files
{
    Param(
        [Parameter(Mandatory)]
        [String]$RemoteHost,
        [Parameter(Mandatory)]
        [String]$Source,
        [Parameter(Mandatory)]
        [String]$Destination
    )

    wsl -e bash -c "rsync -auv $RemoteHost`:$Source $Destination"
}

# Docker Compose Helpers

function Import-Docker-Database
{
    Param(
        [Parameter(Mandatory)]
        [String]$File,
        [Parameter(Mandatory)]
        [String]$Container,
        [Parameter(Mandatory)]
        [String]$DatabaseUser,
        [Parameter(Mandatory)]
        [String]$DatabaseUserPass,
        [Parameter(Mandatory)]
        [String]$DatabaseName
    )

    # upload database to local running container.
    wsl -e bash -c "cat $File | docker exec -i $Container /usr/bin/mysql --user=`"$DatabaseUser`" --password=`"$DatabaseUserPass`" $DatabaseName"
    # TODO: Find out why there's an encoding issue here.
    # Get-Content -Encoding UTF8 $DBFile | docker exec -i $Container /usr/bin/mysql --user="$DBUser" --password="$DBUserPass" $DBName
}

function Install-Docker-Development-Plugins
{
    Param(
        [Parameter(Mandatory)]
        [String]$Container
    )

    # TODO: perform check, to see if the WordPress CLI is already installed.
    Install-Docker-WordPress-CLI $Container

    # TODO: Reimplement this in the PowerShell way.
    docker exec -i $Container sh -c "cd /var/www/html && wp plugin install disable-emails --activate --allow-root"
    docker exec -i $Container sh -c "cd /var/www/html && wp plugin install query-monitor --activate --allow-root"
}

function Uninstall-Docker-Plugins
{
    Param(
        [Parameter(Mandatory)]
        [String]$Container
    )

    # TODO: perform check, to see if the WordPress CLI is already installed.
    Install-Docker-WordPress-CLI $Container

    # TODO: Reimplement this in the PowerShell way.
    docker exec -i $Container sh -c "cd /var/www/html && wp plugin deactivate autoptimize --allow-root"
    docker exec -i $Container sh -c "cd /var/www/html && wp plugin deactivate wordfence --allow-root"
    docker exec -i $Container sh -c "cd /var/www/html && wp plugin deactivate autoptimize --allow-root"
    docker exec -i $Container sh -c "cd /var/www/html && wp plugin deactivate easy-wp-smtp --allow-root"
    docker exec -i $Container sh -c "cd /var/www/html && wp plugin deactivate wp-mail-smtp --allow-root"
    docker exec -i $Container sh -c "cd /var/www/html && wp plugin deactivate wpcf7-recaptcha --allow-root"
    docker exec -i $Container sh -c "cd /var/www/html && wp plugin deactivate login-recaptcha --allow-root"
    docker exec -i $Container sh -c "cd /var/www/html && wp plugin deactivate wps-hide-login --allow-root"
    docker exec -i $Container sh -c "cd /var/www/html && wp plugin deactivate google-site-kit --allow-root"
    docker exec -i $Container sh -c "cd /var/www/html && wp plugin deactivate official-facebook-pixel --allow-root"
}

function Install-Docker-WordPress-CLI
{
    Param(
        [Parameter(Mandatory)]
        [String]$Container
    )

    docker exec -i $Container sh -c "cd /var/www/html && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
    docker exec -i $Container sh -c "cd /var/www/html && chmod +x wp-cli.phar"
    docker exec -i $Container sh -c "cd /var/www/html && mv wp-cli.phar /usr/local/bin/wp"
}

function Set-Docker-WordPress-URL
{
    Param(
        [Parameter(Mandatory)]
        [String]$Container,
        [Parameter(Mandatory)]
        [String]$Old,
        [Parameter(Mandatory)]
        [String]$New
    )

    # TODO: perform check, to see if the WordPress CLI is already installed.
    Install-Docker-WordPress-CLI $Container

    # replace wordpress url.
    docker exec -i $Container sh -c "cd /var/www/html && wp search-replace --all-tables '$Old' '$New' --allow-root"
}