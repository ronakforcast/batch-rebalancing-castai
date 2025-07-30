#!/bin/bash

# Configuration
BASE_URL="${CAST_AI_BASE_URL:-https://api.cast.ai/v1}"
DEFAULT_BATCH_SIZE="${CAST_AI_BATCH_SIZE:-3}"
DEFAULT_MIN_NODES="${CAST_AI_MIN_NODES:-3}"
TIMEOUT_MINUTES="${CAST_AI_TIMEOUT_MINUTES:-60}"
POLL_INTERVAL="${CAST_AI_POLL_INTERVAL:-30}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --cluster-name <name>     Name of the Cast AI cluster"
    echo "  -i, --cluster-id <id>         Direct cluster ID (overrides cluster name lookup)"
    echo "  -z, --zone <zone>             Availability zone to rebalance"
    echo "  -b, --batch-size <size>       Number of nodes per batch (default: $DEFAULT_BATCH_SIZE)"
    echo "  -m, --min-nodes <count>       Minimum nodes to maintain (default: $DEFAULT_MIN_NODES)"
    echo "  -k, --api-key <key>           Cast AI API key"
    echo "  -t, --timeout <minutes>       Timeout in minutes (default: $TIMEOUT_MINUTES)"
    echo "  -p, --poll-interval <seconds> Polling interval in seconds (default: $POLL_INTERVAL)"
    echo "  -u, --base-url <url>          Cast AI API base URL (default: $BASE_URL)"
    echo "  -d, --dry-run                 Show what would be done without executing"
    echo "  -v, --verbose                 Enable verbose logging"
    echo "  -h, --help                    Show this help message"
    echo ""
    echo "Environment Variables (can be used instead of CLI options):"
    echo "  CAST_AI_API_KEY               API key for Cast AI"
    echo "  CAST_AI_CLUSTER_NAME          Cluster name"
    echo "  CAST_AI_CLUSTER_ID            Direct cluster ID"
    echo "  CAST_AI_ZONE                  Availability zone"
    echo "  CAST_AI_BATCH_SIZE            Batch size"
    echo "  CAST_AI_MIN_NODES             Minimum nodes"
    echo "  CAST_AI_TIMEOUT_MINUTES       Timeout in minutes"
    echo "  CAST_AI_POLL_INTERVAL         Poll interval in seconds"
    echo "  CAST_AI_BASE_URL              API base URL"
    echo "  CAST_AI_DRY_RUN               Set to 'true' for dry run"
    echo "  CAST_AI_VERBOSE               Set to 'true' for verbose logging"
    echo ""
    echo "Examples:"
    echo "  # Using cluster name"
    echo "  $0 --cluster-name my-cluster --zone us-east-1a --batch-size 5"
    echo ""
    echo "  # Using cluster ID directly"
    echo "  $0 --cluster-id abc123-def456 --zone us-east-1a"
    echo ""
    echo "  # Using environment variables"
    echo "  export CAST_AI_CLUSTER_NAME=my-cluster"
    echo "  export CAST_AI_ZONE=us-east-1a"
    echo "  export CAST_AI_API_KEY=your-api-key"
    echo "  $0"
    echo ""
    echo "  # CI/CD Example"
    echo "  CAST_AI_API_KEY=\$API_KEY CAST_AI_CLUSTER_ID=\$CLUSTER_ID CAST_AI_ZONE=\$ZONE $0"
    exit 1
}

# Initialize variables from environment
CLUSTER_NAME="${CAST_AI_CLUSTER_NAME:-}"
CLUSTER_ID="${CAST_AI_CLUSTER_ID:-}"
ZONE="${CAST_AI_ZONE:-}"
BATCH_SIZE="${CAST_AI_BATCH_SIZE:-$DEFAULT_BATCH_SIZE}"
MIN_NODES="${CAST_AI_MIN_NODES:-$DEFAULT_MIN_NODES}"
API_KEY="${CAST_AI_API_KEY:-}"
TIMEOUT_MINUTES="${CAST_AI_TIMEOUT_MINUTES:-$TIMEOUT_MINUTES}"
POLL_INTERVAL="${CAST_AI_POLL_INTERVAL:-$POLL_INTERVAL}"
DRY_RUN="${CAST_AI_DRY_RUN:-false}"
VERBOSE="${CAST_AI_VERBOSE:-false}"

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            -i|--cluster-id)
                CLUSTER_ID="$2"
                shift 2
                ;;
            -z|--zone)
                ZONE="$2"
                shift 2
                ;;
            -b|--batch-size)
                BATCH_SIZE="$2"
                shift 2
                ;;
            -m|--min-nodes)
                MIN_NODES="$2"
                shift 2
                ;;
            -k|--api-key)
                API_KEY="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT_MINUTES="$2"
                shift 2
                ;;
            -p|--poll-interval)
                POLL_INTERVAL="$2"
                shift 2
                ;;
            -u|--base-url)
                BASE_URL="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Verbose logging function
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "[VERBOSE] $1"
    fi
}

