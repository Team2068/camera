#!/bin/bash
#the difference between this script and the first one is instead of restarting ffmpeg I pause the stream and unpause the other leaving them in memory the entire time

#quick change vars
declare -r DESTINATION_IP="10.20.68.3"
declare -r DESTINATION_PORT="1180"

declare -r BUFFER_SIZE="500k"
declare -r BITRATE="750K"

#change directory into the ffmpeg build so that we can ./run it later
cd /home/odroid/ffmpeg-rockchip-master


#TODO: add a check to confirm that the cameras we are accessing exist on the expected /dev/video0 and /dev/video2

# start the inital camera views

echo "Starting cam2"
./ffmpeg -nostdin -f v4l2 -i /dev/video2 -framerate 30 -c:v h264_rkmpp -flags +low_delay -b:v $BITRATE -bufsize $BUFFER_SIZE -g 30 -bf 0 -flush_packets 1 -c:a copy -f mpegts udp://$DESTINATION_IP:$DESTINATION_PORT?pkt_size=1316 > /dev/null 2>&1 < /dev/null &
FFMPEG_PID2=$!
echo "Pausing cam2"
kill -s SIGSTOP $FFMPEG_PID2 

#cam1
./ffmpeg -nostdin -f v4l2 -i /dev/video0 -framerate 30 -c:v h264_rkmpp -flags +low_delay -b:v $BITRATE -bufsize $BUFFER_SIZE -g 30 -bf 0 -flush_packets 1 -c:a copy -f mpegts udp://$DESTINATION_IP:$DESTINATION_PORT?pkt_size=1316 > /dev/null 2>&1 < /dev/null &
FFMPEG_PID1=$!


#loop for switching
while IFS= read -r line; do
	if [[ "$line" == "camera1" ]]; then
		echo "pausing cam2"
		kill -s SIGSTOP $FFMPEG_PID2
		echo "unpausing cam1"
		kill -s SIGCONT $FFMPEG_PID1

	elif [[ "$line" == "camera2" ]]; then
		echo "pausing cam1"
		kill -s SIGSTOP $FFMPEG_PID1
		echo "unpausing cam2"
		kill -s SIGCONT $FFMPEG_PID2
	elif [[ "$line" == "reset" ]]; then
		echo "stoping both camera streams"
		kill $FFMPEG_PID1
		kill $FFMPEG_PID2

		echo "starting cams back up"
		./ffmpeg -nostdin -f v4l2 -i /dev/video2 -framerate 30 -c:v h264_rkmpp -flags +low_delay -b:v $BITRATE -bufsize $BUFFER_SIZE -g 30 -bf 0 -flush_packets 1 -c:a copy -f mpegts udp://$DESTINATION_IP:$DESTINATION_PORT?pkt_size=1316 > /dev/null 2>&1 < /dev/null &
		FFMPEG_PID2=$!
		echo "Pausing cam2"
		kill -s SIGSTOP $FFMPEG_PID2 

		./ffmpeg -nostdin -f v4l2 -i /dev/video0 -framerate 30 -c:v h264_rkmpp -flags +low_delay -b:v $BITRATE -bufsize $BUFFER_SIZE -g 30 -bf 0 -flush_packets 1 -c:a copy -f mpegts udp://$DESTINATION_IP:$DESTINATION_PORT?pkt_size=1316 > /dev/null 2>&1 < /dev/null &
		FFMPEG_PID1=$!
	else 
		echo "not a standard command"
	fi
done < <(nc -l -p 5802)

echo "connection closed, exiting safely"
kill $FFMPEG_PID1
kill $FFMPEG_PID2

#delay to give it time to execute 
sleep 1

if [[kill -0 $FFMPEG_PID1 ]]; then
	kill -9 $FFMPEG_PID1
fi

if [[kill -0 $FFMPEG_PID2 ]]; then
	kill -9 $FFMPEG_PID1
fi
