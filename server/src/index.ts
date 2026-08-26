import cors from 'cors';
import express from 'express';
import { config } from './config.js';
import { migrate } from './db/migrate.js';
import { authRouter } from './routes/auth.js';
import { calendarsRouter } from './routes/calendars.js';
import { devicesRouter } from './routes/devices.js';
import { eventsRouter } from './routes/events.js';
import { healthRouter } from './routes/health.js';
import { startSyncScheduler, stopSyncScheduler } from './services/sync.js';

async function main(): Promise<void> {
  await migrate();

  const app = express();
  app.use(cors());
  app.use(express.json());

  app.use(healthRouter);
  app.use('/api/v1/auth', authRouter);
  app.use('/api/v1/devices', devicesRouter);
  app.use('/api/v1/calendars', calendarsRouter);
  app.use('/api/v1/events', eventsRouter);

  app.use(
    (
      err: Error,
      _req: express.Request,
      res: express.Response,
      _next: express.NextFunction,
    ) => {
      console.error(err);
      res.status(500).json({ error: 'Internal server error' });
    },
  );

  startSyncScheduler(config.syncIntervalMs);

  const server = app.listen(config.port, () => {
    console.log(`Family calendar server listening on :${config.port}`);
  });

  const shutdown = () => {
    stopSyncScheduler();
    server.close(() => process.exit(0));
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
