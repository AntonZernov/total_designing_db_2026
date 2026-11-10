create or replace function zernov_food.check_review_constraints()
returns trigger as $$
begin
    if exists (
        select 1
        from zernov_food.review
        where order_id = new.order_id
          and entity_type = new.entity_type
          and entity_id = new.entity_id
          and (TG_OP = 'INSERT' or review_id != old.review_id)
    ) then
        raise exception 'В рамках одного заказа нельзя оставить более одного отзыва на один и тот же объект';
    end if;

    if new.entity_type = 'блюдо' then
        if not exists (
            select 1
            from zernov_food.order_structure
            where order_id = new.order_id and product_id = new.entity_id
        ) then
            raise exception 'Нельзя оставить отзыв на блюдо, которого не было в заказе';
        end if;
    elsif new.entity_type = 'ресторан' then
        if not exists (
            select 1
            from zernov_food.orders
            where order_id = new.order_id and restaurant_id = new.entity_id
        ) then
            raise exception 'Нельзя оставить отзыв на этот ресторан, заказ был сделан в другом месте';
        end if;
    end if;

    return new;
end;
$$ language plpgsql;

create trigger trg_review_constraints_biu
before insert or update on zernov_food.review
for each row
execute function zernov_food.check_review_constraints();
