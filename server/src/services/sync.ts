import { pool } from '../db/pool.js';
import { syncCalendarConnection } from '../routes/calendars.js';

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
        await syncCalendarConnection(row.id);
      } catch (error) {
        const label = await pool.query<{
          google_account_email: string | null;
          feed_url: string | null;
          nickname: string;
        }>(
          `SELECT google_account_email, feed_url, nickname
           FROM calendar_connections WHERE id = $1`,
          [row.id],
        );
        const info = label.rows[0];
        const name =
          info?.google_account_email ??
          info?.feed_url ??
          info?.nickname ??
          row.id;
        console.error(`Sync failed for ${name}:`, error);
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
