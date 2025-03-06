#!/usr/bin/env bash

NODESAPI="/api/v1/nodes"

# Fetch all nodes
function getNodes() {
  kubectl get --raw $NODESAPI | jq -r '.items[].metadata.name'
}

# Fetch Persistent Volume Claims (PVCs), aggregate by namespace, and remove duplicates
function getPVCs() {
  jq -s '[ 
    flatten | .[].pods[].volume[]? 
    | select(has("pvcRef")) 
    | {namespace: .pvcRef.namespace, name: .pvcRef.name, capacityBytes, usedBytes, availableBytes, 
       percentageUsed: (.usedBytes / .capacityBytes * 100)}
    ] 
    | unique_by(.namespace, .name)
    | sort_by(.namespace, .name)'
}

# Format output into columns
function column() {
  awk '{ for (i = 1; i <= NF; i++) { d[NR, i] = $i; w[i] = length($i) > w[i] ? length($i) : w[i] } } '\
'END { for (i = 1; i <= NR; i++) { printf("%-*s", w[1], d[i, 1]); for (j = 2; j <= NF; j++ ) { printf("%*s", w[j] + 1, d[i, j]) } print "" } }'
}

# Default format (size in KB)
function defaultFormat() {
  awk 'BEGIN { printf "%-30s %-10s %-10s %-10s %-5s\n", "NAMESPACE/PVC", "1K-blocks", "Used", "Avail", "Use%" }'\
'{$2 = $2/1024; $3 = $3/1024; $4 = $4/1024; $5 = sprintf("%.0f%%", $5); printf "%-30s %-10.0f %-10.0f %-10.0f %-5s\n", $1, $2, $3, $4, $5}'
}

# Human-readable format (IEC units)
function humanFormat() {
  awk 'BEGIN { printf "%-30s %-10s %-10s %-10s %-5s\n", "NAMESPACE/PVC", "Size", "Used", "Avail", "Use%" }'\
'{$5 = sprintf("%.0f%%", $5); printf "%s ", $1; system(sprintf("numfmt --to=iec --suffix=B %s %s %s | tr -d \n", $2, $3, $4)); print " " $5 }'
}

# Choose the output format
function format() {
  jq -r '.[] | "\(.namespace)/\(.name) \(.capacityBytes) \(.usedBytes) \(.availableBytes) \(.percentageUsed)"' |
    $format | column
}

# Determine format based on flags
if [ "$1" == "-h" ]; then
  format=humanFormat
else
  format=defaultFormat
fi

# Main execution loop: process all nodes and extract PVCs
for node in $(getNodes); do
  kubectl get --raw "$NODESAPI/$node/proxy/stats/summary" 2>/dev/null
done | getPVCs | format
