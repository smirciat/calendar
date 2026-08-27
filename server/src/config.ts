import { config as loadEnv } from 'dotenv';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
loadEnv({ path: resolve(projectRoot, '.env') });

function required(name: string, fallback?: string): string {
  const value = process.env[name] ?? fallback;
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function buildDatabaseUrl(): string {
  if (process.env.DATABASE_URL) {
    return process.env.DATABASE_URL;
  }

  const user = required('POSTGRES_USER');
  const password = required('POSTGRES_PASSWORD');
  const host = process.env.POSTGRES_HOST ?? 'localhost';
  const port = process.env.POSTGRES_PORT ?? '5432';
  const database = required('POSTGRES_DB');
  const encodedUser = encodeURIComponent(user);
  const encodedPassword = encodeURIComponent(password);

  return `postgres://${encodedUser}:${encodedPassword}@${host}:${port}/${database}`;
}

export const config = {
  port: Number(process.env.PORT ?? 3847),
  nodeEnv: process.env.NODE_ENV ?? 'development',
  baseUrl: required('BASE_URL', 'https://smircich.ddns.net'),
  databaseUrl: buildDatabaseUrl(),
  jwtSecret: required('JWT_SECRET'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '365d',
  tokenEncryptionKey: required('TOKEN_ENCRYPTION_KEY'),
  google: {
    clientId: process.env.GOOGLE_CLIENT_ID ?? '',
    clientSecret: process.env.GOOGLE_CLIENT_SECRET ?? '',
    redirectUri:
      process.env.GOOGLE_REDIRECT_URI ??
      `${required('BASE_URL', 'https://smircich.ddns.net')}/api/v1/calendars/oauth/callback`,
  },
  syncIntervalMs: Number(process.env.SYNC_INTERVAL_MS ?? 60_000),
  /** IANA zone for family wall/phones (Oregon default). Used when parsing Google/ICS times. */
  familyTimeZone: process.env.FAMILY_TIMEZONE ?? 'America/Los_Angeles',
  kiosk: {
    latestVersion: process.env.KIOSK_LATEST_VERSION ?? '',
    latestBuild: Number(process.env.KIOSK_LATEST_BUILD ?? 0),
    apkUrl: process.env.KIOSK_APK_URL ?? '',
    releaseNotes: process.env.KIOSK_RELEASE_NOTES ?? '',
  },
};

export function googleOAuthConfigured(): boolean {
  return Boolean(
    config.google.clientId &&
      config.google.clientSecret &&
      config.google.redirectUri,
  );
}
