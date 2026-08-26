import { Router } from 'express';

export const legalRouter = Router();

const page = (title: string, body: string) => `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${title} — Family Calendar</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 40rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; color: #222; }
    h1 { font-size: 1.5rem; }
    h2 { font-size: 1.1rem; margin-top: 1.5rem; }
  </style>
</head>
<body>
  <h1>${title}</h1>
  ${body}
  <p><small>Last updated: August 2026</small></p>
</body>
</html>`;

legalRouter.get('/legal/privacy', (_req, res) => {
  res.type('html').send(
    page(
      'Privacy Policy',
      `
      <p>Family Calendar is a private application used only by our household. It is not offered to the public.</p>
      <h2>Information we collect</h2>
      <ul>
        <li>Google Calendar events (read-only), after you sign in with Google and grant permission</li>
        <li>A family login password and device pairing codes you create in the app</li>
        <li>Calendar nicknames and colors you assign in the app</li>
      </ul>
      <h2>How we use information</h2>
      <p>Calendar data is used only to display a shared family calendar on our wall display and phones. We do not sell or share data with third parties.</p>
      <h2>Data storage</h2>
      <p>Data is stored on our private server. Google account tokens are stored encrypted.</p>
      <h2>Contact</h2>
      <p>Questions: contact the family administrator who manages this server.</p>
      `,
    ),
  );
});

legalRouter.get('/legal/terms', (_req, res) => {
  res.type('html').send(
    page(
      'Terms of Service',
      `
      <p>Family Calendar is a private, household-only service. By using it, you agree to these terms.</p>
      <h2>Use</h2>
      <p>Access is limited to members of our family. You may link your Google Calendar for read-only display. Do not share login credentials outside the household.</p>
      <h2>Availability</h2>
      <p>The service is provided as-is, without warranties. We may change or stop the service at any time.</p>
      <h2>Google Calendar</h2>
      <p>Your use of Google Calendar remains subject to Google's terms. We request read-only access only.</p>
      <h2>Contact</h2>
      <p>Questions: contact the family administrator who manages this server.</p>
      `,
    ),
  );
});
