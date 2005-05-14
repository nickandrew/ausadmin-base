-- @(#) $Header$
-- 
-- Table of all logins and logouts

create table login_history (
	id			integer not null PRIMARY KEY AUTO_INCREMENT,
	is_login		smallint not null,
	username		varchar(16) not null,
	id_token		char(32) not null,
	created_on		datetime not null,
	ip_address		varchar(15),
	uri			varchar(127)
) TYPE=InnoDB PACK_KEYS=1;


