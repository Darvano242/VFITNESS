'use client';

import { useActionState } from 'react';
import { useSearchParams } from 'next/navigation';
import { Suspense } from 'react';
import { signIn, type AuthState } from './actions';

const initial: AuthState = { error: null };

function LoginForm() {
  const params = useSearchParams();
  const next = params.get('next') ?? '';
  const notice = params.get('error');

  const [state, formAction, pending] = useActionState(signIn, initial);

  const banner =
    notice === 'suspended'
      ? 'This account is suspended. Contact VFitness to reopen it.'
      : notice === 'no_profile'
        ? 'We could not load your account. Sign in again, and contact VFitness if it keeps happening.'
        : null;

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-[400px] flex-col justify-center px-5 py-16">
      <div className="mb-8 flex items-center gap-3">
        <div className="grid h-9 w-9 place-items-center rounded-[10px] bg-vf-grad text-white shadow-[0_6px_20px_-6px_rgba(61,125,255,.6)]">
          <svg width="17" height="17" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
            <path d="M13 2L4.5 13.5H11l-1 8.5 8.5-11.5H12l1-8.5z" />
          </svg>
        </div>
        <div className="text-[17px] font-bold tracking-[.01em]">
          VFITNESS<span className="text-vf-accent">.</span>
        </div>
      </div>

      <h1 className="mb-2 text-[27px] font-bold leading-tight tracking-[-.02em]">
        Sign in
      </h1>
      <p className="mb-7 text-[13.5px] text-vf-dim">
        Built for training, tracking, and real results.
      </p>

      {banner && (
        <div className="mb-5 rounded-[10px] border border-vf-gold/30 bg-vf-gold/[.07] px-3.5 py-3 text-[12.5px] text-vf-gold">
          {banner}
        </div>
      )}

      <form action={formAction} className="flex flex-col gap-3.5">
        <input type="hidden" name="next" value={next} />

        <div>
          <label
            htmlFor="email"
            className="mb-1.5 block font-mono text-[9.5px] uppercase tracking-[.09em] text-vf-mute"
          >
            Email
          </label>
          <input
            id="email"
            name="email"
            type="email"
            autoComplete="email"
            required
            className="w-full rounded-[10px] border border-edge bg-vf-bg2 px-3 py-2.5 text-[14px] text-vf-text outline-none transition-colors focus:border-vf-primary"
          />
        </div>

        <div>
          <label
            htmlFor="password"
            className="mb-1.5 block font-mono text-[9.5px] uppercase tracking-[.09em] text-vf-mute"
          >
            Password
          </label>
          <input
            id="password"
            name="password"
            type="password"
            autoComplete="current-password"
            required
            className="w-full rounded-[10px] border border-edge bg-vf-bg2 px-3 py-2.5 text-[14px] text-vf-text outline-none transition-colors focus:border-vf-primary"
          />
        </div>

        {state.error && (
          <p role="alert" className="text-[12.5px] text-vf-red">
            {state.error}
          </p>
        )}

        <button
          type="submit"
          disabled={pending}
          className="mt-1 w-full rounded-[10px] bg-vf-grad px-4 py-3 text-[13.5px] font-semibold text-white shadow-[0_6px_18px_-8px_rgba(61,125,255,.9)] transition-transform hover:-translate-y-px disabled:opacity-60 disabled:hover:translate-y-0"
        >
          {pending ? 'Signing in' : 'Sign in'}
        </button>
      </form>

      <div className="mt-6 flex items-center justify-between text-[12.5px]">
        <a href="/auth/forgot" className="text-vf-dim hover:text-vf-text">
          Forgot your password
        </a>
        <a href="/start" className="text-vf-accent hover:text-vf-text">
          Apply to train
        </a>
      </div>
    </main>
  );
}

export default function LoginPage() {
  return (
    <Suspense>
      <LoginForm />
    </Suspense>
  );
}
