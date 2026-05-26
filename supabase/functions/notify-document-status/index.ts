import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface PushPayload {
  provider_id: string;
  document_id: string;
  status: 'approved' | 'rejected';
  reason?: string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const body: PushPayload = await req.json();
    const { provider_id, document_id, status, reason } = body;

    if (!provider_id || !document_id || !status) {
      return new Response(
        JSON.stringify({ error: 'provider_id, document_id, and status are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get provider's push tokens
    const { data: tokens, error: tokenError } = await supabase
      .from('push_tokens')
      .select('token, platform')
      .eq('user_id', provider_id);

    if (tokenError) {
      console.error('Error fetching push tokens:', tokenError);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch push tokens' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No push tokens found for provider', sent: 0 }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Build notification content
    const title = status === 'approved'
      ? '✅ Document Approved'
      : '❌ Document Rejected';

    const message = status === 'approved'
      ? 'Your document has been approved. Check your verification status.'
      : reason
        ? `Your document was rejected: ${reason}`
        : 'Your document was rejected. Please re-upload.';

    // Send FCM push notifications
    const fcmKey = Deno.env.get('FCM_SERVER_KEY');
    let sentCount = 0;

    if (fcmKey) {
      for (const { token } of tokens) {
        try {
          const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `key=${fcmKey}`,
            },
            body: JSON.stringify({
              to: token,
              notification: { title, body: message },
              data: {
                type: 'document_status',
                document_id,
                status,
              },
            }),
          });

          if (fcmResponse.ok) {
            sentCount++;
          } else {
            console.error('FCM send failed:', await fcmResponse.text());
          }
        } catch (e) {
          console.error('FCM send error:', e);
        }
      }
    }

    return new Response(
      JSON.stringify({ success: true, sent: sentCount }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    console.error('notify-document-status error:', e);
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
