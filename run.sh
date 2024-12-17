#!/bin/bash
set -x
# Check for required parameters
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <wordpress_folder> <file_id>"
    exit 1
fi

# Assign parameters to variables
WORDPRESS_FOLDER=$1
echo $WORDPRESS_FOLDER
FILE_ID=$2
echo "File GG Driver ID: $FILE_ID"

script_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
extension_zip="$script_dir/all-in-one-wp-migration-unlimited-extension.zip"
echo "$extension_zip"


download_gg_driver_file() {
    echo "Downloading backup file from Google Drive..."
    BACKUP_FILE="backup.wpress"
    gdown "https://drive.google.com/uc?id=$FILE_ID" --output "$BACKUP_FILE"
}
# Define the restore_domain function
restore_domain() {
    local domain_path="$1"
    local domain=$(basename "$(dirname "$domain_path")") # Extract domain name
    local owner_group=$(stat -c "%U:%G" "$domain_path")
    echo "Restoring $domain"

    cd "$domain_path" || {
        echo "Directory not found: $domain_path"
        return
    }

    echo "$domain_path"
    echo "$domain"
    echo "$owner_group"

    if ! wp --allow-root plugin is-active all-in-one-wp-migration; then
        # Check if the plugin is installed
        if ! wp --allow-root plugin is-installed all-in-one-wp-migration; then
            # Install and activate the plugin
            echo "Install and activate all-in-one-wp-migration"
            wp --allow-root plugin install all-in-one-wp-migration --activate
        else
            # Activate the plugin if it's installed but not active
            echo "Activate all-in-one-wp-migration"
            wp --allow-root plugin update all-in-one-wp-migration
            wp --allow-root plugin activate all-in-one-wp-migration
        fi
        sudo chown -R "$owner_group" $domain_path/wp-content/plugins/all-in-one-wp-migration/
        sudo chmod -R 755 $domain_path/wp-content/plugins/all-in-one-wp-migration/
    else
        wp --allow-root plugin update all-in-one-wp-migration
        echo "all-in-one-wp-migration is already active"
    fi

    local ext_dir="$domain_path/wp-content/plugins/all-in-one-wp-migration-unlimited-extension/"
    if wp --allow-root plugin is-active all-in-one-wp-migration-unlimited-extension; then
        # Check if the unlimited extension is installed
        echo "all-in-one-wp-migration-unlimited-extension is already active"
        wp --allow-root plugin deactivate all-in-one-wp-migration-unlimited-extension
    fi
    wp --allow-root plugin delete all-in-one-wp-migration-unlimited-extension
    wp --allow-root plugin install "$extension_zip" --activate
    sudo chown -R "$owner_group" "$ext_dir"
    sudo chmod -R 755 "$ext_dir"

    
    download_gg_driver_file
    
    local ai1wm_dir="$domain_path/wp-content/ai1wm-backups"
    sudo chown -R "$owner_group" "$ai1wm_dir"
    sudo chmod -R 755 "$ai1wm_dir"
    # Perform the restore
    backup_dir="$domain_path/wp-content/ai1wm-backups"
    latest_backup="$(ls -1t "$backup_dir"/*.wpress | head -n1)"
    
    echo "file backup $latest_backup"

    if [ -z "$latest_backup" ]; then
        echo "No backup file found to restore for $domain"
        return
    fi
    latest_backup_name=$(basename "$latest_backup")
    wp ai1wm restore "$latest_backup_name" --allow-root
    echo "Restore completed for $domain"

    # remove older backup
    sudo rm -rf "$backup_dir"/*.wpress

    # Uninstall the All-in-One WP Migration plugins after restore
    wp --allow-root plugin deactivate all-in-one-wp-migration-unlimited-extension
    wp --allow-root plugin delete all-in-one-wp-migration-unlimited-extension

    wp --allow-root plugin deactivate all-in-one-wp-migration
    wp --allow-root plugin delete all-in-one-wp-migration

    echo "Update owner $owner_group $domain_new_path"
    sudo chown -R $owner_group $domain_new_path
}

restore_domain "$WORDPRESS_FOLDER"
set +x