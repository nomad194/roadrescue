-- Add provider main screen theme settings to app_settings
-- These are configured via the admin app and displayed in the provider app
INSERT INTO public.app_settings (setting_key, setting_value, setting_type)
VALUES
  ('provider_main_screen_bg', '#FFFFFF', 'text'),
  ('provider_main_screen_bg_opacity', '1.0', 'number'),
  ('provider_main_screen_bg_image_url', '', 'text'),
  ('provider_main_header_opacity', '1.0', 'number'),
  ('provider_main_header_gradient_start', '#1A56DB', 'text'),
  ('provider_main_header_gradient_end', '#7C3AED', 'text'),
  ('provider_main_header_text_color', '#FFFFFF', 'text'),
  ('provider_main_available_color', '#4ADE80', 'text'),
  ('provider_main_unavailable_color', '#F87171', 'text'),
  ('provider_main_header_icon_btn_bg', '#FFFFFF3D', 'text'),
  ('provider_main_header_icon_btn_icon', '#FFFFFF', 'text'),
  ('provider_main_card_bg', '#FFFFFF', 'text'),
  ('provider_main_card_border', '#E5E7EB', 'text'),
  ('provider_main_urgent_border', '#F59E0B', 'text'),
  ('provider_main_action_btn_bg', '#1A56DB', 'text'),
  ('provider_main_action_btn_text', '#FFFFFF', 'text'),
  ('provider_main_secondary_action_btn_bg', '#E5E7EB', 'text'),
  ('provider_main_tab_selected_bg', '#1A56DB', 'text'),
  ('provider_main_tab_unselected_bg', '#00000000', 'text'),
  ('provider_main_tab_selected_text', '#FFFFFF', 'text'),
  ('provider_main_tab_unselected_text', '#6B7280', 'text')
ON CONFLICT (setting_key) DO NOTHING;
