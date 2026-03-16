import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FREE_TIER_LIMIT = 15;

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
    // Extract the user's JWT from the Authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Create a Supabase client authenticated as the calling user
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // User-scoped client for reading the JWT claims
    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    // Verify the user and get their ID
    const {
      data: { user },
      error: userError,
    } = await supabaseUser.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired token" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const userId = user.id;

    // Use the service role client for privileged queries (bypasses RLS)
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // Check if user is Pro
    const { data: profile, error: profileError } = await supabaseAdmin
      .from("user_profiles")
      .select("is_pro")
      .eq("id", userId)
      .single();

    if (profileError && profileError.code !== "PGRST116") {
      // PGRST116 = row not found, which is fine (treat as free tier)
      console.error("Error fetching profile:", profileError);
      return new Response(
        JSON.stringify({ error: "Failed to check subscription status" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const isPro = profile?.is_pro === true;

    // Pro users have unlimited captures
    if (isPro) {
      return new Response(
        JSON.stringify({
          allowed: true,
          is_pro: true,
          captures_this_month: null,
          limit: null,
          message: "Pro users have unlimited captures.",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Count papers created by this user in the current calendar month
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const nextMonthStart = new Date(now.getFullYear(), now.getMonth() + 1, 1);

    const { count, error: countError } = await supabaseAdmin
      .from("papers")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .gte("created_at", monthStart.toISOString())
      .lt("created_at", nextMonthStart.toISOString());

    if (countError) {
      console.error("Error counting captures:", countError);
      return new Response(
        JSON.stringify({ error: "Failed to count monthly captures" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const capturesThisMonth = count ?? 0;
    const remaining = Math.max(0, FREE_TIER_LIMIT - capturesThisMonth);

    if (capturesThisMonth >= FREE_TIER_LIMIT) {
      return new Response(
        JSON.stringify({
          allowed: false,
          is_pro: false,
          captures_this_month: capturesThisMonth,
          limit: FREE_TIER_LIMIT,
          remaining: 0,
          message: `You have reached your free tier limit of ${FREE_TIER_LIMIT} captures this month. Upgrade to Pro for unlimited captures.`,
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(
      JSON.stringify({
        allowed: true,
        is_pro: false,
        captures_this_month: capturesThisMonth,
        limit: FREE_TIER_LIMIT,
        remaining,
        message: `You have ${remaining} capture${remaining === 1 ? "" : "s"} remaining this month.`,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
