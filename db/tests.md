# Протокол для самопроверки

Заполняется по желанию. 

По данному протоколу работа будет проверяться преподавателем.

**Если на каком-то этапе функционал оказывается нерабочим, значит учащийся проигнорировал обязательное тестирование и работа может быть отправлена на доработку без проверки и комментариев или по работе может быть проставлен незачет, если лимит доработок исчерпан.**

## Окружение

| Параметр | Значение                                                                                                                                                 |
|---|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| PostgreSQL version | `SELECT version();` PostgreSQL 17.11 (Ubuntu 17.11-1.pgdg24.04+2)|
| Дата проверки | 09.11.2026                                                                                                                                               |
| Схема | zernov_food`                                                                                                                                             |
| Роль-аудитор | `inspector`                                                                                                                                              |

Все проверки — под `inspector`, если не указано иное.

---

## A. Подготовка

### A.1. Восстановление бэкапа

Ожидается: без ошибок.
Факт: без ошибок
Вердикт: OK

### A.2. Переключение на inspector

```sql
SET ROLE inspector;
SET search_path TO <фамилия>_food, exts;
SELECT current_user;
```

Ожидается: `inspector`.
Факт: `inspector`
Вердикт: OK

---

## B. FOOD-101: Структура схемы

### B.1. Схема существует

```sql
SELECT schema_name FROM information_schema.schemata
WHERE schema_name LIKE '%_food';
```

Ожидается: `zernov_food`.
Факт: `zernov_food`
Вердикт: OK

### B.2. Схема `exts` с `uuid-ossp`

```sql
SELECT extname, extnamespace::regnamespace AS schema
FROM pg_extension WHERE extname = 'uuid-ossp';
```

Ожидается: `uuid-ossp`, схема `exts`.
Факт:
```text
  extname  | schema 
-----------+--------
 uuid-ossp | exts
(1 строка)
```
Вердикт: OK

### B.3. Все 12 исходных таблиц + N после нормализации

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = '<фамилия>_food'
ORDER BY table_name;
```

Ожидается: `address`, `client`, `client_address`, `courier`, `courier_pay`, `order`, `order_structure`, `payment`, `product`, `product_category`, `restaurant`, `review` (12 + N штук).
Факт: 
``` 
 address
 client
 client_address
 courier
 courier_pay
 how_much_money
 order_reviews
 order_structure
 orders
 payment
 product
 product_category
 product_reviews
 restaurant
 restaurant_reviews
 review
(16 строк) 
```
12 + 3 таблицы нормализации и 1 view
Вердикт: OK

### B.4. Все PK — `uuid`

```sql
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = '<фамилия>_food'
  AND column_name LIKE '%_id'
  AND data_type != 'uuid';
```

Ожидается: пусто.
Факт: 
```commandline
 table_name |  column_name   |     data_type
------------+----------------+-------------------
 payment    | transaction_id | character varying
```
Вердикт: FAIL. transaction_id - идентификатор стронней платежной системы, может не быть uuid

### B.5. Enum-типы

```sql
SELECT t.typname, array_agg(e.enumlabel ORDER BY e.enumsortorder) AS values
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = '<фамилия>_food'
GROUP BY t.typname
ORDER BY t.typname;
```

Ожидается: 8 типов со значениями из constraints.md.
Факт: 
```commandline
      typname       |                     values
--------------------+-------------------------------------------------
 courier_status     | {свободен,занят,на_доставке,уволен}
 order_pay_status   | {ожидает,оплачен,ошибка}
 order_status       | {создан,готовится,в_доставке,доставлен,отменен}
 pay_attempt_status | {успех,ошибка,в_обработке}
 payment_type       | {карта,наличные,безнал}
 product_status     | {доступно,нет_в_наличии,архив}
 restaurant_status  | {активен,неактивен}
 review_entity      | {блюдо,ресторан,заказ}
(8 строк)
```
Вердикт: OK
### B.6. FK-ограничения

```sql
SELECT conname, conrelid::regclass AS tbl, confrelid::regclass AS ref
FROM pg_constraint
WHERE contype = 'f'
  AND connamespace = '<фамилия>_food'::regnamespace
ORDER BY tbl, conname;
```

