create or replace function zernov_food.rating_change()
returns trigger
language plpgsql
as $$
declare
    entityid uuid;
begin
    if tg_table_name = 'product_reviews' then
        if tg_op = 'INSERT' or tg_op = 'UPDATE' or tg_op = 'DELETE' then
            if tg_op = 'DELETE' then
                entityid := old.product_id;
            else
                entityid := new.product_id;
            end if;

            update zernov_food.product
            set rating = (
                select avg(r.rating)
                from zernov_food.product_reviews pr
                join zernov_food.review r on pr.review_id = r.review_id
                where pr.product_id = entityid
            )
            where product_id = entityid;
        end if;

    elsif tg_table_name = 'restaurant_reviews' then
        if tg_op = 'INSERT' or tg_op = 'UPDATE' or tg_op = 'DELETE' then
            if tg_op = 'DELETE' then
                entityid := old.restaurant_id;
            else
                entityid := new.restaurant_id;
            end if;

            update zernov_food.restaurant
            set rating = (
                select avg(r.rating)
                from zernov_food.restaurant_reviews rr
                join zernov_food.review r on rr.review_id = r.review_id
                where rr.restaurant_id = entityid
            )
            where restaurant_id = entityid;
        end if;

    elsif tg_table_name = 'review' then
        if tg_op = 'UPDATE' then
            entityid := new.review_id;
            update zernov_food.product_reviews set review_id = review_id where review_id = entityid;
            update zernov_food.restaurant_reviews set review_id = review_id where review_id = entityid;
        end if;
    end if;

    if tg_op = 'DELETE' then
        return old;
    else
        return new;
    end if;
end;
$$;

create trigger trg_product_rating_change
    after insert or update or delete on zernov_food.product_reviews
    for each row execute function zernov_food.rating_change();

create trigger trg_restaurant_rating_change
    after insert or update or delete on zernov_food.restaurant_reviews
    for each row execute function zernov_food.rating_change();

create trigger trg_order_rating_change
    after insert or update or delete on zernov_food.order_reviews
    for each row execute function zernov_food.rating_change();

create trigger trg_review_rating_update
    after update on zernov_food.review
    for each row execute function zernov_food.rating_change();
