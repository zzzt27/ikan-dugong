#!/bin/sh

#================================================================
# OpenClash Advanced Debug Script for OpenWrt
#
# This script automates the process of collecting critical
# debug logs for OpenClash. It handles API authentication,
# captures the crucial initial logs right after a restart,
# runs the standard OpenClash debug utility, and packages
# everything into a single archive for easy analysis.
#================================================================

# --- Configuration ---
# API URL for fetching logs
API_URL="http://127.0.0.1:9090/logs?level=debug"
# Log file for the complete, unfiltered API output
FULL_API_LOG_FILE="/tmp/openclash_full_api.log"
# Log file for only the DEBUG messages from the API
DEBUG_API_LOG_FILE="/tmp/openclash_debug_api.log"
# Standard OpenClash debug script output
SYSTEM_DEBUG_LOG_FILE="/tmp/openclash_debug.log"
# Final compressed log package
OUTPUT_ARCHIVE="/tmp/openclash_debug_package_$(date +%Y%m%d_%H%M%S).tar.gz"
# How long to wait for OpenClash to restart (seconds)
RESTART_WAIT_TIMEOUT=30
# How long to capture the initial API logs (seconds)
LOG_CAPTURE_DURATION=20

# --- Helper Functions ---
# Prints a formatted message
log_info() {
    echo "INFO: $1"
}

log_error() {
    echo "ERROR: $1" >&2
}

# --- Main Script ---

# 1. Ask for the API secret (token)
echo "========================================================="
echo "        OpenClash Advanced Debug Log Collector"
echo "========================================================="
printf "Please enter your OpenClash API secret (leave empty if none), and press Enter: "
read -r SECRET

# 2. Test the secret/token. Only proceed if successful.
log_info "Testing API connectivity and authentication..."
# Create a temporary file to store the response body for checking
AUTH_TEST_OUTPUT=$(mktemp)
if [ -n "$SECRET" ]; then
    # If a secret is provided, use it in the header
    AUTH_HEADER="Authorization: Bearer $SECRET"
    HTTP_STATUS=$(curl --silent --output "$AUTH_TEST_OUTPUT" --write-out "%{http_code}" --max-time 5 -H "$AUTH_HEADER" "$API_URL")
else
    # If no secret, try without authentication
    HTTP_STATUS=$(curl --silent --output "$AUTH_TEST_OUTPUT" --write-out "%{http_code}" --max-time 5 "$API_URL")
fi

# Check for the "Unauthorized" message in the response body
UNAUTHORIZED_MSG=$(grep -c '{"message":"Unauthorized"}' "$AUTH_TEST_OUTPUT")
# Clean up the temporary file immediately
rm -f "$AUTH_TEST_OUTPUT"

# First, check for explicit authentication failure.
if [ "$HTTP_STATUS" -eq 401 ] || [ "$UNAUTHORIZED_MSG" -gt 0 ]; then
    log_error "Authentication failed. The secret you provided is incorrect."
    exit 1
fi

# Next, check for any other connection issue.
if [ "$HTTP_STATUS" -ne 200 ]; then
    log_error "Could not connect to OpenClash API (HTTP Status: $HTTP_STATUS)."
    log_error "Please ensure OpenClash is running and the API is accessible before running this script."
    exit 1
fi

# If we reach here, the connection was successful.
log_info "API connection and authentication successful."


# 3. Restart OpenClash to ensure a clean slate for logging
log_info "Restarting OpenClash service..."
/etc/init.d/openclash restart

# Give OpenClash a few seconds to initialize before we start polling the API
log_info "Waiting 5 seconds for OpenClash to initialize..."
sleep 5

log_info "Starting log capture process. This will wait for the API to come online..."
log_info "(This may take up to $RESTART_WAIT_TIMEOUT seconds)"

