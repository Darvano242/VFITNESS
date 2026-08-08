import { requireRole } from '@/lib/auth';
import { createClient } from '@/lib/supabase/server';
import type { ClientDashboard } from '@/lib/database.types';

export const dynamic = 'force-dynamic';

function Panel({
  title,
  badge,
  children,
}: {
  title: string;
  badge?: string;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-vf border border-edge bg-surface p-[22px]">
      <div className="mb-4 flex items-baseline justify-between gap-3">
        <h2 className="text-[15px] font-semibold tracking-[-.005em]">{title}</h2>
        {badge && (
          <span className="whitespace-nowrap rounded-full border border-edge px-2.5 py-1 font-mono text-[10.5px] uppercase tracking-[.07em] text-vf-dim">
            {badge}
          </span>
        )}
      </div>
      {children}
    </section>
  );
}

function money(n: number | null | undefined) {
  return `$${(n ?? 0).toFixed(2)}`;
}

function whenLocal(iso: string | null) {
  if (!iso) return null;
  // Nassau time. The profiles table defaults timezone to America/Nassau.
  return new Date(iso).toLocaleString('en-BS', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: 'numeric',
    minute: '2-digit',
    timeZone: 'America/Nassau',
  });
}

export default async function DashboardPage() {
  const user = await requireRole('client');
  const supabase = await createClient();

  // One query. The view does the joins and the rollups, and RLS restricts it
  // to this client's own row.
  const { data, error } = await supabase
    .from('client_dashboard')
    .select('*')
    .eq('profile_id', user.id)
    .maybeSingle<ClientDashboard>();

  if (error) {
    return (
      <Panel title="Dashboard">
        <p className="text-[13px] text-vf-dim">
          We could not load your training right now. Refresh, and contact
          VFitness if it keeps happening.
        </p>
      </Panel>
    );
  }

  // No client row yet. This is what an approved application looks like before
  // a package has been sold, so the empty state is an invitation, not an error.
  if (!data) {
    return (
      <Panel title="Welcome to VFitness">
        <p className="mb-4 text-[13px] leading-relaxed text-vf-dim">
          Your account is set up. Once your first block of sessions is booked,
          your trainer, schedule and programme will appear here.
        </p>
        <a
          href="/pricing"
          className="inline-flex rounded-[10px] bg-vf-grad px-4 py-2.5 text-[13px] font-semibold text-white"
        >
          See packages
        </a>
      </Panel>
    );
  }

  const remaining = data.sessions_remaining ?? 0;
  const purchased = data.sessions_purchased ?? 0;
  const nextAppt = whenLocal(data.next_appointment_at);

  return (
    <>
      <div className="mb-6">
        <p className="font-mono text-[10.5px] uppercase tracking-[.14em] text-vf-mute">
          {new Date().toLocaleDateString('en-BS', {
            weekday: 'long',
            day: 'numeric',
            month: 'long',
            timeZone: 'America/Nassau',
          })}
        </p>
        <h1 className="mb-1.5 mt-1.5 text-[clamp(26px,4.4vw,36px)] font-bold leading-tight tracking-[-.02em]">
          {remaining > 0
            ? `${remaining} left on the bar.`
            : 'Time for your next block.'}
        </h1>
        <p className="max-w-[56ch] text-[14px] text-vf-dim">
          {data.trainer_name
            ? `You are training with ${data.trainer_name}.`
            : 'A trainer has not been assigned yet.'}
          {nextAppt ? ` Next session ${nextAppt}.` : ' No session booked yet.'}
        </p>
      </div>

      <div className="mb-[18px] grid gap-[18px] md:grid-cols-3">
        <Panel title="Sessions" badge={data.active_package_name ?? 'No package'}>
          <div className="flex items-baseline gap-2.5">
            <span className="tnum text-[52px] font-extrabold leading-none tracking-[-.03em]">
              {remaining}
            </span>
            <span className="text-[13px] text-vf-dim">of {purchased}</span>
          </div>
          <div className="mt-4 h-1.5 overflow-hidden rounded-full bg-white/[.07]">
            <div
              className="h-full rounded-full bg-vf-grad"
              style={{
                width: purchased
                  ? `${((data.sessions_completed ?? 0) / purchased) * 100}%`
                  : '0%',
              }}
            />
          </div>
          <p className="mt-3 text-[12px] text-vf-mute">
            {data.sessions_completed ?? 0} completed.
            {data.package_expires_on
              ? ` Expires ${new Date(data.package_expires_on).toLocaleDateString('en-BS', { day: 'numeric', month: 'short', year: 'numeric' })}.`
              : ''}
          </p>
        </Panel>

        <Panel title="Your trainer">
          {data.trainer_name ? (
            <div className="flex items-center gap-3">
              <span className="grid h-[52px] w-[52px] place-items-center rounded-[13px] border border-edge bg-vf-grad text-[17px] font-bold text-white">
                {data.trainer_name
                  .split(' ')
                  .slice(0, 2)
                  .map((p) => p[0])
                  .join('')}
              </span>
              <div>
                <p className="text-[16px] font-semibold">{data.trainer_name}</p>
                <p className="mt-0.5 text-[12.5px] text-vf-dim">
                  {data.primary_goal ?? 'Training'}
                </p>
              </div>
            </div>
          ) : (
            <p className="text-[13px] text-vf-dim">
              Not assigned yet. VFitness will match you at your consultation.
            </p>
          )}
        </Panel>

        <Panel title="Progress">
          <div className="flex items-baseline gap-2.5">
            <span className="tnum text-[32px] font-extrabold tracking-[-.02em]">
              {data.latest_weight_kg ?? '—'}
            </span>
            <span className="text-[13px] text-vf-dim">kg</span>
          </div>
          <p className="mt-2 text-[12.5px] text-vf-mute">
            {data.starting_weight_kg && data.latest_weight_kg
              ? `${(data.latest_weight_kg - data.starting_weight_kg).toFixed(1)} kg since you started.`
              : 'Log a weight to start tracking.'}
          </p>
          <p className="mt-1 text-[12.5px] text-vf-mute">
            {data.progress_photo_count} progress photos saved.
          </p>
        </Panel>
      </div>

      {data.balance_outstanding > 0 && (
        <Panel title="Billing" badge={`${money(data.balance_outstanding)} due`}>
          <p className="mb-4 text-[13px] text-vf-dim">
            You have an outstanding balance on your account.
          </p>
          <a
            href="/dashboard/billing"
            className="inline-flex rounded-[10px] bg-vf-grad px-4 py-2.5 text-[13px] font-semibold text-white"
          >
            Pay balance
          </a>
        </Panel>
      )}
    </>
  );
}
