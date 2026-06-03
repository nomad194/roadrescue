import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsOrigin = Deno.env.get('CORS_ORIGIN') ?? '*';
const corsHeaders = {
  'Access-Control-Allow-Origin': corsOrigin,
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('authorization');
    if (!authHeader) {
      return jsonResponse({ success: false, code: 'unauthorized' }, 401);
    }

    const body = await req.json();
    const { userId } = body;

    if (!userId) {
      return jsonResponse({ success: false, code: 'missing_user_id' }, 400);
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const supabaseAuth = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    );

    const { data: { user }, error: userError } = await supabaseAuth.auth.getUser();
    if (userError || !user) {
      return jsonResponse({ success: false, code: 'unauthorized' }, 401);
    }

    if (user.id !== userId) {
      return jsonResponse({ success: false, code: 'unauthorized' }, 403);
    }

    // Helper: log errors but continue so missing tables don't block deletion
    const run = async (label: string, promise: Promise<any>) => {
      try {
        const { error } = await promise;
        if (error) {
          console.warn(`[${label}] warning:`, error);
        }
      } catch (e) {
        console.warn(`[${label}] skipped:`, e instanceof Error ? e.message : e);
      }
    };

    // ─── 1. Anonymize operational data ─────────────────────────────────────
    await run('anon_job_requests', supabase
      .from('job_requests')
      .update({ customer_id: null })
      .eq('customer_id', userId)
      .eq('job_status', 'completed'));

    await run('anon_bookings_customer', supabase
      .from('bookings')
      .update({ customer_id: null })
      .eq('customer_id', userId)
      .eq('booking_status', 'completed'));

    await run('anon_bookings_provider', supabase
      .from('bookings')
      .update({ provider_id: null })
      .eq('provider_id', userId)
      .eq('booking_status', 'completed'));

    await run('anon_payments', supabase
      .from('payments')
      .update({ customer_id: null })
      .eq('customer_id', userId));

    await run('anon_reviews', supabase
      .from('reviews')
      .update({ reviewer_id: null })
      .eq('reviewer_id', userId));

    await run('anon_provider_document_audit', supabase
      .from('provider_document_audit')
      .update({ changed_by: null })
      .eq('changed_by', userId));

    // ─── 2. Delete non-completed / personal data ───────────────────────────
    await run('del_job_requests', supabase
      .from('job_requests')
      .delete()
      .eq('customer_id', userId)
      .neq('job_status', 'completed'));

    await run('del_bookings_customer', supabase
      .from('bookings')
      .delete()
      .eq('customer_id', userId)
      .neq('booking_status', 'completed'));

    await run('del_bookings_provider', supabase
      .from('bookings')
      .delete()
      .eq('provider_id', userId)
      .neq('booking_status', 'completed'));

    await run('del_provider_documents', supabase
      .from('provider_documents')
      .delete()
      .eq('provider_id', userId));

    await run('del_provider_subscriptions', supabase
      .from('provider_subscriptions')
      .delete()
      .eq('provider_id', userId));

    await run('del_provider_services', supabase
      .from('provider_services')
      .delete()
      .eq('provider_id', userId));

    await run('del_push_tokens', supabase
      .from('push_tokens')
      .delete()
      .eq('user_id', userId));

    // ─── 3. Delete auth user (cascades to user_profiles) ───────────────────
    const { error: authDelErr } = await supabase.auth.admin.deleteUser(userId);
    if (authDelErr) {
      console.error('Auth delete error:', authDelErr);
      return jsonResponse(
        { success: false, code: 'auth_delete_failed', error: authDelErr.message },
        500
      );
    }

    return jsonResponse({ success: true });
  } catch (error) {
    console.error('delete-account error:', error);
    return jsonResponse(
      {
        success: false,
        code: 'db_cleanup_failed',
        error: error instanceof Error ? error.message : 'Unknown error',
      },
      500
    );
  }
});

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
