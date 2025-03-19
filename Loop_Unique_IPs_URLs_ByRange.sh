#!/bin/bash

# Output file path
output_file="/tmp/output.txt"

# Clear the output file if it exists
> "$output_file"

# Function to append output to file and display on terminal
append_and_display() {
    tee -a "$output_file"
}

# Get the server's public IP
server_ip=$(curl -s ipinfo.io/ip)

# Prompt user for the start date and time
read -p "Enter the start date and time (DD/MM/YYYY:HH:MM): " start_time
read -p "Enter the end date and time (DD/MM/YYYY:HH:MM): " end_time

# Convert date to Apache log format (Unix timestamp)
convert_date() {
    date -d "$(echo "$1" | awk -F'[:/]' '{printf "%04d-%02d-%02d %02d:%02d:00\n", $3, $2, $1, $4, $5}')" +"%s" 2>/dev/null
}

start_epoch=$(convert_date "$start_time")
end_epoch=$(convert_date "$end_time")

# Validate input dates
if [[ -z "$start_epoch" || -z "$end_epoch" ]]; then
    echo "Error: Invalid date format. Use DD/MM/YYYY:HH:MM" | append_and_display
    exit 1
fi

# Function to truncate long strings
truncate_string() {
    local str="$1"
    local max_length="$2"
    if [[ ${#str} -gt $max_length ]]; then
        echo "${str:0:$((max_length-3))}..."
    else
        echo "$str"
    fi
}


# Loop through all applications
for app_name in $(ls -l /home/master/applications/ | grep "^d" | awk '{print $NF}'); do
    # Get the Domain name from the Nginx configuration
    domain_name=$(awk 'NR==1 {print substr($NF, 1, length($NF)-1)}' /home/master/applications/"$app_name"/conf/server.nginx)

    # Print Application Heading
    echo -e "\n\e[1;36m═════════════════════════════════════════════════════════════════════════════\e[0m" | append_and_display
    echo -e "\e[1;35m         Traffic Analysis Report for Application: $app_name (Domain: $domain_name)         \e[0m" | append_and_display
    echo -e "\e[1;35m         Duration: from $start_time to $end_time         \e[0m" | append_and_display
    echo -e "\e[1;36m═════════════════════════════════════════════════════════════════════════════\e[0m\n" | append_and_display

    # Define log files for the application
    log_files="/home/master/applications/$app_name/logs/apache_*access.log*"

    # Function to generate Unique IPs report
    generate_unique_ips_report() {
        echo -e "\n\e[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m" | append_and_display
        echo -e "\e[1;33m📌 Unique IPs Accessed from $start_time to $end_time \e[0m" | append_and_display
        echo -e "\e[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m\n" | append_and_display
        echo -e "\e[1;34m──────────────────────────────────────────────────────────────────────────────────────────\e[0m" | append_and_display
        printf "\e[1;33m| %-10s | %-18s | %-15s | %-35s |\e[0m\n" "IP Count" "IP Address" "Country" "IP Resolves to Domain" | append_and_display
        echo -e "\e[1;34m──────────────────────────────────────────────────────────────────────────────────────────\e[0m" | append_and_display

        # Process logs (Filter requests based on user input)
        zcat -f $log_files | awk -v end_time="$end_time" '$4 >= "["end_time' | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 5 | while read count ip; do
            country=$(curl -s "http://ip-api.com/line/$ip?fields=country")
            domain=$(dig +short -x "$ip" | head -n 1)
            ip_info=""
            [[ "$ip" == "$server_ip" ]] && ip_info=" --> IT IS YOUR SERVER IP"
            # Truncate domain and country if necessary
            domain=$(truncate_string "$domain" 60)
           country=$(truncate_string "$country" 30)
            printf "\e[1;32m| %-10s | %-18s | %-15s | %-35s %s|\e[0m\n" "$count" "$ip" "${country:-Unknown}" "${domain:-N/A}" "$ip_info" | append_and_display
        done

        echo -e "\e[1;34m──────────────────────────────────────────────────────────────────────────────────────────\e[0m" | append_and_display
    }

    # Function to generate Unique URLs report
    generate_unique_urls_report() {
        echo -e "\n\e[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m" | append_and_display
        echo -e "\e[1;33m📌 Unique URLs Accessed from $start_time to $end_time \e[0m" | append_and_display
        echo -e "\e[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m\n" | append_and_display
        echo -e "\e[1;34m──────────────────────────────────────────────────────────────────────────────────────────────────────────\e[0m" | append_and_display
        printf "\e[1;33m| %-10s | %-18s | %-15s | %-35s | %-30s |\e[0m\n" "IP Count" "IP Address" "Country" "IP Resolves to Domain" "URL" | append_and_display
        echo -e "\e[1;34m──────────────────────────────────────────────────────────────────────────────────────────────────────────\e[0m" | append_and_display

        # Process logs (Filter requests based on user input)
        zcat -f $log_files | awk -v end_time="$end_time" '$4 >= "["end_time' | awk '{print $1, $7}' | sort | uniq -c | sort -nr | head -n 5 | while read count ip url; do
            country=$(curl -s "http://ip-api.com/line/$ip?fields=country")
            domain=$(dig +short -x "$ip" | head -n 1)
            ip_info=""
            [[ "$ip" == "$server_ip" ]] && ip_info=" --> IT IS YOUR SERVER IP"
            # Truncate domain, country, and URL if necessary
            domain=$(truncate_string "$domain" 50)
            country=$(truncate_string "$country" 30)
            url=$(truncate_string "$url" 60)
            printf "\e[1;32m| %-10s | %-18s | %-15s | %-35s | %-30s %s|\e[0m\n" "$count" "$ip" "${country:-Unknown}" "${domain:-N/A}" "$url" "$ip_info" | append_and_display
        done

        echo -e "\e[1;34m──────────────────────────────────────────────────────────────────────────────────────────────────────────\e[0m" | append_and_display
    }

    # Generate both reports for the application
    generate_unique_ips_report
    generate_unique_urls_report

    # Final Footer for Application
    echo -e "\e[1;36m═════════════════════════════════════════════════════════════════════════════\e[0m" | append_and_display
    echo -e "\e[1;32m🚀 Traffic Analysis Completed for $app_name (from $start_time to $end_time) 🚀\e[0m" | append_and_display
    echo -e "\e[1;36m═════════════════════════════════════════════════════════════════════════════\e[0m\n" | append_and_display
done

# Create a zip file of the output
zip -j /tmp/output.zip "$output_file"

echo -e "\e[1;32mReport saved to $output_file and zipped to /tmp/output.zip\e[0m"
