# Cast.ai Batch Rebalancing Script

A bash script for performing batch node rebalancing operations on Cast.ai managed Kubernetes clusters. This script allows you to rebalance nodes in controlled batches rather than all at once, providing better control over cluster operations and reducing potential disruption.

## Features

- **Batch Processing**: Rebalance nodes in configurable batch sizes
- **Zone Filtering**: Optional filtering by availability zone
- **Progress Monitoring**: Real-time status monitoring with timeout protection
- **Error Handling**: Robust error checking and status reporting
- **Safe Execution**: Maintains minimum node requirements during rebalancing

## Prerequisites

- **bash** shell environment
- **curl** - For API requests
- **jq** - For JSON processing
- Valid Cast.ai API key with cluster management permissions
- Access to the target Kubernetes cluster

## Installation

1. Download the script:
   ```bash
   wget https://path-to-script/rebalance.sh
   chmod +x rebalance.sh
   ```

2. Install dependencies (if not already available):
   ```bash
   # On Ubuntu/Debian
   sudo apt-get install curl jq
   
   # On macOS
   brew install curl jq
   
   # On RHEL/CentOS
   sudo yum install curl jq
   ```

## Usage

### Basic Usage
```bash
./rebalance.sh <cluster_id> <api_key> <batch_size>
```

### With Zone Filtering
```bash
./rebalance.sh <cluster_id> <api_key> <batch_size> <zone>
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `cluster_id` | Yes | Cast.ai cluster identifier |
| `api_key` | Yes | Cast.ai API key with cluster permissions |
| `batch_size` | Yes | Number of nodes to process per batch |
| `zone` | No | Filter nodes by specific availability zone |

### Examples

```bash
# Rebalance all nodes in batches of 5
./rebalance.sh abc123-def456 "your-api-key-here" 5

# Rebalance nodes in us-west-2a zone, batches of 3
./rebalance.sh abc123-def456 "your-api-key-here" 3 us-west-2a

# Small batches for production (recommended)
./rebalance.sh abc123-def456 "your-api-key-here" 2
```

## How It Works

1. **Node Discovery**: Fetches all nodes in the cluster (optionally filtered by zone)
2. **Batch Creation**: Divides nodes into batches of specified size
3. **Plan Generation**: Creates a rebalancing plan for each batch with minimum node requirements
4. **Execution**: Executes the plan and monitors progress
5. **Monitoring**: Waits for completion with 40-minute timeout per batch
6. **Iteration**: Processes next batch with 30-second delay between batches

## Output Example

```
Starting batch rebalancing...
Cluster ID: abc123-def456
Batch Size: 3
Fetching nodes...
Found 12 nodes

=== Processing Batch 1 ===
Processing nodes 1 to 3
Creating rebalancing plan...
Plan created: plan-789xyz
Executing plan...
Plan execution started
Waiting for completion...
Status: running (30s elapsed)
Status: running (60s elapsed)
Batch 1 completed successfully!

=== Processing Batch 2 ===
...
```

## Configuration

### Timeouts and Delays

The script includes several timing configurations:

- **Plan Execution Delay**: 10 seconds before executing each plan
- **Status Check Interval**: 30 seconds between status checks
- **Batch Timeout**: 40 minutes (2400 seconds) per batch
- **Inter-batch Delay**: 30 seconds between batches

### Minimum Nodes

The script enforces a minimum of 3 nodes during rebalancing to maintain cluster stability. This can be modified in the script if needed:

```bash
# Line in script:
"minNodes": 3
```

## Error Handling

The script handles various error conditions:

- **No nodes found**: Exits if no nodes are discovered
- **Plan creation failure**: Reports failed plan creation with API response
- **Execution timeout**: Reports timeout after 40 minutes per batch
- **API errors**: Displays raw API responses for debugging

## Security Considerations

- **API Key Protection**: Never commit API keys to version control
- **Environment Variables**: Consider using environment variables for API keys:
  ```bash
  export CAST_AI_API_KEY="your-api-key-here"
  ./batch-rebalancing-batch.sh abc123-def456 "$CAST_AI_API_KEY" 5
  ```
- **Permissions**: Ensure the API key has only necessary permissions

## Troubleshooting

### Common Issues

1. **"No nodes found!"**
   - Verify cluster ID is correct
   - Check API key permissions
   - Ensure nodes exist in specified zone (if using zone filter)

2. **"Failed to create plan"**
   - Check API key validity
   - Verify cluster is accessible
   - Ensure cluster has sufficient nodes for rebalancing

3. **Timeout errors**
   - Increase timeout value for large nodes
   - Check cluster health and node responsiveness
   - Monitor Cast.ai dashboard for stuck operations

### Debug Mode

Add debug output by modifying curl commands:
```bash
# Change from:
curl -s -H "X-API-Key: $API_KEY" ...

# To:
curl -v -H "X-API-Key: $API_KEY" ...
```

## Limitations

- Maximum 40-minute timeout per batch
- Requires jq for JSON processing
- Linux/Unix environments only
- Synchronous processing (one batch at a time)

## Best Practices

1. **Start Small**: Test with small percentages (10-15%) or fixed sizes (2-3 nodes) initially
2. **Choose Appropriate Batch Sizing**:
   - **Small clusters (≤20 nodes)**: Use fixed batch sizes (2-3 nodes)
   - **Medium clusters (20-100 nodes)**: Use 10-25% batches
   - **Large clusters (>100 nodes)**: Use 5-15% batches
3. **Monitor Resources**: Watch cluster resource utilization during rebalancing
4. **Off-Peak Hours**: Run during low-traffic periods
5. **Backup Plans**: Ensure you can manually intervene if needed
6. **Gradual Rollout**: For large clusters, consider multiple smaller runs

## Contributing

To contribute improvements:

1. Test changes thoroughly in non-production environments
2. Follow bash best practices
3. Maintain backward compatibility
4. Update this README with any new features or requirements

## License

This script is provided as-is for Cast.ai users. Please refer to Cast.ai's terms of service for API usage guidelines.
