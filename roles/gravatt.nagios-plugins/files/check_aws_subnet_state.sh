#!/bin/bash -e

SUBNET_ID=$1

if [ -z "$SUBNET_ID" ]
  then
    echo "usage:  $0 <subnet id>"
    exit 99
fi

STATE=`aws ec2 describe-subnets --subnet-ids $SUBNET_ID | jq -r '.Subnets[0].State'`

if [[ $? -eq 0 ]]; then
		
	if [[ ${STATE} == "available" ]]; then
		NAGIOS_STATE=OK
		EXIT_CODE=0
	else
		NAGIOS_STATE=CRITICAL
		EXIT_CODE=2
	fi
	echo "${NAGIOS_STATE}: ${STATE}"
else
	echo "Failed to retrieve subnet state"
	EXIT_CODE=99
fi

exit ${EXIT_CODE}
