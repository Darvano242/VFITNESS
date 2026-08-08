import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import type { UserRole } from '@/lib/database.types';

export type SessionUser = {
  id: string;
  email: string;
  fullName: string;
  avatarUrl: string | null;
  role: UserRole;
  /** clients.id when the user is a client, otherwise null. */
  clientId: string | null;
  /** trainers.id when the user is a trainer, otherwise null. */
  trainerId: string | null;
};

/**
 * Loads the signed-in user plus their role and the id of their client or
 * trainer row. Redirects to /login when there is no session.
 *
 * Role lives in the database, never in JWT metadata a client could influence.
 * The handle_new_user trigger forces role 'client' on signup and a trigger
 * blocks self-escalation, so this read is trustworthy.
 */
export async function requireUser(): Promise<SessionUser> {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect('/login');

  const { data: profile, error } = await supabase
    .from('profiles')
    .select('id, full_name, email, avatar_url, role, status')
    .eq('id', user.id)
    .single();

  // A session with no profile row means the trigger did not fire. Signing them
  // out is safer than guessing a role.
  if (error || !profile) {
    await supabase.auth.signOut();
    redirect('/login?error=no_profile');
  }

  if (profile.status === 'suspended') {
    await supabase.auth.signOut();
    redirect('/login?error=suspended');
  }

  let clientId: string | null = null;
  let trainerId: string | null = null;

  if (profile.role === 'client') {
    const { data } = await supabase
      .from('clients')
      .select('id')
      .eq('profile_id', user.id)
      .maybeSingle();
    clientId = data?.id ?? null;
  } else if (profile.role === 'trainer') {
    const { data } = await supabase
      .from('trainers')
      .select('id')
      .eq('profile_id', user.id)
      .maybeSingle();
    trainerId = data?.id ?? null;
  }

  return {
    id: profile.id,
    email: profile.email,
    fullName: profile.full_name,
    avatarUrl: profile.avatar_url,
    role: profile.role,
    clientId,
    trainerId,
  };
}

/**
 * Requires one of the given roles. Anyone else is bounced to their own home
 * rather than shown a 403, so a mistyped URL is not a dead end.
 *
 * This is defence in depth, not the only defence. RLS already blocks the data;
 * this just stops the wrong shell rendering.
 */
export async function requireRole(...allowed: UserRole[]): Promise<SessionUser> {
  const user = await requireUser();
  if (!allowed.includes(user.role)) redirect(homeFor(user.role));
  return user;
}

export function homeFor(role: UserRole): string {
  switch (role) {
    case 'admin':
      return '/admin';
    case 'trainer':
      return '/coach';
    default:
      return '/dashboard';
  }
}
