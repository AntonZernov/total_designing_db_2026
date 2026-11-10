create or replace function zernov_food.rating_change()
returns trigger
language plpgsql
as $$
begin
    if (tg_op = 'DELETE') or (tg_op = 'UPDATE' and (old.entity_id != new.entity_id or old.entity_type != new.entity_type)) then
        if old.entity_type = 'блюдо' then
            update zernov_food.product
            set rating = (
                select round(avg(rating), 2)
                from zernov_food.review
                where entity_type = 'блюдо' and entity_id = old.entity_id
            )
            where product_id = old.entity_id;

        elsif old.entity_type = 'ресторан' then
            update zernov_food.restaurant
            set rating = (
                select round(avg(rating), 2)
                from zernov_food.review
                where entity_type = 'ресторан' and entity_id = old.entity_id
            )
            where restaurant_id = old.entity_id;
        end if;
    end if;

    if (tg_op = 'INSERT') or (tg_op = 'UPDATE') then
        if new.entity_type = 'блюдо' then
            update zernov_food.product
            set rating = (
                select round(avg(rating), 2)
                from zernov_food.review
                where entity_type = 'блюдо' and entity_id = new.entity_id
            )
            where product_id = new.entity_id;

        elsif new.entity_type = 'ресторан' then
            update zernov_food.restaurant
            set rating = (
                select round(avg(rating), 2)
                from zernov_food.review
                where entity_type = 'ресторан' and entity_id = new.entity_id
            )
            where restaurant_id = new.entity_id;
        end if;
    end if;

    if tg_op = 'DELETE' then
        return old;
    end if;
    return new;
end;
$$;

create trigger trg_rating_change
    after insert or update or delete on zernov_food.review
    for each row execute function zernov_food.rating_change();
