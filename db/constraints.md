# Обоснование ограничений

---

## Переименование таблиц
order переименована в orders для удобства написания скриптов без риска упустить кавычки.

## Enum-типы

Перечисли типы, которые создал. Если добавил/изменил значения относительно BR — обоснуй.

| Тип | Значения | BR     |
|-|--|--------|
|restaurant_status |'активен', 'неактивен'  | BR-4.3 |
| product_status | 'доступно', 'нет_в_наличии', 'архив' | BR-5.5 |
| courier_status | 'свободен', 'занят', 'на_доставке', 'уволен' | BR-6.2 |
| order_status | создан', 'готовится', 'в_доставке', 'доставлен', 'отменен' | BR-7.7 |
| order_pay_status | 'ожидает', 'оплачен', 'ошибка' | BR-7.9 |
| pay_attempt_status | 'успех', 'ошибка', 'в_обработке' | BR-8.2 |
| payment_type | 'карта', 'наличные', 'безнал' | BR-8.2 |
| review_entity | 'блюдо', 'ресторан', 'заказ' | BR-9.1 |

Относительно ERD переименованы pay_status в order_pay_status, payment_status в pay_attempt_status.
Сделано для повышения читаемости и во избежание путаницы.
---

## Ловушки

### Ловушка 1: `payment` — неполная сущность

**Какие атрибуты добавил в `payment` и почему** (BR-8.2):

```
Добавил данные платежа: payment_type, amount, transaction_id, pay_attempt_status, payment_timestamp.
Тип платежа, сумма, идентификатор транзакции - необходимы для возможных сценариев отмены платежа либо разрешения прочих спорных ситуаций.
Статус попытки оплаты - необходим для выполнения требования BR-8.1, возможна только одна успешная попытка.
Для контроля уникальной успешной попытки создан индекс, связывающий успешный статус с идентификатором заказа:
create unique index one_success_payment_per_order on zernov_food.payment (order_id)
    where status = 'успех';
```

**Где хранится тип оплаты — `payment` или `order`** (BR-8.6):

```
Тип оплаты хранится в payment, так как могут быть несколько попыток с разным типом.
```

### Ловушка 2: `order.address_id` — принадлежность клиенту (BR-7.4)

**Как обеспечено, что адрес доставки принадлежит клиенту:**

```
Использован составной внешний ключ, связывающий адрес с идентификатором клиента:
constraint orders_client_address_fkey foreign key (client_id, address_id)
    references zernov_food.client_address (client_id, address_id),
```

### Ловушка 3: `order_structure` — один ресторан в заказе (BR-7.3)

**Как обеспечено, что все блюда из `order.restaurant_id`:**

```
Добавлены два составных внешних ключа, связывающих продукт с ресмтораном и заказ с рестораном:
    constraint order_structure_order_fkey foreign key (order_id, restaurant_id)
        references zernov_food.orders (order_id, restaurant_id) on delete cascade,
    constraint order_structure_product_fkey foreign key (product_id, restaurant_id)
        references zernov_food.product (product_id, restaurant_id) on delete cascade
```

### Ловушка 4: `review` — полиморфизм (BR-9.1)

**Как реализована валидность `review.entity_id`:**

```
Сохранен полиморфизм. FK отсутствует, так как поле не может ссылаться на разные таблицы.
Целостность контролируется составными ключами и триггером.
```

---

## CHECK-ограничения

Каждое — с ссылкой на BR.

| Таблица         | Столбец                            | Условие                                                       | BR             | Обоснование                                       |
|-----------------|------------------------------------|---------------------------------------------------------------|----------------|---------------------------------------------------|
| client          | password                           | ~* '^[0-9a-f]{32}$'                                           | BR-2.3         | Пароль в виде MD5 32 символа, регистронезависимый |
| restaurant      | work_start, work_end               | work_start < work_end                                         | BR-4.4         | Время открытия раньше времени закрытия            |
| restaurant      | rating                             | rating between 0 and 5                                        | BR-4.2         | Значение от 0 до 5                                |
| product         | price                              | price >= 0                                                    | BR-5.3         | Цена не может быть отрицательной                  |
| product         | rating                             | rating between 0 and 5                                        | BR-5.4         | Рейтинг от 0 до 5                                 |
| courier         | coefficient                        | default 0.1 check (coefficient between 0.1 and 0.5)           | BR-5.4 BR-5.4  | Коэффициент от 0.1 до 0.5 по умолчанию 0.1        |
| courier         | status, dismissal_date             | status != 'уволен' or dismissal_date is not null              | BR-6.3         | Уволенный обязан иметь дату увольнения            |
| courier         | hire_date, dismissal_date          | dismissal_date >= hire_date                                   | BR-6.1         | Дата увольнения не раньше даты найма              |
| courier_pay     | month                              | month between 1 and 12                                        | BR-10.3        | Месяц оплаты календарный                          |
| courier_pay     | amount                             | amount >= 0                                                   | BR-10.4        | Сумма оплаты неотрицательная                      |
| courier_pay     | coefficient_used                   | coefficient_used between 0.1 and 0.5                          | BR-6.4         | Коэффициент от 0.1 до 0.5                         |
| orders          | total_amount                       | >= 1000                                                       | BR-1.8 BR-7.11 | Минимальный заказ на 1000р                        |
| orders          | delivery_timestamp, order_timestamp | delivery_timestamp > order_timestamp                          | BR-7.13        | Доставка не раньше создания заказа                |
| orders          | delivery_timestamp, order_timestamp | (status = 'доставлен' and delivery_timestamp is not null) or (status != 'доставлен') | BR-7.12        | Время окончания доставки заполняется, когда заказ получает статус 'доставлен'               |
| order_structure | quantity                           | quantity > 0)                                                 | BR-7.15        | Количество - положительное число                  |
| amount          | amount| amount >= 0                                                   | BR-8.2         | Сумма оплаты не может быть отрицательной          |
| review          |rating | rating between 1 and 5                                        | BR-9.4         | Рейтинг от 1 до 5                                 |

