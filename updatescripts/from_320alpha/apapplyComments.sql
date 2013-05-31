COMMENT ON COLUMN apapply.apapply_source_apopen_id IS 'If apapply_source_doctype is "C" (credit memo) then apapply_source_apopen_id acts as a foreign key to the apopen table. If the source doctype is "K" (check) then the apapply_source_apopen_id acts as a foreign key to the checkhead table. If the apapply_source_apopen_id is -1 then the internal id of the source document is not known (always the case for checks posted before release 3.2.0BETA).';
