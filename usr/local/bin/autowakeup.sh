#!/bin/bash

#=======================================================================
#
#          FILE:  autowakeup.sh
# 
#         USAGE:  don't use it direct! Use the daemon instead:
#				  service autowakeup {start|status}
# 
#   DESCRIPTION:  sets a rtcwake-date based on a schedule for a week
# 
#       OPTIONS:  show
#				  shows the next rtcwake-date
#  REQUIREMENTS:  working rtcwake
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR:  R. Lindlein aka Solo0815
#       CREATED:  09/2013
#
# You can use and modify the script, but please share your mods!
# https://github.com/walterheisenberg/omv-autowakeup
#=======================================================================

# ToDo:
# - check time until next start. It should be higher than 5 mins
#   to give enough time to shutdown before restart

LOGGER="/usr/bin/logger"  	 # path and name of logger (default="/usr/bin/logger")
FACILITY="local6"         	# facility to log to -> see rsyslog.conf
							# for a separate Log:
							# Put the file "autoshutdownlog.conf" in /etc/rsyslog.d/

### Define the daynames, insert a dummy, so that monday = 1
# $DAYNAME[1] gives monday
DAYNAME=(dummy monday tuesday wednesday thursday friday saturday sunday)

VERSION="0.3.0"         # script version information

AUTOWAKEUP_CONF="/etc/autowakeup.conf"

######################################
######## FUNCTION DECLARATION ########
######################################

################################################################
#
#   name        : _log
#   parameter   : $LOGMESSAGE : logmessage in format "PRIORITY: MESSAGE"
#
#   return      : none
#
# logs to syslog and/or to CLI
_log()
{
	[[ "$*" =~ ^([A-Za-z]*):(.*) ]] &&
		{
			PRIORITY=${BASH_REMATCH[1]}
			LOGMESSAGE=${BASH_REMATCH[2]}
			[[ "$(basename "$0")" =~ ^(.*)\. ]] &&
			if $FAKE; then
				LOGMESSAGE="${BASH_REMATCH[1]}[$$]: $PRIORITY: 'FAKE-Mode: $LOGMESSAGE'";
			else
				LOGMESSAGE="${BASH_REMATCH[1]}[$$]: $PRIORITY: '$LOGMESSAGE'";
			fi;
		}

	if $FAKE; then echo "$(date '+%b %e %H:%M:%S'): $USER: $FACILITY $LOGMESSAGE"; fi

	[ $SYSLOG ] && $LOGGER -p $FACILITY.$PRIORITY "$LOGMESSAGE"
}

################################################################
#
#   name          : f_show_alarm
#   parameter     : none
#   global return : none
#   return        : 0
#
# shows the next rtcwake-date
f_show_alarm() {
	if $DEBUG; then _log "DEBUG: f_show_alarm start"; fi
	# for systems with 'rtcwake -m show'
	if [ $RTC_SHOW_MODE = 1 ]; then
		ALARMTIME="$(rtcwake -m show | grep alarm | sed 's/alarm: //g')"
	# for systems without 'rtcwake -m show'. We have to read the output from /proc/driver/rtc
	elif [ $RTC_SHOW_MODE = 2 ]; then
		RTC_OUTPUT="$(cat /proc/driver/rtc)"
		ALARM_DATE="$(echo "$RTC_OUTPUT" | grep alrm_date | awk '{print $3}')"
		ALARM_TIME="$(echo "$RTC_OUTPUT" | grep alrm_time | awk '{print $3}')"
		ALARMTIME="$ALARM_DATE $ALARM_TIME"
	else
		ALARMTIME="could not be read"
	fi
	_log "DEBUG: f_show_alarm: ALARMTIME: $ALARMTIME"
	if [ "$ALARMTIME" = "off" ]; then
		_log "INFO: No alarm set yet"
	else
		_log "INFO: Next set alarm: $ALARMTIME"
	fi
}

################################################################
#
#   name          : f_set_rtcwake_date
#   parameter     : $1 = FUNC_DATE -> the day in the week as digit
#                 : $2 = FUNC_TODAY -> true or false
#                 :      if wkaeup-time is today then 'true' else 'false'
#   global return : none
#   return        : 0
#
# sets the next rtcwake-date via rtcwake
f_set_rtcwake_date() {
	FUNC_DATE="$1" # the day in the week as digit
	FUNC_TODAY="$2" # true or false
	if [ ! "$2" = "true" ]; then
		if $DEBUG; then _log "DEBUG: NEXTDAY wird gesetzt"; fi
		NEXTDAY="next ${DAYNAME[$FUNC_DATE]}"
	fi

	if $DEBUG; then
		_log "DEBUG: f_set_rtcwake_date: NEXTDAY: $NEXTDAY"
		_log "DEBUG: f_set_rtcwake_date: FUNC_DATE = $FUNC_DATE"
		_log "DEBUG: f_set_rtcwake_date: 'rtcwake -m no -l -t $(date -d "$NEXTDAY ${START_AT_DAY[$FUNC_DATE]}" +%s)'"
	fi
	
	if $FAKE; then
		# Dry run
		_log "INFO: The wakeup time would be $(date -d "$NEXTDAY ${START_AT_DAY[$FUNC_DATE]}")"
		_log "INFO: FAKE-Mode: ^^^ nothing is set - dry run -> exit here"
		exit 0
	else
		# Set rtcwake
		rtcwake -m no -l -t $(date -d "$NEXTDAY ${START_AT_DAY[$FUNC_DATE]}") +%s
		if [ $? -eq 0 ]; then
			_log "INFO: Set next wakeup time to $(date -d "$NEXTDAY ${START_AT_DAY[$FUNC_DATE]}")"
			exit 0
		else
			_log "WARN: There was an error setting the wakeup time to $(date -d "$NEXTDAY ${START_AT_DAY[$FUNC_DATE]}")"
			_log "WARN: Please check your start times, rtcwake and rights to set rtcwake. Exit"
			exit 1
		fi
	fi
}

