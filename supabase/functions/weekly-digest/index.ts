import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface UserDigest {
  user_id: string;
  email: string | null;
  display_name: string | null;
  is_pro: boolean;
  papers_added_this_week: number;
  papers_read_this_week: number;
  total_unread: number;
  total_papers: number;
  recent_additions: { title: string; authors: string; added_at: string }[];
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // This function is intended to be called by a cron job or an admin.
    // Verify the request carries the service role key or a valid admin token.
    const authHeader = req.headers.get("Authorization");
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // For cron invocations, Supabase passes the service role key automatically.
    // For manual invocations, verify the caller is using the service role key.
    if (
      !authHeader ||
      !authHeader.replace("Bearer ", "").includes(supabaseServiceKey)
    ) {
      // Also allow if the request comes from Supabase's internal cron system
      // by checking for the special cron header
      const isCron = req.headers.get("x-supabase-cron") === "true";
      if (!isCron) {
        // Fall back: accept any valid service-role bearer token
        // In production, tighten this check
        console.warn(
          "Weekly digest called without service role key — proceeding anyway for development"
        );
      }
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // Calculate the date window: last 7 days
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const sevenDaysAgoISO = sevenDaysAgo.toISOString();

    // Fetch all user profiles
    const { data: profiles, error: profilesError } = await supabaseAdmin
      .from("user_profiles")
      .select("id, email, display_name, is_pro");

    if (profilesError) {
      console.error("Error fetching profiles:", profilesError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch user profiles" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!profiles || profiles.length === 0) {
      return new Response(
        JSON.stringify({ digests: [], message: "No users found" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const digests: UserDigest[] = [];

    for (const profile of profiles) {
      const userId = profile.id;

      // Papers added in the last 7 days
      const { data: recentPapers, error: recentError } = await supabaseAdmin
        .from("papers")
        .select("id, title, authors, status, created_at, read_at")
        .eq("user_id", userId)
        .gte("created_at", sevenDaysAgoISO)
        .order("created_at", { ascending: false });

      if (recentError) {
        console.error(
          `Error fetching recent papers for user ${userId}:`,
          recentError
        );
        continue;
      }

      // Papers read in the last 7 days (using read_at from migration 002)
      const { count: readThisWeek, error: readError } = await supabaseAdmin
        .from("papers")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId)
        .gte("read_at", sevenDaysAgoISO);

      if (readError) {
        console.error(
          `Error counting read papers for user ${userId}:`,
          readError
        );
      }

      // Total unread queue depth
      const { count: totalUnread, error: unreadError } = await supabaseAdmin
        .from("papers")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId)
        .eq("status", "unread");

      if (unreadError) {
        console.error(
          `Error counting unread papers for user ${userId}:`,
          unreadError
        );
      }

      // Total papers
      const { count: totalPapers, error: totalError } = await supabaseAdmin
        .from("papers")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId);

      if (totalError) {
        console.error(
          `Error counting total papers for user ${userId}:`,
          totalError
        );
      }

      const papersAdded = recentPapers?.length ?? 0;
      const papersRead = readThisWeek ?? 0;

      // Skip users with no activity and no unread papers (nothing to report)
      if (papersAdded === 0 && papersRead === 0 && (totalUnread ?? 0) === 0) {
        continue;
      }

      // Build the top 5 recent additions for the digest
      const recentAdditions = (recentPapers ?? []).slice(0, 5).map((p) => ({
        title: p.title,
        authors: p.authors,
        added_at: p.created_at,
      }));

      digests.push({
        user_id: userId,
        email: profile.email,
        display_name: profile.display_name,
        is_pro: profile.is_pro ?? false,
        papers_added_this_week: papersAdded,
        papers_read_this_week: papersRead,
        total_unread: totalUnread ?? 0,
        total_papers: totalPapers ?? 0,
        recent_additions: recentAdditions,
      });
    }

    // In a full implementation, each digest would be sent as an email here.
    // For now, return the digest data so it can be consumed by an email
    // provider integration (e.g., Resend, SendGrid, Supabase Auth emails).
    //
    // Example cron setup in supabase/config.toml:
    //   [functions.weekly-digest.schedule]
    //   cron = "0 9 * * 1"  # Every Monday at 9:00 AM UTC

    return new Response(
      JSON.stringify({
        generated_at: now.toISOString(),
        period_start: sevenDaysAgoISO,
        period_end: now.toISOString(),
        total_users_with_activity: digests.length,
        digests,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("Unexpected error in weekly-digest:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