# Validate dependencies
check_dependencies() {
    local deps=("curl" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required dependency '$dep' is not installed"
            exit 1
        fi
    done
    log_verbose "All dependencies are available"
}

# Get API Key if not provided
get_api_key() {
    if [[ -z "$API_KEY" ]]; then
        while true; do
            read -s -p "Enter your Cast AI X-API-Key: " API_KEY
            echo
            if [[ -z "$API_KEY" ]]; then
                log_error "API Key cannot be empty"
                continue
            fi
            if [[ ${#API_KEY} -lt 10 ]]; then
                log_error "API Key seems too short"
                continue
            fi
            break
        done
    fi
    log_verbose "API key is set (length: ${#API_KEY})"
}

# Validate input parameters
validate_params() {
    # Check required parameters
    if [[ -z "$ZONE" ]]; then
        log_error "Zone is required. Use --zone or set CAST_AI_ZONE environment variable"
        usage
    fi

    if [[ -z "$CLUSTER_ID" && -z "$CLUSTER_NAME" ]]; then
        log_error "Either cluster ID or cluster name is required"
        usage
    fi

    # Validate numeric parameters
    if ! [[ "$BATCH_SIZE" =~ ^[0-9]+$ ]] || [[ "$BATCH_SIZE" -lt 1 ]]; then
        log_error "Batch size must be a positive integer"
        exit 1
    fi

    if ! [[ "$MIN_NODES" =~ ^[0-9]+$ ]] || [[ "$MIN_NODES" -lt 1 ]]; then
        log_error "Min nodes must be a positive integer"
        exit 1
    fi

    if ! [[ "$TIMEOUT_MINUTES" =~ ^[0-9]+$ ]] || [[ "$TIMEOUT_MINUTES" -lt 1 ]]; then
        log_error "Timeout must be a positive integer"
        exit 1
    fi

    if ! [[ "$POLL_INTERVAL" =~ ^[0-9]+$ ]] || [[ "$POLL_INTERVAL" -lt 1 ]]; then
        log_error "Poll interval must be a positive integer"
        exit 1
    fi

    log_info "Configuration:"
    log_info "  Base URL: $BASE_URL"
    log_info "  Cluster Name: ${CLUSTER_NAME:-'N/A'}"
    log_info "  Cluster ID: ${CLUSTER_ID:-'Will be resolved'}"
    log_info "  Zone: $ZONE"
    log_info "  Batch Size: $BATCH_SIZE"
    log_info "  Min Nodes: $MIN_NODES"
    log_info "  Timeout: $TIMEOUT_MINUTES minutes"
    log_info "  Poll Interval: $POLL_INTERVAL seconds"
    log_info "  Dry Run: $DRY_RUN"
}

# Make API call with error handling
api_call() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local max_retries=3
    local retry_count=0

    log_verbose "API Call: $method $BASE_URL$endpoint"

    while [[ $retry_count -lt $max_retries ]]; do
        if [[ "$method" == "GET" ]]; then
            response=$(curl -s -w "%{http_code}" --request GET \
                --url "$BASE_URL$endpoint" \
                --header "X-API-Key: $API_KEY" \
                --header "accept: application/json")
        else
            response=$(curl -s -w "%{http_code}" --request POST \
                --url "$BASE_URL$endpoint" \
                --header "X-API-Key: $API_KEY" \
                --header "accept: application/json" \
                --header "content-type: application/json" \
                --data "$data")
        fi

        http_code="${response: -3}"
        response_body="${response%???}"

        log_verbose "HTTP Response Code: $http_code"

        if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
            echo "$response_body"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_warning "API call failed (HTTP $http_code), retry $retry_count/$max_retries"
            if [[ $retry_count -lt $max_retries ]]; then
                sleep $((retry_count * 2))
            fi
        fi
    done

    log_error "API call failed after $max_retries retries (HTTP $http_code)"
    log_error "Response: $response_body"
    return 1
}

# Get cluster ID from cluster name (if not provided directly)
get_cluster_id() {
    if [[ -n "$CLUSTER_ID" ]]; then
        log_info "Using provided cluster ID: $CLUSTER_ID"
        return 0
    fi

    log_info "Fetching cluster list to find cluster ID for: $CLUSTER_NAME"
    
    local response
    if ! response=$(api_call "GET" "/kubernetes/external-clusters"); then
        log_error "Failed to fetch cluster list"
        exit 1
    fi

    CLUSTER_ID=$(echo "$response" | jq -r --arg clusterName "$CLUSTER_NAME" '.items[] | select(.name == $clusterName) | .id')

    if [[ -z "$CLUSTER_ID" || "$CLUSTER_ID" == "null" ]]; then
        log_error "Cluster not found with name: $CLUSTER_NAME"
        exit 1
    fi

    log_success "Found cluster ID: $CLUSTER_ID"
}

# Get all nodes in the specified zone
get_nodes_in_zone() {
    log_info "Fetching nodes in zone: $zone"
    
    local response
    if ! response=$(api_call "GET" "/kubernetes/external-clusters/$CLUSTER_ID/nodes?nodeStatus=node_status_unspecified&lifecycleType=lifecycle_type_unspecified&zone=$ZONE"); then
        log_error "Failed to fetch nodes"
        exit 1
    fi

    # Parse node IDs and filter out empty lines
    mapfile -t ALL_NODES < <(echo "$response" | jq -r '.items[].id' | grep -v '^$')

    if [[ ${#ALL_NODES[@]} -eq 0 ]]; then
        log_error "No nodes found in zone: $ZONE"
        exit 1
    fi

    log_success "Found ${#ALL_NODES[@]} nodes in zone $ZONE"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_verbose "Node IDs:"
        printf '  %s\n' "${ALL_NODES[@]}"
    fi
}

# Create batches from node list
create_batches() {
    log_info "Creating batches of size $BATCH_SIZE"
    
    BATCHES=()
    local batch=()
    local count=0

    for node in "${ALL_NODES[@]}"; do
        batch+=("$node")
        count=$((count + 1))

        if [[ $count -eq $BATCH_SIZE ]]; then
            BATCHES+=("$(printf '%s\n' "${batch[@]}")")
            batch=()
            count=0
        fi
    done

    # Add remaining nodes as final batch
    if [[ ${#batch[@]} -gt 0 ]]; then
        BATCHES+=("$(printf '%s\n' "${batch[@]}")")
    fi

    log_success "Created ${#BATCHES[@]} batches"
    
    if [[ "$VERBOSE" == "true" ]]; then
        for i in "${!BATCHES[@]}"; do
            local batch_num=$((i + 1))
            local node_count
            node_count=$(echo "${BATCHES[$i]}" | wc -l)
            log_verbose "Batch $batch_num: $node_count nodes"
        done
    fi
}

# Generate rebalancing plan for a batch
generate_rebalancing_plan() {
    local batch_nodes="$1"
    local batch_num="$2"
    
    log_info "Generating rebalancing plan for batch $batch_num"

    # Convert batch nodes to JSON format
    local node_list
    node_list=$(echo "$batch_nodes" | jq -R -s 'split("\n") | map(select(length > 0) | {nodeId: .})')

    local data="{
        \"minNodes\": $MIN_NODES,
        \"rebalancingNodes\": $node_list
    }"

    log_verbose "Request payload: $data"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would generate rebalancing plan for batch $batch_num"
        echo "dry-run-plan-id-$batch_num"
        return 0
    fi

    local response
    if ! response=$(api_call "POST" "/kubernetes/clusters/$CLUSTER_ID/rebalancing-plans" "$data"); then
        log_error "Failed to generate rebalancing plan for batch $batch_num"
        return 1
    fi

    local plan_id
    plan_id=$(echo "$response" | jq -r '.rebalancingPlanId')

    if [[ -z "$plan_id" || "$plan_id" == "null" ]]; then
        log_error "Failed to extract rebalancing plan ID from response"
        log_error "Response: $response"
        return 1
    fi

    log_success "Generated rebalancing plan ID: $plan_id"
    echo "$plan_id"
}

# Execute rebalancing plan
execute_rebalancing_plan() {
    local plan_id="$1"
    local batch_num="$2"
    
    log_info "Executing rebalancing plan $plan_id for batch $batch_num"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute rebalancing plan $plan_id for batch $batch_num"
        return 0
    fi

    # Wait a bit before execution
    sleep 5

    local response
    if ! response=$(api_call "POST" "/kubernetes/clusters/$CLUSTER_ID/rebalancing-plans/$plan_id/execute" ""); then
        log_error "Failed to execute rebalancing plan $plan_id"
        return 1
    fi

    local status
    status=$(echo "$response" | jq -r '.status // "unknown"')

    if [[ "$status" == "failed" ]]; then
        log_error "Rebalancing plan execution failed with status: $status"
        return 1
    fi

    log_success "Rebalancing plan executed successfully. Status: $status"
}

# Monitor rebalancing completion
monitor_rebalancing_completion() {
    local plan_id="$1"
    local batch_num="$2"
    
    log_info "Monitoring rebalancing completion for batch $batch_num (Plan ID: $plan_id)"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would monitor rebalancing completion for batch $batch_num"
        return 0
    fi

    local timeout=$((TIMEOUT_MINUTES * 60))
    local elapsed_time=0

    while [[ $elapsed_time -lt $timeout ]]; do
        local response
        if ! response=$(api_call "GET" "/kubernetes/clusters/$CLUSTER_ID/rebalancing-plans/$plan_id"); then
            log_warning "Failed to fetch rebalancing plan status, retrying..."
            sleep $POLL_INTERVAL
            elapsed_time=$((elapsed_time + POLL_INTERVAL))
            continue
        fi

        local status
        status=$(echo "$response" | jq -r '.status // "unknown"')

        case "$status" in
            "finished"|"completed")
                log_success "Batch $batch_num rebalancing completed successfully"
                return 0
                ;;
            "failed"|"error")
                log_error "Batch $batch_num rebalancing failed with status: $status"
                return 1
                ;;
            *)
                log_info "Batch $batch_num rebalancing in progress... Status: $status (${elapsed_time}s elapsed)"
                ;;
        esac

        sleep $POLL_INTERVAL
        elapsed_time=$((elapsed_time + POLL_INTERVAL))
    done

    log_error "Batch $batch_num rebalancing timed out after $TIMEOUT_MINUTES minutes"
    return 1
}

# Process a single batch
process_batch() {
    local batch_nodes="$1"
    local batch_num="$2"
    local total_batches="$3"
    
    log_info "Processing batch $batch_num of $total_batches"
    
    # Show nodes in this batch
    local node_count
    node_count=$(echo "$batch_nodes" | wc -l)
    log_info "Batch $batch_num contains $node_count nodes"

    # Generate rebalancing plan
    local plan_id
    if ! plan_id=$(generate_rebalancing_plan "$batch_nodes" "$batch_num"); then
        return 1
    fi

    # Execute rebalancing plan
    if ! execute_rebalancing_plan "$plan_id" "$batch_num"; then
        return 1
    fi

    # Monitor completion
    if ! monitor_rebalancing_completion "$plan_id" "$batch_num"; then
        return 1
    fi

    log_success "Batch $batch_num completed successfully"
    
    # Wait between batches (except for the last one)
    if [[ $batch_num -lt $total_batches ]]; then
        log_info "Waiting 30 seconds before processing next batch..."
        sleep 30
    fi
}

# Main execution function
main() {
    log_info "Starting Cast AI Batch Rebalancing Script"
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check dependencies
    check_dependencies
    
    # Validate parameters
    validate_params
    
    # Get API key
    get_api_key
    
    # Get cluster ID (if not provided directly)
    get_cluster_id
    
    # Get nodes in zone
    get_nodes_in_zone
    
    # Create batches
    create_batches
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "=== DRY RUN MODE - No actual changes will be made ==="
    fi
    
    # Process each batch
    local failed_batches=0
    for i in "${!BATCHES[@]}"; do
        local batch_num=$((i + 1))
        local total_batches=${#BATCHES[@]}
        
        if ! process_batch "${BATCHES[$i]}" "$batch_num" "$total_batches"; then
            log_error "Batch $batch_num failed"
            failed_batches=$((failed_batches + 1))
        fi
    done
    
    # Summary
    local successful_batches=$((${#BATCHES[@]} - failed_batches))
    log_info "Rebalancing Summary:"
    log_info "  Total batches: ${#BATCHES[@]}"
    log_info "  Successful: $successful_batches"
    log_info "  Failed: $failed_batches"
    log_info "  Dry Run: $DRY_RUN"
    
    if [[ $failed_batches -eq 0 ]]; then
        log_success "All batches completed successfully!"
        exit 0
    else
        log_error "Some batches failed. Check the logs above for details."
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
