'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { homeFor } from '@/lib/auth';

export type AuthState = { error: string | null };

export async function signIn(
  _prev: AuthState,
  formData: FormData,
): Promise<AuthState> {
  const email = String(formData.get('email') ?? '').trim();
  const password = String(formData.get('password') ?? '');
  const next = String(formData.get('next') ?? '');

  if (!email || !password) {
    return { error: 'Enter your email and password.' };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    // Deliberately vague. Saying which of the two was wrong tells an attacker
    // whether an address is registered.
    return { error: 'That email and password do not match an account.' };
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('role, status')
    .eq('id', data.user.id)
    .single();

  if (profile?.status === 'suspended') {
    await supabase.auth.signOut();
    return { error: 'This account is suspended. Contact VFitness to reopen it.' };
  }

  revalidatePath('/', 'layout');
  redirect(next && next.startsWith('/') ? next : homeFor(profile?.role ?? 'client'));
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  revalidatePath('/', 'layout');
  redirect('/login');
}

/**
 * Password reset. This is the path every migrated client takes at cutover,
 * because Firebase scrypt hashes cannot be carried into Supabase GoTrue.
 */
export async function requestReset(
  _prev: AuthState,
  formData: FormData,
): Promise<AuthState> {
  const email = String(formData.get('email') ?? '').trim();
  if (!email) return { error: 'Enter your email address.' };

  const supabase = await createClient();
  await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${process.env.NEXT_PUBLIC_SITE_URL ?? ''}/auth/reset`,
  });

  // Always report success, whether or not the address exists, so this cannot
  // be used to enumerate accounts.
  return { error: null };
}