Ожидается: не менее 15 FK, все из erd.md.
Факт: 
```commandline
                conname                |              tbl               |             ref
---------------------------------------+--------------------------------+------------------------------
 client_address_address_id_fkey        | zernov_food.client_address     | zernov_food.address
 client_address_client_id_fkey         | zernov_food.client_address     | zernov_food.client
 courier_pay_courier_id_fkey           | zernov_food.courier_pay        | zernov_food.courier
 orders_address_id_fkey                | zernov_food.orders             | zernov_food.address
 orders_client_address_fkey            | zernov_food.orders             | zernov_food.client_address
 orders_client_id_fkey                 | zernov_food.orders             | zernov_food.client
 orders_courier_id_fkey                | zernov_food.orders             | zernov_food.courier
 orders_restaurant_id_fkey             | zernov_food.orders             | zernov_food.restaurant
 order_reviews_review_id_fkey          | zernov_food.order_reviews      | zernov_food.review
 order_structure_order_fkey            | zernov_food.order_structure    | zernov_food.orders
 order_structure_product_fkey          | zernov_food.order_structure    | zernov_food.product
 payment_order_id_fkey                 | zernov_food.payment            | zernov_food.orders
 product_product_category_id_fkey      | zernov_food.product            | zernov_food.product_category
 product_restaurant_id_fkey            | zernov_food.product            | zernov_food.restaurant
 product_reviews_product_id_fkey       | zernov_food.product_reviews    | zernov_food.product
 product_reviews_review_id_fkey        | zernov_food.product_reviews    | zernov_food.review
 restaurant_address_id_fkey            | zernov_food.restaurant         | zernov_food.address
 restaurant_reviews_restaurant_id_fkey | zernov_food.restaurant_reviews | zernov_food.restaurant
 restaurant_reviews_review_id_fkey     | zernov_food.restaurant_reviews | zernov_food.review
 review_client_id_fkey                 | zernov_food.review             | zernov_food.client
 review_order_client_fkey              | zernov_food.review             | zernov_food.orders
(21 строка)
```
Вердикт: OK

### B.7. Пароль — MD5

```sql
SELECT length(password) AS len, password
FROM client LIMIT 5;
```

Ожидается: `len = 32`, hex-строка.
Факт:
```
len |             password
-----+----------------------------------
32 | ced41352c2073216594882a9b643b417
32 | 705f8a96b6563b780d17e4683242a5e8
32 | a09bb87a3e6b5b753dd149a36f7952b8
32 | e8082689401b13465e454c1e3f29bb5a
32 | ebf3ee37d322adee54a18264f474181f
(5 строк)
```
Вердикт: OK

---

## C. FOOD-102: `insert_test_data(value)`

### C.1. Чистая схема

```sql
CALL erase_test_data();
```

Ожидается: без ошибок.
Факт:
```commandline
test_backup=> CALL zernov_food.erase_test_data();
CALL
test_backup=>
```
Вердикт: OK

### C.2. Первый запуск

```sql
CALL insert_test_data(10);
```

Ожидается: без ошибок.
Факт: без ошибок.
Вердикт: OK

### C.3. Распределение строк (BR-11.7)

```sql
SELECT 'client' AS tbl, count(*) FROM client
UNION ALL SELECT 'courier', count(*) FROM courier
UNION ALL SELECT 'product_category', count(*) FROM product_category
UNION ALL SELECT 'restaurant', count(*) FROM restaurant
UNION ALL SELECT 'address', count(*) FROM address
UNION ALL SELECT 'product', count(*) FROM product
UNION ALL SELECT 'order', count(*) FROM orders
UNION ALL SELECT 'review', count(*) FROM review
UNION ALL SELECT 'payment', count(*) FROM payment
ORDER BY tbl;
```

Ожидается: 10, 10, 10, 10, 50, 50, 50, 50, 50.
Факт: 
```commandline
       tbl        | count
------------------+-------
 address          |    50
 client           |    10
 courier          |    10
 order            |    54
 payment          |    54
 product          |    50
 product_category |    10
 restaurant       |    10
 review           |    60
(9 строк)
```
Вердикт: FAIL - ошибки в счетчиках

### C.4. Адреса ресторанов vs клиентов (BR-11.7)

```sql
SELECT 'restaurant addresses' AS cat, count(*) FROM restaurant WHERE address_id IS NOT NULL
UNION ALL
SELECT 'total addresses', count(*) FROM address;
```

