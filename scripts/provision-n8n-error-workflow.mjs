const apiKey = process.env.N8N_API_KEY;
const ntfyDomain = process.env.NTFY_DOMAIN;
if (!apiKey || !ntfyDomain) {
  throw new Error('N8N_API_KEY and NTFY_DOMAIN must be set');
}

const name = 'Infrastructure Error Notifications';
const workflow = {
  name,
  active: true,
  nodes: [
    {
      parameters: {},
      id: '7b2f1a2a-0810-4c9f-9aa6-000000000001',
      name: 'Error Trigger',
      type: 'n8n-nodes-base.errorTrigger',
      typeVersion: 1,
      position: [260, 300],
    },
    {
      parameters: {
        method: 'POST',
        url: `https://${ntfyDomain}/n8n-errors`,
        sendHeaders: true,
        headerParameters: {
          parameters: [
            { name: 'Authorization', value: '=Bearer {{$env.NTFY_TOKEN}}' },
            { name: 'Title', value: '=n8n: {{$json.workflow.name}}' },
            { name: 'Priority', value: 'high' },
            { name: 'Tags', value: 'warning,gear' },
            { name: 'Click', value: `={{'https://${process.env.DOMAIN}/execution/' + $json.execution.id}}` },
          ],
        },
        sendBody: true,
        contentType: 'raw',
        rawContentType: 'text/plain',
        body: '=Workflow "{{$json.workflow.name}}" failed. Execution {{$json.execution.id}}: {{$json.execution.error.message || "unknown error"}}',
        options: {},
      },
      id: '7b2f1a2a-0810-4c9f-9aa6-000000000002',
      name: 'Notify ntfy',
      type: 'n8n-nodes-base.httpRequest',
      typeVersion: 4.2,
      position: [520, 300],
      continueOnFail: true,
    },
  ],
  connections: {
    'Error Trigger': { main: [[{ node: 'Notify ntfy', type: 'main', index: 0 }]] },
  },
  settings: { executionOrder: 'v1' },
};

const request = async (path, options = {}) => {
  const response = await fetch(`http://127.0.0.1:5678/api/v1${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'X-N8N-API-KEY': apiKey,
      ...(options.headers ?? {}),
    },
  });
  if (!response.ok) throw new Error(`n8n API ${options.method ?? 'GET'} ${path} failed: ${response.status} ${await response.text()}`);
  return response.status === 204 ? undefined : response.json();
};

const existing = await request('/workflows?limit=100');
const match = existing.data?.find((item) => item.name === name);
if (match) {
  await request(`/workflows/${match.id}`, { method: 'PUT', body: JSON.stringify(workflow) });
  console.log(`Updated ${name} (${match.id})`);
} else {
  const created = await request('/workflows', { method: 'POST', body: JSON.stringify(workflow) });
  console.log(`Created ${name} (${created.id})`);
}

