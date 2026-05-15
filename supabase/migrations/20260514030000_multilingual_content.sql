-- Migration: Add multilingual content fields to dynamic content tables
-- Adds JSONB translation columns to categories, subscription_plans, and content tables

-- Add translations column to service_categories if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'service_categories'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'service_categories' AND column_name = 'name_translations'
    ) THEN
      ALTER TABLE public.service_categories ADD COLUMN name_translations JSONB DEFAULT '{}'::jsonb;
    END IF;
  END IF;
END $$;

-- Add multilingual columns to subscription_plans
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'subscription_plans'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'subscription_plans' AND column_name = 'name_translations'
    ) THEN
      ALTER TABLE public.subscription_plans ADD COLUMN name_translations JSONB DEFAULT '{}'::jsonb;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'subscription_plans' AND column_name = 'description_translations'
    ) THEN
      ALTER TABLE public.subscription_plans ADD COLUMN description_translations JSONB DEFAULT '{}'::jsonb;
    END IF;
  END IF;
END $$;

-- Create app_content table for FAQ, Terms, Privacy, Blog posts
CREATE TABLE IF NOT EXISTS public.app_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_type TEXT NOT NULL, -- 'faq', 'terms', 'privacy', 'blog'
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  -- Multilingual fields stored as JSONB: { "en": "text", "es": "texto", ... }
  title_translations JSONB DEFAULT '{}'::jsonb,
  body_translations JSONB DEFAULT '{}'::jsonb,
  -- For FAQ: question/answer
  question_translations JSONB DEFAULT '{}'::jsonb,
  answer_translations JSONB DEFAULT '{}'::jsonb,
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS on app_content
ALTER TABLE public.app_content ENABLE ROW LEVEL SECURITY;

-- Public read access for app content
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'app_content' AND policyname = 'app_content_public_read'
  ) THEN
    CREATE POLICY app_content_public_read ON public.app_content
      FOR SELECT USING (is_active = true);
  END IF;
END $$;

-- Admin write access for app content
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'app_content' AND policyname = 'app_content_admin_write'
  ) THEN
    CREATE POLICY app_content_admin_write ON public.app_content
      FOR ALL USING (
        EXISTS (
          SELECT 1 FROM public.user_profiles
          WHERE id = auth.uid() AND role = 'admin'
        )
      );
  END IF;
END $$;

-- Seed default FAQ entries with multilingual content
INSERT INTO public.app_content (content_type, sort_order, is_active, question_translations, answer_translations)
VALUES
  (
    'faq', 1, true,
    '{"en":"How quickly can I get help?","es":"¿Qué tan rápido puedo obtener ayuda?","fr":"À quelle vitesse puis-je obtenir de l''aide?","pt":"Com que rapidez posso obter ajuda?","de":"Wie schnell kann ich Hilfe bekommen?","ar":"كم من الوقت يستغرق الحصول على المساعدة؟"}'::jsonb,
    '{"en":"Most providers arrive within 15–45 minutes depending on your location and service type.","es":"La mayoría de los proveedores llegan en 15 a 45 minutos según tu ubicación.","fr":"La plupart des prestataires arrivent en 15 à 45 minutes selon votre emplacement.","pt":"A maioria dos prestadores chega em 15 a 45 minutos dependendo da sua localização.","de":"Die meisten Anbieter kommen innerhalb von 15–45 Minuten, je nach Standort.","ar":"يصل معظم مزودي الخدمة خلال 15 إلى 45 دقيقة حسب موقعك."}'::jsonb
  ),
  (
    'faq', 2, true,
    '{"en":"How do I pay for services?","es":"¿Cómo pago los servicios?","fr":"Comment puis-je payer les services?","pt":"Como pago pelos serviços?","de":"Wie bezahle ich für Dienstleistungen?","ar":"كيف أدفع مقابل الخدمات؟"}'::jsonb,
    '{"en":"You can pay via credit card, debit card, or cash depending on the provider.","es":"Puedes pagar con tarjeta de crédito, débito o efectivo según el proveedor.","fr":"Vous pouvez payer par carte de crédit, débit ou espèces selon le prestataire.","pt":"Você pode pagar com cartão de crédito, débito ou dinheiro dependendo do prestador.","de":"Sie können per Kreditkarte, Debitkarte oder Bargeld bezahlen.","ar":"يمكنك الدفع ببطاقة الائتمان أو الخصم أو النقد حسب المزود."}'::jsonb
  ),
  (
    'faq', 3, true,
    '{"en":"Can I track my provider?","es":"¿Puedo rastrear a mi proveedor?","fr":"Puis-je suivre mon prestataire?","pt":"Posso rastrear meu prestador?","de":"Kann ich meinen Anbieter verfolgen?","ar":"هل يمكنني تتبع مزود الخدمة؟"}'::jsonb,
    '{"en":"Yes! Once a provider accepts your request, you can track their location in real-time.","es":"¡Sí! Una vez que un proveedor acepta tu solicitud, puedes rastrear su ubicación en tiempo real.","fr":"Oui! Une fois qu''un prestataire accepte votre demande, vous pouvez suivre sa position en temps réel.","pt":"Sim! Assim que um prestador aceitar sua solicitação, você pode rastrear sua localização em tempo real.","de":"Ja! Sobald ein Anbieter Ihre Anfrage annimmt, können Sie seinen Standort in Echtzeit verfolgen.","ar":"نعم! بمجرد قبول المزود لطلبك، يمكنك تتبع موقعه في الوقت الفعلي."}'::jsonb
  )
