create table ac_transactions (
    transaction_id integer(11) auto_increment not null,
    created datetime null,
    updated datetime null,
    primary key (transaction_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

create trigger ac_transactions_insert before insert on `ac_transactions` for each row set new.created = now();

create table ac_transaction_accounts (
    accountline_id integer(11) not null,
    transaction_id integer(11) not null,
    foreign key (accountline_id) references accountlines (accountlines_id),
    foreign key (transaction_id) references ac_transactions (transaction_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
