#!/bin/bash
TIME=`date +%d.%m.%y`
TIMENOW=`date +%d.%m_%H:%M:%S`
LOGFILE=/var/log/backup-$TIME.log
#LOGFILE=/dev/null
TMP_DIR=/tmp/backup
mkdir $TMP_DIR
FILENAME=files.$TIME.tar.gz

DIR=/var/www

YANDEX_USER=YANDEX_USER
YANDEX_PASSWORD=YANDEX_PASSWORD
YANDEX_URL=https://webdav.yandex.ru

while [ -n "$1" ]
do
case "$1" in
-m) manual=true;;
-h) echo "Backup script to Yadex.Disk. Use -m option for make backup in manual mode"; exit;;
esac
shift
done

if [ "$manual" = true ]
then
echo "MANUAL MODE"
echo "`date +%d.%m_%H:%M:%S` MANUAL MODE " >>$LOGFILE
FILENAME=manual.$TIME.tar.gz
fi
TMP_FILE=$TMP_DIR/$FILENAME


echo "`date +%d.%m_%H:%M:%S` Backup started" >>$LOGFILE

echo "`date +%d.%m_%H:%M:%S` Creating archieve $TMP_FILE..." >>$LOGFILE
start=$(date +%s.%N)

tar -czf - -P $DIR 2 | split -b 1024m - $TMP_FILE >>$LOGFILE

BCK_FILES=$(ls $TMP_DIR| tr "\n" ", " )
if [[ $? -ne 0 ]]
then
  echo "failed `date +%d.%m_%H:%M:%S`: lxc/tar/gzip error: $?" >>$LOGFILE 
  exit 1;
else
echo "`date +%d.%m_%H:%M:%S` Success" >>$LOGFILE
fi
dur=$(echo "$(date +%s.%N) - $start" | bc)
printf "Creating time: %.6f seconds" $dur >> $LOGFILE

echo "" >>$LOGFILE
echo "`date +%d.%m_%H:%M:%S` Uploading backup...">>$LOGFILE

start=$(date +%s.%N)

BCK_FILES=$(ls /tmp/backup| tr "\n" ", " )
cd $TMP_DIR && md5sum "{$BCK_FILES}" >> /tmp/backup/$FILENAME.md5.txt
BCK_FILES=$(ls /tmp/backup| tr "\n" ", " )
cd $TMP_DIR && curl -v --user $YANDEX_USER:$YANDEX_PASSWORD -T "{$BCK_FILES}" $YANDEX_URL/Backups/ >>$LOGFILE
printf "Uploading time: %.6f seconds" $dur >> $LOGFILE
echo "" >>$LOGFILE

rm -rf $TMP_DIR

echo "`date +%d.%m_%H:%M:%S` Backup complete">>$LOGFILE
echo "`date +%d.%m_%H:%M:%S` Removing old files...">>$LOGFILE


days="864000"
now_date="$(date +%s)"
full=$(curl --silent --user $YANDEX_USER:$YANDEX_PASSWORD --request "PROPFIND" --header "Depth: 1" $YANDEX_URL/Backups| xmllint --format - |xmlstarlet sel -T -t -m //d:response/d:propstat/d:prop -v d:displayname -o "|" -v d:getlastmodified -o ';;')
name=( $(echo $full |awk -v FS='|' -v RS=';;' '{print $1}' ) )
date=( $(echo $full |awk -v FS='|' -v RS=';;' '{system ("date +%s --date=\""$2"\" ")}') ) 

n=0
for i in "${date[@]}"
do 
cur_date=${date[$n]}
(( diff = now_date - cur_date ))
if [ "$diff" -gt "$days" ]
then
        if [ "${name[$n]}" != "Backups" ]
        then
                if [[ "${name[$n]}" != *"manual"* ]]
                then
                        echo "File "${name[$n]} "is too old. Removing..." >>$LOGFILE
                        curl --silent --user $YANDEX_USER:$YANDEX_PASSWORD --request "DELETE"  $YANDEX_URL/Backups/${name[$n]}
                fi
        fi
fi
((n=n+1))
done

echo "All old backup files was removed" >>$LOGFILE
