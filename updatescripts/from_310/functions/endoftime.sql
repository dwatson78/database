
CREATE OR REPLACE FUNCTION endoftime() RETURNS DATE IMMUTABLE AS $$
SELECT DATE('2100-01-01') as result;
$$ LANGUAGE sql;