Ожидается: 10 ресторанных адресов, 50 всего → 40 клиентских.
Факт: 
```commandline
         cat          | count
----------------------+-------
 restaurant addresses |    10
 total addresses      |    50
(2 строки)
```
Вердикт: OK

### C.5. Нет пустых строк (BR-11.3)

```sql
SELECT count(*) FROM client WHERE login = '' OR password = '' OR phone_number = '';
-- и аналогично для других varchar-полей с NOT NULL
```

Ожидается: 0.
Факт: 
```commandline
 count
-------
     0
(1 строка)
```
Вердикт: OK

### C.6. Нет NULL там, где запрещено (BR-11.3)

```sql
SELECT count(*) FROM orders WHERE client_id IS NULL OR restaurant_id IS NULL
  OR courier_id IS NULL OR address_id IS NULL OR total_amount IS NULL;
-- и аналогично для других NOT NULL полей
```

Ожидается: 0.
Факт: 
```commandline
test_backup=> SELECT count(*) FROM orders WHERE client_id IS NULL OR restaurant_id IS NULL
  OR courier_id IS NULL OR address_id IS NULL OR total_amount IS NULL;
 count
-------
     0
(1 строка)
```
Вердикт: OK

### C.7. Минимум один активный курьер (BR-6.6)

```sql
SELECT count(*) FROM courier WHERE status != 'уволен';
```

Ожидается: `>= 1`.
Факт: 
```commandline
 count
-------
    10
(1 строка)
```
Вердикт: OK

### C.8. `courier_pay` консистентен с правилами (BR-10.2)

```sql
SELECT cp.year, cp.month, cp.courier_id, cp.amount, cp.coefficient_used,
       round(coalesce((
           SELECT sum(o.commission)
           FROM orders o
           WHERE o.courier_id = cp.courier_id
             AND o.status = 'доставлен'
             AND extract(year  from o.order_timestamp) = cp.year
             AND extract(month from o.order_timestamp) = cp.month
       ), 0) * cp.coefficient_used, 2) AS expected_amount
FROM courier_pay cp
LIMIT 20;
```

Ожидается: `amount = expected_amount` в каждой строке.
Факт: 
```commandline
 year | month |              courier_id              | amount  | coefficient_used | expected_amount
------+-------+--------------------------------------+---------+------------------+-----------------
 2026 |     1 | 17d328e4-6f3f-4e65-a663-f391e48e8675 | 4924.00 |              0.5 |            0.00
 2026 |     2 | 17d328e4-6f3f-4e65-a663-f391e48e8675 | 4127.00 |              0.3 |            0.00
 2026 |     3 | 17d328e4-6f3f-4e65-a663-f391e48e8675 | 7657.00 |              0.2 |            0.00
 2026 |     4 | 17d328e4-6f3f-4e65-a663-f391e48e8675 | 7222.00 |              0.1 |            0.00
 2026 |     5 | 17d328e4-6f3f-4e65-a663-f391e48e8675 | 3600.00 |              0.5 |           60.00
 2026 |     6 | 17d328e4-6f3f-4e65-a663-f391e48e8675 | 3511.00 |              0.1 |           24.00
 2026 |     1 | 8b8f05fd-45f3-4231-a6cb-a3500b678da2 | 4876.00 |              0.5 |            0.00
 2026 |     2 | 8b8f05fd-45f3-4231-a6cb-a3500b678da2 | 6563.00 |              0.5 |            0.00
 2026 |     3 | 8b8f05fd-45f3-4231-a6cb-a3500b678da2 | 5490.00 |              0.1 |            0.00
 2026 |     4 | 8b8f05fd-45f3-4231-a6cb-a3500b678da2 | 3275.00 |              0.2 |            0.00
 2026 |     5 | 8b8f05fd-45f3-4231-a6cb-a3500b678da2 | 8498.00 |              0.5 |           60.00
 2026 |     6 | 8b8f05fd-45f3-4231-a6cb-a3500b678da2 | 8801.00 |              0.5 |            0.00
 2026 |     1 | 3317e565-fd05-4b94-a9b0-0e9bd8864ed5 | 5643.00 |              0.5 |            0.00
 2026 |     2 | 3317e565-fd05-4b94-a9b0-0e9bd8864ed5 | 3523.00 |              0.5 |            0.00
 2026 |     3 | 3317e565-fd05-4b94-a9b0-0e9bd8864ed5 | 3042.00 |              0.1 |            0.00
 2026 |     4 | 3317e565-fd05-4b94-a9b0-0e9bd8864ed5 | 5731.00 |              0.2 |            0.00
 2026 |     5 | 3317e565-fd05-4b94-a9b0-0e9bd8864ed5 | 7044.00 |              0.1 |            0.00
 2026 |     6 | 3317e565-fd05-4b94-a9b0-0e9bd8864ed5 | 8382.00 |              0.1 |           12.00
 2026 |     1 | cb97347e-cbc8-4da7-bf2d-07c2650c6cc6 | 3099.00 |              0.3 |            0.00
 2026 |     2 | cb97347e-cbc8-4da7-bf2d-07c2650c6cc6 | 7243.00 |              0.5 |            0.00
(20 строк)
```
Вердикт: FAIL
### C.9. Повторный вызов не ломает

