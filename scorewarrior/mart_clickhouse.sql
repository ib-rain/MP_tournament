with
    payments as (
        select
            toDate(fact_ts) as ts,
            user_id,

            max(amount)     as amount
        from file('fact_payment.csv', CSVWithNames)
        group by
            1, 2
    ),

    advertisements as (
        select
            toDate(fact_ts)  as ts,
            platform,
            ad_id,

            sum(cost)        as cost,
            sum(impressions) as impressions
        from file('fact_ads.csv', CSVWithNames)
        group by
            1, 2, 3
    ),

    installations as ( --Registrations = installations.
        select
            toDate(fact_ts) as ts,
            user_id,
            ad_id,
            platform

            --Unfortunately, an unnecessary field with uninteresting stats, dropping.
            --min(entry_point) as entry_point
        from file('fact_reg.csv', CSVWithNames)
        group by
            1, 2, 3, 4
    ),

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
            toDate(ins.ts)         as date,
            ins.ad_id,
            ins.platform,
            
            uniqExact(ins.user_id) as number_of_installations_,
            uniqExact(pa.user_id)  as number_of_payers_,
            sum(pa.amount)         as payment_amount_
        from installations as ins
        left join payments_agg as pa
        on ins.user_id = pa.user_id
        group by
            1, 2, 3
    ),

    ads_agg as (
        select
            toDate(ts)       as date,
            ad_id,
            platform,

            sum(cost)        as cost_,
            sum(impressions) as impressions_
        from advertisements
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
FORMAT CSVWithNames
