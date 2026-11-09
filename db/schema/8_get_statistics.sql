create or replace function zernov_food.get_statistic()
returns table (
    restaurant_name varchar(64),
    best_product_name varchar(128),
    total_amount numeric(8, 2),
    avg_amount numeric(8, 2),
    best_user varchar(32)
) as $$
begin
    return query
    with delivered_orders as (
        select od.order_id, od.restaurant_id, od.client_id, od.total_amount, re.restaurant_name
        from zernov_food.orders od
        join zernov_food.restaurant re on od.restaurant_id = re.restaurant_id
        where od.status = 'доставлен'
    ),
    restaurant_metrics as (
        select
            dor.restaurant_id,
            dor.restaurant_name,
            sum(dor.total_amount)::numeric(8, 2) as tot_amt,
            round(avg(dor.total_amount), 2)::numeric(8, 2) as avg_amt
        from delivered_orders dor
        group by dor.restaurant_id, dor.restaurant_name
    ),
    top_products as (
        select distinct on (os.restaurant_id) os.restaurant_id, pr.product_name
        from zernov_food.order_structure os
        join zernov_food.product pr on os.product_id = pr.product_id
        where os.order_id in (select dor.order_id from delivered_orders dor)
        group by os.restaurant_id, pr.product_name
        order by os.restaurant_id, sum(os.quantity) desc, pr.product_name
    ),
    top_users as (
        select distinct on (dor.restaurant_id) dor.restaurant_id, cl.login
        from delivered_orders dor
        join zernov_food.client cl on dor.client_id = cl.client_id
        group by dor.restaurant_id, cl.login
        order by dor.restaurant_id, count(dor.order_id) desc, cl.login
    )
    select
        rm.restaurant_name,
        coalesce(tp.product_name, 'Нет данных'),
        rm.tot_amt,
        rm.avg_amt,
        coalesce(tu.login, 'Нет данных')
    from restaurant_metrics rm
    left join top_products tp on rm.restaurant_id = tp.restaurant_id
    left join top_users tu on rm.restaurant_id = tu.restaurant_id;
end;
$$ language plpgsql;
