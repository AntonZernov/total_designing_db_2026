create or replace procedure zernov_food.add_product(
    productname varchar(128),
    productcategoryid uuid,
    productprice numeric(8, 2),
    restaurantid uuid,
    productphotourl text,
    productrating numeric(3, 2),
    productstatus zernov_food.product_status,
    productdescription text
)
language plpgsql
as $$
begin
    if not exists (select 1 from zernov_food.restaurant where restaurant_id = restaurantid) then
        raise exception 'Ресторан с id % не существует.', restaurantid;
    end if;

    if not exists (select 1 from zernov_food.product_category where product_category_id = productcategoryid) then
        raise exception 'Категория продукта с id % не существует.', productcategoryid;
    end if;

    if productprice < 0 then
        raise exception 'Цена не может быть отрицательной.';
    end if;

    if productrating not between 0 and 5 then
        raise exception 'Ошибка: рейтинг должен быть от 0 до 5';
    end if;

    if exists (select 1 from zernov_food.product where product_name = productname) then
        raise exception 'Продукт с таким названием уже существует.';
    end if;

    insert into zernov_food.product (
        product_name,
        product_category_id,
        price,
        restaurant_id,
        photo_url,
        rating,
        status,
        description
    ) values (
        productname,
        productcategoryid,
        productprice,
        restaurantid,
        productphotourl,
        productrating,
        productstatus,
        productdescription
    );
end;
$$;
