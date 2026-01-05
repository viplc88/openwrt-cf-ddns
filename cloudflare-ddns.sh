#!/bin/sh

# ============================================
# Cloudflare DDNS for OpenWRT - Multi-Zone + Multi-Interface
# Version: 2.0 FIXED
# ============================================

CONFIG_FILE="/etc/cloudflare-ddns/cloudflare-ddns.conf"
LOG_FILE="/tmp/cf_ddns.log"
CACHE_DIR="/tmp"

# Load config
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

. "$CONFIG_FILE"

# Functions
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_device() {
    local interface=$1
    local device=$(ubus call network.interface."$interface" status 2>/dev/null | jsonfilter -e '@.l3_device')
    
    if [ -z "$device" ]; then
        device=$(ubus call network.interface."$interface" status 2>/dev/null | jsonfilter -e '@.device')
    fi
    
    echo "$device"
}

get_public_ip() {
    local interface=$1
    local device=$2
    
    if [ -n "$device" ]; then
        curl --silent --interface "$device" --max-time 10 https://api.ipify.org 2>/dev/null || \
        curl --silent --interface "$device" --max-time 10 https://icanhazip.com 2>/dev/null
    else
        curl --silent --max-time 10 https://api.ipify.org 2>/dev/null || \
        curl --silent --max-time 10 https://icanhazip.com 2>/dev/null
    fi
}

update_dns_record() {
    local api_token=$1
    local zone_id=$2
    local record_id=$3
    local record_name=$4
    local new_ip=$5
    local proxied=${6:-false}
    local ttl=${7:-120}
    
    # Convert string "true"/"false" to JSON boolean
    local proxied_json
    if [ "$proxied" = "true" ]; then
        proxied_json="true"
    else
        proxied_json="false"
    fi
    
    # Ensure TTL is a number (remove any non-numeric characters)
    ttl=$(echo "$ttl" | tr -cd '0-9')
    [ -z "$ttl" ] && ttl="120"
    
    # Build JSON payload
    local json_data="{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$new_ip\",\"ttl\":$ttl,\"proxied\":$proxied_json}"
    
    log_message "DEBUG: JSON sent: $json_data"
    
    local response=$(curl --silent --request PATCH \
        --url "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
        --header "Authorization: Bearer $api_token" \
        --header "Content-Type: application/json" \
        --data "$json_data")
    
    local success=$(echo "$response" | jsonfilter -e '@.success')
    
    if [ "$success" = "true" ]; then
        return 0
    else
        local errors=$(echo "$response" | jsonfilter -e '@.errors')
        log_message "ERROR: Failed to update $record_name: $errors"
        return 1
    fi
}

get_record_id_for_zone() {
    local api_token=$1
    local zone_id=$2
    local zone_name=$3
    
    log_message "Fetching DNS records for Zone: $zone_name (ID: $zone_id)"
    
    local response=$(curl --silent --request GET \
        --url "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A" \
        --header "Authorization: Bearer $api_token")
    
    echo "$response" | jsonfilter -e '@.result[@].name' | while read name; do
        local id=$(echo "$response" | jsonfilter -e "@.result[@.name='$name'].id")
        local ip=$(echo "$response" | jsonfilter -e "@.result[@.name='$name'].content")
        echo "  Record: $name | ID: $id | IP: $ip"
    done
}

show_all_records() {
    log_message "=== Fetching all DNS records from Cloudflare ==="
    
    local api_tokens=$(echo "$CF_API_TOKENS" | tr ',' '\n')
    local zone_ids=$(echo "$CF_ZONE_IDS" | tr ',' '\n')
    local domains=$(echo "$CF_DOMAINS" | tr ',' '\n')
    
    local count=0
    local prev_zone=""
    
    echo "$domains" | while read domain; do
        domain=$(echo $domain | xargs)
        [ -z "$domain" ] && continue
        
        count=$((count + 1))
        local api_token=$(echo "$api_tokens" | sed -n "${count}p" | xargs)
        local zone_id=$(echo "$zone_ids" | sed -n "${count}p" | xargs)
        
        [ -z "$api_token" ] && api_token="$DEFAULT_API_TOKEN"
        [ -z "$zone_id" ] && zone_id="$DEFAULT_ZONE_ID"
        
        if [ "$zone_id" != "$prev_zone" ]; then
            get_record_id_for_zone "$api_token" "$zone_id" "$domain"
            prev_zone="$zone_id"
            echo ""
        fi
    done
}