# This loop attempts to connect to the API. It will fail until the service is back up.
start_time=$(date +%s)
while true; do
    # Check if the timeout has been reached
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ "$elapsed_time" -ge "$RESTART_WAIT_TIMEOUT" ]; then
        log_error "OpenClash API did not become available after $RESTART_WAIT_TIMEOUT seconds."
        log_error "Skipping initial API log capture."
        touch "$FULL_API_LOG_FILE" # Create an empty file to avoid errors later
        break
    fi

    # Check for HTTP 200 status code. This is the reliable way to know the service is up.
    if [ -n "$SECRET" ]; then
        POLL_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" --max-time 2 -H "$AUTH_HEADER" "$API_URL")
    else
        POLL_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" --max-time 2 "$API_URL")
    fi

    # Check if the HTTP status is 200 (OK)
    if [ "$POLL_STATUS" -eq 200 ]; then
        log_info "API is online! Capturing initial logs for $LOG_CAPTURE_DURATION seconds..."
        # API is up, start streaming logs for the specified duration and save the JSON response
        if [ -n "$SECRET" ]; then
            curl --silent -H "$AUTH_HEADER" --max-time "$LOG_CAPTURE_DURATION" "$API_URL" > "$FULL_API_LOG_FILE" &
        else
            curl --silent --max-time "$LOG_CAPTURE_DURATION" "$API_URL" > "$FULL_API_LOG_FILE" &
        fi
        # Wait for the capture to finish in the background
        wait $!
        log_info "Initial API log capture complete. Saved to $FULL_API_LOG_FILE"
        break
    else
        log_info "API not ready yet (Status: $POLL_STATUS). Retrying in 1 second..."
    fi
    sleep 1 # Wait 1 second before retrying
done

# 4. Process the full API log to create the filtered debug log
log_info "Filtering API logs..."
if [ -s "$FULL_API_LOG_FILE" ]; then # -s checks if file exists and is not empty
    grep '{"type":"debug"' "$FULL_API_LOG_FILE" > "$DEBUG_API_LOG_FILE"
    log_info "Created filtered debug API log."
else
    log_error "Full API log file is empty or not found. Cannot create filtered log."
    # Create an empty file to prevent the tar command from failing
    touch "$DEBUG_API_LOG_FILE"
fi

# 5. Run the standard OpenClash debug script
log_info "Running the standard OpenClash debug script..."
# Ensure the log file is clean before running
rm -f "$SYSTEM_DEBUG_LOG_FILE"
/usr/share/openclash/openclash_debug.sh

# Check if the debug log was created
if [ ! -f "$SYSTEM_DEBUG_LOG_FILE" ]; then
    log_error "The OpenClash debug script did not create the expected log file at $SYSTEM_DEBUG_LOG_FILE."
    log_error "Please check if the script /usr/share/openclash/openclash_debug.sh exists and is executable."
else
    log_info "Standard debug log created at $SYSTEM_DEBUG_LOG_FILE"
fi


# 6. Package all three logs into a single archive
log_info "Packaging logs into a compressed archive..."
if [ -f "$FULL_API_LOG_FILE" ] && [ -f "$DEBUG_API_LOG_FILE" ] && [ -f "$SYSTEM_DEBUG_LOG_FILE" ]; then
    tar -czvf "$OUTPUT_ARCHIVE" -C /tmp/ "$(basename "$FULL_API_LOG_FILE")" "$(basename "$DEBUG_API_LOG_FILE")" "$(basename "$SYSTEM_DEBUG_LOG_FILE")"
    if [ $? -eq 0 ]; then
        log_info "Successfully created debug package!"
        echo "========================================================="
        echo "  Debug package is ready!"
        echo "  You can download it from: $OUTPUT_ARCHIVE"
        echo "  Use SCP or a tool like WinSCP to get the file."
        echo "========================================================="
    else
        log_error "Failed to create the archive."
    fi
else
    log_error "One or more log files were not found. Cannot create archive."
fi

# 7. Cleanup temporary files
log_info "Cleaning up temporary files..."
rm -f "$FULL_API_LOG_FILE" "$DEBUG_API_LOG_FILE" "$SYSTEM_DEBUG_LOG_FILE"

log_info "Script finished."

