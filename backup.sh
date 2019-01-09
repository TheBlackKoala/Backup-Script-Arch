#!/bin/bash

#Load the configuration
source ./backup.conf

#Check if the drive to backup to is mounted
function CheckMount()
{
    df --output="target" | grep -qs "$BackupPath"
    Mounted=$?
}

#Find the folder with the last name - this will be the latest backup
function GetLastBackup()
{
    # Be sure to start with null
    LastBU=""
    # Change to backup directory for current host
    cd "$BackupPath/$BackupFold/$HostName"
    if [ $? -eq 0 ]
    then
        #List all directories in the folder
        #Only .complete backups were finished so link to the newest .complete.
        LastSlash=`ls -d */ 2> /dev/null | grep ".complete" | sort | tail -1`
        #Check if the directory is there
        if [ -z $LastSlash ]
        then LastBackUp=""
        else
            #Remove the last "/" to enable rsync to use it in link-dest
            Last=${LastSlash::-1}
            LastBackUp="$BackupPath/$BackupFold/$HostName/$Last"
        fi
        # OK get back to wherever we were
        cd -
    else LastBackUp=""
    fi
    echo "$BackupPath Last: $Last" >> backup.log
    echo "The earlier backup path for $BackupPath is set to:$Last"
}

#List all packages installed and put them into a text-document to be backed up.
function Pacman()
{
    pacman -Qqe > "$packages"
}


#Add -%M to the date function to enable backups more often than once an hour.
function GetName()
{
    #Get the time and date for the backup
    BackupTime=`date +%Y-%m-%d-%H`
    #Set the backup path
    BackupName=$BackupPath/$BackupFold/$HostName/$BackupTime
    cd "$BackupPath/$BackupFold/$HostName"
    if [ $? -eq 0 ]
    then
        #List all noncomplete backups in the folder
        InCompSlash=`ls -d */ 2> /dev/null | grep -v ".complete" | sort | tail -1`
        #Check if there are any non-complete backups
        if [ -z $InCompSlash ]
        then :
             #Move the non-complete backup to the folder that will now be the backup - this will allow partial backups
        else InComp=${InCompSlash::-1}
             if [ $InComp != $BackupTime ]
             then mv "$InComp" "$BackupTime"
             fi
        fi
        # Get back to wherever we were
        cd -
        #Write to the log-file
        if [ -z $InComp ]
        then :
        else echo "Using old backup: $InComp on $BackupPath" > backup.log
             echo "Using old backup: $InComp on $BackupPath"
        fi
    else LastBackUp=""
    fi
}

#The backup command itself
function Backup()
{
    mkdir -p "$BackupName"
    if [ -z $LastBackUp ]
    then
    #Nothing to link to
        res=30
        while [ $res -eq 30 ]
        do
            echo "Backing up to $BackupPath" >> backup.log
            rsync $opts --exclude-from="$excl" $BackupDirs "$BackupName"
            res="$?"
        done
    else
    #Link to the old backup
        res=30
        while [ $res -eq 30 ]
        do
            echo "Backing up to $BackupPath" >> backup.log
            rsync $opts --exclude-from="$excl" --link-dest="$LastBackUp" $BackupDirs "$BackupName"
            res="$?"
        done
    fi
    #If the backup was a succes then mark it as such
    echo "$BackupPath backup rsync exited with result: $res" >> backup.log
    #The backup is complete if it worked like it should or if it didn't transfer files that vanished (program files that may have been removed during transfer)
    if [ $res -eq 0 ] || [ $res -eq 24 ]
    then mv -T "$BackupName" "$BackupName.complete"
         if [ deleteIncomp -gt 0 ]
         then ls -d */ 2> /dev/null | grep -v ".complete" | xargs rm -rf
         fi
    fi
}

#As a test perform a dryrun
function BackupTest()
{
    mkdir -p "$BackupName"
    if [ -z LastBackUp ]
    then
        #Nothing to link to
        rsync $opts --dry-run --exclude="$excl" $BackupDirs "$BackupName"
    else
        #Link to the old backup
        rsync $opts --dry-run --exclude="$excl" --link-dest="$LastBackUp" $BackupDirs "$BackupName"
    fi
}

function Clean()
{
    rm -rf "$BackupPath/$BackupFold/$HostName/$BackupTime"
}

#Will delete backups that are more than age days old, counting only whole days.
function DeleteOld()
{
    if [ $age -gt 0 ]
    then
        echo "Deleting old backups is not tested. Remove the comment from the function DeleteOld to test it."
        : '
        #Get a list of directories in backup directory
        #Set oldPath to first
        oldPath=`ls -d */ 2> /dev/null | sort | head -1`
        deleted=1
        while [ $deleted -eq 1 ]
        do
            a=`date +%s`
            b=`date -d $DateCheck +%s`
            old=`echo "($a - $b) / (24*60*60)" | bc -l`
            if [ old -gt $age ]
            then rm -rf $oldPath
                 oldPath=`ls -d */ 2> /dev/null | sort | head -1`
            else deleted=0
        done
        '
    fi
}

function CheckTest()
{
    FullTest
}

function FullTest()
{
    GetName
    Pacman
    GetLastBackup
    BackupTest
    Clean
}

#To delete any backup older than $age if $age > 0 or ask the user if the drive has been filled up
function Check()
{
    DeleteOld
    #Get the percentage of the drive being used. If it is larger than 99% then ask the user if the still want to try to backup.
    Used=`df -h --output=target --output=pcent | grep "$BackupPath" | grep -o "[0-9]*%" | grep -o "[0-9]*"`
    if [ $Used -gt 98 ]
    then
        zenity --question --text="$Warning$BackupPath$FullWarning" --default-cancel
        if [[ $? == 0 ]]
        then
            Do the backup anyways.
            FullBackup
        fi
    Get only the available space and the path then get the line with the path for the drive and get only the available space
    elif [ `df --output=avail --output=target | grep "$BackupPath" | grep -o "[0-9]*"` -lt 1000000 ]
    then
        --zenity --question --text="$Warning$BackupPath$SizeWarning" --default-cancel
        if [[ $? == 0 ]]
        then
            #Do the backup anyways.
            FullBackup
        fi
    else
        #If the drive is not full then backup
        FullBackup
    fi
}

function FullBackup()
{
    #Get the date and time of backuo for the name of the folder
    GetName
    #Put the package configuration into a file in the root directory
    Pacman
    #Get the last backup
    GetLastBackup
    #Do the actual backup
    Backup
}

#Check if the drive is mounted and if then check for backups
echo "Running backups at " `date +%Y-%m-%d-%H` >> backup.log
echo "" > rsyncBackup.log
for i in ${!Backup[@]}
do
    BackupPath=${Backup[$i]}
    echo "Trying to backup to: $BackupPath"
    #Check if the current backup device is connected
    CheckMount
    #0 for no errors in finding the mountpoint
    if [ $Mounted -eq 0 ]
    #Backup if the device is connected, if not then do nothing
    then
        #To test
        #CheckTest
        #To check for old backups, the drive being full and doing the actual backup
        Check
    fi
done
