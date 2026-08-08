import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import type { Database } from '@/lib/database.types';

/**
 * Server client for Server Components, Route Handlers and Server Actions.
 * Still the anon key, so RLS applies. Auth state comes from the cookie.
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Server Components cannot set cookies. The middleware refreshes
            // the session, so swallowing this is correct rather than fatal.
          }
        },
      },
    },
  );
}

/**
 * Service-role client. Bypasses RLS completely.
 *
 * Only for: the PayPal webhook, the data import scripts, and admin jobs that
 * genuinely need to write across users. Never import this into anything that
 * runs in the browser, and never reach for it to work around an RLS error.
 * An RLS error usually means the policy is wrong, not that the key is.
 */
export function createServiceClient() {
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!key) throw new Error('SUPABASE_SERVICE_ROLE_KEY is not set');

  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    key,
    {
      cookies: { getAll: () => [], setAll: () => {} },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
}
