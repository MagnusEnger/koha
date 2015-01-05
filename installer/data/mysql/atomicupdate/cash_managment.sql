
create table cash_till (
	tillid integer(11) auto_increment not null,
	description varchar(100) not null,
	branch varchar(10),
	primary key (tillid),
	foreign key (branch) references branches (branchcode)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

create table cash_transcode (
	code varchar(10) not null,
        description varchar(100) not null default '',
	primary key (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


create table cash_transaction (
	id serial not null,
	created datetime not null default current_timestamp(),
	amt decimal(12,2) not null,
	till integer(11) not null,
	tcode varchar(10) not null,
        paymenttype varchar(10),
	primary key (id),
        foreign key (till) references cash_till (tillid),
	foreign key (tcode ) references cash_transcode( code )
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES('CashManagement', '0', NULL , 'Use the cash management module to record money in and out', 'YesNo');

insert into userflags values ( 21, 'cashmanage', 'Access cash management', 0);
-- payment types should be linked to auth value
