create table if not exists types (
  id__types int generated always as identity primary key,
  label varchar(8000) not null,
  priorite int not null,
  created_at timestamp not null default now()
);

create table if not exists users (
  id_user varchar(50) primary key,
  username varchar(8000) not null unique,
  password varchar(20) not null,
  created_at timestamp not null default now()
);

create table if not exists notes (
  id_notes int generated always as identity primary key,
  texte varchar(8000) not null,
  created_at timestamp not null default now(),
  id__types int,
  id_user varchar(50) not null,
  constraint fk_notes_types
    foreign key (id__types)
    references types (id__types)
    on update cascade
    on delete set null,
  constraint fk_notes_users
    foreign key (id_user)
    references users (id_user)
    on update cascade
    on delete cascade
);
