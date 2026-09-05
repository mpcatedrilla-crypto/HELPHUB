const jsonHeaders = { 'Content-Type': 'application/json' };

type WebhookPayload = {
  type?: string;
  table?: string;
  record?: Record<string, unknown>;
};

function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function base64Url(input: Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

async function googleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: env('FIREBASE_CLIENT_EMAIL'),
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const pem = env('FIREBASE_PRIVATE_KEY').replaceAll('\\n', '\n');
  const der = Uint8Array.from(
    atob(pem.replace(/-----[^-]+-----|\s/g, '')),
    (char) => char.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth-grant-type:jwt-bearer',
      assertion,
    }),
  });
  const result = await response.json();
  if (!response.ok) throw new Error(`Google OAuth failed: ${JSON.stringify(result)}`);
  return result.access_token;
}

Deno.serve(async (request) => {
  try {
    if (request.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: jsonHeaders });
    }
    if (request.headers.get('x-webhook-secret') !== env('SOS_WEBHOOK_SECRET')) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: jsonHeaders });
    }

    const payload = await request.json() as WebhookPayload;
    const report = payload.record ?? {};
    if (payload.type !== 'INSERT' || payload.table !== 'reports' || report.is_critical_override !== true) {
      return new Response(JSON.stringify({ skipped: true }), { headers: jsonHeaders });
    }

    const supabaseUrl = env('SUPABASE_URL');
    const serviceKey = env('SUPABASE_SERVICE_ROLE_KEY');
    const tokenResponse = await fetch(`${supabaseUrl}/rest/v1/admin_push_tokens?select=token`, {
      headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` },
    });
    if (!tokenResponse.ok) throw new Error(await tokenResponse.text());
    const deviceRows = await tokenResponse.json() as Array<{ token: string }>;
    if (deviceRows.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { headers: jsonHeaders });
    }

    const accessToken = await googleAccessToken();
    const projectId = env('FIREBASE_PROJECT_ID');
    const title = String(report.title ?? report.emergency_type ?? 'Emergency SOS');
    const reportId = String(report.id ?? '');
    const results = await Promise.all(deviceRows.map(async ({ token }) => {
      const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: 'CRITICAL SOS ALERT', body: title },
            data: { type: 'critical_sos', report_id: reportId, report_title: title },
            android: {
              priority: 'high',
              notification: {
                channel_id: 'emergency_sos_v4',
                sound: 'siren',
                visibility: 'public',
                default_vibrate_timings: true,
              },
            },
          },
        }),
      });
      return response.ok;
    }));

    return new Response(JSON.stringify({
      sent: results.filter(Boolean).length,
      failed: results.filter((ok) => !ok).length,
    }), { headers: jsonHeaders });
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ error: String(error) }), { status: 500, headers: jsonHeaders });
  }
});
