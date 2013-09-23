#!/bin/bash

# Please run this script from 00:01 until 23:59 on the day BEFORE
# you want to rtcwake your PC

DEBUG=true

AUTOWAKEUP_CONF="$1"

# Check, if the config is existant
if [ -f "$AUTOWAKEUP_CONF" ]; then
	. "$AUTOWAKEUP_CONF"
else
	echo "Config not found!"
	echo "Exiting!"
fi

if $DEBUG; then
	echo "MONDAY:    $MONDAY_wakeup"
	echo "TUESDAY:   $TUESDAY_wakeup"
	echo "WEDNESDAY: $WEDNESDAY_wakeup"
	echo "THURSDAY:  $THURSDAY_wakeup"
	echo "FRIDAY:    $FRIDAY_wakeup"
	echo "SATURDAY:  $SATURDAY_wakeup"
	echo "SUNDAY:    $SUNDAY_wakeup"
fi

# sample conf (autowakeup.conf)
# MONDAY="8:00"
# TUESDAY="10:00"
# WEDNESDAY="12:00"
# THURSDAY="05:30"
# FRIDAY="07:45"
# SATURDAY="-"
# SUNDAY="-" 

f_monday() {
	# tomorrow-date =monday

	# if monday has no start-time (="-"), check tuesday-start-time
	if [ "$MONDAY_wakeup" = "-" ]; then
		f_tuesday 1
	else
		if [ "$1" = "1" ]; then # if function is called from f_sunday
			echo "rtcwake -m no -l -t $(date -d "next monday $MONDAY_wakeup" +%s)"
		else # # tomorrow-date = monday (normal run)
			echo "rtcwake -m no -l -t $(date -d "tomorrow $MONDAY_wakeup" +%s)"
		fi
	fi
}

f_tuesday() {
	# tomorrow-date = tuesday

	# if tuesday has no start-time (="-"), check wednesday-start-time
	if [ "$TUESDAY_wakeup" = "-" ]; then
		f_wednesday 1
	else
		if [ "$1" = "1" ]; then # if function is called from f_monday
			echo "rtcwake -m no -l -t $(date -d "next tuesday $TUESDAY_wakeup" +%s)"
		else # # tomorrow-date = tuesday (normal run)
			echo "rtcwake -m no -l -t $(date -d "tomorrow $TUESDAY_wakeup" +%s)"
		fi
	fi
}

f_wednesday() {
	# tomorrow-date = wednesday

	# if wednesday has no start-time (="-"), check thursday-start-time
	if [ "$WEDNESDAY_wakeup" = "-" ]; then
		f_thursday 1
	else
		if [ "$1" = "1" ]; then # if function is called from f_tuesday
			echo "rtcwake -m no -l -t $(date -d "next wednesday $WEDNESDAY_wakeup" +%s)"
		else # # tomorrow-date = tuesday (normal run)
			echo "rtcwake -m no -l -t $(date -d "tomorrow $WEDNESDAY_wakeup" +%s)"
		fi
	fi
}

f_thursday() {
	# tomorrow-date = thursday

	# if thursday has no start-time (="-"), check friday-start-time
	if [ "$THURSDAY_wakeup" = "-" ]; then
		f_friday 1
	else
		if [ "$1" = "1" ]; then # if function is called from f_wednesday
			echo "rtcwake -m no -l -t $(date -d "next thursday $THURSDAY_wakeup" +%s)"
		else # # tomorrow-date = tuesday (normal run)
			echo "rtcwake -m no -l -t $(date -d "tomorrow $THURSDAY_wakeup" +%s)"
		fi
	fi
}

f_friday() {
	# tomorrow-date = friday

	# if friday has no start-time (="-"), check saturday-start-time
	if [ "$FRIDAY_wakeup" = "-" ]; then
		f_saturday 1
	else
		if [ "$1" = "1" ]; then # if function is called from f_thursday
			echo "rtcwake -m no -l -t $(date -d "next friday $FRIDAY_wakeup" +%s)"
		else # # tomorrow-date = friday (normal run)
			echo "rtcwake -m no -l -t $(date -d "tomorrow $FRIDAY_wakeup" +%s)"
		fi
	fi
}

f_saturday() {
	# tomorrow-date =saturday

	# if saturday has no start-time (="-"), check sunday-start-time
	if [ "$SATURDAY_wakeup" = "-" ]; then
		f_sunday 1
	else
		if [ "$1" = "1" ]; then # if function is called from f_friday
			echo "rtcwake -m no -l -t $(date -d "next friday $SATURDAY_wakeup" +%s)"
		else # # tomorrow-date = saturday (normal run)
			echo "rtcwake -m no -l -t $(date -d "tomorrow $SATURDAY_wakeup" +%s)"
		fi
	fi
}

f_sunday() {
	# tomorrow-date =sunday

	# if sunday has no start-time (="-"), check monday-start-time
	if [ "$SUNDAY_wakeup" = "-" ]; then
		f_monday 1
	else
		if [ "$1" = "1" ]; then # if function is called from f_saturday
			echo "rtcwake -m no -l -t $(date -d "next sunday $SUNDAY_wakeup" +%s)"
		else # # tomorrow-date = sunday (normal run)
			echo "rtcwake -m no -l -t $(date -d "tomorrow $SUNDAY_wakeup" +%s)"
		fi
	fi
}

# check, if at least one time-entry is in the config
# and not only "-"
STARTTIME_CNT=0

for STARTTIMES in $MONDAY_wakeup $TUESDAY_wakeup $WEDNESDAY_wakeup $THURSDAY_wakeup $FRIDAY_wakeup $SATURDAY_wakeup $SUNDAY_wakeup; do
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

# Get the nr. of the day in the week -> monday = 1
TOMORROW=$(date -d tomorrow +%u)

case $TOMORROW in
	1)
		f_monday
		;;
	2)
		f_tuesday
		;;
	3)
		f_wednesday
		;;
	4)
		f_thursday
		;;
	5)
		f_friday
		;;
	6)
		f_saturday
		;;
	7)
		f_sunday
		;;
esac

exit 0