show_status() {
    log_message "=== Cloudflare DDNS Status (Multi-Zone + Multi-Interface) ==="
    
    local domains=$(echo "$CF_DOMAINS" | tr ',' '\n')
    local interfaces=$(echo "$CF_INTERFACES" | tr ',' '\n')
    local api_tokens=$(echo "$CF_API_TOKENS" | tr ',' '\n')
    local zone_ids=$(echo "$CF_ZONE_IDS" | tr ',' '\n')
    local record_ids=$(echo "$CF_RECORD_IDS" | tr ',' '\n')
    local proxied_list=$(echo "$CF_PROXIED" | tr ',' '\n')
    local ttl_list=$(echo "$CF_TTL" | tr ',' '\n')
    
    local count=0
    echo "$domains" | while read domain; do
        domain=$(echo $domain | xargs)
        [ -z "$domain" ] && continue
        
        count=$((count + 1))
        local interface=$(echo "$interfaces" | sed -n "${count}p" | xargs)
        local api_token=$(echo "$api_tokens" | sed -n "${count}p" | xargs)
        local zone_id=$(echo "$zone_ids" | sed -n "${count}p" | xargs)
        local record_id=$(echo "$record_ids" | sed -n "${count}p" | xargs)
        local proxied=$(echo "$proxied_list" | sed -n "${count}p" | xargs)
        local ttl=$(echo "$ttl_list" | sed -n "${count}p" | xargs)
        
        [ -z "$interface" ] && interface="$DEFAULT_INTERFACE"
        [ -z "$api_token" ] && api_token="$DEFAULT_API_TOKEN"
        [ -z "$zone_id" ] && zone_id="$DEFAULT_ZONE_ID"
        [ -z "$proxied" ] && proxied="$DEFAULT_PROXIED"
        [ -z "$ttl" ] && ttl="$DEFAULT_TTL"
        
        local device=$(get_device "$interface")
        local current_ip=$(get_public_ip "$interface" "$device")
        
        local cache_file="${CACHE_DIR}/cf_ddns_ip_cache_$(echo $domain | sed 's/[^a-zA-Z0-9]/_/g')"
        
        if [ -f "$cache_file" ]; then
            local cached_ip=$(cat "$cache_file")
            log_message "Domain: $domain | Zone: ${zone_id:0:8}... | Interface: $interface | Device: $device | IP: $current_ip (cached) | Proxied: $proxied | TTL: $ttl | Record: ${record_id:0:8}..."
        else
            log_message "Domain: $domain | Zone: ${zone_id:0:8}... | Interface: $interface | Device: $device | IP: $current_ip (no cache) | Proxied: $proxied | TTL: $ttl | Record: ${record_id:0:8}..."
        fi
    done
}

# Main execution
FORCE_UPDATE=0

case "$1" in
    --force)
        FORCE_UPDATE=1
        ;;
    --status)
        show_status
        exit 0
        ;;
    --get-record-id)
        show_all_records
        exit 0
        ;;
    --help|-h)
        echo "Cloudflare DDNS - Multi-Zone + Multi-Interface"
        echo ""
        echo "Usage: cloudflare-ddns [options]"
        echo ""
        echo "Options:"
        echo "  --force           Force update all DNS records"
        echo "  --status          Show current status"
        echo "  --get-record-id   Get all A records and their IDs for all zones"
        echo "  --help, -h        Show this help"
        exit 0
        ;;
esac

log_message "=== Starting Cloudflare DDNS Update (Multi-Zone + Multi-Interface) ==="

