/**
 * Types for the public schema.
 *
 * Regenerate from the live database rather than editing by hand once the
 * migrations are applied:
 *
 *   npm run db:types
 *
 * Kept minimal here: the tables the shell actually reads. The generated file
 * will cover all 24.
 */

export type UserRole = 'admin' | 'trainer' | 'client';
export type AccountStatus = 'active' | 'inactive' | 'suspended' | 'pending';
export type PackageStatus =
  | 'pending' | 'active' | 'completed' | 'expired' | 'cancelled';
export type SessionStatus =
  | 'scheduled' | 'completed' | 'no_show' | 'cancelled';
export type AppointmentStatus =
  | 'requested' | 'confirmed' | 'cancelled' | 'completed';
export type InvoiceStatus =
  | 'draft' | 'sent' | 'paid' | 'partial' | 'overdue' | 'void';
export type DifficultyLevel = 'beginner' | 'intermediate' | 'advanced';

export type Profile = {
  id: string;
  role: UserRole;
  full_name: string;
  email: string;
  phone: string | null;
  avatar_url: string | null;
  status: AccountStatus;
  timezone: string;
  created_at: string;
};

export type Client = {
  id: string;
  profile_id: string;
  assigned_trainer_id: string | null;
  primary_goal: string | null;
  height_cm: number | null;
  starting_weight_kg: number | null;
  target_weight_kg: number | null;
  joined_at: string;
  status: AccountStatus;
};

export type Trainer = {
  id: string;
  profile_id: string;
  bio: string | null;
  specialties: string[];
  gym_locations: string[];
  accepting_clients: boolean;
  status: AccountStatus;
  // commission_rate and hourly_rate are intentionally absent. Select on those
  // columns is revoked for anon and authenticated. Read trainer_directory.
};

/** The rollup behind the client dashboard. See migration 04. */
export type ClientDashboard = {
  client_id: string;
  profile_id: string;
  full_name: string;
  avatar_url: string | null;
  primary_goal: string | null;
  assigned_trainer_id: string | null;
  trainer_name: string | null;
  trainer_avatar_url: string | null;
  active_package_id: string | null;
  active_package_name: string | null;
  sessions_purchased: number | null;
  sessions_completed: number | null;
  sessions_remaining: number | null;
  package_expires_on: string | null;
  lifetime_sessions_completed: number;
  next_appointment_at: string | null;
  current_program_id: string | null;
  current_meal_plan_id: string | null;
  latest_weight_kg: number | null;
  starting_weight_kg: number | null;
  target_weight_kg: number | null;
  progress_photo_count: number;
  balance_outstanding: number;
};

export type TrainerDirectory = {
  id: string;
  profile_id: string;
  full_name: string;
  avatar_url: string | null;
  bio: string | null;
  specialties: string[];
  certifications: string[];
  years_experience: number | null;
  gym_locations: string[];
  accepting_clients: boolean;
  status: AccountStatus;
};

export type TrainingSession = {
  id: string;
  client_id: string;
  trainer_id: string | null;
  client_package_id: string | null;
  appointment_id: string | null;
  session_date: string;
  duration_minutes: number;
  status: SessionStatus;
  deducts_from_package: boolean;
  trainer_notes: string | null;
  client_rating: number | null;
  completed_at: string | null;
};

export type Application = {
  id: string;
  kind: 'client' | 'trainer';
  full_name: string;
  email: string;
  phone: string | null;
  goals: string | null;
  message: string | null;
  status: 'new' | 'reviewing' | 'approved' | 'rejected' | 'waitlist';
  reviewed_by: string | null;
  reviewed_at: string | null;
  created_at: string;
};

export type Invoice = {
  id: string;
  invoice_number: string;
  client_id: string;
  trainer_id: string | null;
  issued_on: string;
  due_on: string | null;
  total: number;
  amount_paid: number;
  currency: string;
  status: InvoiceStatus;
};

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: Profile;
        Insert: Partial<Profile> & {
          id: string;
          full_name: string;
          email: string;
        };
        Update: Partial<Profile>;
        Relationships: [];
      };
      clients: {
        Row: Client;
        Insert: Partial<Client> & { profile_id: string };
        Update: Partial<Client>;
        Relationships: [];
      };
      trainers: {
        Row: Trainer;
        Insert: Partial<Trainer> & { profile_id: string };
        Update: Partial<Trainer>;
        Relationships: [];
      };
      training_sessions: {
        Row: TrainingSession;
        Insert: Partial<TrainingSession> & {
          client_id: string;
          session_date: string;
        };
        Update: Partial<TrainingSession>;
        Relationships: [];
      };
      applications: {
        Row: Application;
        Insert: Partial<Application> & { full_name: string; email: string };
        Update: Partial<Application>;
        Relationships: [];
      };
      invoices: {
        Row: Invoice;
        Insert: Partial<Invoice> & { invoice_number: string; client_id: string };
        Update: Partial<Invoice>;
        Relationships: [];
      };
    };
    Views: {
      client_dashboard: { Row: ClientDashboard; Relationships: [] };
      trainer_directory: { Row: TrainerDirectory; Relationships: [] };
    };
    Functions: Record<never, never>;
    Enums: {
      user_role: UserRole;
      account_status: AccountStatus;
      package_status: PackageStatus;
      session_status: SessionStatus;
      appointment_status: AppointmentStatus;
      invoice_status: InvoiceStatus;
      difficulty_level: DifficultyLevel;
    };
    CompositeTypes: Record<never, never>;
  };
};
