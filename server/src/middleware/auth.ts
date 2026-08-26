import type { Request, Response, NextFunction } from 'express';
import type { SignOptions } from 'jsonwebtoken';
import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { pool } from '../db/pool.js';
import { hashToken } from '../services/crypto.js';

export type AuthKind = 'family' | 'device';

export interface FamilyAuth {
  kind: 'family';
  familyId: string;
}

export interface DeviceAuth {
  kind: 'device';
  familyId: string;
  deviceId: string;
}

export type AuthContext = FamilyAuth | DeviceAuth;

declare global {
  namespace Express {
    interface Request {
      auth?: AuthContext;
    }
  }
}

export function signFamilyToken(familyId: string): string {
  const options: SignOptions = { expiresIn: config.jwtExpiresIn as SignOptions['expiresIn'] };
  return jwt.sign({ kind: 'family', familyId }, config.jwtSecret, options);
}

export function requireFamilyAuth(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing authorization' });
    return;
  }

  try {
    const payload = jwt.verify(header.slice(7), config.jwtSecret) as {
      kind?: string;
      familyId?: string;
    };
    if (payload.kind !== 'family' || !payload.familyId) {
      res.status(401).json({ error: 'Invalid token' });
      return;
    }
    req.auth = { kind: 'family', familyId: payload.familyId };
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}

export async function requireFamilyOrDeviceAuth(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing authorization' });
    return;
  }

  const token = header.slice(7);

  try {
    const payload = jwt.verify(token, config.jwtSecret) as {
      kind?: string;
      familyId?: string;
      deviceId?: string;
    };

    if (payload.kind === 'family' && payload.familyId) {
      req.auth = { kind: 'family', familyId: payload.familyId };
      next();
      return;
    }

    if (payload.kind === 'device' && payload.familyId && payload.deviceId) {
      req.auth = {
        kind: 'device',
        familyId: payload.familyId,
        deviceId: payload.deviceId,
      };
      await pool.query(
        'UPDATE devices SET last_seen_at = now() WHERE id = $1',
        [payload.deviceId],
      );
      next();
      return;
    }
  } catch {
    // fall through to device token lookup
  }

  const tokenHash = hashToken(token);
  const result = await pool.query<{
    id: string;
    family_id: string;
  }>('SELECT id, family_id FROM devices WHERE token_hash = $1', [tokenHash]);

  if (result.rowCount === 0) {
    res.status(401).json({ error: 'Invalid token' });
    return;
  }

  const device = result.rows[0];
  req.auth = {
    kind: 'device',
    familyId: device.family_id,
    deviceId: device.id,
  };
  await pool.query('UPDATE devices SET last_seen_at = now() WHERE id = $1', [
    device.id,
  ]);
  next();
}

export function signDeviceToken(familyId: string, deviceId: string): string {
  const options: SignOptions = { expiresIn: config.jwtExpiresIn as SignOptions['expiresIn'] };
  return jwt.sign({ kind: 'device', familyId, deviceId }, config.jwtSecret, options);
}
