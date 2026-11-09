create or replace procedure zernov_food.insert_test_data(val int)
language plpgsql
as $$
declare
    i int;
    month int;
    days_offset int;
    clientid uuid;
    restaurantid uuid;
    addressid uuid;
    courierid uuid;
    productid uuid;
    orderid uuid;
    productprice numeric;
    reviewid uuid;

    arr_courier_statuses zernov_food.courier_status[];
    arr_payment_types zernov_food.payment_type[];
    arr_pay_attempt_statuses zernov_food.pay_attempt_status[];

    arr_coefficients numeric[] := array[0.1, 0.2, 0.3, 0.5];
begin
    arr_courier_statuses := (select enum_range(null::zernov_food.courier_status))::zernov_food.courier_status[];
    arr_payment_types := (select enum_range(null::zernov_food.payment_type))::zernov_food.payment_type[];
    arr_pay_attempt_statuses := (select enum_range(null::zernov_food.pay_attempt_status))::zernov_food.pay_attempt_status[];

    for i in 1..val loop
        insert into zernov_food.client (client_id, login, password, phone_number)
        values (
            exts.uuid_generate_v4(),
            'логин' || substr(exts.uuid_generate_v4()::text, 1, 8),
            md5(random()::text),
            '+7910' || floor(random()*8999999+1000000)::text
        ) returning client_id into clientid;

        insert into zernov_food.product_category (product_category_id, product_category_name)
        values (
            exts.uuid_generate_v4(),
            'Категория ' || substr(exts.uuid_generate_v4()::text, 1, 8)
        );

        insert into zernov_food.courier (courier_id, fio, phone_number, status, hire_date, coefficient)
        values (
            exts.uuid_generate_v4(),
            'Курьер ' || i,
            '+7920' || floor(random()*8999999+1000000)::text,
            arr_courier_statuses[1 + floor(random() * 3)::int],
            current_date - 200,
            arr_coefficients[1 + floor(random() * 4)::int]
        );
    end loop;

    for i in 1..val loop
        insert into zernov_food.address (address_id, street, house_number)
        values (exts.uuid_generate_v4(), 'Московская', i::varchar)
        returning address_id into addressid;

        insert into zernov_food.restaurant (restaurant_id, restaurant_name, address_id, description, work_start, work_end, status)
        values (
            exts.uuid_generate_v4(),
            'Столовая ' || i,
            addressid,
            'Описание столовой',
            '09:00:00'::time,
            '23:00:00'::time,
            'активен'
        ) returning restaurant_id into restaurantid;

        for i in 1..5 loop
            insert into zernov_food.product (product_id, restaurant_id, product_category_id, product_name, price, status, description)
            values (
                exts.uuid_generate_v4(),
                restaurantid,
                (select product_category_id from zernov_food.product_category order by random() limit 1),
                'Суп' || i || substr(exts.uuid_generate_v4()::text, 1, 8),
                600.00,
                'доступно',
                'Вкусное блюдо'
            );
        end loop;
    end loop;

    for i in 1..(val * 4) loop
        insert into zernov_food.address (address_id, street, house_number, apartment_office)
        values (exts.uuid_generate_v4(), 'Ленина', i::varchar, (i * 2)::varchar)
        returning address_id into addressid;

        insert into zernov_food.client_address (client_id, address_id)
        values ((select client_id from zernov_food.client order by random() limit 1), addressid);
    end loop;

    for month in reverse 6..1 loop
        for i in 1..ceil((val * 5) / 6.0)::int loop
            select client_id into clientid from zernov_food.client order by random() limit 1;
            select address_id into addressid from zernov_food.client_address where client_id = clientid limit 1;

            select courier_id into courierid from zernov_food.courier order by random() limit 1;
            select restaurant_id into restaurantid from zernov_food.restaurant order by random() limit 1;
            select product_id, price into productid, productprice from zernov_food.product where restaurant_id = restaurantid limit 1;

            if productid is not null and addressid is not null then
                days_offset := floor(random() * 25)::int;

                insert into zernov_food.orders (
                    order_id, client_id, restaurant_id, address_id, courier_id, status, pay_status,
                    order_amount, order_timestamp, delivery_timestamp
                ) values (
                    exts.uuid_generate_v4(), clientid, restaurantid, addressid, courierid, 'доставлен', 'оплачен',
                    productprice * 2,
                    current_date - (month * 30) + days_offset,
                    current_date - (month * 30) + days_offset + interval '40 minutes'
                ) returning order_id into orderid;

                insert into zernov_food.order_structure (order_id, product_id, restaurant_id, quantity)
                values (orderid, productid, restaurantid, 2);

                insert into zernov_food.payment (payment_id, order_id, payment_type, amount, transaction_id, status, payment_timestamp)
                values (
                    exts.uuid_generate_v4(),
                    orderid,
                    arr_payment_types[1 + floor(random() * array_length(arr_payment_types, 1))::int],
                    (select total_amount from zernov_food.orders where order_id = orderid),
                    'tx' || floor(random()*1000000) || substr(exts.uuid_generate_v4()::text, 1, 4),
                    arr_pay_attempt_statuses[1 + floor(random() * array_length(arr_pay_attempt_statuses, 1))::int],
                    current_date - (month * 30) + days_offset
                );
            end if;
        end loop;
    end loop;

    for courierid in select courier_id from zernov_food.courier loop
        for month in 1..6 loop
            insert into zernov_food.courier_pay (year, month, courier_id, amount, coefficient_used)
            values (
                2026,
                month,
                courierid,
                3000.00 + floor(random() * 6000),
                arr_coefficients[1 + floor(random() * 4)::int]
            )
            on conflict do nothing;
        end loop;
    end loop;

    for orderid, clientid, restaurantid in
        select order_id, client_id, restaurant_id from (
            select distinct o.order_id, o.client_id, o.restaurant_id
            from zernov_food.orders o
            where not exists (
                select 1 from zernov_food.review r where r.order_id = o.order_id
            )
        ) as unique_orders order by random() limit (val * 2)
    loop
        select product_id into productid from zernov_food.order_structure where order_id = orderid limit 1;

        insert into zernov_food.review (review_id, client_id, order_id, description, rating)
        values (exts.uuid_generate_v4(), clientid, orderid, 'Отзыв на заказ', (1 + floor(random() * 5))::numeric)
        returning review_id into reviewid;

        insert into zernov_food.order_reviews (review_id, order_id, entity_type)
        values (reviewid, orderid, 'заказ');

        insert into zernov_food.review (review_id, client_id, order_id, description, rating)
        values (exts.uuid_generate_v4(), clientid, orderid, 'Отзыв на ресторан', (1 + floor(random() * 5))::numeric)
        returning review_id into reviewid;

        insert into zernov_food.restaurant_reviews (review_id, restaurant_id, order_id, entity_type)
        values (reviewid, restaurantid, orderid, 'ресторан');

        if productid is not null then
            insert into zernov_food.review (review_id, client_id, order_id, description, rating)
            values (exts.uuid_generate_v4(), clientid, orderid, 'Отзыв на блюдо', (1 + floor(random() * 5))::numeric)
            returning review_id into reviewid;

            insert into zernov_food.product_reviews (review_id, product_id, order_id, entity_type)
            values (reviewid, productid, orderid, 'блюдо');
        end if;
	end loop;
end;
$$;
