create or replace procedure zernov_food.courier_salary()
as $$
declare
    current_year int := extract(year from localtimestamp)::int;
    current_month int := extract(month from localtimestamp)::int;
begin
    with current_metrics as (
        select
            co.courier_id,
            co.status,
            co.coefficient as current_coeff,
            count(od.order_id) as order_count,
            coalesce(sum(od.commission), 0.00) as total_comm
        from zernov_food.courier co
        left join zernov_food.orders od on co.courier_id = od.courier_id
            and od.status = 'доставлен'
            and extract(year from od.order_timestamp) = current_year
            and extract(month from od.order_timestamp) = current_month
        group by co.courier_id, co.status, co.coefficient
    ),
    calculated_salary as (
        select
            cm.courier_id,
            cm.status,
            (cm.current_coeff * cm.total_comm)::numeric(8, 2) as salary_amount,
            case
                when cm.order_count between 0 and 150 then 0.1
                when cm.order_count between 151 and 250 then 0.2
                when cm.order_count between 251 and 500 then 0.3
                else 0.5
            end as next_coeff
        from current_metrics cm
    ),
    upsert_pay as (
        insert into zernov_food.courier_pay (year, month, courier_id, amount, coefficient_used)
        select current_year, current_month, cs.courier_id, cs.salary_amount, cs.next_coeff
        from calculated_salary cs
        on conflict (year, month, courier_id) do update
        set amount = excluded.amount,
            coefficient_used = excluded.coefficient_used
        returning courier_id
    )
    update zernov_food.courier co
    set coefficient = cs.next_coeff
    from calculated_salary cs
    where co.courier_id = cs.courier_id
      and co.status != 'уволен'
      and co.courier_id in (select up.courier_id from upsert_pay up);
end;
$$ language plpgsql;
