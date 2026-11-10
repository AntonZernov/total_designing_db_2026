create or replace function zernov_food.get_statistic()
returns table (
    restaurant_name varchar(64),
    best_product_name varchar(128),
    total_amount numeric(10, 2),
    avg_amount numeric(8, 2),
    best_user varchar(32)
) as $$
begin
    return query
    with delivered_orders as (
        select od.order_id, od.restaurant_id, od.client_id, od.total_amount
        from zernov_food.orders od
        where od.status = 'доставлен'
    ),
    restaurant_metrics as (
        select
            re.restaurant_id,
            re.restaurant_name,
            coalesce(sum(dor.total_amount), 0.00) as tot_amt,
            coalesce(round(avg(dor.total_amount), 2), 0.00)::numeric(8, 2) as avg_amt
        from zernov_food.restaurant re
        left join delivered_orders dor on re.restaurant_id = dor.restaurant_id
        group by re.restaurant_id, re.restaurant_name
    ),
    top_products as (
        select distinct on (dor.restaurant_id) dor.restaurant_id, pr.product_name
        from delivered_orders dor
        join zernov_food.order_structure os on dor.order_id = os.order_id
        join zernov_food.product pr on os.product_id = pr.product_id
        group by dor.restaurant_id, pr.product_id, pr.product_name
        order by dor.restaurant_id, sum(os.quantity) desc, random()
    ),
    top_users as (
        select distinct on (dor.restaurant_id) dor.restaurant_id, cl.login
        from delivered_orders dor
        join zernov_food.client cl on dor.client_id = cl.client_id
        group by dor.restaurant_id, cl.client_id, cl.login
        order by dor.restaurant_id, count(dor.order_id) desc, random()
    )
    select
        rm.restaurant_name,
        tp.product_name,
        rm.tot_amt,
        rm.avg_amt,
        tu.login
    from restaurant_metrics rm
    left join top_products tp on rm.restaurant_id = tp.restaurant_id
    left join top_users tu on rm.restaurant_id = tu.restaurant_id;
end;
$$ language plpgsql;
