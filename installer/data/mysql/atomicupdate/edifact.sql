CREATE TABLE IF NOT EXISTS vendor_edi_accounts (
  id serial,
  description text NOT NULL,
  host text,
  username text,
  password text,
  last_activity date,
  vendor_id int(11) references aqbooksellers( id ),
  remote_directory text,
  san varchar(20),
  transport varchar(6) default 'FTP',
  PRIMARY KEY  (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS edifact_messages (
  id serial,
  message_type text NOT NULL,
  date_sent date,
  vendor_id int(11) references aqbooksellers( id ),
  status text,
  basketno int(11) references aqbasket( basketno),
  edi text,
  remote_file text,
  invoiceid int(11) references aqinvoices( invoiceid ),
  deleted boolean default 0,
  PRIMARY KEY  (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- insert into permissions (module_bit, code, description) values (13, 'edi_manage', 'Manage EDIFACT transmissions');

insert into permissions (module_bit, code, description) values (11, 'edi_manage', 'Manage EDIFACT transmissions');

CREATE TABLE IF NOT EXISTS edifact_ean (
  branchcode varchar(10) PRIMARY KEY,
  ean varchar(15) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
