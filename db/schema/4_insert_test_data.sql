create or replace procedure zernov_food.insert_test_data(value int)
language plpgsql
as $$
declare
    i int;
    v_idx int := 0;
    v_offset int;
    v_client_id uuid;
    v_address_id uuid;
    v_rest_id uuid;
    v_cat_id uuid;
    v_prof_id uuid;
    v_courier_id uuid;
    v_prod_id uuid;
    v_order_id uuid;
    v_qty numeric(8, 2);
    v_order_amount numeric(8, 2);
    v_total_amount numeric(8, 2);
    v_order_ts timestamp;
    v_deliv_ts timestamp;
    v_status zernov_food.order_status;
    v_pay_status zernov_food.order_pay_status;

    arr_streets text[] := array['Ленина', 'Пушкина', 'Гагарина', 'Мира', 'Советская', 'Тверская', 'Невский проспект', 'Садовая', 'Кирова', 'Победы'];
    arr_rests text[] := array['Белый кролик', 'Сыроварня', 'Пушкинъ', 'Хинкальная', 'Токио Сити', 'Итальянский дворик', 'Мясо и Рыба', 'Теремок', 'Шоколадница', 'Чайхона'];
    arr_cats text[] := array['Супы', 'Горячие блюда', 'Салаты', 'Закуски', 'Десерты', 'Напитки', 'Выпечка', 'Паста и ризотто', 'Роллы и суши', 'Гарниры'];
    arr_dishes text[] := array[
        'Борщ с пампушками', 'Стейк Рибай', 'Салат Цезарь с курицей', 'Карбонара классическая',
        'Том Ям с креветками', 'Хинкали с бараниной', 'Медовик домашний', 'Морс клюквенный',
        'Хачапури по-аджарски', 'Филадельфия с лососем', 'Уха по-фински', 'Бефстроганов с пюре',
        'Греческий салат', 'Брускетта с томатами', 'Тирамису', 'Лимонад маракуйя',
        'Пирожок с вишней', 'Ризотто с белыми грибами', 'Калифорния с крабом', 'Картофель по-деревенски',
        'Солянка мясная сборная', 'Котлета по-киевски', 'Оливье с телятиной', 'Сырная тарелка',
        'Чизкейк Нью-Йорк'
    ];
    arr_names text[] := array['Иванов Алексей Сергеевич', 'Смирнова Елена Викторовна', 'Кузнецов Дмитрий Андреевич', 'Попова Анна Николаевна', 'Васильев Максим Олегович', 'Петрова Ольга Владимировна', 'Соколов Артем Игоревич', 'Михайлова Мария Павловна', 'Новиков Сергей Александрович', 'Федорова Наталья Дмитриевна'];

    enum_rest_st zernov_food.restaurant_status[] := enum_range(null::zernov_food.restaurant_status);
    enum_prod_st zernov_food.product_status[] := enum_range(null::zernov_food.product_status);
    enum_cour_st zernov_food.courier_status[] := enum_range(null::zernov_food.courier_status);
    enum_ord_st zernov_food.order_status[] := enum_range(null::zernov_food.order_status);
    enum_pay_st zernov_food.pay_attempt_status[] := enum_range(null::zernov_food.pay_attempt_status);
    enum_pay_tp zernov_food.payment_type[] := enum_range(null::zernov_food.payment_type);

    ids_clients uuid[] := '{}';
    ids_rest_addrs uuid[] := '{}';
    ids_client_addrs uuid[] := '{}';
    ids_rests uuid[] := '{}';
    ids_cats uuid[] := '{}';
    ids_couriers uuid[] := '{}';

    m_date date;
    v_cnt int;
    v_comm_sum numeric(8, 2);
    v_curr_coeff numeric(2, 1);
    v_next_coeff numeric(2, 1);
    rec_courier record;