```sql
DO $$
BEGIN
    FOR i IN 1..10 LOOP
        CALL insert_test_data(10);
    END LOOP;
END $$;
```

Ожидается: без ошибок, данные добавляются или заменяются (по решению студента, задокументированному в constraints.md).
Факт: без ошибок
Вердикт: OK
---

## D. Проверки бизнес-правил на сгенерированных данных

### D.1. Все FK валидны (нет orphans)

```sql
SELECT 'order_structure → order' AS fk, count(*) AS orphans
FROM order_structure os
LEFT JOIN orders o ON os.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_structure → product', count(*)
FROM order_structure os
LEFT JOIN product p ON os.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'payment → order', count(*)
FROM payment pmt
LEFT JOIN orders o ON pmt.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'review → order', count(*)
FROM review r
LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'courier_pay → courier', count(*)
FROM courier_pay cp
LEFT JOIN courier c ON cp.courier_id = c.courier_id
WHERE c.courier_id IS NULL
UNION ALL
SELECT 'client_address → client', count(*)
FROM client_address ca
LEFT JOIN client c ON ca.client_id = c.client_id
WHERE c.client_id IS NULL
UNION ALL
SELECT 'client_address → address', count(*)
FROM client_address ca
LEFT JOIN address a ON ca.address_id = a.address_id
WHERE a.address_id IS NULL;
```

Ожидается: все 0.
Факт: 
```commandline
            fk             | orphans
---------------------------+---------
 order_structure → order   |       0
 order_structure → product |       0
 payment → order           |       0
 review → order            |       0
 courier_pay → courier     |       0
 client_address → client   |       0
 client_address → address  |       0
(7 строк)
```
Вердикт: OK

### D.2. Минимальная сумма заказа (BR-1.8)

```sql
SELECT count(*) FROM orders WHERE total_amount < 1000;
```

Ожидается: 0.
Факт: 0
Вердикт: OK

### D.3. Комиссия = 10% (BR-1.4)

```sql
SELECT count(*) FROM orders WHERE round(order_amount * 0.10, 2) != commission;
```

Ожидается: 0.
Факт: 0
Вердикт: OK

### D.4. `total_amount = order_amount + commission`

```sql
SELECT count(*) FROM orders
WHERE round(order_amount + commission, 2) != total_amount;
```

Ожидается: 0.
Факт: 0
Вердикт: OK

### D.5. Дата доставки не раньше создания (BR-7.13)

```sql
SELECT count(*) FROM orders
WHERE delivery_timestamp IS NOT NULL AND delivery_timestamp < order_timestamp;
```

Ожидается: 0.
Факт: ___

### D.6. Адрес доставки принадлежит клиенту (BR-7.4)

```sql
SELECT count(*) FROM orders o
LEFT JOIN client_address ca
  ON ca.client_id = o.client_id AND ca.address_id = o.address_id
WHERE ca.client_id IS NULL;
```

Ожидается: 0.
Факт: 0
Вердикт: OK

### D.7. Все блюда в заказе из одного ресторана (BR-7.3)

```sql
SELECT count(DISTINCT os.order_id)
FROM order_structure os
JOIN orders o ON os.order_id = o.order_id
JOIN product p ON os.product_id = p.product_id
WHERE p.restaurant_id != o.restaurant_id;
```

