while [ $(ls *.pcap | wc -l | tail -1) -ne 0 ]; do
	FILE=$(ls *.pcap | head -1 | tail -1)
	echo Processing $FILE
	/usr/local/bro/bin/bro -r $FILE local.bro 1>/dev/null 2> /dev/null
	while [ $(ls *.log 1>/dev/null 2>/dev/null | wc -l | tail -1) -ne 0 ]; do
		LOGFILE=$(ls *.log | head -1 | tail -1)
		cat $LOGFILE >> /data/bro/current/$LOGFILE
		rm $LOGFILE
	done
	mv $FILE processed
done
