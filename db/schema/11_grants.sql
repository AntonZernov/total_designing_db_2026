create user inspector with password 'NetoSQL2025';

grant all privileges on schema zernov_food to inspector;

grant usage on schema information_schema to inspector;
grant usage on schema pg_catalog to inspector;

grant usage on schema exts to inspector;
grant execute on function exts.uuid_generate_v4() to inspector;

grant execute on function zernov_food.rating_change() to inspector;
grant execute on function zernov_food.check_review_constraints() to inspector;
grant execute on procedure zernov_food.insert_test_data(int) to inspector;
grant execute on procedure zernov_food.erase_test_data() to inspector;
grant execute on procedure zernov_food.add_product(varchar, uuid, numeric, uuid, text, numeric, zernov_food.product_status, text) to inspector;
grant execute on function zernov_food.get_statistic() to inspector;
grant execute on procedure zernov_food.courier_salary() to inspector;

grant select on table zernov_food.how_much_money to inspector;
grant insert, select, update, delete, truncate on table zernov_food.client to inspector;
grant insert, select, update, delete, truncate on table zernov_food.address to inspector;
grant insert, select, update, delete, truncate on table zernov_food.client_address to inspector;
grant insert, select, update, delete, truncate on table zernov_food.restaurant to inspector;
grant insert, select, update, delete, truncate on table zernov_food.courier to inspector;
grant insert, select, update, delete, truncate on table zernov_food.courier_profile to inspector;
grant insert, select, update, delete, truncate on table zernov_food.courier_pay to inspector;
grant insert, select, update, delete, truncate on table zernov_food.product_category to inspector;
grant insert, select, update, delete, truncate on table zernov_food.product to inspector;
grant insert, select, update, delete, truncate on table zernov_food.orders to inspector;
grant insert, select, update, delete, truncate on table zernov_food.payment to inspector;
grant insert, select, update, delete, truncate on table zernov_food.order_structure to inspector;
grant insert, select, update, delete, truncate on table zernov_food.review to inspector;
