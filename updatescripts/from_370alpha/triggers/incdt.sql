CREATE OR REPLACE FUNCTION _incdtBeforeTrigger() RETURNS "trigger" AS $$
DECLARE
  _check        BOOLEAN;
  _crmacct      INTEGER;

BEGIN

  --  Checks
  -- Start with privileges
  IF (TG_OP = 'INSERT') THEN
    SELECT checkPrivilege('AddIncidents') INTO _check;
    IF NOT (_check) THEN
      RAISE EXCEPTION 'You do not have privileges to add new Incidents.';
    END IF;
  ELSE
    SELECT checkPrivilege('MaintainIncidents') INTO _check;
    IF NOT (_check) THEN
      RAISE EXCEPTION 'You do not have privileges to alter an Incident.';
    END IF;
  END IF;

  -- Set the incident number if blank
  IF (TG_OP = 'INSERT') THEN
    IF (NEW.incdt_number IS NULL) THEN
      SELECT fetchIncidentNumber() INTO NEW.incdt_number;
    END IF;
  END IF;

  -- Description is required
  IF (LENGTH(COALESCE(NEW.incdt_summary,''))=0) THEN
    RAISE EXCEPTION 'You must supply a valid Incident Description.';
  END IF;
  
  -- CRM Account is required
  IF (NEW.incdt_crmacct_id IS NULL) THEN
    RAISE EXCEPTION 'You must supply a valid CRM Account.';
  END IF;

  -- Contact is required
  IF (NEW.incdt_cntct_id IS NULL) THEN
    RAISE EXCEPTION 'You must supply a valid Contact.';
  END IF;

  NEW.incdt_updated := now();

  RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

SELECT dropIfExists('TRIGGER', 'incdtbeforetrigger');
CREATE TRIGGER incdtbeforetrigger
  BEFORE INSERT OR UPDATE
  ON incdt
  FOR EACH ROW
  EXECUTE PROCEDURE _incdtBeforeTrigger();

CREATE OR REPLACE FUNCTION _incdtBeforeDeleteTrigger() RETURNS TRIGGER AS $$
DECLARE
  _recurid     INTEGER;
  _newparentid INTEGER;
BEGIN
  IF (TG_OP = 'DELETE') THEN
    SELECT recur_id INTO _recurid
      FROM recur
     WHERE ((recur_parent_id=OLD.incdt_id)
        AND (recur_parent_type='INCDT'));

     IF (_recurid IS NOT NULL) THEN
       SELECT MIN(incdt_id) INTO _newparentid
         FROM incdt
        WHERE ((incdt_recurring_incdt_id=OLD.inctd_id)
           AND (incdt_id!=OLD.incdt_id));

      -- client is responsible for warning about deleting a recurring incdt
      IF (_newparentid IS NULL) THEN
        DELETE FROM recur WHERE recur_id=_recurid;
      ELSE
        UPDATE recur SET recur_parent_id=_newparentid
         WHERE recur_id=_recurid;
      END IF;
    END IF;

    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

SELECT dropIfExists('TRIGGER', 'incdtbeforedeletetrigger');
CREATE TRIGGER incdtbeforedeletetrigger
  BEFORE DELETE
  ON incdt
  FOR EACH ROW
  EXECUTE PROCEDURE _incdtBeforeDeleteTrigger();

CREATE OR REPLACE FUNCTION _incdttrigger() RETURNS "trigger" AS $$
DECLARE
  _r		RECORD;
  _counter	INTEGER :=  0;
  _whsId	INTEGER := -1;
  _evntType	TEXT;
  _cmnttypeid   INTEGER := -1;
  _cmntid       INTEGER := -1;
BEGIN

  SELECT cmnttype_id INTO _cmnttypeid
    FROM cmnttype
    WHERE (cmnttype_name='Notes to Comment');
  IF NOT FOUND OR _cmnttypeid IS NULL THEN
    _cmnttypeid := -1;
  END IF;

  IF (TG_OP = 'DELETE') THEN
