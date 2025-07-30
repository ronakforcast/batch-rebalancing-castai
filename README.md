
# Cast AI Batch Rebalancing Script - Quick Start Guide

## Prerequisites

- `curl` and `jq` installed on your system
- Cast AI API key
- Either cluster name or cluster ID
- Target availability zone

## Quick Start

### 1. Basic Usage (Interactive)
```bash
# The script will prompt for API key
./rebalance-script.sh --cluster-name my-cluster --zone us-east-1a
```

### 2. Non-Interactive (Recommended for CI/CD)
```bash
# Using environment variables
export CAST_AI_API_KEY="your-api-key-here"
export CAST_AI_CLUSTER_ID="abc123-def456"  # or use CAST_AI_CLUSTER_NAME
export CAST_AI_ZONE="us-east-1a"
./rebalance-script.sh
```

### 3. Command Line Options
```bash
./rebalance-script.sh \
  --cluster-id abc123-def456 \
  --zone us-east-1a \
  --api-key your-api-key \
  --batch-size 5 \
  --min-nodes 3
```

## Common Scenarios

### Test Run (Dry Run)
```bash
./rebalance-script.sh --cluster-name my-cluster --zone us-east-1a --dry-run
```

### CI/CD Pipeline
```bash
# Set in your CI/CD environment variables:
CAST_AI_API_KEY=<secret>
CAST_AI_CLUSTER_ID=<cluster-id>
CAST_AI_ZONE=<target-zone>

# Run the script
./rebalance-script.sh --verbose
```

### Custom Configuration
```bash
./rebalance-script.sh \
  --cluster-name production-cluster \
  --zone eu-west-1b \
  --batch-size 10 \
  --min-nodes 5 \
  --timeout 90 \
  --verbose
```

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `CAST_AI_API_KEY` | Your Cast AI API key | `sk-cast-ai-...` |
| `CAST_AI_CLUSTER_ID` | Direct cluster ID (faster) | `abc123-def456` |
| `CAST_AI_CLUSTER_NAME` | Cluster name (requires lookup) | `my-production-cluster` |
| `CAST_AI_ZONE` | Target availability zone | `us-east-1a` |
| `CAST_AI_BATCH_SIZE` | Nodes per batch (default: 3) | `5` |
| `CAST_AI_MIN_NODES` | Minimum nodes to maintain (default: 3) | `2` |
| `CAST_AI_TIMEOUT_MINUTES` | Timeout in minutes (default: 60) | `90` |
| `CAST_AI_DRY_RUN` | Set to 'true' for dry run | `true` |
| `CAST_AI_VERBOSE` | Set to 'true' for detailed logs | `true` |

## Command Line Options

| Option | Description |
|--------|-------------|
| `--cluster-name, -c` | Cast AI cluster name |
| `--cluster-id, -i` | Direct cluster ID (skips name lookup) |
| `--zone, -z` | Availability zone to rebalance |
| `--batch-size, -b` | Number of nodes per batch |
| `--min-nodes, -m` | Minimum nodes to maintain |
| `--api-key, -k` | Cast AI API key |
| `--dry-run, -d` | Test mode - shows what would happen |
| `--verbose, -v` | Enable detailed logging |
| `--help, -h` | Show help message |

## CI/CD Examples

### GitHub Actions
```yaml
- name: Rebalance Cast AI Cluster
  env:
    CAST_AI_API_KEY: ${{ secrets.CAST_AI_API_KEY }}
    CAST_AI_CLUSTER_ID: ${{ vars.CLUSTER_ID }}
    CAST_AI_ZONE: ${{ vars.TARGET_ZONE }}
  run: ./rebalance-script.sh --verbose
```

### Jenkins
```groovy
environment {
    CAST_AI_API_KEY = credentials('cast-ai-api-key')
    CAST_AI_CLUSTER_ID = "${params.CLUSTER_ID}"
    CAST_AI_ZONE = "${params.ZONE}"
}
steps {
    sh './rebalance-script.sh --batch-size 5'
}
```

### GitLab CI
```yaml
variables:
  CAST_AI_CLUSTER_ID: "your-cluster-id"
  CAST_AI_ZONE: "us-east-1a"
script:
  - ./rebalance-script.sh --dry-run --verbose
```

## Troubleshooting

### Common Issues

**API Key Problems:**
```bash
# Test your API key
curl -H "X-API-Key: your-key" https://api.cast.ai/v1/kubernetes/external-clusters
```

**Cluster Not Found:**
```bash
# List all clusters to verify name/ID
./rebalance-script.sh --help  # Shows your clusters if API key is valid
```

**Permission Issues:**
```bash
chmod +x rebalance-script.sh
```

### Getting Help
```bash
./rebalance-script.sh --help
```

## Best Practices

1. **Always test first**: Use `--dry-run` before actual execution
2. **Use cluster ID in CI/CD**: Faster than name lookup
3. **Set appropriate timeouts**: Larger clusters need more time
4. **Monitor logs**: Use `--verbose` for troubleshooting
5. **Secure API keys**: Use environment variables, not command line args
6. **Start small**: Use smaller batch sizes for initial runs

## Example Output
```
[INFO] 2024-07-30 10:15:23 - Starting Cast AI Batch Rebalancing Script
[INFO] 2024-07-30 10:15:23 - Using provided cluster ID: abc123-def456
[SUCCESS] 2024-07-30 10:15:25 - Found 12 nodes in zone us-east-1a
[SUCCESS] 2024-07-30 10:15:25 - Created 4 batches
[INFO] 2024-07-30 10:15:25 - Processing batch 1 of 4
[SUCCESS] 2024-07-30 10:18:45 - All batches completed successfully!
```
