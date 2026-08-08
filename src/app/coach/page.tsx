import { requireRole } from '@/lib/auth';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

/**
 * Trainer home. Every query below is unfiltered by trainer on purpose: RLS
 * already scopes these tables to the caller's assigned clients through
 * trainer_owns_client(). Adding a redundant .eq() here would hide a policy
 * regression rather than surface it.
 *
 * No earnings, commission or rate appears anywhere in this route. Commission
 * is settled in person.
 */
export default async function CoachPage() {
  const user = await requireRole('trainer', 'admin');
  const supabase = await createClient();

  const today = new Date().toISOString().slice(0, 10);

  const [{ data: sessions }, { data: roster }] = await Promise.all([
    supabase
      .from('training_sessions')
      .select('id, session_date, status, client_id')
      .eq('session_date', today)
      .order('session_date'),
    supabase
      .from('clients')
      .select('id, primary_goal, status')
      .eq('status', 'active'),
  ]);

  const done = (sessions ?? []).filter((s) => s.status === 'completed').length;
  const left = (sessions ?? []).length - done;

  return (
    <>
      <div className="mb-6">
        <p className="font-mono text-[10.5px] uppercase tracking-[.14em] text-vf-mute">
          {new Date().toLocaleDateString('en-BS', {
            weekday: 'long', day: 'numeric', month: 'long',
            timeZone: 'America/Nassau',
          })}
        </p>
        <h1 className="mb-1.5 mt-1.5 text-[clamp(25px,4.2vw,34px)] font-bold leading-tight tracking-[-.02em]">
          {(sessions ?? []).length} sessions today.
        </h1>
        <p className="max-w-[60ch] text-[14px] text-vf-dim">
          {done} completed, {left} to go. {(roster ?? []).length} active clients
          assigned to you.
        </p>
      </div>

      <section className="rounded-vf border border-edge bg-surface p-[22px]">
        <h2 className="mb-4 text-[15px] font-semibold">Today&rsquo;s schedule</h2>
        {(sessions ?? []).length === 0 ? (
          <p className="text-[13px] text-vf-dim">
            Nothing booked today. Add a session from the schedule.
          </p>
        ) : (
          <ul className="divide-y divide-[rgba(255,255,255,.08)]">
            {(sessions ?? []).map((s) => (
              <li key={s.id} className="flex items-center gap-3 py-3">
                <span className="flex-1 text-[13.5px] font-semibold">
                  Session {s.id.slice(0, 8)}
                </span>
                <span className="font-mono text-[11px] uppercase tracking-[.07em] text-vf-mute">
                  {s.status}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </>
  );
}
