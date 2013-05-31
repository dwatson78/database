CREATE OR REPLACE FUNCTION closeWo(INTEGER, BOOLEAN) RETURNS INTEGER AS $$
DECLARE
  pWoid ALIAS FOR $1;
  pPostMaterialVariances ALIAS FOR $2;
  _woNumber TEXT;
  _check CHAR;

BEGIN

  --If this is item type Job then we cannot close here
  SELECT item_type INTO _check
  FROM wo,itemsite,item
  WHERE ((wo_id=pWoid)
  AND (wo_itemsite_id=itemsite_id)
  AND (itemsite_item_id=item_id)
  AND (item_type = 'J'));
  IF (FOUND) THEN
    RAISE EXCEPTION 'Work orders for Job items are closed when all quantities are shipped';
  END IF;

  SELECT formatWoNumber(pWoid) INTO _woNumber;

--  Distribute any remaining wo_wipvalue to G/L - debit Inventory Cost, credit WIP
  PERFORM insertGLTransaction( 'W/O', 'WO', _woNumber, ('Manufacturing Inventory Cost Variance for ' || item_number),
                               costcat_wip_accnt_id, costcat_invcost_accnt_id, -1,
                               wo_wipvalue, CURRENT_DATE )
  FROM wo, itemsite, item, costcat
  WHERE ( (wo_itemsite_id=itemsite_id)
   AND (itemsite_item_id=item_id)
   AND (itemsite_costcat_id=costcat_id)
   AND (wo_id=pWoid) );

--  Distribute any remaining wo_brdvalue to G/L - debit Inventory Cost, credit WIP
  PERFORM insertGLTransaction( 'W/O', 'WO', _woNumber, ('Breeder Inventory Cost Variance for ' || item_number),
                               costcat_wip_accnt_id,
                               CASE WHEN(itemsite_costmethod='A') THEN costcat_asset_accnt_id
                                    ELSE costcat_invcost_accnt_id
                               END,
                               -1,
                               wo_brdvalue, CURRENT_DATE )
  FROM wo, itemsite, item, costcat
  WHERE ( (wo_itemsite_id=itemsite_id)
   AND (itemsite_item_id=item_id)
   AND (itemsite_costcat_id=costcat_id)
   AND (wo_id=pWoid) );

--  Don't bother with posting variances if the qtyrcv is 0 as
--  they are meaningless.
  IF ( ( SELECT wo_qtyrcv
         FROM wo
         WHERE (wo_id=pWoid) ) > 0 ) THEN

    IF (pPostMaterialVariances) THEN
--  Post womatl variances
    INSERT INTO womatlvar ( womatlvar_number, womatlvar_subnumber, womatlvar_posted,
        womatlvar_parent_itemsite_id, womatlvar_component_itemsite_id,
        womatlvar_qtyord, womatlvar_qtyrcv,
        womatlvar_qtyiss, womatlvar_qtyper,
        womatlvar_scrap, womatlvar_wipscrap, womatlvar_bomitem_id,
        womatlvar_notes, womatlvar_ref )
      SELECT wo_number, wo_subnumber, CURRENT_DATE,
             wo_itemsite_id, womatl_itemsite_id,
             wo_qtyord, wo_qtyrcv,
             itemuomtouom(itemsite_item_id, womatl_uom_id, NULL, womatl_qtyiss),
             itemuomtouom(itemsite_item_id, womatl_uom_id, NULL, womatl_qtyper),
             womatl_scrap,
             itemuomtouom(itemsite_item_id, womatl_uom_id, NULL, womatl_qtywipscrap),
             womatl_bomitem_id,
             womatl_notes, womatl_ref             
      FROM wo, womatl, itemsite
      WHERE ((womatl_wo_id=wo_id)
       AND (womatl_itemsite_id=itemsite_id)      
       AND (wo_id=pWoid));
    END IF;
  END IF;

--  Delete any P/R's created for this W/O
  PERFORM deletePr('W', womatl_id)
  FROM womatl
  WHERE (womatl_wo_id=pWoid);

  UPDATE wo
  SET wo_wipvalue = 0, wo_brdvalue=0,
      wo_status='C'
  WHERE (wo_id=pWoid);

  RETURN 1;
END;
$$ LANGUAGE 'plpgsql';
