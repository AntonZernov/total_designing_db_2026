create table if not exists zernov_food.client (
    client_id uuid primary key default exts.uuid_generate_v4(),
    login varchar(32) not null unique,
    password varchar(32) not null check (password ~* '^[0-9a-f]{32}$'),
    phone_number varchar(20) not null unique
);

create table if not exists zernov_food.address (
    address_id uuid primary key default exts.uuid_generate_v4(),
    street varchar(64) not null,
    house_number varchar(16) not null,
    apartment_office varchar(16)
);

create table if not exists zernov_food.client_address (
    client_id uuid not null references zernov_food.client(client_id) on delete cascade,
    address_id uuid not null references zernov_food.address(address_id) on delete cascade,
    primary key (client_id, address_id)
);

create table if not exists zernov_food.restaurant (
    restaurant_id uuid primary key default exts.uuid_generate_v4(),
    restaurant_name varchar(64) not null,
    address_id uuid not null references zernov_food.address(address_id) unique,
    description text not null,
    work_start time not null,
    work_end time not null,
    rating numeric(3, 2) check (rating between 0 and 5),
    status zernov_food.restaurant_status not null,
    constraint restaurant_work_hours check (work_start < work_end)
);

create table if not exists zernov_food.courier (
    courier_id uuid primary key default exts.uuid_generate_v4(),
    fio varchar(128) not null,
    phone_number varchar(20) not null unique,
    status zernov_food.courier_status not null,
    hire_date date not null,
    dismissal_date date,
    coefficient numeric(2, 1) not null default 0.1 check (coefficient between 0.1 and 0.5),
    constraint courier_dismissal_consistency check ((status != 'уволен' or dismissal_date is not null)),
    constraint courier_hire_date_before_dismissal_date check (dismissal_date >= hire_date)
);

create table if not exists zernov_food.courier_pay (
    year int not null,
    month int not null check (month between 1 and 12),
    courier_id uuid not null references zernov_food.courier(courier_id) on delete cascade,
    amount numeric(8, 2) not null check (amount >= 0),
    coefficient_used numeric(2, 1) not null check (coefficient_used between 0.1 and 0.5),
    primary key (year, month, courier_id)
);

create table if not exists zernov_food.product_category (
    product_category_id uuid primary key default exts.uuid_generate_v4(),
    product_category_name varchar(64) not null unique
);

create table if not exists zernov_food.product (
    product_id uuid primary key default exts.uuid_generate_v4(),
    product_name varchar(128) not null unique,
    product_category_id uuid not null references zernov_food.product_category(product_category_id),
    price numeric(8, 2) not null check (price >= 0),
    restaurant_id uuid not null references zernov_food.restaurant(restaurant_id),
    photo_url text,
    rating numeric(3, 2) check (rating between 0 and 5),
    status zernov_food.product_status not null,
    description text not null,
    constraint product_restaurant_ukey unique (product_id, restaurant_id)
);

create table if not exists zernov_food.orders (
    order_id uuid primary key default exts.uuid_generate_v4(),
    courier_id uuid not null references zernov_food.courier(courier_id),
    client_id uuid not null references zernov_food.client(client_id),
    address_id uuid not null references zernov_food.address(address_id),
    restaurant_id uuid not null references zernov_food.restaurant(restaurant_id),
    order_timestamp timestamp not null default localtimestamp,
    delivery_timestamp timestamp,
    order_amount numeric(8, 2) not null check (order_amount >= 0),
    commission numeric(8, 2) generated always as (round(order_amount * 0.1, 2)) stored,
    total_amount numeric(8, 2) generated always as (order_amount + round(order_amount * 0.1, 2)) stored,
    status zernov_food.order_status not null,
    pay_status zernov_food.order_pay_status not null,
    description text,
    constraint orders_total_min check (order_amount + commission >= 1000),
    constraint orders_delivery_after_order check (delivery_timestamp > order_timestamp),
    constraint orders_client_address_fkey foreign key (client_id, address_id)
        references zernov_food.client_address (client_id, address_id),
    constraint orders_order_client_ukey unique (order_id, client_id),
    constraint orders_order_restaurant_ukey unique (order_id, restaurant_id)
);

create table if not exists zernov_food.payment (
    payment_id uuid primary key default exts.uuid_generate_v4(),
    order_id uuid not null references zernov_food.orders(order_id) on delete cascade,
    payment_type zernov_food.payment_type not null,
    amount numeric(8, 2) not null check (amount >= 0),
    transaction_id varchar(64) not null unique,
    status zernov_food.pay_attempt_status not null
);

create table if not exists zernov_food.order_structure (
    order_id uuid not null,
    product_id uuid not null,
    restaurant_id uuid not null,
    quantity numeric(8, 2) not null check (quantity > 0),
    primary key (order_id, product_id),
    constraint order_structure_order_fkey foreign key (order_id, restaurant_id)
        references zernov_food.orders (order_id, restaurant_id) on delete cascade,
    constraint order_structure_product_fkey foreign key (product_id, restaurant_id)
        references zernov_food.product (product_id, restaurant_id) on delete cascade
);

create unique index one_success_payment_per_order on zernov_food.payment (order_id)
    where status = 'успех';

create table if not exists zernov_food.review (
    review_id uuid primary key default exts.uuid_generate_v4(),
    client_id uuid not null references zernov_food.client(client_id),
    review_timestamp timestamp not null default localtimestamp,
    order_id uuid not null,
    description text not null,
    photo_url text,
    rating numeric(3, 2) not null check (rating between 0 and 5),
    constraint review_order_client_fkey foreign key (order_id, client_id) references zernov_food.orders(order_id, client_id)
);

create table if not exists zernov_food.order_reviews (
    review_id uuid primary key references zernov_food.review(review_id) on delete cascade,
    order_id uuid not null,
    entity_type zernov_food.review_entity not null default 'заказ' check (entity_type = 'заказ'),
    constraint uq_order_reviews_order unique (order_id)
);

create table if not exists zernov_food.restaurant_reviews (
    review_id uuid primary key references zernov_food.review(review_id) on delete cascade,
    restaurant_id uuid not null references zernov_food.restaurant(restaurant_id),
    order_id uuid not null,
    entity_type zernov_food.review_entity not null default 'ресторан' check (entity_type = 'ресторан'),
    constraint uq_restaurant_reviews_order unique (order_id)
);

create table if not exists zernov_food.product_reviews (
    review_id uuid primary key references zernov_food.review(review_id) on delete cascade,
    product_id uuid not null references zernov_food.product(product_id),
    order_id uuid not null,
    entity_type zernov_food.review_entity not null default 'блюдо' check (entity_type = 'блюдо'),
    constraint uq_product_reviews_order_product unique (order_id, product_id)
);