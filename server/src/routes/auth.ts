import bcrypt from 'bcrypt';
import { Router } from 'express';
import { pool } from '../db/pool.js';
import { requireFamilyAuth, signFamilyToken } from '../middleware/auth.js';

export const authRouter = Router();

authRouter.get('/status', async (_req, res) => {
  const result = await pool.query('SELECT COUNT(*)::int AS count FROM families');
  res.json({ registered: result.rows[0].count > 0 });
});

authRouter.post('/register', async (req, res) => {
  const { name, password } = req.body as { name?: string; password?: string };
  if (!name?.trim() || !password || password.length < 8) {
    res.status(400).json({ error: 'Name and password (8+ chars) required' });
    return;
  }

  const existing = await pool.query('SELECT id FROM families LIMIT 1');
  if ((existing.rowCount ?? 0) > 0) {
    res.status(409).json({ error: 'Family already registered' });
    return;
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const result = await pool.query<{ id: string }>(
    'INSERT INTO families (name, password_hash) VALUES ($1, $2) RETURNING id',
    [name.trim(), passwordHash],
  );

  const familyId = result.rows[0].id;
  const token = signFamilyToken(familyId);
  res.status(201).json({ token, familyId, name: name.trim() });
});

authRouter.post('/login', async (req, res) => {
  const { password } = req.body as { password?: string };
  if (!password) {
    res.status(400).json({ error: 'Password required' });
    return;
  }

  const result = await pool.query<{
    id: string;
    name: string;
    password_hash: string;
  }>('SELECT id, name, password_hash FROM families LIMIT 1');

  if (result.rowCount === 0) {
    res.status(404).json({ error: 'Family not registered' });
    return;
  }

  const family = result.rows[0];
  const valid = await bcrypt.compare(password, family.password_hash);
  if (!valid) {
    res.status(401).json({ error: 'Invalid password' });
    return;
  }

  res.json({
    token: signFamilyToken(family.id),
    familyId: family.id,
    name: family.name,
  });
});

authRouter.get('/me', requireFamilyAuth, async (req, res) => {
  const result = await pool.query<{ id: string; name: string }>(
    'SELECT id, name FROM families WHERE id = $1',
    [req.auth!.familyId],
  );
  if (result.rowCount === 0) {
    res.status(404).json({ error: 'Family not found' });
    return;
  }
  res.json(result.rows[0]);
});
