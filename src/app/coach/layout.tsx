import { requireRole } from '@/lib/auth';
import { AppShell } from '@/components/AppShell';

/** Trainer area. Admins are allowed in so they can see what trainers see. */
export default async function CoachLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await requireRole('trainer', 'admin');
  return <AppShell user={user}>{children}</AppShell>;
}
