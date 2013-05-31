
CREATE OR REPLACE FUNCTION copypricingschedule(INTEGER) RETURNS INTEGER AS $$
-- Copyright (c) 1999-2011 by OpenMFG LLC, d/b/a xTuple. 
-- See www.xtuple.com/CPAL for the full text of the software license.
DECLARE
  pIpsheadId ALIAS FOR $1;
  _ipsheadid INTEGER;
  _ipsitemid INTEGER;
  _ipsfreightid INTEGER;
  _x RECORD;

BEGIN

  _ipsheadid := nextval('ipshead_ipshead_id_seq');
  INSERT INTO ipshead 
  ( ipshead_id, ipshead_name, ipshead_descrip,
    ipshead_effective, ipshead_expires, 
    ipshead_curr_id, ipshead_updated ) 
  SELECT _ipsheadid, orig.ipshead_name || (SELECT CAST((COUNT(cnt.ipshead_id)+1) AS text)
				            FROM ipshead cnt
				            WHERE (SUBSTRING(cnt.ipshead_name FROM 0 FOR char_length(orig.ipshead_name)+1) = orig.ipshead_name)),
	 orig.ipshead_descrip, orig.ipshead_effective, orig.ipshead_expires, 
	 orig.ipshead_curr_id, CURRENT_DATE
  FROM ipshead orig
  WHERE (orig.ipshead_id=pIpsheadId);

  FOR _x IN
    SELECT ipsitem_id FROM ipsitem WHERE (ipsitem_ipshead_id=pIpsheadid)
  LOOP 
      _ipsitemid := nextval('ipsitem_ipsitem_id_seq');
      INSERT INTO ipsitem 
          (ipsitem_id, ipsitem_ipshead_id, ipsitem_item_id, 
           ipsitem_qtybreak, ipsitem_price,
           ipsitem_qty_uom_id, ipsitem_price_uom_id,
           ipsitem_discntprcnt, ipsitem_fixedamtdiscount) 
      SELECT _ipsitemid, _ipsheadid, ipsitem_item_id, 
           ipsitem_qtybreak, ipsitem_price,
           ipsitem_qty_uom_id, ipsitem_price_uom_id,
           ipsitem_discntprcnt, ipsitem_fixedamtdiscount
      FROM ipsitem 
      WHERE (ipsitem_id=_x.ipsitem_id); 

      INSERT INTO ipsitemchar
        ( ipsitemchar_ipsitem_id, ipsitemchar_char_id,
          ipsitemchar_value, ipsitemchar_price)
      SELECT  _ipsitemid, ipsitemchar_char_id,
          ipsitemchar_value, ipsitemchar_price
      FROM ipsitemchar
      WHERE (ipsitemchar_ipsitem_id=_x.ipsitem_id);
  END LOOP;

  FOR _x IN
    SELECT ipsfreight_id FROM ipsfreight WHERE (ipsfreight_ipshead_id=pIpsheadid)
  LOOP 
      _ipsfreightid := nextval('ipsfreight_ipsfreight_id_seq');
      INSERT INTO ipsfreight
          (ipsfreight_id, ipsfreight_ipshead_id, 
           ipsfreight_qtybreak, ipsfreight_price,
           ipsfreight_type, ipsfreight_warehous_id,
           ipsfreight_shipzone_id,ipsfreight_freightclass_id,
           ipsfreight_shipvia) 
      SELECT _ipsfreightid, _ipsheadid, ipsfreight_qtybreak, 
           ipsfreight_price,ipsfreight_type, 
           ipsfreight_warehous_id,ipsfreight_shipzone_id,
           ipsfreight_freightclass_id,ipsfreight_shipvia
      FROM ipsfreight
      WHERE (ipsfreight_id=_x.ipsfreight_id); 

  END LOOP;


  INSERT INTO ipsprodcat 
        (ipsprodcat_ipshead_id, ipsprodcat_prodcat_id, 
         ipsprodcat_qtybreak, ipsprodcat_discntprcnt, ipsprodcat_fixedamtdiscount) 
  SELECT _ipsheadid, ipsprodcat_prodcat_id, 
         ipsprodcat_qtybreak, ipsprodcat_discntprcnt, ipsprodcat_fixedamtdiscount 
  FROM ipsprodcat 
  WHERE (ipsprodcat_ipshead_id=pIpsheadId);

  RETURN _ipsheadid;

END;
$$ LANGUAGE 'plpgsql';