---

## UNIQUE-ограничения

| Таблица            | Столбцы   | BR      | Обоснование                                                                                        |
|--------------------|-----------|---------|----------------------------------------------------------------------------------------------------|
| client             | login     | BR-2.2  | Логин уникален                                                                                     |
| client             | phone_number | BR-2.2  | Телефон уникален                                                                                   |
| courier_profile    | phone_number | BR-6.1  | Телефон является одним из идентификаторов курьера                                                  |
| client_address     | primary key (client_id, address_id) | BR-2.5  | Один адрес нельзя привязать клиенту дважды                                                         |
| restaurant         | address_id | BR-3.3  | Один адрес не может быть у двух ресторанов                                                         |
| product_category   | product_category_name | BR-5.7  | Категория блюда — это справочник                                                                   |
| product            | product_id, restaurant_id | BR-7.3  | один из составных ключей для соблюдения: Нельзя заказать блюда из разных ресторанов в одном заказе |
| product            | product_name, restaurant_id | BR-11.8 | Подразумевает вывод названия самого покупаемого болюда, название блюда в одном ресторане уникально |
| courier_pay        | primary key (year, month, courier_id)| BR-10.3 | за один месяц у одного курьера — ровно одна запись                                                 |
| orders             | order_id, client_id| BR-9.2  | Отзыв всегда связан с конкретным заказом клиента                                                   |
| orders             | order_id, restaurant_id| BR-7.3  | один из составных ключей для соблюдения: Нельзя заказать блюда из разных ресторанов в одном заказе |
| payment            | transaction_id| BR-8.3  | Идентификатор финансовой транзакции — внешний, приходит от платёжного провайдера. Уникален         |
| payment            | (order_id) where status = 'успех'| BR-8.1  | Не более одного успешного платежа                                                                  |
| order_structure    | primary key (order_id, product_id)| BR-7.16 | Одно блюдо в заказе не встречается дважды                                                          |
---

## FK-ограничения

| Таблица         | Столбцы           | → Таблица        | BR      | Обоснование                                                                                          |
|-----------------|-------------------|------------------|---------|------------------------------------------------------------------------------------------------------|
| client_address  | client_id         | client           | BR-2.4  | Адрес привязан к существующему клиенту                                                               |
| client_address  | address_id        | address          | BR-2.4  | Адрес привязан к существующему клиенту                                                               |
| restaurant      | address_id        | address          | BR-3.3  | У ресторана один адрес                                                                               |
| product         | product_category_id | product_category | BR-5.1  | Блюдо привязано к одной категории                                                                    |
| product         | restaurant_id     | restaurant       | BR-5.1  | Блюдо привязано к однму ресторану                                                                    |
| courier_pay     | courier_id        | courier          | BR-10.2 | Выплата привязана к одному курьеру                                                                   |
| orders          | client_id         | client           | BR-7.2  | Заказ привязан к одному клиенту                                                                      |
| orders          | restaurant_id     | restaurant       | BR-7.2  | Заказ привязан к одному клиенту                                                                      |
| orders          | courier_id        | courier          | BR-7.5  | Заказ привязан к одному курьеру                                                                      |
| orders          | client_id, address_id| client_address   | BR-7.4  | Адрес доставки - один из адресов клиента                                                             |
| order_structure | order_id, restaurant_id| orders           | BR-7.14 | Позиция принадлежит заказу                                                                           |
| order_structure | product_id, restaurant_id| product          | BR-7.3  | Блюдо из ресторана заказа                                                                            |
| payment         | order_id| orders           | BR-8.1  | Оплата привязана к заказу                                                                            |
| review          | client_id| client           | BR-9.1  | Отзыв привязан к клиенту                                                                             |
| review          | order_id| orders           | BR-9.2  | Отзыв привязан к заказу конкретного клиента                                                          |
| review          | client_id| client           | BR-9.2  | Отзыв привязан к заказу конкретного клиента                                                          |
| courier          | courier_profile_id| courier_profile           | BR-6.3  | Курьер может быть уволен, а значит и нанят повторно, персональные данные нужно отделить от должности |