ON CONFLICT DO NOTHING;

-- Seed Terms of Service with multilingual content
INSERT INTO public.app_content (content_type, sort_order, is_active, title_translations, body_translations)
VALUES
  (
    'terms', 1, true,
    '{"en":"Terms of Service","es":"Términos de Servicio","fr":"Conditions d''Utilisation","pt":"Termos de Serviço","de":"Nutzungsbedingungen","ar":"شروط الخدمة"}'::jsonb,
    '{"en":"Welcome to RoadRescue. By using our service, you agree to the following terms and conditions...\n\n1. Service Agreement\nRoadRescue connects customers with independent roadside assistance providers...\n\n2. Payment Terms\nAll payments are processed securely through our platform...\n\n3. Liability\nRoadRescue acts as a marketplace and is not liable for...","es":"Bienvenido a RoadRescue. Al usar nuestro servicio, acepta los siguientes términos y condiciones...","fr":"Bienvenue sur RoadRescue. En utilisant notre service, vous acceptez les conditions suivantes...","pt":"Bem-vindo ao RoadRescue. Ao usar nosso serviço, você concorda com os seguintes termos...","de":"Willkommen bei RoadRescue. Durch die Nutzung unseres Dienstes stimmen Sie den folgenden Bedingungen zu...","ar":"مرحباً بك في رود ريسكيو. باستخدام خدمتنا، فإنك توافق على الشروط والأحكام التالية..."}'::jsonb
  )
ON CONFLICT DO NOTHING;

-- Seed Privacy Policy with multilingual content
INSERT INTO public.app_content (content_type, sort_order, is_active, title_translations, body_translations)
VALUES
  (
    'privacy', 1, true,
    '{"en":"Privacy Policy","es":"Política de Privacidad","fr":"Politique de Confidentialité","pt":"Política de Privacidade","de":"Datenschutzrichtlinie","ar":"سياسة الخصوصية"}'::jsonb,
    '{"en":"Privacy Policy\n\nLast updated: January 2026\n\nRoadRescue is committed to protecting your privacy...\n\n1. Information We Collect\nWe collect information you provide directly to us...\n\n2. How We Use Your Information\nWe use the information we collect to provide, maintain, and improve our services...","es":"Política de Privacidad\n\nÚltima actualización: Enero 2026\n\nRoadRescue está comprometido con la protección de su privacidad...","fr":"Politique de Confidentialité\n\nDernière mise à jour: Janvier 2026\n\nRoadRescue s''engage à protéger votre vie privée...","pt":"Política de Privacidade\n\nÚltima atualização: Janeiro 2026\n\nRoadRescue está comprometido em proteger sua privacidade...","de":"Datenschutzrichtlinie\n\nZuletzt aktualisiert: Januar 2026\n\nRoadRescue verpflichtet sich, Ihre Privatsphäre zu schützen...","ar":"سياسة الخصوصية\n\nآخر تحديث: يناير 2026\n\nيلتزم رود ريسكيو بحماية خصوصيتك..."}'::jsonb
  )
ON CONFLICT DO NOTHING;

-- Add preferred_language to user_profiles if not exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'user_profiles'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'user_profiles' AND column_name = 'preferred_language'
    ) THEN
      ALTER TABLE public.user_profiles ADD COLUMN preferred_language TEXT DEFAULT 'en';
    END IF;
  END IF;
END $$;

-- Upsert default language setting in app_settings
INSERT INTO public.app_settings (setting_key, setting_value, setting_type)
VALUES ('default_language', 'en', 'string')
ON CONFLICT (setting_key) DO NOTHING;
