-- @(#) $Header$
-- A proposal for a newsgroup creation, deletion or modification
create table proposal (
 id                  integer not null PRIMARY KEY AUTO_INCREMENT,
 status              varchar(16),
 group_name          varchar(64) not null,
 proposer_email      varchar(64),
 newsgroups_line     varchar(80),
 rationale           blob,
 charter             blob,
 owner               varchar(16),
 published_on        datetime,
 voting_on           datetime,
 created_on          datetime not null,
 last_modified_on    datetime
) TYPE=InnoDB PACK_KEYS=1;
