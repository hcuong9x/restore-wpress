#!/bin/bash

# Check for required parameters
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <wordpress_folder> <file_id>"
    exit 1
fi

# Assign parameters to variables
WORDPRESS_FOLDER=$1
FILE_ID=$2

echo "WordPress Folder: $WORDPRESS_FOLDER"
echo "Google Drive File ID: $FILE_ID"

script_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
extension_zip="$script_dir/all-in-one-wp-migration-unlimited-extension.zip"
echo "Extension Path: $extension_zip"

download_gg_driver_file() {
    echo "Downloading backup file from Google Drive..."
    BACKUP_FILE="backup.wpress"
    if ! command -v gdown >/dev/null 2>&1; then
        echo "Error: gdown is not installed. Install it with 'pip install gdown'."
        exit 1
    fi
    gdown "https://drive.google.com/uc?id=$FILE_ID" --output "$BACKUP_FILE"
}

restore_domain() {
    local domain_path="$1"
    local domain=$(basename "$(dirname "$domain_path")") # Extract domain name
    local owner_group=$(stat -f "%Su:%Sg" "$domain_path" 2>/dev/null || stat -c "%U:%G" "$domain_path")
    echo "Restoring $domain"

    if [ ! -d "$domain_path" ]; then
        echo "Error: Directory not found - $domain_path"
        return
    fi

    cd "$domain_path" || exit

    echo "Directory: $domain_path"
    echo "Domain: $domain"
    echo "Owner/Group: $owner_group"
    set -x

    # Install and activate plugins
    if ! wp --allow-root plugin is-active all-in-one-wp-migration; then
        if ! wp --allow-root plugin is-installed all-in-one-wp-migration; then
            echo "Installing all-in-one-wp-migration plugin..."
            wp --allow-root plugin install all-in-one-wp-migration --activate
        else
            echo "Activating all-in-one-wp-migration plugin..."
            wp --allow-root plugin update all-in-one-wp-migration
            wp --allow-root plugin activate all-in-one-wp-migration
        fi
        sudo chown -R "$owner_group" "$domain_path/wp-content/plugins/all-in-one-wp-migration/"
        sudo chmod -R 755 "$domain_path/wp-content/plugins/all-in-one-wp-migration/"
    fi

    local ext_dir="$domain_path/wp-content/plugins/all-in-one-wp-migration-unlimited-extension/"
    wp --allow-root plugin delete all-in-one-wp-migration-unlimited-extension
    wp --allow-root plugin install "$extension_zip" --activate
    sudo chown -R "$owner_group" "$ext_dir"
    sudo chmod -R 755 "$ext_dir"
    set +x
    # Download backup file
    # download_gg_driver_file

    # Check backup directory
    local backup_dir="$domain_path/wp-content/ai1wm-backups"

    sudo chown -R "$owner_group" "$backup_dir"
    sudo chmod -R 755 "$backup_dir"

    # Move backup file to backup directory
    mv backup.wpress "$backup_dir/"
    local latest_backup="$backup_dir/backup.wpress"

    echo "Backup file: $latest_backup"

    if [ ! -f "$latest_backup" ]; then
        echo "Error: No backup file found to restore."
        return
    fi

    # Perform restore
    wp ai1wm restore "$(basename "$latest_backup")" --allow-root
    echo "Restore completed for $domain"

    # Cleanup
    sudo rm -f "$backup_dir"/*.wpress

    # Deactivate and delete plugins
    wp --allow-root plugin deactivate all-in-one-wp-migration-unlimited-extension
    wp --allow-root plugin delete all-in-one-wp-migration-unlimited-extension
    wp --allow-root plugin deactivate all-in-one-wp-migration
    wp --allow-root plugin delete all-in-one-wp-migration

    echo "Reset ownership for $domain_path"
    sudo chown -R "$owner_group" "$domain_path"
}

restore_domain "$WORDPRESS_FOLDER"