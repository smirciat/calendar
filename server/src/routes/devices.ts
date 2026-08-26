import { Router } from 'express';
import { pool } from '../db/pool.js';
import {
  requireFamilyAuth,
  signDeviceToken,
} from '../middleware/auth.js';
import { hashToken, randomPairingCode, randomToken } from '../services/crypto.js';

export const devicesRouter = Router();

devicesRouter.post('/pairing-codes', requireFamilyAuth, async (req, res) => {
  const code = randomPairingCode();
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

  await pool.query(
    `INSERT INTO pairing_codes (family_id, code, expires_at)
     VALUES ($1, $2, $3)`,
    [req.auth!.familyId, code, expiresAt],
  );

  res.status(201).json({
    code,
    expiresAt: expiresAt.toISOString(),
    instructions:
      'On the wall display, enter the server URL and this pairing code.',
  });
});

devicesRouter.post('/pair', async (req, res) => {
  const { code, name } = req.body as { code?: string; name?: string };
  if (!code?.trim()) {
    res.status(400).json({ error: 'Pairing code required' });
    return;
  }

  const normalized = code.trim().toUpperCase();
  const pairing = await pool.query<{
    id: string;
    family_id: string;
    expires_at: Date;
    used_at: Date | null;
  }>(
    `SELECT id, family_id, expires_at, used_at
     FROM pairing_codes
     WHERE code = $1`,
    [normalized],
  );

  if (pairing.rowCount === 0) {
    res.status(404).json({ error: 'Invalid pairing code' });
    return;
  }

  const row = pairing.rows[0];
  if (row.used_at) {
    res.status(410).json({ error: 'Pairing code already used' });
    return;
  }
  if (row.expires_at.getTime() < Date.now()) {
    res.status(410).json({ error: 'Pairing code expired' });
    return;
  }

  const deviceToken = randomToken();
  const tokenHash = hashToken(deviceToken);
  const deviceName = name?.trim() || 'Wall display';

  const device = await pool.query<{ id: string }>(
    `INSERT INTO devices (family_id, name, token_hash)
     VALUES ($1, $2, $3)
     RETURNING id`,
    [row.family_id, deviceName, tokenHash],
  );

  await pool.query(
    'UPDATE pairing_codes SET used_at = now() WHERE id = $1',
    [row.id],
  );

  const deviceId = device.rows[0].id;
  const jwt = signDeviceToken(row.family_id, deviceId);

  res.status(201).json({
    token: jwt,
    deviceToken,
    deviceId,
    familyId: row.family_id,
    name: deviceName,
  });
});

devicesRouter.get('/', requireFamilyAuth, async (req, res) => {
  const result = await pool.query(
    `SELECT id, name, created_at, last_seen_at
     FROM devices
     WHERE family_id = $1
     ORDER BY created_at DESC`,
    [req.auth!.familyId],
  );
  res.json(result.rows);
});
