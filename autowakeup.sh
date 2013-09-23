#!/bin/bash

# Please run this script from 00:01 until 23:59 on the day BEFORE
# you want to rtcwake your PC

# ToDo:
# - log-function
# - code cleanup
# - check time until next start. It should be higher than 5 mins

DEBUG=true

#set -x

# define the daynames, insert a dummy, so that monday = 1
# $DAYNAME[1] gives monday
DAYNAME=(dummy monday tuesday wednesday thursday friday saturday sunday)

AUTOWAKEUP_CONF="$1"
if [ -z $1 ]; then
	AUTOWAKEUP_CONF="./autowakeup.conf"
	echo "local autowakeup.conf set"
fi

# Check, if the config is existant
if [ -f "$AUTOWAKEUP_CONF" ]; then
	. "$AUTOWAKEUP_CONF"
else
	echo "Config not found!"
	echo "Exiting!"
fi

if $DEBUG; then
	echo "MONDAY:    ${START_AT_DAY[1]}"
	echo "TUESDAY:   ${START_AT_DAY[2]}"
	echo "WEDNESDAY: ${START_AT_DAY[3]}"
	echo "THURSDAY:  ${START_AT_DAY[4]}"
	echo "FRIDAY:    ${START_AT_DAY[5]}"
	echo "SATURDAY:  ${START_AT_DAY[6]}"
	echo "SUNDAY:    ${START_AT_DAY[7]}"
fi

# sample conf (autowakeup.conf)
# MONDAY="8:00"
# TUESDAY="10:00"
# WEDNESDAY="12:00"
# THURSDAY="05:30"
# FRIDAY="07:45"
# SATURDAY="-"
# SUNDAY="-" 

f_show_alarm() {
	ALARMTIME="$(rtcwake -m show | grep alarm | sed 's/alarm: //g')"
	echo "ALARMTIME: $ALARMTIME"
	if [ "$ALARMTIME" = "off" ]; then
		echo "No alarm set!"
	else
		echo "Next alarm: $ALARMTIME"
	fi
}

f_show_rtcwake_date() {
	FUNC_DATE="$1" # the day in the week as digit
	FUNC_TODAY="$2" # true or false
	if [ ! "$2" = "true" ]; then
		echo "NEXTDAY wird gesetzt"
		NEXTDAY="next ${DAYNAME[$FUNC_DATE]}"
	fi
	echo "NEXTDAY: $NEXTDAY"
	echo "FUNC_DATE = $FUNC_DATE"
	echo "rtcwake -m no -l -t $(date -d "$NEXTDAY ${START_AT_DAY[$1]}")"
	echo "rtcwake -m no -l -t $(date -d "$NEXTDAY ${START_AT_DAY[$1]}" +%s)"
	
	# uncomment it to make it work!
	#rtcwake -m no -l -t $(date -d "$NEXTDAY ${START_AT_DAY[$1]}") +%s
}

f_check_rtc_date() {
	DAYPARAM="$1" # WAKE_UP_DAY -> nr. of the day (monday = 1)
	TODAYPARAM="$2" # TODAY = true/false

	if [ "${START_AT_DAY[$DAYPARAM]}" = "-" ]; then
		# no WAKE_UP time found
		let DAYPARAM++
		# if DAYPARAM is 8, go to 1 (monday)
		if [ $DAYPARAM -gt 7 ]; then
			DAYPARAM=1
		fi
		f_check_rtc_date $DAYPARAM
	else
		# if a WAKE_UP time is found
		f_show_rtcwake_date $DAYPARAM $TODAYPARAM
	fi
}

