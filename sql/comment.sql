-- @(#) $Header$
-- A comment is attached to a news item
create table comment (
 id                  integer not null PRIMARY KEY AUTO_INCREMENT,
 article_id          integer not null,
 parent_id           integer,
 title               varchar(80),
 contents            blob,
 created_by          varchar(16) not null,
 created_on          datetime not null
) TYPE=InnoDB PACK_KEYS=1;
