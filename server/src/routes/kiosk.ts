import { Router } from 'express';
import { config } from '../config.js';

export const kioskRouter = Router();

kioskRouter.get('/update', (req, res) => {
  const clientBuild = Number(req.query.build ?? 0);
  const { latestBuild, latestVersion, apkUrl, releaseNotes } = config.kiosk;

  if (!latestBuild || !apkUrl) {
    res.status(503).json({
      error: 'kiosk_not_configured',
      message: !apkUrl
        ? 'KIOSK_APK_URL is not set on the server.'
        : 'KIOSK_LATEST_BUILD is not set on the server.',
    });
    return;
  }

  if (clientBuild >= latestBuild) {
    res.status(204).end();
    return;
  }

  res.json({
    version_name: latestVersion,
    build_number: latestBuild,
    apk_url: apkUrl,
    release_notes: releaseNotes,
  });
});
