CREATE TABLE IF NOT EXISTS vendor_edi_accounts (
  id serial,
  description text NOT NULL,
  host text,
  username text,
  password text,
  last_activity date,
  vendor_id int(11) references aqbooksellers( id ),
  directory text,
  san varchar(20),
  id_code_qualifier varchar(3) default '14',
  transport varchar(6) default 'FTP',
  quotes_enabled tinyint(1) not null default 0,
  invoices_enabled tinyint(1) not null default 0,
  orders_enabled tinyint(1) not null default 0,
  PRIMARY KEY  (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS edifact_messages (
  id serial,
  message_type varchar(10) NOT NULL,
  transfer_date date,
  vendor_id int(11) references aqbooksellers( id ),
  status text,
  basketno int(11) references aqbasket( basketno),
  raw_msg text,
  filename text,
  invoiceid int(11) references aqinvoices( invoiceid ),
  deleted boolean not null default 0,
  PRIMARY KEY  (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- insert into permissions (module_bit, code, description) values (13, 'edi_manage', 'Manage EDIFACT transmissions');

insert into permissions (module_bit, code, description) values (11, 'edi_manage', 'Manage EDIFACT transmissions');

CREATE TABLE IF NOT EXISTS edifact_ean (
  branchcode varchar(10) not null references branches (branchcode),
  ean varchar(15) NOT NULL,
  id_code_qualifier varchar(3) NOT NULL default '14'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
