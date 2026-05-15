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

    const { paymentIntentId } = await req.json();

    if (!paymentIntentId) {
      return new Response(JSON.stringify({ error: 'paymentIntentId is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Retrieve payment intent from Stripe
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    const paymentStatus = paymentIntent.status === 'succeeded' ? 'succeeded' : 'pending';

    // Update payment record in database
    const { data: payment, error } = await supabase
      .from('payments')
      .update({
        payment_status: paymentStatus,
        stripe_charge_id: paymentIntent.latest_charge as string ?? '',
        updated_at: new Date().toISOString(),
      })
      .eq('stripe_payment_intent_id', paymentIntentId)
      .select()
      .single();

    if (error) {
      console.error('Failed to update payment:', error);
    }

    // If succeeded, update booking status
    if (paymentStatus === 'succeeded' && payment?.booking_id) {
      await supabase
        .from('bookings')
        .update({ booking_status: 'confirmed', updated_at: new Date().toISOString() })
        .eq('id', payment.booking_id);
    }

    return new Response(
      JSON.stringify({ success: true, status: paymentStatus, payment }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('confirm-payment error:', error);
    return new Response(
      JSON.stringify({ error: 'Payment confirmation failed' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
