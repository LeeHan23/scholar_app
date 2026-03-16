// Auto-generated types matching the Supabase schema.
// To regenerate: npx supabase gen types typescript --project-id <project-id> > src/types/database.ts

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export interface Database {
  public: {
    Tables: {
      papers: {
        Row: {
          id: number;
          title: string;
          authors: string;
          journal: string | null;
          year: number | null;
          doi: string | null;
          abstract: string | null;
          status: 'unread' | 'read';
          user_id: string;
          project_id: number | null;
          tags: string | null;
          location_name: string | null;
          latitude: number | null;
          longitude: number | null;
          page_number: number | null;
          pdf_url: string | null;
          read_at: string | null;
          created_at: string;
        };
        Insert: {
          id?: never;
          title: string;
          authors: string;
          journal?: string | null;
          year?: number | null;
          doi?: string | null;
          abstract?: string | null;
          status?: 'unread' | 'read';
          user_id: string;
          project_id?: number | null;
          tags?: string | null;
          location_name?: string | null;
          latitude?: number | null;
          longitude?: number | null;
          page_number?: number | null;
          pdf_url?: string | null;
          read_at?: string | null;
          created_at?: string;
        };
        Update: {
          title?: string;
          authors?: string;
          journal?: string | null;
          year?: number | null;
          doi?: string | null;
          abstract?: string | null;
          status?: 'unread' | 'read';
          project_id?: number | null;
          tags?: string | null;
          location_name?: string | null;
          latitude?: number | null;
          longitude?: number | null;
          page_number?: number | null;
          pdf_url?: string | null;
          read_at?: string | null;
        };
      };
      projects: {
        Row: {
          id: number;
          name: string;
          user_id: string;
          created_at: string;
        };
        Insert: {
          id?: never;
          name: string;
          user_id: string;
          created_at?: string;
        };
        Update: {
          name?: string;
        };
      };
      project_members: {
        Row: {
          id: number;
          project_id: number;
          user_id: string;
          role: 'owner' | 'editor' | 'viewer';
          invited_email: string | null;
          accepted: boolean;
          created_at: string;
        };
        Insert: {
          id?: never;
          project_id: number;
          user_id: string;
          role?: 'owner' | 'editor' | 'viewer';
          invited_email?: string | null;
          accepted?: boolean;
          created_at?: string;
        };
        Update: {
          role?: 'owner' | 'editor' | 'viewer';
          accepted?: boolean;
        };
      };
    };
  };
}

// Convenience aliases
export type Paper = Database['public']['Tables']['papers']['Row'];
export type PaperInsert = Database['public']['Tables']['papers']['Insert'];
export type PaperUpdate = Database['public']['Tables']['papers']['Update'];
export type Project = Database['public']['Tables']['projects']['Row'];
export type ProjectInsert = Database['public']['Tables']['projects']['Insert'];
export type ProjectMember = Database['public']['Tables']['project_members']['Row'];
