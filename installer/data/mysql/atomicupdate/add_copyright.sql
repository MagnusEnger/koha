CREATE TABLE rlcopyright (
   id SERIAL PRIMARY KEY,
   code varchar(10),
   txt text
);
INSERT INTO rlcopyright ( code, txt) values (
'GENERAL',
'Please respect the firm\'s copyright policy -  do not copy more than one article from this issue.' );

INSERT INTO rlcopyright ( code, txt) values (
'RESTRICTED',
'Please respect the firm\'s copyright policy -  do not copy anything from this issue.' );

INSERT INTO rlcopyright ( code, txt) values (
'LEGALEASE',
'You may copy as many articles as you like for your personal use');

ALTER table subscription add column copyright integer;