begin
    select coalesce(count(*), 0) into v_offset from zernov_food.client;

    for i in 1..(value * 5) loop
        v_address_id := exts.uuid_generate_v4();
        insert into zernov_food.address (address_id, street, house_number, apartment_office)
        values (
            v_address_id,
            case when i = 1 then left(repeat('Улица имени Героя Советского Союза ', 3), 64)
                 else arr_streets[1 + (i % 10)] end,
            ((i % 150) + 1)::text,
            case when i % 2 = 0 then ((i % 90) + 1)::text else null end
        );

        if i <= value then
            ids_rest_addrs := array_append(ids_rest_addrs, v_address_id);
        else
            ids_client_addrs := array_append(ids_client_addrs, v_address_id);
        end if;
    end loop;

    for i in 1..value loop
        v_client_id := exts.uuid_generate_v4();
        insert into zernov_food.client (client_id, login, password, phone_number)
        values (
            v_client_id,
            'user' || (v_offset + i)::text,
            md5(random()::text),
            '+79' || lpad((100000000 + v_offset + i)::text, 9, '0')
        );
        ids_clients := array_append(ids_clients, v_client_id);

        for j in 0..3 loop
            insert into zernov_food.client_address (client_id, address_id)
            values (v_client_id, ids_client_addrs[((i - 1) * 4) + j + 1]);
        end loop;
    end loop;

    for i in 1..value loop
        v_rest_id := exts.uuid_generate_v4();
        insert into zernov_food.restaurant (
            restaurant_id, restaurant_name, address_id, description,
            work_start, work_end, company_details, rating, status
        ) values (
            v_rest_id,
            case when i = 1 then left(repeat('Ресторан авторской кухни ', 5), 64)
                 else arr_rests[1 + ((i - 1) % 10)] end,
            ids_rest_addrs[i],
            'Уютное заведение с авторской кухней и быстрой доставкой свежих блюд.',
            '09:00:00'::time,
            '23:00:00'::time,
            'ООО «ФудГрупп», ИНН 770' || lpad((v_offset + i)::text, 7, '0') || ', р/с 40702810900000000001',
            null,
            enum_rest_st[1 + (i % array_length(enum_rest_st, 1))]
        );
        ids_rests := array_append(ids_rests, v_rest_id);
    end loop;

    for i in 1..value loop
        v_prof_id := exts.uuid_generate_v4();
        v_courier_id := exts.uuid_generate_v4();

        insert into zernov_food.courier_profile (courier_profile_id, fio, phone_number)
        values (
            v_prof_id,
            case when i = 1 then left(repeat('Константинопольский Александр Владимирович ', 4), 128)
                 else arr_names[1 + ((i - 1) % 10)] end,
            '+78' || lpad((100000000 + v_offset + i)::text, 9, '0')
        );

        insert into zernov_food.courier (
            courier_id, courier_profile_id, status, hire_date, dismissal_date, coefficient
        ) values (
            v_courier_id,
            v_prof_id,
            case when i = 1 then 'свободен'::zernov_food.courier_status
                 else enum_cour_st[1 + (i % array_length(enum_cour_st, 1))] end,
            (current_date - interval '7 months')::date,
            case when i != 1 and enum_cour_st[1 + (i % array_length(enum_cour_st, 1))] = 'уволен'
                 then (current_date - interval '5 days')::date else null end,
            0.1
        );
        ids_couriers := array_append(ids_couriers, v_courier_id);
    end loop;

    for i in 1..value loop
        v_cat_id := exts.uuid_generate_v4();
        insert into zernov_food.product_category (product_category_id, product_category_name)
        values (
            v_cat_id,
            arr_cats[1 + ((i - 1) % 10)] || case when (v_offset + i) > 10 then ' ' || (v_offset + i) else '' end
        );
        ids_cats := array_append(ids_cats, v_cat_id);
    end loop;

    for i in 1..(value * 5) loop
        v_prod_id := exts.uuid_generate_v4();
        v_rest_id := ids_rests[1 + ((i - 1) / 5)];

        insert into zernov_food.product (
            product_id, product_name, product_category_id, price, restaurant_id,
            photo_url, rating, status, description
        ) values (
            v_prod_id,
            case when i = 1 then left(repeat('Суп Харчо с говядиной и грецким орехом ', 5), 128)
                 else arr_dishes[1 + ((i - 1) % array_length(arr_dishes, 1))] end,
            ids_cats[1 + (i % value)],
            (450 + ((i * 3) % 11) * 150)::numeric(8, 2),
            v_rest_id,
            case when i % 2 = 0 then 'https://foodexpress.ru' || i || '.jpg' else null end,
            null,
            enum_prod_st[1 + (i % array_length(enum_prod_st, 1))],
            'Приготовлено из свежих фермерских продуктов по фирменному рецепту шеф-повара.'
        );
    end loop;

    for i in 1..(value * 5) loop
        v_order_id := exts.uuid_generate_v4();
        v_client_id := ids_clients[1 + ((i - 1) % value)];
        v_rest_id := ids_rests[1 + ((i - 1) % value)];
        v_courier_id := ids_couriers[1 + ((i - 1) % value)];
        select address_id into v_address_id from zernov_food.client_address where client_id = v_client_id limit 1;

        v_order_ts := localtimestamp - ((array[1, 2, 4, 5])[1 + (i % 4)] || ' months')::interval + ((i % 20) || ' days')::interval;

        if i <= array_length(enum_ord_st, 1) then
            v_status := enum_ord_st[i];
        else
            v_status := 'доставлен';
        end if;

        v_deliv_ts := case when v_status = 'доставлен' then v_order_ts + interval '45 minutes' else null end;
        v_pay_status := case when v_status = 'доставлен' then 'оплачен' else 'ожидает' end;

        select product_id, price into v_prod_id, v_order_amount
        from zernov_food.product where restaurant_id = v_rest_id order by random() limit 1;

        v_qty := (array[0.5, 1.0, 1.5, 2.0, 2.5, 3.0])[1 + (i % 6)];
        if round(v_order_amount * v_qty * 1.1, 2) < 1000 then
            v_qty := ceil(910.0 / v_order_amount);
        end if;

        v_order_amount := round(v_order_amount * v_qty, 2);
        v_total_amount := v_order_amount + round(v_order_amount * 0.1, 2);

        insert into zernov_food.orders (
            order_id, courier_id, client_id, address_id, restaurant_id,
            order_timestamp, delivery_timestamp, order_amount, status, pay_status, description
        ) values (
            v_order_id, v_courier_id, v_client_id, v_address_id, v_rest_id,
            v_order_ts, v_deliv_ts, v_order_amount, v_status, v_pay_status,
            case when i % 3 = 0 then 'Позвонить за 5 минут до приезда' else null end
        );

        insert into zernov_food.order_structure (order_id, product_id, restaurant_id, quantity)
        values (v_order_id, v_prod_id, v_rest_id, v_qty);

        insert into zernov_food.payment (
            payment_id, order_id, payment_type, amount, transaction_id, status, payment_timestamp
        ) values (
            exts.uuid_generate_v4(),
            v_order_id,
            enum_pay_tp[1 + (i % array_length(enum_pay_tp, 1))],
            v_total_amount,
            'TRX-' || (v_offset + i)::text || '-' || substr(md5(random()::text), 1, 10),
            case when v_pay_status = 'оплачен' then 'успех'::zernov_food.pay_attempt_status 
                 else enum_pay_st[2 + (i % 2)] end,
            v_order_ts + interval '2 minutes'
        );

        insert into zernov_food.review (
            review_id, client_id, order_id, review_timestamp, entity_type, entity_id, description, photo_url, rating
        ) values (
            exts.uuid_generate_v4(),
            v_client_id,
            v_order_id,
            v_order_ts + interval '2 hours',
            case when i % 3 = 1 then 'блюдо'::zernov_food.review_entity
                 when i % 3 = 2 then 'ресторан'::zernov_food.review_entity
                 else 'заказ'::zernov_food.review_entity end,
            case when i % 3 = 1 then v_prod_id
                 when i % 3 = 2 then v_rest_id
                 else v_order_id end,
            'Отличный сервис, всё привезли горячим и точно в срок!',
            case when i % 4 = 0 then 'https://foodexpress.ru' || i || '.jpg' else null end,
            (1 + (i % 5))::numeric(3, 2)
        );
    end loop;

    for rec_courier in select courier_id, status from zernov_food.courier where courier_id = any(ids_couriers) loop
        v_idx := v_idx + 1;
        v_curr_coeff := (array[0.1, 0.2, 0.3, 0.5])[1 + (v_idx % 4)];
        
        for m in reverse 6..1 loop
            m_date := (date_trunc('month', current_date) - (m || ' months')::interval)::date;
            
            select count(*), coalesce(sum(commission), 0)
            into v_cnt, v_comm_sum
            from zernov_food.orders
            where courier_id = rec_courier.courier_id
              and status = 'доставлен'
              and extract(year from order_timestamp) = extract(year from m_date)
              and extract(month from order_timestamp) = extract(month from m_date);

            insert into zernov_food.courier_pay (year, month, courier_id, amount, coefficient_used)
            values (
                extract(year from m_date)::int,
                extract(month from m_date)::int,
                rec_courier.courier_id,
                round(v_comm_sum * v_curr_coeff, 2),
                v_curr_coeff
            )
            on conflict (year, month, courier_id) do update 
            set amount = excluded.amount, coefficient_used = excluded.coefficient_used;

            if v_cnt <= 150 then v_next_coeff := 0.1;
            elsif v_cnt <= 250 then v_next_coeff := 0.2;
            elsif v_cnt <= 500 then v_next_coeff := 0.3;
            else v_next_coeff := 0.5;
            end if;

            v_curr_coeff := v_next_coeff;
        end loop;

        if rec_courier.status != 'уволен' then
            update zernov_food.courier 
            set coefficient = (array[0.1, 0.2, 0.3, 0.5])[1 + (v_idx % 4)]
            where courier_id = rec_courier.courier_id;
        end if;
    end loop;
end;
$$;
