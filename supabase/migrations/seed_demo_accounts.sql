-- Seed Demo Accounts
-- This recreates the demo provider accounts

-- Insert demo users into auth.users
-- Note: Passwords are hashed as 'password123' for demo purposes

-- Demo Driver 1
INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_user_meta_data,
    created_at,
    updated_at,
    role
) VALUES (
    '3a433609-e41e-42bd-9b98-854dc5a0dd8a',
    'demo.driver@roadrescue.com',
    crypt('Driver@2026', gen_salt('bf')),
    now(),
    '{"role": "customer", "full_name": "Demo Driver"}',
    now(),
    now(),
    'authenticated'
) ON CONFLICT (id) DO NOTHING;

-- Create user profile for Demo Driver
INSERT INTO public.user_profiles (
    id,
    email,
    full_name,
    phone,
    role,
    address,
    address_lat,
    address_lng,
    selected_state_id,
    selected_city_id,
    service_range_miles,
    is_available,
    is_verified,
    business_name,
    created_at,
    updated_at
) 
SELECT 
    '3a433609-e41e-42bd-9b98-854dc5a0dd8a',
    'demo.driver@roadrescue.com',
    'Demo Driver',
    '+52 998 123 4567',
    'customer',
    'Calle 60 No. 123, Playa del Carmen',
    20.6296,
    -87.0739,
    (SELECT id FROM public.states WHERE code = 'QR' LIMIT 1),
    (SELECT id FROM public.cities WHERE name = 'Playa del Carmen' AND state = 'Quintana Roo' LIMIT 1),
    25,
    true,
    true,
    null,
    now(),
    now()
WHERE NOT EXISTS (
    SELECT 1 FROM public.user_profiles WHERE id = '3a433609-e41e-42bd-9b98-854dc5a0dd8a'
);

-- Demo Provider 1
INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_user_meta_data,
    created_at,
    updated_at,
    role
) VALUES (
    '8b527c69-f52d-42b5-a5b5-854dc5a0dd9b',
    'demo.provider@roadrescue.com',
    crypt('Provider@2026', gen_salt('bf')),
    now(),
    '{"role": "provider", "full_name": "Demo Provider"}',
    now(),
    now(),
    'authenticated'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_profiles (
    id,
    email,
    full_name,
    phone,
    role,
    address,
    address_lat,
    address_lng,
    selected_state_id,
    selected_city_id,
    service_range_miles,
    is_available,
    is_verified,
    business_name,
    created_at,
    updated_at
)
SELECT 
    '8b527c69-f52d-42b5-a5b5-854dc5a0dd9b',
    'demo.provider@roadrescue.com',
    'Demo Provider',
    '+52 998 234 5678',
    'provider',
    'Av. Tulum 456, Cancún',
    21.1619,
    -86.8515,
    (SELECT id FROM public.states WHERE code = 'QR' LIMIT 1),
    (SELECT id FROM public.cities WHERE name = 'Cancún' AND state = 'Quintana Roo' LIMIT 1),
    30,
    true,
    true,
    'Road Rescue Service',
    now(),
    now()
WHERE NOT EXISTS (
    SELECT 1 FROM public.user_profiles WHERE id = '8b527c69-f52d-42b5-a5b5-854dc5a0dd9b'
);

-- Demo Provider 2 (Additional)
INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_user_meta_data,
    created_at,
    updated_at,
    role
) VALUES (
    '9c638d70-a63e-43c6-b6c6-854dc5a0ddac',
    'demo.provider2@roadrescue.com',
    crypt('Provider2@2026', gen_salt('bf')),
    now(),
    '{"role": "provider", "full_name": "Demo Provider 2"}',
    now(),
    now(),
    'authenticated'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_profiles (
    id,
    email,
    full_name,
    phone,
    role,
    address,
    address_lat,
    address_lng,
    selected_state_id,
    selected_city_id,
    service_range_miles,
    is_available,
    is_verified,
    business_name,
    created_at,
    updated_at
)
SELECT 
    '9c638d70-a63e-43c6-b6c6-854dc5a0ddac',
    'demo.provider2@roadrescue.com',
    'Demo Provider 2',
    '+52 998 345 6789',
    'provider',
    'Av. Coba 789, Tulum',
    20.2114,
    -87.4654,
    (SELECT id FROM public.states WHERE code = 'QR' LIMIT 1),
    (SELECT id FROM public.cities WHERE name = 'Tulum' AND state = 'Quintana Roo' LIMIT 1),
    20,
    true,
    true,
    'Tulum Roadside Assistance',
    now(),
    now()
WHERE NOT EXISTS (
    SELECT 1 FROM public.user_profiles WHERE id = '9c638d70-a63e-43c6-b6c6-854dc5a0ddac'
);

-- Demo Admin User
INSERT INTO auth.users (
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_user_meta_data,
    created_at,
    updated_at,
    role
) VALUES (
    'a1d7f4e5-b74f-4a2f-b3f7-123456789abc',
    'demo.admin@roadrescue.com',
    crypt('Admin@2026', gen_salt('bf')),
    now(),
    '{"role": "admin", "full_name": "Demo Admin"}',
    now(),
    now(),
    'authenticated'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_profiles (
    id,
    email,
    full_name,
    phone,
    role,
    is_available,
    is_verified,
    created_at,
    updated_at
)
SELECT 
    'a1d7f4e5-b74f-4a2f-b3f7-123456789abc',
    'demo.admin@roadrescue.com',
    'Demo Admin',
    '+52 998 999 9999',
    'admin',
    true,
    true,
    now(),
    now()
WHERE NOT EXISTS (
    SELECT 1 FROM public.user_profiles WHERE id = 'a1d7f4e5-b74f-4a2f-b3f7-123456789abc'
);


-- Demo credentials summary:
-- Driver: demo.driver@roadrescue.com / Driver@2026
-- Provider: demo.provider@roadrescue.com / Provider@2026
-- Provider 2: demo.provider2@roadrescue.com / Provider2@2026
-- Admin: demo.admin@roadrescue.com / Admin@2026

SELECT 'Demo accounts seeded with working passwords' as result;
