-- @(#) $Header$
-- 
-- Table of currently logged-in users

create table logged_in (
	username		varchar(16) not null PRIMARY KEY,
	login_token		char(32) not null,
	id_token		char(32) not null,
	logged_in_on		datetime not null,
	expires_on		datetime not null,
	last_used_on		datetime not null,
	last_ip_address		varchar(15),
	last_uri		varchar(127)
) TYPE=InnoDB PACK_KEYS=1;

