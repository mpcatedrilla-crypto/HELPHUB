# Critical SOS push setup

Deploy with `supabase functions deploy send-critical-sos --no-verify-jwt`.

Configure these Edge Function secrets without committing their values:

- `FIREBASE_PROJECT_ID=helphub-15f1d`
- `FIREBASE_CLIENT_EMAIL` from a Firebase service account
- `FIREBASE_PRIVATE_KEY` from that service account
- `SOS_WEBHOOK_SECRET` as a long random value

Create a Supabase Database Webhook for `public.reports` on `INSERT`. Point it to
the deployed function URL and add an `x-webhook-secret` header matching the
`SOS_WEBHOOK_SECRET` value.
