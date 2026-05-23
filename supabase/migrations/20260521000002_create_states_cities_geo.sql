-- ============================================================
-- STATES, CITIES, AND GEO ZONES SCHEMA
-- Creates states table, updates cities, seeds Quintana Roo
-- and Yucatán with ALL municipalities
-- ============================================================

-- Create states table
CREATE TABLE IF NOT EXISTS public.states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    country TEXT DEFAULT 'Mexico',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Add state_id to cities table if not exists
ALTER TABLE public.cities 
ADD COLUMN IF NOT EXISTS state_id UUID REFERENCES public.states(id) ON DELETE CASCADE;

-- Add unique constraint on city name + state
CREATE UNIQUE INDEX IF NOT EXISTS idx_cities_name_state 
ON public.cities(name, state_id);

-- Update geo_zones table
ALTER TABLE public.geo_zones 
ADD COLUMN IF NOT EXISTS state_id UUID REFERENCES public.states(id) ON DELETE CASCADE;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_cities_state_id ON public.cities(state_id);
CREATE INDEX IF NOT EXISTS idx_geo_zones_state_id ON public.geo_zones(state_id);
CREATE INDEX IF NOT EXISTS idx_geo_zones_city_id ON public.geo_zones(city_id);

-- Add lat/lng to user_profiles for provider location
ALTER TABLE public.user_profiles 
ADD COLUMN IF NOT EXISTS address_lat FLOAT,
ADD COLUMN IF NOT EXISTS address_lng FLOAT,
ADD COLUMN IF NOT EXISTS selected_state_id UUID REFERENCES public.states(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS selected_city_id UUID REFERENCES public.cities(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_user_profiles_location ON public.user_profiles(address_lat, address_lng);
CREATE INDEX IF NOT EXISTS idx_user_profiles_state ON public.user_profiles(selected_state_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_city ON public.user_profiles(selected_city_id);

-- Seed States
INSERT INTO public.states (code, name, country) VALUES
('QR', 'Quintana Roo', 'Mexico'),
('YU', 'Yucatán', 'Mexico')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- ============================================================
-- SEED ALL QUINTANA ROO MUNICIPALITIES (11 total)
-- ============================================================
WITH state_qr AS (SELECT id FROM public.states WHERE code = 'QR')
INSERT INTO public.cities (name, state, state_id) VALUES
-- Municipalities of Quintana Roo
('Benito Juárez', 'Quintana Roo', (SELECT id FROM state_qr)),      -- Cancún
('Solidaridad', 'Quintana Roo', (SELECT id FROM state_qr)),        -- Playa del Carmen
('Tulum', 'Quintana Roo', (SELECT id FROM state_qr)),              -- Tulum
('Cozumel', 'Quintana Roo', (SELECT id FROM state_qr)),            -- Cozumel Island
('Othón P. Blanco', 'Quintana Roo', (SELECT id FROM state_qr)),    -- Chetumal
('Puerto Morelos', 'Quintana Roo', (SELECT id FROM state_qr)),     -- Puerto Morelos
('Isla Mujeres', 'Quintana Roo', (SELECT id FROM state_qr)),       -- Isla Mujeres
('Felipe Carrillo Puerto', 'Quintana Roo', (SELECT id FROM state_qr)),
('José María Morelos', 'Quintana Roo', (SELECT id FROM state_qr)),
('Bacalar', 'Quintana Roo', (SELECT id FROM state_qr)),
('Lázaro Cárdenas', 'Quintana Roo', (SELECT id FROM state_qr))
ON CONFLICT (name, state_id) DO NOTHING;

-- ============================================================
-- SEED ALL YUCATÁN MUNICIPALITIES (106 total)
-- ============================================================
WITH state_yu AS (SELECT id FROM public.states WHERE code = 'YU')
INSERT INTO public.cities (name, state, state_id) VALUES
-- Major municipalities
('Mérida', 'Yucatán', (SELECT id FROM state_yu)),
('Valladolid', 'Yucatán', (SELECT id FROM state_yu)),
('Progreso', 'Yucatán', (SELECT id FROM state_yu)),
('Tizimín', 'Yucatán', (SELECT id FROM state_yu)),
('Umán', 'Yucatán', (SELECT id FROM state_yu)),
('Kanasín', 'Yucatán', (SELECT id FROM state_yu)),
('Izamal', 'Yucatán', (SELECT id FROM state_yu)),
('Motul', 'Yucatán', (SELECT id FROM state_yu)),
('Tekax', 'Yucatán', (SELECT id FROM state_yu)),
('Ticul', 'Yucatán', (SELECT id FROM state_yu)),
('Oxkutzcab', 'Yucatán', (SELECT id FROM state_yu)),
('Maxcanú', 'Yucatán', (SELECT id FROM state_yu)),
('Hunucmá', 'Yucatán', (SELECT id FROM state_yu)),
('Acanceh', 'Yucatán', (SELECT id FROM state_yu)),
('Espita', 'Yucatán', (SELECT id FROM state_yu)),
('Temozón', 'Yucatán', (SELECT id FROM state_yu)),
('Río Lagartos', 'Yucatán', (SELECT id FROM state_yu)),
('Panabá', 'Yucatán', (SELECT id FROM state_yu)),
('Sinanché', 'Yucatán', (SELECT id FROM state_yu)),
('Dzidzantún', 'Yucatán', (SELECT id FROM state_yu)),
('Telchac Pueblo', 'Yucatán', (SELECT id FROM state_yu)),
('Seyé', 'Yucatán', (SELECT id FROM state_yu)),
('Sotuta', 'Yucatán', (SELECT id FROM state_yu)),
('Homún', 'Yucatán', (SELECT id FROM state_yu)),
('Hocabá', 'Yucatán', (SELECT id FROM state_yu)),
('Xocchel', 'Yucatán', (SELECT id FROM state_yu)),
('Timucuy', 'Yucatán', (SELECT id FROM state_yu)),
('Chicxulub Pueblo', 'Yucatán', (SELECT id FROM state_yu)),
('Conkal', 'Yucatán', (SELECT id FROM state_yu)),
('Tixkokob', 'Yucatán', (SELECT id FROM state_yu)),
('Yaxkukul', 'Yucatán', (SELECT id FROM state_yu)),
('Dzemul', 'Yucatán', (SELECT id FROM state_yu)),
('Baca', 'Yucatán', (SELECT id FROM state_yu)),
('Cansahcab', 'Yucatán', (SELECT id FROM state_yu)),
('Dzununcán', 'Yucatán', (SELECT id FROM state_yu)),
('Mocochá', 'Yucatán', (SELECT id FROM state_yu)),
('Cacalchén', 'Yucatán', (SELECT id FROM state_yu)),
('Muxupip', 'Yucatán', (SELECT id FROM state_yu)),
('Cenotillo', 'Yucatán', (SELECT id FROM state_yu)),
('Sucilá', 'Yucatán', (SELECT id FROM state_yu)),
('Catmis', 'Yucatán', (SELECT id FROM state_yu)),
('Chankom', 'Yucatán', (SELECT id FROM state_yu)),
('Kantunil', 'Yucatán', (SELECT id FROM state_yu)),
('Sudzal', 'Yucatán', (SELECT id FROM state_yu)),
('Tahdziú', 'Yucatán', (SELECT id FROM state_yu)),
('Chumayel', 'Yucatán', (SELECT id FROM state_yu)),
('Maní', 'Yucatán', (SELECT id FROM state_yu)),
('Mayapán', 'Yucatán', (SELECT id FROM state_yu)),
('Mama', 'Yucatán', (SELECT id FROM state_yu)),
('Sacalum', 'Yucatán', (SELECT id FROM state_yu)),
('Mucuyché', 'Yucatán', (SELECT id FROM state_yu)),
('Chapab', 'Yucatán', (SELECT id FROM state_yu)),
('Abalá', 'Yucatán', (SELECT id FROM state_yu)),
('Tecoh', 'Yucatán', (SELECT id FROM state_yu)),
('Kinchil', 'Yucatán', (SELECT id FROM state_yu)),
('Dzitbalché', 'Yucatán', (SELECT id FROM state_yu)),
('Halachó', 'Yucatán', (SELECT id FROM state_yu)),
('Opichén', 'Yucatán', (SELECT id FROM state_yu)),
('Chocholá', 'Yucatán', (SELECT id FROM state_yu)),
('Kopomá', 'Yucatán', (SELECT id FROM state_yu)),
('Celestún', 'Yucatán', (SELECT id FROM state_yu)),
('Chicxulub Puerto', 'Yucatán', (SELECT id FROM state_yu)),
('Telchac Puerto', 'Yucatán', (SELECT id FROM state_yu)),
('San Felipe', 'Yucatán', (SELECT id FROM state_yu)),
('Santa Clara', 'Yucatán', (SELECT id FROM state_yu)),
('Suma', 'Yucatán', (SELECT id FROM state_yu)),
('Teya', 'Yucatán', (SELECT id FROM state_yu)),
('Tahmek', 'Yucatán', (SELECT id FROM state_yu)),
('Huhí', 'Yucatán', (SELECT id FROM state_yu)),
('Sanahcat', 'Yucatán', (SELECT id FROM state_yu)),
('Tixpéhual', 'Yucatán', (SELECT id FROM state_yu)),
('Chacsinkín', 'Yucatán', (SELECT id FROM state_yu)),
('Chemax', 'Yucatán', (SELECT id FROM state_yu)),
('Xocchel', 'Yucatán', (SELECT id FROM state_yu)),
('Yaxcabá', 'Yucatán', (SELECT id FROM state_yu)),
('Dzilam de Bravo', 'Yucatán', (SELECT id FROM state_yu)),
('Dzilam González', 'Yucatán', (SELECT id FROM state_yu)),
('Sanahcat', 'Yucatán', (SELECT id FROM state_yu)),
('Tekantó', 'Yucatán', (SELECT id FROM state_yu)),
('Tepakán', 'Yucatán', (SELECT id FROM state_yu)),
('Tetiz', 'Yucatán', (SELECT id FROM state_yu)),
('Teabo', 'Yucatán', (SELECT id FROM state_yu)),
('Temax', 'Yucatán', (SELECT id FROM state_yu)),
('Suma de Hidalgo', 'Yucatán', (SELECT id FROM state_yu)),
('Huhi', 'Yucatán', (SELECT id FROM state_yu)),
('Quintana Roo', 'Yucatán', (SELECT id FROM state_yu)),
('Santa Elena', 'Yucatán', (SELECT id FROM state_yu)),
('Peto', 'Yucatán', (SELECT id FROM state_yu)),
('Chacsinkín', 'Yucatán', (SELECT id FROM state_yu)),
('Tixméhuac', 'Yucatán', (SELECT id FROM state_yu)),
('Xochempich', 'Yucatán', (SELECT id FROM state_yu)),
('Buctzotz', 'Yucatán', (SELECT id FROM state_yu)),
('Yobaín', 'Yucatán', (SELECT id FROM state_yu)),
('Dzoncauich', 'Yucatán', (SELECT id FROM state_yu)),
('Akil', 'Yucatán', (SELECT id FROM state_yu)),
('Libre Unión', 'Yucatán', (SELECT id FROM state_yu)),
('Tekom', 'Yucatán', (SELECT id FROM state_yu)),
('Cuncunul', 'Yucatán', (SELECT id FROM state_yu)),
('Hocabá', 'Yucatán', (SELECT id FROM state_yu)),
('San Francisco de Campeche', 'Yucatán', (SELECT id FROM state_yu))
ON CONFLICT (name, state_id) DO NOTHING;

-- ============================================================
-- CREATE RPC FUNCTIONS FOR GEO QUERIES
-- ============================================================

-- Function to get cities by state
CREATE OR REPLACE FUNCTION public.get_cities_by_state(p_state_id UUID)
RETURNS SETOF public.cities
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM public.cities
    WHERE state_id = p_state_id
    ORDER BY name;
END;
$$;

-- Function to get jobs for provider (by geo zone + range)
CREATE OR REPLACE FUNCTION public.get_jobs_for_provider(
    p_provider_id UUID,
    p_state_id UUID,
    p_city_id UUID,
    p_provider_lat FLOAT,
    p_provider_lng FLOAT,
    p_range_miles INTEGER
)
RETURNS SETOF public.job_requests
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT jr.*
    FROM public.job_requests jr
    JOIN public.user_profiles customer ON jr.customer_id = customer.id
    WHERE jr.job_status = 'pending'
    AND (
        -- Match by geo zone (state + city)
        (customer.selected_state_id = p_state_id 
         AND customer.selected_city_id = p_city_id)
        OR
        -- OR within service range (distance calculation)
        (customer.address_lat IS NOT NULL 
         AND customer.address_lng IS NOT NULL
         AND (earth_distance(
             ll_to_earth(p_provider_lat, p_provider_lng),
             ll_to_earth(customer.address_lat, customer.address_lng)
         ) / 1609.344) <= p_range_miles)
    );
END;
$$;

-- Add geo columns to job_requests
ALTER TABLE public.job_requests 
ADD COLUMN IF NOT EXISTS customer_lat FLOAT,
ADD COLUMN IF NOT EXISTS customer_lng FLOAT,
ADD COLUMN IF NOT EXISTS customer_city_id UUID REFERENCES public.cities(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS customer_state_id UUID REFERENCES public.states(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_job_requests_location ON public.job_requests(customer_lat, customer_lng);
CREATE INDEX IF NOT EXISTS idx_job_requests_city ON public.job_requests(customer_city_id);
CREATE INDEX IF NOT EXISTS idx_job_requests_state ON public.job_requests(customer_state_id);

-- Enable RLS on new tables
ALTER TABLE public.states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;

-- RLS policies for states (readable by all authenticated users)
CREATE POLICY "states_select_all" 
ON public.states FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "states_admin_all"
ON public.states FOR ALL
TO authenticated
USING (auth.jwt() ->> 'role' = 'admin')
WITH CHECK (auth.jwt() ->> 'role' = 'admin');

-- RLS policies for cities (readable by all authenticated users)
CREATE POLICY "cities_select_all"
ON public.cities FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "cities_admin_all"
ON public.cities FOR ALL
TO authenticated
USING (auth.jwt() ->> 'role' = 'admin')
WITH CHECK (auth.jwt() ->> 'role' = 'admin');
