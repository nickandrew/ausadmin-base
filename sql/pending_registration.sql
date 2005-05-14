-- @(#) $Header$
-- 
-- This is our list of pending user registrations

create table pending_registration (
	username		varchar(16) not null PRIMARY KEY,
	password		varchar(16) not null,
	email_address		varchar(64),
	verify_string		varchar(32) not null,
	created_on		datetime not null,
	expires_on		datetime not null
) TYPE=InnoDB PACK_KEYS=1;

