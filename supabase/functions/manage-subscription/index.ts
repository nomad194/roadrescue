import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const body = await req.json();
    const { action, provider_id, plan_id, billing_cycle, amount, payment_method } = body;

    if (!action) {
      return jsonResponse({ error: 'action is required' }, 400);
    }

    if (!provider_id && action !== 'check_status') {
      return jsonResponse({ error: 'provider_id is required' }, 400);
    }

    let result;

    // ─── DOCUMENT VERIFICATION GUARD ─────────────────────────────────────
    if (action === 'start_trial' || action === 'activate') {
      // Count active required document types
      const { count: requiredCount } = await supabase
        .from('required_document_types')
        .select('*', { count: 'exact', head: true })
        .eq('is_active', true);

      if (requiredCount && requiredCount > 0) {
        // Count approved documents for this provider
        const { count: approvedCount } = await supabase
          .from('provider_documents')
          .select('*', { count: 'exact', head: true })
          .eq('provider_id', provider_id)
          .eq('status', 'approved')
          .in_('document_type_id',
            (await supabase.from('required_document_types').select('id').eq('is_active', true)).data?.map((d: any) => d.id) ?? []
          );

        if ((approvedCount ?? 0) < requiredCount) {
          return jsonResponse({ error: 'documents_not_verified', required: requiredCount, approved: approvedCount ?? 0 }, 403);
        }
      }
    }
    // ─── END DOCUMENT VERIFICATION GUARD ──────────────────────────────────

    switch (action) {
      case 'start_trial': {
        if (!plan_id) {
          return jsonResponse({ error: 'plan_id is required for start_trial' }, 400);
        }
        const { data, error } = await supabase.rpc('start_provider_trial', {
          p_provider_id: provider_id,
          p_plan_id: plan_id,
        });
        if (error) {
          console.error('start_trial error:', error);
          return jsonResponse({ error: error.message }, 500);
        }
        result = data;
        break;
      }

      case 'activate': {
        if (!plan_id) {
          return jsonResponse({ error: 'plan_id is required for activate' }, 400);
        }
        const { data, error } = await supabase.rpc('activate_provider_subscription', {
          p_provider_id: provider_id,
          p_plan_id: plan_id,
          p_billing_cycle: billing_cycle ?? 'monthly',
          p_amount: amount ?? 0,
          p_payment_method: payment_method ?? 'online',
        });
        if (error) {
          console.error('activate error:', error);
          return jsonResponse({ error: error.message }, 500);
        }
        result = data;
        break;
      }

      case 'expire': {
        const { data, error } = await supabase.rpc('expire_provider_subscription', {
          p_provider_id: provider_id,
        });
        if (error) {
          console.error('expire error:', error);
          return jsonResponse({ error: error.message }, 500);
        }
        result = data;
        break;
      }

      case 'complete_month': {
        const { data, error } = await supabase.rpc('complete_paid_month', {
          p_provider_id: provider_id,
        });
        if (error) {
          console.error('complete_month error:', error);
          return jsonResponse({ error: error.message }, 500);
        }
        result = data;
        break;
      }

      case 'check_status': {
        if (!provider_id) {
          return jsonResponse({ error: 'provider_id is required for check_status' }, 400);
        }
        const { data, error } = await supabase.rpc('get_provider_subscription_state', {
          p_provider_id: provider_id,
        });
        if (error) {
          console.error('check_status error:', error);
          return jsonResponse({ error: error.message }, 500);
        }
        result = data;
        break;
      }

      default:
        return jsonResponse({ error: `Unknown action: ${action}` }, 400);
    }

    return jsonResponse({ success: true, ...result });
  } catch (error) {
    console.error('manage-subscription error:', error);
    return jsonResponse({ error: 'Subscription management failed' }, 500);
  }
});

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
