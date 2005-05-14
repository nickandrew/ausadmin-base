-- @(#) $Header$
-- 
-- This is our list of registered users

create table user (
	username		varchar(16) not null PRIMARY KEY,
	password		varchar(16) not null,
	active			smallint not null,
	email_address		varchar(64),
	created_on		datetime not null,
	expires_on		datetime
) TYPE=InnoDB PACK_KEYS=1;
