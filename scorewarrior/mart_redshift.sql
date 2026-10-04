with
    payments as (
        select
            timestamp 'epoch' + fact_ts::bigint * interval '1 second' as ts,
            user_id,

            --If there is a duplication on ts-user_id level, I assume it's a data bug and take only the max.
            max(amount)                                               as amount
        from prod_seeds.fact_payment as fp
        group by
            1, 2
    ),

    advertisements as (
        select
            timestamp 'epoch' + fact_ts::bigint * interval '1 second' as ts,
            platform,
            ad_id,

            --If there is a duplication on ts-platform-ad_id level, I assume there is a split so I sum them.
            sum(cost)                                                 as cost,
            sum(impressions)                                          as impressions
        from prod_seeds.fact_ads as fa
        group by
            1, 2, 3
    ),

    installations as (
        select
            timestamp 'epoch' + fact_ts::bigint * interval '1 second' as ts,
            user_id,
            ad_id,
            platform

        --Unfortunately, an unnecessary field with uninteresting stats, dropping.
        --min(entry_point)                                          as entry_point
        from prod_seeds.fact_reg as fr --Registrations = installations.
        group by
            1, 2, 3, 4
    ),

    --Check #2 showed that there are no interesting patterns in payment dates so I collapse them to user_id.
    payments_agg as (
        select
            user_id,

            sum(amount) as amount
        from payments as pay
        group by
            1
    ),

    reg_pay_agg as (
        select
            ins.ts::date                as date,
            ins.ad_id,
            ins.platform,

            count(distinct ins.user_id) as number_of_installations_,
            count(distinct pa.user_id)  as number_of_payers_,
            sum(pa.amount)              as payment_amount_
        from installations as ins
        left join payments_agg as pa
        on ins.user_id = pa.user_id
        group by
            1, 2, 3
    ),

    ads_agg as (
        select
            ts::date         as date,
            ad_id,
            platform,

            sum(cost)        as cost_,
            sum(impressions) as impressions_
        from advertisements as ad
        group by
            1, 2, 3
    ),

    final as (
        select
            ada.date,
            ada.ad_id,
            ada.platform,

            max(ada.cost_)                          as cost,
            max(ada.impressions_)                   as impressions,

            max(rpa.number_of_installations_)       as number_of_installations,
            coalesce(max(rpa.number_of_payers_), 0) as number_of_payers,
            coalesce(max(rpa.payment_amount_), 0.0) as payment_amount
        from ads_agg as ada
        left join reg_pay_agg as rpa
        on
            (ada.date, ada.ad_id, ada.platform) =
                (rpa.date, rpa.ad_id, rpa.platform)
        group by
            1, 2, 3
    )

select
    date,
    ad_id,
    platform,
    cost,
    impressions,
    number_of_installations,
    number_of_payers,
    payment_amount
from final
order by
    1, 2, 3
