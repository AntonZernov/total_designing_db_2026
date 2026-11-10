create or replace view zernov_food.how_much_money as
with recursive limits as (
    select
        date_trunc('month', min(od.order_timestamp)) as min_month,
        date_trunc('month', max(od.order_timestamp)) as max_month
    from zernov_food.orders od
    where od.status = 'доставлен'
),
months_series (month_date) as (
    select min_month from limits where min_month is not null
    union all
    select (month_date + interval '1 month')::timestamp
    from months_series
    where month_date < (select max_month from limits)
),
order_metrics as (
    select
        date_trunc('month', od.order_timestamp) as order_month,
        sum(od.order_amount)::numeric as sum_no_commission,
        sum(od.total_amount)::numeric as sum_with_commission,
        (sum(od.total_amount) - sum(od.order_amount))::numeric as commission
    from zernov_food.orders od
    where od.status = 'доставлен'
    group by date_trunc('month', od.order_timestamp)
),
salary_metrics as (
    select
        to_date(cp.year || '-' || cp.month || '-01', 'YYYY-MM-DD') as salary_month,
        sum(cp.amount)::numeric as courier_pay
    from zernov_food.courier_pay cp
    group by cp.year, cp.month
),
combined_metrics as (
    select
        to_char(ms.month_date, 'YYYY-MM') as year_month,
        coalesce(om.sum_no_commission, 0.00) as sum_no_commission,
        coalesce(om.sum_with_commission, 0.00) as sum_with_commission,
        coalesce(om.commission, 0.00) as commission,
        coalesce(sm.courier_pay, 0.00) as courier_pay
    from months_series ms
    left join order_metrics om on ms.month_date = om.order_month
    left join salary_metrics sm on ms.month_date = sm.salary_month
),
windowed_metrics as (
    select
        cm.year_month,
        cm.sum_no_commission,
        cm.sum_with_commission,
        cm.commission,
        lag(cm.commission) over (order by cm.year_month) as prev_commission,
        cm.courier_pay
    from combined_metrics cm
)
select
    wm.year_month::text as year_month,
    wm.sum_no_commission,
    wm.sum_with_commission,
    wm.commission,
    wm.prev_commission,
    (wm.commission - wm.prev_commission) as commission_diff,
    wm.courier_pay,
    (wm.commission - wm.courier_pay) as net_profit
from windowed_metrics wm;
