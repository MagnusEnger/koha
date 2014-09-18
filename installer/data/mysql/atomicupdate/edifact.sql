CREATE TABLE IF NOT EXISTS vendor_edi_accounts (
  id int(11) NOT NULL auto_increment,
  description text NOT NULL,
  host varchar(40),
  username varchar(40),
  password varchar(40),
  last_activity date,
  vendor_id int(11) references aqbooksellers( id ),
  directory text,
  san varchar(20),
  id_code_qualifier varchar(3) default '14',
  transport varchar(6) default 'FTP',
  quotes_enabled tinyint(1) not null default 0,
  invoices_enabled tinyint(1) not null default 0,
  orders_enabled tinyint(1) not null default 0,
  shipment_budget integer(11) references aqbudgets( budget_id ),
  PRIMARY KEY  (id),
  KEY vendorid (vendor_id),
  KEY shipmentbudget (shipment_budget),
  CONSTRAINT vfk_vendor_id FOREIGN KEY ( vendor_id ) REFERENCES aqbooksellers ( id ),
  CONSTRAINT vfk_shipment_budget FOREIGN KEY ( shipment_budget ) REFERENCES aqbudgets ( budget_id )
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS edifact_messages (
  id int(11) NOT NULL auto_increment,
  message_type varchar(10) NOT NULL,
  transfer_date date,
  vendor_id int(11) references aqbooksellers( id ),
  edi_acct  integer references vendor_edi_accounts( id ),
  status text,
  basketno int(11) references aqbasket( basketno),
  raw_msg text,
  filename text,
  deleted boolean not null default 0,
  PRIMARY KEY  (id),
  KEY vendorid ( vendor_id),
  KEY ediacct (edi_acct),
  KEY basketno ( basketno),
  CONSTRAINT emfk_vendor FOREIGN KEY ( vendor_id ) REFERENCES aqbooksellers ( id ),
  CONSTRAINT emfk_edi_acct FOREIGN KEY ( edi_acct ) REFERENCES vendor_edi_accounts ( id ),
  CONSTRAINT emfk_basketno FOREIGN KEY ( basketno ) REFERENCES aqbasket ( basketno )
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE aqinvoices ADD COLUMN message_id int(11) references edifact_messages( id );

ALTER TABLE aqinvoices ADD CONSTRAINT edifact_msg_fk FOREIGN KEY ( message_id ) REFERENCES edifact_messages ( id ) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS msg_invoice (
  mi_id int(11) NOT NULL auto_increment,
  msg_id int(11) references edifact_messages( id ),
  invoiceid int(11) references aqinvoices( invoiceid ),
  PRIMARY KEY (mi_id),
  KEY msgid ( msg_id),
  KEY invoiceid ( invoiceid ),
  CONSTRAINT mifk_msgid FOREIGN KEY ( msg_id ) REFERENCES edifact_messages ( id ),
  CONSTRAINT mifk_invoiceid FOREIGN KEY ( invoiceid ) REFERENCES aqinvoices ( invoiceid )
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


CREATE TABLE IF NOT EXISTS edifact_ean (
  branchcode varchar(10) not null references branches (branchcode),
  ean varchar(15) NOT NULL,
  id_code_qualifier varchar(3) NOT NULL default '14',
  CONSTRAINT efk_branchcode FOREIGN KEY ( branchcode ) REFERENCES branches ( branchcode )
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

insert into permissions (module_bit, code, description) values (11, 'edi_manage', 'Manage EDIFACT transmissions');
