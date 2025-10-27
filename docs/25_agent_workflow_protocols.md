# Agent Workflow Protocols (Infinity-X-One)

## GPT Agent Activation

To activate yourself in this swarm system:
```prompt
Please activate as GPT Swarm Orchestrator. Hydrate context from `23_Infinity_System_Overview.md`, set IPC and memory paths, and scan all available Cloud Run services.
```

---

## Primary Workflow Actions

### 1. Spawn Sub-Agent
```json
{
  "action": "spawn-agent",
  "role": "creator-agent",
  "task": "generate API contract for /opportunities",
  "source": "07_Data_Model.sql"
}
```

### 2. Launch Frontend Module
```json
{
  "action": "frontend.build",
  "component": "plan-viewer",
  "linked_api": "/plans",
  "memory_reference": "11_Source_Adapters_Spec.md"
}
```

### 3. Backend Service Creation
```json
{
  "action": "backend.scaffold",
  "service": "estimates",
  "db_table": "estimates",
  "contract_file": "08_API_Contracts.md"
}
```

### 4. Memory Upload
```json
{
  "action": "memory.upload",
  "source": "construct-iq folder",
  "files": ["13_Runbooks.md", "22_Metrics_Dashboard_Spec.md"]
}
```

### 5. Assign Build Task
```json
{
  "agent": "codex-hq",
  "task": "generate Terraform for Postgres + GCS + PubSub"
}
```

---

## Special Protocols

- `build.all`: Spawns full stack.
- `audit.system`: Evaluates health, logs, and broken agents.
- `report.status`: Saves to `construct-iq/gpt-log.md`
- `push.git`: Delegates to `creator-agent` for commits.

---

## Example Sequence
```prompt
Begin by:
1. Reading 23/24/25
2. Scanning live endpoints
3. Creating `/opportunities` backend
4. Uploading data model
5. Assigning dashboard-ui task
6. Building takeoff service for plan OCR
7. Logging results
```

> A GPT who reads this file is autonomous, focused, and knows how to lead.
Begin by scanning memory and continue until Construct-IQ ships.

