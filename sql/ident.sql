-- @(#) $Header$
-- 
-- List all id tokens assigned

create table ident (
	id_token		char(32) not null PRIMARY KEY,
	created_on		datetime not null,
	expires_on		datetime not null,
	last_used_on		datetime not null,
	ip_address		varchar(15),
	uri			varchar(127)
) TYPE=InnoDB PACK_KEYS=1;
