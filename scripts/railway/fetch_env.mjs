// Fetch production env vars from Railway (for VPS migration). Writes only names to stdout.
import { readFileSync, writeFileSync } from 'node:fs';
import { GRAPHQL, IDS, getToken } from './common.mjs';

const query = `
query($projectId: String!, $environmentId: String!, $serviceId: String!) {
  variables(projectId: $projectId, environmentId: $environmentId, serviceId: $serviceId)
}`;

const res = await fetch(GRAPHQL, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${getToken()}`,
  },
  body: JSON.stringify({
    query,
    variables: {
      projectId: IDS.project,
      environmentId: IDS.environment,
      serviceId: IDS.service,
    },
  }),
});

const json = await res.json();
if (json.errors) {
  console.error('ERRORS:', JSON.stringify(json.errors));
  process.exit(1);
}

const raw = json.data?.variables;
if (!raw) {
  console.error('No variables returned:', JSON.stringify(json));
  process.exit(1);
}

// variables is a SCALAR — may be a JSON string or already an object
const obj = typeof raw === 'string' ? JSON.parse(raw) : raw;
const names = Object.keys(obj);
console.error(`Fetched ${names.length} variables:`);
const lines = [];
for (const name of names) {
  console.error(`  - ${name}`);
  lines.push(`${name}=${obj[name]}`);
}
lines.push('PORT=5001');
lines.push('NODE_ENV=production');
writeFileSync(process.argv[2], lines.join('\n') + '\n', 'utf8');
console.error(`Wrote ${process.argv[2]}`);
