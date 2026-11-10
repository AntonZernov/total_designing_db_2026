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
    insert into zernov_food.product (
        product_id,
        product_name,
        product_category_id,
        price,
        restaurant_id,
        photo_url,
        rating,
        status,
        description
    ) values (
        exts.uuid_generate_v4(),
        productname,
        productcategoryid,
        productprice,
        restaurantid,
        productphotourl,
        productrating,
        productstatus,
        productdescription
    );
exception
    when foreign_key_violation then
        raise exception 'Указанный ресторан или категория продукта не существуют.';
    when unique_violation then
        raise exception 'Блюдо с таким названием уже добавлено в меню.';
    when check_violation then
        raise exception 'Указана неверная цена или нарушены правила заполнения полей.';
end;
$$;
