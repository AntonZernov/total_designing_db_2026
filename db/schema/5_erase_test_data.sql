create or replace procedure zernov_food.erase_test_data()
language plpgsql
as $$
begin
    truncate table
        zernov_food.review,
        zernov_food.order_structure,
        zernov_food.payment,
        zernov_food.orders,
        zernov_food.product,
        zernov_food.product_category,
        zernov_food.courier_pay,
        zernov_food.courier,
        zernov_food.courier_profile,
        zernov_food.restaurant,
        zernov_food.client_address,
        zernov_food.address,
        zernov_food.client
    cascade;
end;
$$;