Ожидается: 0.
Факт: 0
Вердикт: OK

### D.8. Ровно одна успешная оплата на заказ (BR-8.1)

```sql
SELECT order_id, count(*) AS cnt
FROM payment
WHERE status = 'успех'
GROUP BY order_id
HAVING count(*) != 1;
```

Ожидается: пусто.
Факт: 
```commandline
 order_id | cnt
----------+-----
(0 строк)
```
Вердикт: OK
### D.9. Сумма оплаты = `total_amount` заказа (BR-8.4)

```sql
SELECT count(*) FROM payment p
JOIN orders o ON p.order_id = o.order_id
WHERE p.amount != o.total_amount;
```

Ожидается: 0.
Факт: 0
Вердикт: OK

### D.10. Нет дубликатов в `client_address` (BR-2.5)

```sql
SELECT client_id, address_id, count(*)
FROM client_address
GROUP BY client_id, address_id
HAVING count(*) > 1;
```

Ожидается: пусто.
Факт: пусто
Вердикт: OK

### D.11. Нет дубликатов в `order_structure` (BR-7.16)

```sql
SELECT order_id, product_id, count(*)
FROM order_structure
GROUP BY order_id, product_id
HAVING count(*) > 1;
```

Ожидается: пусто.
Факт: пусто
Вердикт: OK

### D.12. `work_end > work_start` (BR-4.4)

```sql
SELECT count(*) FROM restaurant WHERE work_end <= work_start;
```

Ожидается: 0.
Факт: 0
Вердикт: OK

### D.13. `dismissal_date >= hire_date` (BR-6.3)

```sql
SELECT count(*) FROM courier
WHERE dismissal_date IS NOT NULL AND dismissal_date < hire_date;
```

Ожидается: 0.
Факт: 0
Вердикт: OK

### D.14. Рейтинг блюд/ресторанов соответствует отзывам (BR-9.6)

```sql
-- product.rating = AVG(review.rating) по отзывам на блюдо
SELECT p.product_id, p.rating,
       (SELECT round(avg(r.rating), 2) FROM review r
        WHERE r.entity_type = 'блюдо' AND r.entity_id = p.product_id) AS expected
FROM product p
WHERE p.rating IS NOT NULL
LIMIT 20;
```

Ожидается: `rating = expected`.
Проверочный запрос скорректирован под фактические таблицы.
```commandline
SELECT p.product_id, p.rating,
       (SELECT round(avg(r.rating), 2)
        FROM product_reviews pr
        JOIN review r ON pr.review_id = r.review_id
        WHERE pr.product_id = p.product_id
          AND pr.entity_type = 'блюдо') AS expected
FROM product p
WHERE p.rating IS NOT NULL
LIMIT 20;
```
Факт: 
```commandline
              product_id              | rating | expected
--------------------------------------+--------+----------
 112f2eb7-0366-440d-9e32-1d3d70e8c132 |   3.00 |     3.00
 c7dcbb5a-bd15-4df6-949b-c20bc0b39f99 |   1.00 |     1.00
 a32ed37d-569d-415c-b37a-591be59c3d1f |   3.00 |     3.00
 ea88c1ed-3e93-4ab1-af4f-3531c9f58304 |   2.33 |     2.33
 8e0a19ab-31da-43af-8c21-54e75de58d99 |   5.00 |     5.00
 c51fa78e-2fb6-4c49-9efb-fdc3292eb906 |   4.00 |     4.00
 c77676f2-c328-4618-9396-08c024fd8a11 |   2.67 |     2.67
 bff38401-f201-4d1c-84c9-d5ee247af18e |   5.00 |     5.00
 176585f2-139c-49bf-838d-588c8675e79f |   2.50 |     2.50
(9 строк)
```
Вердикт: OK

---

## E. Функции и процедуры

### E.1. `add_product` — успешный вызов

```sql
SELECT count(*) AS before FROM product;

CALL add_product(
    p_restaurant_id => (SELECT restaurant_id FROM restaurant LIMIT 1),
    p_product_category_id => (SELECT product_category_id FROM product_category LIMIT 1),
    p_name => 'Тестовое блюдо',
    p_price => 250,
    p_rating => 4.5,
    p_status => 'доступно',
    p_description => 'Описание'
    -- + photo_url если есть
);

SELECT count(*) AS after FROM product;
```