--  This should never happen
    RETURN OLD;
  ELSIF (TG_OP = 'INSERT') THEN
    INSERT INTO incdthist
	  (incdthist_incdt_id,
	   incdthist_change, incdthist_target_id,
	   incdthist_descrip)
    VALUES(NEW.incdt_id,
	   'N', NULL,
	   'Incident Added');

    _evntType = 'NewIncident';

    IF (_cmnttypeid <> -1 AND COALESCE(NEW.incdt_descrip, '') <> '') THEN
      PERFORM postComment(_cmnttypeid, 'INCDT', NEW.incdt_id, NEW.incdt_descrip);
    END IF;
  ELSIF (TG_OP = 'UPDATE') THEN
    _evntType = 'UpdatedIncident';

    IF (COALESCE(NEW.incdt_cntct_id,-1) <> COALESCE(OLD.incdt_cntct_id,-1)) THEN
      INSERT INTO incdthist
	    (incdthist_incdt_id,
	     incdthist_change, incdthist_target_id,
	     incdthist_descrip)
      VALUES(NEW.incdt_id,
	     'C', NEW.incdt_cntct_id,
	     ('Contact Changed: "' ||
	       COALESCE((SELECT cntct_first_name || ' ' || cntct_last_name
			   FROM cntct
			  WHERE (cntct_id=OLD.incdt_cntct_id)), '')
	      || '" -> "' ||
	       COALESCE((SELECT cntct_first_name || ' ' || cntct_last_name
			   FROM cntct
			  WHERE (cntct_id=NEW.incdt_cntct_id)), '')
	      || '"') );
    END IF;

    IF (COALESCE(NEW.incdt_summary,'') <> COALESCE(OLD.incdt_summary,'')) THEN
      INSERT INTO incdthist
	    (incdthist_incdt_id,
	     incdthist_descrip)
      VALUES(NEW.incdt_id,
	     ('Summary Updated: "' ||
	       COALESCE(OLD.incdt_summary, '') ||
	      '" -> "' ||
	       COALESCE(NEW.incdt_summary, '') ||
	      '"') );
    END IF;

    IF (COALESCE(NEW.incdt_descrip,'') <> COALESCE(OLD.incdt_descrip,'')) THEN
      INSERT INTO incdthist
	    (incdthist_incdt_id,
	     incdthist_descrip)
      VALUES(NEW.incdt_id,
	     ('Description Updated: "' ||
	       substr(COALESCE(OLD.incdt_descrip, ''), 1, 20) ||
	      '..." -> "' ||
	       substr(COALESCE(NEW.incdt_descrip, ''), 1, 20) ||
	      '..."') );

      IF (_cmnttypeid <> -1) THEN
        -- find an existing comment
        SELECT comment_id
          INTO _cmntid
          FROM comment
         WHERE comment_source = 'INCDT'
           AND comment_source_id = NEW.incdt_id
           AND comment_cmnttype_id = _cmnttypeid;
        IF FOUND THEN
          UPDATE comment SET comment_text = NEW.incdt_descrip WHERE comment_id = _cmntid;
        ELSE
          PERFORM postComment(_cmnttypeid, 'INCDT', NEW.incdt_id, NEW.incdt_descrip);
        END IF;
      END IF;
    END IF;

    IF (NEW.incdt_status <> OLD.incdt_status) THEN
      INSERT INTO incdthist
	    (incdthist_incdt_id,
	     incdthist_change, incdthist_target_id,
	     incdthist_descrip)
      VALUES(NEW.incdt_id,
	     'S', NULL,
	     ('Status Changed: ' ||
	      CASE WHEN(OLD.incdt_status='N') THEN 'New'
		   WHEN(OLD.incdt_status='F') THEN 'Feedback'
		   WHEN(OLD.incdt_status='C') THEN 'Confirmed'
		   WHEN(OLD.incdt_status='A') THEN 'Assigned'
		   WHEN(OLD.incdt_status='R') THEN 'Resolved'
		   WHEN(OLD.incdt_status='L') THEN 'Closed'
		   ELSE OLD.incdt_status
	      END
	      || ' -> ' ||
	      CASE WHEN(NEW.incdt_status='N') THEN 'New'
		   WHEN(NEW.incdt_status='F') THEN 'Feedback'
		   WHEN(NEW.incdt_status='C') THEN 'Confirmed'
		   WHEN(NEW.incdt_status='A') THEN 'Assigned'
		   WHEN(NEW.incdt_status='R') THEN 'Resolved'
		   WHEN(NEW.incdt_status='L') THEN 'Closed'
		   ELSE NEW.incdt_status
	      END
	      ) );
      IF (NEW.incdt_status = 'L') THEN
	_evntType = 'ClosedIncident';
      ELSIF (OLD.incdt_status = 'L') THEN
	_evntType = 'ReopenedIncident';
      END IF;
    END IF;

    IF (COALESCE(NEW.incdt_assigned_username,'') <> COALESCE(OLD.incdt_assigned_username,'')) THEN
      INSERT INTO incdthist
	    (incdthist_incdt_id,
	     incdthist_change, incdthist_target_id,
	     incdthist_descrip)
      VALUES(NEW.incdt_id,
	     'A', NULL,
	     ('Assigned to: "' ||
	       COALESCE(OLD.incdt_assigned_username, '') ||
	      '" -> "' ||
	       COALESCE(NEW.incdt_assigned_username, '') ||
	      '"') );
    END IF;

    IF (COALESCE(NEW.incdt_incdtcat_id,-1) <> COALESCE(OLD.incdt_incdtcat_id,-1)) THEN
      INSERT INTO incdthist
	    (incdthist_incdt_id,
	     incdthist_change, incdthist_target_id,
	     incdthist_descrip)
      VALUES(NEW.incdt_id,
	     'T', NEW.incdt_incdtcat_id,
	     ('Category Changed: ' ||
	       COALESCE((SELECT incdtcat_name
			   FROM incdtcat
			  WHERE (incdtcat_id=OLD.incdt_incdtcat_id)), '')
	      || ' -> ' ||
	       COALESCE((SELECT incdtcat_name
			   FROM incdtcat
			  WHERE (incdtcat_id=NEW.incdt_incdtcat_id)), '')
	      || '') );
    END IF;

    IF (COALESCE(NEW.incdt_incdtseverity_id,-1) <> COALESCE(OLD.incdt_incdtseverity_id,-1)) THEN
      INSERT INTO incdthist
	    (incdthist_incdt_id,
	     incdthist_change, incdthist_target_id,
	     incdthist_descrip)
      VALUES(NEW.incdt_id,
	     'V', NEW.incdt_incdtseverity_id,
	     ('Severity Changed: ' ||
	       COALESCE((SELECT incdtseverity_name
			   FROM incdtseverity
			  WHERE (incdtseverity_id=OLD.incdt_incdtseverity_id)), '')
	      || ' -> ' ||
	       COALESCE((SELECT incdtseverity_name
			   FROM incdtseverity
			  WHERE (incdtseverity_id=NEW.incdt_incdtseverity_id)), '')
	      || '') );
    END IF;

    IF (COALESCE(NEW.incdt_incdtpriority_id,-1) <> COALESCE(OLD.incdt_incdtpriority_id,-1)) THEN
      INSERT INTO incdthist
	    (incdthist_incdt_id,
	     incdthist_change, incdthist_target_id,
	     incdthist_descrip)
      VALUES(NEW.incdt_id,
	     'P', NEW.incdt_incdtpriority_id,
	     ('Priority Changed: ' ||
	       COALESCE((SELECT incdtpriority_name
			   FROM incdtpriority
			  WHERE (incdtpriority_id=OLD.incdt_incdtpriority_id)), '')
	      || ' -> ' ||
	       COALESCE((SELECT incdtpriority_name
			   FROM incdtpriority
			  WHERE (incdtpriority_id=NEW.incdt_incdtpriority_id)), '')
	      || '') );
    END IF;

    IF (COALESCE(NEW.incdt_incdtresolution_id,-1) <> COALESCE(OLD.incdt_incdtresolution_id,-1)) THEN
      INSERT INTO incdthist
	    (incdthist_incdt_id,
	     incdthist_change, incdthist_target_id,
	     incdthist_descrip)
      VALUES(NEW.incdt_id,
	     'E', NEW.incdt_incdtresolution_id,
	     ('Resolution Changed: ' ||
	       COALESCE((SELECT incdtresolution_name
			   FROM incdtresolution
			  WHERE (incdtresolution_id=OLD.incdt_incdtresolution_id)), '')
	      || ' -> ' ||
	       COALESCE((SELECT incdtresolution_name
			   FROM incdtresolution
			  WHERE (incdtresolution_id=NEW.incdt_incdtresolution_id)), '')
	      || '') );
    END IF;
  END IF;

  -- find the warehouse for which to create evntlog entries
    SELECT usrpref_value  INTO _whsId
    FROM usrpref
    WHERE usrpref_username = CURRENT_USER
      AND usrpref_name = 'PreferredWarehouse';

  INSERT INTO evntlog (evntlog_evnttime, evntlog_username,
		       evntlog_evnttype_id, evntlog_ordtype,
		       evntlog_ord_id, evntlog_warehous_id, evntlog_number)
  SELECT DISTINCT CURRENT_TIMESTAMP, evntnot_username, evnttype_id,
		       'IC', NEW.incdt_id, _whsId, NEW.incdt_number
  FROM evntnot, evnttype
  WHERE ((evntnot_evnttype_id=evnttype_id)
    AND  (evnttype_name=_evntType));

  RETURN NEW;
  END;
$$ LANGUAGE 'plpgsql';

SELECT dropIfExists('TRIGGER', 'incdttrigger');
CREATE TRIGGER incdttrigger
  AFTER INSERT OR UPDATE OR DELETE
  ON incdt
  FOR EACH ROW
  EXECUTE PROCEDURE _incdttrigger();