################################################################
#
#   name          : f_check_rtc_date
#   parameter     : $1 = DAYPARAM -> WAKE_UP_DAY -> nr. of the day (monday = 1)
#                 : $2 = TODAYPARAM -> TODAY = true/false
#   global return : none
#   return        : 0
#
# checks, if the wakeup-time is set, then if it is set for 
# today or next day. Then it sets rtcwake
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
		# call function again with next day
		f_check_rtc_date $DAYPARAM
	else
		# if a WAKE_UP time is found
		# set alarm
		f_set_rtcwake_date $DAYPARAM $TODAYPARAM
	fi
}

###############################################################
######## START OF BODY FUNCTION SCRIPT AUTOWAKEUP.SH ########
###############################################################

# if parameter "show" is given by '/etc/init.d/autowakeup status'
# set SHOW_NEXT_WAKEUP -> f_show_alarm
SHOW_NEXT_WAKEUP="$1"

logger -s -t "logger: $(basename "$0" | sed 's/\.sh$//g')[$$]" -p $FACILITY.info "INFO: ' XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'"
logger -s -t "logger: $(basename "$0" | sed 's/\.sh$//g')[$$]" -p $FACILITY.info "INFO: ' X Version: $VERSION' - logging to $FACILITY'"

# define FAKE here, later is it overwritten by user-config
FAKE=false

# Check, if the config is existant
if [ -f "$AUTOWAKEUP_CONF" ]; then
	. "$AUTOWAKEUP_CONF"
	if [ $? = 0 ]; then
		_log "INFO: $AUTOWAKEUP_CONF loaded as config-file"
	fi
else
	_log "WARN: Config '$AUTOWAKEUP_CONF' found!"
	_log "WARN: Exiting!"
fi

# "show" given by '/etc/init.d/autowakeup status'
if [ "$SHOW_NEXT_WAKEUP" = "show" ]; then
	_log "INFO: autowakeup status:"
	f_show_alarm
	exit 0
fi

if [ -f "$SCHEDULE" ]; then
	. "$SCHEDULE"
	_log "INFO: $SCHEDULE loaded as schedule"
else
	_log "WARN: Schedule '$SCHEDULE' found!"
	_log "WARN: Exiting!"
fi

if $FAKE; then DEBUG=true; fi

if $DEBUG ; then
	_log "INFO:------------------------------------------------------"
	_log "DEBUG: ### DEBUG:"
	_log "DEBUG: MONDAY:    ${START_AT_DAY[1]}"
	_log "DEBUG: TUESDAY:   ${START_AT_DAY[2]}"
	_log "DEBUG: WEDNESDAY: ${START_AT_DAY[3]}"
	_log "DEBUG: THURSDAY:  ${START_AT_DAY[4]}"
	_log "DEBUG: FRIDAY:    ${START_AT_DAY[5]}"
	_log "DEBUG: SATURDAY:  ${START_AT_DAY[6]}"
	_log "DEBUG: SUNDAY:    ${START_AT_DAY[7]}"
	_log "DEBUG: SYSLOG:    $SYSLOG"
	_log "DEBUG: FAKE:      $FAKE"
	_log "DEBUG: RTC_SHOW_MODE: $RTC_SHOW_MODE"
fi   # > if $DEBUG ;then

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
			_log "DEBUG: Starttime not correct: $STARTTIMES"
			_log "DEBUG: Exiting"
			exit 1
		fi
	fi
done

if [ $STARTTIME_CNT -eq 0 ]; then
	_log "WARN: There is not one starttime defined."
	_log "WARN: Mon: ${START_AT_DAY[1]} Tue: ${START_AT_DAY[2]} Wed: ${START_AT_DAY[3]} Thu: ${START_AT_DAY[4]}"
	_log "WARN: Fri: ${START_AT_DAY[5]} Sat: ${START_AT_DAY[6]} Sun: ${START_AT_DAY[7]}"
	_log "WARN: Exiting"
	exit 1
fi

ACT_TIME="$(date +%s)"
ACT_DAY="$(date +%u)"
TODAY_START="$(date -d "${START_AT_DAY[$ACT_DAY]}" +%s)"

if [ $ACT_TIME -gt $TODAY_START ]; then
	# start-time is in the past
	# use tomorrow -> actual day +1
	WAKE_UP_DAY=$(date -d tomorrow +%u)
	TODAY=false
else
	WAKE_UP_DAY="${ACT_DAY}"
	TODAY=true
fi

if $DEBUG; then
	_log "DEBUG: ACT_TIME: $ACT_TIME"
	_log "DEBUG: ACT_DAY: $ACT_DAY"
	_log "DEBUG: TODAY_START: $TODAY_START -> this is '$(date -d "${START_AT_DAY[$ACT_DAY]}")'"
	_log "DEBUG: WAKE_UP_DAY: $WAKE_UP_DAY = ${DAYNAME[$WAKE_UP_DAY]}"
	_log "DEBUG: TODAY: $TODAY"
fi

f_check_rtc_date $WAKE_UP_DAY $TODAY

exit 0