# f_monday() {
# 	# tomorrow-date =monday
# 
# 	# if monday has no start-time (="-"), check tuesday-start-time
# 	if [ "${START_AT_DAY[1]}" = "-" ]; then
# 		f_tuesday
# 	else
# 		f_show_rtcwake_date 1 "$1"
# 	fi
# }
# 
# f_tuesday() {
# 	# tomorrow-date = tuesday
# 
# 	# if tuesday has no start-time (="-"), check wednesday-start-time
# 	if [ "${START_AT_DAY[2]}" = "-" ]; then
# 		f_wednesday
# 	else
# 		f_show_rtcwake_date 2 "$1"
# 	fi
# }
# 
# f_wednesday() {
# 	# tomorrow-date = wednesday
# 
# 	# if wednesday has no start-time (="-"), check thursday-start-time
# 	if [ "${START_AT_DAY[3]}" = "-" ]; then
# 		f_thursday
# 	else
# 		f_show_rtcwake_date 3 "$1"
# 	fi
# }
# 
# f_thursday() {
# 	# tomorrow-date = thursday
# 
# 	# if thursday has no start-time (="-"), check friday-start-time
# 	if [ "${START_AT_DAY[4]}" = "-" ]; then
# 		f_friday
# 	else
# 		f_show_rtcwake_date 4 "$1"
# 	fi
# }
# 
# f_friday() {
# 	# tomorrow-date = friday
# 
# 	# if friday has no start-time (="-"), check saturday-start-time
# 	if [ "${START_AT_DAY[5]}" = "-" ]; then
# 		f_saturday
# 	else
# 		f_show_rtcwake_date 5 "$1"
# 	fi
# }
# 
# f_saturday() {
# 	# tomorrow-date =saturday
# 
# 	# if saturday has no start-time (="-"), check sunday-start-time
# 	if [ "${START_AT_DAY[6]}" = "-" ]; then
# 		f_sunday
# 	else
# 		f_show_rtcwake_date 6 "$1"
# 	fi
# }
# 
# f_sunday() {
# 	# tomorrow-date =sunday
# 
# 	# if sunday has no start-time (="-"), check monday-start-time
# 	if [ "${START_AT_DAY[7]}" = "-" ]; then
# 		f_monday
# 	else
# 		f_show_rtcwake_date 7 "$1"
# 	fi
# }

f_show_alarm

# check, if at least one time-entry is in the config
# and not only "-"
STARTTIME_CNT=0

for STARTTIMES in ${START_AT_DAY[@]}; do
	#echo "STARTTIMES: $STARTTIMES"
	if [ ! "$STARTTIMES" = "-" ]; then
		# check the time-format
		if [[ "$STARTTIMES" =~ ^([0-9]|[01][0-9]|2[0-3])\:[0-5][0-9] ]]; then
			let STARTTIME_CNT++
		else
			echo "Starttime not correct: $STARTTIMES"
			echo "Exiting"
			exit 1
		fi
	fi
done

if [ $STARTTIME_CNT -eq 0 ]; then
	echo "There is not one starttime defined. Exiting"
	exit 1
fi

ACT_TIME="$(date +%s)"
ACT_DAY="$(date +%u)"
TODAY_START="$(date -d "${START_AT_DAY[$ACT_DAY]}" +%s)"
echo "actual date: $ACT_TIME"
echo "targetdate:  $TODAY_START"

if [ $ACT_TIME -gt $TODAY_START ]; then
	# start-time is in the past
	# use tomorrow -> actual day +1
	WAKE_UP_DAY=$(date -d tomorrow +%u)
	TODAY=false
else
	WAKE_UP_DAY="${ACT_DAY}"
	TODAY=true
fi

echo "WAKE_UP_DAY: $WAKE_UP_DAY = ${DAYNAME[$WAKE_UP_DAY]}"
echo "TODAY: $TODAY"

f_check_rtc_date $WAKE_UP_DAY $TODAY

# case $WAKE_UP_DAY in
# 	1)
# 		f_monday $TODAY
# 		;;
# 	2)
# 		f_tuesday $TODAY
# 		;;
# 	3)
# 		f_wednesday $TODAY
# 		;;
# 	4)
# 		f_thursday $TODAY
# 		;;
# 	5)
# 		f_friday $TODAY
# 		;;
# 	6)
# 		f_saturday $TODAY
# 		;;
# 	7)
# 		f_sunday $TODAY
# 		;;
# esac

exit 0