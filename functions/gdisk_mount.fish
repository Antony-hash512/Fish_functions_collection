function gdisk_mount
	mkdir -p ~/GoogleDrive
	rclone mount gdrive: ~/GoogleDrive --vfs-cache-mode full &
end