Ожидается: `after = before + 1`.
Факт: before 50, after 51
Вердикт: OK

### E.2. `add_product` — падает на несуществующий ресторан

```sql
CALL add_product(
    p_restaurant_id => '00000000-0000-0000-0000-000000000000',
    -- остальные аргументы
);
```

Ожидается: ошибка с внятным сообщением.
Факт: 
```commandline
test_backup=> call add_product('prrrr', '00000000-0000-0000-0000-000000000000', 12, '00000000-0000-0000-0000-000000000000','www.www.qqq', 6, 'архив', 'mmmm');
ОШИБКА:  Ресторан с id 00000000-0000-0000-0000-000000000000 не существует.
КОНТЕКСТ:  функция PL/pgSQL add_product(character varying,uuid,numeric,uuid,text,numeric,product_status,text), строка 4, оператор RAISE
```

### E.3. `rating_change` — пересчитывает рейтинг

```sql
-- Выбрать заказ, блюдо и клиента
SELECT p.product_id, p.rating FROM product p WHERE p.rating IS NOT NULL LIMIT 1;

-- Вставить отзыв на это блюдо
INSERT INTO review (review_id, client_id, review_timestamp, entity_id, entity_type, order_id, description, rating)
VALUES (
    exts.uuid_generate_v4(),
    (SELECT client_id FROM client LIMIT 1),
    localtimestamp,
    <product_id>,
    'блюдо',
    (SELECT order_id FROM orders LIMIT 1),
    'Тестовый отзыв',
    5
);

SELECT rating FROM product WHERE product_id = <product_id>;
```

Ожидается: `rating` пересчитан.
Факт: `rating` пересчитан.
Вердикт: OK

### E.4. `rating_change` — удаление отзыва

```sql
-- Удалить отзыв из E.3
DELETE FROM review WHERE review_id = <review_id>;

SELECT rating FROM product WHERE product_id = <product_id>;
```

Ожидается: если других отзывов нет — `rating IS NULL`; иначе — пересчитан.
Факт: NULL
Вердикт: OK

### E.5. `get_statistic()`

```sql
SELECT * FROM get_statistic();
```

Ожидается:
- Колонки: `restaurant_name`, `best_product_name`, `total_amount`, `avg_amount`, `best_user`.
- По одной строке на ресторан.
- `best_user` = `client.login` (не NULL при наличии заказов).

Факт: 
```commandline
 restaurant_name | best_product_name | total_amount | avg_amount |   best_user
-----------------+-------------------+--------------+------------+---------------
 Столовая 1      | Суп1ed52c72c      |      5280.00 |    1320.00 | логин4699de76
 Столовая 7      | Суп175ec2b5e      |     11880.00 |    1320.00 | логинf817c6d0
 Столовая 2      | Суп125f36493      |      6600.00 |    1320.00 | логинd5f4ca88
 Столовая 8      | Суп1af338776      |     11880.00 |    1320.00 | логинd5f4ca88
 Столовая 3      | Суп190420cfe      |      9240.00 |    1320.00 | логин520849fe
 Столовая 6      | Суп1856ebd82      |      3960.00 |    1320.00 | логин4699de76
 Столовая 5      | Суп1514318f1      |      6600.00 |    1320.00 | логин520849fe
 Столовая 4      | Суп140fcc4d6      |      3960.00 |    1320.00 | логин4699de76
 Столовая 9      | Суп15fb73a59      |      5280.00 |    1320.00 | логин4699de76
 Столовая 10     | Суп168bf9bcb      |      6600.00 |    1320.00 | логинf817c6d0
(10 строк)
```

### E.6. `courier_salary()`

```sql
-- До
SELECT courier_id, coefficient FROM courier ORDER BY courier_id;

CALL courier_salary();

-- После
SELECT courier_id, coefficient FROM courier ORDER BY courier_id;
SELECT year, month, courier_id, amount, coefficient_used
FROM courier_pay
ORDER BY year DESC, month DESC, courier_id
LIMIT 20;
```

Ожидается:
- `courier.coefficient` пересчитан для работающих (по BR-10.2).
- У уволенных — не изменился.
- `courier_pay` содержит запись за текущий месяц.

