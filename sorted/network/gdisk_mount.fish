function gdisk_mount --description "Mount Google Drive using rclone (preconfiguration of rclone required)"
	mkdir -p ~/GoogleDrive
	rclone mount gdrive: ~/GoogleDrive --vfs-cache-mode full & # use the gdrive name during rclone configiration (or change it in this line)
end
