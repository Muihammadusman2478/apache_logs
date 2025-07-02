#!/bin/bash

LOG_FILES=../logs/apache_*access.log

# Get top user agents in last 24 hours
echo "Top User Agents:"
awk -v end_time="$(date --date='24 hours ago' '+%d/%b/%Y:%H')" '$4 >= "["end_time' $LOG_FILES | \
awk -F\" '{print $6}' | \
sort | uniq -c | sort -nr | head -n 20 | while read -r count agent; do
    echo "User Agent: $agent"
    echo "Count: $count"

    echo
    echo "Top IPs for this agent:"
    grep -F "$agent" $LOG_FILES | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 20

    echo
    echo "Top URLs for this agent:"
    grep -F "$agent" $LOG_FILES | awk -F\" '{print $2}' | awk '{print $2}' | sort | uniq -c | sort -nr | head -n 20

    echo "-----------------------------"
    echo
done
