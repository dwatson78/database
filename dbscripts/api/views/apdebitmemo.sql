/*
select * from apopen
select * from vend
select * from terms
select * from accnt

insert into api.apdebitmemo 
values(5100,20000,30000,'2008-03-31',1000,'NOTES','01-01-5550-01','2008-03-31','NET30')

*/

BEGIN;

-- AP Debit memo
--DROP VIEW api.apdebitmemo;
CREATE VIEW api.apdebitmemo
AS 

SELECT 
vend.vend_number,  --
apo.apopen_ponumber,
apo.apopen_docnumber,
apo.apopen_docdate, 
apo.apopen_amount,
apo.apopen_notes,
acc.accnt_number,
apo.apopen_duedate,
term.terms_code
FROM apopen apo,vendinfo vend,terms term,accnt acc
WHERE apo.apopen_vend_id = vend.vend_id
AND apo.apopen_terms_id = term.terms_id
AND apo.apopen_accnt_id = acc.accnt_id
AND apo.apopen_doctype = 'D';


GRANT ALL ON TABLE api.apdebitmemo TO openmfg;
COMMENT ON VIEW api.apdebitmemo IS 'AP Credit Memo';

--Rules

CREATE OR REPLACE RULE "_INSERT" AS
    ON INSERT TO api.apdebitmemo DO INSTEAD

select createAPDebitMemo(
getVendId(NEW.vend_number), 
NEW.apopen_ponumber,
NEW.apopen_docnumber,
--NEW.apopen_ordernumber,
NEW.apopen_docdate, 
NEW.apopen_amount,
NEW.apopen_notes,
getGlAccntId(NEW.accnt_number),
NEW.apopen_duedate,
getTermsId(NEW.terms_code) --
);

CREATE OR REPLACE RULE "_UPDATE" AS 
    ON UPDATE TO api.apdebitmemo DO INSTEAD

  NOTHING;
           
CREATE OR REPLACE RULE "_DELETE" AS 
    ON DELETE TO api.apdebitmemo DO INSTEAD

  NOTHING;


COMMIT;
