// Investigate the streak group access bug: find group 'daily namaz', its
// owner, members, and recently created users (who lost access after install).
import mongodb from 'mongodb';

const envRaw = (await import('node:fs')).readFileSync('D:/sajda_app/backend/.env', 'utf8');
const line = envRaw.split(/\r?\n/).find((l) => l.startsWith('MONGODB_URI'));
const localUri = line.slice(line.indexOf('=') + 1).trim();

const client = new mongodb.MongoClient(localUri, { serverSelectionTimeoutMS: 20000 });
await client.connect();
const db = client.db('test');

const groups = await db.collection('groups').find({}).sort({ createdAt: -1 }).toArray();
console.log('=== GROUPS (latest 10) ===');
for (const g of groups.slice(0, 10)) {
  console.log(`${g.groupId} | ${g.name} | status=${g.status} | owner=${g.ownerId} | members=${g.memberCount} | created=${g.createdAt?.toISOString?.()}`);
}

console.log('\n=== RECENT USERS (latest 15) ===');
const users = await db.collection('users').find({}).sort({ createdAt: -1 }).limit(15).toArray();
for (const u of users) {
  console.log(`${u._id} | ${u.displayName} | email=${u.email ?? '-'} | fbUid=${u.firebaseUid ? 'yes' : 'no'} | deviceId=${u.deviceId ? u.deviceId.slice(0, 8) + '…' : '-'} | created=${u.createdAt?.toISOString?.()}`);
}

console.log('\n=== GROUP MEMBERS (latest 15) ===');
const members = await db.collection('groupmembers').find({}).sort({ joinedAt: -1 }).limit(15).toArray();
for (const m of members) {
  console.log(`group=${m.groupId} | user=${m.userId} | role=${m.role} | status=${m.status} | joined=${m.joinedAt?.toISOString?.() ?? m.createdAt?.toISOString?.()}`);
}

console.log('\n=== JOIN REQUESTS (latest 10) ===');
const reqs = await db.collection('joinrequests').find({}).sort({ createdAt: -1 }).limit(10).toArray();
for (const r of reqs) {
  console.log(`group=${r.groupId} | user=${r.userId} | status=${r.status} | created=${r.createdAt?.toISOString?.()}`);
}

await client.close();
process.exit(0);