---

## NOT NULL (только бизнес-обязательные)
| Таблица | Столбец     | BR            | Обоснование                                   |
|---------|-------------|---------------|-----------------------------------------------|
| orders  | courier_id  | BR-7.5        | Доставка только курьером                      |
| orders  | pay_status  | BR-7.8        | Всегда есть статус оплаты                     |
| review  | description | BR-9.4        | В отзыыве есть текст                          |
| review  | rating      | BR-9.4        | Всегда есть рейтинг начиная с нулевого        |
| payment     | transaction_id         | BR-8.2        | Каждая попытка оплаты - финансовая транзакция |
| restaurant     | company_details         | BR-4.1 BR-4.5 | У ресторана должны быть реквизиты |
---

## NULL (осознанно разрешено)

| Таблица    | Столбец            | BR      | Почему NULL                              |
|------------|--------------------|---------|------------------------------------------|
| address    | apartment_office   | BR-3.2  | Частные дома не имеют номера квартиры    |
| product    | photo_url          | BR-5.6  | Фото не обязательно                      |
| product    | rating             | BR-9.7  | Нет отзывов - рейтинг null               |
| restaurant | rating             | BR-9.7  | Нет отзывов - рейтинг null               |
| courier    | dismissal_date     | BR-6.3  | Дата увольнения не обязательна           |
| orders     | delivery_timestamp | BR-7.12 | Заполняется при статусе доставка         |
| orders     | description        | BR-11.3 | Дополнительная информация, необязательна |
| review     | photo_url          | BR-9.3  | Фото в отзыве необязательно              |

---

## DEFAULT и GENERATED

| Таблица | Столбец               | Что                             | Обоснование                                                                               |
|---|-----------------------|---------------------------------|-------------------------------------------------------------------------------------------|
| все | _id                   | default exts.uuid_generate_v4() | BR-11.1 Все ID — UUID, генерируются на сервере через `exts.uuid_generate_v4()             |
| courier | coefficient           | default 0.1                     | BR-6.5 Изначальный коэффициент курьера 0.1                                                |
| orders | order_timestamp       | localtimestamp                  | BR-7.1 BR-11.2 У заказа есть дата время. Часовой пояс сервера                             |
| payment | transaction_timestamp | localtimestamp                  | BR-8.2 BR-11.2 У платежа есть дата время. Часовой пояс сервера                            |
|review   | review_timestamp      | localtimestamp                  | BR-9.3 BR-11.2 У отзыва есть дата время. Часовой пояс сервера                             |
|orders   | comission             | (round(order_amount * 0.1, 2))                  | BR-1.4 BR-7.10 Комиссия всегда 10%, вычисление не даст сохранить несогласованное значение |
|orders   | total_amount          | (order_amount + round(order_amount * 0.1, 2))   | BR-7.10 Комиссия всегда 10%, вычисление не даст сохранить несогласованное значение |
---

## Нормализация (3НФ)

Короткое обоснование, что все таблицы в 3НФ:

```
Все таблицы имеют первичные ключи (простые или составные). Каждый неключевой атрибут зависит от полного первичного ключа, а не от его части. 
В таблицах со ставными ключами (client_address, courier_pay, order_structure) нет полей, которые зависели бы только от одного из id.
В таблицах отсутствуют транзитивные зависимости. Любой неключевой атрибут, например, phone_number, price,
описывает только сущность первичного ключа (client, product, orders) и не зависит от других полей.

- commission и total_amount нарушают 3НФ, но использование stored столбцов гарантирует консистентость на уровне БД, значения невозможно
исказить в коде приложения. Также это позволяет избежать написания тяжелых джойнов и триггеров.
commission numeric(8, 2) generated always as (round(order_amount * 0.1, 2)) stored
total_amount numeric(8, 2) generated always as (order_amount + round(order_amount * 0.1, 2)) stored
- агрегаты product.rating и restaurant.rating поддерживаются триггером, что повышает производительность, так как пересчет происходит при изменениях в отзывах
без использования агрегатных вычислений при каждом запросе, а вычитываются, как атомарное значение.
- review.entity_id + entity_type ревью разбиты на 3 дополнительные таблицы, общая часть в review, специфическая в отдельных дочерних.
Это облегчает поддерживать согласованность данных. Без разделения пришлось бы разрабатывать дополнительные триггеры.
entity_id - неопределенный ключ, заменен на конкретные внешние ключи.
```



