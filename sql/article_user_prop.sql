-- @(#) $Header$
-- An article_user_prop is a property given to an article by a user

create table article_user_prop (
 id                  integer not null PRIMARY KEY AUTO_INCREMENT,
 article_id          integer,
 username            varchar(16) not null,
 name                varchar(80) not null,
 value               varchar(254) not null
) TYPE=InnoDB PACK_KEYS=1;
