import Link from 'next/link';
import type { SessionUser } from '@/lib/auth';
import { signOut } from '@/app/login/actions';

type NavLink = { href: string; label: string };

/**
 * Nav is derived from role here, on the server, so a client-side toggle can
 * never reveal a link the user is not entitled to. Even if it did, the route
 * layout and RLS would both refuse.
 */
function navFor(user: SessionUser): NavLink[] {
  switch (user.role) {
    case 'admin':
      return [
        { href: '/admin', label: 'Overview' },
        { href: '/admin/applications', label: 'Applications' },
        { href: '/admin/clients', label: 'Clients' },
        { href: '/admin/trainers', label: 'Trainers' },
        { href: '/admin/storefront', label: 'Storefront' },
        { href: '/admin/invoices', label: 'Invoices' },
      ];
    case 'trainer':
      return [
        { href: '/coach', label: 'Today' },
        { href: '/coach/clients', label: 'My clients' },
        { href: '/coach/workouts', label: 'Workouts' },
        { href: '/coach/schedule', label: 'Schedule' },
      ];
    default:
      return [
        { href: '/dashboard', label: 'Dashboard' },
        { href: '/dashboard/workouts', label: 'Workouts' },
        { href: '/dashboard/nutrition', label: 'Nutrition' },
        { href: '/dashboard/progress', label: 'Progress' },
        { href: '/dashboard/programs', label: 'Programs' },
        { href: '/dashboard/billing', label: 'Billing' },
      ];
  }
}

function initials(name: string) {
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase() ?? '')
    .join('');
}

export function AppShell({
  user,
  children,
}: {
  user: SessionUser;
  children: React.ReactNode;
}) {
  const links = navFor(user);

  return (
    <div className="mx-auto max-w-[1400px] px-5 pb-20 pt-6 md:px-7">
      <header className="mb-7 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Link href="/" className="flex items-center gap-2.5">
            <span className="grid h-8 w-8 place-items-center rounded-[9px] bg-vf-grad text-white shadow-[0_6px_18px_-6px_rgba(61,125,255,.6)]">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
                <path d="M13 2L4.5 13.5H11l-1 8.5 8.5-11.5H12l1-8.5z" />
              </svg>
            </span>
            <span className="text-[16px] font-bold tracking-[.01em]">
              VFITNESS<span className="text-vf-accent">.</span>
            </span>
          </Link>

          {user.role === 'trainer' && (
            <span className="rounded-full border border-vf-accent/30 bg-vf-accent/[.08] px-2.5 py-1 font-mono text-[10px] uppercase tracking-[.09em] text-vf-accent">
              Your clients only
            </span>
          )}
          {user.role === 'admin' && (
            <span className="rounded-full border border-vf-primary/40 bg-vf-primary/[.12] px-2.5 py-1 font-mono text-[10px] uppercase tracking-[.09em] text-vf-text">
              Admin
            </span>
          )}
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2.5">
            <span className="grid h-9 w-9 place-items-center rounded-full bg-vf-grad text-[12.5px] font-bold text-white">
              {initials(user.fullName)}
            </span>
            <span className="hidden sm:block">
              <span className="block text-[13px] font-semibold leading-tight">
                {user.fullName}
              </span>
              <span className="block font-mono text-[10px] uppercase tracking-[.08em] text-vf-mute">
                {user.role}
              </span>
            </span>
          </div>
          <form action={signOut}>
            <button
              type="submit"
              className="rounded-[9px] border border-edge px-3 py-2 text-[12.5px] text-vf-dim transition-colors hover:border-edge-hi hover:text-vf-text"
            >
              Sign out
            </button>
          </form>
        </div>
      </header>

      <nav
        aria-label="Sections"
        className="mb-7 flex gap-1.5 overflow-x-auto border-b border-edge pb-3"
      >
        {links.map((l) => (
          <Link
            key={l.href}
            href={l.href}
            className="whitespace-nowrap rounded-full border border-edge px-3.5 py-2 font-mono text-[10.5px] uppercase tracking-[.08em] text-vf-dim transition-colors hover:border-edge-hi hover:text-vf-text"
          >
            {l.label}
          </Link>
        ))}
      </nav>

      {children}
    </div>
  );
}
