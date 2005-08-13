-- @(#) $Header$
-- An article is a news item
create table article (
 id                  integer not null PRIMARY KEY AUTO_INCREMENT,
 proposal_id         integer,
 title               varchar(80) not null,
 contents            blob,
 submitted_by        varchar(16) not null,
 vote_good           smallint,
 vote_needswork      smallint,
 vote_bad            smallint,
 created_on          datetime not null
) TYPE=InnoDB PACK_KEYS=1;
