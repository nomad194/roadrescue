import Stripe from 'https://esm.sh/stripe@14.21.0';
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
    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
      apiVersion: '2024-06-20',
    });

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const body = await req.json();
    const {
      bookingId,
      jobRequestId,
      customerId,
      providerId,
      amount,
      currency = 'usd',
      customerEmail,
      customerName,
    } = body;

    const resolvedJobRequestId = jobRequestId ?? bookingId ?? null;

    if (!amount || amount <= 0) {
      return new Response(JSON.stringify({ error: 'Invalid amount' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { data: settings } = await supabase
      .from('app_settings')
      .select('setting_key, setting_value')
      .in('setting_key', ['commission_enabled', 'commission_percent']);

    const commissionEnabled =
      settings?.find((s: { setting_key: string }) => s.setting_key === 'commission_enabled')
        ?.setting_value === 'true';
    const commissionPercent = parseFloat(
      settings?.find((s: { setting_key: string }) => s.setting_key === 'commission_percent')
        ?.setting_value ?? '15'
    );

    const commissionAmount = commissionEnabled
      ? Math.round(amount * (commissionPercent / 100) * 100) / 100
      : 0;
    const providerPayout = amount - commissionAmount;

    let stripeCustomerId: string | undefined;
    if (customerId) {
      const { data: profile } = await supabase
        .from('user_profiles')
        .select('id, email, full_name')
        .eq('id', customerId)
        .maybeSingle();

      if (profile) {
        const existingCustomers = await stripe.customers.list({
          email: profile.email,
          limit: 1,
        });

        if (existingCustomers.data.length > 0) {
          stripeCustomerId = existingCustomers.data[0].id;
        } else {
          const customer = await stripe.customers.create({
            email: profile.email ?? customerEmail,
            name: profile.full_name ?? customerName,
            metadata: { supabase_user_id: customerId },
          });
          stripeCustomerId = customer.id;
        }
      }
    }

    const paymentIntentParams: Stripe.PaymentIntentCreateParams = {
      amount: Math.round(amount * 100),
      currency,
      customer: stripeCustomerId,
      description: `RoadRescue service payment - Job ${resolvedJobRequestId ?? 'N/A'}`,
      metadata: {
        job_request_id: resolvedJobRequestId ?? '',
        booking_id: resolvedJobRequestId ?? '',
        customer_id: customerId ?? '',
        provider_id: providerId ?? '',
        commission_amount: commissionAmount.toString(),
        provider_payout: providerPayout.toString(),
      },
      automatic_payment_methods: { enabled: true },
    };

    const paymentIntent = await stripe.paymentIntents.create(paymentIntentParams);

    const { data: paymentRecord, error: paymentError } = await supabase
      .from('payments')
      .insert({
        job_request_id: resolvedJobRequestId,
        customer_id: customerId,
        provider_id: providerId ?? null,
        stripe_payment_intent_id: paymentIntent.id,
        amount,
        commission_amount: commissionAmount,
        provider_payout: providerPayout,
        currency,
        payment_status: 'pending',
      })
      .select()
      .single();

    if (paymentError) {
      console.error('Failed to save payment record:', paymentError);
    }

    return new Response(
      JSON.stringify({
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
        recordId: paymentRecord?.id,
        commissionAmount,
        providerPayout,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('create-payment-intent error:', error);
    return new Response(
      JSON.stringify({ error: 'Payment initialization failed' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