Факт: 
Пересчета нет, за текущий месяц записи есть.
Вердикт: FAIL

### E.7. `courier_salary()` — повторный вызов

```sql
CALL courier_salary();
SELECT count(*) FROM courier_pay
WHERE year = extract(year from current_date)
  AND month = extract(month from current_date);
```

Ожидается: количество не изменилось (idempotency / обновление).
Факт:  количество не изменилось
Вердикт: OK

---

## F. Представление `how_much_money`

### F.1. Колонки

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = '<фамилия>_food'
  AND table_name = 'how_much_money'
ORDER BY ordinal_position;
```

Ожидается: `year_month` (text), `sum_no_commission`, `sum_with_commission`, `commission`, `prev_commission`, `commission_diff`, `courier_pay`, `net_profit` (numeric).
Факт: 
```commandline
     column_name     | data_type
---------------------+-----------
 year_month          | text
 sum_no_commission   | numeric
 sum_with_commission | numeric
 commission          | numeric
 prev_commission     | numeric
 commission_diff     | numeric
 courier_pay         | numeric
 net_profit          | numeric
```

### F.2. Месяцы покрыты

```sql
SELECT * FROM how_much_money ORDER BY year_month;
```

Ожидается: месяцы от первого доставленного заказа до последнего (не пропущено ни одного).
Факт: представлены все месяцы.
Вердикт: OK

### F.3. Месяцы без заказов присутствуют (BR-11.9)

```sql
SELECT year_month FROM how_much_money
WHERE sum_no_commission = 0 OR sum_no_commission IS NULL;
```

Ожидается: если в какие-то месяцы заказов не было — они есть в результате.
Факт: нет месяцев без заказов
Вердикт: FAIL

### F.4. Корректность сумм

```sql
SELECT year_month,
       sum_no_commission,
       sum_with_commission,
       commission,
       prev_commission,
       commission_diff,
       courier_pay,
       net_profit
FROM how_much_money
ORDER BY year_month
LIMIT 10;
```

Ожидается:
- `commission = sum_with_commission - sum_no_commission`.
- `commission_diff = commission - prev_commission` (NULL для первого месяца).
- `net_profit = commission - courier_pay`.

Факт: 
```commandline
 year_month | sum_no_commission | sum_with_commission | commission | prev_commission | commission_diff | courier_pay | net_profit
------------+-------------------+---------------------+------------+-----------------+-----------------+-------------+------------
 2026-05    |           9600.00 |            10560.00 |     960.00 |                 |          960.00 |    65767.00 |  -64807.00
 2026-06    |           8400.00 |             9240.00 |     840.00 |          960.00 |         -120.00 |    52967.00 |  -52127.00
 2026-07    |          14400.00 |            15840.00 |    1440.00 |          840.00 |          600.00 |        0.00 |    1440.00
 2026-08    |           7200.00 |             7920.00 |     720.00 |         1440.00 |         -720.00 |        0.00 |     720.00
 2026-09    |          13200.00 |            14520.00 |    1320.00 |          720.00 |          600.00 |        0.00 |    1320.00
 2026-10    |           9600.00 |            10560.00 |     960.00 |         1320.00 |         -360.00 |        0.00 |     960.00
 2026-11    |           2400.00 |             2640.00 |     240.00 |          960.00 |         -720.00 |       24.00 |     216.00
```
Вердикт: OK

---

## G. Права `inspector`

### G.1. Права на схему

```sql
SELECT
nspname AS schema_name,
has_schema_privilege('inspector', nspname, 'USAGE')  AS usage,
has_schema_privilege('inspector', nspname, 'CREATE') AS create
FROM pg_namespace
WHERE nspname = zernov_foodfood';
```

Ожидается: `USAGE`, `CREATE` (полный доступ).
Факт: 
```commandline
 schema_name | usage | create
-------------+-------+--------
 zernov_food | t     | t
