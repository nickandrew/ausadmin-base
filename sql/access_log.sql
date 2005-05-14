-- @(#) $Header$
-- 
-- List all usage of id tokens

create table access_log (
	id			integer not null PRIMARY KEY AUTO_INCREMENT,
	id_token		char(32) not null,
	created_on		datetime not null,
	username		varchar(16),
	ip_address		varchar(15),
	uri			varchar(127)
) TYPE=InnoDB PACK_KEYS=1;

