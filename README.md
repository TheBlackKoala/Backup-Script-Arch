This is a backupscript.
It is built for use on arch-linux. Specifically a gnome-desktop environment 
but should work for all arch-users.
The main arch-specific backup-part is the use of pacman to output all 
installed packages as to easily restore these in the case of building a new 
system.
The rest should be general for linux.

Please feel free to come with suggestions or ask for help with the script.

The idea is based on the script created by David Both: https://github.com/opensourceway/rsync-backup-script

To configure the script to your system please change backup.conf appropriately.
When running the system use sudo to access the root directories.

No warranty of any kind at all.
You may change the script in any way you find suitable, please just give credit.