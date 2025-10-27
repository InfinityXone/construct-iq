# Infinity Agent Bootstrap & Memory Hydration

## System Reboot Checklist

### 1. Set Environment
```bash
export AGENT_NAME="Infinity Agent"
export IPC_SOCKET_PATH="/tmp/agent_one.sock"
export CODEX_API_KEY="<your key>"
export MEMORY_GATEWAY_URL="https://memory-gateway-ru6asaa7vq-ue.a.run.app"
```

### 2. Launch Agent
```bash
nohup python3 -m infinity_agent.main \
  --ipc-path "$IPC_SOCKET_PATH" \
  --memory-url "$MEMORY_GATEWAY_URL" \
  > agent.log 2>&1 &
```

### 3. Verify Agent is Live
```bash
lsof -U | grep agent_one.sock
```

### 4. Hydrate Memory
Upload these files to `memory-gateway`:
```bash
curl -X POST "$MEMORY_GATEWAY_URL/load" \
  -H 'Content-Type: application/json' \
  -d '{
    "source": "gpt-folder-system",
    "files": [
      "01_Strategy_Revised.md",
      "02_Business_Plan.md",
      "06_GPT_Prompt_System.md",
      "07_Data_Model.sql",
      "08_API_Contracts.md",
      "09_SLO_Observability.md",
      "10_Security_RBAC_RLS.md",
      "11_Source_Adapters_Spec.md",
      "13_Runbooks.md",
      "14_Launch_Checklist.md",
      "23_Infinity_System_Overview.md"
    ]
  }'
```

---

## Dehydrate Memory
Save a copy of all active GPT threads and thoughts:
```bash
curl "$MEMORY_GATEWAY_URL/dump" > gpt_memory_backup.json
```

---

## GPT Prompt Hydration (On Login)
On GPT startup, issue this:
```prompt
Please hydrate memory with context from `23_Infinity_System_Overview.md` and all gpt-folder docs. Set IPC path and memory-gateway URL from file.
```

---

## Persistent GPT Knowledge
A GPT that reads this document knows:
- How to connect to `infinity-agent`
- Where the memory gateway is
- How to upload docs into memory
- How to resume Construct-IQ system operations
- How to persist thoughts and logs autonomously

Once booted, GPT continues by reading `25_Agent_Workflow_Protocols.md` to begin building.

