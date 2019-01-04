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
        #Last=`ls -d "*/" | grep ".complete" | sort | tail -1`
        Last=`ls -d */ | sort | tail -1`
        echo "Last: $Last"
        #Check if the directory is there
        if [ -n $Last ]
        then LastBackUp="$BackupPath/$BackupFold/$HostName/$Last"
        else LastBackUp=""
        fi
        # OK get back to wherever we were
        cd -
    else LastBackUp=""
    fi
    echo "The backup path is set to:$Last"
}

#List all packages installed and put them into a text-document to be backed up.
function Pacman()
{
    pacman -Qqe > "$packages"
}

#Get the time and date for the backup
#Add -%M to the date function to enable backups more often than once an hour.
function GetName()
{
    BackupTime=`date +%Y-%m-%d-%H`
}

#The backup command itself
function Backup()
{
    mkdir -p "$BackupPath/$BackupFold/$HostName/$BackupTime"
    if [ -n LastBackUp ]
    then
    #Nothing to link to
        res=30
        while [ $res -eq 30 ]
        do
            echo "Baacking up to $BackupPath" >> backup.log
            rsync $opts --exclude-from="$excl" $BackupDirs "$BackupPath/$BackupFold/$HostName/$BackupTime"
            res="$?"
        done
    else
    #Link to the old backup
        res=30
        while [ $res -eq 30 ]
        do
            echo "Baacking up to $BackupPath" >> backup.log
            rsync $opts --exclude-from="$excl" --link-dest="$LastBackUp" $BackupDirs "$BackupPath/$BackupFold/$HostName/$BackupTime" > $BackupPath.log
            res="$?"
        done
    fi
    #If the backup was a succes then mark it as such
    echo "$BackupPath backup rsync exited with result: $res" >> backup.log
    if [ $res -eq 0 ] || [ $res -eq 24 ]
    then mv -T "$BackupPath/$BackupFold/$HostName/$BackupTime" "$BackupPath/$BackupFold/$HostName/$BackupTime.complete"
    fi
}

#As a test perform a dryrun
function BackupTest()
{
    mkdir -p "$BackupPath/$BackupFold/$HostName/$BackupTime"
    if [ -n LastBackUp ]
    then
        #Nothing to link to
        rsync $opts --dry-run --exclude="$excl" $BackupDirs "$BackupPath/$BackupFold/$HostName/$BackupTime"
    else
        #Link to the old backup
        rsync $opts --dry-run --exclude="$excl"  --link-dest=$LastBackUp $BackupDirs "$BackupPath/$BackupFold/$HostName/$BackupTime"
    fi
}

function Clean()
{
    rm -rf "$BackupPath/$BackupFold/$HostName/$BackupTime"
}

function DeleteOld()
{
    if [ $age -gt 0 ]
    then
        echo "Deleting old backups is not implemnted" #Remove backups older than age (days)
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
len=`expr ${#Backup[@]} - 1`
for i in $(seq 0 $len)
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
