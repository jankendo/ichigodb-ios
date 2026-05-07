revoke all privileges on public.variety_library_cards from anon;
revoke all privileges on public.review_analysis_cards from anon;
revoke all privileges on public.variety_library_cards from authenticated;
revoke all privileges on public.review_analysis_cards from authenticated;

grant select on public.variety_library_cards to authenticated;
grant select on public.review_analysis_cards to authenticated;
