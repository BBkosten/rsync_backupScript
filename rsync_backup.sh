#!/bin/bash
LOG="/var/log/rsync_backup.log"
exec >> $LOG 2>&1

if [ ! -f "/home/rsync/rsync_config.cfg" ]; then
       echo -e "!!!!!!!!!!!!!!!!!!!!!!!! ERROR CODE: 999 Configuration file not found !!!!!!!!!!!!!!!!!!!!!!!!!\nPut the rsync_config.cfg into the directory as specified in script, or change path inside the script!"
       exit
fi

source /home/rsync/rsync_config.cfg

if [ -e $PID_FILE ]; then
       echo -e "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ERROR CODE: 666 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\nThis task is already running or previous run was completed with errors. Location lock file:$PID_FILE"
       exit 1
fi

touch $PID_FILE


if [ ! -f "$SERVERS_LIST" ]; then 
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!! ERROR CODE: 404 Server_list file not found !!!!!!!!!!!!!!!!!!!!!!!!!!"
    else
        if [ ! -s "$SERVERS_LIST" ]; then 
	        echo "!!!!!!!!!!!!!!!!!!!!!!!!!! ERROR CODE: 404 Server_list file is empty !!!!!!!!!!!!!!!!!!!!!!!!!!" 
            exit 1 
        fi
fi

is_var_empty() {
    if [ -z $DST_FOLDER]; then
        echo -e "[$1]"
    else
        echo "Hostname received: $DST_FOLDER, continue"
    fi
}

cat << EOF                                                                               
               *****************************************************               
               ***************NEW BUCKUP STARTED********************               
               ***********`date`***************                                    
               *****************************************************               
EOF
start_all=$(date +%s)
for SERVER_IP in $(cat $SERVERS_LIST)
    do
    echo "###############################################################################################"
    start=$(date +%s)
    if ping -c 1 $SERVER_IP &> /dev/null
        then
            echo "<<<<<<<<<<<<<<<<<<<<<<<<< Host $SERVER_IP is alive, start backup >>>>>>>>>>>>>>>>>>>>>>>>>>>"
            echo -e "`date` Start time backup $SERVER_IP"
            DST_FOLDER="$(ssh -o ConnectTimeout=90 -i $KEY $USER@$SERVER_IP 'echo "$HOSTNAME"')" # Добавил -о таймаут и ключ.
            #DST_FOLDER="" #For tests
                #is_var_empty "!!!!!!!!!!!! ERROR! Server's Hostname wasn't received from the server $SERVER_IP !!!!!!!!!!!!\nWill try to started to get backup to the directory $DST_DIR If backup will be success, you shuld to move it to right dirrectory"
                if [ -z $DST_FOLDER ]; then
                    echo -e "!!!!!!!!!!!! ERROR! Server's Hostname wasn't received from the server $SERVER_IP !!!!!!!!!!!!\nWill try to started to get backup to the directory $DST_DIR If backup will be success, you shuld to manualy move it to right dirrectory!"
                    #exit 1
                else
                    echo "Hostname received: $DST_FOLDER, continue"
                fi
                    if [ ! -d "$DST_DIR/$DST_FOLDER/" ]; then
                        mkdir $DST_DIR/$DST_FOLDER/
                    fi
                rsync -a --progress --exclude-from=$FILTER -e "ssh -i $KEY" $USER@$SERVER_IP:$SRC_DIR $DST_DIR/$DST_FOLDER/$(date +%F_%H:%M)
                    if [ "$?" = 0 ]; then
                        echo "rsync answer: $?"
                        echo "///////////////////////////////Start deleting old backups/////////////////////////////////////" # Перенес секцию удаления бэкапов
                        #start_back=$(date +%s)#######
                        DELETE_BEFORE="$(date +%Y%m%d%H%M -d "$DELETE_OLD_FOLDER_TIME")"
                        DELETE_IN_FOLDERS="$(ls $DST_DIR/$DST_FOLDER/)"
                        for OLD_FOLDERS in $DELETE_IN_FOLDERS
                            do
                                IS_DELETE_DATE="$(echo "$OLD_FOLDERS" | tr -cd [:digit:])"   # removing all symbols except numbers
                                #is_var_empty "!!!!!! Hostname wasn't received from the server $SERVER_IP We can't starting delete old backups !!!!!!" ####!!!!!!!! тестирую, как и выше функцию.

                                if [ "$IS_DELETE_DATE" -lt "$DELETE_BEFORE" ]; then
                                        rm -rf $DST_DIR/$DST_FOLDER/$OLD_FOLDERS/ && echo -e "$OLD_FOLDERS has been deleted as a old backup"
                                fi
                        done
                        echo "Nothing else to delete, hasn't backups older then $DELETE_BEFORE"
                        #finish_back=$(date +%s) ######
                        #echo -e "Delete old backups for HOST-$SERVER_IP worked for $((finish_back - start_back)) seconds"
                    else
                    echo "!!!!!!! rsync answer with ERROR CODE: $? for HOST:$SERVER_IP We won't starting delete old backups !!!!!!"
                    fi
                #fi
        else
            echo "<<<<<<<<<<<<<<<<<<< ERROR! Host $SERVER_IP is down, skip it, try next >>>>>>>>>>>>>>>>>>>>>>"
    fi           
    finish=$(date +%s)
    echo -e "`date` Rsync and clean old backups for HOST-$SERVER_IP worked for $((finish - start)) seconds \n###############################################################################################"
done
finish_all=$(date +%s)
echo -e "***`date` ALL TASKS RSYNC AND CLEAN OLD BACKUPS for ALL HOSTS worked for $((finish_all - start_all)) seconds *** \n***********************************************************************************************"

rm $PID_FILE
exit 





