type GaxiosLikeError = {
  response?: {
    data?: {
      error?: string;
      error_description?: string;
    };
  };
  message?: string;
};

export function formatSyncError(error: unknown): string {
  const err = error as GaxiosLikeError;
  const oauthError = err.response?.data?.error;
  const oauthDescription = err.response?.data?.error_description;

  if (oauthError === 'invalid_grant') {
    return 'Google refresh token expired or revoked — re-link this calendar in the mobile app (Settings → Link Google Calendar).';
  }

  if (oauthError && oauthDescription) {
    return `${oauthError}: ${oauthDescription}`;
  }

  if (error instanceof Error && error.message) {
    return error.message;
  }

  return String(error);
}

export function isRevokedGoogleTokenError(error: unknown): boolean {
  const err = error as GaxiosLikeError;
  return err.response?.data?.error === 'invalid_grant';
}
