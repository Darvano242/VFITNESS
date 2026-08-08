import { requireRole } from '@/lib/auth';
import { AppShell } from '@/components/AppShell';

/**
 * Client area. requireRole bounces a trainer or admin to their own home.
 * RLS is what actually protects the data; this keeps the wrong shell from
 * rendering.
 */
export default async function ClientLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await requireRole('client');
  return <AppShell user={user}>{children}</AppShell>;
}