```
Вердикт: OK

### G.2. Права на таблицы

```sql
SELECT table_name, string_agg(privilege_type, ', ') AS privs
FROM information_schema.role_table_grants
WHERE grantee = 'inspector' AND table_schema = 'zernov_food'
GROUP BY table_name;
```

Ожидается: у каждой таблицы `SELECT, INSERT, UPDATE, DELETE` (или `ALL`).
Факт: дополниттельно выдан truncate для очистки тестовых данных
Вердикт: FAIL

### G.3. `information_schema` читается под `inspector`

```sql
SET ROLE inspector;
SELECT count(*) FROM information_schema.tables
WHERE table_schema = 'zernov_food';
RESET ROLE;
```

Ожидается: 12 + N (количество таблиц).
Факт: 16
Вердикт: OK

### G.4. `pg_catalog` читается под `inspector`

```sql
SET ROLE inspector;
SELECT count(*) FROM pg_catalog.pg_tables
WHERE schemaname = 'zernov_food';
RESET ROLE;
```

Ожидается: 12 + N.
Факт: 15
Вердикт: OK

### G.5. Все процедуры/функции работают под `inspector`

```sql
SET ROLE inspector;
SET search_path TO <фамилия>_food, exts;

CALL erase_test_data();
CALL insert_test_data(10);
CALL courier_salary();
SELECT * FROM get_statistic();
SELECT * FROM how_much_money LIMIT 5;

RESET ROLE;
```

Ожидается: без `permission denied`.
Факт: выполнено без ошибок
Вердикт: OK

---

## H. Оптимизация `get_statistic` (BR-11.8)

### H.1. `EXPLAIN ANALYZE` — паттерн «избыточные подзапросы»

```sql
EXPLAIN ANALYZE
SELECT c.courier_id,
       (SELECT count(*) FROM orders o WHERE o.courier_id = c.courier_id AND o.status = 'доставлен') AS cnt,
       (SELECT coalesce(sum(commission), 0) FROM orders o WHERE o.courier_id = c.courier_id AND o.status = 'доставлен') AS commission_sum
FROM courier c;
```

Ожидается: два SubPlan, каждый — скан `orders`. Время растёт линейно от числа курьеров.
Факт: время 0.493 мс, план 0.540
Вердикт: OK

### H.2. `EXPLAIN ANALYZE` — паттерн «один JOIN»

```sql
EXPLAIN ANALYZE
SELECT c.courier_id,
       count(o.order_id) AS cnt,
       coalesce(sum(o.commission), 0) AS commission_sum
FROM courier c
LEFT JOIN orders o ON o.courier_id = c.courier_id AND o.status = 'доставлен'
GROUP BY c.courier_id;
```

Ожидается: один `Hash Right Join` / `Hash Left Join`, один скан `orders`. Время меньше, чем в H.1.
Факт: время 0.197 мс, план 0.438
Вердикт: OK

### H.3. Применить к `get_statistic`

```sql
EXPLAIN ANALYZE SELECT * FROM get_statistic();
```

Ожидается: без `LATERAL`, без множественных подзапросов к одной таблице, без оконных функций там, где хватает агрегата.
Факт: без `LATERAL`, без множественных подзапросов к одной таблице, без оконных функций там, где хватает агрегата.
Вердикт: OK
---

## I. Очистка и повторная генерация

### I.1. `erase_test_data` очищает всё

```sql
CALL erase_test_data();

SELECT 'client' AS tbl, count(*) FROM client
UNION ALL SELECT 'courier', count(*) FROM courier
UNION ALL SELECT 'product_category', count(*) FROM product_category
UNION ALL SELECT 'restaurant', count(*) FROM restaurant
UNION ALL SELECT 'address', count(*) FROM address
UNION ALL SELECT 'product', count(*) FROM product
UNION ALL SELECT 'order', count(*) FROM orders
UNION ALL SELECT 'review', count(*) FROM review
UNION ALL SELECT 'payment', count(*) FROM payment
UNION ALL SELECT 'order_structure', count(*) FROM order_structure
UNION ALL SELECT 'client_address', count(*) FROM client_address
UNION ALL SELECT 'courier_pay', count(*) FROM courier_pay;
```

Ожидается: все 0.
Факт: все 0.
Вердикт: OK

### I.2. Повторный `erase_test_data` не падает

```sql
CALL erase_test_data();
```

Ожидается: без ошибок.
Факт: без ошибок.
Вердикт: OK

### I.3. После очистки `insert_test_data` снова работает

```sql
CALL insert_test_data(10);
SELECT count(*) FROM orders;
```

Ожидается: 50.
Факт: 54
Вердикт: OK (есть ошибка в скрипте геренации тестовых данных)

