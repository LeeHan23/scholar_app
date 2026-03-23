import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    // Validate Authorization header
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

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // User-scoped client to verify the JWT
    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

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

    // Parse request body
    const body = await req.json();
    const { projectId, invitedEmail, role = "viewer" } = body;

    if (!projectId || !invitedEmail) {
      return new Response(
        JSON.stringify({ error: "projectId and invitedEmail are required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!["owner", "editor", "viewer"].includes(role)) {
      return new Response(
        JSON.stringify({ error: "role must be owner, editor, or viewer" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Service role client for privileged operations
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // Verify the caller owns the project
    const { data: project, error: projectError } = await supabaseAdmin
      .from("projects")
      .select("id, user_id")
      .eq("id", projectId)
      .single();

    if (projectError || !project) {
      return new Response(
        JSON.stringify({ error: "Project not found" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (project.user_id !== user.id) {
      return new Response(
        JSON.stringify({ error: "Only the project owner can invite members" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Prevent self-invite
    if (invitedEmail === user.email) {
      return new Response(
        JSON.stringify({ error: "You cannot invite yourself" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Check if already a member
    const { data: existing } = await supabaseAdmin
      .from("project_members")
      .select("id, accepted")
      .eq("project_id", projectId)
      .eq("invited_email", invitedEmail)
      .maybeSingle();

    if (existing) {
      return new Response(
        JSON.stringify({
          error: existing.accepted
            ? "This user is already a member of the project"
            : "An invitation has already been sent to this email",
        }),
        {
          status: 409,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Look up if the invited email already has an account
    const { data: usersPage } = await supabaseAdmin.auth.admin.listUsers({
      perPage: 1000,
    });

    const existingUser = usersPage?.users?.find(
      (u) => u.email === invitedEmail
    );

    // Insert the member row
    const memberRow: Record<string, unknown> = {
      project_id: projectId,
      role,
      invited_email: invitedEmail,
      accepted: false,
    };

    if (existingUser) {
      // User has an account — link their ID so they can see the invitation immediately
      memberRow.user_id = existingUser.id;
    }
    // If no account yet: user_id stays null; the auto_accept_invitations trigger
    // will link them when they sign up.

    const { data: member, error: insertError } = await supabaseAdmin
      .from("project_members")
      .insert(memberRow)
      .select()
      .single();

    if (insertError) {
      console.error("Insert error:", insertError);
      return new Response(
        JSON.stringify({ error: "Failed to create invitation" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        status: "invited",
        userExists: !!existingUser,
        member,
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
