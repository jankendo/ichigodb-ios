create or replace function public.get_analysis_snapshot()
returns jsonb
language sql
stable
as $$
with active_varieties as (
    select * from public.varieties where deleted_at is null
),
active_reviews as (
    select r.*, v.name as variety_name, v.origin_prefecture
    from public.reviews r
    join active_varieties v on v.id = r.variety_id
    where r.deleted_at is null
),
variety_scores as (
    select
        variety_id,
        max(variety_name) as variety_name,
        count(*)::integer as review_count,
        round(avg(overall)::numeric, 2) as average_overall,
        round(avg(sweetness)::numeric, 2) as sweetness,
        round(avg(sourness)::numeric, 2) as sourness,
        round(avg(aroma)::numeric, 2) as aroma,
        round(avg(texture)::numeric, 2) as texture,
        round(avg(appearance)::numeric, 2) as appearance,
        max(tasted_date) as latest_review_date
    from active_reviews
    group by variety_id
)
select jsonb_build_object(
    'generated_at', now(),
    'variety_count', (select count(*) from active_varieties),
    'review_count', (select count(*) from active_reviews),
    'discovered_count', (select count(distinct variety_id) from active_reviews),
    'average_overall', coalesce((select round(avg(overall)::numeric, 2) from active_reviews), 0),
    'top_overall', coalesce((select jsonb_agg(to_jsonb(t)) from (
        select variety_id, variety_name, review_count, average_overall, latest_review_date
        from variety_scores
        order by average_overall desc, review_count desc, latest_review_date desc
        limit 20
    ) t), '[]'::jsonb),
    'trait_leaders', jsonb_build_object(
        'sweetness', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from (select variety_id, variety_name, review_count, sweetness as average_score from variety_scores order by sweetness desc, review_count desc limit 10) t),
        'sourness', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from (select variety_id, variety_name, review_count, sourness as average_score from variety_scores order by sourness desc, review_count desc limit 10) t),
        'aroma', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from (select variety_id, variety_name, review_count, aroma as average_score from variety_scores order by aroma desc, review_count desc limit 10) t),
        'texture', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from (select variety_id, variety_name, review_count, texture as average_score from variety_scores order by texture desc, review_count desc limit 10) t),
        'appearance', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from (select variety_id, variety_name, review_count, appearance as average_score from variety_scores order by appearance desc, review_count desc limit 10) t)
    ),
    'prefectures', coalesce((select jsonb_agg(to_jsonb(t)) from (
        select coalesce(origin_prefecture, '未設定') as prefecture,
               count(*)::integer as review_count,
               count(distinct variety_id)::integer as variety_count,
               round(avg(overall)::numeric, 2) as average_overall
        from active_reviews
        group by coalesce(origin_prefecture, '未設定')
        order by review_count desc, average_overall desc
        limit 47
    ) t), '[]'::jsonb),
    'monthly', coalesce((select jsonb_agg(to_jsonb(t)) from (
        select to_char(date_trunc('month', tasted_date), 'YYYY-MM') as month,
               count(*)::integer as review_count,
               round(avg(overall)::numeric, 2) as average_overall
        from active_reviews
        group by date_trunc('month', tasted_date)
        order by month desc
        limit 24
    ) t), '[]'::jsonb),
    'cost_performance', coalesce((select jsonb_agg(to_jsonb(t)) from (
        select variety_id,
               max(variety_name) as variety_name,
               count(*)::integer as review_count,
               round(avg(overall)::numeric, 2) as average_overall,
               round(avg(price_jpy)::numeric, 0) as average_price_jpy,
               round((avg(overall)::numeric * 1000 / nullif(avg(price_jpy)::numeric, 0)), 2) as score_per_1000_yen
        from active_reviews
        where price_jpy is not null and price_jpy > 0
        group by variety_id
        order by score_per_1000_yen desc, average_overall desc
        limit 20
    ) t), '[]'::jsonb)
);
$$;

grant execute on function public.get_analysis_snapshot() to anon, authenticated;
