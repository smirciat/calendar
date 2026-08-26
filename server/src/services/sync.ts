import { pool } from '../db/pool.js';
import { listGoogleEventsForConnection } from '../routes/calendars.js';

let syncTimer: NodeJS.Timeout | null = null;
let syncing = false;

export async function syncAllCalendars(): Promise<void> {
  if (syncing) return;
  syncing = true;
  try {
    const result = await pool.query<{ id: string }>(
      'SELECT id FROM calendar_connections',
    );
    for (const row of result.rows) {
      try {
        await listGoogleEventsForConnection(row.id);
      } catch (error) {
        const email = await pool.query<{ google_account_email: string }>(
          'SELECT google_account_email FROM calendar_connections WHERE id = $1',
          [row.id],
        );
        console.error(
          `Sync failed for ${email.rows[0]?.google_account_email ?? row.id}:`,
          error,
        );
      }
    }
  } finally {
    syncing = false;
  }
}

export function startSyncScheduler(intervalMs: number): void {
  if (syncTimer) clearInterval(syncTimer);
  void syncAllCalendars();
  syncTimer = setInterval(() => {
    void syncAllCalendars();
  }, intervalMs);
}

export function stopSyncScheduler(): void {
  if (syncTimer) {
    clearInterval(syncTimer);
    syncTimer = null;
  }
}
