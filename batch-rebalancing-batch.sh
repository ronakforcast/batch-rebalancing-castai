#!/bin/bash

# Simple batch rebalancing script
# Usage: ./script.sh <cluster_id> <api_key> <batch_size> [zone]

if [ $# -lt 3 ]; then
    echo "Usage: $0 <cluster_id> <api_key> <batch_size> [zone]"
    exit 1
fi

CLUSTER_ID="$1"
API_KEY="$2"
BATCH_SIZE="$3"
ZONE="$4"

echo "Starting batch rebalancing..."
echo "Cluster ID: $CLUSTER_ID"
echo "Batch Size: $BATCH_SIZE"

# Get all nodes
echo "Fetching nodes..."
if [ -n "$ZONE" ]; then
    URL="https://api.cast.ai/v1/kubernetes/external-clusters/$CLUSTER_ID/nodes?zone=$ZONE"
else
    URL="https://api.cast.ai/v1/kubernetes/external-clusters/$CLUSTER_ID/nodes"
fi

# Fetch nodes and save to temp file
curl -s -H "X-API-Key: $API_KEY" -H "accept: application/json" "$URL" | \
    jq -r '.items[]?.id' | grep -v "^null$" | grep -v "^$" > /tmp/nodes.txt

# Check if we got nodes
if [ ! -s /tmp/nodes.txt ]; then
    echo "No nodes found!"
    exit 1
fi

TOTAL_NODES=$(wc -l < /tmp/nodes.txt)
echo "Found $TOTAL_NODES nodes"

# Process in batches
BATCH_NUM=1
START_LINE=1

while [ $START_LINE -le $TOTAL_NODES ]; do
    echo ""
    echo "=== Processing Batch $BATCH_NUM ==="
    
    # Get batch of nodes
    END_LINE=$((START_LINE + BATCH_SIZE - 1))
    if [ $END_LINE -gt $TOTAL_NODES ]; then
        END_LINE=$TOTAL_NODES
    fi
    
    echo "Processing nodes $START_LINE to $END_LINE"
    
    # Extract batch nodes and create JSON
    BATCH_NODES=$(sed -n "${START_LINE},${END_LINE}p" /tmp/nodes.txt)
    NODE_JSON="["
    FIRST=true
    for node in $BATCH_NODES; do
        if [ "$FIRST" = true ]; then
            NODE_JSON="${NODE_JSON}{\"nodeId\":\"$node\"}"
            FIRST=false
        else
            NODE_JSON="${NODE_JSON},{\"nodeId\":\"$node\"}"
        fi
    done
    NODE_JSON="${NODE_JSON}]"
    
    echo "Creating rebalancing plan..."
    
    # Create rebalancing plan
    PLAN_RESPONSE=$(curl -s -X POST \
        "https://api.cast.ai/v1/kubernetes/clusters/$CLUSTER_ID/rebalancing-plans" \
        -H "X-API-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"minNodes\": 3, \"rebalancingNodes\": $NODE_JSON}")
    
    PLAN_ID=$(echo "$PLAN_RESPONSE" | jq -r '.rebalancingPlanId // empty')
    
    if [ -z "$PLAN_ID" ] || [ "$PLAN_ID" = "null" ]; then
        echo "Failed to create plan for batch $BATCH_NUM"
        echo "Response: $PLAN_RESPONSE"
    else
        echo "Plan created: $PLAN_ID"
        
        # Execute plan
        echo "Executing plan..."
        sleep 10
        
        EXEC_RESPONSE=$(curl -s -X POST \
            "https://api.cast.ai/v1/kubernetes/clusters/$CLUSTER_ID/rebalancing-plans/$PLAN_ID/execute" \
            -H "X-API-Key: $API_KEY")
        
        echo "Plan execution started"
        
        # Wait for completion
        echo "Waiting for completion..."
        TIMEOUT=2400  # 40 minutes
        ELAPSED=0
        
        while [ $ELAPSED -lt $TIMEOUT ]; do
            STATUS_RESPONSE=$(curl -s \
                "https://api.cast.ai/v1/kubernetes/clusters/$CLUSTER_ID/rebalancing-plans/$PLAN_ID" \
                -H "X-API-Key: $API_KEY")
            
            STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status // empty')
            
            if [ "$STATUS" = "finished" ]; then
                echo "Batch $BATCH_NUM completed successfully!"
                break
            elif [ "$STATUS" = "failed" ]; then
                echo "Batch $BATCH_NUM failed!"
                break
            else
                echo "Status: $STATUS (${ELAPSED}s elapsed)"
                sleep 30
                ELAPSED=$((ELAPSED + 30))
            fi
        done
        
        if [ $ELAPSED -ge $TIMEOUT ]; then
            echo "Batch $BATCH_NUM timed out!"
        fi
    fi
    
    # Move to next batch
    START_LINE=$((END_LINE + 1))
    BATCH_NUM=$((BATCH_NUM + 1))
    
    # Small delay between batches
    if [ $START_LINE -le $TOTAL_NODES ]; then
        echo "Waiting 30 seconds before next batch..."
        sleep 30
    fi
done

# Cleanup
rm -f /tmp/nodes.txt

echo ""
echo "All batches processed!"
