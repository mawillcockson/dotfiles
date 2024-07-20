rclone `
    copy `
    --progress `
    --checksum `
    --human-readable `
    --onedrive-server-side-across-configs `
    --immutable `
    --ignore-case `
    --exclude "**/Thumbs.db" `
    --exclude "**/desktop.ini" `
    --exclude "**/.DS_Store" `
    C:\Users\Public\Pictures\ `
    mawillcockson_onedrive:FamilyPhotos/
