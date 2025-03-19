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

# Ask the user for the time range (e.g., "2" for logs from 2 hours ago)
read -p "Enter the number of hours ago to filter logs from: " hours_ago

# Validate input (ensure it's a positive integer)
if ! [[ "$hours_ago" =~ ^[0-9]+$ ]]; then
    echo "Invalid input. Please enter a valid number of hours." | append_and_display
    exit 1
fi

# Define the time filter based on user input
end_time=$(date --date="$hours_ago hours ago" '+%d/%b/%Y:%H')

# Function to generate Unique IPs report
generate_unique_ips_report() {
    # Print the big heading
    echo -e "\n\e[1;36m════════════════════════════════════════════════════════════════════════════════════════\e[0m" | append_and_display
    echo -e "\e[1;35m          Unique IPs Accessed in the Last $hours_ago Hour(s)          \e[0m" | append_and_display
    echo -e "\e[1;36m════════════════════════════════════════════════════════════════════════════════════════\e[0m" | append_and_display

    # Print table header
    echo -e "\e[1;34m──────────────────────────────────────────────────────────────────────────────────────────\e[0m" | append_and_display
    printf "\e[1;33m| %-10s | %-18s | %-15s | %-35s |\e[0m\n" "IP Count" "IP Address" "Country" "IP Resolves to Domain" | append_and_display
    echo -e "\e[1;34m──────────────────────────────────────────────────────────────────────────────────────────\e[0m" | append_and_display

    # Process logs (Filter requests based on user input)
    cat ../logs/apache_*access.log | awk -v end_time="$end_time" '$4 >= "["end_time' | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 20 | while read count ip; do
        country=$(curl -s "http://ip-api.com/line/$ip?fields=country")
        domain=$(dig +short -x "$ip" | head -n 1)
        
        # Check if the IP is the server's IP
        if [[ "$ip" == "$server_ip" ]]; then
            ip_info="        -->  IT IS YOUR SERVER IP"
        else
            ip_info=""
        fi
        
        # Print each row in a properly aligned format
        printf "\e[1;32m| %-10s | %-18s | %-15s | %-35s %s|\e[0m\n" "$count" "$ip" "${country:-Unknown}" "${domain:-N/A}" "$ip_info" | append_and_display
    done

    # Print footer
    echo -e "\e[1;34m──────────────────────────────────────────────────────────────────────────────────────────\e[0m" | append_and_display
}

# Function to generate Unique URLs report
generate_unique_urls_report() {
    # Print the big heading
    echo -e "\n\e[1;36m════════════════════════════════════════════════════════════════════════════════════════\e[0m" | append_and_display
    echo -e "\e[1;35m          Unique URLs Accessed in the Last $hours_ago Hour(s)          \e[0m" | append_and_display
    echo -e "\e[1;36m════════════════════════════════════════════════════════════════════════════════════════\e[0m" | append_and_display

    # Print table header
    echo -e "\e[1;34m──────────────────────────────────────────────────────────────────────────────────────────────────────────\e[0m" | append_and_display
    printf "\e[1;33m| %-10s | %-18s | %-15s | %-35s | %-30s |\e[0m\n" "IP Count" "IP Address" "Country" "IP Resolves to Domain" "URL" | append_and_display
    echo -e "\e[1;34m──────────────────────────────────────────────────────────────────────────────────────────────────────────\e[0m" | append_and_display

    # Process logs (Filter requests based on user input)
    cat ../logs/apache_*access.log | awk -v end_time="$end_time" '$4 >= "["end_time' | awk '{print $1, $7}' | sort | uniq -c | sort -nr | head -n 20 | while read count ip url; do
        country=$(curl -s "http://ip-api.com/line/$ip?fields=country")
        domain=$(dig +short -x "$ip" | head -n 1)
        
        # Check if the IP is the server's IP
        if [[ "$ip" == "$server_ip" ]]; then
            ip_info="        -->  IT IS YOUR SERVER IP"
        else
            ip_info=""
        fi
        
        # Print each row in a properly aligned format
        printf "\e[1;32m| %-10s | %-18s | %-15s | %-35s | %-30s %s|\e[0m\n" "$count" "$ip" "${country:-Unknown}" "${domain:-N/A}" "$url" "$ip_info" | append_and_display
    done

    # Print footer
    echo -e "\e[1;34m──────────────────────────────────────────────────────────────────────────────────────────────────────────\e[0m" | append_and_display
}

# Generate both reports
generate_unique_ips_report
generate_unique_urls_report

# Create a zip file of the output
zip -j /tmp/output.zip "$output_file"

echo -e "\e[1;32mReport saved to $output_file and zipped to /tmp/output.zip\e[0m"
