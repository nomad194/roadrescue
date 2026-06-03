import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface ReportPayload {
  review_id: string;
  provider_id: string;
  provider_name: string;
  customer_name: string;
  review_rating: number;
  review_comment: string;
  reason: string;
  details?: string;
  report_id: string;
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

    const body: ReportPayload = await req.json();
    const { 
      review_id, 
      provider_id, 
      provider_name, 
      customer_name, 
      review_rating, 
      review_comment,
      reason, 
      details,
      report_id 
    } = body;

    if (!review_id || !provider_id || !reason) {
      return new Response(
        JSON.stringify({ error: 'review_id, provider_id, and reason are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get support email from app settings
    const { data: supportEmailData, error: emailError } = await supabase
      .from('app_settings')
      .select('setting_value')
      .eq('setting_key', 'support_email')
      .maybeSingle();

    if (emailError || !supportEmailData?.setting_value) {
      console.error('Support email not configured:', emailError);
      return new Response(
        JSON.stringify({ error: 'Support email not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supportEmail = supportEmailData.setting_value;

    // Try to send email using Resend if API key is available
    const resendApiKey = Deno.env.get('RESEND_API_KEY');
    let emailSent = false;

    if (resendApiKey) {
      try {
        const emailHtml = `
          <h2>Review Report Submitted</h2>
          <p><strong>Report ID:</strong> ${report_id}</p>
          <p><strong>Provider:</strong> ${provider_name} (${provider_id})</p>
          <p><strong>Review ID:</strong> ${review_id}</p>
          <hr>
          <h3>Review Details:</h3>
          <p><strong>Customer:</strong> ${customer_name}</p>
          <p><strong>Rating:</strong> ${review_rating}/5</p>
          <p><strong>Comment:</strong> "${review_comment}"</p>
          <hr>
          <h3>Report:</h3>
          <p><strong>Reason:</strong> ${reason}</p>
          <p><strong>Details:</strong> ${details || 'None provided'}</p>
          <hr>
          <p><em>This report was submitted via the RoadRescue Provider App.</em></p>
        `;

        const resendResponse = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${resendApiKey}`,
          },
          body: JSON.stringify({
            from: 'RoadRescue Support <support@roadrescue.app>',
            to: [supportEmail],
            subject: `Review Report: ${provider_name} reported a review`,
            html: emailHtml,
          }),
        });

        if (resendResponse.ok) {
          emailSent = true;
          console.log('Email sent successfully to:', supportEmail);
        } else {
          console.error('Resend API error:', await resendResponse.text());
        }
      } catch (e) {
        console.error('Error sending email:', e);
      }
    }

    // Log the notification attempt
    console.log('Review report notification processed:', {
      report_id,
      review_id,
      provider_id,
      support_email: supportEmail,
      email_sent: emailSent,
    });

    return new Response(
      JSON.stringify({ 
        success: true, 
        email_sent: emailSent,
        message: emailSent 
          ? 'Report submitted and support notified via email'
          : 'Report submitted. Support will be notified.'
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    console.error('notify-support error:', e);
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
