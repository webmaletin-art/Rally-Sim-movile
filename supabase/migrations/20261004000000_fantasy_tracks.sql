-- Dream Racing · mapas fantasía nuevos para los rankings (Marte, la Luna y el Anillo de Júpiter). El largo sirve para descartar tiempos imposibles.
insert into public.tracks (id, name, length_m) values
  ('marte',  'Marte · Monte Olimpo',            9366),
  ('luna',   'La Luna · Mar de la Tranquilidad', 7013),
  ('anillo', 'Anillo de Júpiter',                7798)
on conflict (id) do update set name = excluded.name, length_m = excluded.length_m;
