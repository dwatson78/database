CREATE OR REPLACE FUNCTION _voheadBeforeTrigger() RETURNS "trigger" AS $$
DECLARE
  _recurid     INTEGER;
  _newparentid INTEGER;

BEGIN
  IF (TG_OP = 'DELETE') THEN
    DELETE FROM voheadtax
    WHERE (taxhist_parent_id=OLD.vohead_id);

    SELECT recur_id INTO _recurid
      FROM recur
     WHERE ((recur_parent_id=OLD.vohead_id)
        AND (recur_parent_type='V'));
    IF (_recurid IS NOT NULL) THEN
      SELECT vohead_id INTO _newparentid
        FROM vohead
       WHERE ((vohead_recurring_vohead_id=OLD.vohead_id)
          AND (vohead_id!=OLD.vohead_id))
       ORDER BY vohead_docdate
       LIMIT 1;

      IF (_newparentid IS NULL) THEN
        DELETE FROM recur WHERE recur_id=_recurid;
      ELSE
        UPDATE recur SET recur_parent_id=_newparentid
         WHERE recur_id=_recurid;
        UPDATE vohead SET vohead_recurring_vohead_id=_newparentid
         WHERE vohead_recurring_vohead_id=OLD.vohead_id
           AND vohead_id!=OLD.vohead_id;
      END IF;
    END IF;

    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

SELECT dropIfExists('TRIGGER', 'voheadBeforeTrigger');
CREATE TRIGGER voheadBeforeTrigger
  BEFORE INSERT OR UPDATE OR DELETE
  ON vohead
  FOR EACH ROW
  EXECUTE PROCEDURE _voheadBeforeTrigger();

CREATE OR REPLACE FUNCTION _voheadTrigger() RETURNS "trigger" AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    -- Something can go here
    RETURN OLD;
  END IF;

-- Insert new row
  IF (TG_OP = 'INSERT') THEN
    -- Something can go here
    RETURN NEW;
  END IF;

-- Update row
  IF (TG_OP = 'UPDATE') THEN

  -- Calculate Tax
    IF ( (COALESCE(NEW.vohead_taxzone_id,-1) <> COALESCE(OLD.vohead_taxzone_id,-1)) OR
         (NEW.vohead_docdate <> OLD.vohead_docdate) OR
         (NEW.vohead_curr_id <> OLD.vohead_curr_id) ) THEN
      PERFORM calculateTaxHist( 'voitemtax',
                                voitem_id,
                                NEW.vohead_taxzone_id,
                                voitem_taxtype_id,
                                NEW.vohead_docdate,
                                NEW.vohead_curr_id,
                                (vodist_amount * -1) )
      FROM voitem JOIN vodist ON ( (vodist_vohead_id=voitem_vohead_id) AND
                                   (vodist_poitem_id=voitem_poitem_id) )
      WHERE (voitem_vohead_id = NEW.vohead_id);
    END IF;

  -- Touch any Misc Tax Distributions so voheadtax is recalculated
    IF (NEW.vohead_docdate <> OLD.vohead_docdate) THEN
      UPDATE vodist SET vodist_vohead_id=NEW.vohead_id
      WHERE ( (vodist_vohead_id=OLD.vohead_id)
        AND   (vodist_tax_id <> -1) );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

SELECT dropIfExists('TRIGGER', 'voheadtrigger');
CREATE TRIGGER voheadtrigger
  AFTER INSERT OR UPDATE OR DELETE
  ON vohead
  FOR EACH ROW
  EXECUTE PROCEDURE _voheadTrigger();
