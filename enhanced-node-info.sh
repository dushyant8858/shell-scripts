#!/bin/bash

# Set up headers and format for the table
printf "%-40s %-12s %-12s %-12s %-12s %-8s %-12s %-12s %-12s %-8s %-12s %-12s %-12s %-12s %-12s %-8s %-12s %-12s %s\n" \
  "NODE_NAME" "ZONE" "INSTANCE_TYPE" "PODS_RUNNING" "MAX_PODS" "POD_%" "CPU_CAPACITY" "CPU_ALLOC" "CPU_REQ" "REQ_%" "CPU_USED" "MEM_CAPACITY" "MEM_ALLOC" "MEM_REQ" "REQ_%" "MEM_USED" "CPU_AVAIL" "MEM_AVAIL" "GPU"

# Loop through each node to get detailed information
kubectl get nodes --no-headers -o custom-columns=\
"NODE_NAME:.metadata.name,ZONE:.metadata.labels.topology\\.kubernetes\\.io/zone,INSTANCE_TYPE:.metadata.labels.node\\.kubernetes\\.io/instance-type,MAX_PODS:.status.capacity.pods,CPU_CAPACITY:.status.capacity.cpu,CPU_ALLOC:.status.allocatable.cpu,MEM_CAPACITY:.status.capacity.memory,MEM_ALLOC:.status.allocatable.memory,GPU:.status.capacity.nvidia\\.com/gpu" \
| while read -r NODE_NAME ZONE INSTANCE_TYPE MAX_PODS CPU_CAPACITY CPU_ALLOC MEM_CAPACITY MEM_ALLOC GPU; do
  # Fallback for GPU if the capacity field is not present
  if [[ -z "$GPU" ]]; then
    GPU="0"
  fi

  # Get number of running pods on this node
  PODS_RUNNING=$(kubectl get pods --all-namespaces --field-selector spec.nodeName="$NODE_NAME" --no-headers 2>/dev/null | wc -l)

  # Get resource usage from kubectl top
  USAGE_LINE=$(kubectl top nodes "$NODE_NAME" --no-headers 2>/dev/null)
  if [ -n "$USAGE_LINE" ]; then
    CPU_USED=$(echo "$USAGE_LINE" | awk '{print $2}')
    MEM_USED=$(echo "$USAGE_LINE" | awk '{print $4}')
  else
    CPU_USED="N/A"
    MEM_USED="N/A"
  fi

  # Get resource requests and limits for pods on this node
  RESOURCE_INFO=$(kubectl describe node "$NODE_NAME" 2>/dev/null | awk '/Allocated resources:/,/Events:/ {print}' | grep -E "cpu|memory")
  CPU_REQ=$(echo "$RESOURCE_INFO" | grep "cpu" | awk '{print $2}' | head -1)
  MEM_REQ=$(echo "$RESOURCE_INFO" | grep "memory" | awk '{print $2}' | head -1)
  MEM_LIM=$(echo "$RESOURCE_INFO" | grep "memory" | awk '{print $4}' | head -1)
  
  # Set defaults if not found
  [[ -z "$CPU_REQ" ]] && CPU_REQ="0"
  [[ -z "$MEM_REQ" ]] && MEM_REQ="0"
  [[ -z "$MEM_LIM" ]] && MEM_LIM="0"

  # Calculate available resources (allocatable - used)
  if [[ "$CPU_USED" != "N/A" && -n "$CPU_ALLOC" ]]; then
    CPU_USED_MC=$(echo "$CPU_USED" | sed 's/m$//')
    CPU_ALLOC_MC=$(echo "$CPU_ALLOC" | sed 's/m$//')
    if [[ "$CPU_USED_MC" =~ ^[0-9]+$ && "$CPU_ALLOC_MC" =~ ^[0-9]+$ ]]; then
      CPU_AVAIL_MC=$((CPU_ALLOC_MC - CPU_USED_MC))
      CPU_AVAIL="${CPU_AVAIL_MC}m"
    else
      CPU_AVAIL="N/A"
    fi
  else
    CPU_AVAIL="N/A"
  fi

  if [[ "$MEM_USED" != "N/A" && -n "$MEM_ALLOC" ]]; then
    MEM_USED_NUM=$(echo "$MEM_USED" | sed 's/[A-Za-z]*$//')
    MEM_ALLOC_NUM=$(echo "$MEM_ALLOC" | sed 's/[A-Za-z]*$//')
    
    if [[ "$MEM_USED_NUM" =~ ^[0-9]+$ && "$MEM_ALLOC_NUM" =~ ^[0-9]+$ ]]; then
      if [[ "$MEM_USED" =~ Mi$ ]]; then
        MEM_USED_KI=$((MEM_USED_NUM * 1024))
      else
        MEM_USED_KI=$MEM_USED_NUM
      fi
      
      if [[ "$MEM_ALLOC" =~ Mi$ ]]; then
        MEM_ALLOC_KI=$((MEM_ALLOC_NUM * 1024))
      else
        MEM_ALLOC_KI=$MEM_ALLOC_NUM
      fi
      
      MEM_AVAIL_KI=$((MEM_ALLOC_KI - MEM_USED_KI))
      MEM_AVAIL="${MEM_AVAIL_KI}Ki"
    else
      MEM_AVAIL="N/A"
    fi
  else
    MEM_AVAIL="N/A"
  fi

  # Calculate percentages
  POD_PCT=$(( (PODS_RUNNING * 100) / MAX_PODS ))%
  
  # Calculate CPU request percentage (CPU_REQ / CPU_ALLOC)
  if [[ "$CPU_REQ" != "0" && -n "$CPU_ALLOC" ]]; then
    CPU_REQ_MC=$(echo "$CPU_REQ" | sed 's/[()%m]//g')
    CPU_ALLOC_MC=$(echo "$CPU_ALLOC" | sed 's/m$//')
    if [[ "$CPU_REQ_MC" =~ ^[0-9]+$ && "$CPU_ALLOC_MC" =~ ^[0-9]+$ && "$CPU_ALLOC_MC" -gt 0 ]]; then
      CPU_REQ_PCT=$(( (CPU_REQ_MC * 100) / CPU_ALLOC_MC ))%
    else
      CPU_REQ_PCT="0%"
    fi
  else
    CPU_REQ_PCT="0%"
  fi
  
  # Calculate memory request percentage (MEM_REQ / MEM_ALLOC)
  if [[ "$MEM_REQ" != "0" && -n "$MEM_ALLOC" ]]; then
    MEM_REQ_NUM=$(echo "$MEM_REQ" | sed 's/[()%A-Za-z]*$//' | sed 's/^[^0-9]*//')
    MEM_ALLOC_NUM=$(echo "$MEM_ALLOC" | sed 's/[A-Za-z]*$//')
    if [[ "$MEM_REQ_NUM" =~ ^[0-9]+$ && "$MEM_ALLOC_NUM" =~ ^[0-9]+$ && "$MEM_ALLOC_NUM" -gt 0 ]]; then
      # Convert to same units
      if [[ "$MEM_REQ" =~ Mi ]]; then
        MEM_REQ_KI=$((MEM_REQ_NUM * 1024))
      else
        MEM_REQ_KI=$MEM_REQ_NUM
      fi
      if [[ "$MEM_ALLOC" =~ Mi$ ]]; then
        MEM_ALLOC_KI=$((MEM_ALLOC_NUM * 1024))
      else
        MEM_ALLOC_KI=$MEM_ALLOC_NUM
      fi
      MEM_REQ_PCT=$(( (MEM_REQ_KI * 100) / MEM_ALLOC_KI ))%
    else
      MEM_REQ_PCT="0%"
    fi
  else
    MEM_REQ_PCT="0%"
  fi

  # Print all collected information in a formatted row
  printf "%-40s %-12s %-12s %-12s %-12s %-8s %-12s %-12s %-12s %-8s %-12s %-12s %-12s %-12s %-8s %-12s %-12s %-12s %s\n" \
  "$NODE_NAME" "$ZONE" "$INSTANCE_TYPE" "$PODS_RUNNING" "$MAX_PODS" "$POD_PCT" "$CPU_CAPACITY" "$CPU_ALLOC" "$CPU_REQ" "$CPU_REQ_PCT" "$CPU_USED" "$MEM_CAPACITY" "$MEM_ALLOC" "$MEM_REQ" "$MEM_REQ_PCT" "$MEM_USED" "$CPU_AVAIL" "$MEM_AVAIL" "$GPU"
done