create type zernov_food.restaurant_status as enum ('активен', 'неактивен');
create type zernov_food.product_status as enum ('доступно', 'нет_в_наличии', 'архив');
create type zernov_food.courier_status as enum ('свободен', 'занят', 'на_доставке', 'уволен');
create type zernov_food.order_status as enum ('создан', 'готовится', 'в_доставке', 'доставлен', 'отменен');
create type zernov_food.order_pay_status as enum ('ожидает', 'оплачен', 'ошибка');
create type zernov_food.pay_attempt_status as enum ('успех', 'ошибка', 'в_обработке');
create type zernov_food.payment_type as enum ('карта', 'наличные', 'безнал');
create type zernov_food.review_entity as enum ('блюдо', 'ресторан', 'заказ');