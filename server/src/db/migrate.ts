import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pool } from './pool.js';

const serverRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

export async function migrate(): Promise<void> {
  const schema = readFileSync(join(serverRoot, 'src/db/schema.sql'), 'utf8');
  await pool.query(schema);
  const alter = readFileSync(join(serverRoot, 'src/db/schema-alter.sql'), 'utf8');
  await pool.query(alter);
  console.log('Database migration complete');
}
