CREATE OR REPLACE FUNCTION getContrctExpires(pContrctNumber text) RETURNS DATE AS $$
-- Copyright (c) 1999-2012 by OpenMFG LLC, d/b/a xTuple. 
-- See www.xtuple.com/CPAL for the full text of the software license.
DECLARE
  _returnVal DATE;
BEGIN
  IF (pContrctNumber IS NULL) THEN
    RETURN NULL;
  END IF;

  SELECT contrct_expires INTO _returnVal
  FROM contrct
  WHERE (contrct_number=pContrctNumber);

  IF (_returnVal IS NULL) THEN
	RAISE EXCEPTION 'Contract Number % not found.', pContrctNumber;
  END IF;

  RETURN _returnVal;
END;
$$ LANGUAGE 'plpgsql';
