import { requireRole } from '@/lib/auth';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

function Stat({ value, label, note }: { value: string; label: string; note?: string }) {
  return (
    <div className="rounded-vf border border-edge bg-surface p-4">
      <div className="tnum text-[27px] font-extrabold leading-none tracking-[-.025em]">
        {value}
      </div>
      <div className="mt-2 font-mono text-[9.5px] uppercase tracking-[.1em] text-vf-mute">
        {label}
      </div>
      {note && <div className="mt-1 text-[11px] text-vf-dim">{note}</div>}
    </div>
  );
}

export default async function AdminPage() {
  await requireRole('admin');
  const supabase = await createClient();

  const [clients, trainers, openApps, openInvoices] = await Promise.all([
    supabase.from('clients').select('id', { count: 'exact', head: true }).eq('status', 'active'),
    supabase.from('trainers').select('id', { count: 'exact', head: true }).eq('status', 'active'),
    supabase.from('applications').select('id', { count: 'exact', head: true }).eq('status', 'new'),
    supabase.from('invoices').select('id', { count: 'exact', head: true })
      .in('status', ['sent', 'partial', 'overdue']),
  ]);

  return (
    <>
      <div className="mb-6">
        <h1 className="mb-1.5 text-[clamp(23px,3.4vw,31px)] font-bold leading-tight tracking-[-.02em]">
          Everything, at once.
        </h1>
        <p className="max-w-[62ch] text-[13.5px] text-vf-dim">
          {openApps.count ?? 0} applications waiting and {openInvoices.count ?? 0} open
          invoices.
        </p>
      </div>

      <div className="grid grid-cols-2 gap-[18px] md:grid-cols-4">
        <Stat value={String(clients.count ?? 0)} label="Active clients" />
        <Stat value={String(trainers.count ?? 0)} label="Trainers" />
        <Stat value={String(openApps.count ?? 0)} label="Open applications" note="Unreviewed" />
        <Stat value={String(openInvoices.count ?? 0)} label="Open invoices" />
      </div>
    </>
  );
}
