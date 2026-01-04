#!/bin/sh

# ============================================
# Cloudflare DDNS for OpenWRT - Multi-Zone + Multi-Interface
# Version: 2.0
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
    # Cloudflare API requires boolean, not string
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
        log_message "DEBUG: JSON sent: $json_data"
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
    
    # Parse config
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
        
        # Use default if not specified
        [ -z "$api_token" ] && api_token="$DEFAULT_API_TOKEN"
        [ -z "$zone_id" ] && zone_id="$DEFAULT_ZONE_ID"
        
        # Only fetch once per zone
        if [ "$zone_id" != "$prev_zone" ]; then
            get_record_id_for_zone "$api_token" "$zone_id" "$domain"
            prev_zone="$zone_id"
            echo ""
        fi
    done
}

show_status() {
    log_message "=== Cloudflare DDNS Status (Multi-Zone + Multi-Interface) ==="
    
    # Parse all config arrays
    local domains=$(echo "$CF_DOMAINS" | tr ',' '\n')
    local interfaces=$(echo "$CF_INTERFACES" | tr ',' '\n')
    local api_tokens=$(echo "$CF_API_TOKENS" | tr ',' '\n')
    local zone_ids=$(echo "$CF_ZONE_IDS" | tr ',' '\n')
    local record_ids=$(echo "$CF_RECORD_IDS" | tr ',' '\n')
    
    local count=0
    echo "$domains" | while read domain; do
        domain=$(echo $domain | xargs)
        [ -z "$domain" ] && continue
        
        count=$((count + 1))
        local interface=$(echo "$interfaces" | sed -n "${count}p" | xargs)
        local api_token=$(echo "$api_tokens" | sed -n "${count}p" | xargs)
        local zone_id=$(echo "$zone_ids" | sed -n "${count}p" | xargs)
        local record_id=$(echo "$record_ids" | sed -n "${count}p" | xargs)
        
        # Use defaults if not specified
        [ -z "$interface" ] && interface="$DEFAULT_INTERFACE"
        [ -z "$api_token" ] && api_token="$DEFAULT_API_TOKEN"
        [ -z "$zone_id" ] && zone_id="$DEFAULT_ZONE_ID"
        
        local device=$(get_device "$interface")
        local current_ip=$(get_public_ip "$interface" "$device")
        
        local cache_file="${CACHE_DIR}/cf_ddns_ip_cache_$(echo $domain | sed 's/[^a-zA-Z0-9]/_/g')"
        
        if [ -f "$cache_file" ]; then
            local cached_ip=$(cat "$cache_file")
            log_message "Domain: $domain | Zone: ${zone_id:0:8}... | Interface: $interface | Device: $device | Current IP: $current_ip | Cached IP: $cached_ip | Record ID: ${record_id:0:8}..."
        else
            log_message "Domain: $domain | Zone: ${zone_id:0:8}... | Interface: $interface | Device: $device | Current IP: $current_ip | No cache | Record ID: ${record_id:0:8}..."
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
        echo ""
        echo "Features:"
        echo "  ✓ Multiple domains across different Cloudflare zones"
        echo "  ✓ Each domain can use different interface (multi-WAN)"
        echo "  ✓ Each domain can have different API token"
        echo "  ✓ Smart caching to avoid unnecessary API calls"
        echo "  ✓ Detailed logging with summary"
        exit 0
        ;;
esac

log_message "=== Starting Cloudflare DDNS Update (Multi-Zone + Multi-Interface) ==="

# Parse all config arrays
domains=$(echo "$CF_DOMAINS" | tr ',' '\n')
interfaces=$(echo "$CF_INTERFACES" | tr ',' '\n')
api_tokens=$(echo "$CF_API_TOKENS" | tr ',' '\n')
zone_ids=$(echo "$CF_ZONE_IDS" | tr ',' '\n')
record_ids=$(echo "$CF_RECORD_IDS" | tr ',' '\n')

count=0
updated=0
skipped=0
failed=0

echo "$domains" | while read domain; do
    domain=$(echo $domain | xargs)
    [ -z "$domain" ] && continue
    
    count=$((count + 1))
    interface=$(echo "$interfaces" | sed -n "${count}p" | xargs)
    api_token=$(echo "$api_tokens" | sed -n "${count}p" | xargs)
    zone_id=$(echo "$zone_ids" | sed -n "${count}p" | xargs)
    record_id=$(echo "$record_ids" | sed -n "${count}p" | xargs)
    
    # Use defaults if not specified
    [ -z "$interface" ] && interface="$DEFAULT_INTERFACE"
    [ -z "$api_token" ] && api_token="$DEFAULT_API_TOKEN"
    [ -z "$zone_id" ] && zone_id="$DEFAULT_ZONE_ID"
    
    # Validate required fields
    if [ -z "$api_token" ] || [ -z "$zone_id" ] || [ -z "$record_id" ]; then
        log_message "ERROR: Missing configuration for $domain (API Token/Zone ID/Record ID)"
        failed=$((failed + 1))
        continue
    fi
    
    # Get device for this interface
    device=$(get_device "$interface")
    if [ -z "$device" ]; then
        log_message "ERROR: Cannot detect device for interface '$interface' (domain: $domain)"
        failed=$((failed + 1))
        continue
    fi
    
    # Get current IP from this interface
    current_ip=$(get_public_ip "$interface" "$device")
    
    if [ -z "$current_ip" ]; then
        log_message "ERROR: Cannot get public IP from interface '$interface' (domain: $domain)"
        failed=$((failed + 1))
        continue
    fi
    
    log_message "Domain: $domain | Zone: ${zone_id:0:8}... | Interface: $interface | Device: $device | IP: $current_ip"
    
    cache_file="${CACHE_DIR}/cf_ddns_ip_cache_$(echo $domain | sed 's/[^a-zA-Z0-9]/_/g')"
    
    # Check if update needed
    if [ -f "$cache_file" ] && [ "$FORCE_UPDATE" -eq 0 ]; then
        cached_ip=$(cat "$cache_file")
        
        if [ "$cached_ip" = "$current_ip" ]; then
            log_message "SKIP: $domain - IP unchanged ($current_ip)"
            skipped=$((skipped + 1))
            continue
        fi
    fi
    
    # Update DNS
    log_message "UPDATE: $domain - IP: $current_ip (from $interface)"
    
    if update_dns_record "$api_token" "$zone_id" "$record_id" "$domain" "$current_ip" "${CF_PROXIED:-false}" "${CF_TTL:-120}"; then
        echo "$current_ip" > "$cache_file"
        log_message "SUCCESS: $domain updated to $current_ip"
        updated=$((updated + 1))
    else
        log_message "FAILED: $domain update failed"
        failed=$((failed + 1))
    fi
done

log_message "=== Summary: Updated=$updated, Skipped=$skipped, Failed=$failed ==="