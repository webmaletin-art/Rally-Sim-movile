-- Dream Racing · 14/10/2026 (noche): variantes de color del Volante Pro 3D (game/data/cosmetics.json; texturas: tools/cars/make_wheel_variants.py).
-- Aditivo y repetible: los cosméticos se validan como piezas («buy_part») con el mismo id y precio que el juego.
insert into public.online_cat_parts (id, category, price, shop, vehicles) values
  ('vol_pro_azul', 'cosmetic', 10000, 'paint', '{}'::text[]),
  ('vol_pro_rojo', 'cosmetic', 10000, 'paint', '{}'::text[]),
  ('vol_pro_blanco', 'cosmetic', 10500, 'paint', '{}'::text[]),
  ('vol_pro_oro', 'cosmetic', 12000, 'paint', '{}'::text[]),
  ('vol_pro_verde', 'cosmetic', 10000, 'paint', '{}'::text[])
on conflict (id) do update set category = excluded.category, price = excluded.price, shop = excluded.shop, vehicles = excluded.vehicles;