# Parse config arrays once
domains_array=$(echo "$CF_DOMAINS" | tr ',' '\n')
interfaces_array=$(echo "$CF_INTERFACES" | tr ',' '\n')
api_tokens_array=$(echo "$CF_API_TOKENS" | tr ',' '\n')
zone_ids_array=$(echo "$CF_ZONE_IDS" | tr ',' '\n')
record_ids_array=$(echo "$CF_RECORD_IDS" | tr ',' '\n')
proxied_array=$(echo "$CF_PROXIED" | tr ',' '\n')
ttl_array=$(echo "$CF_TTL" | tr ',' '\n')

updated=0
skipped=0
failed=0
count=0

# Process each domain
while IFS= read -r domain; do
    domain=$(echo "$domain" | xargs)
    [ -z "$domain" ] && continue
    
    count=$((count + 1))
    
    # Get values for this domain
    interface=$(echo "$interfaces_array" | sed -n "${count}p" | xargs)
    api_token=$(echo "$api_tokens_array" | sed -n "${count}p" | xargs)
    zone_id=$(echo "$zone_ids_array" | sed -n "${count}p" | xargs)
    record_id=$(echo "$record_ids_array" | sed -n "${count}p" | xargs)
    proxied=$(echo "$proxied_array" | sed -n "${count}p" | xargs)
    ttl=$(echo "$ttl_array" | sed -n "${count}p" | xargs)
    
    # Use defaults if empty
    [ -z "$interface" ] && interface="$DEFAULT_INTERFACE"
    [ -z "$api_token" ] && api_token="$DEFAULT_API_TOKEN"
    [ -z "$zone_id" ] && zone_id="$DEFAULT_ZONE_ID"
    [ -z "$proxied" ] && proxied="$DEFAULT_PROXIED"
    [ -z "$ttl" ] && ttl="$DEFAULT_TTL"
    
    log_message "DEBUG: Parsed - Domain #$count: $domain, Proxied=[$proxied], TTL=[$ttl]"
    
    # Validate required fields
    if [ -z "$api_token" ] || [ -z "$zone_id" ] || [ -z "$record_id" ]; then
        log_message "ERROR: Missing configuration for $domain"
        failed=$((failed + 1))
        continue
    fi
    
    # Get device
    device=$(get_device "$interface")
    if [ -z "$device" ]; then
        log_message "ERROR: Cannot detect device for interface '$interface' (domain: $domain)"
        failed=$((failed + 1))
        continue
    fi
    
    # Get current IP
    current_ip=$(get_public_ip "$interface" "$device")
    if [ -z "$current_ip" ]; then
        log_message "ERROR: Cannot get public IP from interface '$interface' (domain: $domain)"
        failed=$((failed + 1))
        continue
    fi
    
    log_message "Domain: $domain | Zone: ${zone_id:0:8}... | Interface: $interface | Device: $device | IP: $current_ip | Proxied: $proxied | TTL: $ttl"
    
    # Check cache
    cache_file="${CACHE_DIR}/cf_ddns_ip_cache_$(echo $domain | sed 's/[^a-zA-Z0-9]/_/g')"
    
    if [ -f "$cache_file" ] && [ "$FORCE_UPDATE" -eq 0 ]; then
        cached_ip=$(cat "$cache_file")
        
        if [ "$cached_ip" = "$current_ip" ]; then
            log_message "SKIP: $domain - IP unchanged ($current_ip)"
            skipped=$((skipped + 1))
            continue
        fi
    fi
    
    # Update DNS
    log_message "UPDATE: $domain - IP: $current_ip (from $interface, proxied: $proxied, ttl: $ttl)"
    
    if update_dns_record "$api_token" "$zone_id" "$record_id" "$domain" "$current_ip" "$proxied" "$ttl"; then
        echo "$current_ip" > "$cache_file"
        log_message "SUCCESS: $domain updated to $current_ip"
        updated=$((updated + 1))
    else
        log_message "FAILED: $domain update failed"
        failed=$((failed + 1))
    fi
    
done << EOF
$domains_array
EOF

log_message "=== Summary: Updated=$updated, Skipped=$skipped, Failed=$failed ==="
