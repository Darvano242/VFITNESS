import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { homeFor } from '@/lib/auth';

/**
 * Root. A signed-in user goes to their own dashboard; everyone else sees the
 * public storefront. The storefront is the next build, so for now this sends
 * visitors to sign in.
 */
export default async function Home() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) redirect('/login');

  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single();

  redirect(homeFor(profile?.role ?? 'client'));
}
