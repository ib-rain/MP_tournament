--#1: Data sanity checks.
--Result: all is good, all assumptions hold, only one duplicate in ads.
with
    fact_pay as (
        select
            fact_ts,
            timestamp 'epoch' + fact_ts::bigint * interval '1 second' as ts,
            user_id,
            amount
        from prod_seeds.fact_payment as fp
    ),

    fact_ads as (
        select
            fact_ts,
            timestamp 'epoch' + fact_ts::bigint * interval '1 second' as ts,
            platform,
            ad_id,
            cost,
            impressions
        from prod_seeds.fact_ads as fa
    ),

    fact_reg as (
        select
            fact_ts,
            timestamp 'epoch' + fact_ts::bigint * interval '1 second' as ts,
            user_id,
            platform,
            ad_id,
            entry_point
        from prod_seeds.fact_reg as fr
    ),

    pk_check as (
        select
            count(*)                                  as cnt,
            count(distinct fact_ts || '_' || user_id) as pk,
            cnt - pk                                  as diff
        from fact_pay as fp
        --No duplicates

        union all

        select
            count(*)                                                   as cnt,
            count(distinct fact_ts || '_' || ad_id || '_' || platform) as pk,
            cnt - pk                                                   as diff
        from fact_ads as fa
        --One duplicate: 1661990400,Bing Ads,5837094

        union all

        select
            count(*)                                  as cnt,
            count(distinct fact_ts || '_' || user_id) as pk,
            cnt - pk                                  as diff
        from fact_reg as fr
        --No duplicates
    ),

    dedup as (
        select fa.*
        from fact_ads as fa
        inner join (
            select fact_ts || '_' || ad_id || '_' || platform as pk
            from fact_ads
            group by
                1
            having
                count(*) > 1
        ) as dt
        on (fa.fact_ts || '_' || fa.ad_id || '_' || fa.platform) = dt.pk
    ),

    reg_cnt as (
        select
            cnt,
            pl,
            ad,
            ep,

            count(*) as cnt_
        from (
            select
                user_id,

                count(*)                    as cnt,
                count(distinct platform)    as pl,
                count(distinct ad_id)       as ad,
                count(distinct entry_point) as ep
            from fact_reg as fr
            group by
                1
        ) as dt
        group by
            1, 2, 3, 4
    ),

    pay_cnt as (
        select
            cnt,
            ts,
            am,

            count(*) as cnt_
        from (
            select
                user_id,

                count(*)                as cnt,
                count(distinct fact_ts) as ts,
                count(distinct amount)  as am
            from fact_pay as fp
            group by
                1
        ) as dt
        group by
            1, 2, 3
    ),

    multibuyers as (
        select fp.*
        from fact_pay as fp
        inner join (
            select user_id
            from fact_pay as fp_
            group by
                1
            having
                count(*) > 1
        ) as dt
        on fp.user_id = dt.user_id
        order by
            3, 4, 1, 2
    ),

    datetime_cmp as (
        with
            ads as (
                select
                    ad_id,

                    min(ts) as min_ts,
                    max(ts) as max_ts
                from fact_ads
                group by
                    1
            ),

            reg as (
                select
                    user_id,
                    ad_id,

                    min(ts) as min_ts,
                    max(ts) as max_ts
                from fact_reg
                group by
                    1, 2
            ),

            pay as (
                select
                    user_id,

                    min(ts) as min_ts,
                    max(ts) as max_ts
                from fact_pay
                group by
                    1
            ),

            ads_vs_reg__ts as (
                select
                    cmp,

                    count(*) as cnt
                from (
                    select
                        ad_id,

                        min(ads.min_ts) as ads_min_ts,
                        min(reg.min_ts) as reg_min_ts,

                        case
                            when ads_min_ts < reg_min_ts then '<'
                            when ads_min_ts = reg_min_ts then '='
                            when ads_min_ts > reg_min_ts then '>'
                        end             as cmp
                    from ads
                    full outer join reg
                    using (ad_id)
                    group by
                        1
                ) as dt
                group by
                    1
            ),

            --**Note**: It is assumed that the ad impression day matches the user registration day.
            --This assumption holds.
            ads_vs_reg__day as (
                select
                    cmp,

                    count(*) as cnt
                from (
                    select
                        ad_id,

                        min(ads.min_ts)::date as ads_min_date,
                        min(reg.min_ts)::date as reg_min_date,

                        case
                            when ads_min_date < reg_min_date then '<'
                            when ads_min_date = reg_min_date then '='
                            when ads_min_date > reg_min_date then '>'
                        end                   as cmp
                    from ads
                    full outer join reg
                    using (ad_id)
                    group by
                        1
                ) as dt
                group by
                    1
            ),

            reg_vs_pay__ts as (
                select
                    cmp,

                    count(*) as cnt
                from (
                    select
                        user_id,

                        min(reg.min_ts) as reg_min_ts,
                        min(pay.min_ts) as pay_min_ts,

                        case
                            when reg_min_ts < pay_min_ts then '<'
                            when reg_min_ts = pay_min_ts then '='
                            when reg_min_ts > pay_min_ts then '>'
                        end             as cmp
                    from reg
                    full outer join pay
                    using (user_id)
                    group by
                        1
                ) as dt
                group by
                    1
            ),

            reg_vs_pay__day as (
                select
                    cmp,

                    count(*) as cnt
                from (
                    select
                        user_id,

                        min(reg.min_ts)::date as reg_min_date,
                        min(pay.min_ts)::date as pay_min_date,

                        case
                            when reg_min_date < pay_min_date then '<'
                            when reg_min_date = pay_min_date then '='
                            when reg_min_date > pay_min_date then '>'
                        end                   as cmp
                    from reg
                    full outer join pay
                    using (user_id)
                    group by
                        1
                ) as dt
                group by
                    1
            )

        select *
        from reg_vs_pay__day
    )

select *
from datetime_cmp;

--#2: Checking the amount of hours/days between registration and payment.
--Result: nothing interesting.
with
    fact_pay as (
        select
            timestamp 'epoch' + fact_ts::bigint * interval '1 second' as ts,
            user_id,

            max(amount)                                               as amount
        from prod_seeds.fact_payment as pay
        group by
            1, 2
    ),

    fact_reg as (
        select
            timestamp 'epoch' + fact_ts::bigint * interval '1 second' as ts,
            user_id,
            ad_id,
            platform,

            min(entry_point)                                          as entry_point
        from prod_seeds.fact_reg as reg
        group by
            1, 2, 3, 4
    ),

    reg_day as (
        select
            user_id,
            min(ts) as reg_ts
        from fact_reg as fr
        group by
            1
    ),

    pay_wide as (
        select
            rd.user_id,
            rd.reg_ts,

            fp.ts                                 as pay_ts,
            fp.amount                             as pay_amount,

            date_diff('hours', rd.reg_ts, pay_ts) as diff_hrs,
            date_diff('day', rd.reg_ts, pay_ts)   as diff_days
        from reg_day as rd
        inner join fact_pay as fp
        on rd.user_id = fp.user_id
        order by
            1, 2, 3, 4
    ),

    min_max_diff as (
        select
            user_id,

            min(diff_days) as min_diff_days,
            max(diff_days) as max_diff_days
        from pay_wide as pw
        group by
            1
    )

select
    'all'                as type,
    avg(1.0 * diff_days) as avg_diff_days
from pay_wide as rp

union all

select
    'first'                  as type,
    avg(1.0 * min_diff_days) as avg_diff_days
from min_max_diff
union all

select
    'last'                   as type,
    avg(1.0 * max_diff_days) as avg_diff_days
from min_max_diff;
